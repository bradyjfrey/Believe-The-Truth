-- CharacterPickerUI.client.lua
-- The "Choose Your Yokai" killer-select screen.
--
-- HOW IT TALKS TO THE SERVER (do not change this contract):
--   * Server fires Remotes.CharacterPicker with a LIST of character keys -> we show a card per key.
--   * Player clicks a card -> we fire the same remote back with that key, then lock the screen.
--   * Server fires the remote with `nil` -> we close (the round is starting).
-- The server gives the player up to 10 seconds, then auto-picks. Our on-screen clock mirrors that.
--
-- The look matches mockups/killer-select.html: a dark full-screen panel, "Choose Your YOKAI" with a
-- red countdown under it, and one card per killer. Each card has a slowly-spinning 3D model of the
-- real costume that peeks up above the box, the word "KILLER" over the name, a blood-red hover, and a
-- chosen state where the card's chin (the name strip) fills blood red.

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

	-- Camera framing for the little 3D portraits. Nudge these if a model sits too high/low/zoomed.
	cameraDistanceMult = 2.4,   -- bigger = model further away (smaller in the box)
	cameraHeightFrac   = 0.10,  -- how high the camera floats vs the model height
	aimHeightFrac      = 0.55,  -- where the camera looks (0 = feet, 1 = top); higher = head sits lower
	fieldOfView        = 28,
	spinSpeed          = 0.6,   -- radians/sec turntable spin

	-- Card background = the uploaded diagonal-stripe tile. tileSize sets stripe thickness on screen
	-- (smaller = finer stripes). The source tile is 128px and tiles seamlessly.
	stripeImage = "rbxassetid://119070341954890",
	stripeTile  = 64,

	-- The "CHOOSE YOUR YOKAI" title, baked in Cinzel Decorative (it's fixed text, so it's an image).
	-- Source PNG is 2293x337 -> aspect ~6.8:1.
	titleImage  = "rbxassetid://116198292162889",

	-- Fonts. Swap freely. Merriweather is the closest built-in to the mockup's serif title.
	titleFont = Enum.Font.Merriweather,
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
	black       = Color3.fromRGB(0, 0, 0),       -- "KILLER" text on the chosen red chin
}

-- Display names per character key (the key "GirlA" should read "Girl A").
local LABELS = {
	Momotaro   = "Momotaro",
	Rokurokubi = "Rokurokubi",
	GirlA      = "Girl A",
}

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
-- Half-transparent so the lobby/scene behind shows through and frames the selection.
backdrop.BackgroundTransparency = 0.45
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
header.Size = UDim2.fromOffset(700, 120)
header.AnchorPoint = Vector2.new(0.5, 1)
header.Position = UDim2.new(0.5, 0, 0.5, -(CONFIG.cardHeight / 2) - 120)
header.BackgroundTransparency = 1
header.Parent = backdrop

-- Title is the baked Cinzel Decorative image, centered. ScaleType Fit keeps it from distorting.
local titleLabel = Instance.new("ImageLabel")
titleLabel.AnchorPoint = Vector2.new(0.5, 0)
titleLabel.Position = UDim2.new(0.5, 0, 0, 0)
titleLabel.Size = UDim2.fromOffset(440, 64)
titleLabel.BackgroundTransparency = 1
titleLabel.Image = CONFIG.titleImage
titleLabel.ScaleType = Enum.ScaleType.Fit
titleLabel.Parent = header

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Size = UDim2.new(1, 0, 0, 40)
countdownLabel.Position = UDim2.fromOffset(0, 68)   -- tight gap under the title
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

local function buildViewport(characterKey)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	-- Cover the card and reach above it by `avatarPeek` so the head can poke out the top.
	viewport.Size = UDim2.new(1, 0, 1, CONFIG.avatarPeek)
	viewport.Position = UDim2.new(0, 0, 0, -CONFIG.avatarPeek)
	viewport.ZIndex = 2   -- above the card's textured background, below the chin

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

	-- Frame the camera on the model from its size.
	local pivot, size = model:GetBoundingBox()
	local maxExtent = math.max(size.X, size.Y, size.Z)
	local distance = maxExtent * CONFIG.cameraDistanceMult
	local lookAt = pivot.Position + Vector3.new(0, size.Y * (CONFIG.aimHeightFrac - 0.5), 0)
	local camPos = lookAt + Vector3.new(0, size.Y * CONFIG.cameraHeightFrac, distance)

	local camera = Instance.new("Camera")
	camera.FieldOfView = CONFIG.fieldOfView
	camera.CFrame = CFrame.lookAt(camPos, lookAt)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- Slow turntable spin around the model's own vertical axis.
	local basePivot = model:GetPivot()
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

local function buildCard(characterKey, layoutOrder)
	-- The card is a button so the whole thing is clickable; we handle our own hover colors.
	local card = Instance.new("TextButton")
	card.Name = characterKey
	card.AutoButtonColor = false
	card.Text = ""
	card.Size = UDim2.fromOffset(CONFIG.cardWidth, CONFIG.cardHeight)
	card.BackgroundColor3 = COLOR.panel
	card.BorderSizePixel = 0
	card.ClipsDescendants = false   -- avatar peeks above
	card.LayoutOrder = layoutOrder
	card.Parent = cardRow

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = COLOR.borderDark
	stroke.Parent = card

	-- The textured portrait background (diagonal-ish dark stripes were decorative in the mockup;
	-- here we keep a simple dark fill with rounded top corners, sitting BEHIND the 3D model).
	-- The portrait background: the uploaded diagonal-stripe tile, repeated to fill.
	local portraitBg = Instance.new("ImageLabel")
	portraitBg.Size = UDim2.new(1, 0, 1, -64)   -- leave room for the chin
	portraitBg.BackgroundColor3 = COLOR.panelDeep
	portraitBg.BorderSizePixel = 0
	portraitBg.Image = CONFIG.stripeImage
	portraitBg.ScaleType = Enum.ScaleType.Tile
	portraitBg.TileSize = UDim2.fromOffset(CONFIG.stripeTile, CONFIG.stripeTile)
	portraitBg.ClipsDescendants = true   -- so the hover wash respects the rounded corners
	portraitBg.ZIndex = 1
	portraitBg.Parent = card
	local pbCorner = Instance.new("UICorner")
	pbCorner.CornerRadius = UDim.new(0, 12)
	pbCorner.Parent = portraitBg

	-- A blood-red wash that fades in on hover; hidden until then.
	local hoverWash = Instance.new("Frame")
	hoverWash.Size = UDim2.fromScale(1, 1)
	hoverWash.BackgroundColor3 = COLOR.blood
	hoverWash.BackgroundTransparency = 1
	hoverWash.BorderSizePixel = 0
	hoverWash.Parent = portraitBg

	-- The 3D model portrait (peeks above the card).
	buildViewport(characterKey).Parent = card

	-- The chin: a strip at the bottom with "KILLER" over the character name.
	local chin = Instance.new("Frame")
	chin.AnchorPoint = Vector2.new(0, 1)
	chin.Position = UDim2.fromScale(0, 1)
	chin.Size = UDim2.new(1, 0, 0, 64)
	chin.BackgroundColor3 = COLOR.panel
	chin.BorderSizePixel = 0
	chin.ZIndex = 3   -- in front of the model, so the model stands "behind" the name strip
	chin.Parent = card
	local chinCorner = Instance.new("UICorner")
	chinCorner.CornerRadius = UDim.new(0, 12)
	chinCorner.Parent = chin

	local roleLabel = Instance.new("TextLabel")
	roleLabel.Size = UDim2.new(1, -36, 0, 14)
	roleLabel.Position = UDim2.fromOffset(18, 12)
	roleLabel.BackgroundTransparency = 1
	roleLabel.Text = "KILLER"
	roleLabel.TextXAlignment = Enum.TextXAlignment.Left
	roleLabel.TextColor3 = COLOR.bloodBright
	roleLabel.TextSize = 11
	roleLabel.Font = CONFIG.bodyFont
	roleLabel.ZIndex = 3
	roleLabel.Parent = chin

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -36, 0, 28)
	nameLabel.Position = UDim2.fromOffset(18, 26)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = LABELS[characterKey] or characterKey
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = COLOR.ink
	nameLabel.TextSize = 26
	nameLabel.Font = CONFIG.titleFont
	nameLabel.ZIndex = 3
	nameLabel.Parent = chin

	-- Hover: the portrait background turns blood red and the border brightens (per your note that
	-- hovering a choice makes the background blood red). Skipped once a pick is locked in.
	local quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad)
	local isChosen = false

	card.MouseEnter:Connect(function()
		if locked or isChosen then return end
		TweenService:Create(hoverWash, quick, { BackgroundTransparency = 0.1 }):Play()
		TweenService:Create(stroke, quick, { Color = COLOR.bloodBright }):Play()
	end)
	card.MouseLeave:Connect(function()
		if locked or isChosen then return end
		TweenService:Create(hoverWash, quick, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stroke, quick, { Color = COLOR.borderDark }):Play()
	end)

	-- Click: lock the screen, fire the choice, and switch THIS card to the chosen look —
	-- chin fills blood red and "KILLER" goes black (matches the mockup's selected state).
	card.MouseButton1Click:Connect(function()
		if locked then return end
		locked = true
		isChosen = true
		CharacterPicker:FireServer(characterKey)

		TweenService:Create(chin, quick, { BackgroundColor3 = COLOR.blood }):Play()
		TweenService:Create(stroke, quick, { Color = COLOR.bloodBright }):Play()
		roleLabel.TextColor3 = COLOR.black

		-- Dim the cards that were NOT chosen so the choice reads clearly.
		for _, other in ipairs(cardRow:GetChildren()) do
			if other:IsA("TextButton") and other ~= card then
				TweenService:Create(other, quick, { BackgroundTransparency = 0.55 }):Play()
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
	-- Whole line is red; the clock is bold + bigger so it pops (matches the mockup).
	countdownLabel.Text = string.format(
		'THE HUNT BEGINS IN <font size="28"><b>%s</b></font>', formatClock(seconds))
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

local function open(options)
	clearCardsAndLoops()
	locked = false

	-- Size the row to fit however many options the server sent.
	local count = #options
	cardRow.Size = UDim2.fromOffset(
		count * CONFIG.cardWidth + math.max(0, count - 1) * CONFIG.cardGap,
		CONFIG.cardHeight + CONFIG.avatarPeek + 20)

	for i, characterKey in ipairs(options) do
		buildCard(characterKey, i)
	end

	startCountdown()
	screenGui.Enabled = true
end

local function close()
	screenGui.Enabled = false
	clearCardsAndLoops()
end

CharacterPicker.OnClientEvent:Connect(function(optionsOrNil)
	if optionsOrNil == nil then
		close()
	elseif type(optionsOrNil) == "table" then
		open(optionsOrNil)
	end
end)
