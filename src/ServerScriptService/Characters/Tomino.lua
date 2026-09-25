local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local AbilityModule = require(ReplicatedStorage.Shared.AbilityModule)
local Types = require(ReplicatedStorage.Shared.Types)
local EffectsService = require(ServerScriptService.Services.EffectsService)
local BleedService = require(ServerScriptService.Services.BleedService)

local T = Constants.Tomino

local Tomino = {}

Tomino.Abilities = {}

local activePinTrap = {}

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

local function livingWardenAt(player)
    if not isWarden(player) then return nil end
    local humanoid = getHumanoid(player)
    local root = getRootPart(player)
    if humanoid and root and humanoid.Health > 0 then return humanoid, root end
    return nil
end

local function playSwing(player, style)
    local swingRemote = ReplicatedStorage.Remotes:FindFirstChild("WeaponSwing")
    if swingRemote then swingRemote:FireAllClients(player, style) end
end

local function knockDown(humanoid, seconds)
    local walkBefore = humanoid.WalkSpeed
    local jumpBefore = humanoid.JumpPower
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid:ChangeState(Enum.HumanoidStateType.PlatformStanding)

    task.delay(seconds, function()
        if humanoid.Parent then
            humanoid.WalkSpeed = walkBefore
            humanoid.JumpPower = jumpBefore
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
end

local function flash(effectName, cframe)
    EffectsService:Play(effectName, nil, {
        CFrame = cframe,
        Lifetime = T.Effects.FlashSeconds,
        LingerSeconds = T.Effects.LingerSeconds,
    })
end

local function ignoringCharacters()
    local ignore = {}
    for _, other in ipairs(Players:GetPlayers()) do
        if other.Character then table.insert(ignore, other.Character) end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    return params
end

local function groundBelow(position, params)
    local hit = workspace:Raycast(position, Vector3.new(0, -200, 0), params)
    return hit and hit.Position or position
end

Tomino.Abilities.WhipLash = function(player, params)
    if not AbilityModule.isOffCooldown(player, "WhipLash") then return end
    local root = getRootPart(player)
    if not root then return end

    local lash = T.WhipLash
    AbilityModule.startCooldown(player, "WhipLash", lash.CooldownSeconds)
    playSwing(player, "TominoWhip")
    flash("TominoWhipLash", root.CFrame * CFrame.new(0, 0, -lash.RangeStuds / 2))

    for _, other in ipairs(Players:GetPlayers()) do
        local humanoid, otherRoot = livingWardenAt(other)
        if humanoid then
            local relative = root.CFrame:PointToObjectSpace(otherRoot.Position)
            if relative.Z <= lash.PassThroughGraceStuds and -relative.Z <= lash.RangeStuds
                and math.abs(relative.X) <= lash.SwingWidthStuds then
                humanoid:TakeDamage(lash.Damage)
                BleedService:Apply(humanoid, "TominoWhipLash", lash.BleedDamagePerSecond,
                    lash.BleedDurationSeconds, lash.MaxBleedStacks, true)
                flash("TominoWhipLashHit", CFrame.new(otherRoot.Position))
            end
        end
    end
end

Tomino.Abilities.WhipSlam = function(player, params)
    if not AbilityModule.isOffCooldown(player, "WhipSlam") then return end
    local root = getRootPart(player)
    local humanoid = getHumanoid(player)
    if not (root and humanoid) then return end

    local slam = T.WhipSlam
    AbilityModule.startCooldown(player, "WhipSlam", slam.CooldownSeconds)
    playSwing(player, "TominoWhipSlam")

    task.wait(slam.WindupSeconds)
    if not root.Parent or humanoid.Health <= 0 then return end

    local center = groundBelow(root.Position, ignoringCharacters())
    flash("TominoWhipSlam", CFrame.new(center))

    for _, other in ipairs(Players:GetPlayers()) do
        local victim, otherRoot = livingWardenAt(other)
        if victim then
            local flat = Vector3.new(otherRoot.Position.X - root.Position.X, 0, otherRoot.Position.Z - root.Position.Z)
            if flat.Magnitude <= slam.RadiusStuds then
                victim:TakeDamage(slam.Damage)
                knockDown(victim, slam.RagdollSeconds)
            end
        end
    end
end

Tomino.Abilities.PinTrap = function(player, params)
    if not AbilityModule.isOffCooldown(player, "PinTrap") then return end
    local root = getRootPart(player)
    if not root then return end

    local trap = T.PinTrap
    AbilityModule.startCooldown(player, "PinTrap", trap.CooldownSeconds)

    local previous = activePinTrap[player]
    if previous then previous() end

    local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
    local spot = groundBelow(root.Position + look * trap.PlaceForwardStuds, ignoringCharacters())
    local facing = CFrame.lookAt(spot, spot + look)

    local pad = Instance.new("Part")
    pad.Name = "TominoPinTrapTrigger"
    pad.Size = trap.TriggerPadSize
    pad.Anchored = true
    pad.CanCollide = false
    pad.Transparency = 1
    pad.CFrame = facing + Vector3.new(0, pad.Size.Y / 2, 0)
    pad.Parent = workspace

    local visual = EffectsService:Play("TominoPinTrap", nil, {
        CFrame = facing,
        Lifetime = trap.LifetimeSeconds,
    })

    local function cleanup()
        if pad.Parent then pad:Destroy() end
        if visual and visual.Parent then visual:Destroy() end
        if activePinTrap[player] == cleanup then activePinTrap[player] = nil end
    end
    activePinTrap[player] = cleanup

    pad.Touched:Connect(function(hit)
        if not pad.Parent then return end
        local model = hit:FindFirstAncestorOfClass("Model")
        local victimPlayer = model and Players:GetPlayerFromCharacter(model)
        if not victimPlayer then return end
        local victim = livingWardenAt(victimPlayer)
        if not victim then return end

        flash("TominoPinTrapTrip", pad.CFrame)
        knockDown(victim, trap.TripSeconds)
        cleanup()
    end)

    task.delay(trap.LifetimeSeconds, cleanup)
end

Tomino.Abilities.BombPin = function(player, params)
    local root = getRootPart(player)
    if not root then return end

    local bomb = T.BombPin
    if not AbilityModule.useCharge(player, "BombPin", bomb.Charges, bomb.CooldownSeconds) then return end

    local rayParams = ignoringCharacters()
    local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
    local blocked = workspace:Raycast(root.Position, look * bomb.ThrowRangeStuds, rayParams)
    local landing = blocked and (blocked.Position - look * 2) or (root.Position + look * bomb.ThrowRangeStuds)
    local center = groundBelow(landing, rayParams)
    local start = (root.CFrame * CFrame.new(0, 2, -3)).Position

    local mover = Instance.new("Part")
    mover.Name = "TominoBombPinFlight"
    mover.Size = Vector3.new(1, 1, 1)
    mover.Transparency = 1
    mover.Anchored = true
    mover.CanCollide = false
    mover.CanQuery = false
    mover.CanTouch = false
    mover.CFrame = CFrame.lookAt(start, center)
    mover.Parent = workspace

    EffectsService:Play("TominoBombPinThrow", nil, {
        AttachTo = mover,
        Parent = mover,
        Lifetime = bomb.FlightSeconds + 1,
    })

    local flightStart = os.clock()
    while true do
        local t = math.min((os.clock() - flightStart) / bomb.FlightSeconds, 1)
        local position = start:Lerp(center, t) + Vector3.new(0, bomb.ArcHeightStuds * 4 * t * (1 - t), 0)
        local spin = CFrame.Angles(-t * bomb.FlightSeconds * bomb.SpinsPerSecond * math.pi * 2, 0, 0)
        mover.CFrame = CFrame.lookAt(position, position + look) * spin
        if t >= 1 then break end
        RunService.Heartbeat:Wait()
    end
    mover:Destroy()

    EffectsService:Play("TominoBombPin", nil, {
        CFrame = CFrame.new(center),
        Lifetime = bomb.PoolSeconds,
        LingerSeconds = T.Effects.LingerSeconds,
    })

    task.spawn(function()
        for _ = 1, math.floor(bomb.PoolSeconds) do
            task.wait(1)
            for _, other in ipairs(Players:GetPlayers()) do
                local victim, otherRoot = livingWardenAt(other)
                if victim then
                    local offset = otherRoot.Position - center
                    local flat = Vector3.new(offset.X, 0, offset.Z)
                    if flat.Magnitude <= bomb.PoolRadiusStuds and math.abs(offset.Y) <= bomb.PoolRadiusStuds then
                        victim:TakeDamage(bomb.DamagePerSecond)
                    end
                end
            end
        end
    end)
end

local function clearPanicStruck()
    for _, other in ipairs(Players:GetPlayers()) do
        other:SetAttribute("StaminaRegenScale", nil)
    end
end

function Tomino:StartPassives(player)
    if player:GetAttribute("PanicStruckRunning") then return end
    player:SetAttribute("PanicStruckRunning", true)

    task.spawn(function()
        while player.Parent and player:GetAttribute("Character") == Types.Character.Tomino do
            local root = getRootPart(player)
            for _, other in ipairs(Players:GetPlayers()) do
                local _, otherRoot = livingWardenAt(other)
                local inRange = root and otherRoot
                    and (otherRoot.Position - root.Position).Magnitude <= T.PanicStruck.RangeStuds
                other:SetAttribute("StaminaRegenScale", inRange and T.PanicStruck.RegenScale or nil)
            end
            task.wait(T.PanicStruck.CheckEverySeconds)
        end
        clearPanicStruck()
        if activePinTrap[player] then activePinTrap[player]() end
        player:SetAttribute("PanicStruckRunning", nil)
    end)
end

return Tomino
