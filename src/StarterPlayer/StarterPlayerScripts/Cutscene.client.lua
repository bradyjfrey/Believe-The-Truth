-- Cutscene.client.lua
-- Plays a scripted cutscene on THIS player's screen: takes the camera, puts stand-in copies of the
-- characters on the CutsceneStage, moves them through the scene's beats, shows the name card, and
-- hands the camera back. Scenes live in Shared/Cutscenes.lua. The server asks for one via the
-- Cutscene remote ("Intro", characterName, stageCFrame). Nothing here touches the real
-- characters or the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local Cutscenes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cutscenes"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local CutsceneRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Cutscene")

local CS = Constants.Cutscene

-- Roblox's own default walk/idle animations, which play in any experience.
local ANIMATIONS = {
	R6  = {Walk = "rbxassetid://180426354", Idle = "rbxassetid://180435571"},
	R15 = {Walk = "rbxassetid://507777826", Idle = "rbxassetid://507766666"},
}

local THEME = {
	Warden = Color3.fromRGB(124, 192, 255),
	Yokai  = Color3.fromRGB(255, 59, 65),
}

-- Same feel as NeckWave.client.lua, so a stand-in Rokurokubi's neck moves like the real one.
local NECK_WAVE = {Amplitude = 6, Speed = 2.5, Phase = 0.5}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Cutscene"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 20
screenGui.Enabled = false
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1, 1)
fade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fade.BackgroundTransparency = 1
fade.BorderSizePixel = 0
fade.ZIndex = 10
fade.Parent = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.AnchorPoint = Vector2.new(0.5, 1)
titleLabel.Position = UDim2.new(0.5, 0, 0.86, 0)
titleLabel.Size = UDim2.new(0.8, 0, 0, 96)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GrenzeGotisch
titleLabel.TextScaled = true
titleLabel.TextColor3 = Color3.fromRGB(243, 233, 236)
titleLabel.TextTransparency = 1
titleLabel.ZIndex = 5
titleLabel.Parent = screenGui
local titleStroke = Instance.new("UIStroke")
titleStroke.Thickness = 2
titleStroke.Color = Color3.fromRGB(0, 0, 0)
titleStroke.Transparency = 1
titleStroke.Parent = titleLabel

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.AnchorPoint = Vector2.new(0.5, 0)
subtitleLabel.Position = UDim2.new(0.5, 0, 0.86, 4)
subtitleLabel.Size = UDim2.new(0.8, 0, 0, 28)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Font = Enum.Font.GothamBold
subtitleLabel.TextScaled = true
subtitleLabel.TextTransparency = 1
subtitleLabel.ZIndex = 5
subtitleLabel.Parent = screenGui
local subtitleStroke = Instance.new("UIStroke")
subtitleStroke.Thickness = 1.5
subtitleStroke.Color = Color3.fromRGB(0, 0, 0)
subtitleStroke.Transparency = 1
subtitleStroke.Parent = subtitleLabel

local function tweenTo(instance, props, seconds)
	TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function easeInOut(t)
	return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2
end

local function stageCFrame(fromServer)
	if fromServer then return fromServer end
	local stage = workspace:FindFirstChild("CutsceneStage", true)
	if stage and stage:IsA("BasePart") then
		return stage.CFrame * CFrame.new(0, stage.Size.Y / 2, 0)
	end
	local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local boxCF, boxSize = localPlayer.Character:GetBoundingBox()
		local floorY = boxCF.Position.Y - boxSize.Y / 2
		local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
		local feet = Vector3.new(root.Position.X, floorY, root.Position.Z)
		return CFrame.lookAt(feet, feet + flat)
	end
	return CFrame.new(0, 10, 0)
end

local function setControlsEnabled(enabled)
	pcall(function()
		local controls = require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
		if enabled then controls:Enable() else controls:Disable() end
	end)
end

local function findJoint(model, jointName)
	local torso = model:FindFirstChild("Torso")
	if torso and torso:FindFirstChild(jointName) then return torso[jointName] end
	local side, rest = jointName:match("^(%a+) (%a+)$")
	if side and rest == "Shoulder" then
		local upperArm = model:FindFirstChild(side .. "UpperArm")   -- R15
		if upperArm then return upperArm:FindFirstChild(side .. "Shoulder") end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == jointName then return d end
	end
	return nil
end

local function rotateOn(axis, radians)
	if axis == "X" then return CFrame.Angles(radians, 0, 0) end
	if axis == "Y" then return CFrame.Angles(0, radians, 0) end
	return CFrame.Angles(0, 0, radians)
end

local function neckJoints(model)
	local byNum = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name:match("^NeckJoint%d+$") then
			byNum[tonumber(d.Name:match("%d+"))] = d
		end
	end
	local list = {}
	local i = 1
	while byNum[i] do table.insert(list, byNum[i]); i += 1 end
	return list
end

-- Builds a stand-in: a copy of the character model, scripts stripped, root anchored so we can
-- place it by hand, everything else loose so the animations and poses can move the limbs.
local function buildActor(characterName, stage)
	local models = ReplicatedStorage:FindFirstChild("CharacterModels")
	local source = models and models:FindFirstChild(characterName)
	if not source then return nil end

	local model = source:Clone()
	model.Name = "CutsceneActor_" .. characterName
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then model:Destroy() return nil end
	root.Anchored = true
	model.PrimaryPart = root

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local tracks = {}
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		local ids = (humanoid.RigType == Enum.HumanoidRigType.R15) and ANIMATIONS.R15 or ANIMATIONS.R6
		for name, id in pairs(ids) do
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			tracks[name] = animator:LoadAnimation(anim)
			tracks[name].Looped = true
		end
	end

	model.Parent = workspace
	local boxCF, boxSize = model:GetBoundingBox()

	local neck = neckJoints(model)
	local neckBase = {}
	for i, joint in ipairs(neck) do neckBase[i] = joint.C0 end

	return {
		model = model,
		root = root,
		tracks = tracks,
		rootAboveFeet = root.Position.Y - (boxCF.Position.Y - boxSize.Y / 2),
		neck = neck,
		neckBase = neckBase,
		feet = Vector3.new(0, 0, 0),
		facing = Vector3.new(0, 0, -1),
		lift = 0,
		bob = 0,
		fallen = false,
		anim = nil,
		poseBase = {},
		posed = {},
	}
end

local playing = false

local function playScene(scene, characterName, stageFromServer)
	if playing or not scene then return end
	local stage = stageCFrame(stageFromServer)

	local actors = {}
	actors.Actor = buildActor(characterName, stage)
	if not actors.Actor then return end
	if scene.Victim then actors.Victim = buildActor(scene.Victim, stage) end
	playing = true

	local camera = workspace.CurrentCamera
	local team = Types.CharacterTeam and Types.CharacterTeam[characterName]
	subtitleLabel.TextColor3 = THEME[team] or THEME.Warden

	screenGui.Enabled = true
	setControlsEnabled(false)
	tweenTo(fade, {BackgroundTransparency = 0}, CS.FadeSeconds)
	task.wait(CS.FadeSeconds)

	camera.CameraType = Enum.CameraType.Scriptable
	local sceneStart = os.clock()

	local function place(state, feet, lookDir, shake)
		local flat = Vector3.new(lookDir.X, 0, lookDir.Z)
		if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
		local worldLook = stage:VectorToWorldSpace(flat.Unit)
		local jitter = Vector3.new(0, 0, 0)
		if shake and shake > 0 then
			jitter = Vector3.new((math.random() - 0.5) * 2 * shake, 0, (math.random() - 0.5) * 2 * shake)
		end
		local bobOffset = state.bob > 0 and math.sin((os.clock() - sceneStart) * 2.2) * state.bob or 0

		local rootPos, cf
		if state.fallen then
			rootPos = stage:PointToWorldSpace(feet + jitter) + Vector3.new(0, 2, 0)
			cf = CFrame.lookAt(rootPos, rootPos + worldLook) * CFrame.Angles(math.rad(-90), 0, 0)
		else
			rootPos = stage:PointToWorldSpace(feet + jitter) + Vector3.new(0, state.rootAboveFeet + state.lift + bobOffset, 0)
			cf = CFrame.lookAt(rootPos, rootPos + worldLook)
		end
		state.root.CFrame = cf
	end

	local function setAnim(state, name)
		name = name or "Idle"
		if state.anim == name then return end
		for trackName, track in pairs(state.tracks) do
			if trackName == name then track:Play(0.15) else track:Stop(0.15) end
		end
		state.anim = name
	end

	local function waveNeck(state)
		local t = os.clock() - sceneStart
		for i, joint in ipairs(state.neck) do
			joint.C0 = state.neckBase[i] * CFrame.Angles(0, 0, math.rad(NECK_WAVE.Amplitude * math.sin(t * NECK_WAVE.Speed + i * NECK_WAVE.Phase)))
		end
	end

	local function poseList(spec)
		if not spec or not spec.Pose then return {} end
		if spec.Pose.Joint then return {spec.Pose} end
		return spec.Pose
	end

	local function cameraAt(shot)
		camera.CFrame = CFrame.lookAt(stage:PointToWorldSpace(shot.Pos), stage:PointToWorldSpace(shot.Look))
	end

	for _, state in pairs(actors) do place(state, state.feet, state.facing) end
	tweenTo(fade, {BackgroundTransparency = 1}, CS.FadeSeconds)

	local lastCamera = nil
	for _, beat in ipairs(scene) do
		if not actors.Actor.model.Parent then break end

		local camFrom = (beat.Camera and beat.Camera.From) or lastCamera
		local camTo = (beat.Camera and beat.Camera.To) or camFrom

		-- Per-actor setup for this beat.
		local plans = {}
		for role, state in pairs(actors) do
			local spec = beat[role] or {}
			if spec.Lift then state.lift = spec.Lift end
			if spec.Bob then state.bob = spec.Bob end
			if spec.Fall ~= nil then state.fallen = spec.Fall end
			setAnim(state, state.fallen and "Idle" or spec.Anim)

			local poses = {}
			for _, p in ipairs(poseList(spec)) do
				local joint = findJoint(state.model, p.Joint)
				if joint then
					if not state.poseBase[joint] then state.poseBase[joint] = joint.C0 end
					table.insert(poses, {joint = joint, axis = p.Axis or "Z", degrees = p.Degrees})
				end
			end
			-- Joints posed last beat but not this one go back to rest.
			for joint in pairs(state.posed) do
				local keep = false
				for _, p in ipairs(poses) do if p.joint == joint then keep = true end end
				if not keep then joint.C0 = state.poseBase[joint] end
			end
			state.posed = {}
			for _, p in ipairs(poses) do state.posed[p.joint] = true end

			plans[role] = {
				state = state,
				from = spec.From or state.feet,
				to = spec.To or spec.From or state.feet,
				face = spec.Face,
				shake = spec.Shake,
				poses = poses,
			}
		end

		if beat.Title then
			titleLabel.Text = beat.Title
			subtitleLabel.Text = beat.Subtitle or ""
			tweenTo(titleLabel, {TextTransparency = 0}, 0.3)
			tweenTo(titleStroke, {Transparency = 0}, 0.3)
			tweenTo(subtitleLabel, {TextTransparency = 0}, 0.3)
			tweenTo(subtitleStroke, {Transparency = 0}, 0.3)
		end

		local start = os.clock()
		while true do
			local t = math.clamp((os.clock() - start) / beat.Seconds, 0, 1)
			local e = easeInOut(t)

			if camFrom then
				cameraAt({Pos = camFrom.Pos:Lerp(camTo.Pos, e), Look = camFrom.Look:Lerp(camTo.Look, e)})
			end

			-- Feet first, so "look at the other actor" uses this frame's positions.
			for _, plan in pairs(plans) do
				plan.state.feet = plan.from:Lerp(plan.to, e)
			end
			for role, plan in pairs(plans) do
				local state = plan.state
				local facing
				if plan.face == "Camera" then
					facing = stage:PointToObjectSpace(camera.CFrame.Position) - state.feet
				elseif plan.face == "Actor" or plan.face == "Victim" then
					local other = actors[plan.face]
					facing = other and (other.feet - state.feet) or state.facing
				elseif typeof(plan.face) == "Vector3" then
					facing = plan.face - state.feet
				elseif (plan.to - plan.from).Magnitude > 0.01 then
					facing = plan.to - plan.from
				else
					facing = state.facing
				end
				if facing.Magnitude > 0.01 then state.facing = facing end
				place(state, state.feet, state.facing, plan.shake)

				local snap = easeInOut(math.clamp((os.clock() - start) / math.min(0.25, beat.Seconds), 0, 1))
				for _, p in ipairs(plan.poses) do
					p.joint.C0 = state.poseBase[p.joint] * rotateOn(p.axis, math.rad(p.degrees * snap))
				end
				waveNeck(state)
			end

			if t >= 1 then break end
			RunService.RenderStepped:Wait()
		end

		lastCamera = camTo
	end

	tweenTo(fade, {BackgroundTransparency = 0}, CS.FadeSeconds)
	task.wait(CS.FadeSeconds)

	for _, state in pairs(actors) do state.model:Destroy() end
	tweenTo(titleLabel, {TextTransparency = 1}, 0.1)
	tweenTo(titleStroke, {Transparency = 1}, 0.1)
	tweenTo(subtitleLabel, {TextTransparency = 1}, 0.1)
	tweenTo(subtitleStroke, {Transparency = 1}, 0.1)

	camera.CameraType = Enum.CameraType.Custom
	local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
	setControlsEnabled(true)

	tweenTo(fade, {BackgroundTransparency = 1}, CS.FadeSeconds)
	task.wait(CS.FadeSeconds)
	screenGui.Enabled = false
	playing = false
end

CutsceneRemote.OnClientEvent:Connect(function(kind, characterName, stageFromServer)
	local group = Cutscenes[kind]
	local scene = group and group[characterName]
	if scene then playScene(scene, characterName, stageFromServer) end
end)

-- Test keys: one key per intro scene (Constants.Cutscene.DebugKeys), playable any time without
-- starting a round. Goes through the server so the stage area is streamed in first.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local characterName = CS.DebugKeys[input.KeyCode]
	if characterName then CutsceneRemote:FireServer("Intro", characterName) end
end)
