-- Sprint.client.lua
-- Hold Shift to run faster -- but it costs STAMINA. Stamina drains while you're actually running,
-- refills when you're not, and if it empties you drop back to walk until it recovers a bit.
--
-- Each character has its own walk/sprint speeds in Constants.lua. Characters not listed in SPEEDS
-- here can't sprint. Stamina numbers live in Constants.Stamina. The HUD reads our progress from the
-- "Stamina" attribute we set on the local player (a 0..1 fraction).
--
-- Walk speed gets reset to the character's default whenever they spawn (Bootstrap handles that). We
-- only change WalkSpeed when sprint actually turns ON or OFF, so we don't fight ability slows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local localPlayer = Players.LocalPlayer
local ST = Constants.Stamina

-- Per-character {walk, sprint}. Characters missing here don't sprint.
local SPEEDS = {
	Momotaro    = {Walk = Constants.Speed.WardenWalk,     Sprint = Constants.Speed.WardenSprint},
	Otohime     = {Walk = Constants.Speed.WardenWalk,     Sprint = Constants.Speed.WardenSprint},
	Rokurokubi  = {Walk = Constants.Speed.RokurokubiWalk, Sprint = Constants.Speed.RokurokubiSprint},
	GirlA       = {Walk = Constants.Speed.GirlAWalk,      Sprint = Constants.Speed.GirlARun},
}

local stamina = ST.Max          -- current stamina (0 .. ST.Max)
local wantSprint = false        -- is Shift / the run button currently held?
local depleted = false          -- true after we hit 0, until we recover MinToSprint
local wasSprinting = false      -- so we only set WalkSpeed on the actual on/off transition
local lastSprintClock = 0       -- when we last sprinted (for the regen delay)

localPlayer:SetAttribute("Stamina", 1)   -- HUD reads this (0..1)

-- Shift (and an auto on-screen "Run" button on mobile) just flips wantSprint.
ContextActionService:BindAction("Sprint", function(_, inputState)
	wantSprint = (inputState == Enum.UserInputState.Begin)
	return Enum.ContextActionResult.Pass   -- don't sink the key; other things may want Shift too
end, true, Enum.KeyCode.LeftShift)
ContextActionService:SetTitle("Sprint", "Run")

RunService.Heartbeat:Connect(function(dt)
	local characterName = localPlayer:GetAttribute("Character")
	local pair = SPEEDS[characterName]
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not pair or not humanoid then return end

	-- Girl A's Incognito Mode controls her own speed boost -- don't fight it, and don't drain.
	if localPlayer:GetAttribute("Incognito") then return end

	-- Only counts as running if they're actually moving while holding the button and have stamina.
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local sprinting = wantSprint and moving and not depleted and stamina > 0

	if sprinting then
		stamina = math.max(0, stamina - ST.DrainPerSecond * dt)
		lastSprintClock = os.clock()
		if stamina <= 0 then depleted = true end   -- emptied -> must recover before running again
	else
		-- Refill, after a short pause since we last sprinted.
		if os.clock() - lastSprintClock >= ST.RegenDelaySeconds then
			stamina = math.min(ST.Max, stamina + ST.RegenPerSecond * dt)
		end
		if depleted and stamina >= ST.MinToSprint then depleted = false end
	end

	-- Only touch WalkSpeed when sprint flips on or off (so we don't stomp ability slows every frame).
	if sprinting ~= wasSprinting then
		humanoid.WalkSpeed = sprinting and pair.Sprint or pair.Walk
		wasSprinting = sprinting
	end

	localPlayer:SetAttribute("Stamina", stamina / ST.Max)
end)
