-- SoundPlayer.client.lua
-- Plays one-shot sound effects LOCALLY on this player's machine when the server asks.
--
-- WHY THIS IS A CLIENT SCRIPT: sounds created on the SERVER are unreliable to hear -- the server
-- can create, play, and clean up a short sound before every client has finished loading the audio,
-- so players often hear nothing (this is exactly why the dog bark was silent). Instead the server
-- fires the "PlaySound" remote to ALL clients, and each client makes + plays its OWN copy of the
-- sound right here, which plays reliably.
--
-- The server sends: (part, soundId, volume)
--   part    - the BasePart to play the sound FROM, so it's 3D (louder the closer you are). If it's
--             missing, we just play the sound flat (2D) so it's still heard.
--   soundId - e.g. "rbxassetid://123456"
--   volume  - 0..1

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local PlaySound = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlaySound")

PlaySound.OnClientEvent:Connect(function(part, soundId, volume)
	if not soundId or soundId == "" then return end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5

	if part and part:IsDescendantOf(workspace) then
		-- 3D: play it FROM the part so it comes from that spot in the world.
		sound.Parent = part
		sound:Play()
		Debris:AddItem(sound, 5)   -- clean up after it finishes (safe upper bound)
	else
		-- No part to play from -- just play it flat so it's still heard.
		SoundService:PlayLocalSound(sound)
	end
end)
