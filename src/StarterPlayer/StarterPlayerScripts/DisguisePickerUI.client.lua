-- DisguisePickerUI.client.lua
-- When the local player is Rokurokubi, this script binds R to open a picker
-- UI listing every Warden in the round (alive or dead). Tapping a row sends
-- DisguisePickerSelect to the server with the chosen Warden's UserId, which
-- triggers the Disguise ability.
--
-- This script owns Rokurokubi's R key. AbilityInput doesn't bind R for her.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local localPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DisguisePickerSelect = Remotes:WaitForChild("DisguisePickerSelect")

------------------------------------------------------------------------------
-- Build the UI once. Show/hide it as needed.
------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DisguisePicker"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel = 0
backdrop.Parent = screenGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(420, 540)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
panel.BorderSizePixel = 0
panel.Parent = backdrop

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundTransparency = 1
title.Text = "Pick a Warden to copy"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = panel

local scroller = Instance.new("ScrollingFrame")
scroller.Size = UDim2.new(1, -20, 1, -110)
scroller.Position = UDim2.new(0, 10, 0, 60)
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.CanvasSize = UDim2.fromOffset(0, 0)
scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroller.ScrollBarThickness = 6
scroller.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 6)
listLayout.Parent = scroller

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(1, -20, 0, 35)
closeButton.Position = UDim2.new(0, 10, 1, -45)
closeButton.Text = "Cancel"
closeButton.BackgroundColor3 = Color3.fromRGB(80, 50, 50)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.Gotham
closeButton.TextScaled = true
closeButton.Parent = panel

local function close()
    screenGui.Enabled = false
end
closeButton.MouseButton1Click:Connect(close)

------------------------------------------------------------------------------
-- Build the row list every time the picker opens (Wardens can join/leave).
------------------------------------------------------------------------------

local function populate()
    for _, child in ipairs(scroller:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("Team") == "Warden" then
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, 0, 0, 60)
            row.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
            row.TextColor3 = Color3.fromRGB(255, 255, 255)
            row.Font = Enum.Font.Gotham
            row.TextScaled = true
            local suffix = player.Character and "" or "  (dead)"
            row.Text = player.DisplayName .. suffix
            row.Parent = scroller

            local rowCorner = Instance.new("UICorner")
            rowCorner.CornerRadius = UDim.new(0, 6)
            rowCorner.Parent = row

            row.MouseButton1Click:Connect(function()
                DisguisePickerSelect:FireServer(player.UserId)
                close()
            end)
        end
    end
end

local function open()
    populate()
    screenGui.Enabled = true
end

------------------------------------------------------------------------------
-- Bind R only when the local player is Rokurokubi. Higher priority than
-- AbilityInput so this binding wins for Rokurokubi.
------------------------------------------------------------------------------

local ACTION = "OpenDisguisePicker"

local function updateBinding()
    ContextActionService:UnbindAction(ACTION)
    if localPlayer:GetAttribute("Character") == "Rokurokubi" then
        ContextActionService:BindActionAtPriority(ACTION, function(_, inputState)
            if inputState == Enum.UserInputState.Begin then
                if screenGui.Enabled then close() else open() end
                return Enum.ContextActionResult.Sink
            end
        end, true, 2000, Enum.KeyCode.R)
        ContextActionService:SetTitle(ACTION, "Disguise")
    end
end

localPlayer:GetAttributeChangedSignal("Character"):Connect(updateBinding)
updateBinding()
