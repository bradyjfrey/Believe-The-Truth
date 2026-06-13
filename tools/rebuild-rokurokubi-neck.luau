-- REBUILD ROKUROKUBI'S NECK JOINTS, IN PLACE.  (Run ONCE.)
--
-- WHY: the Rokurokubi model in ReplicatedStorage.CharacterModels has the neck SEGMENTS
-- (neck 1 .. neck 12) but lost the Motor6D joints that connect + drive them, so NeckWave finds
-- 0 joints and her neck stays stiff. This rebuilds NeckJoint1..N+1 (Torso -> segments -> Head),
-- hinged at each junction, then makes sure she's left spawn-ready (unanchored; neck + head massless
-- and non-colliding so the long neck doesn't unbalance her). It does NOT rename or move her.
--
-- HOW: in the Explorer, select ReplicatedStorage.CharacterModels.Rokurokubi (the MODEL), paste this
-- into the Command Bar, and Run. Then play as Rokurokubi -- the neck should wave.

local Selection = game:GetService("Selection")

local char = Selection:Get()[1]
if not char or not char:FindFirstChildOfClass("Humanoid") then
	warn("Select the Rokurokubi MODEL (the one with a Humanoid) first.")
	return
end

local folder = char:FindFirstChild("NeckChain", true)
if not folder then warn("No 'NeckChain' folder inside the model.") return end

local torso = char:FindFirstChild("Torso", true)
local head = char:FindFirstChild("Head", true)
local hrp = char:FindFirstChild("HumanoidRootPart", true)
if not (torso and head) then warn("Torso or Head not found.") return end

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
if #ordered == 0 then warn("No numbered neck segments found in NeckChain.") return end

-- Remove any old neck joints (a single Torso->Head Neck, or NeckJoints from a previous run).
for _, d in ipairs(char:GetDescendants()) do
	if d:IsA("Motor6D") and (d.Name:match("^NeckJoint") or (d.Part0 == torso and d.Part1 == head)) then
		d:Destroy()
	end
end

-- Build a Motor6D between each pair in the chain Torso -> neck1 .. neckN -> Head, hinged at the
-- midpoint between the two parts so the bend happens at the junction.
local chain = { torso }
for _, s in ipairs(ordered) do table.insert(chain, s) end
table.insert(chain, head)

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

-- Leave her spawn-ready: nothing anchored (the Humanoid drives her), and the neck + head are
-- massless + non-colliding so the long neck doesn't drag her balance or snag on the map.
for _, d in ipairs(char:GetDescendants()) do
	if d:IsA("BasePart") then
		d.Anchored = false
		if d == head or d:IsDescendantOf(folder) then
			d.Massless = true
			d.CanCollide = false
		end
	end
end
if hrp then char.PrimaryPart = hrp end

print(("Rebuilt %d neck joints (Torso -> %d segments -> Head). She's spawn-ready; play as Rokurokubi.")
	:format(made, #ordered))
