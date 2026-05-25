-- Bootstrap.server.lua
-- This is the one server script that boots up the whole game. It:
--   1. Turns off Roblox's auto-respawn (RoundService takes over)
--   2. Creates the RemoteEvents in ReplicatedStorage/Remotes
--   3. Creates the Companions folder for the art team
--   4. Wires up the services with their dependencies
--   5. Listens to the client remotes and routes them to AbilityService
--   6. Sets up per-character HP and walk speed when a character spawns
--   7. Starts the round-tick loop

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Disable Roblox's automatic respawn so dead players spectate until the next
-- round. RoundService calls player:LoadCharacter() when it's time to respawn.
Players.CharacterAutoLoads = false

-- Seed math.random with the current time so Yokai picks don't pattern-repeat
-- across test sessions. Otherwise Roblox's default seed gives the same
-- sequence every run.
math.randomseed(os.time())

local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterAppearance = require(ReplicatedStorage.Shared.CharacterAppearance)

local RoundService = require(ServerScriptService.Services.RoundService)
local AbilityService = require(ServerScriptService.Services.AbilityService)
local DisguiseService = require(ServerScriptService.Services.DisguiseService)
-- (BleedService and EffectsService run themselves — no init needed.)

local Momotaro = require(ServerScriptService.Characters.Momotaro)
local Rokurokubi = require(ServerScriptService.Characters.Rokurokubi)
local GirlA = require(ServerScriptService.Characters.GirlA)

------------------------------------------------------------------------------
-- Folders + Remotes in ReplicatedStorage
------------------------------------------------------------------------------

local function ensureFolder(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing then return existing end
    local folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = parent
    return folder
end

local Remotes = ensureFolder(ReplicatedStorage, "Remotes")
ensureFolder(ReplicatedStorage, "Companions")

local function ensureRemote(name, className)
    local existing = Remotes:FindFirstChild(name)
    if existing then return existing end
    local remote = Instance.new(className)
    remote.Name = name
    remote.Parent = Remotes
    return remote
end

local AbilityRequest        = ensureRemote("AbilityRequest", "RemoteEvent")
local NeckWrapMash          = ensureRemote("NeckWrapMash", "RemoteEvent")
local BreachClose           = ensureRemote("BreachClose", "RemoteEvent")
local DisguisePickerSelect  = ensureRemote("DisguisePickerSelect", "RemoteEvent")
local CharacterPicker       = ensureRemote("CharacterPicker", "RemoteEvent")

------------------------------------------------------------------------------
-- Wire services together
------------------------------------------------------------------------------

local characterModules = {
    [Types.Character.Momotaro]    = Momotaro,
    [Types.Character.Rokurokubi]  = Rokurokubi,
    [Types.Character.GirlA]       = GirlA,
}
AbilityService:Init(characterModules, RoundService)
RoundService:Init({
    AbilityService = AbilityService,
    DisguiseService = DisguiseService,
})

------------------------------------------------------------------------------
-- Client-to-server remote handlers
------------------------------------------------------------------------------

AbilityRequest.OnServerEvent:Connect(function(player, abilityName, params)
    if typeof(abilityName) ~= "string" then return end
    AbilityService:Handle(player, abilityName, params)
end)

NeckWrapMash.OnServerEvent:Connect(function(player)
    Rokurokubi.RegisterMash(player)
end)

BreachClose.OnServerEvent:Connect(function(player)
    if player:GetAttribute("BreachPopupActive") then
        player:SetAttribute("BreachPopupActive", nil)
    end
end)

DisguisePickerSelect.OnServerEvent:Connect(function(player, targetUserId)
    if typeof(targetUserId) ~= "number" then return end
    local target = Players:GetPlayerByUserId(targetUserId)
    if not target then return end
    AbilityService:Handle(player, "Disguise", {TargetPlayer = target})
end)

------------------------------------------------------------------------------
-- Per-character setup when a character spawns
------------------------------------------------------------------------------

local function applyCharacterStats(player, character)
    local humanoid = character:WaitForChild("Humanoid")
    local characterName = player:GetAttribute("Character")
    if not characterName then return end

    -- Apply appearance FIRST. ApplyDescription resets Health to 100, so we
    -- set MaxHealth/Health after this call.
    CharacterAppearance.apply(player, characterName)

    if characterName == Types.Character.Momotaro then
        humanoid.MaxHealth = Constants.Momotaro.MaxHealth
        humanoid.Health = humanoid.MaxHealth
        humanoid.WalkSpeed = Constants.Speed.WardenWalk
        Momotaro:StartPassives(player)
    elseif characterName == Types.Character.Rokurokubi then
        humanoid.MaxHealth = Constants.Rokurokubi.MaxHealth
        humanoid.Health = humanoid.MaxHealth
        humanoid.WalkSpeed = Constants.Speed.RokurokubiWalk
        Rokurokubi:StartPassives(player)
    elseif characterName == Types.Character.GirlA then
        humanoid.MaxHealth = Constants.GirlA.MaxHealth
        humanoid.Health = humanoid.MaxHealth
        humanoid.WalkSpeed = Constants.Speed.GirlAWalk
        GirlA:StartPassives(player)
    end
end

local function watchPlayer(player)
    player.CharacterAdded:Connect(function(character)
        applyCharacterStats(player, character)
    end)
    if player.Character then
        applyCharacterStats(player, player.Character)
    end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
    watchPlayer(player)
end

------------------------------------------------------------------------------
-- Round tick: once per second, RoundService decides if state needs to change.
------------------------------------------------------------------------------

task.spawn(function()
    while true do
        RoundService:Tick()
        task.wait(1)
    end
end)
