-- CharacterPickerUI.client.lua
-- The character-select screen. ONE screen serves both roles -- it themes itself red for the Yokai
-- (killer) pick and light-blue for the Warden (survivor) pick, based on what the server tells it.
--
-- HOW IT TALKS TO THE SERVER (do not change this contract):
--   * Server fires Remotes.CharacterPicker with a LIST of character keys + a role ("Yokai"/"Warden")
--     -> we theme the screen and show a card per key.
--   * Player clicks a card -> we fire the same remote back with that key, then lock the screen.
--   * Server fires the remote with `nil` -> we close (the round is starting).
-- The server gives the player up to 10 seconds, then auto-picks. Our on-screen clock mirrors that.
--
-- The look matches mockups/killer-select.html: a dark full-screen panel, "Choose Your YOKAI/WARDEN"
-- with a countdown under it, and one card per character. Each card has a slowly-spinning 3D model of
-- the real costume that peeks up above the box, the role word over the name, an accent hover, and a
-- chosen state where the card's chin (the name strip) fills with the accent color.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")

local localPlayer    = Players.LocalPlayer
local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local CharacterPicker = Remotes:WaitForChild("CharacterPicker")

----------------------------------------------------------------------------------------------------
-- TUNABLES — change these first; everything else follows from them.
-- (Same idea as the :root variables at the top of the HTML mockup.)
----------------------------------------------------------------------------------------------------

local CONFIG = {
	-- How many seconds the clock counts down from. Keep this matching the server's
	-- pickTimeoutSeconds in RoundService:_askPlayerToPick (currently 10) so the clock is honest.
	pickSeconds = 10,

	-- Card size (pixels) and spacing.
	cardWidth  = 300,
	cardHeight = 380,   -- portrait area; the chin (name strip) is added below this
	cardGap    = 28,

	-- How far the 3D model is allowed to poke ABOVE the top of the card (pixels).
	avatarPeek = 70,

	-- Gap (px) between the bottom of the title/countdown block and where the avatars peek over the
	-- cards. Bigger = title sits higher. (The avatars cap how low the title can go.)
	headerGap = 28,

	-- Portrait camera framing. Per-character zoom/drop lives in the CAMERA table below; these are global.
	cameraDistanceMult = 2.4,    -- bigger = model smaller in the box
	cameraAimFrac      = 0.05,   -- look slightly above the framing center (fraction of model size)
	cameraEyeFrac      = 0.10,   -- camera floats a bit above the look point
	fieldOfView        = 28,
	spinSpeed          = 0.6,    -- radians/sec turntable spin

	-- Card background = the uploaded diagonal-stripe tile. tileSize sets stripe thickness on screen
	-- (smaller = finer stripes). The source tile is 128px and tiles seamlessly.
	stripeImage = "rbxassetid://119070341954890",
	stripeTile  = 64,

	-- Lock icon for the "coming soon" card (source is 160x160; we draw it smaller via lockSize).
	lockImage   = "rbxassetid://127360932839161",
	lockSize    = 84,

	-- Height of the chin (the name strip) at the bottom of each card.
	chinHeight  = 88,

	-- Show a trailing locked "coming soon" card after the real options.
	showLockedSlot = true,

	-- Fonts. titleFont = the gothic display font (Grenze Gotisch, built into Roblox) for the title
	-- + character names; bodyFont = clean sans for "KILLER" and the countdown.
	titleFont = Enum.Font.GrenzeGotisch,
	bodyFont  = Enum.Font.GothamBold,
}

-- COLORS (translated straight from the mockup's hex values).
local COLOR = {
	bgDarkest   = Color3.fromRGB(10, 6, 8),     -- page background, almost black
	panel       = Color3.fromRGB(22, 13, 18),   -- a card
	panelDeep   = Color3.fromRGB(13, 7, 10),    -- bottom of the card gradient
	ink         = Color3.fromRGB(243, 233, 236),-- main text
	inkDim      = Color3.fromRGB(154, 138, 144),-- secondary text
	blood       = Color3.fromRGB(177, 36, 43),  -- the danger / killer accent
	bloodBright = Color3.fromRGB(255, 59, 65),  -- hover + chosen glow
	borderDark  = Color3.fromRGB(120, 60, 68),  -- resting card border (light enough to actually see)
	black       = Color3.fromRGB(0, 0, 0),       -- role word on the chosen (filled) chin
}

-- Two looks for the SAME screen. The server tells us which role is being picked; everything tinted
-- by the theme's accent follows. Yokai = the original blood red; Warden = light blue. The wording
-- changes too (YOKAI/KILLER vs WARDEN/SURVIVOR), so the two screens read differently even at a glance.
local THEMES = {
	Yokai = {
		titleWord    = "YOKAI",
		titleHex     = "#ff3b41",
		roleWord     = "KILLER",
		clockLead    = "THE HUNT BEGINS IN",
		accent       = COLOR.blood,                    -- chin fill on hover/select
		accentBright = COLOR.bloodBright,              -- role word + countdown + bright border
		border       = COLOR.borderDark,               -- resting card border
	},
	Warden = {
		titleWord    = "WARDEN",
		titleHex     = "#7cc0ff",
		roleWord     = "SURVIVOR",
		clockLead    = "PROTECT THE TOWN IN",
		accent       = Color3.fromRGB(46, 120, 190),   -- light blue
		accentBright = Color3.fromRGB(124, 192, 255),  -- bright light blue
		border       = Color3.fromRGB(54, 92, 130),    -- bluish resting border
	},
}
-- The theme in force for the screen that's currently open. open() sets this before building cards.
local activeTheme = THEMES.Yokai

-- Display names per character key (the key "GirlA" should read "Girl A").
local LABELS = {
	Momotaro   = "Momotaro",
	Otohime    = "Otohime",
	Rokurokubi = "Rokurokubi",
	GirlA      = "Girl A",
}

-- Per-character framing tweaks on top of the automatic fit.
--   zoom: >1 = smaller/further, <1 = bigger/closer.
--   drop: studs to shift the model DOWN in the box (raises the camera's look point).
--   face: degrees to turn the model so its FRONT points at the camera (some models were built
--         facing the other way). 180 = spin it halfway around.
local CAMERA = {
	GirlA      = { zoom = 1.15, drop = 0 },    -- a touch smaller
	Rokurokubi = { zoom = 0.7,  drop = 0.8 },  -- bigger, and nudged down
	Momotaro   = { zoom = 1.0,  drop = 0 },
	Otohime    = { zoom = 1.0,  drop = 0, face = 180 },  -- built facing away; turn her to face us
}
local DEFAULT_CAM = { zoom = 1.0, drop = 0, face = 0 }

----------------------------------------------------------------------------------------------------
-- Build the parts of the screen that never change (backdrop, title, countdown).
-- Cards get built fresh every time the picker opens, because the option list can differ.
----------------------------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CharacterPicker"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 50
-- Sibling ZIndex = children always draw above their parent, and ZIndex only sorts among siblings.
-- That's what makes "model behind the chin, model above the card background" work reliably.
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

-- Full-screen dark backdrop.
local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = COLOR.bgDarkest
-- Mostly opaque + dark, with only a subtle hint of the scene showing through behind it.
backdrop.BackgroundTransparency = 0.25
backdrop.BorderSizePixel = 0
backdrop.Parent = screenGui

-- A soft red glow across the top, approximating the mockup's radial glow (Roblox gradients are
-- linear, so this fades red->clear downward rather than as a true radial).
local topGlow = Instance.new("Frame")
topGlow.Size = UDim2.new(1, 0, 0.45, 0)
topGlow.BackgroundColor3 = COLOR.blood
topGlow.BorderSizePixel = 0
topGlow.ZIndex = 0
topGlow.Parent = backdrop
local glowGrad = Instance.new("UIGradient")
glowGrad.Rotation = 90
glowGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.88),
	NumberSequenceKeypoint.new(1, 1),
})
glowGrad.Parent = topGlow

-- Small game title, top-left.
local gameTitle = Instance.new("TextLabel")
gameTitle.Size = UDim2.fromOffset(360, 30)
gameTitle.Position = UDim2.fromOffset(34, 22)
gameTitle.BackgroundTransparency = 1
gameTitle.Text = "BELIEVE THE TRUTH"
gameTitle.TextColor3 = COLOR.inkDim
gameTitle.TextXAlignment = Enum.TextXAlignment.Left
gameTitle.TextSize = 16
gameTitle.Font = CONFIG.titleFont
gameTitle.Parent = backdrop

-- Centered header block: title + countdown sit just above the cards.
-- We anchor the header above screen-center and the card row at center so the spacing feels like
-- the mockup (tight gap title->clock, big gap clock->cards).
local header = Instance.new("Frame")
header.Size = UDim2.fromOffset(1000, 156)
header.AnchorPoint = Vector2.new(0.5, 1)   -- anchored by its BOTTOM
-- Sit the header just above where the avatars peek over the cards (cards are centered on screen).
header.Position = UDim2.new(0.5, 0, 0.5,
	-(CONFIG.cardHeight / 2 + CONFIG.avatarPeek + CONFIG.headerGap))
header.BackgroundTransparency = 1
header.Parent = backdrop

-- Title in the gothic display font. "Yokai" is bright red via RichText.
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 96)
titleLabel.Position = UDim2.fromScale(0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.RichText = true
titleLabel.Text = 'CHOOSE YOUR <font color="#ff3b41">YOKAI</font>'
titleLabel.TextColor3 = COLOR.ink
titleLabel.TextSize = 90
titleLabel.Font = CONFIG.titleFont
titleLabel.Parent = header

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Size = UDim2.new(1, 0, 0, 40)
countdownLabel.Position = UDim2.fromOffset(0, 108)   -- tight gap under the title
countdownLabel.BackgroundTransparency = 1
countdownLabel.RichText = true
countdownLabel.TextColor3 = COLOR.bloodBright
countdownLabel.TextSize = 18
countdownLabel.Font = CONFIG.bodyFont
countdownLabel.Parent = header

-- The row that holds the cards, centered on screen.
local cardRow = Instance.new("Frame")
cardRow.AnchorPoint = Vector2.new(0.5, 0.5)
cardRow.Position = UDim2.fromScale(0.5, 0.5)
cardRow.Size = UDim2.fromOffset(100, CONFIG.cardHeight + 80) -- width set when we know option count
cardRow.BackgroundTransparency = 1
cardRow.ClipsDescendants = false  -- let avatars peek above the cards
cardRow.Parent = backdrop

local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rowLayout.Padding = UDim.new(0, CONFIG.cardGap)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = cardRow

-- Re-skin the always-on parts (title text/color, countdown color, top glow) for the given role.
-- Cards read `activeTheme` directly when they're built, so this must run before we build them.
local function applyTheme(role)
	activeTheme = THEMES[role] or THEMES.Yokai
	titleLabel.Text = string.format('CHOOSE YOUR <font color="%s">%s</font>',
		activeTheme.titleHex, activeTheme.titleWord)
	countdownLabel.TextColor3 = activeTheme.accentBright
	topGlow.BackgroundColor3 = activeTheme.accent
end

----------------------------------------------------------------------------------------------------
-- Bookkeeping so we can tidy up every connection when the screen closes (no leaks).
----------------------------------------------------------------------------------------------------

local liveConnections = {}   -- spin loops + the countdown loop
local locked = false         -- true once the player has picked (stops further clicks)

local function track(conn)
	table.insert(liveConnections, conn)
	return conn
end

local function clearCardsAndLoops()
	for _, conn in ipairs(liveConnections) do
		conn:Disconnect()
	end
	table.clear(liveConnections)
	for _, child in ipairs(cardRow:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

----------------------------------------------------------------------------------------------------
-- Build one 3D portrait. Returns the ViewportFrame so the caller can place it.
-- We render the REAL dressed model from ReplicatedStorage.CharacterModels with a slow turntable spin.
-- The viewport is transparent and taller than the card, so the model appears to float above the box.
----------------------------------------------------------------------------------------------------

-- The framing box for the portrait. Normally the model's full bounding box, BUT if the model has a
-- stretchy neck chain we exclude the neck segments + the head on top of it -- otherwise the long
-- neck inflates the box and the camera zooms the whole character out tiny. With it excluded, the
-- body frames nicely and the neck just runs up out of the top of the box.
local function framingBox(model)
	local neck = model:FindFirstChild("NeckChain", true)
	if neck then
		local minV, maxV
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and not p:IsDescendantOf(neck) and p.Name ~= "Head" then
				local lo = p.Position - p.Size * 0.5
				local hi = p.Position + p.Size * 0.5
				minV = minV and minV:Min(lo) or lo
				maxV = maxV and maxV:Max(hi) or hi
			end
		end
		if minV then
			local size = maxV - minV
			return (minV + maxV) * 0.5, math.max(size.X, size.Y, size.Z)
		end
	end
	local cf, size = model:GetBoundingBox()
	return cf.Position, math.max(size.X, size.Y, size.Z)
end

local function buildViewport(characterKey)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	-- Covers the PORTRAIT area (card minus the chin) plus a peek above the card top. The viewport's
	-- own rectangle crops the model at the seam, so the figure stands "behind" the name strip.
	viewport.Size = UDim2.new(1, 0, 0, (CONFIG.cardHeight - CONFIG.chinHeight) + CONFIG.avatarPeek)
	viewport.Position = UDim2.new(0, 0, 0, -CONFIG.avatarPeek)
	viewport.ZIndex = 12   -- ABOVE the borders, so the model peeks over the top edge (not behind it)

	-- Viewports have their own little lighting rig; without this, models render almost black.
	viewport.Ambient = Color3.fromRGB(120, 118, 124)
	viewport.LightColor = Color3.fromRGB(255, 245, 245)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.55)

	local modelsFolder = ReplicatedStorage:FindFirstChild("CharacterModels")
	local source = modelsFolder and modelsFolder:FindFirstChild(characterKey)
	if not source then
		-- No model yet (or not exported): leave the viewport empty rather than erroring.
		return viewport
	end

	-- A WorldModel makes models (with humanoids/welds) display correctly inside a ViewportFrame.
	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local model = source:Clone()
	-- Strip anything that would try to "run" or animate; a portrait is a frozen pose.
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Parent = world

	-- Stand the camera back from the framing box (neck excluded), with a small upward aim/float.
	local center, extent = framingBox(model)
	local camCfg = CAMERA[characterKey] or DEFAULT_CAM
	local distance = extent * CONFIG.cameraDistanceMult * camCfg.zoom
	-- Look a bit above center; `drop` raises the look point further so the model sits lower in the box.
	local lookAt = center + Vector3.new(0, extent * CONFIG.cameraAimFrac + camCfg.drop, 0)
	local camPos = lookAt + Vector3.new(0, extent * CONFIG.cameraEyeFrac, distance)

	local camera = Instance.new("Camera")
	camera.FieldOfView = CONFIG.fieldOfView
	camera.CFrame = CFrame.lookAt(camPos, lookAt)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- Slow turntable spin around the model's own vertical axis. We first turn the model by `face` so
	-- its front points at the camera (some models were built facing away), then spin from there.
	local basePivot = model:GetPivot() * CFrame.Angles(0, math.rad(camCfg.face or 0), 0)
	local angle = 0
	track(RunService.RenderStepped:Connect(function(dt)
		angle += dt * CONFIG.spinSpeed
		model:PivotTo(basePivot * CFrame.Angles(0, angle, 0))
	end))

	return viewport
end

----------------------------------------------------------------------------------------------------
-- Build one card (background + portrait + chin) and wire its hover / click behavior.
----------------------------------------------------------------------------------------------------

local function buildCard(characterKey, layoutOrder, isLocked)
	-- The card is a button so the whole thing is clickable; we handle our own hover colors.
	local card = Instance.new("TextButton")
	card.Name = isLocked and "Locked" or characterKey
	card.AutoButtonColor = false
	card.Text = ""
	card.Size = UDim2.fromOffset(CONFIG.cardWidth, CONFIG.cardHeight)
	card.BackgroundTransparency = 1   -- the rounded panel look comes from `content` below
	card.BorderSizePixel = 0
	card.ClipsDescendants = false      -- so the avatar can peek above the card
	card.LayoutOrder = layoutOrder
	card.Parent = cardRow

	-- CONTENT: a clipped, rounded container. Because it clips, the portrait + chin keep SQUARE
	-- corners and the seam between them stays straight -- only the OUTER corners round. (This is what
	-- fixes the odd rounded notch where the chin met the portrait.)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundColor3 = COLOR.panel
	content.BorderSizePixel = 0
	content.ClipsDescendants = true
	content.ZIndex = 1
	content.Parent = card
	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 14)
	contentCorner.Parent = content

	-- Portrait background = the tiled stripe (square; the content clip rounds the visible corners).
	local portraitBg = Instance.new("ImageLabel")
	portraitBg.Size = UDim2.new(1, 0, 1, -CONFIG.chinHeight)
	portraitBg.BackgroundColor3 = COLOR.panelDeep
	portraitBg.BorderSizePixel = 0
	portraitBg.Image = CONFIG.stripeImage
	portraitBg.ScaleType = Enum.ScaleType.Tile
	portraitBg.TileSize = UDim2.fromOffset(CONFIG.stripeTile, CONFIG.stripeTile)
	portraitBg.ZIndex = 1
	portraitBg.Parent = content

	-- The chin (name strip). Square corners; the content clip rounds the bottom outer corners.
	local chin = Instance.new("Frame")
	chin.AnchorPoint = Vector2.new(0, 1)
	chin.Position = UDim2.fromScale(0, 1)
	chin.Size = UDim2.new(1, 0, 0, CONFIG.chinHeight)
	chin.BackgroundColor3 = COLOR.panel
	chin.BorderSizePixel = 0
	chin.ZIndex = 3
	chin.Parent = content

	local roleLabel = Instance.new("TextLabel")
	roleLabel.Size = UDim2.new(1, -36, 0, 14)
	roleLabel.Position = UDim2.fromOffset(18, 12)
	roleLabel.BackgroundTransparency = 1
	roleLabel.Text = isLocked and "COMING SOON" or activeTheme.roleWord
	roleLabel.TextXAlignment = Enum.TextXAlignment.Left
	roleLabel.TextColor3 = activeTheme.accentBright
	roleLabel.TextSize = 11
	roleLabel.Font = CONFIG.bodyFont
	roleLabel.ZIndex = 3
	roleLabel.Parent = chin

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -32, 0, 54)
	nameLabel.Position = UDim2.fromOffset(18, 28)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = isLocked and "??????" or (LABELS[characterKey] or characterKey)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = COLOR.ink
	nameLabel.TextScaled = true   -- fills the taller chin; capped below so long names won't overflow
	nameLabel.Font = CONFIG.titleFont
	nameLabel.ZIndex = 3
	nameLabel.Parent = chin
	local nameMax = Instance.new("UITextSizeConstraint")
	nameMax.MaxTextSize = 52
	nameMax.Parent = nameLabel

	-- Portrait contents: the real 3D model, OR (locked card) a centered lock icon.
	if isLocked then
		local lock = Instance.new("ImageLabel")
		lock.AnchorPoint = Vector2.new(0.5, 0.5)
		lock.Position = UDim2.new(0.5, 0, 0.5, -CONFIG.chinHeight / 2)
		lock.Size = UDim2.fromOffset(CONFIG.lockSize, CONFIG.lockSize)
		lock.BackgroundTransparency = 1
		lock.Image = CONFIG.lockImage
		lock.ImageColor3 = COLOR.inkDim
		lock.ZIndex = 2
		lock.Parent = content
	else
		buildViewport(characterKey).Parent = card   -- sibling of `content`, so it can peek above
	end

	-- A dim overlay over the whole card (greys out the locked card, and the non-chosen cards once a
	-- pick is made). Child of the card so it covers the 3D model too; sits under the borders.
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = COLOR.bgDarkest
	dim.BackgroundTransparency = isLocked and 0.5 or 1
	dim.BorderSizePixel = 0
	dim.ZIndex = 6
	dim.Parent = card
	local dimCorner = Instance.new("UICorner")
	dimCorner.CornerRadius = UDim.new(0, 14)
	dimCorner.Parent = dim

	-- DOUBLE BORDER: two concentric rounded outlines (outer + a thinner, fainter inner line just
	-- inside it) on transparent frames ABOVE everything, so the strokes aren't covered.
	local function makeBorder(inset, radius, thickness, transparency, z)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
		f.BackgroundTransparency = 1
		f.ZIndex = z
		f.Parent = card
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = f
		local s = Instance.new("UIStroke")
		s.Thickness = thickness
		s.Color = activeTheme.border
		s.Transparency = transparency
		s.Parent = f
		return s
	end
	local strokeOuter = makeBorder(0, 14, 2, 0, 10)
	local strokeInner = makeBorder(5, 9, 1, 0.35, 11)

	-- The locked card is a static, dimmed "coming soon" -- no hover/click behavior.
	if isLocked then
		return
	end

	local quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad)
	local isChosen = false

	local function setBorder(color)
		TweenService:Create(strokeOuter, quick, { Color = color }):Play()
		TweenService:Create(strokeInner, quick, { Color = color }):Play()
	end

	-- On hover/select, ONLY the chin + border change to the theme accent -- the striped portrait
	-- stays as-is. (Red for Yokai, light blue for Wardens.)
	local function setAccent(on)
		TweenService:Create(chin, quick, { BackgroundColor3 = on and activeTheme.accent or COLOR.panel }):Play()
		setBorder(on and activeTheme.accentBright or activeTheme.border)
		roleLabel.TextColor3 = on and COLOR.black or activeTheme.accentBright
	end

	card.MouseEnter:Connect(function()
		if locked or isChosen then return end
		setAccent(true)
	end)
	card.MouseLeave:Connect(function()
		if locked or isChosen then return end
		setAccent(false)
	end)

	-- Click: lock the screen, fire the choice, keep THIS card highlighted, and dim the others.
	card.MouseButton1Click:Connect(function()
		if locked then return end
		locked = true
		isChosen = true
		CharacterPicker:FireServer(characterKey)
		setAccent(true)

		for _, other in ipairs(cardRow:GetChildren()) do
			if other ~= card and other:IsA("TextButton") then
				local otherDim = other:FindFirstChild("Dim")
				if otherDim then
					TweenService:Create(otherDim, quick, { BackgroundTransparency = 0.55 }):Play()
				end
			end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- The on-screen countdown. We just count down locally from CONFIG.pickSeconds; the server is the
-- real authority and will fire `nil` to close us when time is actually up.
----------------------------------------------------------------------------------------------------

local function formatClock(seconds)
	local s = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function setCountdownText(seconds)
	-- Whole line is the accent color; the clock is bold + bigger so it pops (matches the mockup).
	-- The lead-in wording is themed: "THE HUNT BEGINS IN" for Yokai, "PROTECT THE TOWN IN" for Wardens.
	countdownLabel.Text = string.format(
		'%s <font size="28"><b>%s</b></font>', activeTheme.clockLead, formatClock(seconds))
end

local function startCountdown()
	local remaining = CONFIG.pickSeconds
	local shown = -1
	setCountdownText(remaining)
	track(RunService.Heartbeat:Connect(function(dt)
		remaining = math.max(0, remaining - dt)
		local whole = math.floor(remaining + 0.5)
		if whole ~= shown then
			shown = whole
			setCountdownText(remaining)
		end
	end))
end

----------------------------------------------------------------------------------------------------
-- Open / close, and the remote handler.
----------------------------------------------------------------------------------------------------

local function open(options, role)
	clearCardsAndLoops()
	locked = false

	-- Theme the screen for this role BEFORE building cards (cards read activeTheme as they're built).
	applyTheme(role)

	-- Total cards = the server's options + an optional trailing locked "coming soon" slot.
	local count = #options + (CONFIG.showLockedSlot and 1 or 0)
	cardRow.Size = UDim2.fromOffset(
		count * CONFIG.cardWidth + math.max(0, count - 1) * CONFIG.cardGap,
		CONFIG.cardHeight + CONFIG.avatarPeek + 20)

	for i, characterKey in ipairs(options) do
		buildCard(characterKey, i, false)
	end
	if CONFIG.showLockedSlot then
		buildCard(nil, #options + 1, true)
	end

	startCountdown()
	screenGui.Enabled = true
end

local function close()
	screenGui.Enabled = false
	clearCardsAndLoops()
end

CharacterPicker.OnClientEvent:Connect(function(optionsOrNil, role)
	if optionsOrNil == nil then
		close()
	elseif type(optionsOrNil) == "table" then
		open(optionsOrNil, role)
	end
end)
