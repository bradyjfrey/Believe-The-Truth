-- Incognito.client.lua
-- Girl A's Incognito Mode makes her invisible to all other players. We can't
-- do "invisible to others" on the server alone (Transparency replicates to
-- everyone), so this client script watches every player's Incognito
-- attribute and locally renders them invisible or semi-transparent.
--
-- Brady's call: invisible to ALL other players (including other Yokai). The
-- Incognito player sees themselves semi-transparent so they know it's working.
--
-- WHY THIS RE-APPLIES EVERY FRAME (playtest bug 2026-07-19): applying the
-- transparency once wasn't enough — costume parts that finish loading late,
-- map streaming, and Roblox's own camera scripts can all reset a part back
-- to visible, so she "glitched" in and out on the Warden's screen. While a
-- player is incognito we now re-paint their whole character every frame.
-- It's a handful of parts for one or two players — cheap.
--
-- ALSO HIDDEN NOW (same playtest): ParticleEmitters (her costume FIRE kept
-- burning in plain sight — transparency does nothing to particles), plus
-- trails, beams, lights, and the face decal (an invisible body with a
-- floating face is not stealth).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

-- Everyone currently incognito, and how see-through THIS client should draw
-- them (1 = fully invisible, 0.7 = the ghost-faint self view).
local hiddenPlayers = {}   -- [player] = transparency

------------------------------------------------------------------------------
-- Paint one player's whole character to a given transparency.
-- LocalTransparencyModifier is per-client only; nothing here replicates.
------------------------------------------------------------------------------

-- Things that glow/spew on their own and ignore transparency. We switch them
-- off locally and remember (via an attribute on the instance) that WE did it,
-- so we only turn back on what we turned off.
local function isEffectInstance(d)
	return d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
		or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles")
		or d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight")
end

local function applyTransparency(player, transparency)
	local character = player.Character
	if not character then return end

	local hideEffects = transparency >= 1   -- self view (0.7) keeps her own fire as feedback

	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = transparency
		elseif d:IsA("Decal") then
			-- The face is a Decal — without this an invisible body still has a floating face.
			d.LocalTransparencyModifier = transparency
		elseif isEffectInstance(d) then
			if hideEffects then
				if d.Enabled then
					d:SetAttribute("HiddenByIncognito", true)
					d.Enabled = false
				end
			elseif d:GetAttribute("HiddenByIncognito") then
				d:SetAttribute("HiddenByIncognito", nil)
				d.Enabled = true
			end
		end
	end

	-- Hide the floating name + health bar when fully invisible.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.NameDisplayDistance = transparency >= 1 and 0 or 100
		humanoid.HealthDisplayDistance = transparency >= 1 and 0 or 100
	end
end

local function updatePlayer(player)
	if player:GetAttribute("Incognito") then
		-- Self-view: semi-transparent so you can still see what you're doing.
		-- Everyone else's view: fully invisible.
		hiddenPlayers[player] = (player == localPlayer) and 0.7 or 1
		applyTransparency(player, hiddenPlayers[player])
	elseif hiddenPlayers[player] then
		hiddenPlayers[player] = nil
		applyTransparency(player, 0)
	end
end

local function watchPlayer(player)
	player:GetAttributeChangedSignal("Incognito"):Connect(function()
		updatePlayer(player)
	end)
	player.CharacterAdded:Connect(function()
		-- Wait a moment for parts to load, then re-apply.
		task.wait(0.1)
		updatePlayer(player)
	end)
	if player.Character then updatePlayer(player) end
end

for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(player)
	hiddenPlayers[player] = nil
end)

-- The every-frame re-paint: keeps hidden players hidden no matter what loads
-- in or resets underneath us. Does nothing at all while nobody is incognito.
RunService.Heartbeat:Connect(function()
	for player, transparency in pairs(hiddenPlayers) do
		applyTransparency(player, transparency)
	end
end)
