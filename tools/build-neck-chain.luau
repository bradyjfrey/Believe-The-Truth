-- BUILD ROKUROKUBI'S SEGMENTED NECK CHAIN.  (Run ONCE.)
-- 1. Select the "NeckChain" folder in the Explorer.
-- 2. Paste this into the Command Bar, Run.
-- It links Torso -> neck 1 -> neck 2 -> ... -> neck 12 -> Head with Motor6D joints, each hinged at
-- the junction between two segments. Then run "preview-neck-wave" to animate it.

local Selection = game:GetService("Selection")
local folder = Selection:Get()[1]
if not folder or not folder:IsA("Folder") then warn("Select the NeckChain folder first.") return end

-- Find the character (the model that holds a Humanoid) above the folder.
local char = folder.Parent
while char and not char:FindFirstChildOfClass("Humanoid") do char = char.Parent end
if not char then warn("No character (Humanoid) found above NeckChain.") return end

local torso = char:FindFirstChild("Torso", true)
local head = char:FindFirstChild("Head", true)
if not (torso and head) then warn("Torso or Head not found in the character.") return end

-- Sort the segments by their number (neck 1 .. neck 12).
local segs = {}
for _, p in ipairs(folder:GetChildren()) do
	if p:IsA("BasePart") then
		local n = tonumber(p.Name:match("%d+"))
		if n then segs[n] = p end
	end
end
local ordered = {}
local i = 1
while segs[i] do table.insert(ordered, segs[i]); i = i + 1 end
if #ordered == 0 then warn("No numbered neck segments found in the folder.") return end

-- Remove the old single Torso->Head neck joint, and any chain joints from a previous run.
for _, d in ipairs(char:GetDescendants()) do
	if d:IsA("Motor6D") and (d.Name:match("^NeckJoint") or (d.Part0 == torso and d.Part1 == head)) then
		d:Destroy()
	end
end

-- The chain, base to tip: Torso, neck1 .. neckN, Head.
local chain = { torso }
for _, s in ipairs(ordered) do table.insert(chain, s) end
table.insert(chain, head)

-- Anchor the base so she stays put while we preview; unanchor the moving neck + head.
local hrp = char:FindFirstChild("HumanoidRootPart", true)
if hrp then hrp.Anchored = true end
torso.Anchored = true
for _, s in ipairs(ordered) do s.Anchored = false end
head.Anchored = false

-- Build a Motor6D between each pair, hinged at the midpoint (the junction) so they bend there.
local made = 0
for idx = 1, #chain - 1 do
	local a, b = chain[idx], chain[idx + 1]
	local pivot = a.CFrame:Lerp(b.CFrame, 0.5)
	local m = Instance.new("Motor6D")
	m.Name = "NeckJoint" .. idx
	m.Part0 = a
	m.Part1 = b
	m.C0 = a.CFrame:ToObjectSpace(pivot)
	m.C1 = b.CFrame:ToObjectSpace(pivot)
	m.Parent = b
	made = made + 1
end

print("Built " .. made .. " neck joints (Torso -> " .. #ordered .. " segments -> Head). Now run preview-neck-wave.")
