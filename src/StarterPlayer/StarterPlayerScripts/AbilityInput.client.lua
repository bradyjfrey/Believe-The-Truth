-- AbilityInput.client.lua
-- Binds keys (and mobile touch buttons) to ability requests. When the local
-- player's character changes (set by RoundService via the "Character"
-- attribute), this script re-binds to whatever that character's keys are.
--
-- ContextActionService handles the cross-platform stuff for us — on mobile,
-- when we pass `true` as the "create touch button" flag, Roblox auto-creates
-- an on-screen button labeled with our action name.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local localPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AbilityRequest = Remotes:WaitForChild("AbilityRequest")
local NeckWrapMash = Remotes:WaitForChild("NeckWrapMash")

------------------------------------------------------------------------------
-- The key list lives in the SHARED AbilityBindings module now, so the HUD's
-- ability icons and these key binds always agree. Rows marked HudOnly belong
-- to another script (e.g. DisguisePickerUI owns Rokurokubi's R) — we show
-- them on the HUD but skip binding them here.
------------------------------------------------------------------------------

local BINDINGS = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AbilityBindings"))

local currentActions = {}

local function clearBindings()
	for _, action in ipairs(currentActions) do
		ContextActionService:UnbindAction(action)
	end
	currentActions = {}
end

local function applyBindings(characterName)
	clearBindings()
	local list = BINDINGS[characterName]
	if not list then return end

	for _, binding in ipairs(list) do
		if binding.HudOnly then continue end   -- another script owns this key
		local action = characterName .. "_" .. binding.Ability
		local ability = binding.Ability
		local isHold = binding.Hold

		ContextActionService:BindAction(action, function(_, inputState)
			if isHold then
				if inputState == Enum.UserInputState.Begin then
					AbilityRequest:FireServer(ability, {Phase = "Begin"})
				elseif inputState == Enum.UserInputState.End then
					AbilityRequest:FireServer(ability, {Phase = "End"})
				end
			else
				if inputState == Enum.UserInputState.Begin then
					AbilityRequest:FireServer(ability, {})
				end
			end
		end, true, binding.Key)

		-- Friendly label on the on-screen touch button (mobile).
		ContextActionService:SetTitle(action, binding.Label)

		table.insert(currentActions, action)
	end
end

-- React to the server setting the local player's character.
localPlayer:GetAttributeChangedSignal("Character"):Connect(function()
	applyBindings(localPlayer:GetAttribute("Character"))
end)
if localPlayer:GetAttribute("Character") then
	applyBindings(localPlayer:GetAttribute("Character"))
end

------------------------------------------------------------------------------
-- Neck Wrap escape: when this player gets the Wrapped attribute set true,
-- bind Space (PC) and create a touch button (mobile) for mashing.
------------------------------------------------------------------------------

local MASH_ACTION = "EscapeNeckWrap"

local function bindMash()
	ContextActionService:BindActionAtPriority(MASH_ACTION, function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then return end
		NeckWrapMash:FireServer()
		return Enum.ContextActionResult.Sink
	end, true, 1000, Enum.KeyCode.Space)
	ContextActionService:SetTitle(MASH_ACTION, "MASH!")
end

local function unbindMash()
	ContextActionService:UnbindAction(MASH_ACTION)
end

localPlayer:GetAttributeChangedSignal("Wrapped"):Connect(function()
	if localPlayer:GetAttribute("Wrapped") then bindMash() else unbindMash() end
end)
if localPlayer:GetAttribute("Wrapped") then bindMash() end
