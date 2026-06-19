-- JumpControl.client.lua
-- A FALLBACK jump for characters whose Humanoid refuses to jump on its own.
--
-- Some of our hand-built dressed rigs (Momotaro) will not enter the Jumping state even though they're
-- grounded, have JumpPower set, and CAN be moved upward by raw velocity -- the engine just refuses the
-- native jump on that rig. Rather than keep fighting it, we let the native jump try first, and if it
-- DIDN'T happen (still grounded a moment later), we apply the upward velocity ourselves.
--
-- Characters whose native jump works (Girl A, Otohime) are already airborne before our check, so we
-- skip them -- no double jumps. Rokurokubi has a jump velocity of 0 (she floats), so she's skipped too.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local lp = Players.LocalPlayer

-- Same per-character logic Bootstrap uses: a PerCharacter override wins, else the default; 0 = no jump.
local function jumpVelocityFor(characterName)
	local per = Constants.Jump.PerCharacter
	if per and per[characterName] ~= nil then return per[characterName] end
	return Constants.Jump.Power
end

local lastJump = 0

UserInputService.JumpRequest:Connect(function()
	local char = lp.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end

	local velocity = jumpVelocityFor(lp:GetAttribute("Character"))
	if velocity <= 0 then return end                                -- this character doesn't jump (Rokurokubi)
	if humanoid.FloorMaterial == Enum.Material.Air then return end   -- not grounded, can't jump
	if tick() - lastJump < 0.2 then return end                       -- debounce repeated JumpRequests
	lastJump = tick()

	-- Give the native jump a moment. If it worked we're airborne now (leave it alone); if it didn't
	-- (the broken rigs) we're still grounded -> force the jump with the velocity we proved works.
	task.wait(0.06)
	local state = humanoid:GetState()
	if humanoid.FloorMaterial ~= Enum.Material.Air
		and state ~= Enum.HumanoidStateType.Jumping
		and state ~= Enum.HumanoidStateType.Freefall then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, velocity, v.Z)   -- keep horizontal momentum
	end
end)
