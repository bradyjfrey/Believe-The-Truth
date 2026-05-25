-- AbilityService.lua
-- The gatekeeper between the client and a character's ability code. When a
-- player presses a key, their client fires AbilityRequest to the server, and
-- the server calls AbilityService:Handle. This module checks:
--   * is the round actually running?
--   * is the player alive?
--   * is the player on the right character to use this ability?
-- Then it calls the matching function in the character's module.
--
-- Cooldowns are checked INSIDE each ability function — see AbilityModule.

local AbilityService = {}

-- Active character per player. Set by RoundService when teams are picked.
-- {playerUserId = "Momotaro" | "Rokurokubi" | "GirlA"}
local activeCharacter = {}

-- Filled in by Bootstrap so we don't get circular requires.
local characterModules = {}
local roundService = nil

function AbilityService:Init(modules, round)
    characterModules = modules
    roundService = round
end

function AbilityService:SetCharacter(player, characterName)
    activeCharacter[player.UserId] = characterName
end

function AbilityService:GetCharacter(player)
    return activeCharacter[player.UserId]
end

function AbilityService:Clear(player)
    activeCharacter[player.UserId] = nil
end

function AbilityService:Handle(player, abilityName, params)
    -- Bail early on any of the gate checks.
    if not roundService or not roundService:IsInRound() then return end

    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local charName = activeCharacter[player.UserId]
    if not charName then return end

    local module = characterModules[charName]
    if not module or not module.Abilities then return end

    local handler = module.Abilities[abilityName]
    if not handler then
        warn(string.format("[AbilityService] %s has no ability '%s'", charName, tostring(abilityName)))
        return
    end

    -- The character handler is responsible for checking + starting its own
    -- cooldown, doing the work, and calling EffectsService for VFX/SFX.
    -- Wrap in pcall so a broken handler doesn't crash the server.
    local ok, err = pcall(handler, player, params or {})
    if not ok then
        warn(string.format("[AbilityService] error in %s.%s: %s", charName, abilityName, tostring(err)))
    end
end

return AbilityService
