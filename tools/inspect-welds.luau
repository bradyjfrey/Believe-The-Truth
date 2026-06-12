-- READ-ONLY weld map. Changes nothing.
-- Select a dressed character model (e.g. StarterPlayer > StarterCharacter), paste into the
-- Command Bar, Run. Prints every part and which body part it's welded/jointed to, so we can
-- see what's riding the head vs the arms vs the torso.

local Selection = game:GetService("Selection")
local root = Selection:Get()[1]
if not root then warn("Select the dressed character model first.") return end

-- For each part, find what limb it is attached to (via WeldConstraint or Motor6D).
local function attachedTo(part)
	-- WeldConstraint child on this part points Part0 -> limb.
	for _, c in ipairs(part:GetChildren()) do
		if c:IsA("WeldConstraint") then
			local other = (c.Part1 == part) and c.Part0 or c.Part1
			if other then return other.Name .. "  (WeldConstraint)" end
		end
	end
	-- A Motor6D where this part is Part1 (limb is Part0).
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 == part then
			return (d.Part0 and d.Part0.Name or "?") .. "  (Motor6D '" .. d.Name .. "')"
		end
	end
	return "<not attached>"
end

print("==================================================")
print("WELD MAP for: " .. root.Name)
print("(part  ->  the limb it rides)")
print("==================================================")

local CORE = { HumanoidRootPart=true, Torso=true, Head=true,
	["Left Arm"]=true, ["Right Arm"]=true, ["Left Leg"]=true, ["Right Leg"]=true }

for _, p in ipairs(root:GetDescendants()) do
	if p:IsA("BasePart") and not CORE[p.Name] then
		-- show the part's own name + the model it lives in, then where it's attached
		local parentName = p.Parent and p.Parent.Name or "?"
		print(string.format("'%s'  (in '%s')   ->   %s", p.Name, parentName, attachedTo(p)))
	end
end
print("--------------------------------------------------")
print("(core body parts hidden; only costume/extra parts shown)")
