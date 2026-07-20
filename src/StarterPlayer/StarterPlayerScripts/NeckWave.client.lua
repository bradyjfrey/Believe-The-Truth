-- NeckWave.client.lua
-- Makes EVERY Rokurokubi's segmented neck wave, on EVERY player's screen.
--
-- WHY THIS LIVES HERE NOW (playtest 2026-07-19): the old version was a
-- LocalScript in StarterCharacterScripts, which only runs on the Rokurokubi
-- player's own machine -- and joint changes made by one client never replicate
-- to anyone else. So Roro saw her neck wave while the Wardens saw a stiff
-- pole. Now every client runs this ONE script and animates every waving neck
-- it can see. (Delete the old NeckWave from StarterCharacterScripts -- running
-- both would double the wave on Roro's own screen.)
--
-- Animates each joint's C0 (not Transform) -- the animation system wipes
-- Transform every frame, but C0 holds. Only characters that actually have
-- NeckJoint1..N motors get animated; everyone else is skipped automatically.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- TUNABLES (same feel as the original)
local WAVE_AXIS = "Z"
local AMPLITUDE = 6      -- degrees each joint swings
local SPEED     = 2.5    -- how fast the wave travels
local PHASE     = 0.5    -- lag between joints (makes it a wave, not a metronome)

-- Every character we're currently waving: waving[character] = {joints, base}
local waving = {}

-- Collect the NeckJoint1..N motors, in order. Returns {} if none are present.
local function findJoints(character)
	local byNum = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name:match("^NeckJoint%d+$") then
			byNum[tonumber(d.Name:match("%d+"))] = d
		end
	end
	local list = {}
	local i = 1
	while byNum[i] do table.insert(list, byNum[i]); i = i + 1 end
	return list
end

-- Watch one character: wait up to ~5s for its neck joints to replicate in
-- (spawn timing race -- same wait the old script needed), then start waving.
local function watchCharacter(character)
	task.spawn(function()
		local joints = findJoints(character)
		local waited = 0
		while #joints == 0 and waited < 5 do
			task.wait(0.2)
			if not character.Parent then return end
			waited += 0.2
			joints = findJoints(character)
		end
		if #joints == 0 then return end   -- not a segmented Rokurokubi -- nothing to do

		-- Remember each joint's rest C0 so we rotate relative to it.
		local base = {}
		for j, m in ipairs(joints) do base[j] = m.C0 end
		waving[character] = {joints = joints, base = base}
	end)
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(watchCharacter)
	player.CharacterRemoving:Connect(function(character)
		waving[character] = nil
	end)
	if player.Character then watchCharacter(player.Character) end
end

for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)

local function rot(deg)
	if WAVE_AXIS == "X" then return CFrame.Angles(math.rad(deg), 0, 0)
	elseif WAVE_AXIS == "Y" then return CFrame.Angles(0, math.rad(deg), 0)
	else return CFrame.Angles(0, 0, math.rad(deg)) end
end

local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock = clock + dt
	for character, info in pairs(waving) do
		if not character.Parent then
			waving[character] = nil   -- character despawned (or disguise-swapped away)
		else
			for j, m in ipairs(info.joints) do
				m.C0 = info.base[j] * rot(AMPLITUDE * math.sin(clock * SPEED - j * PHASE))
			end
		end
	end
end)
