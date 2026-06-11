-- DRESS GIRLA (non-destructive): build a clean, dressed, spawn-ready GirlA and deploy it
-- as StarterCharacter so you can walk around in her. Your master "Girl A" is NEVER touched --
-- this clones it and edits only the clone.
--
-- HOW TO USE:
-- 1. In the Explorer, select "Killer GirlA".
-- 2. Copy this whole file into the Command Bar, click the Command Bar's Run button.
-- 3. Test > Server and Clients (2 players) to spawn and look at her.
-- 4. When done, delete StarterCharacter from StarterPlayer.
--
-- HOW IT DRESSES: each costume part is welded to a body limb chosen by the NAME of the
-- model your daughter built it in ("Fire Right Hand" -> Right Arm, "skirt"/"blouse"/"bowtie"
-- -> Torso, "Fire Face"/"hair" -> Head, ...). If a name doesn't match, it falls back to the
-- nearest limb by distance. Costume parts are made massless + non-colliding so they ride the
-- body without wrecking its balance. (Hair Accessories are skipped this pass -- handled later.)

local Selection = game:GetService("Selection")
local StarterPlayer = game:GetService("StarterPlayer")

-- TUNABLE: how high the hair sits on the head, in studs above the head's center. If the hair
-- floats above her head, lower this; if it sits too low (balding look), raise it.
local HAIR_Y = 1.2

-- TUNABLE: spin the hair around so the bangs face forward. 180 = flipped front-to-back.
-- If the bangs end up on a side, try 90 or -90.
local HAIR_TURN_DEGREES = 180

-- TUNABLE: the "shoulder line." A shirt piece only follows the arm if it's at least this much
-- closer to the arm than to the torso. Smaller = more of the shoulder follows the arm; bigger =
-- more stays rigid on the torso. (At 0.6 the shoulders articulate; the small inner sliver is
-- the cost until the shoulder caps are split into their own parts.)
local SHOULDER_MARGIN = 0.6

local sourceRoot = Selection:Get()[1]
if not sourceRoot then warn("Select 'Killer GirlA' first.") return end

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

-- Move the Humanoid + the six R6 body parts into it (their Motor6Ds come along).
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

-- Pick the closest limb out of a named shortlist (so the skirt follows whichever LEG is
-- nearest, and each shirt-shoulder follows whichever ARM is nearest).
local function nearestOf(pos, names)
	local best, bestD
	for _, nm in ipairs(names) do
		local limb = limbs[nm]
		if limb then
			local d = (limb.Position - pos).Magnitude
			if not bestD or d < bestD then bestD, best = d, limb end
		end
	end
	return best
end

-- Decide which limb a costume part belongs to, by the names of the models it sits inside.
local function targetLimb(p)
	local node = p
	while node and node ~= srcClone do
		local n = string.lower(node.Name)
		-- Skirt: follow the nearer LEG so each side sways with that leg as she walks.
		if string.find(n, "skirt") then return nearestOf(p.Position, {"Left Leg", "Right Leg"}) end
		-- Blouse: a shoulder piece follows the nearer arm ONLY if it's clearly closer to that
		-- arm than to the torso (by SHOULDER_MARGIN). Pieces in the gap near the chest fall
		-- back to the torso -- that's the "line" that keeps a stray underarm block off the arm.
		if string.find(n, "blouse") then
			local dTorso = (limbs.Torso.Position - p.Position).Magnitude
			local dLeft  = (limbs["Left Arm"].Position - p.Position).Magnitude
			local dRight = (limbs["Right Arm"].Position - p.Position).Magnitude
			local arm = (dLeft <= dRight) and limbs["Left Arm"] or limbs["Right Arm"]
			local dArm = math.min(dLeft, dRight)
			if dArm < dTorso - SHOULDER_MARGIN then return arm end
			return limbs.Torso
		end
		if string.find(n, "bowtie") then return limbs.Torso end
		if string.find(n, "right hand") or string.find(n, "right arm") then return limbs["Right Arm"] end
		if string.find(n, "left hand")  or string.find(n, "left arm")  then return limbs["Left Arm"] end
		if string.find(n, "right leg") then return limbs["Right Leg"] end
		if string.find(n, "left leg")  then return limbs["Left Leg"] end
		if string.find(n, "face") or string.find(n, "head") or string.find(n, "hair") then return limbs.Head end
		node = node.Parent
	end
	return nil
end

local function nearestLimb(pos)
	local best, bestD
	for name, limb in pairs(limbs) do
		if name ~= "HumanoidRootPart" then
			local d = (limb.Position - pos).Magnitude
			if not bestD or d < bestD then bestD, best = d, limb end
		end
	end
	return best
end

local function insideAccessory(p)
	local n = p
	while n do
		if n:IsA("Accessory") then return true end
		n = n.Parent
	end
	return false
end

-- Weld every remaining costume part onto its limb.
local welded, fallback, skippedHair = 0, 0, 0
for _, p in ipairs(srcClone:GetDescendants()) do
	if p:IsA("BasePart") then
		if insideAccessory(p) then
			skippedHair = skippedHair + 1
		else
			local limb = targetLimb(p)
			if not limb then limb = nearestLimb(p.Position) fallback = fallback + 1 end
			if limb then
				p.Parent = dressed
				p.Anchored = false
				p.CanCollide = false
				p.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = limb
				w.Part1 = p
				w.Parent = p
				welded = welded + 1
			end
		end
	end
end

-- Fix the rig basics (same cleanup as the bare-rig proof).
-- Left Arm was a static Weld -> make it an animatable Motor6D.
if limbs.Torso and limbs["Left Arm"] then
	for _, d in ipairs(dressed:GetDescendants()) do
		if d:IsA("Weld") then
			local a = d.Part0 and d.Part0.Name
			local b = d.Part1 and d.Part1.Name
			if (a == "Torso" and b == "Left Arm") or (a == "Left Arm" and b == "Torso") then d:Destroy() end
		end
	end
	if not dressed:FindFirstChild("Left Shoulder", true) then
		local m = Instance.new("Motor6D")
		m.Name = "Left Shoulder"
		m.Part0 = limbs.Torso
		m.Part1 = limbs["Left Arm"]
		-- Build the left shoulder by mirroring the working RIGHT shoulder: flip its X and
		-- spin its orientation 180 degrees. This makes the left arm swing front-to-back the
		-- same way the right does, and it adapts to her exact proportions.
		local rightShoulder
		for _, d in ipairs(dressed:GetDescendants()) do
			if d:IsA("Motor6D") and d.Name == "Right Shoulder" then rightShoulder = d break end
		end
		local function mirrorX(cf)
			local p = cf.Position
			local rot = cf - p
			return CFrame.new(-p.X, p.Y, p.Z) * (rot * CFrame.Angles(0, math.pi, 0))
		end
		if rightShoulder then
			m.C0 = mirrorX(rightShoulder.C0)
			m.C1 = mirrorX(rightShoulder.C1)
		else
			-- fallback: standard R6 left shoulder
			m.C0 = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0)
			m.C1 = CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0)
		end
		m.Parent = limbs.Torso
	end
end
-- Drop dead welds, unanchor, set PrimaryPart.
for _, d in ipairs(dressed:GetDescendants()) do
	if (d:IsA("Weld") or d:IsA("ManualWeld")) and (d.Part0 == nil or d.Part1 == nil) then d:Destroy() end
	if d:IsA("BasePart") then d.Anchored = false end
end
dressed.PrimaryPart = limbs.HumanoidRootPart

-- Mount the hair accessory on the head (it was skipped during the costume pass).
local hairResult = "no accessory found"
do
	local head = limbs.Head
	local hair
	for _, d in ipairs(srcClone:GetDescendants()) do
		if d:IsA("Accessory") then hair = d break end
	end
	local handle = hair and hair:FindFirstChild("Handle")
	if head and handle then
		-- Direct weld: place the hair HAIR_Y studs above the head's center, turned so the bangs
		-- face forward, then weld it there. (AddAccessory ignored HAIR_Y because this hair's
		-- Handle has no attachment to align to.)
		handle.CFrame = head.CFrame * CFrame.new(0, HAIR_Y, 0) * CFrame.Angles(0, math.rad(HAIR_TURN_DEGREES), 0)
		handle.Anchored = false
		handle.CanCollide = false
		handle.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = head
		w.Part1 = handle
		w.Parent = handle
		handle.Parent = dressed
		-- Bring along any extra hair parts (welded to the handle so they move with it).
		for _, d in ipairs(hair:GetChildren()) do
			if d:IsA("BasePart") and d ~= handle then
				d.Anchored = false
				d.CanCollide = false
				d.Massless = true
				local w2 = Instance.new("WeldConstraint")
				w2.Part0 = handle
				w2.Part1 = d
				w2.Parent = d
				d.Parent = dressed
			end
		end
		hairResult = "welded directly to head at HAIR_Y=" .. HAIR_Y
	end
end

srcClone:Destroy()

local old = StarterPlayer:FindFirstChild("StarterCharacter")
if old then old:Destroy() end
dressed.Parent = StarterPlayer

print(string.format("DONE. Dressed GirlA: %d costume parts welded (%d by nearest-limb fallback). Hair: %s.",
	welded, fallback, hairResult))
print("Test > Server and Clients (2 players) to view. Delete StarterCharacter when done.")
