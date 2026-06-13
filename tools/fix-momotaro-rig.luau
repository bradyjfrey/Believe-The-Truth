-- FIX MOMOTARO'S RIG NAMING.  (Run ONCE. Just renames -- reversible.)
--
-- His model HAS all the R6 joints, but two naming defects make the default Animate hang at spawn on
-- Torso:WaitForChild("Right Shoulder") so he never animates:
--   1. the root joint (HumanoidRootPart -> Torso) is named "Root Hip" instead of the required "RootJoint"
--   2. a costume MeshPart is ALSO named "Torso", colliding with the real rig Torso
-- This renames the root joint to "RootJoint" and any extra "Torso" to "TorsoMesh".
--
-- HOW: select ReplicatedStorage.CharacterModels.Momotaro (the MODEL), paste into the Command Bar, Run.

local Selection = game:GetService("Selection")

local char = Selection:Get()[1]
if not char or not char:FindFirstChildOfClass("Humanoid") then
	warn("Select the Momotaro MODEL (the one with a Humanoid) first.")
	return
end

local hrp = char:FindFirstChild("HumanoidRootPart", true)

-- 1. The root joint is the Motor6D whose Part0 is the HumanoidRootPart. Rename it to "RootJoint".
local rootJoint
for _, d in ipairs(char:GetDescendants()) do
	if d:IsA("Motor6D") and d.Part0 == hrp then
		rootJoint = d
		break
	end
end
if rootJoint then
	print(("root joint was '%s' (HRP -> %s) -> renaming to 'RootJoint'"):format(
		rootJoint.Name, rootJoint.Part1 and rootJoint.Part1.Name or "?"))
	rootJoint.Name = "RootJoint"
else
	warn("Couldn't find a Motor6D with Part0 = HumanoidRootPart.")
end

-- 2. The real rig Torso is whatever the root joint connects to. Rename any OTHER part named "Torso".
local rigTorso = rootJoint and rootJoint.Part1
local renamed = 0
for _, d in ipairs(char:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "Torso" and d ~= rigTorso then
		d.Name = "TorsoMesh"
		renamed += 1
	end
end
print(("renamed %d duplicate 'Torso' costume part(s) to 'TorsoMesh'"):format(renamed))

print("Done. Play as Momotaro -- he should animate now. (If not, we check whether the joints survive the spawn.)")
