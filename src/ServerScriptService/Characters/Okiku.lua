local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)

local O = Constants.Okiku

local Okiku = {}

Okiku.Abilities = {}

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

function Okiku:StartPassives(player)
end

return Okiku
