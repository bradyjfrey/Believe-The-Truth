-- Otohime.lua
-- Otohime is the 2nd survivor (Warden). This is a STUB so far: she spawns, walks, and is selectable,
-- but her abilities aren't built yet. AbilityService calls into Otohime.Abilities by name when the
-- player presses a key; with the table empty it simply does nothing for her (no errors).
--
-- TO BUILD (numbers/keybinds live in `• specs/` -- don't invent them):
--   * Healing Pulse — pulses out from her and heals nearby survivors (~+20 HP) within a radius.
--                     Effect template: ReplicatedStorage.Effects.OtohimeHealingPulse.
--   * Dark Moon     — her attack. Effect template: ReplicatedStorage.Effects.OtohimeDarkMoon.
-- Each ability should follow the same shape as Momotaro's: check cooldown -> start cooldown ->
-- (optional windup) -> do the work -> EffectsService:Play(...) for the VFX/SFX.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local AbilityModule = require(ReplicatedStorage.Shared.AbilityModule)
local Types = require(ReplicatedStorage.Shared.Types)
local EffectsService = require(ServerScriptService.Services.EffectsService)

local Otohime = {}
Otohime.Abilities = {}

------------------------------------------------------------------------------
-- Little helpers (kept ready for when the abilities are built)
------------------------------------------------------------------------------

local function getHumanoid(player)
    local character = player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(player)
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isWarden(player)
    return player:GetAttribute("Team") == Types.Team.Warden
end

------------------------------------------------------------------------------
-- ABILITIES — to be built (see header). Examples of where they'll go:
--   Otohime.Abilities.HealingPulse = function(player, params) ... end
--   Otohime.Abilities.DarkMoon     = function(player, params) ... end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- PASSIVE — none wired yet. Bootstrap may call this once she has one.
------------------------------------------------------------------------------
function Otohime:StartPassives(player)
    -- No passive yet. (Left as the extension point so Bootstrap can call it later.)
end

return Otohime
