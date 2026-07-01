-- HighlightReveal.client.lua
-- Draws a glowing outline around a character, but ONLY on this player's screen.
--
-- Why this exists: some abilities are supposed to reveal an enemy to just ONE
-- player (Momotaro's Bird's Eye View shows the Yokai only to Momotaro; Girl A's
-- Breach of Privacy shows a Warden only to Girl A). If the server made the glow,
-- everybody would see it -- the enemy would know they'd been spotted, and other
-- teammates would get the reveal for free.
--
-- The fix: the server sends a private "ShowHighlight" message to the ONE player
-- who should see it, and this script builds the glow here on the client. A
-- Highlight created on the client is only ever visible on this screen.
--
-- The server sends: (targetCharacter, info) where info is a table:
--   info.Fill     - Color3 for the glowing fill (optional, defaults to red)
--   info.Outline  - Color3 for the outline (optional, defaults to light red)
--   info.Seconds  - how long the glow stays before it fades away

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShowHighlight = Remotes:WaitForChild("ShowHighlight")

local DEFAULT_FILL = Color3.fromRGB(255, 0, 0)
local DEFAULT_OUTLINE = Color3.fromRGB(255, 150, 150)
local DEFAULT_SECONDS = 6

ShowHighlight.OnClientEvent:Connect(function(targetCharacter, info)
	-- The character might have despawned between the server sending this and us
	-- receiving it -- if so, there's nothing to glow.
	if not targetCharacter or not targetCharacter:IsDescendantOf(workspace) then
		return
	end

	info = info or {}

	local highlight = Instance.new("Highlight")
	highlight.FillColor = info.Fill or DEFAULT_FILL
	highlight.OutlineColor = info.Outline or DEFAULT_OUTLINE
	highlight.Adornee = targetCharacter
	highlight.Parent = targetCharacter

	-- Take the glow away after its time is up.
	task.delay(info.Seconds or DEFAULT_SECONDS, function()
		if highlight then
			highlight:Destroy()
		end
	end)
end)
