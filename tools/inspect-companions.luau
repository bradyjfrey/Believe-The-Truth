-- READ-ONLY. Changes nothing. Tells us what's in ReplicatedStorage.Companions so we can wire the
-- Hawk into Momotaro's spawn precisely. Paste into the Command Bar (no selection needed), Enter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local folder = ReplicatedStorage:FindFirstChild("Companions")
if not folder then warn("No ReplicatedStorage.Companions folder found.") return end

print("============ ReplicatedStorage.Companions ============")
for _, child in ipairs(folder:GetChildren()) do
	print(("- %s  (%s)"):format(child.Name, child.ClassName))

	-- For each companion model, report the bits the bird script needs.
	local parts, anchored = 0, 0
	local hasScript, hasAnimator = false, false
	local primary = (child:IsA("Model") and child.PrimaryPart) and child.PrimaryPart.Name or "<none>"
	local boneNames = {}
	for _, d in ipairs(child:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			if d.Anchored then anchored += 1 end
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			hasScript = true
		elseif d:IsA("Animator") then
			hasAnimator = true
		elseif d:IsA("Bone") then
			if #boneNames < 12 then table.insert(boneNames, d.Name) end
		end
	end
	print(("    PrimaryPart=%s  parts=%d (anchored %d)  Script=%s  Animator=%s")
		:format(primary, parts, anchored, tostring(hasScript), tostring(hasAnimator)))
	if #boneNames > 0 then
		print("    Bones: " .. table.concat(boneNames, ", "))
	end
end
print("======================================================")
