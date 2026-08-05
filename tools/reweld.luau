-- RE-WELD clothing to a body part.
-- 1. Change TARGET below to "Left Arm", "Right Arm", "Left Leg", etc.
-- 2. In Studio, select the clothing part(s).
-- 3. Copy this whole file, paste into the Command Bar, press Enter.

local TARGET = "Torso"

local Selection = game:GetService("Selection")

local function findRig(node)
	while node do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local selected = Selection:Get()
if #selected == 0 then
	warn("Nothing selected. Select the part (or the model holding it) and run again.")
	return
end

local targets = {}
for _, item in ipairs(selected) do
	if item:IsA("BasePart") then
		table.insert(targets, item)
	else
		for _, d in ipairs(item:GetDescendants()) do
			if d:IsA("BasePart") then table.insert(targets, d) end
		end
	end
end

if #targets == 0 then
	warn("No BaseParts found in the selection.")
	return
end

for _, part in ipairs(targets) do
	if part:IsA("BasePart") then
		local rig = findRig(part)
		local target = rig and rig:FindFirstChild(TARGET, true)
		if target then
			local cleared = 0
			for _, w in ipairs(rig:GetDescendants()) do
				if w:IsA("WeldConstraint") or w:IsA("Weld") then
					if w.Part0 == part or w.Part1 == part then
						w:Destroy()
						cleared += 1
					end
				end
			end
			local nw = Instance.new("WeldConstraint")
			nw.Part0 = target
			nw.Part1 = part
			nw.Parent = target
			part.Anchored = false
			print(("Re-welded %s to %s (cleared %d old weld(s))"):format(part.Name, TARGET, cleared))
		else
			warn("Could not find " .. TARGET)
		end
	end
end
