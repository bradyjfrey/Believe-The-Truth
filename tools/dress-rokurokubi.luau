-- FLATTEN ROKUROKUBI (non-destructive): she is ALREADY rigged and her costume is ALREADY welded.
-- Unlike GirlA/Momotaro we do NOT re-weld anything. Her only problem is that her body parts are
-- buried several models deep, while the Humanoid expects them as direct children of ONE model. So
-- this script clones her, pulls the Humanoid + the 6 R6 body parts + all her welded costume into a
-- single clean "StarterCharacter" model, unanchors it, and deploys it. Master is never touched.
--
-- HOW TO USE:
-- 1. In the Explorer, select "Killer Rorokubi".
-- 2. Copy this whole file into the Command Bar, click the Command Bar's Run button.
-- 3. Test > Server and Clients (2 players) to spawn and look at her.
-- 4. When done, delete StarterCharacter from StarterPlayer.

local Selection = game:GetService("Selection")
local StarterPlayer = game:GetService("StarterPlayer")

-- TUNABLE: her auto-built rig faces BACKWARD, so she runs showing her backside. This spins her
-- body to face the way she walks. 180 flips her around; if she ends up sideways try 90 or -90.
local BODY_TURN = 180

-- Rokurokubi doesn't walk -- she FLOATS with her arms folded in front. So instead of fixing the
-- walk swing, we POSE her arms folded and FREEZE her limbs so the walk animation can't move them.
-- These three knobs rotate the arms in the TORSO's OWN axes (so the directions are predictable).
-- Re-run and nudge until they fold in front, like we did the hair.
local ARM_SWING = 80   -- bring the arms from the SIDES to the FRONT (+ = more toward the front)
local ARM_RAISE = -10  -- tilt the arms up/down (- = lower them)
local ARM_TWIST = 90   -- roll each arm along its length so the bottoms point IN (try -90 if they point out)

-- TUNABLE: how high she floats off the ground, in studs. WASD still drives her -- she just glides
-- this much higher. Bigger = floats higher. (The gentle up/down bob + side sway come in a separate
-- behavior script next.)
local FLOAT_LIFT = 3

local src = Selection:Get()[1]
if not src then warn("Select 'Killer Rorokubi' first.") return end
local clone = src:Clone()

-- Find the Humanoid and the HumanoidRootPart.
local hum
for _, d in ipairs(clone:GetDescendants()) do
	if d:IsA("Humanoid") then hum = d break end
end
if not hum then warn("No Humanoid found.") clone:Destroy() return end

local hrp
for _, d in ipairs(clone:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "HumanoidRootPart" then hrp = d break end
end

-- Find the real rig parts THROUGH THE JOINTS (not by name), since her head is hidden inside the
-- "Handle" mesh and some names are non-standard.
local function findMotor(name)
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == name then return d end
	end
end
local neck  = findMotor("Neck")
local lsh   = findMotor("Left Shoulder")
local rsh   = findMotor("Right Shoulder")
local lhip  = findMotor("Left Hip")
local rhip  = findMotor("Right Hip")
local rootj = findMotor("RootJoint")

local torso = (neck and neck.Part0) or (rootj and rootj.Part1)
local head  = neck and neck.Part1

-- The set of parts that must be DIRECT children of the character model.
local rigParts = {}
local function markRig(p) if p then rigParts[p] = true end end
markRig(hrp); markRig(torso); markRig(head)
markRig(lsh and lsh.Part1); markRig(rsh and rsh.Part1)
markRig(lhip and lhip.Part1); markRig(rhip and rhip.Part1)

-- Build the clean character.
local dressed = Instance.new("Model")
dressed.Name = "StarterCharacter"

-- Make sure the three name-critical parts are named exactly right (the Humanoid/Animate look these
-- up by name). Arm/leg names are left alone -- they animate through their joints.
if hrp   then hrp.Name = "HumanoidRootPart" end
if torso then torso.Name = "Torso" end
if head  then head.Name = "Head" end

-- Move the Humanoid + rig parts in first (their joints ride along as children).
hum.Parent = dressed
for p, _ in pairs(rigParts) do p.Parent = dressed end

-- ----------------------------------------------------------------------------
-- Fix the rig orientation (her auto-built rig faces backward + swings limbs sideways).
-- ----------------------------------------------------------------------------
-- Turn the whole body to face the way she runs. Rotating only the RootJoint's C0 spins the body.
if rootj and BODY_TURN ~= 0 then
	rootj.C0 = CFrame.Angles(0, math.rad(BODY_TURN), 0) * rootj.C0
end
-- Fold her arms in front by rotating each shoulder joint ABOUT THE SHOULDER, in the Torso's own
-- axes (so SWING/RAISE/TWIST mean the same thing no matter how her rig was built). Rotating through
-- the joint (not the bare part) keeps her welded kimono sleeves attached. The two arms are mirrored.
local function foldShoulder(m, side)
	if not m then return end
	local pivot = CFrame.new(m.C0.Position)   -- the shoulder attach point, in Torso space
	-- Step 1: swing the arm to the front (about Torso up) and raise/lower it (about Torso right).
	local swing = CFrame.Angles(math.rad(ARM_RAISE), math.rad(ARM_SWING * side), 0)
	m.C0 = pivot * swing * pivot:Inverse() * m.C0
	-- Step 2: roll the arm along its length (about Torso forward, which is ~the arm's axis now).
	local twist = CFrame.Angles(0, 0, math.rad(ARM_TWIST * side))
	m.C0 = pivot * twist * pivot:Inverse() * m.C0
end
foldShoulder(lsh, 1)
foldShoulder(rsh, -1)

-- Hide the bare arm blocks (the skin-colored parts that poke out when the arms fold). The red
-- kimono sleeves are welded over them, so those are all we want to see.
for _, m in ipairs({ lsh, rsh }) do
	if m and m.Part1 then m.Part1.Transparency = 1 end
end

-- FREEZE her arms + legs by renaming their joints, so Roblox's default walk animation can't find
-- them and therefore can't flap them -- the arms hold the fold, the legs stay straight. (The default
-- Animate logs a harmless "infinite yield" warning about the renamed joint; ignore it.) The Neck is
-- left named normally so our custom Animate can still sway it.
for _, m in ipairs({ lsh, rsh, lhip, rhip }) do
	if m then m.Name = m.Name .. " (held)" end
end

-- Float her off the ground. WASD still drives her; she just glides higher.
hum.HipHeight = hum.HipHeight + FLOAT_LIFT

-- Replace Roblox's default Animate script with our own (named "Animate" so Roblox won't add its
-- default). Ours plays NO walk/idle -- so her folded arms + straight legs just hold their pose --
-- and it gently sways her neck. This is the reliable way to run per-character behavior + it fixes
-- the "infinite yield on Right Shoulder" the default Animate threw when we used to rename joints.
local animateSource = [[
-- Rokurokubi's custom Animate: just sways her neck. (Her arms + legs are already frozen by the
-- renamed joints, so nothing else needs holding here.)
local RunService = game:GetService("RunService")
local SWAY_ANGLE = 15     -- how far her head leans side to side (degrees). Bigger = more. (Try 8-25.)
local SWAY_SPEED = 0.4    -- sways per second (slower = creepier)
local NOD_ANGLE  = 3      -- tiny forward/back nod (0 = none)
local NOD_SPEED  = 0.55
local char = script.Parent
local neck
for _, d in ipairs(char:GetDescendants()) do
	if d:IsA("Motor6D") and (d.Name == "Neck" or (d.Part1 and d.Part1.Name == "Head")) then neck = d break end
end
if not neck then warn("[Rokurokubi] neck joint not found; no sway.") return end
local baseC0 = neck.C0
local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock = clock + dt
	local sway = math.sin(clock * SWAY_SPEED * math.pi * 2) * math.rad(SWAY_ANGLE)
	local nod  = math.sin(clock * NOD_SPEED * math.pi * 2) * math.rad(NOD_ANGLE)
	-- Pre-multiply: rotate the head about the TORSO, so the long neck leans in a wide arc.
	neck.C0 = CFrame.Angles(nod, 0, sway) * baseC0
end)
]]
-- NOTE: this LocalScript must NOT be named "Animate" -- Roblox replaces any character script named
-- "Animate" with its own default, so ours would never run. "NeckSway" runs fine (it's a LocalScript
-- inside the character, like the default Animate, just a different name).
local animate = Instance.new("LocalScript")
animate.Name = "NeckSway"
local okSource = pcall(function() animate.Source = animateSource end)
animate.Parent = dressed
if not okSource then
	warn("Could not set the NeckSway script's code automatically -- open the 'NeckSway' LocalScript")
	warn("inside StarterCharacter and paste the sway code in by hand.")
end

-- Now flatten EVERYTHING else (costume, neck pieces, weapon, hair, eyes, decals) into the model so
-- it all clones/replicates together. Welds reference parts by object, so reparenting keeps them.
local RESERVED = { Head=true, Torso=true, HumanoidRootPart=true,
	["Left Arm"]=true, ["Right Arm"]=true, ["Left Leg"]=true, ["Right Leg"]=true }

local otherParts, joints = {}, {}
for _, d in ipairs(clone:GetDescendants()) do
	if d:IsA("BasePart") and not rigParts[d] then
		table.insert(otherParts, d)
	elseif d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("ManualWeld") or d:IsA("Motor6D") then
		table.insert(joints, d)
	end
end

-- Costume parts: rename any that clash with a reserved R6 name (e.g. the decorative second "Head"),
-- then move into the model.
for _, p in ipairs(otherParts) do
	if RESERVED[p.Name] then p.Name = p.Name .. " (decor)" end
	p.Parent = dressed
end
-- Rescue any welds that didn't already ride along with their part, so none get destroyed.
for _, j in ipairs(joints) do
	if not j:IsDescendantOf(dressed) then j.Parent = dressed end
end

-- Unanchor everything (her HRP was anchored) and set the PrimaryPart.
for _, d in ipairs(dressed:GetDescendants()) do
	if d:IsA("BasePart") then d.Anchored = false end
end
dressed.PrimaryPart = hrp

clone:Destroy()  -- only the empty nested husk is left; everything real moved into "dressed"

local old = StarterPlayer:FindFirstChild("StarterCharacter")
if old then old:Destroy() end
dressed.Parent = StarterPlayer

local partCount = 0
for _, d in ipairs(dressed:GetDescendants()) do if d:IsA("BasePart") then partCount = partCount + 1 end end
print(string.format("DONE. Flattened Rokurokubi into StarterCharacter: %d parts, Head=%s, HRP=%s.",
	partCount, tostring(head ~= nil), tostring(hrp ~= nil)))
print("Test > Server and Clients (2 players) to view. Watch her walk -- if arms/legs swing mirrored,")
print("that's the cross-named joints; tell me and I'll fix it. Delete StarterCharacter when done.")
