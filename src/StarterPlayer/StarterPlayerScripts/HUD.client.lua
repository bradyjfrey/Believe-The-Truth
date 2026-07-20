-- HUD.client.lua
-- The on-screen heads-up display. Shows:
--   * Bottom center: round timer + state, with the ABILITY ICONS row above it
--                    (key + name per ability; icons gray out + count down on cooldown)
--   * Top left:      the local player's role ("You are: Momotaro (Warden)")
--   * Bottom left:   health bar; bottom right: stamina bar
--
-- All the data comes from attributes the server sets:
--   ReplicatedStorage.Remotes.RoundState        - "Lobby" / "InRound" / "Ending"
--   ReplicatedStorage.Remotes.SecondsRemaining  - number, current countdown
--   ReplicatedStorage.Remotes.Winners           - "Wardens" or "Yokai" (only during Ending)
--   localPlayer.Character                       - "Momotaro" / "Rokurokubi" / "GirlA"
--   localPlayer.Team                            - "Warden" / "Yokai"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AbilityBindings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AbilityBindings"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

-- Turn off Roblox's built-in health bar -- we draw our own below (so we don't show two).
-- The core GUI can be briefly unavailable on join, so retry until it takes.
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		if ok then break end
		task.wait(0.5)
	end
end)

------------------------------------------------------------------------------
-- Build the UI
------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
-- IgnoreGuiInset MUST be false here so our elements sit BELOW Roblox's top
-- bar / leaderboard instead of getting hidden behind it.
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 5
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

-- Shared helper to add interior padding (left/right gets the most so text
-- has breathing room from the rounded corners).
local function addPadding(frame)
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft   = UDim.new(0, 20)
    padding.PaddingRight  = UDim.new(0, 20)
    padding.PaddingTop    = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.Parent = frame
end

-- Bottom-center timer
local timerFrame = Instance.new("Frame")
timerFrame.Size = UDim2.fromOffset(320, 64)
timerFrame.Position = UDim2.new(0.5, 0, 1, -24)
timerFrame.AnchorPoint = Vector2.new(0.5, 1)
timerFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
timerFrame.BackgroundTransparency = 0.1
timerFrame.BorderSizePixel = 0
timerFrame.Parent = screenGui

local timerCorner = Instance.new("UICorner")
timerCorner.CornerRadius = UDim.new(0, 10)
timerCorner.Parent = timerFrame

addPadding(timerFrame)

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.fromScale(1, 1)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextScaled = true
timerLabel.Text = "Waiting..."
timerLabel.Parent = timerFrame

-- Top-left role badge
local roleFrame = Instance.new("Frame")
roleFrame.Size = UDim2.fromOffset(340, 56)
roleFrame.Position = UDim2.new(0, 16, 0, 16)
roleFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
roleFrame.BackgroundTransparency = 0.1
roleFrame.BorderSizePixel = 0
roleFrame.Parent = screenGui

local roleCorner = Instance.new("UICorner")
roleCorner.CornerRadius = UDim.new(0, 10)
roleCorner.Parent = roleFrame

addPadding(roleFrame)

local roleLabel = Instance.new("TextLabel")
roleLabel.Size = UDim2.fromScale(1, 1)
roleLabel.BackgroundTransparency = 1
roleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
roleLabel.Font = Enum.Font.Gotham
roleLabel.TextScaled = true
roleLabel.Text = "Lobby"
roleLabel.Parent = roleFrame

-- Bottom-left HEALTH bar.
-- NOTE (colorblind-friendly): we do NOT color-code health (no green->red). The info comes from
-- the bar's LENGTH and the "current / max" NUMBER on top, which read the same to everyone.
local healthFrame = Instance.new("Frame")
healthFrame.Size = UDim2.fromOffset(300, 40)
healthFrame.Position = UDim2.new(0, 16, 1, -24)
healthFrame.AnchorPoint = Vector2.new(0, 1)
healthFrame.BackgroundColor3 = Color3.fromRGB(80, 20, 24)   -- solid (themed per team below)
healthFrame.BackgroundTransparency = 0
healthFrame.BorderSizePixel = 0
healthFrame.Parent = screenGui

local healthCorner = Instance.new("UICorner")
healthCorner.CornerRadius = UDim.new(0, 10)
healthCorner.Parent = healthFrame

-- Bright border, matching the character-select (login) cards.
local healthStroke = Instance.new("UIStroke")
healthStroke.Thickness = 2.5
healthStroke.Color = Color3.fromRGB(255, 59, 65)
healthStroke.Parent = healthFrame

local healthPad = Instance.new("UIPadding")
healthPad.PaddingLeft   = UDim.new(0, 8)
healthPad.PaddingRight  = UDim.new(0, 8)
healthPad.PaddingTop    = UDim.new(0, 8)
healthPad.PaddingBottom = UDim.new(0, 8)
healthPad.Parent = healthFrame

-- Large heart icon on the left.
local heartLabel = Instance.new("TextLabel")
heartLabel.Size = UDim2.new(0, 30, 1, 6)             -- a touch taller than the bar so it reads "large"
heartLabel.Position = UDim2.new(0, 0, 0.5, 0)
heartLabel.AnchorPoint = Vector2.new(0, 0.5)
heartLabel.BackgroundTransparency = 1
heartLabel.Text = "♥"
heartLabel.Font = Enum.Font.GothamBold
heartLabel.TextScaled = true
heartLabel.TextColor3 = Color3.fromRGB(255, 59, 65)  -- themed per team below
heartLabel.ZIndex = 3
heartLabel.Parent = healthFrame

-- The empty bar track (the darker, drained part). Sits to the right of the heart.
local barTrack = Instance.new("Frame")
barTrack.Size = UDim2.new(1, -38, 1, 0)
barTrack.Position = UDim2.new(0, 38, 0, 0)
barTrack.BackgroundColor3 = Color3.fromRGB(80, 20, 24)
barTrack.BorderSizePixel = 0
barTrack.Parent = healthFrame
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(0, 8)
trackCorner.Parent = barTrack

-- The fill -- its WIDTH is the health fraction. Bright (themed per team), one steady color on purpose.
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = Color3.fromRGB(230, 50, 56)
barFill.BorderSizePixel = 0
barFill.Parent = barTrack
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 8)
fillCorner.Parent = barFill

-- The number, centered on top of the bar (the real source of truth). White with a dark outline so
-- it stays readable over both the bright fill and the darker drained part.
local healthLabel = Instance.new("TextLabel")
healthLabel.Size = UDim2.fromScale(1, 1)
healthLabel.BackgroundTransparency = 1
healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
healthLabel.Font = Enum.Font.GothamBold
healthLabel.TextScaled = true
healthLabel.Text = "HP"
healthLabel.ZIndex = 2
healthLabel.Parent = barTrack
local healthTextSize = Instance.new("UITextSizeConstraint")
healthTextSize.MaxTextSize = 20
healthTextSize.Parent = healthLabel
local labelStroke = Instance.new("UIStroke")
labelStroke.Thickness = 1.5
labelStroke.Color = Color3.fromRGB(0, 0, 0)
labelStroke.Transparency = 0.35
labelStroke.Parent = healthLabel

-- Bottom-left STAMINA bar -- a thinner bar sitting just above the health bar. Drains while you
-- sprint (hold Shift), refills when you stop. Amber + a bolt icon so it's clearly not the health bar.
local staminaFrame = Instance.new("Frame")
staminaFrame.Size = UDim2.fromOffset(300, 40)              -- same height as the health bar
-- Floated to the BOTTOM-RIGHT of the screen (health is bottom-left). The X scale of 1 anchors it to
-- the right edge, so it moves with the window when it resizes.
staminaFrame.Position = UDim2.new(1, -16, 1, -24)
staminaFrame.AnchorPoint = Vector2.new(1, 1)
staminaFrame.BackgroundColor3 = Color3.fromRGB(22, 20, 12)
staminaFrame.BorderSizePixel = 0
staminaFrame.Parent = screenGui

local staminaCorner = Instance.new("UICorner")
staminaCorner.CornerRadius = UDim.new(0, 10)
staminaCorner.Parent = staminaFrame

local staminaStroke = Instance.new("UIStroke")
staminaStroke.Thickness = 1.5
staminaStroke.Color = Color3.fromRGB(235, 200, 80)
staminaStroke.Parent = staminaFrame

local staminaPad = Instance.new("UIPadding")
staminaPad.PaddingLeft = UDim.new(0, 8)
staminaPad.PaddingRight = UDim.new(0, 8)
staminaPad.PaddingTop = UDim.new(0, 8)
staminaPad.PaddingBottom = UDim.new(0, 8)
staminaPad.Parent = staminaFrame

local boltLabel = Instance.new("TextLabel")
boltLabel.Size = UDim2.new(0, 30, 1, 6)
boltLabel.Position = UDim2.new(0, 0, 0.5, 0)
boltLabel.AnchorPoint = Vector2.new(0, 0.5)
boltLabel.BackgroundTransparency = 1
boltLabel.Text = "⚡"
boltLabel.Font = Enum.Font.GothamBold
boltLabel.TextScaled = true
boltLabel.TextColor3 = Color3.fromRGB(235, 200, 80)
boltLabel.ZIndex = 3
boltLabel.Parent = staminaFrame

local staminaTrack = Instance.new("Frame")
staminaTrack.Size = UDim2.new(1, -38, 1, 0)
staminaTrack.Position = UDim2.new(0, 38, 0, 0)
staminaTrack.BackgroundColor3 = Color3.fromRGB(40, 36, 20)
staminaTrack.BorderSizePixel = 0
staminaTrack.Parent = staminaFrame
local staminaTrackCorner = Instance.new("UICorner")
staminaTrackCorner.CornerRadius = UDim.new(0, 8)
staminaTrackCorner.Parent = staminaTrack

local staminaFill = Instance.new("Frame")
staminaFill.Size = UDim2.fromScale(1, 1)
staminaFill.BackgroundColor3 = Color3.fromRGB(235, 200, 80)
staminaFill.BorderSizePixel = 0
staminaFill.Parent = staminaTrack
local staminaFillCorner = Instance.new("UICorner")
staminaFillCorner.CornerRadius = UDim.new(0, 8)
staminaFillCorner.Parent = staminaFill

------------------------------------------------------------------------------
-- Bottom-center ABILITY icons -- one square per ability, sitting just above the
-- round timer. Styled to match the character-picker language (2026-07-19):
-- dark panel with a faint stripe tile, DOUBLE border, gothic key letter, and a
-- small accent label strip -- accent color themed by team (Warden light blue,
-- Yokai blood red). While an ability recharges, a dark shade drains away, the
-- gothic seconds count down, and the borders drop to the dim resting color.
-- The server stamps an "AbilityReadyAt_<Name>" attribute on the player every
-- time a cooldown starts (see AbilityModule.startCooldown) -- that's all the
-- HUD needs. Mockup: mockups/store-and-hud.html (Mock 2).
------------------------------------------------------------------------------

-- The picker's look, shrunk to gameplay scale. Same stripe tile upload.
local SLOT = {
	width = 84, height = 96,
	labelHeight = 26,
	panel = Color3.fromRGB(22, 13, 18),
	ink = Color3.fromRGB(243, 233, 236),
	stripeImage = "rbxassetid://119070341954890",
	stripeTile = 48,
	titleFont = Enum.Font.GrenzeGotisch,
	bodyFont = Enum.Font.GothamBold,
}

-- Accent per team (same hues as the picker themes).
local SLOT_THEME = {
	Warden = { bright = Color3.fromRGB(124, 192, 255), dim = Color3.fromRGB(54, 92, 130) },
	Yokai  = { bright = Color3.fromRGB(255, 59, 65),   dim = Color3.fromRGB(120, 60, 68) },
}

local abilityRow = Instance.new("Frame")
abilityRow.Name = "AbilityRow"
abilityRow.AnchorPoint = Vector2.new(0.5, 1)
abilityRow.Position = UDim2.new(0.5, 0, 1, -96)   -- just above the round timer
abilityRow.Size = UDim2.fromOffset(600, SLOT.height)
abilityRow.BackgroundTransparency = 1
abilityRow.Parent = screenGui

local abilityLayout = Instance.new("UIListLayout")
abilityLayout.FillDirection = Enum.FillDirection.Horizontal
abilityLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
abilityLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
abilityLayout.Padding = UDim.new(0, 12)
abilityLayout.Parent = abilityRow

-- What to print on the key badge for mouse "keys".
local function keyText(key)
	if key == Enum.UserInputType.MouseButton1 then return "LMB" end
	if key == Enum.UserInputType.MouseButton2 then return "RMB" end
	return key.Name   -- Q, E, R, F...
end

local abilityIcons = {}   -- one record per icon: the gui pieces + its cooldown timing

local function clearAbilityIcons()
	for _, icon in ipairs(abilityIcons) do
		icon.conn:Disconnect()
		icon.frame:Destroy()
	end
	abilityIcons = {}
end

local function buildAbilityIcons(characterName)
	clearAbilityIcons()
	local list = characterName and AbilityBindings[characterName]
	if not list then return end

	-- Accent by team; if Team isn't set yet for some reason, Warden blue is a safe default.
	local theme = SLOT_THEME[localPlayer:GetAttribute("Team")] or SLOT_THEME.Warden

	for order, binding in ipairs(list) do
		-- The slot itself is a transparent, UNCLIPPED container. The borders live
		-- directly in it; everything else goes in the clipped `content` frame
		-- below. (Clipping the borders square-cut their rounded strokes into red
		-- corner wedges -- playtest 2026-07-19. Same structure as a picker card.)
		local frame = Instance.new("Frame")
		frame.Name = binding.Ability
		frame.LayoutOrder = order
		frame.Size = UDim2.fromOffset(SLOT.width, SLOT.height)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Parent = abilityRow

		local content = Instance.new("Frame")
		content.Size = UDim2.fromScale(1, 1)
		content.BackgroundColor3 = SLOT.panel
		content.BorderSizePixel = 0
		content.ClipsDescendants = true
		content.ZIndex = 1
		content.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = content

		-- Faint stripe tile behind the key letter (same upload as the picker cards).
		local stripes = Instance.new("ImageLabel")
		stripes.Size = UDim2.new(1, 0, 1, -SLOT.labelHeight)
		stripes.BackgroundTransparency = 1
		stripes.Image = SLOT.stripeImage
		stripes.ImageTransparency = 0.5
		stripes.ScaleType = Enum.ScaleType.Tile
		stripes.TileSize = UDim2.fromOffset(SLOT.stripeTile, SLOT.stripeTile)
		stripes.ZIndex = 1
		stripes.Parent = content

		-- Big gothic key letter ("Q") over the stripes.
		local keyLabel = Instance.new("TextLabel")
		keyLabel.Size = UDim2.new(1, 0, 1, -SLOT.labelHeight)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Font = SLOT.titleFont
		keyLabel.TextScaled = true
		keyLabel.TextColor3 = SLOT.ink
		keyLabel.Text = keyText(binding.Key)
		keyLabel.ZIndex = 2
		keyLabel.Parent = content
		local keyMax = Instance.new("UITextSizeConstraint")
		keyMax.MaxTextSize = 46
		keyMax.Parent = keyLabel

		-- The label strip along the bottom: darkened band, accent-colored name.
		-- Rounds its own bottom corners (the content clip is rectangular and
		-- would let square corners poke out); the patch squares off its top edge.
		local labelStrip = Instance.new("Frame")
		labelStrip.AnchorPoint = Vector2.new(0, 1)
		labelStrip.Position = UDim2.fromScale(0, 1)
		labelStrip.Size = UDim2.new(1, 0, 0, SLOT.labelHeight)
		labelStrip.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		labelStrip.BackgroundTransparency = 0.35
		labelStrip.BorderSizePixel = 0
		labelStrip.ZIndex = 2
		labelStrip.Parent = content
		local stripCorner = Instance.new("UICorner")
		stripCorner.CornerRadius = UDim.new(0, 12)
		stripCorner.Parent = labelStrip
		local stripPatch = Instance.new("Frame")
		stripPatch.Size = UDim2.new(1, 0, 0, 12)
		stripPatch.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		stripPatch.BackgroundTransparency = 0.35
		stripPatch.BorderSizePixel = 0
		stripPatch.ZIndex = 1
		stripPatch.Parent = labelStrip

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -8, 1, 0)
		nameLabel.Position = UDim2.fromOffset(4, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = SLOT.bodyFont
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = theme.bright
		nameLabel.Text = string.upper(binding.Label)
		nameLabel.ZIndex = 3
		nameLabel.Parent = labelStrip
		local nameMax = Instance.new("UITextSizeConstraint")
		nameMax.MaxTextSize = 11
		nameMax.Parent = nameLabel

		-- The recharge shade: covers the square when the cooldown starts, then
		-- drains away (bottom edge rises) as the ability comes back.
		local shade = Instance.new("Frame")
		shade.Size = UDim2.fromScale(1, 0)
		shade.BackgroundColor3 = Color3.fromRGB(6, 3, 5)
		shade.BackgroundTransparency = 0.22
		shade.BorderSizePixel = 0
		shade.ZIndex = 4
		shade.Parent = content
		local shadeCorner = Instance.new("UICorner")
		shadeCorner.CornerRadius = UDim.new(0, 12)
		shadeCorner.Parent = shade

		-- The seconds left, gothic + accent, centered in the key area while recharging.
		local secondsLabel = Instance.new("TextLabel")
		secondsLabel.Size = UDim2.new(1, 0, 1, -SLOT.labelHeight)
		secondsLabel.BackgroundTransparency = 1
		secondsLabel.Font = SLOT.titleFont
		secondsLabel.TextScaled = true
		secondsLabel.TextColor3 = theme.bright
		secondsLabel.Visible = false
		secondsLabel.ZIndex = 5
		secondsLabel.Parent = content
		local secondsStroke = Instance.new("UIStroke")
		secondsStroke.Thickness = 1.5
		secondsStroke.Color = Color3.fromRGB(0, 0, 0)
		secondsStroke.Parent = secondsLabel
		local secondsSize = Instance.new("UITextSizeConstraint")
		secondsSize.MaxTextSize = 36
		secondsSize.Parent = secondsLabel

		-- DOUBLE border, exactly like a picker card: outer stroke + a thinner,
		-- fainter inner line. Bright accent when ready, dim while recharging.
		local function makeBorder(inset, radius, thickness, transparency, z)
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			f.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
			f.BackgroundTransparency = 1
			f.ZIndex = z
			f.Parent = frame
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, radius)
			c.Parent = f
			local s = Instance.new("UIStroke")
			s.Thickness = thickness
			s.Color = theme.bright
			s.Transparency = transparency
			s.Parent = f
			return s
		end
		local strokeOuter = makeBorder(0, 12, 2, 0, 6)
		local strokeInner = makeBorder(4, 8, 1, 0.45, 7)

		local icon = {
			ability = binding.Ability,
			frame = frame,
			keyLabel = keyLabel,
			shade = shade,
			secondsLabel = secondsLabel,
			strokeOuter = strokeOuter,
			strokeInner = strokeInner,
			theme = theme,
			readyAt = 0,
			total = 0,
			conn = nil,
		}

		-- When the server stamps a new cooldown, remember when it ends and how long
		-- it is. We normally hear about it the moment it starts, so "time left" IS
		-- the full length; if the HUD rebuilds mid-cooldown (a respawn), fall back
		-- to the Constants number so the shade fraction stays honest.
		local attrName = "AbilityReadyAt_" .. binding.Ability
		local function readAttribute()
			local readyAt = localPlayer:GetAttribute(attrName)
			if not readyAt then
				icon.readyAt = 0
				return
			end
			icon.readyAt = readyAt
			local remaining = readyAt - workspace:GetServerTimeNow()
			if remaining > 0 then
				local config = Constants[characterName] and Constants[characterName][binding.Ability]
				icon.total = math.max(remaining, (config and config.CooldownSeconds) or 0)
			end
		end
		icon.conn = localPlayer:GetAttributeChangedSignal(attrName):Connect(readAttribute)
		readAttribute()

		table.insert(abilityIcons, icon)
	end
end

-- Tick every icon's shade + number down. Runs every frame; with at most four
-- icons this is cheap.
RunService.Heartbeat:Connect(function()
	for _, icon in ipairs(abilityIcons) do
		local remaining = icon.readyAt - workspace:GetServerTimeNow()
		if remaining > 0 and icon.total > 0 then
			local frac = math.clamp(remaining / icon.total, 0, 1)
			icon.shade.Size = UDim2.new(1, 0, frac, 0)
			icon.secondsLabel.Visible = true
			icon.secondsLabel.Text = tostring(math.ceil(remaining))
			icon.keyLabel.TextTransparency = 0.75              -- key fades while recharging
			icon.strokeOuter.Color = icon.theme.dim            -- borders drop to the dim resting color
			icon.strokeInner.Color = icon.theme.dim
		else
			icon.shade.Size = UDim2.new(1, 0, 0, 0)
			icon.secondsLabel.Visible = false
			icon.keyLabel.TextTransparency = 0                 -- ready
			icon.strokeOuter.Color = icon.theme.bright
			icon.strokeInner.Color = icon.theme.bright
		end
	end
end)

-- Rebuild the row whenever the server hands us a (new) character; no character
-- (back in the lobby) clears the row entirely.
localPlayer:GetAttributeChangedSignal("Character"):Connect(function()
	buildAbilityIcons(localPlayer:GetAttribute("Character"))
end)
buildAbilityIcons(localPlayer:GetAttribute("Character"))

-- Friendly display names for the character keys.
local CHARACTER_LABEL = {
	Momotaro   = "Momotaro",
	Rokurokubi = "Rokurokubi",
	GirlA      = "Girl A",
	Otohime    = "Otohime",
}

-- Colors so the role badge feels different per team.
local TEAM_COLOR = {
	Warden = Color3.fromRGB(80, 140, 220),   -- blue
	Yokai  = Color3.fromRGB(200, 60, 60),    -- red
}

-- Health bar palette per team, matching the character-select (login) cards:
-- a solid panel (bg/drained), a bright fill, and a bright border.
local HEALTH_THEME = {
	Yokai  = { bg = Color3.fromRGB(80, 20, 24),  fill = Color3.fromRGB(230, 50, 56), border = Color3.fromRGB(255, 59, 65) },
	Warden = { bg = Color3.fromRGB(26, 58, 92),  fill = Color3.fromRGB(80, 160, 235), border = Color3.fromRGB(124, 192, 255) },
}
local HEALTH_NEUTRAL = { bg = Color3.fromRGB(28, 28, 38), fill = Color3.fromRGB(150, 150, 165), border = Color3.fromRGB(90, 90, 110) }

local function themeHealth(team)
	local t = HEALTH_THEME[team] or HEALTH_NEUTRAL
	healthFrame.BackgroundColor3 = t.bg
	barTrack.BackgroundColor3 = t.bg
	barFill.BackgroundColor3 = t.fill
	healthStroke.Color = t.border
	heartLabel.TextColor3 = t.border
end

------------------------------------------------------------------------------
-- Update functions
------------------------------------------------------------------------------

local function formatSeconds(seconds)
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	if minutes > 0 then
		return string.format("%d:%02d", minutes, secs)
	else
		return string.format("0:%02d", secs)
	end
end

local function updateTimer()
	local state = Remotes:GetAttribute("RoundState")
	local seconds = Remotes:GetAttribute("SecondsRemaining") or 0
	local winners = Remotes:GetAttribute("Winners")
	local hasEnough = Remotes:GetAttribute("HasEnoughPlayers")
	local playersInLobby = Remotes:GetAttribute("PlayersInLobby") or 0
	local playersNeeded = Remotes:GetAttribute("PlayersNeeded") or 2

	if state == "Ending" and winners then
		timerLabel.Text = winners .. " win!"
		timerFrame.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
	elseif state == "InRound" then
		timerLabel.Text = "Round: " .. formatSeconds(seconds)
		timerFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
	elseif state == "Lobby" then
		if hasEnough then
			timerLabel.Text = "Starts in " .. formatSeconds(seconds)
		else
			timerLabel.Text = "Waiting (" .. playersInLobby .. "/" .. playersNeeded .. ")"
		end
		timerFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
	else
		timerLabel.Text = "Connecting..."
	end
end

local function updateRole()
	local characterKey = localPlayer:GetAttribute("Character")
	local team = localPlayer:GetAttribute("Team")

	if not characterKey or not team then
		roleLabel.Text = "Waiting in lobby"
		roleFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		themeHealth(nil)
		return
	end

	local displayName = CHARACTER_LABEL[characterKey] or characterKey
	roleLabel.Text = "You are: " .. displayName .. "  (" .. team .. ")"
	roleFrame.BackgroundColor3 = TEAM_COLOR[team] or Color3.fromRGB(20, 20, 30)
	themeHealth(team)
end

------------------------------------------------------------------------------
-- Wire up listeners
------------------------------------------------------------------------------

Remotes:GetAttributeChangedSignal("RoundState"):Connect(updateTimer)
Remotes:GetAttributeChangedSignal("SecondsRemaining"):Connect(updateTimer)
Remotes:GetAttributeChangedSignal("Winners"):Connect(updateTimer)
Remotes:GetAttributeChangedSignal("HasEnoughPlayers"):Connect(updateTimer)
Remotes:GetAttributeChangedSignal("PlayersInLobby"):Connect(updateTimer)
Remotes:GetAttributeChangedSignal("PlayersNeeded"):Connect(updateTimer)

localPlayer:GetAttributeChangedSignal("Character"):Connect(updateRole)
localPlayer:GetAttributeChangedSignal("Team"):Connect(updateRole)

-- Health: re-bind to whatever Humanoid the local character currently has (it changes each spawn,
-- including the dressed-model swap), and refresh the bar whenever health or max health changes.
local function bindHealth(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	local function refresh()
		local current = math.max(0, math.floor(humanoid.Health + 0.5))
		barFill.Size = UDim2.new(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 0, 1, 0)
		healthLabel.Text = tostring(current)   -- just the current HP, ticking down as they take damage
	end

	humanoid.HealthChanged:Connect(refresh)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refresh)
	refresh()
end

localPlayer.CharacterAdded:Connect(bindHealth)
if localPlayer.Character then bindHealth(localPlayer.Character) end

-- Stamina: the Sprint script sets a "Stamina" attribute (0..1); we just mirror it to the bar.
local function updateStamina()
	local frac = localPlayer:GetAttribute("Stamina")
	if frac == nil then frac = 1 end
	staminaFill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
end
localPlayer:GetAttributeChangedSignal("Stamina"):Connect(updateStamina)
updateStamina()

updateTimer()
updateRole()
