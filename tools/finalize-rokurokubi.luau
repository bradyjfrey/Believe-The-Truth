-- FINALIZE ROKUROKUBI: turn ModelingRorokubi (with the segmented neck) into the deployed
-- StarterCharacter so you can play as her. Select ModelingRorokubi in the Explorer, paste, Run.
--
-- It: removes the in-model preview wave Script (won't run as a StarterCharacter anyway), unanchors
-- everything so the player can move, makes the neck + head massless + non-colliding (so the long
-- neck doesn't unbalance her or snag on the map), sets the PrimaryPart, and deploys it.

local Selection = game:GetService("Selection")
local StarterPlayer = game:GetService("StarterPlayer")

local model = Selection:Get()[1]
if not model then warn("Select ModelingRorokubi first.") return end

-- Remove the in-model preview wave Script (the real wave lives in StarterCharacterScripts).
for _, d in ipairs(model:GetDescendants()) do
	if d.ClassName == "Script" then d:Destroy() end
end

-- Mark the neck segments.
local neck = {}
local nc = model:FindFirstChild("NeckChain", true)
if nc then
	for _, p in ipairs(nc:GetChildren()) do
		if p:IsA("BasePart") then neck[p] = true end
	end
end

-- Unanchor everything; make neck + head massless + non-colliding.
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		d.Anchored = false
		if neck[d] or d.Name == "Head" then
			d.Massless = true
			d.CanCollide = false
		end
	end
end

local hrp = model:FindFirstChild("HumanoidRootPart", true)
if hrp then model.PrimaryPart = hrp end

model.Name = "StarterCharacter"
local old = StarterPlayer:FindFirstChild("StarterCharacter")
if old and old ~= model then old:Destroy() end
model.Parent = StarterPlayer

print("Finalized -> StarterCharacter (neck massless + non-colliding, unanchored, deployed).")
print("Now put the NeckWave LocalScript in StarterCharacterScripts and Play (Server and Clients).")
