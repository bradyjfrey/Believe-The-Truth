-- CompanionFollower.client.lua
-- Smoothly flies/walks Momotaro's companions (the Hawk now; his dogs later) beside their owner.
--
-- WHY THIS IS ON THE CLIENT: a companion that rides beside a player must be repositioned every
-- single frame. Doing that on the SERVER means moving an anchored part ~60x/sec and replicating it,
-- which stutters for everyone watching. Doing it here, on each player's RENDER loop, is buttery
-- smooth -- and reading the live animation pose here keeps the flap-cancel from wobbling.
--
-- HOW IT FINDS COMPANIONS: the server tags each companion model "FollowingCompanion" and drops a
-- "FollowTarget" ObjectValue inside it pointing at the character to ride beside. We drive every
-- tagged model we can see (each client moves its own local copy -- the change isn't replicated).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "FollowingCompanion"

-- WHERE each companion sits + how it behaves, keyed by the model's name. >>> TUNE HERE <<<
--   right / up / forward: studs from the owner (his right, above him, in front). ABSOLUTE studs --
--     our characters are ~2.4x size, so these are bigger than a normal rig would need.
--   pinBone: the bone we hold still each frame to cancel the asset's baked flight-path travel, so
--     the wings flap but the body doesn't fly off in a circle. Try "Root" if "Body" still drifts.
--   facingYaw: degrees to spin the model if it faces the wrong way (try 180 / 90 / -90).
--   bobHeight / bobSpeed: gentle idle float so it feels alive. followSmooth: 0..1, smaller = floatier.
local CONFIG = {
	Hawk = { right = 6, up = 10, forward = 0, pinBone = "Body", facingYaw = 0,
	         bobHeight = 0.4, bobSpeed = 1.5, followSmooth = 0.18 },
}
local DEFAULT = { right = 4, up = 6, forward = 0, pinBone = "Root", facingYaw = 0,
                  bobHeight = 0.3, bobSpeed = 1.5, followSmooth = 0.18 }

-- Live state per companion model we're driving.
local tracked = {}

local function startTracking(model)
	if tracked[model] then return end
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not primary then return end
	local cfg = CONFIG[model.Name] or DEFAULT
	tracked[model] = {
		primary = primary,
		pinBone = primary:FindFirstChild(cfg.pinBone, true),
		cfg = cfg,
		current = nil,   -- eased CFrame, so it glides instead of snapping
		clock = 0,
	}
end

local function stopTracking(model)
	tracked[model] = nil
end

for _, m in ipairs(CollectionService:GetTagged(TAG)) do startTracking(m) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(startTracking)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(stopTracking)

-- Where is the owner this frame? Use the HumanoidRootPart for a clean position + facing.
local function ownerCFrame(model)
	local ft = model:FindFirstChild("FollowTarget")
	local t = ft and ft.Value
	if not t then return nil end
	if t:IsA("Model") then
		local hrp = t:FindFirstChild("HumanoidRootPart")
		if hrp then return hrp.CFrame end
		if t.PrimaryPart then return t:GetPivot() end
		return nil
	elseif t:IsA("BasePart") then
		return t.CFrame
	end
	return nil
end

RunService.RenderStepped:Connect(function(dt)
	for model, s in pairs(tracked) do
		-- Drop anything that's been removed (round ended, owner despawned, etc.).
		if not model.Parent or not s.primary or not s.primary.Parent then
			tracked[model] = nil
		else
			local base = ownerCFrame(model)
			if base then
				s.clock += dt
				local cfg = s.cfg
				local bob = math.sin(s.clock * cfg.bobSpeed * math.pi * 2) * cfg.bobHeight
				-- His local axes: +X = his right, +Y = up, -Z = the way he faces.
				local goalPos = base:PointToWorldSpace(Vector3.new(cfg.right, cfg.up + bob, -cfg.forward))
				local goal = CFrame.new(goalPos) * (base - base.Position) * CFrame.Angles(0, math.rad(cfg.facingYaw), 0)
				-- Ease toward the goal so it glides instead of snapping.
				s.current = s.current and s.current:Lerp(goal, cfg.followSmooth) or goal
				-- Pin the chosen bone onto our goal: cancels the baked flight-circle but keeps the
				-- wing flapping. Reading the bone here (render loop, in sync with the part) avoids wobble.
				if s.pinBone then
					local meshToBone = s.primary.CFrame:ToObjectSpace(s.pinBone.TransformedWorldCFrame)
					s.primary.CFrame = s.current * meshToBone:Inverse()
				else
					s.primary.CFrame = s.current
				end
			end
		end
	end
end)
