-- HUD.client.lua
-- The on-screen heads-up display. Shows:
--   * Top center: round timer + state ("Lobby: 0:18", "Round: 2:47", "Wardens win!")
--   * Top left:   the local player's role ("You are: Momotaro (Warden)")
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

local localPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

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
