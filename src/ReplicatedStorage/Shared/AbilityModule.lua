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
    -- Tell that player's HUD so it can gray out the ability icon and count down.
    -- GetServerTimeNow is the SAME clock on the server and every client, so the
    -- client can count down to this exact moment without any drift.
    player:SetAttribute("AbilityReadyAt_" .. abilityName, workspace:GetServerTimeNow() + seconds)
end

function AbilityModule.secondsRemaining(player, abilityName)
    local playerCooldowns = cooldowns[player.UserId]
    if not playerCooldowns then return 0 end
    local readyAt = playerCooldowns[abilityName]
    if not readyAt then return 0 end
    return math.max(0, readyAt - tick())
end

-- charges[playerUserId][abilityName] = {count = uses left, token = identifies the current recharge loop}
local charges = {}

local function publishCharges(player, abilityName, state)
    player:SetAttribute("AbilityCharges_" .. abilityName, state.count)
    player:SetAttribute("AbilityReadyAt_" .. abilityName, state.count == 0 and state.nextChargeAt or nil)
end

-- Spends one charge if any are left and returns true. Spent charges come back one at a
-- time, each taking rechargeSeconds, until the ability is full again.
function AbilityModule.useCharge(player, abilityName, maxCharges, rechargeSeconds)
    charges[player.UserId] = charges[player.UserId] or {}
    local state = charges[player.UserId][abilityName]
    if not state then
        state = {count = maxCharges}
        charges[player.UserId][abilityName] = state
    end
    if state.count <= 0 then return false end

    state.count -= 1
    if not state.token then state.nextChargeAt = workspace:GetServerTimeNow() + rechargeSeconds end
    publishCharges(player, abilityName, state)

    if not state.token then
        local token = {}
        state.token = token
        local function stillCurrent()
            local mine = charges[player.UserId]
            return mine ~= nil and mine[abilityName] == state and state.token == token
        end
        task.spawn(function()
            while stillCurrent() and state.count < maxCharges do
                task.wait(state.nextChargeAt - workspace:GetServerTimeNow())
                if not stillCurrent() then return end
                state.count += 1
                state.nextChargeAt = workspace:GetServerTimeNow() + rechargeSeconds
                publishCharges(player, abilityName, state)
            end
            if state.token == token then state.token = nil end
        end)
    end
    return true
end

-- Called when a player swaps character or leaves the round, so old cooldowns
-- don't follow them into a new life.
function AbilityModule.resetForPlayer(player)
    cooldowns[player.UserId] = nil
    charges[player.UserId] = nil
    -- Clear the HUD attributes too, so no stale "recharging" icons follow them.
    for name in pairs(player:GetAttributes()) do
        if string.sub(name, 1, 15) == "AbilityReadyAt_" or string.sub(name, 1, 15) == "AbilityCharges_" then
            player:SetAttribute(name, nil)
        end
    end
end

return AbilityModule
