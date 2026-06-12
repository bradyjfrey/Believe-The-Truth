-- ROKUROKUBI NECK WAVE.
-- WHERE IT GOES: a LocalScript in StarterPlayer > StarterCharacterScripts.
-- Drives the segmented neck (NeckJoint1..N) in a traveling wave.
--
-- Animates each joint's C0 (not Transform) -- on a player's own character the animation system
-- wipes Transform each frame, but C0 holds. (Same reason the single-joint sway used C0.)
--
-- Set these 4 values to whatever you tuned in the Workspace preview.

local RunService = game:GetService("RunService")

-- TUNABLES
local WAVE_AXIS = "Z"
local AMPLITUDE = 6
local SPEED     = 2.5
local PHASE     = 0.5

local char = script.Parent

local byNum = {}
for _, d in ipairs(char:GetDescendants()) do
	if d:IsA("Motor6D") and d.Name:match("^NeckJoint%d+$") then
		byNum[tonumber(d.Name:match("%d+"))] = d
	end
end
local joints = {}
local i = 1
while byNum[i] do table.insert(joints, byNum[i]); i = i + 1 end
if #joints == 0 then return end   -- not the segmented Rokurokubi -- do nothing

-- Remember each joint's rest C0 so we rotate relative to it.
local base = {}
for j, m in ipairs(joints) do base[j] = m.C0 end

local function rot(deg)
	if WAVE_AXIS == "X" then return CFrame.Angles(math.rad(deg), 0, 0)
	elseif WAVE_AXIS == "Y" then return CFrame.Angles(0, math.rad(deg), 0)
	else return CFrame.Angles(0, 0, math.rad(deg)) end
end

local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock = clock + dt
	for j, m in ipairs(joints) do
		m.C0 = base[j] * rot(AMPLITUDE * math.sin(clock * SPEED - j * PHASE))
	end
end)
