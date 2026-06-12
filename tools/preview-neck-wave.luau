-- PREVIEW ROKUROKUBI'S NECK WAVE (live, in edit mode). Run/re-run anytime to tune.
-- Run "build-neck-chain" FIRST. Then paste this into the Command Bar and Run (no selection needed).
-- It animates a traveling sine wave up the neck joints so the neck whips like a cartoon snake.
--
-- TO STOP THE WAVE: paste this one line into the Command Bar and Run:
--   if _G.NeckWaveConn then _G.NeckWaveConn:Disconnect() _G.NeckWaveConn = nil end

local RunService = game:GetService("RunService")

------------------------------------------------------------------------------
-- TUNABLES
------------------------------------------------------------------------------
local WAVE_AXIS = "Z"   -- bend direction: "X" / "Y" / "Z". (Z matched the side-to-side single sway.)
local AMPLITUDE = 6     -- degrees EACH joint bends -- they add up into a big curve, so keep it small
local SPEED     = 2.5   -- how fast the wave travels up the neck
local PHASE     = 0.5   -- phase shift per joint = how "snaky" it is. Bigger = more S-curves at once.

------------------------------------------------------------------------------
-- Collect the NeckJoint motors in order.
------------------------------------------------------------------------------
local byNum = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Motor6D") and d.Name:match("^NeckJoint%d+$") then
		byNum[tonumber(d.Name:match("%d+"))] = d
	end
end
local joints = {}
local i = 1
while byNum[i] do table.insert(joints, byNum[i]); i = i + 1 end
if #joints == 0 then warn("No NeckJoint motors found -- run build-neck-chain first.") return end

local function rot(deg)
	if WAVE_AXIS == "X" then return CFrame.Angles(math.rad(deg), 0, 0)
	elseif WAVE_AXIS == "Y" then return CFrame.Angles(0, math.rad(deg), 0)
	else return CFrame.Angles(0, 0, math.rad(deg)) end
end

-- Disconnect a previous preview so re-running doesn't stack waves.
if _G.NeckWaveConn then _G.NeckWaveConn:Disconnect() end
local clock = 0
_G.NeckWaveConn = RunService.Heartbeat:Connect(function(dt)
	clock = clock + dt
	for j, m in ipairs(joints) do
		local deg = AMPLITUDE * math.sin(clock * SPEED - j * PHASE)
		m.Transform = rot(deg)
	end
end)

print("Neck wave running on " .. #joints .. " joints (axis " .. WAVE_AXIS .. "). Re-run to update tunables.")
print("To stop: if _G.NeckWaveConn then _G.NeckWaveConn:Disconnect() _G.NeckWaveConn = nil end")
