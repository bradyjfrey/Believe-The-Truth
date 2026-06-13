-- ROKUROKUBI NECK WAVE.
-- WHERE IT GOES: a LocalScript in StarterPlayer > StarterCharacterScripts.
-- Drives the segmented neck (NeckJoint1..N) in a traveling wave.
--
-- Animates each joint's C0 (not Transform) -- on a player's own character the animation system
-- wipes Transform each frame, but C0 holds. (Same reason the single-joint sway used C0.)
--
-- IMPORTANT: when the character spawns through the round flow, the NeckJoint Motor6Ds may not have
-- replicated to the client yet at the instant this script first runs. So we WAIT for them (poll a
-- few seconds) instead of scanning once and giving up -- that one-time scan is why the neck stayed
-- stiff in a round but worked in the standalone test (a timing race).

local RunService = game:GetService("RunService")

-- TUNABLES
local WAVE_AXIS = "Z"
local AMPLITUDE = 6
local SPEED     = 2.5
local PHASE     = 0.5

local char = script.Parent

-- Collect the NeckJoint1..N motors, in order. Returns {} if none are present yet.
local function findJoints()
	local byNum = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name:match("^NeckJoint%d+$") then
			byNum[tonumber(d.Name:match("%d+"))] = d
		end
	end
	local list = {}
	local i = 1
	while byNum[i] do table.insert(list, byNum[i]); i = i + 1 end
	return list
end

-- Wait up to ~5s for the joints to appear (handles spawn/replication timing).
local joints = findJoints()
local waited = 0
while #joints == 0 and waited < 5 do
	task.wait(0.2)
	waited += 0.2
	joints = findJoints()
end

if #joints == 0 then return end   -- not the segmented Rokurokubi (or joints never arrived) -- do nothing

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
