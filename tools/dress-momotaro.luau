-- DRESS MOMOTARO (non-destructive): build a clean, dressed, spawn-ready Momotaro and deploy
-- it as StarterCharacter so you can walk around in him. Your master "Survivor Momotaro" is
-- NEVER touched -- this clones it and edits only the clone.
--
-- HOW TO USE:
-- 1. In the Explorer, select "Survivor Momotaro" (the top folder).
-- 2. Copy this whole file into the Command Bar, click the Command Bar's Run button.
-- 3. Test > Server and Clients (2 players) to spawn and look at him.
-- 4. When done, delete StarterCharacter from StarterPlayer.
--
-- WHAT'S DIFFERENT FROM GIRL A: Momotaro's rig has NO HEAD, so we add an invisible Head block
-- plus a normal Neck joint, then weld his full-head MASK on top (right where it was built). The
-- robe (Kokushibo Haori), the webbing/belt/pouches, and his Handle are welded onto the body by
-- name, just like Girl A's costume.

local Selection = game:GetService("Selection")
local StarterPlayer = game:GetService("StarterPlayer")

-- TUNABLE: how high the invisible Head sits above the Torso's center, in studs. 1.5 is the
-- normal Roblox spot (torso is 2 tall, head is 1 tall: 1 + 0.5 = 1.5). Keep this at 1.5 so the
-- mask doesn't hop when the game starts; only change it if the mask sits too high or too low.
local HEAD_Y = 1.5

-- NOTE: the part named "Handle" in this model is actually his HAIR (not a weapon/prop), so we
-- weld it to the Head, not a hand. If a real weapon-handle is added later, give it a clearer
-- name (like "Hatchet") and add a rule for it below.

-- TUNABLE: slide the hair BACKWARD a little so it covers the back of the head (his head was
-- peeking through). Bigger number = hair moves further back. If it slides off the front of his
-- face, lower it or use a small negative number.
local HAIR_BACK = 0.5

-- TUNABLE: nudge the hair UP a little if the bald spot is on top. 0 = no change.
local HAIR_UP = 0

local sourceRoot = Selection:Get()[1]
if not sourceRoot then warn("Select 'Survivor Momotaro' first.") return end

-- Clone the whole thing so the master is never edited.
local srcClone = sourceRoot:Clone()

-- Find the rig (the model holding the Humanoid).
local hum
for _, d in ipairs(srcClone:GetDescendants()) do
	if d:IsA("Humanoid") then hum = d break end
end
if not hum then warn("No Humanoid found under selection.") srcClone:Destroy() return end
local rig = hum.Parent

-- Build the dressed character.
local dressed = Instance.new("Model")
dressed.Name = "StarterCharacter"

-- Move the Humanoid + the R6 body parts into it (their Motor6Ds come along). Momotaro has no
-- Head yet -- we build one below.
local R6 = { HumanoidRootPart=true, Torso=true, Head=true,
	["Left Arm"]=true, ["Right Arm"]=true, ["Left Leg"]=true, ["Right Leg"]=true }
hum.Parent = dressed
local limbs = {}
for _, child in ipairs(rig:GetChildren()) do
	if child:IsA("BasePart") and R6[child.Name] then
		child.Parent = dressed
		limbs[child.Name] = child
	elseif child:IsA("CharacterMesh") or child:IsA("BodyColors") then
		child.Parent = dressed
	end
end

-- ----------------------------------------------------------------------------
-- Build the missing Head + Neck joint (standard R6).
-- ----------------------------------------------------------------------------
if not limbs.Head and limbs.Torso then
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)        -- standard R6 head size
	head.Transparency = 1                    -- invisible: we only want to see the mask
	head.CanCollide = false
	head.TopSurface = Enum.SurfaceType.Smooth
	head.BottomSurface = Enum.SurfaceType.Smooth
	-- Sit the head where the Neck joint will rest, so the welded mask won't hop on spawn.
	head.CFrame = limbs.Torso.CFrame * CFrame.new(0, HEAD_Y, 0)
	head.Parent = dressed
	limbs.Head = head

	-- Neck Motor6D with the classic R6 numbers (so the head turns/tilts like a normal avatar).
	local neck = Instance.new("Motor6D")
	neck.Name = "Neck"
	neck.Part0 = limbs.Torso
	neck.Part1 = head
	neck.C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	neck.C1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	neck.Parent = limbs.Torso
end

-- ----------------------------------------------------------------------------
-- Decide which limb a costume part belongs to, by the names of the models it sits inside.
-- ----------------------------------------------------------------------------
local function nearestLimb(pos)
	local best, bestD
	for name, limb in pairs(limbs) do
		-- Don't let stray parts snap to the root or fly up to the face.
		if name ~= "HumanoidRootPart" and name ~= "Head" then
			local d = (limb.Position - pos).Magnitude
			if not bestD or d < bestD then bestD, best = d, limb end
		end
	end
	return best
end

-- Is this part his hair (the "Handle"/"Hair" piece) rather than the face mask? We only nudge
-- the hair, never the mask.
local function isHairPart(p)
	local node = p
	while node and node ~= srcClone do
		local n = string.lower(node.Name)
		if string.find(n, "mask") or string.find(n, "fullhead") or string.find(n, "pdrzin") then
			return false
		end
		if string.find(n, "handle") or string.find(n, "hair") then return true end
		node = node.Parent
	end
	return false
end

local function targetLimb(p)
	local node = p
	while node and node ~= srcClone do
		local n = string.lower(node.Name)
		-- His head mask AND his hair (named "Handle") -> the new Head.
		if string.find(n, "mask") or string.find(n, "pdrzin") or string.find(n, "fullhead")
			or string.find(n, "head") or string.find(n, "hair") or string.find(n, "handle") then
			return limbs.Head
		end
		-- Robe sleeves: Arm1 was built as his RIGHT sleeve, Arm2 as his LEFT (from the weld names).
		if string.find(n, "arm1") then return limbs["Right Arm"] end
		if string.find(n, "arm2") then return limbs["Left Arm"] end
		-- The robe body, plus all the belt / pouches / back webbing, ride the Torso.
		if string.find(n, "haori") or string.find(n, "webbing") or string.find(n, "belt")
			or string.find(n, "pouch") or string.find(n, "back") then return limbs.Torso end
		node = node.Parent
	end
	return nil
end

-- ----------------------------------------------------------------------------
-- Weld every remaining costume part onto its limb (massless + non-colliding so it just rides).
-- ----------------------------------------------------------------------------
local welded, fallback = 0, 0
for _, p in ipairs(srcClone:GetDescendants()) do
	if p:IsA("BasePart") then
		local limb = targetLimb(p)
		if not limb then limb = nearestLimb(p.Position) fallback = fallback + 1 end
		if limb then
			p.Parent = dressed
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			-- Slide the hair back/up (in the head's own frame) before welding it in place, so the
			-- weld locks it at the nicer spot. +Z in the head's frame points BEHIND the face.
			if limb == limbs.Head and isHairPart(p) and (HAIR_BACK ~= 0 or HAIR_UP ~= 0) then
				p.CFrame = p.CFrame + limbs.Head.CFrame:VectorToWorldSpace(Vector3.new(0, HAIR_UP, HAIR_BACK))
			end
			local w = Instance.new("WeldConstraint")
			w.Part0 = limb
			w.Part1 = p
			w.Parent = p
			welded = welded + 1
		end
	end
end

-- ----------------------------------------------------------------------------
-- Rig cleanup: drop dead placeholder welds (the robe's Part1 = nil ones), unanchor everything,
-- set the PrimaryPart.
-- ----------------------------------------------------------------------------
for _, d in ipairs(dressed:GetDescendants()) do
	if (d:IsA("Weld") or d:IsA("ManualWeld")) and (d.Part0 == nil or d.Part1 == nil) then d:Destroy() end
	if d:IsA("BasePart") then d.Anchored = false end
end
dressed.PrimaryPart = limbs.HumanoidRootPart

srcClone:Destroy()

local old = StarterPlayer:FindFirstChild("StarterCharacter")
if old then old:Destroy() end
dressed.Parent = StarterPlayer

print(string.format("DONE. Dressed Momotaro: %d costume parts welded (%d by nearest-limb fallback). Head added: %s.",
	welded, fallback, tostring(limbs.Head ~= nil)))
print("Test > Server and Clients (2 players) to view. Delete StarterCharacter when done.")
