local Selection = game:GetService("Selection")
local StarterPlayer = game:GetService("StarterPlayer")

local FACE_YAW = -90

local source = Selection:Get()[1]
if not source then
	warn("Select Verity in the Explorer first.")
	return
end

local destParent = source.Parent
local destName = source.Name

local SKELETON_NAMES = {
	HumanoidRootPart = true, Torso = true, Head = true,
	["Left Arm"] = true, ["Right Arm"] = true,
	["Left Leg"] = true, ["Right Leg"] = true,
}

local clone = source:Clone()

local stripped = 0
for _, d in ipairs(clone:GetDescendants()) do
	local isOldSkeleton = d:IsA("BasePart") and SKELETON_NAMES[d.Name]
	if isOldSkeleton or d:IsA("Humanoid") or d:IsA("Motor6D") or d:IsA("WeldConstraint") then
		d:Destroy()
		stripped += 1
	end
end

local parts = {}
for _, d in ipairs(clone:GetDescendants()) do
	if d:IsA("BasePart") then table.insert(parts, d) end
end
if clone:IsA("BasePart") then table.insert(parts, clone) end

if #parts < 2 then
	warn(("Expected the ball and the crown, found %d part(s)."):format(#parts))
	clone:Destroy()
	return
end

local ball
for _, p in ipairs(parts) do
	if not ball or p.Size.Magnitude > ball.Size.Magnitude then ball = p end
end

local minV, maxV
for _, p in ipairs(parts) do
	local lo, hi = p.Position - p.Size / 2, p.Position + p.Size / 2
	minV = minV and minV:Min(lo) or lo
	maxV = maxV and maxV:Max(hi) or hi
end
local extents = maxV - minV
local footY = minV.Y
local centerX = (minV.X + maxV.X) / 2
local centerZ = (minV.Z + maxV.Z) / 2

local SCALE = extents.Y / 5

local dressed = Instance.new("Model")
dressed.Name = destName

local baseCF = CFrame.new(centerX, footY, centerZ)
	* CFrame.Angles(0, math.rad(FACE_YAW), 0)

local SKELETON = {
	{ name = "HumanoidRootPart", size = Vector3.new(2, 2, 1), x = 0,    y = 3   },
	{ name = "Torso",            size = Vector3.new(2, 2, 1), x = 0,    y = 3   },
	{ name = "Head",             size = Vector3.new(2, 1, 1), x = 0,    y = 4.5 },
	{ name = "Left Arm",         size = Vector3.new(1, 2, 1), x = -1.5, y = 3   },
	{ name = "Right Arm",        size = Vector3.new(1, 2, 1), x = 1.5,  y = 3   },
	{ name = "Left Leg",         size = Vector3.new(1, 2, 1), x = -0.5, y = 1   },
	{ name = "Right Leg",        size = Vector3.new(1, 2, 1), x = 0.5,  y = 1   },
}

local limbs = {}
for _, spec in ipairs(SKELETON) do
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Size = spec.size * SCALE
	part.Transparency = 1
	part.CanCollide = (spec.name ~= "HumanoidRootPart")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = baseCF * CFrame.new(spec.x * SCALE, spec.y * SCALE, 0)
	part.Parent = dressed
	limbs[spec.name] = part
end

limbs.Torso.Size = Vector3.new(ball.Size.X * 0.8, 2 * SCALE, ball.Size.Z * 0.8)
limbs.Torso.CFrame = baseCF * CFrame.new(0, 3 * SCALE, 0)

local function scalePos(cf, k)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(x * k, y * k, z * k, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

local JOINTS = {
	{ name = "RootJoint", part0 = "HumanoidRootPart", part1 = "Torso",
		C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		C1 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	{ name = "Neck", part0 = "Torso", part1 = "Head",
		C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		C1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	{ name = "Right Shoulder", part0 = "Torso", part1 = "Right Arm",
		C0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		C1 = CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	{ name = "Left Shoulder", part0 = "Torso", part1 = "Left Arm",
		C0 = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		C1 = CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	{ name = "Right Hip", part0 = "Torso", part1 = "Right Leg",
		C0 = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		C1 = CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	{ name = "Left Hip", part0 = "Torso", part1 = "Left Leg",
		C0 = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		C1 = CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
}

for _, j in ipairs(JOINTS) do
	local motor = Instance.new("Motor6D")
	motor.Name = j.name
	motor.Part0 = limbs[j.part0]
	motor.Part1 = limbs[j.part1]
	motor.C0 = scalePos(j.C0, SCALE)
	motor.C1 = scalePos(j.C1, SCALE)
	motor.Parent = (j.name == "RootJoint") and limbs.HumanoidRootPart or limbs.Torso
end

local report = {}
for _, p in ipairs(parts) do
	local limb = (p == ball) and limbs.Torso or limbs.Head
	p.Parent = dressed
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = p
	weld.Parent = p
	table.insert(report, ("   %-20s -> %s"):format(p.Name:sub(1, 20), limb.Name))
end

for _, d in ipairs(dressed:GetDescendants()) do
	if (d:IsA("Weld") or d:IsA("WeldConstraint")) and (d.Part0 == nil or d.Part1 == nil) then
		d:Destroy()
	end
	if d:IsA("BasePart") then d.Anchored = false end
end

local humanoid = Instance.new("Humanoid")
humanoid.RigType = Enum.HumanoidRigType.R6
humanoid.Parent = dressed

dressed.PrimaryPart = limbs.HumanoidRootPart
if clone.Parent ~= dressed then clone:Destroy() end

local stale = StarterPlayer:FindFirstChild("StarterCharacter")
if stale then stale:Destroy() end

source:Destroy()
dressed.Parent = destParent

print("==================================================")
print("VERITY DRESSED")
print("==================================================")
print(("Size: %.1f tall (%.2fx a standard R6 avatar)"):format(extents.Y, SCALE))
if stripped > 0 then
	print(("Stripped %d leftover(s) from a previous dressing pass."):format(stripped))
end
print(("Ball: %s   Face yaw: %d deg"):format(ball.Name, FACE_YAW))
print(("Collider widened to %.1f x %.1f to match the ball."):format(limbs.Torso.Size.X, limbs.Torso.Size.Z))
print(("Replaced in place: %s"):format(dressed:GetFullName()))
print("")
for _, line in ipairs(report) do print(line) end
print("")
print("Float is NOT set here -- Constants.Verity.FloatLift owns it, applied at spawn.")
print("Face pointing the wrong way: change FACE_YAW and re-run.")
