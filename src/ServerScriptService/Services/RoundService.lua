-- RoundService.lua
-- The brain of the round loop. There are three states:
--   * Lobby   — waiting for enough players, counting down
--   * InRound — picked teams, characters spawned, checking win conditions
--   * Ending  — round just finished, short pause before back to Lobby
--
-- Extension points for the team (search for "EXTENSION POINT" below):
--   * Errands — Wardens win by completing errands (not implemented yet)
--   * Citizens — non-player NPCs the Yokai also kill (not implemented yet)
--   * Per-player character ownership — right now everyone owns every character

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)

local RoundService = {}

local state = Types.RoundState.Lobby
local roundEndTime = 0
local lobbyEndTime = 0

-- playerCharacter[userId] = "Momotaro" / "Rokurokubi" / "GirlA"
local playerCharacter = {}
-- playerTeam[userId] = "Warden" / "Yokai"
local playerTeam = {}

local abilityService = nil
local disguiseService = nil

-- EXTENSION POINT: ownership. Today every player owns every character. Later
-- this will read from a saved profile. The shape stays the same.
local function ownsCharacter(player, characterName)
    return true
end

function RoundService:Init(deps)
    abilityService = deps.AbilityService
    disguiseService = deps.DisguiseService
    self:_enterLobby()
end

function RoundService:GetState()
    return state
end

function RoundService:IsInRound()
    return state == Types.RoundState.InRound
end

function RoundService:GetTeam(player)
    return playerTeam[player.UserId]
end

function RoundService:GetCharacter(player)
    return playerCharacter[player.UserId]
end

function RoundService:GetWardens()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if playerTeam[player.UserId] == Types.Team.Warden then
            table.insert(list, player)
        end
    end
    return list
end

function RoundService:GetYokai()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if playerTeam[player.UserId] == Types.Team.Yokai then
            table.insert(list, player)
        end
    end
    return list
end

------------------------------------------------------------------------------
-- State transitions
------------------------------------------------------------------------------

function RoundService:_enterLobby()
    state = Types.RoundState.Lobby
    playerCharacter = {}
    playerTeam = {}

    if disguiseService then disguiseService:DropAll() end

    -- Clear per-player state and respawn everyone in the lobby.
    for _, player in ipairs(Players:GetPlayers()) do
        if abilityService then abilityService:Clear(player) end
        player:SetAttribute("Team", nil)
        player:SetAttribute("Character", nil)
        player:SetAttribute("Wrapped", nil)
        player:SetAttribute("BeingStrangled", nil)
        player:SetAttribute("Incognito", nil)
        player:SetAttribute("Disguised", nil)
        player:SetAttribute("BreachPopupActive", nil)
        player:LoadCharacter()
    end

    -- Clean up any hotspots from last round.
    local hotspotFolder = workspace:FindFirstChild("Hotspots")
    if hotspotFolder then hotspotFolder:Destroy() end

    lobbyEndTime = tick() + Constants.Round.LobbyTimeSeconds
end

function RoundService:_enterRound()
    state = Types.RoundState.InRound

    local players = Players:GetPlayers()
    if #players < Constants.Round.MinPlayers then
        -- Lost a player while counting down — go back to lobby.
        self:_enterLobby()
        return
    end

    -- Pick one random Yokai.
    local yokaiPlayer = players[math.random(1, #players)]

    -- Pick which Yokai character. If they own Girl A AND Rokurokubi, random
    -- for now. TODO: pre-round picker UI lets them choose.
    local yokaiOptions = {}
    if ownsCharacter(yokaiPlayer, Types.Character.Rokurokubi) then
        table.insert(yokaiOptions, Types.Character.Rokurokubi)
    end
    if ownsCharacter(yokaiPlayer, Types.Character.GirlA) then
        table.insert(yokaiOptions, Types.Character.GirlA)
    end
    if #yokaiOptions == 0 then
        warn("[RoundService] picked yokai player owns no Yokai characters — falling back to Rokurokubi")
        table.insert(yokaiOptions, Types.Character.Rokurokubi)
    end
    local yokaiCharacter = yokaiOptions[math.random(1, #yokaiOptions)]

    -- Assign teams + characters and respawn so the character gets fresh HP.
    for _, player in ipairs(players) do
        if player == yokaiPlayer then
            playerTeam[player.UserId] = Types.Team.Yokai
            playerCharacter[player.UserId] = yokaiCharacter
        else
            playerTeam[player.UserId] = Types.Team.Warden
            playerCharacter[player.UserId] = Types.Character.Momotaro
        end
        player:SetAttribute("Team", playerTeam[player.UserId])
        player:SetAttribute("Character", playerCharacter[player.UserId])
        abilityService:SetCharacter(player, playerCharacter[player.UserId])
        player:LoadCharacter()
    end

    -- Spawn placeholder Hotspots so Girl A's Incognito teleport works.
    -- EXTENSION POINT: the team can place real hotspots in Studio later.
    -- If a "Hotspots" folder is already in Workspace at round start, we'll
    -- skip making placeholders.
    self:_spawnPlaceholderHotspots()

    roundEndTime = tick() + Constants.Round.RoundLengthSeconds
end

function RoundService:_spawnPlaceholderHotspots()
    if workspace:FindFirstChild("Hotspots") then return end

    local folder = Instance.new("Folder")
    folder.Name = "Hotspots"
    folder.Parent = workspace

    -- Simple ring of 4 positions around the world origin. Replace with real
    -- positions when the team builds proper map placements.
    local positions = {
        Vector3.new(60, 5, 0),
        Vector3.new(-60, 5, 0),
        Vector3.new(0, 5, 60),
        Vector3.new(0, 5, -60),
    }
    for i = 1, Constants.GirlA.Hotspots.Count do
        local hotspot = Instance.new("Part")
        hotspot.Name = "Hotspot" .. i
        hotspot.Size = Vector3.new(4, 0.5, 4)
        hotspot.Color = Color3.fromRGB(150, 100, 255)
        hotspot.Material = Enum.Material.Neon
        hotspot.Anchored = true
        hotspot.CanCollide = false
        hotspot.Position = positions[i] or Vector3.new(0, 5, 0)
        hotspot.Parent = folder

        -- ClickDetector so Girl A can click the hotspot to teleport to it
        -- (works only while she's in Incognito Mode — checked server-side
        -- in GirlA.HotspotTeleport). MaxActivationDistance is high because
        -- she can click from anywhere on the map.
        local clickDetector = Instance.new("ClickDetector")
        clickDetector.MaxActivationDistance = 1000
        clickDetector.Parent = hotspot
        clickDetector.MouseClick:Connect(function(player)
            if abilityService then
                abilityService:Handle(player, "HotspotTeleport", {Hotspot = hotspot})
            end
        end)
    end
end

function RoundService:_checkWinConditions()
    local wardensAlive = 0
    local yokaiAlive = 0
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local alive = humanoid and humanoid.Health > 0
        if alive then
            if playerTeam[player.UserId] == Types.Team.Warden then
                wardensAlive = wardensAlive + 1
            elseif playerTeam[player.UserId] == Types.Team.Yokai then
                yokaiAlive = yokaiAlive + 1
            end
        end
    end

    -- Per Brady's rules:
    --   Wardens win when all Yokai are dead OR time runs out (they survived).
    --   Yokai win when all Wardens are dead.
    if wardensAlive == 0 then
        return "Yokai"
    elseif yokaiAlive == 0 then
        return "Wardens"
    elseif tick() >= roundEndTime then
        return "Wardens"
    end
    return nil
end

function RoundService:_enterEnding(winners)
    state = Types.RoundState.Ending
    print(string.format("[Round] %s win!", winners))
    task.delay(Constants.Round.EndOfRoundDelaySeconds, function()
        self:_enterLobby()
    end)
end

------------------------------------------------------------------------------
-- Tick: called once per second by Bootstrap.
------------------------------------------------------------------------------

function RoundService:Tick()
    if state == Types.RoundState.Lobby then
        if #Players:GetPlayers() < Constants.Round.MinPlayers then
            -- Reset the countdown until we have enough players again.
            lobbyEndTime = tick() + Constants.Round.LobbyTimeSeconds
        elseif tick() >= lobbyEndTime then
            self:_enterRound()
        end
    elseif state == Types.RoundState.InRound then
        local winner = self:_checkWinConditions()
        if winner then
            self:_enterEnding(winner)
        end
    end
end

return RoundService
