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

-- Roblox's modern RNG. Each instance is auto-seeded with high precision,
-- so we don't get repeated sequences across test sessions like math.random
-- sometimes does.
local rng = Random.new()

-- Publishes the current round state to the client HUD by setting attributes
-- on ReplicatedStorage/Remotes. The HUD just reads these attributes.
local function publish(key, value)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		remotes:SetAttribute(key, value)
	end
end

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

	-- Clear per-player state FIRST in a single pass so the Character attribute
	-- definitely reads nil before any CharacterAdded handler can run.
	for _, player in ipairs(Players:GetPlayers()) do
		if abilityService then abilityService:Clear(player) end
		player:SetAttribute("Team", nil)
		player:SetAttribute("Character", nil)
		player:SetAttribute("Wrapped", nil)
		player:SetAttribute("BeingStrangled", nil)
		player:SetAttribute("Incognito", nil)
		player:SetAttribute("Disguised", nil)
		player:SetAttribute("BreachPopupActive", nil)
	end

	-- Wait a frame so the attribute clears propagate, then respawn everyone.
	-- Without this, CharacterAdded can fire BEFORE the nil attribute is seen,
	-- and the character keeps its round styling in the lobby.
	task.wait()

	for _, player in ipairs(Players:GetPlayers()) do
		player:LoadCharacter()
	end

	-- Clean up any hotspots from last round.
	local hotspotFolder = workspace:FindFirstChild("Hotspots")
	if hotspotFolder then hotspotFolder:Destroy() end

	lobbyEndTime = tick() + Constants.Round.LobbyTimeSeconds
	publish("RoundState", Types.RoundState.Lobby)
	publish("SecondsRemaining", Constants.Round.LobbyTimeSeconds)
	publish("PlayersInLobby", #Players:GetPlayers())
	publish("PlayersNeeded", Constants.Round.MinPlayers)
	publish("HasEnoughPlayers", #Players:GetPlayers() >= Constants.Round.MinPlayers)
end

function RoundService:_enterRound()
	state = Types.RoundState.InRound

	local players = Players:GetPlayers()
	if #players < Constants.Round.MinPlayers then
		-- Lost a player while counting down — go back to lobby.
		self:_enterLobby()
		return
	end

	-- Pick one random Yokai player.
	local yokaiPlayer = players[rng:NextInteger(1, #players)]

	-- Build the list of Yokai characters this player owns.
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

	local yokaiCharacter
	if #yokaiOptions == 1 then
		yokaiCharacter = yokaiOptions[1]
	else
		-- Ask the picked player to choose. If they don't pick in time, default
		-- to a random one so the round still starts.
		yokaiCharacter = self:_askPlayerToPick(yokaiPlayer, yokaiOptions)
	end
	print(string.format("[RoundService] Yokai options: [%s], chosen -> %s",
		table.concat(yokaiOptions, ", "), yokaiCharacter))

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
	publish("RoundState", Types.RoundState.InRound)
	publish("SecondsRemaining", Constants.Round.RoundLengthSeconds)
end

-- Asks the player to pick from `options`. Shows them a UI via the
-- CharacterPicker remote, waits up to PickTimeoutSeconds for them to choose,
-- and falls back to random if they don't.
function RoundService:_askPlayerToPick(player, options)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local picker = remotes and remotes:FindFirstChild("CharacterPicker")
	if not picker then
		return options[rng:NextInteger(1, #options)]
	end

	-- Tell the client to open the picker with these options.
	picker:FireClient(player, options)

	-- Listen for their pick.
	local chosen = nil
	local conn
	conn = picker.OnServerEvent:Connect(function(firingPlayer, choice)
		if firingPlayer ~= player then return end
		for _, valid in ipairs(options) do
			if choice == valid then
				chosen = choice
				break
			end
		end
	end)

	local pickTimeoutSeconds = 10
	local startTime = tick()
	while not chosen and (tick() - startTime) < pickTimeoutSeconds do
		task.wait(0.1)
	end
	conn:Disconnect()

	if not chosen then
		chosen = options[rng:NextInteger(1, #options)]
		print(string.format("[RoundService] %s didn't pick in time — using %s", player.Name, chosen))
	end

	-- Tell the client the picker can close.
	picker:FireClient(player, nil)
	return chosen
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
		--
		-- We pre-filter here: only forward to AbilityService if the clicker
		-- is actually Girl A. Otherwise every Warden click would spam an
		-- "Momotaro has no ability HotspotTeleport" warning.
		local clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 1000
		clickDetector.Parent = hotspot
		clickDetector.MouseClick:Connect(function(player)
			if not abilityService then return end
			if player:GetAttribute("Character") ~= Types.Character.GirlA then return end
			abilityService:Handle(player, "HotspotTeleport", {Hotspot = hotspot})
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
	publish("RoundState", Types.RoundState.Ending)
	publish("Winners", winners)
	publish("SecondsRemaining", Constants.Round.EndOfRoundDelaySeconds)
	task.delay(Constants.Round.EndOfRoundDelaySeconds, function()
		publish("Winners", nil)
		self:_enterLobby()
	end)
end

------------------------------------------------------------------------------
-- Tick: called once per second by Bootstrap.
------------------------------------------------------------------------------

function RoundService:Tick()
	if state == Types.RoundState.Lobby then
		local currentPlayers = #Players:GetPlayers()
		publish("PlayersInLobby", currentPlayers)
		if currentPlayers < Constants.Round.MinPlayers then
			-- Reset the countdown until we have enough players again.
			lobbyEndTime = tick() + Constants.Round.LobbyTimeSeconds
			publish("SecondsRemaining", Constants.Round.LobbyTimeSeconds)
			publish("HasEnoughPlayers", false)
		elseif tick() >= lobbyEndTime then
			self:_enterRound()
		else
			-- Clamp to LobbyTimeSeconds so a stale lobbyEndTime can never
			-- display a wildly-large number like "Starts in 2:20".
			local remaining = math.max(0, math.floor(lobbyEndTime - tick()))
			remaining = math.min(remaining, Constants.Round.LobbyTimeSeconds)
			publish("SecondsRemaining", remaining)
			publish("HasEnoughPlayers", true)
		end
	elseif state == Types.RoundState.InRound then
		publish("SecondsRemaining", math.max(0, math.floor(roundEndTime - tick())))
		local winner = self:_checkWinConditions()
		if winner then
			self:_enterEnding(winner)
		end
	end
end

return RoundService
