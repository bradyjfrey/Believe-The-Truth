-- READ-ONLY inspector. Changes nothing.
-- 1. Select the character's top folder/model in the Explorer (Survivor Momotaro).
-- 2. Copy this whole file, paste into the Command Bar, Enter.
-- 3. Copy the Output back to Brady.

local Selection = game:GetService("Selection")

local roots = Selection:Get()
if #roots == 0 then
	warn("Nothing selected.")
	return
end

for _, root in ipairs(roots) do
	-- path of a node relative to the selected root (so names are short + readable)
	local function relPath(node)
		local parts = {}
		local n = node
		while n and n ~= root.Parent do
			table.insert(parts, 1, n.Name)
			if n == root then break end
			n = n.Parent
		end
		return table.concat(parts, ".")
	end

	print("==================================================")
	print("TREE for: " .. root.Name .. " (" .. root.ClassName .. ")")
	print("==================================================")

	local function printTree(node, depth)
		local indent = string.rep("  ", depth)
		local extra = ""
		if node:IsA("BasePart") then
			extra = node.Anchored and "  [ANCHORED]" or ""
		end
		print(indent .. node.ClassName .. "  '" .. node.Name .. "'" .. extra)
		for _, child in ipairs(node:GetChildren()) do
			printTree(child, depth + 1)
		end
	end
	printTree(root, 0)

	print("--------------------------------------------------")
	print("JOINTS (Motor6D / Weld / WeldConstraint / Motor):")
	print("--------------------------------------------------")
	local jointCount = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("ManualWeld") or d:IsA("Motor") then
			jointCount = jointCount + 1
			local p0 = d.Part0 and relPath(d.Part0) or "nil"
			local p1 = d.Part1 and relPath(d.Part1) or "nil"
			print(d.ClassName .. " '" .. d.Name .. "':  " .. p0 .. "  ->  " .. p1)
		end
	end
	print("(total joints: " .. jointCount .. ")")

	print("--------------------------------------------------")
	print("RIG CHECK:")
	print("--------------------------------------------------")
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Humanoid") then
			print("Humanoid at: " .. relPath(d) .. "   RigType=" .. tostring(d.RigType))
			local m = d.Parent
			print("  -> its Model parent: " .. relPath(m) .. " (" .. m.ClassName .. ")")
			print("     PrimaryPart: " .. (m:IsA("Model") and m.PrimaryPart and m.PrimaryPart.Name or "<none>"))
		end
	end
	local hrpCount = 0
	local anchored = 0
	local totalParts = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			totalParts = totalParts + 1
			if d.Anchored then anchored = anchored + 1 end
			if d.Name == "HumanoidRootPart" then
				hrpCount = hrpCount + 1
				print("HumanoidRootPart at: " .. relPath(d) .. (d.Anchored and "  [ANCHORED]" or ""))
			end
		end
	end
	print("Total BaseParts: " .. totalParts .. "   Anchored: " .. anchored .. "   HumanoidRootParts: " .. hrpCount)
end
