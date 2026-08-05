local Selection = game:GetService("Selection")
local StarterPlayer = game:GetService("StarterPlayer")

local FACE_FLIP = false

local HEAD_HINTS = { "head", "eye", "tophat", "hat", "face" }

local SKELETON_NAMES = {
	HumanoidRootPart = true, Torso = true, Head = true,
	["Left Arm"] = true, ["Right Arm"] = true,
	["Left Leg"] = true, ["Right Leg"] = true,
}

local source = Selection:Get()[1]
if not source then
	warn("Select Bobzilla in the Explorer first.")
	return
end

local destParent = source.Parent
local destName = source.Name

local clone = source:Clone()

local stripped = 0
for _, d in ipairs(clone:GetDescendants()) do
	if d:GetAttribute("DressedSkeleton") or d:IsA("Humanoid") then
		d:Destroy()
		stripped += 1
	end
end

local renamed = 0
for _, d in ipairs(clone:GetDescendants()) do
	if d:IsA("BasePart") and SKELETON_NAMES[d.Name] then
		d.Name = d.Name .. "_mesh"
		renamed += 1
	end
end

local parts = {}
for _, d in ipairs(clone:GetDescendants()) do
	if d:IsA("BasePart") then table.insert(parts, d) end
end
if clone:IsA("BasePart") then table.insert(parts, clone) end

if #parts == 0 then
	warn("No parts found.")
	clone:Destroy()
	return
end

local minV, maxV
for _, p in ipairs(parts) do
	local lo, hi = p.Position - p.Size / 2, p.Position + p.Size / 2
	minV = minV and minV:Min(lo) or lo
	maxV = maxV and maxV:Max(hi) or hi
end
local extents = maxV - minV
local footY = minV.Y

local bulk, totalVolume = Vector3.zero, 0
local biggest
for _, p in ipairs(parts) do
	local v = p.Size.X * p.Size.Y * p.Size.Z
	bulk += p.Position * v
	totalVolume += v
	if not biggest or v > (biggest.Size.X * biggest.Size.Y * biggest.Size.Z) then
		biggest = p
	end
end
local bodyCenter = bulk / totalVolume

local headSum, headCount = Vector3.zero, 0
for _, p in ipairs(parts) do
	local lower = p.Name:lower()
	for _, hint in ipairs(HEAD_HINTS) do
		if lower:find(hint, 1, true) then
			headSum += p.Position
			headCount += 1
			break
		end
	end
end

local forward
if headCount > 0 then
	local headCenter = headSum / headCount
	local flat = Vector3.new(headCenter.X - bodyCenter.X, 0, headCenter.Z - bodyCenter.Z)
	forward = (flat.Magnitude > 0.01) and flat.Unit or Vector3.new(0, 0, -1)
else
	warn("No head-ish part names found; guessing forward. Set FACE_FLIP if he walks backwards.")
	forward = Vector3.new(0, 0, -1)
end
if FACE_FLIP then forward = -forward end

local SCALE = extents.Y / 5

local groundedCenter = Vector3.new(bodyCenter.X, footY, bodyCenter.Z)
local baseCF = CFrame.lookAt(groundedCenter, groundedCenter + forward)

local dressed = Instance.new("Model")
dressed.Name = destName

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
	part:SetAttribute("DressedSkeleton", true)
	part.Parent = dressed
	limbs[spec.name] = part
end

limbs.Torso.Size = biggest.Size
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

local welded = 0
for _, p in ipairs(parts) do
	p.Parent = dressed
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limbs.Torso
	weld.Part1 = p
	weld.Parent = p
	welded += 1
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
print("BOBZILLA DRESSED (rigid)")
print("==================================================")
print(("Size: %.1f tall, %.1f x %.1f footprint (%.2fx an R6 avatar)")
	:format(extents.Y, extents.X, extents.Z, SCALE))
if stripped > 0 then
	print(("Stripped %d leftover(s) from a previous pass."):format(stripped))
end
if renamed > 0 then
	print(("Renamed %d of his parts that clashed with skeleton names (added _mesh)."):format(renamed))
end
print(("Body centre (volume-weighted): %.1f, %.1f"):format(bodyCenter.X, bodyCenter.Z))
print(("Facing: %s   (from %d head-ish part name(s))"):format(tostring(forward), headCount))
print(("Collider: %s taken from '%s'"):format(tostring(biggest.Size), biggest.Name))
print(("Welded %d parts rigidly to the Torso."):format(welded))
print(("Replaced in place: %s"):format(dressed:GetFullName()))
print("")
print("He is ONE SOLID PIECE -- no leg or tail motion yet. Walk him around the map first;")
print("if he can't fit the lobby or corridors, that decides more than any animation would.")
print("Walks backwards? Set FACE_FLIP = true and re-run.")
