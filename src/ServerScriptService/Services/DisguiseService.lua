-- DisguiseService.lua
-- Handles Rokurokubi's Disguise ability. When she disguises, we swap her whole
-- character for a clone of the target Warden's dressed model (the same
-- StarterCharacter trick RoundService uses for round spawns), keeping her
-- health and position, and wear the target's display name. When the disguise
-- drops, we swap her back to her own Rokurokubi model the same way.
--
-- WHY NOT HumanoidDescription? The old version used ApplyDescription, which
-- only works on standard Roblox rigs. Our dressed models are hand-built, so
-- the call errored and she never visibly changed (playtest 2026-07-19). The
-- model swap also copies what the target ACTUALLY looks like in-game (their
-- dressed model), not their roblox.com avatar.
--
-- The disguise can drop because:
--   * The 19-second timer ran out (Rokurokubi.lua)
--   * She used Bite (Rokurokubi.lua calls Drop)
--   * She used Strangle (Rokurokubi.lua calls Drop)
--   * She took any damage (we watch HealthChanged in Apply)
--   * She manually canceled with R (Rokurokubi.lua)
--   * The round ended (RoundService calls DropAll)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local DisguiseService = {}

-- active[rokurokubiPlayer] = {target = the Warden she copied, healthConn = connection}
local active = {}

function DisguiseService:IsDisguised(player)
	return active[player] ~= nil
end

function DisguiseService:GetCopiedTarget(player)
	return active[player] and active[player].target or nil
end

------------------------------------------------------------------------------
-- The StarterCharacter swap trick (borrowed from RoundService.spawnPlayerAt):
-- drop the model into StarterPlayer.StarterCharacter, LoadCharacter, then
-- clean up. Roblox still injects the default Animate + StarterCharacterScripts
-- + camera/controls for us -- things a bare "player.Character = clone" would not.
------------------------------------------------------------------------------
local function swapToModel(player, sourceModel, atCFrame)
	local template = sourceModel:Clone()
	template.Name = "StarterCharacter"
	template:SetAttribute("Dressed", true)   -- Bootstrap skips the placeholder recolor
	local existing = StarterPlayer:FindFirstChild("StarterCharacter")
	if existing then existing:Destroy() end
	template.Parent = StarterPlayer

	local ok, err = pcall(function() player:LoadCharacter() end)

	-- Let Roblox finish injecting Animate before removing the template
	-- (destroying it immediately races the injection -- frozen arms/legs).
	local spawned = player.Character
	if spawned then spawned:WaitForChild("Animate", 3) end

	local used = StarterPlayer:FindFirstChild("StarterCharacter")
	if used then used:Destroy() end
	if not ok then
		warn("[DisguiseService] model swap failed: " .. tostring(err))
		return nil
	end
	if spawned and atCFrame then
		local root = spawned:WaitForChild("HumanoidRootPart", 5)
		if root then spawned:PivotTo(atCFrame) end
	end
	return spawned
end

-- Swap the player's model while keeping where they stand and how hurt they are.
-- Returns the new character + humanoid, or nil if the swap failed.
local function swapKeepingSelf(player, sourceModel)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local savedCFrame = character:GetPivot()
	local savedHealth = humanoid.Health

	local newCharacter = swapToModel(player, sourceModel, savedCFrame)
	if not newCharacter then return nil end

	-- Bootstrap re-applies her stats on the fresh body (CharacterAdded), which
	-- fills health to max. Give that a beat to finish, then put her REAL health
	-- back so disguising is never a free full heal.
	task.wait(0.2)
	local newHumanoid = newCharacter:FindFirstChildOfClass("Humanoid")
	if newHumanoid then
		newHumanoid.Health = math.min(savedHealth, newHumanoid.MaxHealth)
	end
	return newCharacter, newHumanoid
end

function DisguiseService:Apply(rokurokubiPlayer, targetWardenPlayer)
	if active[rokurokubiPlayer] then return false end

	-- Which dressed model to copy: the target's CHARACTER (Momotaro, Otohime...),
	-- pulled from the same CharacterModels folder the round spawn uses.
	local targetKey = targetWardenPlayer:GetAttribute("Character")
	local models = ReplicatedStorage:FindFirstChild("CharacterModels")
	local source = targetKey and models and models:FindFirstChild(targetKey)
	if not source then
		warn("[DisguiseService] no CharacterModels model for " .. tostring(targetKey))
		return false
	end

	local newCharacter, newHumanoid = swapKeepingSelf(rokurokubiPlayer, source)
	if not newCharacter or not newHumanoid then return false end

	-- Wear the target's name too.
	newHumanoid.DisplayName = targetWardenPlayer.DisplayName

	-- Taking ANY damage breaks the disguise (per spec). Hooked AFTER the health
	-- restore above so the restore itself doesn't count as damage.
	local startHealth = newHumanoid.Health
	local healthConn
	healthConn = newHumanoid.HealthChanged:Connect(function(newHealth)
		if newHealth < startHealth - 0.01 then
			DisguiseService:Drop(rokurokubiPlayer)
		end
	end)

	active[rokurokubiPlayer] = {target = targetWardenPlayer, healthConn = healthConn}
	rokurokubiPlayer:SetAttribute("Disguised", true)
	return true
end

function DisguiseService:Drop(rokurokubiPlayer)
	local state = active[rokurokubiPlayer]
	if not state then return end
	-- Clear the state FIRST so the health watcher can't re-enter Drop mid-swap.
	active[rokurokubiPlayer] = nil
	if state.healthConn then state.healthConn:Disconnect() end
	rokurokubiPlayer:SetAttribute("Disguised", nil)

	-- If she's dead, don't swap -- LoadCharacter would resurrect her. The round
	-- flow owns dead players.
	local character = rokurokubiPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local models = ReplicatedStorage:FindFirstChild("CharacterModels")
	local source = models and models:FindFirstChild("Rokurokubi")
	if not source then
		warn("[DisguiseService] CharacterModels.Rokurokubi missing -- cannot swap back")
		return
	end
	swapKeepingSelf(rokurokubiPlayer, source)
end

function DisguiseService:DropAll()
	for player in pairs(active) do
		self:Drop(player)
	end
end

return DisguiseService
