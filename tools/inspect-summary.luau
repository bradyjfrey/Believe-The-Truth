-- READ-ONLY compact survey of every character under the selection. Changes nothing.
-- 1. In the Explorer, select the containers you want surveyed. You can shift-select several:
--    ReplicatedStorage > CharacterModels, Companions, Skins, Weapons  (select all four).
-- 2. Copy this whole file into the Command Bar, Enter.
-- 3. Copy the Output back to Brady.
--
-- It prints ONE short block per rig (no giant tree), plus a line for weapon-like models
-- that have no Humanoid.

local Selection = game:GetService("Selection")
local roots = Selection:Get()
if #roots == 0 then warn("Nothing selected.") return end

-- the 6 standard R6 joints we expect: jointName, Part0 name, Part1 name
local R6 = {
	{"RootJoint",      "HumanoidRootPart", "Torso"},
	{"Neck",           "Torso",            "Head"},
	{"Left Shoulder",  "Torso",            "Left Arm"},
	{"Right Shoulder", "Torso",            "Right Arm"},
	{"Left Hip",       "Torso",            "Left Leg"},
	{"Right Hip",      "Torso",            "Right Leg"},
}

local function shortName(p) return p and p.Name or "nil" end

-- find a joint (Motor6D/Weld/etc) inside `rig` connecting two parts named a and b (either direction)
local function findJoint(rig, aName, bName)
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("ManualWeld") or d:IsA("Motor") then
			local n0 = d.Part0 and d.Part0.Name or nil
			local n1 = d.Part1 and d.Part1.Name or nil
			if (n0 == aName and n1 == bName) or (n0 == bName and n1 == aName) then
				return d
			end
		end
	end
	return nil
end

local function reportRig(humanoid)
	local rig = humanoid.Parent
	print("==================================================")
	print("RIG: " .. rig:GetFullName())
	print("  RigType=" .. tostring(humanoid.RigType)
		.. "   PrimaryPart=" .. (rig:IsA("Model") and rig.PrimaryPart and rig.PrimaryPart.Name or "<NONE>"))

	-- body part presence (direct search within rig)
	local present = {}
	for _, name in ipairs({"HumanoidRootPart","Torso","Head","Left Arm","Right Arm","Left Leg","Right Leg"}) do
		local p = rig:FindFirstChild(name, true)
		present[name] = p
	end
	local missing = {}
	for _, name in ipairs({"HumanoidRootPart","Torso","Head","Left Arm","Right Arm","Left Leg","Right Leg"}) do
		if not present[name] then table.insert(missing, name) end
	end
	print("  Body parts missing: " .. (#missing > 0 and table.concat(missing, ", ") or "none (full R6)"))

	-- standard joint check
	print("  Standard R6 joints:")
	for _, j in ipairs(R6) do
		local found = findJoint(rig, j[2], j[3])
		if found then
			local tag = found:IsA("Motor6D") and "Motor6D (animatable)" or (found.ClassName .. "  <-- STATIC, won't animate")
			print("    " .. j[1] .. ": " .. tag)
		else
			print("    " .. j[1] .. ": MISSING")
		end
	end

	-- joint + part census
	local motor, weld, nilTarget, parts, anchored = 0, 0, 0, 0, 0
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("Motor6D") then motor = motor + 1
		elseif d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("ManualWeld") or d:IsA("Motor") then
			weld = weld + 1
			if d:IsA("Weld") or d:IsA("ManualWeld") then
				if d.Part0 == nil or d.Part1 == nil then nilTarget = nilTarget + 1 end
			end
		end
		if d:IsA("BasePart") then
			parts = parts + 1
			if d.Anchored then anchored = anchored + 1 end
		end
	end
	print(string.format("  Census: %d parts, %d anchored, %d Motor6D, %d welds (%d with a nil target)",
		parts, anchored, motor, weld, nilTarget))
	-- rough costume estimate: parts beyond the ~6-7 rig parts that aren't joined
	print(string.format("  => ~%d non-rig parts; with only %d welds, most costume is NOT attached to the rig.",
		math.max(0, parts - 7), weld))
end

-- main: find every Humanoid under each selected root; also flag humanoid-less top models (weapons)
local seenRig = {}
for _, root in ipairs(roots) do
	local foundHumanoid = false
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Humanoid") and not seenRig[d] then
			seenRig[d] = true
			foundHumanoid = true
			reportRig(d)
		end
	end
	if root:IsA("Humanoid") then
		-- (selected the humanoid directly)
	end
	if not foundHumanoid then
		-- treat each direct child model as a weapon-like item
		print("==================================================")
		print("NO HUMANOID under: " .. root:GetFullName() .. "  (weapon/prop container?)")
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA("Model") or child:IsA("BasePart") then
				local parts, anchored, handle = 0, 0, false
				for _, d in ipairs(child:GetDescendants()) do
					if d:IsA("BasePart") then
						parts = parts + 1
						if d.Anchored then anchored = anchored + 1 end
						if d.Name == "Handle" then handle = true end
					end
				end
				if child:IsA("BasePart") then parts = parts + 1 end
				print(string.format("  '%s': %d parts, %d anchored, Handle=%s",
					child.Name, parts, anchored, tostring(handle)))
			end
		end
	end
end
print("==================================================")
print("END OF SURVEY")
