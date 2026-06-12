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

for _, part in ipairs(Selection:Get()) do
	if part:IsA("BasePart") then
		local rig = findRig(part)
		local target = rig and rig:FindFirstChild(TARGET, true)
		if target then
			for _, w in ipairs(rig:GetDescendants()) do
				if w:IsA("WeldConstraint") or w:IsA("ManualWeld") then
					if w.Part0 == part or w.Part1 == part then
						w:Destroy()
					end
				end
			end
			local nw = Instance.new("WeldConstraint")
			nw.Part0 = target
			nw.Part1 = part
			nw.Parent = target
			part.Anchored = false
			print("Re-welded " .. part.Name .. " to " .. TARGET)
		else
			warn("Could not find " .. TARGET)
		end
	end
end
