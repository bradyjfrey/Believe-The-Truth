-- ROKUROKUBI NECK WAVE -- preview version that runs during PLAY.
-- WHERE IT GOES: a Script (NOT LocalScript) placed INSIDE the ModelingRorokubi model in Workspace.
-- Then press Play and look at ModelingRorokubi -- its neck should whip in a traveling wave.
-- (Edit mode can't animate joints; that's why the Command Bar preview did nothing.)
--
-- Tune the values, then just re-Play.

local RunService = game:GetService("RunService")

-- TUNABLES
local WAVE_AXIS = "Z"   -- bend direction: "X" / "Y" / "Z" (find side-to-side)
local AMPLITUDE = 6     -- degrees EACH joint bends (they add up -- keep small)
local SPEED     = 2.5   -- how fast the wave travels up the neck
local PHASE     = 0.5   -- phase shift per joint = snakiness (bigger = more S-curves)

local model = script.Parent

local byNum = {}
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") and d.Name:match("^NeckJoint%d+$") then
		byNum[tonumber(d.Name:match("%d+"))] = d
	end
end
local joints = {}
local i = 1
while byNum[i] do table.insert(joints, byNum[i]); i = i + 1 end
if #joints == 0 then warn("[NeckWave] no NeckJoint motors found -- run build-neck-chain first.") return end

local function rot(deg)
	if WAVE_AXIS == "X" then return CFrame.Angles(math.rad(deg), 0, 0)
	elseif WAVE_AXIS == "Y" then return CFrame.Angles(0, math.rad(deg), 0)
	else return CFrame.Angles(0, 0, math.rad(deg)) end
end

local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock = clock + dt
	for j, m in ipairs(joints) do
		m.Transform = rot(AMPLITUDE * math.sin(clock * SPEED - j * PHASE))
	end
end)
