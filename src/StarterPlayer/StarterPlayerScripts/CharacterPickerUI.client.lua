-- CharacterPickerUI.client.lua
-- When the server fires the CharacterPicker remote with a list of options,
-- show a UI listing each character. Player taps one → fire the same remote
-- back with the chosen character name.
-- When the server fires with `nil`, close the UI (the round is starting).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CharacterPicker = Remotes:WaitForChild("CharacterPicker")

-- Display labels per character key.
local LABELS = {
    Momotaro   = "Momotaro",
    Rokurokubi = "Rokurokubi",
    GirlA      = "Girl A",
}

------------------------------------------------------------------------------
-- UI scaffolding (built once, shown/hidden as needed)
------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CharacterPicker"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 50
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.4
backdrop.BorderSizePixel = 0
backdrop.Parent = screenGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(440, 320)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
panel.BorderSizePixel = 0
panel.Parent = backdrop

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 60)
title.Position = UDim2.fromOffset(20, 20)
title.BackgroundTransparency = 1
title.Text = "Pick your Yokai"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = panel

local buttonRow = Instance.new("Frame")
buttonRow.Size = UDim2.new(1, -40, 1, -100)
buttonRow.Position = UDim2.fromOffset(20, 90)
buttonRow.BackgroundTransparency = 1
buttonRow.Parent = panel

local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rowLayout.Padding = UDim.new(0, 16)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = buttonRow

local function close()
    screenGui.Enabled = false
    for _, child in ipairs(buttonRow:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
end

------------------------------------------------------------------------------
-- Open with options
------------------------------------------------------------------------------

local function open(options)
    -- Clear any old buttons
    for _, child in ipairs(buttonRow:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    for i, characterKey in ipairs(options) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1 / #options, -8, 1, 0)
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Font = Enum.Font.GothamBold
        button.TextScaled = true
        button.Text = LABELS[characterKey] or characterKey
        button.LayoutOrder = i
        button.Parent = buttonRow

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 10)
        btnCorner.Parent = button

        button.MouseButton1Click:Connect(function()
            -- Disable all buttons so they can't double-pick
            for _, sibling in ipairs(buttonRow:GetChildren()) do
                if sibling:IsA("TextButton") then sibling.AutoButtonColor = false end
            end
            CharacterPicker:FireServer(characterKey)
            close()
        end)
    end

    screenGui.Enabled = true
end

------------------------------------------------------------------------------
-- Remote handler
------------------------------------------------------------------------------

CharacterPicker.OnClientEvent:Connect(function(optionsOrNil)
    if optionsOrNil == nil then
        close()
        return
    end
    if type(optionsOrNil) == "table" then
        open(optionsOrNil)
    end
end)
