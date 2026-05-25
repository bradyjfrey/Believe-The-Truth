-- Sprint.client.lua
-- Hold Shift to run faster. Each character has its own walk/sprint speeds
-- in Constants.lua. Characters not listed in SPEEDS here can't sprint.
--
-- Walk speed gets reset to the character's default whenever they spawn —
-- Bootstrap.server.lua handles that. Sprint just temporarily bumps the
-- speed while Shift is held.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local localPlayer = Players.LocalPlayer

-- Per-character {walk, sprint}. Characters missing here don't sprint.
local SPEEDS = {
    Momotaro    = {Walk = Constants.Speed.WardenWalk,     Sprint = Constants.Speed.WardenSprint},
    Rokurokubi  = {Walk = Constants.Speed.RokurokubiWalk, Sprint = Constants.Speed.RokurokubiSprint},
    GirlA       = {Walk = Constants.Speed.GirlAWalk,      Sprint = Constants.Speed.GirlARun},
}

local function setSpeed(speed)
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.WalkSpeed = speed end
end

ContextActionService:BindAction("Sprint", function(_, inputState)
    local characterName = localPlayer:GetAttribute("Character")
    local pair = SPEEDS[characterName]
    if not pair then return end

    -- Don't override Incognito Mode's speed boost.
    if localPlayer:GetAttribute("Incognito") then return end

    if inputState == Enum.UserInputState.Begin then
        setSpeed(pair.Sprint)
    elseif inputState == Enum.UserInputState.End then
        setSpeed(pair.Walk)
    end
end, true, Enum.KeyCode.LeftShift)
ContextActionService:SetTitle("Sprint", "Run")
