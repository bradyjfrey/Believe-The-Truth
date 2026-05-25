-- DisguiseService.lua
-- Handles Rokurokubi's Disguise ability. When she disguises, we change her
-- body to look like the chosen Warden using Roblox's HumanoidDescription
-- system, and we swap her displayed name. When the disguise drops, we put
-- everything back the way it was.
--
-- The disguise can drop because:
--   * The 19-second timer ran out (Rokurokubi.lua)
--   * She used Bite (Rokurokubi.lua calls Drop)
--   * She used Strangle (Rokurokubi.lua calls Drop)
--   * She took any damage (we watch HealthChanged in Apply)
--   * She manually canceled with R (Rokurokubi.lua)
--   * The round ended (RoundService calls DropAll)

local Players = game:GetService("Players")

local DisguiseService = {}

-- active[rokurokubiPlayer] = {
--   description = original HumanoidDescription,
--   displayName = original DisplayName,
--   target = the Warden player she copied,
--   healthConn = the HealthChanged connection (so we can disconnect it),
--   startHealth = her health when the disguise started,
-- }
local active = {}

function DisguiseService:IsDisguised(player)
    return active[player] ~= nil
end

function DisguiseService:GetCopiedTarget(player)
    return active[player] and active[player].target or nil
end

function DisguiseService:Apply(rokurokubiPlayer, targetWardenPlayer)
    local character = rokurokubiPlayer.Character
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    -- Save the originals so we can restore them on drop.
    local originalDesc = humanoid:GetAppliedDescription()
    local originalDisplayName = humanoid.DisplayName

    -- Pull the target's appearance. This calls Roblox's web service, so wrap
    -- in pcall in case of network hiccups.
    local ok, targetDesc = pcall(function()
        return Players:GetHumanoidDescriptionFromUserId(targetWardenPlayer.UserId)
    end)
    if not ok or not targetDesc then
        warn("DisguiseService: failed to fetch HumanoidDescription for " .. targetWardenPlayer.Name)
        return false
    end

    humanoid:ApplyDescription(targetDesc)
    humanoid.DisplayName = targetWardenPlayer.DisplayName

    -- Watch for any damage. Taking ANY damage breaks the disguise (per spec).
    local startHealth = humanoid.Health
    local healthConn
    healthConn = humanoid.HealthChanged:Connect(function(newHealth)
        if newHealth < startHealth - 0.01 then
            DisguiseService:Drop(rokurokubiPlayer)
        end
    end)

    active[rokurokubiPlayer] = {
        description = originalDesc,
        displayName = originalDisplayName,
        target = targetWardenPlayer,
        healthConn = healthConn,
        startHealth = startHealth,
    }

    -- Tell the client(s) so any UI knows she's disguised.
    rokurokubiPlayer:SetAttribute("Disguised", true)
    return true
end

function DisguiseService:Drop(rokurokubiPlayer)
    local state = active[rokurokubiPlayer]
    if not state then return end

    if state.healthConn then state.healthConn:Disconnect() end

    local character = rokurokubiPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ApplyDescription(state.description)
            humanoid.DisplayName = state.displayName
        end
    end
    active[rokurokubiPlayer] = nil
    rokurokubiPlayer:SetAttribute("Disguised", nil)
end

function DisguiseService:DropAll()
    for player in pairs(active) do
        self:Drop(player)
    end
end

return DisguiseService
