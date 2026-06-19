-- COMPANION BIRD — server-side SETUP ONLY. Anchors the bird, makes it non-colliding, starts the
-- wing-flap, and tags it so the per-client follower takes over the movement.
--
-- WHERE THIS LIVES: a Script INSIDE the bird model (ReplicatedStorage > Companions > Hawk).
--
-- WHY IT'S SO SHORT NOW: the "ride beside Momotaro + cancel the baked flight-circle" logic used to
-- live here and ran on the SERVER, moving an anchored part every frame -- which stutters when it
-- replicates to other players. That movement now happens per-client on the render loop, in
-- src/StarterPlayer/StarterPlayerScripts/CompanionFollower.client.lua (smooth, no replication lag,
-- and the flap-cancel reads the animation in sync so it doesn't wobble). This script just gets the
-- bird ready + flapping; Momotaro's passive drops a "FollowTarget" value pointing at him.
--
-- TUNING (where the bird sits, its facing) now lives in that client follower's CONFIG table, NOT here.

local CollectionService = game:GetService("CollectionService")

local FLAP_ANIM_ID = 6409102589   -- the wing-flap animation that came with the bird

local bird = script.Parent
local primary = bird.PrimaryPart or bird:FindFirstChildWhichIsA("BasePart")
if not primary then warn("[Bird] No BasePart found in the bird model.") return end
bird.PrimaryPart = primary

-- Anchored (the client moves it by code) and non-colliding (so Momotaro can't bump his own bird).
for _, d in ipairs(bird:GetDescendants()) do
	if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end
end

-- Start the wings flapping. Played on the server so it replicates to everyone; each client reads the
-- animated bones to cancel the baked flight-path travel.
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

-- Hand the bird off to the per-client follower (StarterPlayerScripts/CompanionFollower.client.lua),
-- which drives every model carrying this tag.
CollectionService:AddTag(bird, "FollowingCompanion")
