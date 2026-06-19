-- WeaponSwing.client.lua
-- Plays a quick code-driven weapon swing on a character's arms -- no uploaded animation needed.
--
-- WHY THIS IS A CLIENT SCRIPT: every R6 character runs Roblox's built-in "Animate" script for
-- walking/idle, and it drives the same shoulder joints we want to swing. If we posed the arms on
-- the server it would flicker as Animate fought us. Instead, each client poses the shoulders in
-- RenderStepped, which runs AFTER the default animation every frame, so our swing wins the frame.
--
-- The server fires the WeaponSwing remote to ALL clients when someone swings, passing the player
-- and a style name. Every client then plays that style on that player's body, so everyone sees it.
--
-- TO TUNE: edit the CONFIG entry for the style. Angles are in degrees. If the arm swings the wrong
-- way (backwards), flip the SIGN of WindupAngle/SwingAngle. To add a new weapon (e.g. Momotaro's
-- katana) just add another CONFIG entry and fire that style name from the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponSwing = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeaponSwing")

------------------------------------------------------------------------------
-- One entry per swing style.
--   Duration     : how long the whole swing takes, in seconds.
--   WindupFrac   : fraction of the time spent winding UP before the chop (0..1).
--   WindupAngle  : how far the arm raises during the windup, in degrees.
--   SwingAngle   : where the arm ends up at the follow-through, in degrees.
--   PrimaryArm   : which arm holds the weapon and does the swing -- "Right" or "Left".
--   TwoHanded    : if true, the OTHER arm swings along too (both grip the weapon).
--   Axis         : which way the arm swings -- "X", "Y", or "Z". If the swing goes the wrong
--                  direction (e.g. sideways instead of overhead), try a different letter.
------------------------------------------------------------------------------
local CONFIG = {
	GirlAHatchet = {
		Duration    = 0.45,
		WindupFrac  = 0.4,
		WindupAngle = 150,    -- raise the arm up-and-forward (overhead in front)
		SwingAngle  = 40,     -- chop down and forward
		PrimaryArm  = "Right",
		TwoHanded   = true,
		Axis        = "Z",    -- overhead chop plane (forward/back)
	},
	MomotaroKatana = {
		Duration    = 0.4,
		WindupFrac  = 0.3,
		WindupAngle = -110,
		SwingAngle  = 60,
		PrimaryArm  = "Left",  -- his katana is welded to his Left arm
		TwoHanded   = false,
		Axis        = "Z",
	},
}

-- Tracks the active swing per character so a new swing cancels the old one cleanly.
local activeToken = setmetatable({}, { __mode = "k" })   -- weak keys: characters can be collected

-- Each joint's resting C0 (its "arm down" base). We pose the swing by rotating OFF this base and
-- restore to it when done. The animator never touches C0, so reading it any time gives the true
-- rest pose. Weak keys so joints can be collected with their characters.
local baseC0 = setmetatable({}, { __mode = "k" })
local function restingC0(motor)
	if not baseC0[motor] then baseC0[motor] = motor.C0 end
	return baseC0[motor]
end

-- A rotation of `radians` around the chosen axis.
local function rotateOn(axis, radians)
	if axis == "X" then return CFrame.Angles(radians, 0, 0) end
	if axis == "Y" then return CFrame.Angles(0, radians, 0) end
	return CFrame.Angles(0, 0, radians)   -- "Z" (default)
end

local function lerp(a, b, t) return a + (b - a) * t end
local function easeOut(a) return 1 - (1 - a) * (1 - a) end   -- fast then slow (windup)
local function easeIn(a)  return a * a end                    -- slow then fast (the chop)

-- The angle of the swing at time `t` (0..1) for a given style.
local function angleAt(cfg, t)
	if t < cfg.WindupFrac then
		local a = t / cfg.WindupFrac
		return lerp(0, cfg.WindupAngle, easeOut(a))
	else
		local a = (t - cfg.WindupFrac) / (1 - cfg.WindupFrac)
		return lerp(cfg.WindupAngle, cfg.SwingAngle, easeIn(a))
	end
end

local function playSwing(character, style)
	local cfg = CONFIG[style]
	if not cfg or not character then return end

	local torso = character:FindFirstChild("Torso")
	if not torso then return end   -- not an R6 rig; nothing to swing

	-- The primary arm holds the weapon; the other arm only moves if it's a two-handed swing.
	local primaryName = (cfg.PrimaryArm == "Left") and "Left Shoulder" or "Right Shoulder"
	local otherName   = (cfg.PrimaryArm == "Left") and "Right Shoulder" or "Left Shoulder"
	local primaryShoulder = torso:FindFirstChild(primaryName)
	local otherShoulder   = cfg.TwoHanded and torso:FindFirstChild(otherName) or nil
	if not primaryShoulder then return end

	-- Grab each arm's resting C0 so we rotate off it and can restore it cleanly afterward.
	local axis = cfg.Axis or "Z"
	local primaryBase = restingC0(primaryShoulder)
	local otherBase   = otherShoulder and restingC0(otherShoulder) or nil

	-- New swing token; any previous swing on this character sees a stale token and stops.
	local myToken = {}
	activeToken[character] = myToken

	local function restore()
		primaryShoulder.C0 = primaryBase
		if otherShoulder then otherShoulder.C0 = otherBase end
	end

	local start = tick()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		-- Stop if a newer swing started, or the character/joints went away.
		if activeToken[character] ~= myToken or not primaryShoulder.Parent then
			conn:Disconnect()
			return
		end

		local t = (tick() - start) / cfg.Duration
		if t >= 1 then
			-- Done: snap the arms back to their resting pose (default animation resumes).
			restore()
			if activeToken[character] == myToken then activeToken[character] = nil end
			conn:Disconnect()
			return
		end

		-- Pose by rotating each shoulder's C0 off its rest pose (the animator can't fight C0).
		local degrees = angleAt(cfg, t)
		primaryShoulder.C0 = primaryBase * rotateOn(axis, math.rad(degrees))
		-- The other shoulder is built mirrored, so negate the angle to sweep the SAME way.
		if otherShoulder then otherShoulder.C0 = otherBase * rotateOn(axis, math.rad(-degrees)) end
	end)
end

WeaponSwing.OnClientEvent:Connect(function(player, style)
	if typeof(player) ~= "Instance" then return end
	local character = player.Character
	if character then playSwing(character, style) end
end)
