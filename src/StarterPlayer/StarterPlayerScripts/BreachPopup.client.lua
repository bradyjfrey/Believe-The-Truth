-- BreachPopup.client.lua
-- When Girl A's Breach of Privacy hits this player, the server sets the
-- BreachPopupActive attribute to true. We show an obnoxious pop-up with a
-- close button. If the player closes early, we fire BreachClose to the
-- server (which deals damage). If they wait 7 seconds, the server clears
-- the attribute itself and we just hide the popup.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BreachClose = Remotes:WaitForChild("BreachClose")

------------------------------------------------------------------------------
-- Build the popup once.
------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BreachPopup"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 100
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local popup = Instance.new("Frame")
popup.Size = UDim2.fromOffset(360, 200)
popup.Position = UDim2.fromScale(0.5, 0.5)
popup.AnchorPoint = Vector2.new(0.5, 0.5)
popup.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
popup.BorderSizePixel = 2
popup.BorderColor3 = Color3.fromRGB(255, 255, 255)
popup.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
title.BorderSizePixel = 0
title.Text = "  Pop-up!"
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = popup

local body = Instance.new("TextLabel")
body.Size = UDim2.new(1, -20, 1, -90)
body.Position = UDim2.new(0, 10, 0, 46)
body.BackgroundTransparency = 1
body.Text = "Your privacy has been breached.\nClose this... if you dare."
body.TextColor3 = Color3.fromRGB(255, 255, 255)
body.TextScaled = true
body.Font = Enum.Font.Gotham
body.TextWrapped = true
body.Parent = popup

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 100, 0, 30)
closeButton.Position = UDim2.new(1, -110, 1, -40)
closeButton.Text = "Close"
closeButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextColor3 = Color3.fromRGB(0, 0, 0)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextScaled = true
closeButton.Parent = popup

closeButton.MouseButton1Click:Connect(function()
    if not localPlayer:GetAttribute("BreachPopupActive") then return end
    BreachClose:FireServer()
    screenGui.Enabled = false
end)

------------------------------------------------------------------------------
-- React to the server toggling the attribute.
------------------------------------------------------------------------------

local function update()
    screenGui.Enabled = localPlayer:GetAttribute("BreachPopupActive") == true
end

localPlayer:GetAttributeChangedSignal("BreachPopupActive"):Connect(update)
update()
