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
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)

local RoundService = {}

-- Roblox's modern RNG. Each instance is auto-seeded with high precision,
-- so we don't get repeated sequences across test sessions like math.random
-- sometimes does.
local rng = Random.new()

-- Lobby background music. The script makes this Sound itself (no need to keep one in
-- the place); a server-owned Sound in SoundService replicates to every client, so
-- everyone hears it. It plays while waiting in the lobby and stops when a round starts.
-- TODO: move the id into Constants once we add more tracks (map themes, etc.).
local lobbyMusic = Instance.new("Sound")
lobbyMusic.Name = "LobbyMusic"
lobbyMusic.SoundId = "rbxassetid://115719912767412"
lobbyMusic.Looped = true
lobbyMusic.Volume = 0.5
lobbyMusic.Parent = SoundService

-- In-round "chase" music (CODE RED). Same idea as the lobby music: a server-owned
-- Sound that everyone hears. It plays while a round is happening and stops the moment
-- we go back to the lobby. (This audio may be pending Roblox moderation — the code is
-- ready and it'll start playing on its own once Roblox approves the upload.)
local roundMusic = Instance.new("Sound")
roundMusic.Name = "RoundMusic"
roundMusic.SoundId = "rbxassetid://116756933501242"
roundMusic.Looped = true
roundMusic.Volume = 0.5
roundMusic.Parent = SoundService

-- Publishes the current round state to the client HUD by setting attributes
-- on ReplicatedStorage/Remotes. The HUD just reads these attributes.
local function publish(key, value)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		remotes:SetAttribute(key, value)
	end
end

------------------------------------------------------------------------------
-- Spawning helpers
--
-- WHERE players appear is controlled by named marker Parts the art team places
-- in the Workspace. They aren't in git (Workspace isn't synced), so we find them
-- by name and fall back to a safe spot if one is ever missing:
--   * "LobbySpawn"  - in the Finished Lobby; where everyone waits and hangs out
--   * "WardenSpawn" - in Map 1; where the survivors (Wardens) start (blue area)
--   * "YokaiSpawn"  - in Map 1; where the killer (Yokai) starts, away from the
--                     Wardens so it's fair (red area)
------------------------------------------------------------------------------

-- How far (in studs) to randomly spread players around a marker so a whole team
-- doesn't pile up on the exact same point.
local SPAWN_SCATTER = 6

-- Find a marker Part anywhere in the Workspace by its (unique) name.
local function markerCFrame(name, fallback)
	local marker = workspace:FindFirstChild(name, true)
	if marker and marker:IsA("BasePart") then
		return marker.CFrame
	end
	warn("[RoundService] spawn marker '" .. name .. "' not found - using a fallback spot")
	return fallback
end

-- Dressed models we've wired into the round spawn SO FAR. Flip each to true once it's proven
-- end-to-end (we're starting with Momotaro). Anything false/missing spawns the normal avatar.
local DRESSED_ENABLED = {
	Momotaro   = true,
	GirlA      = true,
	Rokurokubi = true,
	Otohime    = true,   -- 2nd survivor; model lives in CharacterModels. Reachable once the survivor picker assigns her.
}

-- Spawn the player and drop them at `baseCFrame` (a few studs up so they don't clip into the
-- floor), nudged a little so multiple players don't stack.
--
-- If `characterKey` names a dressed model we've enabled, we spawn THAT model. The trick: drop a
-- tagged copy into StarterPlayer.StarterCharacter and call LoadCharacter, so Roblox still injects
-- the default (correct, R6) Animate + StarterCharacterScripts + camera/controls/ownership for us --
-- the things a manual `player.Character = clone` would NOT give. We remove the template right after
-- so lobby/default spawns stay normal. (See PLAN_dressed_model_spawn.md / the Step-0 homework.)
local function spawnPlayerAt(player, baseCFrame, characterKey)
	local models = ReplicatedStorage:FindFirstChild("CharacterModels")
	local source = characterKey and DRESSED_ENABLED[characterKey] and models and models:FindFirstChild(characterKey)

	if source then
		local template = source:Clone()
		template.Name = "StarterCharacter"
		template:SetAttribute("Dressed", true)   -- Bootstrap skips the placeholder recolor when set
		local existing = StarterPlayer:FindFirstChild("StarterCharacter")
		if existing then existing:Destroy() end
		template.Parent = StarterPlayer

		-- pcall so a bad model can NEVER kill the round loop, and ALWAYS remove the template
		-- afterward (even on error) so lobby/normal spawns don't inherit a stray StarterCharacter.
		local ok, err = pcall(function() player:LoadCharacter() end)

		-- IMPORTANT: let Roblox finish injecting the default Animate + StarterCharacterScripts BEFORE
		-- we remove the template. Destroying it immediately races that injection, and the dressed
		-- character can spawn with no Animate (frozen arms/legs). Wait for Animate to appear (or 3s).
		local spawned = player.Character
		if spawned then spawned:WaitForChild("Animate", 3) end

		local used = StarterPlayer:FindFirstChild("StarterCharacter")
		if used then used:Destroy() end
		if not ok then
			warn(("[RoundService] dressed spawn for %s failed (%s) -- using normal avatar"):format(
				tostring(characterKey), tostring(err)))
			player:LoadCharacter()
		end
	else
		player:LoadCharacter()
	end

	local character = player.Character or player.CharacterAdded:Wait()
	-- Don't wait forever: a malformed model could hang the whole round loop here.
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		warn(("[RoundService] %s spawned with no HumanoidRootPart (model issue) -- skipping placement"):format(player.Name))
		return
	end
	local ox = (rng:NextNumber() - 0.5) * 2 * SPAWN_SCATTER
	local oz = (rng:NextNumber() - 0.5) * 2 * SPAWN_SCATTER
	character:PivotTo(baseCFrame * CFrame.new(ox, 3, oz))
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

-- Build the list of characters a player may choose from for their team. Only the ones they own show
-- up; if somehow none do, we fall back to the team's free starter so the round still starts.
local function yokaiOptionsFor(player)
	local opts = {}
	if ownsCharacter(player, Types.Character.Rokurokubi) then table.insert(opts, Types.Character.Rokurokubi) end
	if ownsCharacter(player, Types.Character.GirlA) then table.insert(opts, Types.Character.GirlA) end
	if #opts == 0 then table.insert(opts, Types.Character.Rokurokubi) end
	return opts
end

local function survivorOptionsFor(player)
	local opts = {}
	if ownsCharacter(player, Types.Character.Momotaro) then table.insert(opts, Types.Character.Momotaro) end
	if ownsCharacter(player, Types.Character.Otohime) then table.insert(opts, Types.Character.Otohime) end
	if #opts == 0 then table.insert(opts, Types.Character.Momotaro) end
	return opts
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

-- Called by Bootstrap when a player joins. Drop them into the lobby with a body
-- so they can walk around while waiting. A player who joins mid-round also waits
-- in the lobby (no spectating) and gets pulled into the next round automatically.
function RoundService:OnPlayerJoined(player)
	if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
		return  -- already has a body (e.g. a state transition just spawned them)
	end
	spawnPlayerAt(player, markerCFrame("LobbySpawn", CFrame.new(0, 10, 0)))
end

------------------------------------------------------------------------------
-- State transitions
------------------------------------------------------------------------------

function RoundService:_enterLobby()
	state = Types.RoundState.Lobby
	playerCharacter = {}
	playerTeam = {}

	-- Back in the lobby — stop the chase music and start the calm lobby music.
	roundMusic:Stop()
	if not lobbyMusic.IsPlaying then
		lobbyMusic:Play()
	end

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

	-- Respawn everyone back in the lobby to hang out while waiting.
	local lobbyCFrame = markerCFrame("LobbySpawn", CFrame.new(0, 10, 0))
	for _, player in ipairs(Players:GetPlayers()) do
		spawnPlayerAt(player, lobbyCFrame)
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

	-- Hunt's on — cut the lobby music and start the chase music.
	lobbyMusic:Stop()
	roundMusic:Play()

	local players = Players:GetPlayers()
	if #players < Constants.Round.MinPlayers then
		-- Lost a player while counting down — go back to lobby.
		self:_enterLobby()
		return
	end

	-- Pick one random Yokai player; everyone else is a Warden (survivor).
	local yokaiPlayer = players[rng:NextInteger(1, #players)]

	-- Let every player choose their character. We run the picks CONCURRENTLY (each in its own thread)
	-- so the Yokai and all the survivors choose at the same time instead of waiting in line. Each pick
	-- is capped at ~10s inside _askPlayerToPick; we then wait for everyone (with a safety ceiling) so
	-- nobody spawns before their choice is in.
	local pending = #players
	for _, player in ipairs(players) do
		task.spawn(function()
			local team = (player == yokaiPlayer) and Types.Team.Yokai or Types.Team.Warden
			local options = (team == Types.Team.Yokai) and yokaiOptionsFor(player) or survivorOptionsFor(player)
			playerTeam[player.UserId] = team
			if #options == 1 then
				playerCharacter[player.UserId] = options[1]   -- only one choice: skip the screen
			else
				playerCharacter[player.UserId] = self:_askPlayerToPick(player, options, team)
			end
			pending -= 1
		end)
	end

	-- Wait for all picks to land. The ceiling is a touch above the 10s pick timeout so a slow/stuck
	-- client can't hang the round forever.
	local waitStart = tick()
	while pending > 0 and (tick() - waitStart) < 15 do
		task.wait(0.1)
	end

	print(string.format("[RoundService] Yokai = %s -> %s", yokaiPlayer.Name,
		tostring(playerCharacter[yokaiPlayer.UserId])))

	-- Assign teams + characters and respawn (fresh HP) at the team's spot in Map 1.
	-- The killer (Yokai) starts in the red area, survivors (Wardens) in the blue area.
	local wardenCFrame = markerCFrame("WardenSpawn", CFrame.new(0, 50, 0))
	local yokaiCFrame = markerCFrame("YokaiSpawn", CFrame.new(40, 50, 0))
	for _, player in ipairs(players) do
		-- Safety net: if a pick thread didn't finish (e.g. the player left), fall back sensibly.
		if not playerCharacter[player.UserId] then
			playerTeam[player.UserId] = (player == yokaiPlayer) and Types.Team.Yokai or Types.Team.Warden
			playerCharacter[player.UserId] = (player == yokaiPlayer)
				and Types.Character.Rokurokubi or Types.Character.Momotaro
		end
		player:SetAttribute("Team", playerTeam[player.UserId])
		player:SetAttribute("Character", playerCharacter[player.UserId])
		abilityService:SetCharacter(player, playerCharacter[player.UserId])
		local spawnAt = (playerTeam[player.UserId] == Types.Team.Yokai) and yokaiCFrame or wardenCFrame
		spawnPlayerAt(player, spawnAt, playerCharacter[player.UserId])
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
function RoundService:_askPlayerToPick(player, options, role)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local picker = remotes and remotes:FindFirstChild("CharacterPicker")
	if not picker then
		return options[rng:NextInteger(1, #options)]
	end

	-- Tell the client to open the picker with these options. `role` ("Yokai"/"Warden") themes the
	-- screen red for killers or light-blue for survivors.
	picker:FireClient(player, options, role)

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
