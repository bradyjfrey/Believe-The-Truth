-- Incognito.client.lua
-- Girl A's Incognito Mode makes her invisible to all other players. We can't
-- do "invisible to others" on the server alone (Transparency replicates to
-- everyone), so this client script watches every player's Incognito
-- attribute and locally renders them invisible or semi-transparent.
--
-- Brady's call: invisible to ALL other players (including other Yokai). The
-- Incognito player sees themselves semi-transparent so they know it's working.

local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

------------------------------------------------------------------------------
-- Set the local view of a player to a given transparency.
-- LocalTransparencyModifier is a per-client modifier; setting it doesn't
-- replicate to other players.
------------------------------------------------------------------------------

local function applyTransparency(player, transparency)
    local character = player.Character
    if not character then return end

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.LocalTransparencyModifier = transparency
        end
    end

    -- Hide the floating name + health bar when fully invisible.
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.NameDisplayDistance = transparency >= 1 and 0 or 100
        humanoid.HealthDisplayDistance = transparency >= 1 and 0 or 100
    end
end

local function updatePlayer(player)
    local incognito = player:GetAttribute("Incognito")
    if not incognito then
        applyTransparency(player, 0)
        return
    end
    if player == localPlayer then
        -- Self-view: semi-transparent so you can still see what you're doing.
        applyTransparency(player, 0.7)
    else
        -- Everyone else: fully invisible.
        applyTransparency(player, 1)
    end
end

local function watchPlayer(player)
    player:GetAttributeChangedSignal("Incognito"):Connect(function()
        updatePlayer(player)
    end)
    player.CharacterAdded:Connect(function()
        -- Wait a moment for parts to load, then re-apply.
        task.wait(0.1)
        updatePlayer(player)
    end)
    if player.Character then updatePlayer(player) end
end

for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)
