-- READ-ONLY. Changes nothing.
-- Tells us if Otohime's 6 body parts are standard R6 size + spacing, which decides whether we
-- can reuse them (just add the missing skeleton) or need to drop in a fresh standard R6 rig.
--
-- HOW: select the "Otohime" folder in the Explorer, paste into the Command Bar, Enter.
-- Copy the Output back to Brady.

local Selection = game:GetService("Selection")
local root = Selection:Get()[1]
if not root then warn("Select the Otohime folder first.") return end

-- Find the R6 body (the model with the Humanoid).
local hum
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("Humanoid") then hum = d break end
end
if not hum then warn("No Humanoid found.") return end
local rig = hum.Parent

-- Standard R6 sizes for reference.
local STD = {
	["Head"]      = Vector3.new(2, 1, 1),
	["Torso"]     = Vector3.new(2, 2, 1),
	["Left Arm"]  = Vector3.new(1, 2, 1),
	["Right Arm"] = Vector3.new(1, 2, 1),
	["Left Leg"]  = Vector3.new(1, 2, 1),
	["Right Leg"] = Vector3.new(1, 2, 1),
}

-- Where each part SHOULD sit relative to the Torso center in a standard R6 rig.
local STD_OFFSET = {
	["Head"]      = Vector3.new(0, 1.5, 0),
	["Left Arm"]  = Vector3.new(-1.5, 0, 0),
	["Right Arm"] = Vector3.new(1.5, 0, 0),
	["Left Leg"]  = Vector3.new(-0.5, -2, 0),
	["Right Leg"] = Vector3.new(0.5, -2, 0),
}

local torso = rig:FindFirstChild("Torso")
if not torso then warn("No Torso found in the rig.") return end

local function fmt(v) return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z) end

print("============ OTOHIME BODY-PART SIZES / SPACING ============")
print("Torso position (world): " .. fmt(torso.Position) .. "   Anchored=" .. tostring(torso.Anchored))
print("-----------------------------------------------------------")

for _, name in ipairs({"Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg"}) do
	local p = rig:FindFirstChild(name)
	if not p then
		print(name .. ": *** MISSING ***")
	else
		local sizeOK = STD[name] and (p.Size - STD[name]).Magnitude < 0.05
		local line = string.format("%-10s size=%s  %s", name, fmt(p.Size),
			sizeOK and "[standard]" or ("[NON-STANDARD, expected " .. fmt(STD[name]) .. "]"))
		print(line)
		if name ~= "Torso" and STD_OFFSET[name] then
			local rel = torso.CFrame:PointToObjectSpace(p.Position)
			local offOK = (rel - STD_OFFSET[name]).Magnitude < 0.25
			print(string.format("           offset-from-Torso=%s  %s", fmt(rel),
				offOK and "[standard spot]" or ("[OFF, expected " .. fmt(STD_OFFSET[name]) .. "]")))
		end
	end
end
print("===========================================================")
