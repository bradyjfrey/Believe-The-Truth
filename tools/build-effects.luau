-- Builds code-made effect templates into ReplicatedStorage.Effects. No selection needed.
-- Re-running rebuilds anything this tool made before (tagged BuiltByTool) and never touches a
-- template someone built by hand: those are skipped with a warning.
-- ADDONS instead add particles to an EXISTING hand-built template (e.g. one holding the kids'
-- sound), inside one tagged Attachment named CodeVisual; re-running replaces only that.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local BLOOD = Color3.fromRGB(120, 8, 14)
local DARK_BLOOD = Color3.fromRGB(60, 0, 6)
local PIN_METAL = Color3.fromRGB(95, 90, 88)
local PIN_HEAD = Color3.fromRGB(150, 12, 20)

local effects = ReplicatedStorage:FindFirstChild("Effects")
if not effects then
	effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = ReplicatedStorage
end

local function part(parent, name, size, cframe, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe or CFrame.new()
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props or {}) do p[key] = value end
	p.Parent = parent
	return p
end

-- burstCount makes it a one-shot: each player's PreloadEffects fires that many particles once,
-- then nothing (server-side Emit never reaches players).
-- Leave it out for an emitter that should keep running for the effect's whole lifetime.
local function emitter(parent, props, burstCount)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightEmission = 0
	for key, value in pairs(props) do e[key] = value end
	if burstCount then e:SetAttribute("Burst", burstCount) end
	e.Parent = parent
	return e
end

local function core(model, size)
	return part(model, "Core", size or Vector3.new(1, 1, 1), nil, {Transparency = 1})
end

local function fade(fromTransparency)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, fromTransparency),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function shrink(fromSize)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, fromSize),
		NumberSequenceKeypoint.new(1, 0),
	})
end

local function grow(fromSize, toSize)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, fromSize),
		NumberSequenceKeypoint.new(1, toSize),
	})
end

-- EffectsService places an effect by the FIRST part it finds, and resets that part's rotation.
-- So every recipe creates an unrotated part first; a rotated one (the flat discs) placed first
-- ends up standing on its edge.
local RECIPES = {}

-- The whip's crack along its reach in front of him. Placed by Tomino.lua at the middle of the reach.
RECIPES.TominoWhipLash = function(model)
	local line = part(model, "Reach", Vector3.new(1.5, 1.5, 20), nil, {Transparency = 1})
	emitter(line, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 200), BLOOD),
		Size = shrink(1.4),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 160,
		LightEmission = 0.6,
	})
	return line
end

-- Blood spray on the survivor the lash lands on.
RECIPES.TominoWhipLashHit = function(model)
	local core = part(model, "Core", Vector3.new(1, 1, 1), nil, {Transparency = 1})
	emitter(core, {
		Texture = SPARKLE,
		Color = ColorSequence.new(BLOOD, DARK_BLOOD),
		Size = shrink(0.9),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(10, 20),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -60, 0),
		Rate = 120,
	})
	return core
end

-- Shockwave on the ground. The flat disc is exactly the 30-stud hit radius, so what survivors
-- see flash is what got hit; it's hidden when the flash ends and the dust finishes on its own.
-- Keep DISC_RADIUS in step with Constants.Tomino.WhipSlam.RadiusStuds.
local DISC_RADIUS = 30
RECIPES.TominoWhipSlam = function(model)
	local center = part(model, "Center", Vector3.new(2, 1, 2), nil, {Transparency = 1})
	part(model, "Ring", Vector3.new(0.4, DISC_RADIUS * 2, DISC_RADIUS * 2),
		CFrame.Angles(0, 0, math.rad(90)), {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.ForceField,
			Color = BLOOD,
			Transparency = 0.2,
		})
	emitter(center, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(110, 90, 80)),
		Size = grow(4, 9),
		Transparency = fade(0.2),
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(40, 55),
		SpreadAngle = Vector2.new(80, 80),
		Drag = 3,
		Rate = 240,
	})
	emitter(center, {
		Texture = SPARKLE,
		Color = ColorSequence.new(BLOOD),
		Size = shrink(1.2),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(30, 50),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -80, 0),
		Rate = 120,
	})
	return center
end

-- Two pins staked into the ground with a thin wire strung between them. Spans the same 14 studs as
-- Constants.Tomino.PinTrap.TriggerPadSize.X; the wire runs across his facing (local X).
local TRAP_WIDTH = 14
RECIPES.TominoPinTrap = function(model)
	local wire = part(model, "Wire", Vector3.new(TRAP_WIDTH, 0.12, 0.12), CFrame.new(0, 0.9, 0), {
		Color = PIN_METAL,
		Material = Enum.Material.Metal,
		Transparency = 0.25,
	})
	for _, side in ipairs({-1, 1}) do
		local x = side * TRAP_WIDTH / 2
		part(model, "Pin", Vector3.new(0.3, 3, 0.3), CFrame.new(x, 0, 0), {
			Color = PIN_METAL,
			Material = Enum.Material.Metal,
		})
		part(model, "PinHead", Vector3.new(0.8, 0.8, 0.8), CFrame.new(x, 1.6, 0), {
			Shape = Enum.PartType.Ball,
			Color = PIN_HEAD,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	return wire
end

-- The wire snapping when a survivor walks into it.
RECIPES.TominoPinTrapTrip = function(model)
	local core = part(model, "Core", Vector3.new(TRAP_WIDTH, 1, 1), nil, {Transparency = 1})
	emitter(core, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(230, 225, 220), PIN_HEAD),
		Size = shrink(1),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -40, 0),
		Rate = 120,
		LightEmission = 0.5,
	})
	return core
end

-- The pin in flight: a big hatpin trailing blood drops. Rides an invisible mover part that
-- Tomino.lua moves along the throw arc.
RECIPES.TominoBombPinThrow = function(model)
	local shaft = part(model, "Shaft", Vector3.new(0.5, 5, 0.5), nil, {
		Color = PIN_METAL,
		Material = Enum.Material.Metal,
	})
	part(model, "PinHead", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 2.8, 0), {
		Shape = Enum.PartType.Ball,
		Color = PIN_HEAD,
		Material = Enum.Material.SmoothPlastic,
	})
	emitter(shaft, {
		Texture = SPARKLE,
		Color = ColorSequence.new(BLOOD, DARK_BLOOD),
		Size = shrink(0.7),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(0, 1),
		Acceleration = Vector3.new(0, -50, 0),
		Rate = 60,
	})
	return shaft
end

-- The blood patch. Sized to Constants.Tomino.BombPin.PoolRadiusStuds (10), bubbling for its life.
local POOL_RADIUS = 10
RECIPES.TominoBombPin = function(model)
	local bubbles = part(model, "Bubbles", Vector3.new(POOL_RADIUS * 1.6, 0.2, POOL_RADIUS * 1.6), nil, {
		Transparency = 1,
	})
	part(model, "Pool", Vector3.new(0.3, POOL_RADIUS * 2, POOL_RADIUS * 2),
		CFrame.Angles(0, 0, math.rad(90)), {
			Shape = Enum.PartType.Cylinder,
			Color = DARK_BLOOD,
			Material = Enum.Material.Glass,
			Transparency = 0.1,
			Reflectance = 0.15,
		})
	emitter(bubbles, {
		Texture = SPARKLE,
		Color = ColorSequence.new(BLOOD),
		Size = grow(0.4, 1.2),
		Transparency = fade(0.1),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(10, 10),
		Rate = 25,
	})
	emitter(bubbles, {
		Texture = SMOKE,
		Color = ColorSequence.new(DARK_BLOOD),
		Size = grow(3, 6),
		Transparency = fade(0.6),
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(1, 2),
		Rate = 6,
	})
	return bubbles
end

-------------------------------------------------------------------------------
-- MOMOTARO (peach + gold, clean white steel)
-------------------------------------------------------------------------------
local PEACH = Color3.fromRGB(248, 184, 146)
local PEACH_PINK = Color3.fromRGB(239, 144, 128)
local GOLD = Color3.fromRGB(255, 214, 120)
local STEEL = Color3.fromRGB(255, 255, 255)
local DUST = Color3.fromRGB(150, 130, 105)
local BANANA = Color3.fromRGB(245, 215, 70)

-- The glint on his blade during the half-second windup: one big star and a scatter of sparkle.
RECIPES.MomotaroKatanaWindup = function(model)
	local c = core(model)
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(STEEL),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 7),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.5),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(180),
		LightEmission = 1,
	}, 1)
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(STEEL, GOLD),
		Size = shrink(1.2),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(3, 8),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
	}, 14)
	return c
end

-- The burst he leaves behind as the dash launches: a peach-tinted gust and a kick of dust.
RECIPES.MomotaroKatanaSwing = function(model)
	local c = core(model)
	emitter(c, {
		Texture = SMOKE,
		Color = ColorSequence.new(DUST),
		Size = grow(3, 8),
		Transparency = fade(0.4),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(10, 18),
		SpreadAngle = Vector2.new(180, 20),
		Acceleration = Vector3.new(0, 4, 0),
		Drag = 4,
	}, 12)
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(STEEL, PEACH_PINK),
		Size = shrink(1.4),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.2, 0.35),
		Speed = NumberRange.new(20, 30),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 5,
		LightEmission = 0.8,
	}, 20)
	return c
end

-- The katana landing on a Yokai: a white flash with peach and gold sparks.
RECIPES.MomotaroKatanaHit = function(model)
	local c = core(model)
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(STEEL),
		Size = shrink(9),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.2),
		Speed = NumberRange.new(0),
		LightEmission = 1,
	}, 1)
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(STEEL, PEACH),
		Size = shrink(1.5),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(25, 40),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		LightEmission = 1,
	}, 30)
	return c
end

-- Dust thrown up where the two dogs drop in.
RECIPES.MomotaroInutaDeploy = function(model)
	local c = core(model, Vector3.new(8, 1, 3))
	emitter(c, {
		Texture = SMOKE,
		Color = ColorSequence.new(DUST),
		Size = grow(3, 7),
		Transparency = fade(0.3),
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 30),
		Drag = 3,
	}, 16)
	return c
end

-- A bark you can see: a quick ring of pale puffs from the guard post, once per bark.
RECIPES.MomotaroInutaBark = function(model)
	local c = core(model)
	emitter(c, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(245, 235, 220)),
		Size = grow(1.5, 4),
		Transparency = fade(0.3),
		Lifetime = NumberRange.new(0.35, 0.5),
		Speed = NumberRange.new(20, 26),
		SpreadAngle = Vector2.new(80, 80),
		Drag = 2,
	}, 14)
	return c
end

-- Crumbs and banana bits while Saru eats; runs the whole SaruEatSeconds.
RECIPES.MomotaroSaruEat = function(model)
	local c = core(model, Vector3.new(3, 3, 3))
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(BANANA, Color3.fromRGB(200, 160, 60)),
		Size = shrink(1.8),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -40, 0),
		LightEmission = 0.4,
		Rate = 40,
	})
	return c
end

-- A little poof as the peel lands.
RECIPES.MomotaroBananaDrop = function(model)
	local c = core(model)
	emitter(c, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(235, 225, 190)),
		Size = grow(1.5, 4),
		Transparency = fade(0.4),
		Lifetime = NumberRange.new(0.5, 0.7),
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(180, 20),
		Drag = 3,
	}, 8)
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(BANANA),
		Size = shrink(1),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(6, 10),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -30, 0),
		LightEmission = 0.4,
	}, 8)
	return c
end

-------------------------------------------------------------------------------
-- ROKUROKUBI (geisha white, black smoke, dark red)
-------------------------------------------------------------------------------
local GEISHA_WHITE = Color3.fromRGB(245, 227, 212)
local ROKU_RED = Color3.fromRGB(178, 34, 34)
local INK = Color3.fromRGB(26, 10, 14)
local SMOKE_RED = Color3.fromRGB(70, 12, 22)

-- Her effects start at her root, which sits deep inside a large floating body. Emitting from a
-- volume bigger than her body, with some outward speed, is what gets particles out where they
-- show; small slow emitters sat hidden inside her kimono.
local ROKU_BODY = Vector3.new(12, 16, 12)

-- Black wisps coiling around her for the whole 2-second windup, so a Warden sees the strike coming.
RECIPES.RokurokubiNeckWrapWindup = function(model)
	local c = core(model, ROKU_BODY)
	emitter(c, {
		Texture = SMOKE,
		Color = ColorSequence.new(SMOKE_RED, INK),
		Size = grow(4, 8),
		Transparency = fade(0.2),
		Lifetime = NumberRange.new(0.7, 1.1),
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(180, 180),
		RotSpeed = NumberRange.new(-120, 120),
		Rotation = NumberRange.new(0, 360),
		Acceleration = Vector3.new(0, 4, 0),
		Rate = 40,
	})
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(ROKU_RED),
		Size = shrink(1.6),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.8,
		Rate = 25,
	})
	return c
end

-- The grab landing: a slam of black smoke with red flecks around the victim.
RECIPES.RokurokubiNeckWrapHit = function(model)
	local c = core(model)
	emitter(c, {
		Texture = SMOKE,
		Color = ColorSequence.new(INK),
		Size = grow(3, 7),
		Transparency = fade(0.2),
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
	}, 14)
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(ROKU_RED),
		Size = shrink(1.2),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(15, 25),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		LightEmission = 0.6,
	}, 16)
	return c
end

-- Her bite: a red flash, pale "teeth" glints, and a blood spray big and bright enough to clear the victim's body.
RECIPES.RokurokubiBite = function(model)
	local c = core(model, Vector3.new(5, 6, 5))
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 60, 60)),
		Size = shrink(8),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.2),
		Speed = NumberRange.new(0),
		LightEmission = 1,
	}, 1)
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(GEISHA_WHITE),
		Size = shrink(3),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.25, 0.4),
		Speed = NumberRange.new(15, 25),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		LightEmission = 1,
	}, 8)
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(190, 15, 25), BLOOD),
		Size = shrink(1.8),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(15, 25),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -60, 0),
		LightEmission = 0.3,
	}, 30)
	return c
end

-- Pale mist rising off her through the whole 5-second charge-up (she's frozen, so it's her tell).
RECIPES.RokurokubiDisguiseChargeUp = function(model)
	local c = core(model, ROKU_BODY)
	emitter(c, {
		Texture = SMOKE,
		Color = ColorSequence.new(GEISHA_WHITE),
		Size = grow(4, 9),
		Transparency = fade(0.3),
		Lifetime = NumberRange.new(1.2, 1.8),
		Speed = NumberRange.new(4, 7),
		SpreadAngle = Vector2.new(40, 40),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		Rate = 30,
	})
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(GEISHA_WHITE, ROKU_RED),
		Size = shrink(1.5),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(60, 60),
		LightEmission = 0.7,
		Rate = 20,
	})
	return c
end

-- The disguise breaking: a puff of pale smoke with red cracks through it.
RECIPES.RokurokubiDisguiseEnded = function(model)
	local c = core(model)
	emitter(c, {
		Texture = SMOKE,
		Color = ColorSequence.new(GEISHA_WHITE),
		Size = grow(3, 8),
		Transparency = fade(0.3),
		Lifetime = NumberRange.new(0.7, 1),
		Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
	}, 16)
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(ROKU_RED),
		Size = shrink(1.4),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(18, 28),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		LightEmission = 0.7,
	}, 18)
	return c
end

-- The choke: dark smoke tightening around the victim for the whole ChokeSeconds.
RECIPES.RokurokubiStrangle = function(model)
	local c = core(model, Vector3.new(8, 12, 8))
	emitter(c, {
		Texture = SMOKE,
		Color = ColorSequence.new(SMOKE_RED, INK),
		Size = grow(5, 2),
		Transparency = fade(0.2),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(1, 2),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-200, 200),
		Rate = 35,
	})
	return c
end

-------------------------------------------------------------------------------
-- GIRL A (screen glow: cyan and white)
-------------------------------------------------------------------------------
local SCREEN_CYAN = Color3.fromRGB(90, 230, 255)

-- Arriving at a Hotspot: a flash of screen light and a scatter of glitchy cyan sparks.
RECIPES.GirlAHotspotTeleport = function(model)
	local c = core(model, Vector3.new(3, 8, 3))
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(STEEL),
		Size = shrink(10),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.25),
		Speed = NumberRange.new(0),
		LightEmission = 1,
	}, 1)
	emitter(c, {
		Texture = SPARKLE,
		Color = ColorSequence.new(SCREEN_CYAN, STEEL),
		Size = shrink(1.3),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(10, 20),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 5,
		LightEmission = 1,
	}, 30)
	return c
end

local ADDONS = {}

-- Girl A's hatchet landing: hot sparks off the blade plus a blood spray. Rides on the kids'
-- GirlASlashHit part next to their hit sound. EffectsService deletes this effect after 0.8s
-- (LIFETIMES.GirlASlashHit), so every particle here dies inside that.
ADDONS.GirlASlashHit = function(attachment)
	emitter(attachment, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 245, 210), Color3.fromRGB(255, 150, 60)),
		Size = shrink(1.6),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(25, 40),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		Rate = 120,
		LightEmission = 1,
	})
	emitter(attachment, {
		Texture = SPARKLE,
		Color = ColorSequence.new(BLOOD, DARK_BLOOD),
		Size = shrink(1.1),
		Transparency = fade(0),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(10, 20),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -60, 0),
		Rate = 100,
	})
end

local built, skipped = {}, {}
for name, recipe in pairs(RECIPES) do
	local existing = effects:FindFirstChild(name)
	if existing and not existing:GetAttribute("BuiltByTool") then
		table.insert(skipped, name)
	else
		if existing then existing:Destroy() end
		local model = Instance.new("Model")
		model.Name = name
		model.PrimaryPart = recipe(model)
		model:SetAttribute("BuiltByTool", true)
		model.Parent = effects
		table.insert(built, name)
	end
end

local missing = {}
for name, addon in pairs(ADDONS) do
	local template = effects:FindFirstChild(name)
	local host = template and (template:IsA("BasePart") and template
		or (template:IsA("Model") and template.PrimaryPart)
		or template:FindFirstChildWhichIsA("BasePart", true))
	if not host then
		table.insert(missing, name)
	else
		for _, old in ipairs(template:GetDescendants()) do
			if old.Name == "CodeVisual" and old:GetAttribute("BuiltByTool") then old:Destroy() end
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "CodeVisual"
		attachment:SetAttribute("BuiltByTool", true)
		attachment.Parent = host
		addon(attachment)
		table.insert(built, name .. " (add-on)")
	end
end

table.sort(built)
table.sort(skipped)
print("[build-effects] built: " .. (#built > 0 and table.concat(built, ", ") or "none"))
if #missing > 0 then
	warn("[build-effects] add-on skipped, no template with a part to attach to: " .. table.concat(missing, ", "))
end
if #skipped > 0 then
	warn("[build-effects] skipped (hand-built template already there, left alone): " .. table.concat(skipped, ", "))
end
