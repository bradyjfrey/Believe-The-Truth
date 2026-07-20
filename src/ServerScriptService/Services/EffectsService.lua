-- EffectsService.lua
-- Plays a visual effect by NAME. Abilities just call EffectsService:Play("SomeName", position)
-- and we look for a template named exactly "SomeName" inside ReplicatedStorage.Effects, clone it
-- to that spot, fire its particles/sounds, and clean it up a few seconds later.
--
-- HOW EFFECTS ARE BUILT (drop a template into ReplicatedStorage.Effects):
--   * Name it EXACTLY the effect name an ability passes (e.g. "GirlASlash", "OtohimeHealingPulse").
--   * It can be a single Part, a Model, or a Folder full of parts -- we handle all three.
--   * Put your ParticleEmitters / Sounds / PointLights inside it; we turn the emitters on, play
--     the sounds, then remove the whole thing after its lifetime so nothing piles up in the world.
--   * IMPORTANT: effects are PURELY VISUAL. The actual healing/damage numbers live in the ability
--     code (e.g. Otohime's heal amount), never here.
--
-- If no template exists for a name yet, we just print (so playtests still show the ability fired).
-- Any Script/LocalScript/ModuleScript found inside a template is STRIPPED before it plays -- free
-- art assets sometimes smuggle scripts in, and an effect should never run code.
--
-- Effect names the abilities currently call:
--   MOMOTARO: MomotaroKatanaWindup, MomotaroKatanaSwing, MomotaroKatanaHit, MomotaroInutaDeploy,
--     MomotaroInutaBark, MomotaroSaruEat, MomotaroBananaDrop, MomotaroBananaSlip,
--     MomotaroKibiDangoSelf, MomotaroKibiDangoTeammate, MomotaroBirdsEyeView
--   ROKUROKUBI: RokurokubiNeckWrapWindup, RokurokubiNeckWrapHit, RokurokubiBite,
--     RokurokubiDisguiseChargeUp, RokurokubiDisguiseApplied, RokurokubiDisguiseEnded,
--     RokurokubiEyeGlow, RokurokubiStrangle, RokurokubiHiddenHungerGrowl
--   GIRL A: GirlASlash, GirlASlashHit, GirlABreachPopup, GirlAStrayBladeAim, GirlAStrayBladeThrow,
--     GirlAStrayBladeImpact, GirlAIncognitoStart, GirlAIncognitoEnd, GirlAHotspotTeleport
--   OTOHIME: OtohimeHealingPulse, OtohimeDarkMoon

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local EffectsService = {}

-- How long an effect stays in the world before we delete it (seconds). A name can override the
-- default here if it needs to linger longer (a slow-fading moon) or shorter (a quick slash).
local DEFAULT_LIFETIME = 2.5
local LIFETIMES = {
	GirlASlash = 1,
	GirlASlashHit = 0.8,
	OtohimeHealingPulse = 2.5,
	OtohimeDarkMoon = 3,
	RokurokubiHiddenHungerGrowl = 4,   -- sound-only; long enough that the growl isn't cut off
}

-- The folder all templates live in. Looked up lazily so this module loads cleanly at startup.
local function effectsFolder()
	return ReplicatedStorage:FindFirstChild("Effects")
end

-- Pick a part to anchor the effect on, so we can place the whole thing at the target spot.
-- Prefers a Model's PrimaryPart, else the first BasePart we can find inside.
local function findAnchorPart(inst)
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") and inst.PrimaryPart then return inst.PrimaryPart end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

-- Strip any scripts out of a cloned effect -- a visual should never run code (free-asset safety).
local function stripScripts(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then   -- Script, LocalScript, or ModuleScript
			d:Destroy()
		end
	end
end

-- Switch on every particle emitter (with a little instant burst) and play every sound.
local function enablePlayback(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Enabled = true
			if d.Rate and d.Rate > 0 then d:Emit(math.clamp(math.floor(d.Rate / 4), 1, 30)) end
		elseif d:IsA("Sound") then
			d.Looped = false
			d:Play()
		end
	end
end

-- For a fixed-spot effect: anchor every part so it stays put and never shoves a player.
local function freezeInWorld(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
end

-- For an attached effect: make every part weightless + non-colliding so it can ride a moving limb.
local function makeRideable(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
		end
	end
end

-- Play an effect by name.
--   position : where it happens (Vector3). nil = skip placement.
--   extras   : optional table. Supported:
--                extras.AttachTo -- a BasePart to ride along (e.g. a weapon arm). The effect welds
--                                   to it and follows it, immune to dashes/lunges. When set,
--                                   extras.CFrame is a LOCAL offset from that part.
--                extras.CFrame   -- full world CFrame to place + orient at (or, with AttachTo, the
--                                   local offset from the part).
--                extras.Scale    -- shrink/grow the effect (1 = original size).
--                extras.Lifetime -- override how long it lives, in seconds.
--                extras.Parent   -- parent the effect under this instance instead of Workspace.
function EffectsService:Play(effectName, position, extras)
	extras = extras or {}

	local folder = effectsFolder()
	local template = folder and folder:FindFirstChild(effectName)
	if not template then
		-- No template built for this name yet -- just log it so we can see the ability fired.
		print(string.format("[EffectsService] (no template) %s at %s", tostring(effectName), tostring(position)))
		return
	end

	local clone = template:Clone()
	stripScripts(clone)

	-- Wrap the clone in a Model so we can move/scale the whole thing as one piece (works even if
	-- the template is a Folder, which can't be positioned on its own).
	local container = Instance.new("Model")
	container.Name = effectName .. "_FX"
	clone.Parent = container

	local anchor = findAnchorPart(container)
	if anchor then container.PrimaryPart = anchor end

	if extras.Scale and anchor then container:ScaleTo(extras.Scale) end

	if extras.AttachTo and anchor then
		-- Ride along a moving part (a limb/weapon). CFrame is a local offset from that part.
		local offset = extras.CFrame or CFrame.new()
		makeRideable(container)
		container:PivotTo(extras.AttachTo.CFrame * offset)
		-- Weld every loose part of the effect to the anchor so the whole thing moves as one piece
		-- (templates that are a Folder of un-welded parts would otherwise leave bits behind).
		for _, d in ipairs(container:GetDescendants()) do
			if d:IsA("BasePart") and d ~= anchor then
				local w = Instance.new("WeldConstraint")
				w.Part0 = anchor
				w.Part1 = d
				w.Parent = anchor
			end
		end
		-- Then weld the anchor to the part we're riding.
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = extras.AttachTo
		weld.Part1 = anchor
		weld.Parent = anchor
		container.Parent = extras.Parent or Workspace
	else
		-- Fixed spot in the world, centered on the target point.
		freezeInWorld(container)
		local cf = extras.CFrame or (position and CFrame.new(position))
		if anchor and cf then
			container:PivotTo(cf)
			-- Re-center so the effect's BOUNDING-BOX middle sits on the target, not whatever random
			-- part happened to be the anchor (templates are usually off-center, so they'd appear
			-- shoved to one side / behind the target).
			local boxCF = container:GetBoundingBox()
			container:PivotTo(cf + (cf.Position - boxCF.Position))
		end
		container.Parent = extras.Parent or Workspace
	end

	enablePlayback(container)

	local lifetime = extras.Lifetime or LIFETIMES[effectName] or DEFAULT_LIFETIME
	Debris:AddItem(container, lifetime)
end

return EffectsService
