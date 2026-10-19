-- Cutscenes.lua
-- Scene data for the scripted intro/win/loss cutscenes. Cutscene.client.lua plays them;
-- RoundService reads their length so the round waits for them.
--
-- A scene is a list of BEATS played in order, plus an optional `Victim` (a second character
-- model that shares the stage, e.g. the Warden Rokurokubi strangles). Every position is relative
-- to the stage: the top of the `CutsceneStage` part in Workspace. X = stage right, Y = up,
-- Z = toward the camera is NEGATIVE (Roblox look direction). Our rigs are ~2.4x normal size
-- (12 studs tall), so distances here are bigger than they look.
--
-- Beat fields:
--   Seconds     how long the beat lasts (required)
--   Camera      {From = {Pos = Vector3, Look = Vector3}, To = {...}} eased between From and To;
--               leave To out to hold still. Carries over from the previous beat if absent.
--   Title       big name card text; Subtitle the smaller line under it
--   Actor       what the character does this beat (see below); Victim = same for the second model
--
-- Actor / Victim fields (all optional):
--   From, To    the FEET position, eased over the beat; absent = stays put
--   Face        "Camera", "Actor", "Victim", a Vector3 stage point, or absent = the way it moves
--   Anim        "Walk" or "Idle" (default Idle)
--   Pose        {Joint = "Left Shoulder", Axis = "Z", Degrees = -110} or a list of those; joint
--               names/axes as in WeaponSwing.client.lua. Held for the beat, released after.
--   Shake       studs of jitter (struggling)
--   Fall        true = drops face-down and stays down for the rest of the scene
--   Lift        studs above the floor (floating characters); carries over
--   Bob         studs of gentle up/down float; carries over

local Cutscenes = {}

Cutscenes.Intro = {
	Momotaro = {
		-- Low, wide shot; he runs in from stage right and stops centre.
		{
			Seconds = 1.6,
			Camera = {From = {Pos = Vector3.new(-18, 4, -42), Look = Vector3.new(0, 6, 0)}},
			Actor = {From = Vector3.new(34, 0, 0), To = Vector3.new(0, 0, 0), Anim = "Walk"},
		},
		-- Turns to us and flicks the katana up.
		{
			Seconds = 0.9,
			Camera = {
				From = {Pos = Vector3.new(-18, 4, -42), Look = Vector3.new(0, 6, 0)},
				To = {Pos = Vector3.new(-4, 7, -30), Look = Vector3.new(0, 7, 0)},
			},
			Actor = {Face = "Camera", Pose = {Joint = "Left Shoulder", Axis = "Z", Degrees = -110}},
		},
		-- Push in on the pose while the name card shows.
		{
			Seconds = 1.6,
			Camera = {
				From = {Pos = Vector3.new(-4, 7, -30), Look = Vector3.new(0, 7, 0)},
				To = {Pos = Vector3.new(-2, 8, -20), Look = Vector3.new(0, 8, 0)},
			},
			Actor = {Face = "Camera", Pose = {Joint = "Left Shoulder", Axis = "Z", Degrees = -110}},
			Title = "MOMOTARO",
			Subtitle = "WARDEN",
		},
	},

	-- The kids' brief: she floats at a Warden, strangles them with her neck while they struggle,
	-- then comes for you.
	Rokurokubi = {
		Victim = "Momotaro",
		-- Wide: Momotaro stands centre and turns to see her floating in from stage right.
		{
			Seconds = 2.2,
			Camera = {
				From = {Pos = Vector3.new(-22, 9, -56), Look = Vector3.new(4, 9, 0)},
				To = {Pos = Vector3.new(-18, 9, -50), Look = Vector3.new(4, 9, 0)},
			},
			Actor = {From = Vector3.new(40, 0, -4), To = Vector3.new(9, 0, -3), Lift = 3, Bob = 0.5, Face = "Victim"},
			Victim = {From = Vector3.new(-2, 0, 0), Face = "Actor"},
		},
		-- Closer: the grab. He struggles, hands at his throat.
		{
			Seconds = 2.2,
			Camera = {
				From = {Pos = Vector3.new(-10, 11, -36), Look = Vector3.new(2, 10, 0)},
				To = {Pos = Vector3.new(-8, 11, -32), Look = Vector3.new(2, 10, 0)},
			},
			Actor = {To = Vector3.new(5, 0, -2), Lift = 3, Bob = 0.3, Face = "Victim"},
			Victim = {
				Face = "Actor",
				Shake = 0.35,
				Pose = {
					{Joint = "Right Shoulder", Axis = "Z", Degrees = 130},
					{Joint = "Left Shoulder", Axis = "Z", Degrees = -130},
				},
			},
		},
		-- He drops.
		{
			Seconds = 1.0,
			Camera = {From = {Pos = Vector3.new(-8, 11, -32), Look = Vector3.new(2, 7, 0)}},
			Actor = {Face = "Victim"},
			Victim = {Fall = true},
		},
		-- She turns to us and comes straight at the camera. Cut to black.
		{
			Seconds = 1.3,
			Camera = {
				From = {Pos = Vector3.new(-8, 11, -32), Look = Vector3.new(2, 10, 0)},
				To = {Pos = Vector3.new(-8, 11, -32), Look = Vector3.new(-4, 13, -17)},
			},
			Actor = {To = Vector3.new(-4, 0, -17), Bob = 0.6, Face = "Camera"},
			Title = "ROKUROKUBI",
			Subtitle = "YOKAI",
		},
	},
}

function Cutscenes.duration(scene)
	local total = 0
	for _, beat in ipairs(scene) do
		total += beat.Seconds
	end
	return total
end

return Cutscenes
