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

local localPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

------------------------------------------------------------------------------
-- Build the UI
------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

-- Top-center timer
local timerFrame = Instance.new("Frame")
timerFrame.Size = UDim2.fromOffset(280, 56)
timerFrame.Position = UDim2.new(0.5, 0, 0, 12)
timerFrame.AnchorPoint = Vector2.new(0.5, 0)
timerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
timerFrame.BackgroundTransparency = 0.2
timerFrame.BorderSizePixel = 0
timerFrame.Parent = screenGui

local timerCorner = Instance.new("UICorner")
timerCorner.CornerRadius = UDim.new(0, 8)
timerCorner.Parent = timerFrame

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
roleFrame.Size = UDim2.fromOffset(280, 48)
roleFrame.Position = UDim2.new(0, 12, 0, 12)
roleFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
roleFrame.BackgroundTransparency = 0.2
roleFrame.BorderSizePixel = 0
roleFrame.Parent = screenGui

local roleCorner = Instance.new("UICorner")
roleCorner.CornerRadius = UDim.new(0, 8)
roleCorner.Parent = roleFrame

local roleLabel = Instance.new("TextLabel")
roleLabel.Size = UDim2.fromScale(1, 1)
roleLabel.BackgroundTransparency = 1
roleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
roleLabel.Font = Enum.Font.Gotham
roleLabel.TextScaled = true
roleLabel.Text = "Lobby"
roleLabel.Parent = roleFrame

-- Friendly display names for the character keys.
local CHARACTER_LABEL = {
    Momotaro   = "Momotaro",
    Rokurokubi = "Rokurokubi",
    GirlA      = "Girl A",
}

-- Colors so the role badge feels different per team.
local TEAM_COLOR = {
    Warden = Color3.fromRGB(80, 140, 220),   -- blue
    Yokai  = Color3.fromRGB(200, 60, 60),    -- red
}

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

    if state == "Ending" and winners then
        timerLabel.Text = winners .. " win!"
        timerFrame.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
    elseif state == "InRound" then
        timerLabel.Text = "Round: " .. formatSeconds(seconds)
        timerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    elseif state == "Lobby" then
        timerLabel.Text = "Next round: " .. formatSeconds(seconds)
        timerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    else
        timerLabel.Text = "Waiting..."
    end
end

local function updateRole()
    local characterKey = localPlayer:GetAttribute("Character")
    local team = localPlayer:GetAttribute("Team")

    if not characterKey or not team then
        roleLabel.Text = "Waiting in lobby"
        roleFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        return
    end

    local displayName = CHARACTER_LABEL[characterKey] or characterKey
    roleLabel.Text = "You are: " .. displayName .. "  (" .. team .. ")"
    roleFrame.BackgroundColor3 = TEAM_COLOR[team] or Color3.fromRGB(20, 20, 30)
end

------------------------------------------------------------------------------
-- Wire up listeners
------------------------------------------------------------------------------

Remotes:GetAttributeChangedSignal("RoundState"):Connect(updateTimer)
Remotes:GetAttributeChangedSignal("SecondsRemaining"):Connect(updateTimer)
Remotes:GetAttributeChangedSignal("Winners"):Connect(updateTimer)

localPlayer:GetAttributeChangedSignal("Character"):Connect(updateRole)
localPlayer:GetAttributeChangedSignal("Team"):Connect(updateRole)

updateTimer()
updateRole()
