-- READ-ONLY (only changes your Explorer selection). Finds the parts welded to the ARMS that are
-- NOT the main robe sleeves (Arm1/Arm2) or the Handle, then SELECTS them so they light up in the
-- viewport. Use it to confirm whether those extra arm pieces are actually the hair.
-- Select StarterPlayer > StarterCharacter first, paste into the Command Bar, Run.

local Selection = game:GetService("Selection")
local root = Selection:Get()[1]
if not root then warn("Select StarterCharacter first.") return end

local KEEP_ON_ARM = { Arm1=true, Arm2=true, Handle=true }

local hrp = root:FindFirstChild("HumanoidRootPart")
local suspects = {}
for _, p in ipairs(root:GetDescendants()) do
	if p:IsA("BasePart") and not KEEP_ON_ARM[p.Name] then
		for _, c in ipairs(p:GetChildren()) do
			if c:IsA("WeldConstraint") then
				local limb = (c.Part0 and c.Part0.Name) or (c.Part1 and c.Part1.Name)
				if limb == "Left Arm" or limb == "Right Arm" then
					table.insert(suspects, {part = p, limb = limb})
				end
			end
		end
	end
end

print("==================================================")
print("Extra parts riding the ARMS (not sleeves/handle): " .. #suspects)
print("==================================================")
local toSelect = {}
for _, s in ipairs(suspects) do
	local p = s.part
	local relY = hrp and (p.Position.Y - hrp.Position.Y) or 0
	print(string.format("'%s'  on %s   size=%.1f,%.1f,%.1f   height above root=%.1f studs   mesh=%s",
		p.Name, s.limb, p.Size.X, p.Size.Y, p.Size.Z, relY,
		(p:FindFirstChildWhichIsA("SpecialMesh") and "SpecialMesh") or
		(p:IsA("MeshPart") and "MeshPart") or "plain"))
	table.insert(toSelect, p)
end
Selection:Set(toSelect)
print("--------------------------------------------------")
print("^ These parts are now SELECTED (highlighted). Are they the hair?")
