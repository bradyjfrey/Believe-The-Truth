local Selection = game:GetService("Selection")

local FLOAT_LIFT = 0
local FACE_FLIP = false

local PREFIXES = { "Head_", "Torso_", "LeftArm_", "RightArm_", "LeftLeg_", "RightLeg_" }

local R6_LIMBS = { "HumanoidRootPart", "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local R15_LIMBS = {
	"HumanoidRootPart", "UpperTorso", "LowerTorso", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local HEAD_HINTS = { "hair", "face", "eye", "mask", "head", "horn", "crown" }
local TORSO_HINTS = { "shirt", "torso", "chest", "back", "pocket", "obi", "sash", "robe", "kimono", "skirt", "dress" }

local source = Selection:Get()[1]
if not source then
	warn("Select the character model in the Explorer first.")
	return
end

local destParent = source.Parent
local destName = source.Name

local function anyHint(name, hints)
	local lower = name:lower()
	for _, hint in ipairs(hints) do
		if lower:find(hint, 1, true) then return true end
	end
	return false
end

local function prefixOf(name)
	for _, prefix in ipairs(PREFIXES) do
		if name:sub(1, #prefix) == prefix then return prefix:sub(1, #prefix - 1) end
	end
	return nil
end

local clone = source:Clone()

local parts, humanoid = {}, nil
for _, d in ipairs(clone:GetDescendants()) do
	if d:IsA("BasePart") then
		table.insert(parts, d)
	elseif d:IsA("Humanoid") then
		humanoid = d
	end
end
if #parts == 0 then
	warn("No parts under " .. source:GetFullName())
	clone:Destroy()
	return
end

local function limbsPresent(names)
	local found = {}
	for _, name in ipairs(names) do
		local part = clone:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then found[name] = part end
	end
	return found
end

local r15 = limbsPresent(R15_LIMBS)
local r6 = limbsPresent(R6_LIMBS)
local r15Count, r6Count = 0, 0
for _ in pairs(r15) do r15Count += 1 end
for _ in pairs(r6) do r6Count += 1 end

local minV, maxV
for _, p in ipairs(parts) do
	local lo, hi = p.Position - p.Size / 2, p.Position + p.Size / 2
	minV = minV and Vector3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z)) or lo
	maxV = maxV and Vector3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z)) or hi
end
local extents = maxV - minV
local footY = minV.Y
local centerX = (minV.X + maxV.X) / 2
local centerZ = (minV.Z + maxV.Z) / 2

local dressed = Instance.new("Model")
dressed.Name = destName

local limbs, strategy = nil, nil
local weldReport = {}

if r15Count >= 12 then
	strategy = "R15 rig already built — welding the costume onto it"
	limbs = r15
elseif r6Count >= 6 then
	strategy = "R6 rig already built — welding the costume onto it"
	limbs = r6
else
	strategy = "no rig — building an invisible R6 skeleton and welding the costume onto it"
end

if limbs then
	if not humanoid then
		warn("Found rig parts but no Humanoid. Add a Humanoid to the model and run again.")
		clone:Destroy()
		return
	end

	humanoid.Parent = dressed
	for _, part in pairs(limbs) do
		part.Parent = dressed
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Motor6D") then
			d.Parent = (d.Name == "RootJoint" and limbs.HumanoidRootPart) or limbs[d.Part0 and d.Part0.Name] or dressed
		end
	end

	local limbList = {}
	for _, part in pairs(limbs) do table.insert(limbList, part) end

	local headLimb = limbs.Head
	local torsoLimb = limbs.UpperTorso or limbs.Torso

	local function nearestLimb(p)
		local best, bestDist
		for _, limb in ipairs(limbList) do
			if limb.Name ~= "HumanoidRootPart" then
				local d = (limb.Position - p.Position).Magnitude
				if not bestDist or d < bestDist then bestDist, best = d, limb end
			end
		end
		return best
	end

	local function targetFor(p)
		if anyHint(p.Name, HEAD_HINTS) and headLimb then return headLimb end
		if anyHint(p.Name, TORSO_HINTS) and torsoLimb then return torsoLimb end
		return nearestLimb(p)
	end

	for _, p in ipairs(parts) do
		if not limbs[p.Name] then
			local limb = targetFor(p)
			p.Parent = dressed
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = limb
			weld.Part1 = p
			weld.Parent = p
			table.insert(weldReport, ("   %-26s -> %s"):format(p.Name:sub(1, 26), limb.Name))
		end
	end

	for _, part in pairs(limbs) do
		part.Anchored = false
	end
else
	local problems = {}
	for _, p in ipairs(parts) do
		if not prefixOf(p.Name) then
			table.insert(problems, p.Name)
		end
	end
	if #problems > 0 then
		warn("NOT DRESSING. This model has no rig, so welding is driven by name prefixes")
		warn("(Head_, Torso_, LeftArm_, RightArm_, LeftLeg_, RightLeg_). These parts have none:")
		for _, name in ipairs(problems) do warn("   " .. name) end
		clone:Destroy()
		dressed:Destroy()
		return
	end

	local SCALE = extents.Y / 5

	local leftSum, leftCount = Vector3.zero, 0
	local rightSum, rightCount = Vector3.zero, 0
	for _, p in ipairs(parts) do
		local prefix = prefixOf(p.Name)
		if prefix == "LeftArm" or prefix == "LeftLeg" then
			leftSum, leftCount = leftSum + p.Position, leftCount + 1
		elseif prefix == "RightArm" or prefix == "RightLeg" then
			rightSum, rightCount = rightSum + p.Position, rightCount + 1
		end
	end
	if leftCount == 0 or rightCount == 0 then
		warn("Need at least one Left* and one Right* prefixed part to work out which way it faces.")
		clone:Destroy()
		dressed:Destroy()
		return
	end

	local leftMid, rightMid = leftSum / leftCount, rightSum / rightCount
	local sideAxis = (math.abs(leftMid.Z - rightMid.Z) > math.abs(leftMid.X - rightMid.X)) and "Z" or "X"
	local rightVec
	if sideAxis == "Z" then
		rightVec = Vector3.new(0, 0, (rightMid.Z > leftMid.Z) and 1 or -1)
	else
		rightVec = Vector3.new((rightMid.X > leftMid.X) and 1 or -1, 0, 0)
	end
	if FACE_FLIP then rightVec = -rightVec end

	local upVec = Vector3.new(0, 1, 0)
	local baseCF = CFrame.fromMatrix(Vector3.new(centerX, footY, centerZ), rightVec, upVec, rightVec:Cross(upVec))

	local SKELETON = {
		{ name = "HumanoidRootPart", size = Vector3.new(2, 2, 1), x = 0,    y = 3   },
		{ name = "Torso",            size = Vector3.new(2, 2, 1), x = 0,    y = 3   },
		{ name = "Head",             size = Vector3.new(2, 1, 1), x = 0,    y = 4.5 },
		{ name = "Left Arm",         size = Vector3.new(1, 2, 1), x = -1.5, y = 3   },
		{ name = "Right Arm",        size = Vector3.new(1, 2, 1), x = 1.5,  y = 3   },
		{ name = "Left Leg",         size = Vector3.new(1, 2, 1), x = -0.5, y = 1   },
		{ name = "Right Leg",        size = Vector3.new(1, 2, 1), x = 0.5,  y = 1   },
	}

	limbs = {}
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

	local function limbForPrefix(prefix)
		if prefix == "Head" then return limbs.Head end
		if prefix == "Torso" then return limbs.Torso end
		local isRight = (prefix == "RightArm" or prefix == "RightLeg")
		if FACE_FLIP then isRight = not isRight end
		local isLeg = (prefix == "LeftLeg" or prefix == "RightLeg")
		if isLeg then
			return isRight and limbs["Right Leg"] or limbs["Left Leg"]
		end
		return isRight and limbs["Right Arm"] or limbs["Left Arm"]
	end

	for _, p in ipairs(parts) do
		local limb = limbForPrefix(prefixOf(p.Name))
		p.Parent = dressed
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = limb
		weld.Part1 = p
		weld.Parent = p
		table.insert(weldReport, ("   %-26s -> %s"):format(p.Name:sub(1, 26), limb.Name))
	end

	humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = dressed
end

for _, d in ipairs(dressed:GetDescendants()) do
	if (d:IsA("Weld") or d:IsA("ManualWeld") or d:IsA("WeldConstraint")) and (d.Part0 == nil or d.Part1 == nil) then
		d:Destroy()
	end
	if d:IsA("BasePart") then d.Anchored = false end
end

if FLOAT_LIFT > 0 then
	humanoid.HipHeight = humanoid.HipHeight + FLOAT_LIFT
end

dressed.PrimaryPart = limbs.HumanoidRootPart
if clone.Parent ~= dressed then clone:Destroy() end

source:Destroy()
dressed.Parent = destParent

print("==================================================")
print("DRESSED: " .. destName)
print("==================================================")
print("Strategy: " .. strategy)
print(("Rig: %s   Size: %.1f studs tall (%.2fx a standard R6 avatar)")
	:format(tostring(humanoid.RigType):gsub("Enum.HumanoidRigType.", ""), extents.Y, extents.Y / 5))
if FLOAT_LIFT > 0 then print(("Float: HipHeight +%d"):format(FLOAT_LIFT)) end
print("")
print(("WELDS (%d costume parts):"):format(#weldReport))
for _, line in ipairs(weldReport) do print(line) end
print("")
print(("Replaced in place: %s"):format(dressed:GetFullName()))
print("")
print("Play to walk around. Anything welded to the wrong limb: select it + the right limb, use reweld.luau.")
print("Run inspect-character.luau on the model to check humanoid=y and hrp=y before trusting it.")
