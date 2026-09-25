-- PreloadEffects.client.lua
-- Downloads every effect's meshes/textures/sounds right after you join, so the FIRST
-- time an ability fires its visual shows instantly.
--
-- WHY: templates in ReplicatedStorage.Effects replicate their INSTANCES to every player,
-- but the actual assets (mesh files, texture images, audio) only download the first time
-- they appear in the Workspace. Without this, the first Dark Moon / slash / growl of a
-- session can show up invisible or silent, and only work from the second use onward.
--
-- HOW TO EXTEND: nothing to do — it preloads whatever is inside ReplicatedStorage.Effects,
-- so new effect templates the art team drops in are covered automatically.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for the Effects folder (Bootstrap/setup may still be creating things right at join).
local effectsFolder = ReplicatedStorage:WaitForChild("Effects", 10)
if not effectsFolder then return end

-- Gather the folder itself plus everything inside it. ContentProvider digs the asset URLs
-- out of each instance (MeshParts, Decals, ParticleEmitters, Sounds, etc.) for us.
local toLoad = effectsFolder:GetDescendants()
table.insert(toLoad, effectsFolder)

-- PreloadAsync YIELDS until the downloads finish, so run it in its own thread — we never
-- want to hold up other scripts. If it takes a while on a slow connection that's fine;
-- the game is playable the whole time, effects just warm up as they arrive.
task.spawn(function()
	ContentProvider:PreloadAsync(toLoad)
	print("[PreloadEffects] all effect assets warmed up (" .. #toLoad .. " instances)")
end)

-- One-shot effects: emitters tagged with a "Burst" count are fired HERE, on each player's own
-- screen, as the effect arrives. Emit() called on the server is never shown to players.
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ParticleEmitter") then
		local burst = d:GetAttribute("Burst")
		if burst then
			task.defer(function()
				if d.Parent then d:Emit(burst) end
			end)
		end
	end
end)
