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
--   Hold         : seconds to keep the finished pose before snapping back (a stab lingers).
--   Joints       : INSTEAD of PrimaryArm/TwoHanded: a list of {Name, Axis, Windup, Swing, Offset}
--                  posing any joints by name (shoulders, hips, Neck, RootJoint). Offset is a
--                  joint-local translation reached at the end of the swing (e.g. a drop).
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
	TominoWhip = {
		Duration    = 0.45,
		WindupFrac  = 0.35,
		WindupAngle = 150,
		SwingAngle  = -30,
		PrimaryArm  = "Left",  -- his whip hangs on his left side
		TwoHanded   = false,
		Axis        = "X",     -- R15 shoulders pitch forward on X, not Z like R6
	},
	-- Two Time Prime's lunge-and-stab, knife in the LEFT hand. Angles are the R6 approximation of the
	-- kids' posed reference (CHECKLIST, Two Time Prime): torso pitched forward, lead leg forward,
	-- back leg thrust back, head looking UP at the target. Signs are first guesses; flip one if a
	-- joint bends the wrong way.
	TwoTimePrimeStab = {
		Duration    = 0.5,
		WindupFrac  = 0.35,
		Hold        = 0.25,
		Joints = {
			{Name = "Left Shoulder",  Axis = "Z", Windup = 20,  Swing = -95},   -- knife arm: back, then thrust
			{Name = "Right Shoulder", Axis = "Z", Windup = -10, Swing = 35},    -- free arm forward for balance
			{Name = "Left Hip",       Axis = "Z", Windup = 0,   Swing = -40},   -- lead leg forward
			{Name = "Right Hip",      Axis = "Z", Windup = 0,   Swing = -35},   -- back leg thrust back
			{Name = "RootJoint",      Axis = "X", Windup = 5,   Swing = -40, Offset = Vector3.new(0, 0, -1)},  -- lean in + drop
			{Name = "Neck",           Axis = "X", Windup = 0,   Swing = 35},    -- keeps looking at the target
		},
	},
	TominoWhipSlam = {
		Duration    = 0.7,     -- windup lines up with Constants.Tomino.WhipSlam.WindupSeconds (0.7 x 0.6 = 0.42s)
		WindupFrac  = 0.6,
		WindupAngle = 180,     -- straight overhead
		SwingAngle  = -60,     -- slams down past his side into the ground
		PrimaryArm  = "Left",
		TwoHanded   = true,    -- both arms bring it down, so it reads heavier than a lash
		Axis        = "X",
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

local function findJoint(character, name)
	local torso = character:FindFirstChild("Torso")
	if torso and torso:FindFirstChild(name) then return torso[name] end
	local side, rest = name:match("^(%a+) (%a+)$")
	if side and rest == "Shoulder" then
		local upperArm = character:FindFirstChild(side .. "UpperArm")   -- R15 (Tomino)
		if upperArm then return upperArm:FindFirstChild(side .. "Shoulder") end
	end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == name then return d end
	end
	return nil
end

-- Turns a style into a list of {joint, base, axis, windup, swing, offset} to drive each frame.
-- Arm styles (PrimaryArm/TwoHanded) become one or two shoulder entries; Joints styles list
-- every joint by hand with its own angles.
local function jointPlan(character, cfg)
	local plan = {}
	if cfg.Joints then
		for _, j in ipairs(cfg.Joints) do
			local joint = findJoint(character, j.Name)
			if joint then
				table.insert(plan, {joint = joint, base = restingC0(joint), axis = j.Axis or "Z",
					windup = j.Windup or 0, swing = j.Swing or 0, offset = j.Offset})
			end
		end
		return plan
	end

	local otherArm = (cfg.PrimaryArm == "Left") and "Right" or "Left"
	local primary = findJoint(character, cfg.PrimaryArm .. " Shoulder")
	if not primary then return plan end
	local axis = cfg.Axis or "Z"
	table.insert(plan, {joint = primary, base = restingC0(primary), axis = axis,
		windup = cfg.WindupAngle, swing = cfg.SwingAngle})
	if cfg.TwoHanded then
		local other = findJoint(character, otherArm .. " Shoulder")
		if other then
			-- R6 shoulders are built mirrored, so the other arm needs the angle negated to sweep the
			-- SAME way. R15 shoulders aren't mirrored.
			local sign = character:FindFirstChild("Torso") and -1 or 1
			table.insert(plan, {joint = other, base = restingC0(other), axis = axis,
				windup = sign * cfg.WindupAngle, swing = sign * cfg.SwingAngle})
		end
	end
	return plan
end

local function playSwing(character, style)
	local cfg = CONFIG[style]
	if not cfg or not character then return end

	local plan = jointPlan(character, cfg)
	if #plan == 0 then return end

	-- New swing token; any previous swing on this character sees a stale token and stops.
	local myToken = {}
	activeToken[character] = myToken
	character:SetAttribute("Swinging", true)

	local function restore()
		for _, entry in ipairs(plan) do entry.joint.C0 = entry.base end
		if activeToken[character] == myToken then
			activeToken[character] = nil
			character:SetAttribute("Swinging", nil)
		end
	end

	local total = cfg.Duration + (cfg.Hold or 0)
	local start = tick()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		-- Stop if a newer swing started, or the character/joints went away.
		if activeToken[character] ~= myToken or not plan[1].joint.Parent then
			conn:Disconnect()
			return
		end

		local elapsed = tick() - start
		if elapsed >= total then
			-- Done: snap everything back to its resting pose (default animation resumes).
			restore()
			conn:Disconnect()
			return
		end

		-- Pose by rotating each joint's C0 off its rest pose (the animator can't fight C0). After
		-- Duration the final pose holds for cfg.Hold seconds.
		local t = math.min(elapsed / cfg.Duration, 1)
		for _, entry in ipairs(plan) do
			local degrees = angleAt({WindupFrac = cfg.WindupFrac, WindupAngle = entry.windup, SwingAngle = entry.swing}, t)
			local cf = entry.base
			if entry.offset then
				local progress = (t < cfg.WindupFrac) and 0 or easeIn((t - cfg.WindupFrac) / (1 - cfg.WindupFrac))
				cf = cf * CFrame.new(entry.offset * progress)
			end
			entry.joint.C0 = cf * rotateOn(entry.axis, math.rad(degrees))
		end
	end)
end

WeaponSwing.OnClientEvent:Connect(function(player, style)
	if typeof(player) ~= "Instance" then return end
	local character = player.Character
	if character then playSwing(character, style) end
end)
