local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)

local T = Constants.Tomino

local Tomino = {}

Tomino.Abilities = {}

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

function Tomino:StartPassives(player)
end

return Tomino
