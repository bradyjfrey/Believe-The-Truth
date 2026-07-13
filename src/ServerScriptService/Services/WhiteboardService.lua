-- WhiteboardService.lua
-- The lobby whiteboard everyone can draw on. The kids' board model lives in
-- Workspace; this service finds it by name (Constants.Whiteboard.PartName),
-- puts a drawing canvas (SurfaceGui) on it, and keeps everyone's strokes in sync:
--
--   * A client sends batches of stroke points through the WhiteboardDraw remote.
--   * We sanity-check them (close enough? sane sizes? board not full?), remember
--     them, and rebroadcast to every client, which draws the dots locally.
--   * We keep the FULL drawing in `history`, so someone who joins late asks for
--     it (by sending "Ready") and gets the whole board replayed.
--   * A ProximityPrompt on the board ("Wipe the board", hold E) clears everything.
--
-- Marker colors are assigned per player from Constants.Whiteboard.MarkerColors --
-- the server picks the color (never trusts the client), so nobody can spoof.
--
-- To extend: a real color-picker, an eraser, or per-stroke thickness would all
-- ride the same remote -- add fields to the batch and validate them here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local W = Constants.Whiteboard

local WhiteboardService = {}

local board = nil          -- the BasePart we draw on
local drawRemote = nil     -- WhiteboardDraw RemoteEvent
local wipeRemote = nil     -- WhiteboardWipe RemoteEvent

-- Everything drawn since the last wipe. One entry per point-batch:
-- {userId = ..., strokeId = ..., points = { {x=0..1, y=0..1}, ... }}
local history = {}
local totalPoints = 0

-- Per-player timestamp of their last accepted batch (simple flood protection).
local lastSendAt = {}

local function markerColorIndex(userId)
    return (userId % #W.MarkerColors) + 1
end

local function isNearBoard(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    -- Distance to the NEAREST point of the board, not its center -- the kids'
    -- board is ~46 studs tall, so its center floats far overhead and would fail
    -- players standing right against it. Plus slack so lag doesn't eat strokes.
    local rel = board.CFrame:PointToObjectSpace(root.Position)
    local half = board.Size / 2
    local nearest = Vector3.new(
        math.clamp(rel.X, -half.X, half.X),
        math.clamp(rel.Y, -half.Y, half.Y),
        math.clamp(rel.Z, -half.Z, half.Z)
    )
    return (rel - nearest).Magnitude <= W.DrawRangeStuds + 10
end

-- Replay the whole board to one (late-joining) client.
local function sendHistory(player)
    for _, entry in ipairs(history) do
        -- The final `true` marks this as a catch-up batch, so the client renders
        -- it even if it's the player's own old scribbles.
        drawRemote:FireClient(player, entry.userId, markerColorIndex(entry.userId), entry.strokeId, entry.points, true)
    end
end

local function onDraw(player, strokeId, points)
    -- A client that just finished setting up asks for the board so far.
    if strokeId == "Ready" then
        sendHistory(player)
        return
    end

    -- Sanity checks: right shapes, close enough, not flooding, board not full.
    if typeof(strokeId) ~= "number" then return end
    if typeof(points) ~= "table" then return end
    if #points == 0 or #points > W.MaxPointsPerSend then return end
    if not isNearBoard(player) then return end

    local now = tick()
    local minInterval = 1 / (W.SendsPerSecond * 2)   -- 2x slack over the client's honest rate
    if lastSendAt[player.UserId] and (now - lastSendAt[player.UserId]) < minInterval then return end
    lastSendAt[player.UserId] = now

    if totalPoints + #points > W.MaxPointsTotal then return end   -- board is full; wipe to keep drawing

    -- Rebuild the points table ourselves so only clean {x, y} pairs get stored/broadcast.
    local clean = {}
    for _, p in ipairs(points) do
        if typeof(p) ~= "table" then return end
        local x, y = p.x, p.y
        if typeof(x) ~= "number" or typeof(y) ~= "number" then return end
        if x ~= x or y ~= y then return end   -- rejects NaN (NaN never equals itself)
        table.insert(clean, {x = math.clamp(x, 0, 1), y = math.clamp(y, 0, 1)})
    end

    table.insert(history, {userId = player.UserId, strokeId = strokeId, points = clean})
    totalPoints += #clean

    drawRemote:FireAllClients(player.UserId, markerColorIndex(player.UserId), strokeId, clean, false)
end

local function wipe()
    history = {}
    totalPoints = 0
    wipeRemote:FireAllClients()
end

function WhiteboardService:Init(remotes)
    drawRemote = remotes.Draw
    wipeRemote = remotes.Wipe

    -- Find the kids' board. PartName can be the surface part itself, or a Model
    -- (their Whiteboard model holds marker props + a Board frame). For a Model we
    -- pick the part with the BIGGEST flat face -- that's the writing surface, and
    -- it wins no matter what the individual parts are named.
    local found = workspace:FindFirstChild(W.PartName, true)
    local surface = nil
    if found then
        if found:IsA("BasePart") then
            surface = found
        else
            local bestFaceArea = 0
            for _, part in ipairs(found:GetDescendants()) do
                if part:IsA("BasePart") then
                    local dims = {part.Size.X, part.Size.Y, part.Size.Z}
                    table.sort(dims)
                    local faceArea = dims[2] * dims[3]   -- the two biggest dimensions = the flat face
                    if faceArea > bestFaceArea then
                        bestFaceArea = faceArea
                        surface = part
                    end
                end
            end
        end
    end
    if not surface then
        warn("WhiteboardService: nothing named '" .. W.PartName .. "' with a part in it found in Workspace -- "
            .. "whiteboard disabled. (Set Constants.Whiteboard.PartName to the board's real name.)")
        return
    end
    board = surface

    -- The canvas the dots go on. Clients find it by this exact name.
    local canvas = Instance.new("SurfaceGui")
    canvas.Name = "WhiteboardCanvas"
    canvas.Face = Enum.NormalId[W.Face]
    canvas.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    canvas.PixelsPerStud = W.PixelsPerStud
    canvas.Parent = board

    -- Hold-E prompt to wipe the board clean.
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "WipePrompt"
    prompt.ActionText = "Wipe the board"
    prompt.ObjectText = "Whiteboard"
    prompt.HoldDuration = W.WipeHoldSeconds
    prompt.MaxActivationDistance = W.DrawRangeStuds
    prompt.RequiresLineOfSight = false
    prompt.Parent = board
    prompt.Triggered:Connect(wipe)

    drawRemote.OnServerEvent:Connect(onDraw)

    Players.PlayerRemoving:Connect(function(player)
        lastSendAt[player.UserId] = nil
    end)
end

return WhiteboardService
