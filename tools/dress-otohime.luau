-- DRESS OTOHIME (non-destructive): build a clean, spawn-ready Otohime and deploy her as
-- StarterCharacter so you can walk around in her. Your master "Otohime" folder is NEVER touched --
-- this clones it and edits only the clone.
--
-- WHY THIS ONE IS BIGGER THAN MOMOTARO'S: Otohime came in with her Humanoid + 6 body parts, but
-- with NO HumanoidRootPart and NONE of the 6 joints (RootJoint/Neck/Shoulders/Hips) -- so she was a
-- frozen statue. Good news from the size report: her parts are a perfectly uniform 2.4x scale of a
-- standard R6 rig, so we can build the standard skeleton onto her existing parts -- we just scale
-- every joint offset by that same 2.4 so the limbs line up. Then we weld her kimono/hair/face/tiara
-- onto the body, exactly like Girl A and Momotaro.
--
-- HOW TO USE:
-- 1. In the Explorer, select the "Otohime" folder (the top one).
-- 2. Copy this whole file into the Command Bar, click the Command Bar's Run button.
-- 3. Play (or Test > Server and Clients) to walk around in her and watch her animate.
-- 4. When done, delete StarterCharacter from StarterPlayer.
--
-- SIZE: keep her at her NATIVE size. The "2.4x" is just how this game's survivors are built (the
-- other survivor is the same scale) -- she was the right size from the start, so we do NOT shrink
-- her. We still scale the JOINT offsets by 2.4 (her native body needs native-scaled joints).

local Selection = game:GetService("Selection")
local StarterPlayer = game:GetService("StarterPlayer")

local sourceRoot = Selection:Get()[1]
if not sourceRoot then warn("Select the 'Otohime' folder first.") return end

-- Clone the whole thing so the master is never edited.
local srcClone = sourceRoot:Clone()

-- Find the rig (the model holding the Humanoid) inside the clone.
local hum
for _, d in ipairs(srcClone:GetDescendants()) do
	if d:IsA("Humanoid") then hum = d break end
end
if not hum then warn("No Humanoid found under selection.") srcClone:Destroy() return end
local rig = hum.Parent

-- Build the dressed character.
local dressed = Instance.new("Model")
dressed.Name = "StarterCharacter"

-- Move the Humanoid + the R6 body parts into it.
local R6 = { Torso=true, Head=true,
	["Left Arm"]=true, ["Right Arm"]=true, ["Left Leg"]=true, ["Right Leg"]=true }
hum.Parent = dressed
local limbs = {}
for _, child in ipairs(rig:GetChildren()) do
	if child:IsA("BasePart") and R6[child.Name] then
		child.Parent = dressed
		limbs[child.Name] = child
	end
end

local torso = limbs.Torso
if not torso then warn("No Torso found -- can't build the skeleton.") srcClone:Destroy() dressed:Destroy() return end

-- ----------------------------------------------------------------------------
-- How much bigger than a normal rig is she? Standard Torso is 2 studs tall; hers is 4.8, so the
-- scale is 4.8 / 2 = 2.4. We multiply every standard joint OFFSET by this so the limbs line up.
-- (Computing it instead of hard-coding 2.4 means this still works if she's ever re-scaled.)
-- ----------------------------------------------------------------------------
local SCALE = torso.Size.Y / 2

-- Scale only the POSITION of a CFrame, leaving the rotation alone.
local function scalePos(cf, k)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(x * k, y * k, z * k, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

-- ----------------------------------------------------------------------------
-- Build the missing HumanoidRootPart (the invisible part the Humanoid actually "walks").
-- ----------------------------------------------------------------------------
local hrp = Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.Size = Vector3.new(2, 2, 1) * SCALE      -- standard HRP size, scaled to match her
hrp.Transparency = 1
hrp.CanCollide = false
hrp.TopSurface = Enum.SurfaceType.Smooth
hrp.BottomSurface = Enum.SurfaceType.Smooth
hrp.CFrame = torso.CFrame                     -- the root sits right at the torso's center
hrp.Parent = dressed
limbs.HumanoidRootPart = hrp

-- ----------------------------------------------------------------------------
-- Build the 6 standard R6 joints. These are the exact values a normal Roblox R6 avatar uses; we
-- scale each one's position by SCALE so the limbs sit in the right spot on her bigger body. The
-- ROTATION half of each value is what makes the default Animate script swing arms/legs correctly.
-- ----------------------------------------------------------------------------
local JOINTS = {
	{name = "RootJoint", part0 = "HumanoidRootPart", part1 = "Torso",
		C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		C1 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)},
	{name = "Neck", part0 = "Torso", part1 = "Head",
		C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		C1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)},
	{name = "Right Shoulder", part0 = "Torso", part1 = "Right Arm",
		C0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		C1 = CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)},
	{name = "Left Shoulder", part0 = "Torso", part1 = "Left Arm",
		C0 = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		C1 = CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)},
	{name = "Right Hip", part0 = "Torso", part1 = "Right Leg",
		C0 = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		C1 = CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)},
	{name = "Left Hip", part0 = "Torso", part1 = "Left Leg",
		C0 = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		C1 = CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)},
}

for _, j in ipairs(JOINTS) do
	local p0, p1 = limbs[j.part0], limbs[j.part1]
	if p0 and p1 then
		local motor = Instance.new("Motor6D")
		motor.Name = j.name
		motor.Part0 = p0
		motor.Part1 = p1
		motor.C0 = scalePos(j.C0, SCALE)
		motor.C1 = scalePos(j.C1, SCALE)
		-- Real R6 keeps RootJoint inside the HumanoidRootPart and the rest inside the Torso.
		motor.Parent = (j.name == "RootJoint") and p0 or torso
	else
		warn("Skipped joint " .. j.name .. " (missing " .. j.part0 .. " or " .. j.part1 .. ")")
	end
end

-- ----------------------------------------------------------------------------
-- Decide which body part each costume piece welds to. The OLD version welded everything to the
-- Torso, so her sleeves/pant-legs stayed put while her real arms/legs swung out past them. Fix:
--   * accessories (hair / face / tiara) -> the Head
--   * every other costume piece -> the NEAREST body part, so a sleeve mesh welds to the arm it sits
--     on and a pant-leg mesh welds to the leg it sits on, and they move WITH that limb.
-- ----------------------------------------------------------------------------

-- Nearest of the moving limbs (arms, legs, torso) to a world position. Head is left out here so a
-- high collar doesn't fly up to the face; accessories handle the head separately.
local function nearestLimb(pos)
	local best, bestDist
	for _, name in ipairs({"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}) do
		local limb = limbs[name]
		if limb then
			local d = (limb.Position - pos).Magnitude
			if not bestDist or d < bestDist then bestDist, best = d, limb end
		end
	end
	return best
end

-- Left or Right, decided by which side of the Torso the part sits on (so you never have to label
-- left vs right yourself -- just tag a piece "sleeve" or "pant" and we pick the correct side).
local function side(p)
	local relX = torso.CFrame:PointToObjectSpace(p.Position).X
	return (relX < 0) and "Left" or "Right"
end

local function targetLimb(p)
	local node = p
	while node and node ~= srcClone do
		if node:IsA("Accessory") then return limbs.Head end
		local n = string.lower(node.Name)
		if string.find(n, "hair") or string.find(n, "face") or string.find(n, "tiara")
			or string.find(n, "head") then return limbs.Head end
		-- NAME HINTS (rename a piece to include one of these words for an exact weld). Left vs right
		-- is auto-detected by position, so just use "sleeve" / "pant" -- not "left sleeve".
		if string.find(n, "sleeve") then return limbs[side(p) .. " Arm"] end
		if string.find(n, "pant") or string.find(n, "hakama") or string.find(n, "legwrap") then
			return limbs[side(p) .. " Leg"]
		end
		if string.find(n, "body") or string.find(n, "obi") or string.find(n, "sash")
			or string.find(n, "robe") or string.find(n, "torso") then return limbs.Torso end
		node = node.Parent
	end
	return nearestLimb(p.Position)   -- no hint: nearest body part (sleeves->arms, legs->legs, body->torso)
end

-- ----------------------------------------------------------------------------
-- Move every costume part onto the body (massless + non-colliding so it just rides). RESPECT
-- MANUAL WELDS: if you already added a WeldConstraint to a piece yourself (like the pants legs),
-- we leave that weld alone and don't add a second one. Only pieces with NO weld get auto-welded
-- by name/nearest-limb (that's how the kimono's body_*/sleeve_* parts get attached).
-- ----------------------------------------------------------------------------
local autoWelded, kept = 0, 0
for _, p in ipairs(srcClone:GetDescendants()) do
	if p:IsA("BasePart") then
		p.Parent = dressed
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		if p:FindFirstChildWhichIsA("WeldConstraint") then
			kept = kept + 1          -- you welded this one by hand -- keep it
		else
			local limb = targetLimb(p)
			if limb then
				local w = Instance.new("WeldConstraint")
				w.Part0 = limb
				w.Part1 = p
				w.Parent = p
				autoWelded = autoWelded + 1
			end
		end
	end
end

-- ----------------------------------------------------------------------------
-- Cleanup: drop dead placeholder welds (like the tiara's Part1 = nil one), unanchor everything,
-- set the PrimaryPart.
-- ----------------------------------------------------------------------------
for _, d in ipairs(dressed:GetDescendants()) do
	if (d:IsA("Weld") or d:IsA("ManualWeld")) and (d.Part0 == nil or d.Part1 == nil) then d:Destroy() end
	if d:IsA("BasePart") then d.Anchored = false end
end
dressed.PrimaryPart = hrp

srcClone:Destroy()

local old = StarterPlayer:FindFirstChild("StarterCharacter")
if old then old:Destroy() end
dressed.Parent = StarterPlayer

print(string.format("DONE. Built Otohime's skeleton at her native %.2fx size (no shrink). HRP + 6 joints added. Auto-welded %d costume parts; kept %d of your hand-made welds.", SCALE, autoWelded, kept))
print("Play to walk around in her. Your manual pant welds are preserved; the kimono (body_/sleeve_) is welded automatically. Delete StarterCharacter when done.")
