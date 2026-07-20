-- StoreUI.client.lua
-- The Skin Store screen (PHASE-0: looks only, no saving). Opens when the player
-- triggers the ProximityPrompt named in Constants.SkinStore.PromptName -- that
-- prompt lives in the store house in the lobby (on Zoe's shopkeeper, eventually).
--
-- Deliberately mirrors CharacterPickerUI.client.lua: same faintly-see-through
-- dark backdrop + top glow, same tiled-stripe cards with a chin strip, same
-- double border, same slow-spinning 3D viewport portraits. Store-specific
-- design (approved off mockups/store-and-hud.html):
--   * A 4-wide, 3-tall GRID of cards -- 12 per page.
--   * Bare gold chevrons left/right page through the catalog (NOT boxed --
--     boxed ones read as purchasable items). Dots + "PAGE X OF Y" underneath.
--   * Locked "COMING SOON" cards (lock icon, no price) pad out the catalog.
--   * Can't afford = the card stays bright but its outline turns GRAY and the
--     price runs red. Owned = gold outline. Equipped = gold-filled chin.
--
-- PHASE-0 RULES (all on purpose, all temporary):
--   * The Omamori wallet is FAKE -- Constants.SkinStore.StartingOmamori each
--     join, gone when you leave.
--   * Buying deducts fake coins and marks the skin owned FOR THIS SESSION.
--   * Equipping only changes the card -- your character doesn't change yet.
--     That's phase-1 (locker + DataStore) work.
-- The catalog + prices live in Constants.SkinStore -- change numbers there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local localPlayer = Players.LocalPlayer
local STORE = Constants.SkinStore

----------------------------------------------------------------------------------------------------
-- TUNABLES -- change these first, everything else follows.
----------------------------------------------------------------------------------------------------

local CONFIG = {
	columns    = 4,
	rows       = 3,
	cardWidth  = 210,
	cardHeight = 268,
	chinHeight = 72,
	columnGap  = 18,
	rowGap     = 46,     -- extra tall so a peeking model doesn't crowd the card above it
	avatarPeek = 44,     -- how far a skin model may poke above its card

	-- Portrait camera (same numbers as the picker).
	cameraDistanceMult = 2.4,
	cameraAimFrac      = 0.05,
	cameraEyeFrac      = 0.10,
	fieldOfView        = 28,
	spinSpeed          = 0.6,

	-- Same uploads the picker uses.
	stripeImage = "rbxassetid://119070341954890",
	stripeTile  = 64,
	lockImage   = "rbxassetid://127360932839161",
	lockSize    = 58,

	titleFont = Enum.Font.GrenzeGotisch,
	bodyFont  = Enum.Font.GothamBold,

	-- The store's player-facing name is THE YOROZUYA (万屋, "shop of ten thousand
	-- things") -- picked because it'll sell more than skins one day. Internal code
	-- names stay "SkinStore"; players never see those.
	titleText    = 'THE <font color="%s">YOROZUYA</font>',
	subtitleText = "TEN THOUSAND THINGS, PAID IN OMAMORI",
}

-- Base palette copied from the picker so the two screens agree.
local COLOR = {
	bgDarkest   = Color3.fromRGB(10, 6, 8),
	panel       = Color3.fromRGB(22, 13, 18),
	panelDeep   = Color3.fromRGB(13, 7, 10),
	ink         = Color3.fromRGB(243, 233, 236),
	inkDim      = Color3.fromRGB(154, 138, 144),
	black       = Color3.fromRGB(0, 0, 0),
}

-- The store's own accent: charm-gold (Omamori!), distinct from the blood-red
-- killer pick and the light-blue Warden pick.
local THEME = {
	titleHex     = "#ffcd50",
	accent       = Color3.fromRGB(178, 132, 40),   -- chin fill on hover/equip
	accentBright = Color3.fromRGB(255, 205, 80),   -- labels, wallet, bright border
	border       = Color3.fromRGB(130, 100, 55),   -- resting card border
	borderGray   = Color3.fromRGB(74, 64, 70),     -- can't-afford outline
	borderLocked = Color3.fromRGB(58, 43, 48),     -- coming-soon outline
	priceRed     = Color3.fromRGB(200, 80, 80),    -- can't-afford price
}

local PAGE_SIZE = CONFIG.columns * CONFIG.rows

----------------------------------------------------------------------------------------------------
-- PHASE-0 session state (fake on purpose -- see header).
----------------------------------------------------------------------------------------------------

local wallet = STORE.StartingOmamori
local owned = {}          -- owned[skinId] = true (this session only)
local equippedId = nil    -- which owned skin is "worn" (card state only in phase-0)
local currentPage = 1

-- The full shelf: real catalog entries, then locked "coming soon" placeholders.
local entries = {}
for _, skin in ipairs(STORE.Catalog) do
	table.insert(entries, skin)
end
for _ = 1, (STORE.ComingSoonSlots or 0) do
	table.insert(entries, { Locked = true })
end
local totalPages = math.max(1, math.ceil(#entries / PAGE_SIZE))

----------------------------------------------------------------------------------------------------
-- Screen skeleton (backdrop, glow, title, wallet, grid, pager) -- built once.
----------------------------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkinStore"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 60
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

-- Faintly see-through dark backdrop. Darker than the picker's 0.25 -- the lobby
-- is bright daylight, so at 0.25 the cards fought the scenery (playtest 2026-07-19).
local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = COLOR.bgDarkest
backdrop.BackgroundTransparency = 0.1
backdrop.BorderSizePixel = 0
backdrop.Parent = screenGui

local topGlow = Instance.new("Frame")
topGlow.Size = UDim2.new(1, 0, 0.45, 0)
topGlow.BackgroundColor3 = THEME.accent
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

-- Wallet: centered in the header under the subtitle, framed by two thin gold
-- rules. (Top-right corner is Roblox's turf -- player list + its toggle -- and
-- a chip up there collided with both; playtest 2026-07-19.)
local function makeRule(yOffset)
	local rule = Instance.new("Frame")
	rule.AnchorPoint = Vector2.new(0.5, 0)
	rule.Position = UDim2.new(0.5, 0, 0, yOffset)
	rule.Size = UDim2.fromOffset(260, 1)
	rule.BackgroundColor3 = THEME.border
	rule.BorderSizePixel = 0
	rule.Parent = backdrop
	return rule
end
makeRule(150)
makeRule(206)

local walletLabel = Instance.new("TextLabel")
walletLabel.AnchorPoint = Vector2.new(0.5, 0)
walletLabel.Size = UDim2.fromOffset(400, 46)
walletLabel.Position = UDim2.new(0.5, 0, 0, 155)
walletLabel.BackgroundTransparency = 1
walletLabel.RichText = true
walletLabel.TextColor3 = THEME.accentBright
walletLabel.TextSize = 40
walletLabel.Font = CONFIG.titleFont
walletLabel.Parent = backdrop

local function refreshWallet()
	walletLabel.Text = string.format('%d <font color="#9a8a90">OMAMORI</font>', wallet)
end
refreshWallet()

-- Close: a big clearly-labeled LEAVE SHOP pill UNDER the card grid (it scales
-- with the grid). Walking away from the shop also closes the screen -- see the
-- watcher in open(). Its exact offset is set in showPage(), since it sits lower
-- when the page dots are showing.
-- Gold pill, black text; on hover it inverts (black pill, gold text + outline).
local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(0.5, 0)
closeButton.Size = UDim2.fromOffset(260, 56)
closeButton.Position = UDim2.new(0.5, 0, 1, 24)
closeButton.BackgroundColor3 = THEME.accentBright
closeButton.Text = "LEAVE SHOP"
closeButton.TextColor3 = COLOR.black
closeButton.TextSize = 26
closeButton.Font = CONFIG.bodyFont
-- (parented to gridZone right after the grid zone is built below)
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 28)
closeCorner.Parent = closeButton
local closeStroke = Instance.new("UIStroke")
-- On a text object a UIStroke outlines the LETTERS by default ("Contextual");
-- Border mode makes it outline the pill shape instead.
closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
closeStroke.Color = THEME.accentBright
closeStroke.Thickness = 2
closeStroke.Enabled = false   -- outline only shows on hover
closeStroke.Parent = closeButton
closeButton.MouseEnter:Connect(function()
	closeButton.BackgroundColor3 = COLOR.black
	closeButton.TextColor3 = THEME.accentBright
	closeStroke.Enabled = true
end)
closeButton.MouseLeave:Connect(function()
	closeButton.BackgroundColor3 = THEME.accentBright
	closeButton.TextColor3 = COLOR.black
	closeStroke.Enabled = false
end)

-- Header (title + subtitle), top-center.
local header = Instance.new("Frame")
header.AnchorPoint = Vector2.new(0.5, 0)
header.Position = UDim2.new(0.5, 0, 0, 26)
header.Size = UDim2.fromOffset(1000, 120)
header.BackgroundTransparency = 1
header.Parent = backdrop

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 78)
titleLabel.BackgroundTransparency = 1
titleLabel.RichText = true
titleLabel.Text = string.format(CONFIG.titleText, THEME.titleHex)
titleLabel.TextColor3 = COLOR.ink
titleLabel.TextSize = 72
titleLabel.Font = CONFIG.titleFont
titleLabel.Parent = header

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Size = UDim2.new(1, 0, 0, 30)
subtitleLabel.Position = UDim2.fromOffset(0, 84)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = CONFIG.subtitleText
subtitleLabel.TextColor3 = THEME.accentBright
subtitleLabel.TextSize = 15
subtitleLabel.Font = CONFIG.bodyFont
subtitleLabel.Parent = header

-- The grid zone, centered below the header.
local gridWidth = CONFIG.columns * CONFIG.cardWidth + (CONFIG.columns - 1) * CONFIG.columnGap
local gridHeight = CONFIG.rows * CONFIG.cardHeight + (CONFIG.rows - 1) * CONFIG.rowGap

local gridZone = Instance.new("Frame")
gridZone.AnchorPoint = Vector2.new(0.5, 0)
gridZone.Position = UDim2.new(0.5, 0, 0, 228)
gridZone.Size = UDim2.fromOffset(gridWidth, gridHeight)
gridZone.BackgroundTransparency = 1
gridZone.Parent = backdrop
closeButton.Parent = gridZone   -- the LEAVE SHOP pill rides (and scales with) the grid

-- Auto-fit: a 4x3 grid of full-size cards is taller than many viewports, so the
-- whole zone (cards + chevrons + page line) scales down until it fits on screen.
local gridScale = Instance.new("UIScale")
gridScale.Parent = gridZone
local function fitGrid()
	local vp = backdrop.AbsoluteSize
	if vp.X <= 0 or vp.Y <= 0 then return end
	local neededHeight = 228 + gridHeight + 130         -- header+wallet offset + grid + page line + LEAVE pill
	local neededWidth = gridWidth + 2 * 170             -- room for the chevrons
	gridScale.Scale = math.min(1, vp.Y / neededHeight, vp.X / neededWidth)
end
backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitGrid)
fitGrid()

-- The cards live in their OWN frame: UIGridLayout force-arranges every child of
-- its container, so the chevrons/page line must NOT share a parent with the
-- cards (first playtest had the chevrons gridded in like purchasable items).
local cardsFrame = Instance.new("Frame")
cardsFrame.Size = UDim2.fromScale(1, 1)
cardsFrame.BackgroundTransparency = 1
cardsFrame.Parent = gridZone

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(CONFIG.cardWidth, CONFIG.cardHeight)
gridLayout.CellPadding = UDim2.fromOffset(CONFIG.columnGap, CONFIG.rowGap)
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.FillDirectionMaxCells = CONFIG.columns
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = cardsFrame

-- Page chevrons: bare gothic glyphs beside the grid (NOT boxed -- boxed ones
-- read as purchasable cards). Dim at rest, bright on hover, faint when dead.
local function makeChevron(text, sideAnchorX, xOffset)
	local chevron = Instance.new("TextButton")
	chevron.AnchorPoint = Vector2.new(sideAnchorX, 0.5)
	chevron.Position = UDim2.new(sideAnchorX, xOffset, 0.5, 0)
	chevron.Size = UDim2.fromOffset(64, 140)
	chevron.BackgroundTransparency = 1
	chevron.Text = text
	chevron.TextColor3 = THEME.border
	chevron.TextSize = 96
	chevron.Font = CONFIG.titleFont
	chevron.Parent = gridZone
	return chevron
end
local prevChevron = makeChevron("<", 0, -84)
local nextChevron = makeChevron(">", 1, 84)

-- Dots + "PAGE X OF Y" under the grid.
local pageLine = Instance.new("Frame")
pageLine.AnchorPoint = Vector2.new(0.5, 0)
pageLine.Position = UDim2.new(0.5, 0, 1, 18)
pageLine.Size = UDim2.fromOffset(400, 44)
pageLine.BackgroundTransparency = 1
pageLine.Parent = gridZone

local dotsRow = Instance.new("Frame")
dotsRow.AnchorPoint = Vector2.new(0.5, 0)
dotsRow.Position = UDim2.new(0.5, 0, 0, 0)
dotsRow.Size = UDim2.fromOffset(totalPages * 19, 9)
dotsRow.BackgroundTransparency = 1
dotsRow.Parent = pageLine
local dotsLayout = Instance.new("UIListLayout")
dotsLayout.FillDirection = Enum.FillDirection.Horizontal
dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
dotsLayout.Padding = UDim.new(0, 10)
dotsLayout.Parent = dotsRow

local dots = {}
for i = 1, totalPages do
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(9, 9)
	dot.BackgroundColor3 = THEME.borderLocked
	dot.BorderSizePixel = 0
	dot.LayoutOrder = i
	dot.Parent = dotsRow
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot
	dots[i] = dot
end

local pageLabel = Instance.new("TextLabel")
pageLabel.Size = UDim2.new(1, 0, 0, 16)
pageLabel.Position = UDim2.fromOffset(0, 20)
pageLabel.BackgroundTransparency = 1
pageLabel.TextColor3 = COLOR.inkDim
pageLabel.TextSize = 11
pageLabel.Font = CONFIG.bodyFont
pageLabel.Parent = pageLine

----------------------------------------------------------------------------------------------------
-- Connection bookkeeping (spin loops), same as the picker.
----------------------------------------------------------------------------------------------------

local liveConnections = {}

local function track(conn)
	table.insert(liveConnections, conn)
	return conn
end

local function clearCardsAndLoops()
	for _, conn in ipairs(liveConnections) do
		conn:Disconnect()
	end
	table.clear(liveConnections)
	for _, child in ipairs(cardsFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Portrait viewport: the skin model from ReplicatedStorage.SkinModels, slow turntable spin.
-- No model yet -> a big "?" holds the spot (the catalog list can lead the art).
----------------------------------------------------------------------------------------------------

-- Same neck-aware framing as the picker (a Rokurokubi skin would inflate the box otherwise).
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

local function buildPortrait(skin)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, (CONFIG.cardHeight - CONFIG.chinHeight) + CONFIG.avatarPeek)
	holder.Position = UDim2.new(0, 0, 0, -CONFIG.avatarPeek)
	holder.ZIndex = 12

	local skinsFolder = ReplicatedStorage:FindFirstChild("SkinModels")
	local source = skinsFolder and skinsFolder:FindFirstChild(skin.ModelName)

	if not source then
		local question = Instance.new("TextLabel")
		question.AnchorPoint = Vector2.new(0.5, 0.5)
		question.Position = UDim2.new(0.5, 0, 0.5, CONFIG.avatarPeek / 2)
		question.Size = UDim2.fromOffset(110, 120)
		question.BackgroundTransparency = 1
		question.Text = "?"
		question.TextColor3 = COLOR.inkDim
		question.TextSize = 96
		question.Font = CONFIG.titleFont
		question.ZIndex = 12
		question.Parent = holder
		return holder
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = 12
	viewport.Ambient = Color3.fromRGB(120, 118, 124)
	viewport.LightColor = Color3.fromRGB(255, 245, 245)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.55)
	viewport.Parent = holder

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local model = source:Clone()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Parent = world

	local center, extent = framingBox(model)
	local distance = extent * CONFIG.cameraDistanceMult
	local lookAt = center + Vector3.new(0, extent * CONFIG.cameraAimFrac, 0)
	local camPos = lookAt + Vector3.new(0, extent * CONFIG.cameraEyeFrac, distance)

	local camera = Instance.new("Camera")
	camera.FieldOfView = CONFIG.fieldOfView
	camera.CFrame = CFrame.lookAt(camPos, lookAt)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local basePivot = model:GetPivot()
	local angle = 0
	track(RunService.RenderStepped:Connect(function(dt)
		angle += dt * CONFIG.spinSpeed
		model:PivotTo(basePivot * CFrame.Angles(0, angle, 0))
	end))

	return holder
end

----------------------------------------------------------------------------------------------------
-- One card. States, in priority order:
--   LOCKED (coming soon) > EQUIPPED (gold chin) > OWNED (gold border)
--   > affordable (resting gold border) > can't afford (GRAY border + red price).
----------------------------------------------------------------------------------------------------

local refreshAllCards
local cardRefreshers = {}

local function buildCard(entry, layoutOrder)
	local isLockedSlot = entry.Locked == true
	local tier = not isLockedSlot and (STORE.Tiers[entry.Tier] or { Price = 0, Label = "???" }) or nil

	local card = Instance.new("TextButton")
	card.Name = isLockedSlot and "ComingSoon" or entry.Id
	card.AutoButtonColor = false
	card.Text = ""
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.ClipsDescendants = false
	card.LayoutOrder = layoutOrder
	card.Parent = cardsFrame

	local content = Instance.new("Frame")
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundColor3 = COLOR.panel
	content.BorderSizePixel = 0
	content.ClipsDescendants = true
	content.ZIndex = 1
	content.Parent = card
	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 14)
	contentCorner.Parent = content

	local portraitBg = Instance.new("ImageLabel")
	portraitBg.Size = UDim2.new(1, 0, 1, -CONFIG.chinHeight)
	portraitBg.BackgroundColor3 = COLOR.panelDeep
	portraitBg.BorderSizePixel = 0
	portraitBg.Image = CONFIG.stripeImage
	portraitBg.ScaleType = Enum.ScaleType.Tile
	portraitBg.TileSize = UDim2.fromOffset(CONFIG.stripeTile, CONFIG.stripeTile)
	portraitBg.ZIndex = 1
	portraitBg.Parent = content

	-- The chin rounds its own bottom corners (relying on the content clip left
	-- square gold corners poking past the border on hover -- playtest 2026-07-19).
	-- A square "patch" strip covers the chin's TOP corners so the seam against
	-- the portrait stays a straight line; it must always match the chin's color.
	local chin = Instance.new("Frame")
	chin.AnchorPoint = Vector2.new(0, 1)
	chin.Position = UDim2.fromScale(0, 1)
	chin.Size = UDim2.new(1, 0, 0, CONFIG.chinHeight)
	chin.BackgroundColor3 = COLOR.panel
	chin.BorderSizePixel = 0
	chin.ZIndex = 3
	chin.Parent = content
	local chinCorner = Instance.new("UICorner")
	chinCorner.CornerRadius = UDim.new(0, 14)
	chinCorner.Parent = chin

	local chinPatch = Instance.new("Frame")
	chinPatch.Size = UDim2.new(1, 0, 0, 14)
	chinPatch.BackgroundColor3 = COLOR.panel
	chinPatch.BorderSizePixel = 0
	chinPatch.ZIndex = 1   -- above the chin body, below its text labels
	chinPatch.Parent = chin

	local tierLabel = Instance.new("TextLabel")
	tierLabel.Size = UDim2.new(0.6, -14, 0, 12)
	tierLabel.Position = UDim2.fromOffset(14, 10)
	tierLabel.BackgroundTransparency = 1
	tierLabel.Text = isLockedSlot and "COMING SOON" or tier.Label
	tierLabel.TextXAlignment = Enum.TextXAlignment.Left
	tierLabel.TextColor3 = isLockedSlot and COLOR.inkDim or THEME.accentBright
	tierLabel.TextSize = 10
	tierLabel.Font = CONFIG.bodyFont
	tierLabel.ZIndex = 3
	tierLabel.Parent = chin

	local stateLabel = Instance.new("TextLabel")
	stateLabel.AnchorPoint = Vector2.new(1, 0)
	stateLabel.Size = UDim2.new(0.4, -14, 0, 12)
	stateLabel.Position = UDim2.new(1, -14, 0, 10)
	stateLabel.BackgroundTransparency = 1
	stateLabel.Text = ""
	stateLabel.TextXAlignment = Enum.TextXAlignment.Right
	stateLabel.TextColor3 = THEME.accentBright
	stateLabel.TextSize = 10
	stateLabel.Font = CONFIG.bodyFont
	stateLabel.ZIndex = 3
	stateLabel.Parent = chin

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -100, 0, 40)
	nameLabel.Position = UDim2.fromOffset(14, 24)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = isLockedSlot and "??????" or entry.DisplayName
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = isLockedSlot and COLOR.inkDim or COLOR.ink
	nameLabel.TextScaled = true
	nameLabel.Font = CONFIG.titleFont
	nameLabel.ZIndex = 3
	nameLabel.Parent = chin
	local nameMax = Instance.new("UITextSizeConstraint")
	nameMax.MaxTextSize = 30
	nameMax.Parent = nameLabel

	local priceLabel = Instance.new("TextLabel")
	priceLabel.AnchorPoint = Vector2.new(1, 1)
	priceLabel.Size = UDim2.fromOffset(86, 40)
	priceLabel.Position = UDim2.new(1, -14, 1, -10)
	priceLabel.BackgroundTransparency = 1
	priceLabel.RichText = true
	priceLabel.Text = ""   -- a TextLabel's default text is literally "Label"; locked cards showed it
	priceLabel.TextXAlignment = Enum.TextXAlignment.Right
	priceLabel.TextColor3 = THEME.accentBright
	priceLabel.TextSize = 24
	priceLabel.Font = CONFIG.titleFont
	priceLabel.ZIndex = 3
	priceLabel.Parent = chin

	-- Portrait: spinning model / "?" for real skins, the lock icon for coming-soon.
	if isLockedSlot then
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
		buildPortrait(entry).Parent = card
	end

	-- Coming-soon cards sit behind a faint veil (like the picker's locked card).
	if isLockedSlot then
		local veil = Instance.new("Frame")
		veil.Size = UDim2.fromScale(1, 1)
		veil.BackgroundColor3 = COLOR.bgDarkest
		veil.BackgroundTransparency = 0.5
		veil.BorderSizePixel = 0
		veil.ZIndex = 6
		veil.Parent = card
		local veilCorner = Instance.new("UICorner")
		veilCorner.CornerRadius = UDim.new(0, 14)
		veilCorner.Parent = veil
	end

	-- Double border, exactly like the picker.
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
		s.Color = isLockedSlot and THEME.borderLocked or THEME.border
		s.Transparency = transparency
		s.Parent = f
		return s
	end
	local strokeOuter = makeBorder(0, 14, 2, 0, 10)
	local strokeInner = makeBorder(5, 9, 1, 0.35, 11)

	if isLockedSlot then
		return   -- static card; no hover, no click, no refresher
	end

	local quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad)
	local hovering = false

	-- Repaint the card to match current wallet/owned/equipped state.
	local function refresh()
		local isOwned = owned[entry.Id] == true
		local isEquipped = equippedId == entry.Id
		local canAfford = wallet >= tier.Price

		if isOwned then
			priceLabel.Text = ""
			stateLabel.Text = isEquipped and "EQUIPPED" or "OWNED"
		else
			priceLabel.Text = string.format('%d <font size="10">OMAMORI</font>', tier.Price)
			stateLabel.Text = ""
			priceLabel.TextColor3 = canAfford and THEME.accentBright or THEME.priceRed
		end

		-- Hover only "lights up" cards you could actually act on (buy or wear).
		local accentOn = isEquipped or (hovering and (isOwned or canAfford))
		local chinColor = accentOn and THEME.accent or COLOR.panel
		TweenService:Create(chin, quick, { BackgroundColor3 = chinColor }):Play()
		TweenService:Create(chinPatch, quick, { BackgroundColor3 = chinColor }):Play()

		-- Border: gold family when reachable, GRAY when you can't afford it yet
		-- (the card itself stays bright -- you should still want the thing).
		local borderColor
		if accentOn or isOwned then
			borderColor = THEME.accentBright
		elseif canAfford then
			borderColor = THEME.border
		else
			borderColor = THEME.borderGray
		end
		TweenService:Create(strokeOuter, quick, { Color = borderColor }):Play()
		TweenService:Create(strokeInner, quick, { Color = borderColor }):Play()
		tierLabel.TextColor3 = accentOn and COLOR.black or THEME.accentBright
		stateLabel.TextColor3 = accentOn and COLOR.black or THEME.accentBright
	end
	table.insert(cardRefreshers, refresh)

	card.MouseEnter:Connect(function()
		hovering = true
		refresh()
	end)
	card.MouseLeave:Connect(function()
		hovering = false
		refresh()
	end)

	-- Click: buy it if you can, then wear it. Clicking your equipped skin takes it off.
	card.MouseButton1Click:Connect(function()
		local isOwned = owned[entry.Id] == true
		if not isOwned then
			if wallet < tier.Price then return end
			wallet -= tier.Price
			owned[entry.Id] = true
			equippedId = entry.Id
			refreshWallet()
		elseif equippedId == entry.Id then
			equippedId = nil          -- take it off (back to the default look)
		else
			equippedId = entry.Id     -- wear this one instead
		end
		refreshAllCards()
	end)

	refresh()
end

refreshAllCards = function()
	for _, refresh in ipairs(cardRefreshers) do
		refresh()
	end
end

----------------------------------------------------------------------------------------------------
-- Paging.
----------------------------------------------------------------------------------------------------

local function showPage(page)
	currentPage = math.clamp(page, 1, totalPages)
	clearCardsAndLoops()
	table.clear(cardRefreshers)

	local first = (currentPage - 1) * PAGE_SIZE + 1
	local last = math.min(first + PAGE_SIZE - 1, #entries)
	for i = first, last do
		buildCard(entries[i], i - first + 1)
	end

	-- One page = no paging chrome at all. Chevrons, dots, and the PAGE line only
	-- exist once the catalog outgrows a single screen.
	local paging = totalPages > 1
	prevChevron.Visible = paging
	nextChevron.Visible = paging
	pageLine.Visible = paging
	if paging then
		-- Chevrons: faint + dead at the ends of the shelf.
		local atFirst = currentPage <= 1
		local atLast = currentPage >= totalPages
		prevChevron.TextTransparency = atFirst and 0.75 or 0
		nextChevron.TextTransparency = atLast and 0.75 or 0
		prevChevron.Active = not atFirst
		nextChevron.Active = not atLast

		for i, dot in ipairs(dots) do
			dot.BackgroundColor3 = (i == currentPage) and THEME.accentBright or THEME.borderLocked
		end
		pageLabel.Text = string.format("PAGE %d OF %d", currentPage, totalPages)
	end

	-- LEAVE SHOP sits right under the grid -- lower when the page dots are showing.
	closeButton.Position = UDim2.new(0.5, 0, 1, paging and 76 or 24)
end

prevChevron.MouseButton1Click:Connect(function()
	if currentPage > 1 then showPage(currentPage - 1) end
end)
nextChevron.MouseButton1Click:Connect(function()
	if currentPage < totalPages then showPage(currentPage + 1) end
end)
prevChevron.MouseEnter:Connect(function()
	if currentPage > 1 then prevChevron.TextColor3 = THEME.accentBright end
end)
prevChevron.MouseLeave:Connect(function() prevChevron.TextColor3 = THEME.border end)
nextChevron.MouseEnter:Connect(function()
	if currentPage < totalPages then nextChevron.TextColor3 = THEME.accentBright end
end)
nextChevron.MouseLeave:Connect(function() nextChevron.TextColor3 = THEME.border end)

----------------------------------------------------------------------------------------------------
-- Open / close.
----------------------------------------------------------------------------------------------------

-- Remembers which prompt opened the store, so the walk-away watcher below knows
-- where "the shop" physically is.
local openedFromPrompt = nil

local function open(prompt)
	openedFromPrompt = prompt
	refreshWallet()
	showPage(currentPage)
	screenGui.Enabled = true

	-- Walking away closes the screen (a few studs of grace past the prompt's own
	-- range) -- matches how the whiteboard and every shop NPC feels.
	task.spawn(function()
		while screenGui.Enabled do
			task.wait(0.5)
			local promptPart = openedFromPrompt and openedFromPrompt.Parent
			local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
			if promptPart and promptPart:IsA("BasePart") and root then
				local reach = openedFromPrompt.MaxActivationDistance + 8
				if (root.Position - promptPart.Position).Magnitude > reach then
					screenGui.Enabled = false
				end
			end
		end
	end)
end

local function close()
	screenGui.Enabled = false
	clearCardsAndLoops()
	table.clear(cardRefreshers)
end

closeButton.MouseButton1Click:Connect(close)

-- The store opens from the ProximityPrompt in the lobby store house. Any prompt
-- with the right name works, so the prompt can live on the shopkeeper, the
-- counter, the door -- wherever the kids put it.
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if player ~= localPlayer then return end
	if prompt.Name == STORE.PromptName then
		open(prompt)
	end
end)

-- If the round starts (we respawn as our character), the store closes itself.
localPlayer.CharacterAdded:Connect(close)
