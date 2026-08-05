local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local AbilityModule = require(ReplicatedStorage.Shared.AbilityModule)
local Types = require(ReplicatedStorage.Shared.Types)
local EffectsService = require(ServerScriptService.Services.EffectsService)

local B = Constants.Bobzilla

local Bobzilla = {}

Bobzilla.Abilities = {}

local function getHumanoid(player)
    local character = player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(player)
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isWarden(player)
    return player:GetAttribute("Team") == Types.Team.Warden
end

local function isYokai(player)
    return player:GetAttribute("Team") == Types.Team.Yokai
end

local function mouthOffsetFromRoot(character, root)
    local ray = B.HeatRay
    local boxCFrame, boxSize = character:GetBoundingBox()
    local floorY = boxCFrame.Position.Y - boxSize.Y / 2
    local up = (floorY + ray.MouthHeightStuds) - root.Position.Y
    return CFrame.new(0, up, -ray.MouthForwardStuds)
end

local function mouthPosition(character, root)
    return (root.CFrame * mouthOffsetFromRoot(character, root)).Position
end

local function aimDirection(root)
    local pitch = math.rad(B.HeatRay.MouthPitchDegrees)
    return (root.CFrame * CFrame.Angles(pitch, 0, 0)).LookVector
end

local function beamStopPoint(character, from, direction)
    local ray = B.HeatRay
    local ignore = {character}
    for _, other in ipairs(Players:GetPlayers()) do
        if other.Character then table.insert(ignore, other.Character) end
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore

    local blocked = workspace:Raycast(from, direction * ray.RangeStuds, params)
    if blocked then return blocked.Position end
    return from + direction * ray.RangeStuds
end

local function distanceToBeam(point, from, to)
    local along = to - from
    local lengthSquared = along:Dot(along)
    if lengthSquared <= 0 then return (point - from).Magnitude end
    local howFarAlong = math.clamp((point - from):Dot(along) / lengthSquared, 0, 1)
    return (point - (from + along * howFarAlong)).Magnitude
end

local function aimBeam(beam, from, to)
    local length = (to - from).Magnitude
    if length <= 0 then return end

    local middle = from + (to - from) * 0.5
    local aim = CFrame.lookAt(middle, to)
        * CFrame.Angles(-math.pi / 2, 0, 0)
        * CFrame.Angles(0, math.rad(B.HeatRay.BeamRollDegrees), 0)

    for _, part in ipairs(beam:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Size = Vector3.new(part.Size.X, length, part.Size.Z)
            part.CFrame = aim
        end
    end
end

Bobzilla.Abilities.HeatRay = function(player, params)
    if not AbilityModule.isOffCooldown(player, "HeatRay") then return end

    local root = getRootPart(player)
    local humanoid = getHumanoid(player)
    local character = player.Character
    if not (root and humanoid and character) then return end

    local ray = B.HeatRay
    AbilityModule.startCooldown(player, "HeatRay", ray.CooldownSeconds)

    EffectsService:Play("BobzillaHeatRayWindup", nil, {
        AttachTo = root,
        CFrame = mouthOffsetFromRoot(character, root),
        Scale = ray.WindupScale,
        Lifetime = ray.WindupSeconds,
        BurstSeconds = ray.WindupBurstSeconds,
    })

    local walkBefore = humanoid.WalkSpeed
    humanoid.WalkSpeed = walkBefore * ray.FiringSpeedMultiplier

    task.spawn(function()
        task.wait(ray.WindupSeconds)

        local function stillFighting()
            return humanoid.Parent ~= nil and humanoid.Health > 0 and root.Parent ~= nil
        end

        local function releaseHim()
            if humanoid.Parent then humanoid.WalkSpeed = walkBefore end
        end

        if not stillFighting() then
            releaseHim()
            return
        end

        local direction = aimDirection(root)
        local from = mouthPosition(character, root)
        local to = beamStopPoint(character, from, direction)

        local beam = EffectsService:Play("BobzillaHeatRay", nil, {
            CFrame = CFrame.new(from),
            Lifetime = ray.DurationSeconds,
        })
        if beam then aimBeam(beam, from, to) end

        local lastBurnAt = nil
        local totalTicks = math.max(1, math.floor(ray.DurationSeconds / ray.TickSeconds))

        for _ = 1, totalTicks do
            if not stillFighting() then break end

            from = mouthPosition(character, root)
            if ray.TracksAim then direction = aimDirection(root) end
            to = beamStopPoint(character, from, direction)

            if beam and beam.Parent then aimBeam(beam, from, to) end

            if not lastBurnAt or (to - lastBurnAt).Magnitude > ray.HitRadiusStuds then
                lastBurnAt = to
                EffectsService:Play("BobzillaHeatRayHit", nil, {
                    CFrame = CFrame.new(to),
                    Lifetime = ray.HitLifetimeSeconds,
                    BurstSeconds = ray.HitBurstSeconds,
                    LingerSeconds = ray.HitLingerSeconds,
                })
            end

            for _, other in ipairs(Players:GetPlayers()) do
                if isWarden(other) then
                    local otherRoot = getRootPart(other)
                    local otherHumanoid = getHumanoid(other)
                    if otherRoot and otherHumanoid and otherHumanoid.Health > 0
                        and distanceToBeam(otherRoot.Position, from, to) <= ray.HitRadiusStuds then
                        otherHumanoid:TakeDamage(ray.DamagePerTick)
                    end
                end
            end

            task.wait(ray.TickSeconds)
        end

        releaseHim()
    end)
end

function Bobzilla:StartPassives(player)
end

return Bobzilla
