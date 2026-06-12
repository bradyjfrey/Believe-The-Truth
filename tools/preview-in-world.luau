-- Drops a VISIBLE copy of StarterCharacter into the world so you can look at it and click parts,
-- then highlights the head mask. Does NOT touch your real StarterCharacter or any master model.
-- Select StarterPlayer > StarterCharacter first, paste into the Command Bar, Run.
-- When you're done looking, just delete "MomotaroPreview" from the Workspace.

local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

local src = Selection:Get()[1]
if not src then warn("Select StarterCharacter first.") return end

-- Remove an old preview if it's still around.
local old = Workspace:FindFirstChild("MomotaroPreview")
if old then old:Destroy() end

local preview = src:Clone()
preview.Name = "MomotaroPreview"
preview.Parent = Workspace

-- Stand it up at a visible spot and anchor it so it can't fall or wander.
local hrp = preview:FindFirstChild("HumanoidRootPart")
if hrp then
	preview:PivotTo(CFrame.new(0, 10, 0))
end
for _, d in ipairs(preview:GetDescendants()) do
	if d:IsA("BasePart") then d.Anchored = true end
end

-- Highlight the head mask so you can see exactly which mesh it is.
local mask
for _, d in ipairs(preview:GetDescendants()) do
	if d:IsA("BasePart") and string.find(string.lower(d.Name), "mask") then mask = d break end
end
if mask then
	Selection:Set({mask})
	print("Highlighted the head MASK: '" .. mask.Name .. "'")
	print(">> Is the highlighted mesh the BEIGE face, or the BROWN spiky hair?")
else
	print("Could not find a mask part by name.")
end
print("A visible copy is now in Workspace as 'MomotaroPreview' (camera-find it near 0,10,0).")
print("Rotate around it and click the brown hair if you want to identify it, then tell me its name.")
print("Delete 'MomotaroPreview' from Workspace when done.")
