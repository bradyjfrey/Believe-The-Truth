local Selection = game:GetService("Selection")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PREFIXES = { "Head_", "Torso_", "LeftArm_", "RightArm_", "LeftLeg_", "RightLeg_" }

local R6_PARTS = { "HumanoidRootPart", "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local R15_PARTS = {
	"HumanoidRootPart", "UpperTorso", "LowerTorso", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local R6_JOINTS = {
	{ "RootJoint",      "HumanoidRootPart", "Torso" },
	{ "Neck",           "Torso",            "Head" },
	{ "Left Shoulder",  "Torso",            "Left Arm" },
	{ "Right Shoulder", "Torso",            "Right Arm" },
	{ "Left Hip",       "Torso",            "Left Leg" },
	{ "Right Hip",      "Torso",            "Right Leg" },
}

local roots = Selection:Get()
if #roots == 0 then
	warn("Select one or more models/folders in the Explorer first, then run this again.")
	return
end

local function prefixOf(name)
	for _, prefix in ipairs(PREFIXES) do
		if name:sub(1, #prefix) == prefix then return prefix:sub(1, #prefix - 1) end
	end
	return nil
end

local function findJoint(root, aName, bName)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("ManualWeld") or d:IsA("Motor") then
			local n0 = d.Part0 and d.Part0.Name
			local n1 = d.Part1 and d.Part1.Name
			if (n0 == aName and n1 == bName) or (n0 == bName and n1 == aName) then return d end
		end
	end
	return nil
end

local function countPresent(root, names)
	local found, missing = 0, {}
	for _, name in ipairs(names) do
		if root:FindFirstChild(name, true) then
			found += 1
		else
			table.insert(missing, name)
		end
	end
	return found, missing
end

print("==================================================")
print("SIZE REFERENCE — finished characters")
local characterModels = ReplicatedStorage:FindFirstChild("CharacterModels")
if characterModels then
	for _, m in ipairs(characterModels:GetChildren()) do
		if m:IsA("Model") then
			local size = m:GetExtentsSize()
			print(("   %-12s %5.1f studs tall  (%.1f x %.1f)"):format(m.Name, size.Y, size.X, size.Z))
		end
	end
else
	print("   (ReplicatedStorage.CharacterModels not found)")
end

local copyBlock = {}
local function copyLine(text)
	table.insert(copyBlock, text)
end

local function analyze(root)
	print("==================================================")
	print(("%s   (%s)"):format(root:GetFullName(), root.ClassName))

	local parts, joints, scripts = {}, {}, {}
	local humanoid, rootPart = nil, nil
	local connectedTo = {}

	local function link(a, b)
		if not (a and b) then return end
		connectedTo[a] = connectedTo[a] or {}
		connectedTo[b] = connectedTo[b] or {}
		table.insert(connectedTo[a], b)
		table.insert(connectedTo[b], a)
	end

	local scanList = root:GetDescendants()
	if root:IsA("BasePart") then table.insert(scanList, root) end

	for _, d in ipairs(scanList) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			if d.Name == "HumanoidRootPart" then rootPart = d end
		elseif d:IsA("WeldConstraint") or d:IsA("JointInstance") then
			table.insert(joints, d)
			link(d.Part0, d.Part1)
		elseif d:IsA("Humanoid") then
			humanoid = d
		elseif d:IsA("LuaSourceContainer") then
			table.insert(scripts, d)
		end
	end

	if #parts == 0 then
		warn("   no parts at all inside this — wrong thing selected?")
		return
	end

	local minV, maxV
	local anchored, massless = 0, 0
	local motors, welds, deadWelds = 0, 0, 0
	for _, p in ipairs(parts) do
		local lo, hi = p.Position - p.Size / 2, p.Position + p.Size / 2
		minV = minV and Vector3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z)) or lo
		maxV = maxV and Vector3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z)) or hi
		if p.Anchored then anchored += 1 end
		if p.Massless then massless += 1 end
	end
	for _, j in ipairs(joints) do
		if j:IsA("Motor6D") then motors += 1 else welds += 1 end
		if j.Part0 == nil or j.Part1 == nil then deadWelds += 1 end
	end

	local extents = maxV - minV
	local footY = minV.Y
	local centerX = (minV.X + maxV.X) / 2
	local centerZ = (minV.Z + maxV.Z) / 2

	local r6Found, r6Missing = countPresent(root, R6_PARTS)
	local r15Found = countPresent(root, R15_PARTS)

	print(("   Humanoid: %s%s   HumanoidRootPart: %s   PrimaryPart: %s")
		:format(
			humanoid and "yes" or "NO",
			humanoid and ("  RigType=" .. tostring(humanoid.RigType)) or "",
			rootPart and "yes" or "NO",
			(root:IsA("Model") and root.PrimaryPart) and root.PrimaryPart.Name or "<none>"
		))
	print(("   Parts: %d   Anchored: %d   Massless: %d   Motor6D: %d   Welds: %d (%d dead)")
		:format(#parts, anchored, massless, motors, welds, deadWelds))
	print(("   Size: %.1f tall  (%.1f x %.1f)   = %.2fx a standard 5-stud R6 avatar")
		:format(extents.Y, extents.X, extents.Z, extents.Y / 5))

	if r15Found > r6Found then
		print(("   RIG SHAPE: looks R15 (%d/%d R15 part names present, only %d/%d R6)")
			:format(r15Found, #R15_PARTS, r6Found, #R6_PARTS))
		print("   ⚠️ Everything in this project is R6. R15 needs its own dressing + swing code.")
	elseif r6Found > 0 then
		print(("   RIG SHAPE: R6 body parts present %d/%d   missing: %s")
			:format(r6Found, #R6_PARTS, #r6Missing > 0 and table.concat(r6Missing, ", ") or "none"))
		print("   Standard R6 joints:")
		for _, j in ipairs(R6_JOINTS) do
			local found = findJoint(root, j[2], j[3])
			local tag = "MISSING"
			if found then
				tag = found:IsA("Motor6D") and "Motor6D (animatable)" or (found.ClassName .. "  <-- STATIC, won't animate")
			end
			print(("      %-16s %s"):format(j[1], tag))
		end
	else
		print("   RIG SHAPE: no standard body parts at all — costume meshes only.")
		print("   Dressing builds an invisible skeleton underneath (see dress-okiku.luau).")
	end

	local prefixed, unprefixed = 0, {}
	for _, p in ipairs(parts) do
		if prefixOf(p.Name) then
			prefixed += 1
		else
			table.insert(unprefixed, p.Name)
		end
	end
	if prefixed > 0 then
		print(("   PREFIX SCHEME: %d/%d parts named Head_/Torso_/LeftArm_/RightArm_/LeftLeg_/RightLeg_")
			:format(prefixed, #parts))
		if #unprefixed > 0 then
			print(("      not prefixed: %s"):format(table.concat(unprefixed, ", ")))
		end
	end

	if #scripts > 0 then
		for _, s in ipairs(scripts) do
			warn("   ⚠️ script inside: " .. s:GetFullName() .. "  — delete unless we put it there")
		end
	else
		print("   Scripts inside: none ✅")
	end

	local core = rootPart or (root:IsA("Model") and root.PrimaryPart)
	if not core then
		local biggest, biggestVolume = nil, 0
		for _, p in ipairs(parts) do
			local v = p.Size.X * p.Size.Y * p.Size.Z
			if v > biggestVolume then biggest, biggestVolume = p, v end
		end
		core = biggest
	end
	local reached, queue = { [core] = true }, { core }
	while #queue > 0 do
		local p = table.remove(queue)
		for _, other in ipairs(connectedTo[p] or {}) do
			if not reached[other] then
				reached[other] = true
				table.insert(queue, other)
			end
		end
	end
	local loose = {}
	for _, p in ipairs(parts) do
		if not reached[p] then table.insert(loose, p) end
	end
	if #loose == 0 then
		print(("   HOLDS TOGETHER: ✅ every part connects to '%s'"):format(core.Name))
	else
		print(("   HOLDS TOGETHER: %d of %d part(s) NOT connected to '%s' (fine while anchored on display)")
			:format(#loose, #parts, core.Name))
	end

	local leftSum, leftCount = Vector3.zero, 0
	local rightSum, rightCount = Vector3.zero, 0
	for _, p in ipairs(parts) do
		local lower = p.Name:lower()
		if lower:find("left", 1, true) then
			leftSum, leftCount = leftSum + p.Position, leftCount + 1
		elseif lower:find("right", 1, true) then
			rightSum, rightCount = rightSum + p.Position, rightCount + 1
		end
	end

	local sideAxis, axisReason
	if leftCount > 0 and rightCount > 0 then
		local leftMid, rightMid = leftSum / leftCount, rightSum / rightCount
		local gapX = math.abs(leftMid.X - rightMid.X)
		local gapZ = math.abs(leftMid.Z - rightMid.Z)
		sideAxis = (gapZ > gapX) and "Z" or "X"
		axisReason = ("left-named vs right-named parts are %.1f apart on X, %.1f on Z"):format(gapX, gapZ)
	else
		sideAxis = (extents.Z > extents.X) and "Z" or "X"
		axisReason = ("no left/right named parts; using the wider footprint (X=%.1f, Z=%.1f)")
			:format(extents.X, extents.Z)
	end

	local function sideOffset(p)
		if sideAxis == "Z" then return p.Position.Z - centerZ end
		return p.Position.X - centerX
	end
	local function depthOffset(p)
		if sideAxis == "Z" then return p.Position.X - centerX end
		return p.Position.Z - centerZ
	end

	print(("   SIDE AXIS: %s   (%s)"):format(sideAxis, axisReason))

	table.sort(parts, function(a, b) return a.Position.Y > b.Position.Y end)
	local labelFor, total, running = {}, {}, {}
	for _, p in ipairs(parts) do total[p.Name] = (total[p.Name] or 0) + 1 end
	for _, p in ipairs(parts) do
		if total[p.Name] > 1 then
			running[p.Name] = (running[p.Name] or 0) + 1
			labelFor[p] = ("%s #%d"):format(p.Name, running[p.Name])
		else
			labelFor[p] = p.Name
		end
	end

	print("")
	print("   PARTS, tallest first. BOT/TOP = studs above the lowest point (BOT ~0 reaches the floor).")
	print(("   %-26s %-16s %6s %6s %7s %7s"):format("PART", "SIZE (X,Y,Z)", "BOT", "TOP", "SIDE", "DEPTH"))
	for _, p in ipairs(parts) do
		print(("   %-26s %-16s %6.1f %6.1f %7.1f %7.1f"):format(
			labelFor[p]:sub(1, 26),
			("%.1f,%.1f,%.1f"):format(p.Size.X, p.Size.Y, p.Size.Z),
			(p.Position.Y - p.Size.Y / 2) - footY,
			(p.Position.Y + p.Size.Y / 2) - footY,
			sideOffset(p),
			depthOffset(p)
		))
	end

	print("")
	print("   LIKELY LEFT/RIGHT PAIRS (similar size + height, meaningfully apart on the side axis):")
	local pairsFound = 0
	for i = 1, #parts do
		for j = i + 1, #parts do
			local a, b = parts[i], parts[j]
			local sameHeight = math.abs(a.Position.Y - b.Position.Y) < math.max(a.Size.Y, b.Size.Y) * 0.25
			local sameSize = (a.Size - b.Size).Magnitude < math.max(a.Size.Magnitude, b.Size.Magnitude) * 0.35
			local apart = math.abs(sideOffset(a) - sideOffset(b)) > extents.X * 0.1
			local opposite = (sideOffset(a) * sideOffset(b)) < 0
			if sameHeight and sameSize and opposite and apart then
				pairsFound += 1
				print(("      %-20s (%+.1f)  <->  %-20s (%+.1f)")
					:format(labelFor[a], sideOffset(a), labelFor[b], sideOffset(b)))
			end
		end
	end
	if pairsFound == 0 then
		print("      none — nothing symmetric enough to call a pair.")
	end

	copyLine(("=== %s | %s"):format(root:GetFullName(), root.ClassName))
	copyLine(("humanoid=%s rig=%s hrp=%s parts=%d anchored=%d motors=%d welds=%d dead=%d loose=%d scripts=%d")
		:format(
			humanoid and "y" or "n",
			humanoid and tostring(humanoid.RigType):gsub("Enum.HumanoidRigType.", "") or "-",
			rootPart and "y" or "n",
			#parts, anchored, motors, welds, deadWelds, #loose, #scripts
		))
	copyLine(("height=%.1f scale=%.2f sideaxis=%s r6parts=%d/%d r15parts=%d/%d prefixed=%d/%d")
		:format(extents.Y, extents.Y / 5, sideAxis, r6Found, #R6_PARTS, r15Found, #R15_PARTS, prefixed, #parts))
	for _, p in ipairs(parts) do
		copyLine(("%s | %.1f,%.1f,%.1f | bot=%.1f | top=%.1f | side=%+.1f | depth=%+.1f | anch=%s")
			:format(
				labelFor[p],
				p.Size.X, p.Size.Y, p.Size.Z,
				(p.Position.Y - p.Size.Y / 2) - footY,
				(p.Position.Y + p.Size.Y / 2) - footY,
				sideOffset(p),
				depthOffset(p),
				tostring(p.Anchored)
			))
	end
end

for _, root in ipairs(roots) do
	analyze(root)
end

print("")
print("========== COPY FROM HERE ==========")
for _, line in ipairs(copyBlock) do print(line) end
print("========== COPY TO HERE ==========")
