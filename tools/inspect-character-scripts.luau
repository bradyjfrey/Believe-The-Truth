-- READ-ONLY. Changes nothing. Lists every Script / LocalScript / ModuleScript hiding inside each
-- dressed character model in ReplicatedStorage.CharacterModels. We're hunting a leftover bundled
-- script (from a free asset) inside Momotaro that the others don't have -- the likely cause of the
-- delayed brown block AND the jump not firing. Paste into the Command Bar, Enter; copy Output back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local models = ReplicatedStorage:FindFirstChild("CharacterModels")
if not models then warn("No ReplicatedStorage.CharacterModels found.") return end

for _, model in ipairs(models:GetChildren()) do
	local found = {}
	for _, d in ipairs(model:GetDescendants()) do
		-- LuaSourceContainer = Script, LocalScript, or ModuleScript.
		if d:IsA("LuaSourceContainer") then
			local enabled = ""
			if d:IsA("BaseScript") then enabled = d.Enabled and "  (Enabled)" or "  (Disabled)" end
			table.insert(found, ("   %s '%s'%s  —  %s"):format(d.ClassName, d.Name, enabled, d:GetFullName()))
		end
	end
	print(("== %s : %d script(s) =="):format(model.Name, #found))
	for _, line in ipairs(found) do print(line) end
end
