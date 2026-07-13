-- Whiteboard.client.lua
-- The player's half of the lobby whiteboard. Two jobs:
--
--   1. DRAWING: while you hold the left mouse button with the cursor on the board
--      (and you're standing close enough), we sample where the cursor touches the
--      board every frame, draw the dots instantly on OUR screen, and send the
--      points to the server in small batches so everyone else sees them too.
--
--   2. RENDERING: when the WhiteboardDraw remote delivers someone's points, we
--      draw them as little round dots on the board's canvas. Dots between two
--      sampled points get filled in, so fast mouse swipes still look like a
--      solid line instead of a dotted trail.
--
-- The server owns the truth: it validates, remembers, and rebroadcasts every
-- stroke. We ask for the full board once at startup (the "Ready" message) so a
-- late joiner sees everything drawn before they arrived.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local W = Constants.Whiteboard

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local drawRemote = Remotes:WaitForChild("WhiteboardDraw")
local wipeRemote = Remotes:WaitForChild("WhiteboardWipe")

------------------------------------------------------------------------------
-- Find the canvas. The SERVER already figured out which part is the writing
-- surface and put a SurfaceGui named "WhiteboardCanvas" on it -- we just look
-- for that, retrying briefly since it can take a moment to replicate on join.
-- If this place has no whiteboard, quietly do nothing.
------------------------------------------------------------------------------

local canvas = nil
for _ = 1, 30 do
	canvas = workspace:FindFirstChild("WhiteboardCanvas", true)
	if canvas then break end
	task.wait(0.5)
end
if not canvas then return end
local board = canvas.Parent

-- All dots live in this one frame, so a wipe is just "destroy the children".
local dotsFrame = Instance.new("Frame")
dotsFrame.Name = "Dots"
dotsFrame.Size = UDim2.fromScale(1, 1)
dotsFrame.BackgroundTransparency = 1
dotsFrame.ClipsDescendants = true
dotsFrame.Parent = canvas

------------------------------------------------------------------------------
-- Rendering dots
------------------------------------------------------------------------------

-- Where each stroke last left off, so we can fill the gap to the next point.
-- Key: "userId_strokeId" -> Vector2 in canvas pixels.
local lastDotAt = {}

local function placeDot(pixelPos, color)
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(W.DotSizePixels, W.DotSizePixels)
	dot.Position = UDim2.fromOffset(pixelPos.X, pixelPos.Y)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.Parent = dotsFrame
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)   -- full circle
	round.Parent = dot
end

local function renderBatch(userId, colorIndex, strokeId, points)
	local color = W.MarkerColors[colorIndex] or W.MarkerColors[1]
	local canvasSize = dotsFrame.AbsoluteSize
	local sizeX = math.max(canvasSize.X, 1)
	local sizeY = math.max(canvasSize.Y, 1)
	local strokeKey = userId .. "_" .. strokeId

	for _, p in ipairs(points) do
		local target = Vector2.new(p.x * sizeX, p.y * sizeY)
		local from = lastDotAt[strokeKey]
		if from then
			-- Fill the gap so the line looks solid: one dot every ~half dot-width.
			local distance = (target - from).Magnitude
			local steps = math.floor(distance / (W.DotSizePixels * 0.5))
			for i = 1, steps do
				placeDot(from:Lerp(target, i / (steps + 1)), color)
			end
		end
		placeDot(target, color)
		lastDotAt[strokeKey] = target
	end
end

drawRemote.OnClientEvent:Connect(function(userId, colorIndex, strokeId, points, isCatchUp)
	-- Our own live strokes were already drawn the moment the mouse moved --
	-- skip the echo. (Catch-up batches after joining DO include our old
	-- scribbles, and those we haven't drawn yet, so render them.)
	if userId == localPlayer.UserId and not isCatchUp then return end
	renderBatch(userId, colorIndex, strokeId, points)
end)

wipeRemote.OnClientEvent:Connect(function()
	dotsFrame:ClearAllChildren()
	lastDotAt = {}
end)

------------------------------------------------------------------------------
-- Drawing input
------------------------------------------------------------------------------

local myColorIndex = (localPlayer.UserId % #W.MarkerColors) + 1

-- Distance from a world position to the NEAREST point of the board -- not its
-- center. (The kids' board is ~46 studs tall, so its center floats way up in
-- the air; measuring to the center would say you're "far away" while you're
-- standing right at it.)
local function distanceToBoard(worldPos)
	local rel = board.CFrame:PointToObjectSpace(worldPos)
	local half = board.Size / 2
	local nearest = Vector3.new(
		math.clamp(rel.X, -half.X, half.X),
		math.clamp(rel.Y, -half.Y, half.Y),
		math.clamp(rel.Z, -half.Z, half.Z)
	)
	return (rel - nearest).Magnitude
end

-- Where is the mouse touching the board right now? Returns x, y in 0..1
-- canvas coordinates, or nil (not pointing at the board / too far away).
local function boardSpotUnderMouse()
	-- Must be standing near the board.
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	if distanceToBoard(root.Position) > W.DrawRangeStuds then return nil end

	-- Shoot a ray from the camera through the cursor, at ONLY the board. (Long
	-- reach on purpose: the camera can be zoomed way back behind the player.)
	local unitRay = mouse.UnitRay
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { board }
	local hit = workspace:Raycast(unitRay.Origin, unitRay.Direction * 120, rayParams)
	if not hit then return nil end

	-- Convert the world hit to a spot on the board's face. The SurfaceGui's X
	-- axis runs OPPOSITE the part's X on the Front face (and with it on Back);
	-- Y is down on the canvas but up on the part, so both flip.
	local rel = board.CFrame:PointToObjectSpace(hit.Position)
	local x
	if W.Face == "Back" then
		x = rel.X / board.Size.X + 0.5
	else
		x = 0.5 - rel.X / board.Size.X
	end
	local y = 0.5 - rel.Y / board.Size.Y
	if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
	return x, y
end

local drawing = false
local strokeCounter = 0
local pendingPoints = {}   -- sampled but not yet sent to the server
local lastFlushAt = 0
local lastSample = nil     -- last sampled spot (canvas pixels), to skip micro-moves

local function flush()
	if #pendingPoints > 0 then
		drawRemote:FireServer(strokeCounter, pendingPoints)
		pendingPoints = {}
	end
	lastFlushAt = tick()
end

local function endStroke()
	if not drawing then return end
	flush()
	drawing = false
	lastSample = nil
end

-- Roblox's camera ALSO listens for left-click-drag (that's how you rotate the
-- view), so a plain listener loses the fight: the camera grabs the drag and the
-- cursor never draws. Binding at HIGH priority lets us see the click first.
-- If the cursor is on the board and we're close enough, we start drawing and
-- SINK the input (the camera never hears about it). Anywhere else we PASS, and
-- clicking/dragging works exactly like normal.
ContextActionService:BindActionAtPriority("WhiteboardMarker", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		local x, y = boardSpotUnderMouse()
		if not x then return Enum.ContextActionResult.Pass end
		strokeCounter += 1
		drawing = true
		pendingPoints = {}
		lastSample = nil
		return Enum.ContextActionResult.Sink
	elseif inputState == Enum.UserInputState.End then
		if drawing then
			endStroke()
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1)

RunService.RenderStepped:Connect(function()
	if not drawing then return end

	local x, y = boardSpotUnderMouse()
	if not x then
		-- Dragged off the board (or stepped away): the stroke ends here.
		endStroke()
		return
	end

	-- Skip samples closer than half a dot to the last one -- they'd just pile
	-- dots on the same pixel and eat the board's point budget.
	local canvasSize = dotsFrame.AbsoluteSize
	local samplePixels = Vector2.new(x * math.max(canvasSize.X, 1), y * math.max(canvasSize.Y, 1))
	if lastSample and (samplePixels - lastSample).Magnitude < (W.DotSizePixels * 0.5) then return end
	lastSample = samplePixels

	local point = {x = x, y = y}
	table.insert(pendingPoints, point)

	-- Draw it on OUR screen right now (zero lag); everyone else gets it on the
	-- next flush below.
	renderBatch(localPlayer.UserId, myColorIndex, strokeCounter, {point})

	if tick() - lastFlushAt >= (1 / W.SendsPerSecond) then
		flush()
	end
end)

------------------------------------------------------------------------------
-- Ask the server for everything drawn before we joined.
------------------------------------------------------------------------------

drawRemote:FireServer("Ready")
