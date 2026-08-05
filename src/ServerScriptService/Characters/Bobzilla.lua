local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)

local B = Constants.Bobzilla

local Bobzilla = {}

Bobzilla.Abilities = {}

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

function Bobzilla:StartPassives(player)
end

return Bobzilla
