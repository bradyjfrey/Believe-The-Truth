-- GirlAHover.client.lua
-- Girl A floats and drags her hatchet behind her (the kids' brief). Two jobs:
--   1. On HER OWN client: swap the walk/run animations for the idle one so her legs don't cycle
--      while she glides (the default Animate script re-reads these when they change), and bob her
--      HipHeight gently. The lift itself is set at spawn (Constants.GirlA.Hover.FloatLift).
--   2. On EVERY client: pose her hatchet arm trailing back, the same C0 trick WeaponSwing uses.
--      Stands aside while WeaponSwing has her mid-swing (the Swinging attribute on her character).
-- Numbers in Constants.GirlA.Hover. If the arm trails the wrong way, flip DragArmDegrees' sign.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local H = Constants.GirlA.Hover

local localPlayer = Players.LocalPlayer

local function isGirlA(player)
	return player:GetAttribute("Character") == "GirlA"
end

------------------------------------------------------------------------------
-- 1. Own client: no leg cycle, gentle bob
------------------------------------------------------------------------------

local function glideOwnCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	local animate = character:WaitForChild("Animate", 5)
	if not (humanoid and animate) then return end

	local idle = animate:FindFirstChild("idle")
	local idleAnim = idle and idle:FindFirstChild("Animation1")
	if idleAnim then
		for _, name in ipairs({"walk", "run"}) do
			local folder = animate:FindFirstChild(name)
			if folder then
				for _, anim in ipairs(folder:GetChildren()) do
					if anim:IsA("Animation") then anim.AnimationId = idleAnim.AnimationId end
				end
			end
		end
	end

	-- The server applies the float lift at spawn; wait so we read the lifted height as our base.
	task.wait(1)
	if not character.Parent then return end
	local baseHip = humanoid.HipHeight
	local started = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not character.Parent or not isGirlA(localPlayer) then
			conn:Disconnect()
			return
		end
		humanoid.HipHeight = baseHip + math.sin((os.clock() - started) * H.BobPerSecond * 2 * math.pi) * H.BobStuds
	end)
end

local function watchOwn()
	local function onCharacter(character)
		if isGirlA(localPlayer) then glideOwnCharacter(character) end
	end
	localPlayer.CharacterAdded:Connect(onCharacter)
	localPlayer:GetAttributeChangedSignal("Character"):Connect(function()
		if localPlayer.Character and isGirlA(localPlayer) then glideOwnCharacter(localPlayer.Character) end
	end)
	if localPlayer.Character then onCharacter(localPlayer.Character) end
end
watchOwn()

------------------------------------------------------------------------------
-- 2. Every client: hatchet arm trails behind
------------------------------------------------------------------------------

local baseC0 = setmetatable({}, {__mode = "k"})

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if not character or not isGirlA(player) or character:GetAttribute("Swinging") then continue end
		local torso = character:FindFirstChild("Torso")
		local shoulder = torso and torso:FindFirstChild("Right Shoulder")
		if not shoulder then continue end
		if not baseC0[shoulder] then baseC0[shoulder] = shoulder.C0 end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local moving = humanoid and humanoid.MoveDirection.Magnitude > 0.1
		local sway = math.sin(t * H.SwayPerSecond * 2 * math.pi) * H.SwayDegrees * (moving and 1 or 0.3)
		shoulder.C0 = baseC0[shoulder] * CFrame.Angles(0, 0, math.rad(H.DragArmDegrees + sway))
	end
end)
