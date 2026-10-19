local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local AbilityModule = require(ReplicatedStorage.Shared.AbilityModule)
local Types = require(ReplicatedStorage.Shared.Types)

local T = Constants.TwoTimePrime

local TwoTimePrime = {}

TwoTimePrime.Abilities = {}

local function getHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isWarden(player)
    return player:GetAttribute("Team") == Types.Team.Warden
end

local function isYokai(player)
    return player:GetAttribute("Team") == Types.Team.Yokai
end

-- The lunge pose only, so the kids can see it. Damage and reach come with his kit.
TwoTimePrime.Abilities.Stab = function(player, params)
    if not AbilityModule.isOffCooldown(player, "Stab") then return end
    if not getRootPart(player.Character) then return end
    AbilityModule.startCooldown(player, "Stab", T.Stab.CooldownSeconds)
    local swingRemote = ReplicatedStorage.Remotes:FindFirstChild("WeaponSwing")
    if swingRemote then swingRemote:FireAllClients(player, "TwoTimePrimeStab") end
end

function TwoTimePrime:StartPassives(player)
end

return TwoTimePrime
