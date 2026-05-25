-- AbilityModule.lua
-- Shared helpers any ability function can use. Right now the main job is
-- tracking cooldowns so each character module doesn't have to.
--
-- This is NOT a base class. Characters don't inherit from it. They just call
-- functions like AbilityModule.isOffCooldown(player, "Katana").

local AbilityModule = {}

-- cooldowns[playerUserId][abilityName] = the tick() time when it's ready again
local cooldowns = {}

function AbilityModule.isOffCooldown(player, abilityName)
    local playerCooldowns = cooldowns[player.UserId]
    if not playerCooldowns then return true end
    local readyAt = playerCooldowns[abilityName]
    if not readyAt then return true end
    return tick() >= readyAt
end

function AbilityModule.startCooldown(player, abilityName, seconds)
    cooldowns[player.UserId] = cooldowns[player.UserId] or {}
    cooldowns[player.UserId][abilityName] = tick() + seconds
end

function AbilityModule.secondsRemaining(player, abilityName)
    local playerCooldowns = cooldowns[player.UserId]
    if not playerCooldowns then return 0 end
    local readyAt = playerCooldowns[abilityName]
    if not readyAt then return 0 end
    return math.max(0, readyAt - tick())
end

-- Called when a player swaps character or leaves the round, so old cooldowns
-- don't follow them into a new life.
function AbilityModule.resetForPlayer(player)
    cooldowns[player.UserId] = nil
end

return AbilityModule
