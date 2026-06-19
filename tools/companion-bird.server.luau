-- COMPANION BIRD — hovers beside Momotaro (above his head, off his right shoulder) and flaps.
--
-- WHERE THIS LIVES: this is a Script that goes INSIDE the bird model (not the Command Bar).
-- It replaces the little flap-only script that came with the free bird asset.
--
-- HOW TO USE:
-- 1. Inside the bird model, add a new Script (right-click model > Insert Object > Script).
-- 2. Paste this whole file into it. Delete the old "Script" that came with the bird.
-- 3. The bird is huge by default — resize it smaller with the Scale tool first.
--
-- IMPORTANT: the bird's animation is a baked "flight path" — it flaps the wings AND flies the
-- body in a big circle. We keep the flapping but CANCEL the travel by pinning the body bone to the
-- spot we want each frame. So the wings move, but the bird stays put beside Momotaro.
--
-- WHO IT FOLLOWS: Momotaro's passive drops an ObjectValue named "FollowTarget" inside this model,
-- pointing at the live player's character -- we ride beside that. If there's no FollowTarget (e.g.
-- you're testing the bird on its own in Studio), it falls back to finding a Model/Part named
-- TARGET_NAME, and if that's missing too it just hovers beside its own starting spot.

local RunService = game:GetService("RunService")

------------------------------------------------------------------------------
-- TUNABLES (the bird's spot is measured from Momotaro: right of him, above him, in front of him)
------------------------------------------------------------------------------
local FLAP_ANIM_ID   = 6409102589  -- the wing-flap (flight-path) animation that came with the bird
local TARGET_NAME    = "Momotaro"  -- who to ride beside (a Model/Part by this name); else its start spot
local PIN_BONE       = "Body"      -- the bone we hold in place to cancel the flight travel. If it still
                                   -- drifts in a circle, try "Root" instead.
-- NOTE: these are ABSOLUTE studs. Momotaro is a big (~2.4x) character, so the numbers are larger
-- than a normal rig would need -- they put the bird above his head and out past his right shoulder.
local RIGHT_OFFSET   = 6           -- studs to his right (off the right shoulder). Negative = his left.
local UP_OFFSET      = 10          -- studs up (well above his head so it flies free, not on the shoulder)
local FORWARD_OFFSET = 0           -- studs in front of him. Negative = behind him.
local BOB_HEIGHT     = 0.4         -- gentle up/down float so it feels alive, in studs
local BOB_SPEED      = 1.5         -- up/down bobs per second
local FOLLOW_SMOOTH  = 0.15        -- 0..1: how snappily it keeps up (smaller = floatier, lazier follow)
local FACING_YAW     = 0           -- if the bird faces the wrong way, try 180, 90, or -90

local bird = script.Parent

------------------------------------------------------------------------------
-- Setup: pick the main part, anchor everything (we move it by code), play the flap.
------------------------------------------------------------------------------
local primary = bird.PrimaryPart or bird:FindFirstChildWhichIsA("BasePart")
if not primary then warn("[Bird] No BasePart found in the bird model.") return end
bird.PrimaryPart = primary

for _, d in ipairs(bird:GetDescendants()) do
	-- Anchored (we move it by code) and non-colliding (so Momotaro can't bump into his own bird).
	if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end
end

-- The bone we'll pin in place to cancel the flight-path travel.
local pinBone = primary:FindFirstChild(PIN_BONE, true)
if not pinBone then warn("[Bird] No bone named '" .. PIN_BONE .. "' found; the circle may not cancel.") end

local animator = bird:FindFirstChildWhichIsA("Animator", true)
if animator then
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. tostring(FLAP_ANIM_ID)
	local track = animator:LoadAnimation(anim)
	track.Looped = true
	track:Play()
else
	warn("[Bird] No Animator found, so the wings won't flap.")
end

------------------------------------------------------------------------------
-- Find Momotaro each frame (so the bird follows him as he moves), keeping it off his RIGHT shoulder
-- even as he turns.
------------------------------------------------------------------------------
local startCFrame = primary.CFrame
local function targetCFrame()
	-- Preferred: ride beside whoever the spawner pointed us at (Momotaro's passive sets this to the
	-- live player character). Read it each frame so it works even if it's set a moment after we start.
	local follow = bird:FindFirstChild("FollowTarget")
	if follow and follow.Value then
		local t = follow.Value
		if t:IsA("Model") then return t:GetPivot() end
		if t:IsA("BasePart") then return t.CFrame end
	end
	-- Fallback: find a Model/Part named TARGET_NAME (handy for standalone Studio testing).
	if TARGET_NAME ~= "" then
		local t = workspace:FindFirstChild(TARGET_NAME, true)
		if t and t:IsA("Model") then return t:GetPivot() end
		if t and t:IsA("BasePart") then return t.CFrame end
	end
	return startCFrame   -- nothing found: hover beside our own starting spot
end

------------------------------------------------------------------------------
-- Each frame: pick the goal spot beside him, ease toward it, then pin the body bone there so the
-- baked flight-circle is cancelled but the wing flapping stays.
------------------------------------------------------------------------------
local current = nil
local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock = clock + dt
	local bob = math.sin(clock * BOB_SPEED * math.pi * 2) * BOB_HEIGHT

	local base = targetCFrame()
	-- His local axes: +X = his right, +Y = up, -Z = the way he faces. So forward is a NEGATIVE Z.
	local goalPos = base:PointToWorldSpace(Vector3.new(RIGHT_OFFSET, UP_OFFSET + bob, -FORWARD_OFFSET))
	local goal = CFrame.new(goalPos) * (base - base.Position) * CFrame.Angles(0, math.rad(FACING_YAW), 0)

	-- Ease toward the goal so it glides instead of snapping.
	current = current and current:Lerp(goal, FOLLOW_SMOOTH) or goal

	if pinBone then
		-- Where has the animation flung the body bone, relative to the mesh? Move the mesh so that
		-- bone lands exactly on our goal -- this cancels the flight-path travel.
		local meshToBone = primary.CFrame:ToObjectSpace(pinBone.TransformedWorldCFrame)
		primary.CFrame = current * meshToBone:Inverse()
	else
		primary.CFrame = current
	end
end)
