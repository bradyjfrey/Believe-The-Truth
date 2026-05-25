-- Momotaro.lua
-- Momotaro's four abilities + his passive. AbilityService calls into the
-- functions in Momotaro.Abilities by name when the player presses a key.
--
-- Every ability function follows the same pattern:
--   1. Check cooldown — bail if not ready
--   2. Start cooldown
--   3. Maybe wait for a windup
--   4. Do the work (damage, stun, spawn a thing, etc.)
--   5. Call EffectsService:Play so the art team can hook in VFX/SFX

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Constants = require(ReplicatedStorage.Shared.Constants)
local AbilityModule = require(ReplicatedStorage.Shared.AbilityModule)
local Types = require(ReplicatedStorage.Shared.Types)
local EffectsService = require(ServerScriptService.Services.EffectsService)
local BleedService = require(ServerScriptService.Services.BleedService)
local Rokurokubi = require(ServerScriptService.Characters.Rokurokubi)

local Momotaro = {}
Momotaro.Abilities = {}

local M = Constants.Momotaro

------------------------------------------------------------------------------
-- Little helpers used by more than one ability
------------------------------------------------------------------------------

local function getHumanoid(player)
    local character = player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(player)
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isYokai(player)
    return player:GetAttribute("Team") == Types.Team.Yokai
end

local function isWarden(player)
    return player:GetAttribute("Team") == Types.Team.Warden
end

-- Find Yokai players in front of `attackerRoot` within `forwardStuds` and
-- within `sideStuds` to either side of the look direction. Used by Katana.
local function findYokaiInFront(attackerRoot, forwardStuds, sideStuds)
    local hits = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if isYokai(player) then
            local otherRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if otherRoot then
                local relative = attackerRoot.CFrame:PointToObjectSpace(otherRoot.Position)
                -- In object space, forward is -Z. So a positive forward distance is -relative.Z.
                if relative.Z < 0 and -relative.Z <= forwardStuds and math.abs(relative.X) <= sideStuds then
                    table.insert(hits, player)
                end
            end
        end
    end
    return hits
end

-- Spawns a companion (Inuta, Saru, Kijiro). Tries in order:
--   1. A Model the art team dropped into ReplicatedStorage/Companions/<name>
--   2. The Creator Store asset at `assetId` via InsertService:LoadAsset
--   3. A colored placeholder Part so the ability is testable even without art
local InsertService = game:GetService("InsertService")

local function placeAtPosition(thing, position)
    if thing:IsA("Model") then
        if not thing.PrimaryPart then
            thing.PrimaryPart = thing:FindFirstChildWhichIsA("BasePart")
        end
        if thing.PrimaryPart then
            thing:PivotTo(CFrame.new(position))
        end
    elseif thing:IsA("BasePart") then
        thing.Position = position
    end
end

local function spawnCompanion(name, assetId, fallbackColor, fallbackSize, position, parent)
    -- 1. Local override from the art team
    local companionsFolder = ReplicatedStorage:FindFirstChild("Companions")
    local template = companionsFolder and companionsFolder:FindFirstChild(name)
    if template then
        local clone = template:Clone()
        clone.Parent = parent
        placeAtPosition(clone, position)
        return clone
    end

    -- 2. Pull the model from Roblox's Creator Store at runtime
    if assetId and assetId > 0 then
        local ok, container = pcall(function()
            return InsertService:LoadAsset(assetId)
        end)
        if ok and container then
            local asset = container:FindFirstChildWhichIsA("Model")
                       or container:FindFirstChildWhichIsA("BasePart")
            if asset then
                asset.Name = name
                asset.Parent = parent
                placeAtPosition(asset, position)
                container:Destroy()
                return asset
            end
            container:Destroy()
        end
    end

    -- 3. Fallback placeholder
    local part = Instance.new("Part")
    part.Name = name
    part.Size = fallbackSize
    part.Color = fallbackColor
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.SmoothPlastic
    part.Position = position
    part.Parent = parent
    return part
end

-- Returns the BasePart we should treat as the "anchor" for a companion (so we
-- can read its position or anchor it).
local function companionAnchor(companion)
    if companion:IsA("BasePart") then return companion end
    if companion:IsA("Model") then
        return companion.PrimaryPart or companion:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

------------------------------------------------------------------------------
-- Q — KATANA
-- 0.5s windup → dash forward 30 studs, hitting any Yokai in the path for
-- 15 damage and a 3-second stun. Stops at walls; can hit multiple enemies.
------------------------------------------------------------------------------
Momotaro.Abilities.Katana = function(player, params)
    if not AbilityModule.isOffCooldown(player, "Katana") then return end
    local humanoid = getHumanoid(player)
    local rootPart = getRootPart(player)
    if not humanoid or not rootPart then return end

    AbilityModule.startCooldown(player, "Katana", M.Katana.CooldownSeconds)

    EffectsService:Play("MomotaroKatanaWindup", rootPart.Position)
    task.wait(M.Katana.WindupSeconds)
    if humanoid.Health <= 0 then return end  -- died during windup

    -- Dash: BodyVelocity pushes the root forward for DashDurationSeconds.
    local lookVector = rootPart.CFrame.LookVector
    local dashSpeed = M.Katana.DashStuds / M.Katana.DashDurationSeconds
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e5, 0, 1e5)
    bodyVelocity.Velocity = Vector3.new(lookVector.X * dashSpeed, 0, lookVector.Z * dashSpeed)
    bodyVelocity.Parent = rootPart
    Debris:AddItem(bodyVelocity, M.Katana.DashDurationSeconds)

    EffectsService:Play("MomotaroKatanaSwing", rootPart.Position)

    -- Hit detection during the dash. Poll a few times so we catch Yokai who
    -- step into the swing zone mid-dash.
    local alreadyHit = {}
    local elapsed = 0
    local stepSeconds = 0.05
    while elapsed < M.Katana.DashDurationSeconds do
        local hits = findYokaiInFront(rootPart, M.Katana.DashStuds, M.Katana.HitboxWidth / 2)
        for _, yokai in ipairs(hits) do
            if not alreadyHit[yokai] then
                alreadyHit[yokai] = true
                local yokaiHumanoid = getHumanoid(yokai)
                local yokaiRoot = getRootPart(yokai)
                if yokaiHumanoid and yokaiRoot then
                    yokaiHumanoid:TakeDamage(M.Katana.Damage)
                    EffectsService:Play("MomotaroKatanaHit", yokaiRoot.Position)

                    -- Stun: freeze movement and jumping for StunSeconds.
                    local originalWalk = yokaiHumanoid.WalkSpeed
                    local originalJump = yokaiHumanoid.JumpPower
                    yokaiHumanoid.WalkSpeed = 0
                    yokaiHumanoid.JumpPower = 0
                    task.delay(M.Katana.StunSeconds, function()
                        if yokaiHumanoid and yokaiHumanoid.Parent then
                            yokaiHumanoid.WalkSpeed = originalWalk
                            yokaiHumanoid.JumpPower = originalJump
                        end
                    end)

                    -- If we hit a Rokurokubi, any wrap or strangle she's
                    -- holding gets interrupted (teammate save).
                    if yokai:GetAttribute("Character") == Types.Character.Rokurokubi then
                        Rokurokubi.InterruptHolds(yokai)
                    end
                end
            end
        end
        task.wait(stepSeconds)
        elapsed = elapsed + stepSeconds
    end
end

------------------------------------------------------------------------------
-- E — GUARD DOG (INUTA)
-- Drop Inuta at Momotaro's feet. He barks at any Yokai within 50 studs,
-- dealing 1-5 damage per bark and slowing them to 50% speed. 40 HP, lifetime
-- 60 seconds.
------------------------------------------------------------------------------
Momotaro.Abilities.GuardDog = function(player, params)
    if not AbilityModule.isOffCooldown(player, "GuardDog") then return end
    local rootPart = getRootPart(player)
    if not rootPart then return end

    AbilityModule.startCooldown(player, "GuardDog", M.GuardDog.CooldownSeconds)

    local spawnPos = rootPart.Position - Vector3.new(0, 2, 0)
    local inuta = spawnCompanion(
        "Inuta",
        M.GuardDog.InutaAssetId,
        Color3.fromRGB(120, 80, 40),     -- brown placeholder fallback
        Vector3.new(3, 2, 4),
        spawnPos,
        workspace
    )
    EffectsService:Play("MomotaroInutaDeploy", spawnPos)

    -- Store Inuta's "HP" as an attribute so the placeholder Part doesn't
    -- need a Humanoid. If art-team Model has its own Humanoid later, we
    -- could swap to reading that instead.
    inuta:SetAttribute("Health", M.GuardDog.InutaHealth)

    local startTime = tick()
    local slowedYokai = {}    -- {humanoid = originalWalkSpeed}

    local function despawn()
        for yokaiHumanoid, originalSpeed in pairs(slowedYokai) do
            if yokaiHumanoid and yokaiHumanoid.Parent then
                yokaiHumanoid.WalkSpeed = originalSpeed
            end
        end
        if inuta and inuta.Parent then inuta:Destroy() end
    end

    -- Detection loop: every Heartbeat, find Yokai in range and apply slow.
    local detectionConn
    detectionConn = RunService.Heartbeat:Connect(function()
        if not inuta or not inuta.Parent then
            if detectionConn then detectionConn:Disconnect() end
            return
        end
        local elapsed = tick() - startTime
        local health = inuta:GetAttribute("Health") or 0
        if elapsed >= M.GuardDog.InutaLifetimeSeconds or health <= 0 then
            if detectionConn then detectionConn:Disconnect() end
            despawn()
            return
        end

        -- Who's in range right now?
        local inRange = {}
        local inutaPos = inuta:IsA("Model") and inuta:GetPivot().Position or inuta.Position
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if isYokai(otherPlayer) then
                local otherRoot = otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart")
                if otherRoot and (otherRoot.Position - inutaPos).Magnitude <= M.GuardDog.DetectRangeStuds then
                    local h = getHumanoid(otherPlayer)
                    if h then inRange[h] = true end
                end
            end
        end

        -- Apply slow to newly in-range Yokai, restore speed to those who left.
        for h in pairs(inRange) do
            if not slowedYokai[h] then
                slowedYokai[h] = h.WalkSpeed
                h.WalkSpeed = h.WalkSpeed * M.GuardDog.SlowMultiplier
            end
        end
        for h, originalSpeed in pairs(slowedYokai) do
            if not inRange[h] then
                if h and h.Parent then h.WalkSpeed = originalSpeed end
                slowedYokai[h] = nil
            end
        end
    end)

    -- Bark loop: damage tick once per BarkIntervalSeconds.
    task.spawn(function()
        while inuta and inuta.Parent do
            task.wait(M.GuardDog.BarkIntervalSeconds)
            if not inuta or not inuta.Parent then break end
            local inutaPos = inuta:IsA("Model") and inuta:GetPivot().Position or inuta.Position
            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if isYokai(otherPlayer) then
                    local otherRoot = otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if otherRoot and (otherRoot.Position - inutaPos).Magnitude <= M.GuardDog.DetectRangeStuds then
                        local h = getHumanoid(otherPlayer)
                        if h then
                            local barkDamage = math.random(M.GuardDog.MinDamage, M.GuardDog.MaxDamage)
                            h:TakeDamage(barkDamage)
                            EffectsService:Play("MomotaroInutaBark", inutaPos)
                        end
                    end
                end
            end
        end
    end)
end

------------------------------------------------------------------------------
-- R — MESSY EATER
-- Saru briefly appears, eats a banana, drops the peel. Any Yokai who steps
-- on the peel is ragdolled for 2 seconds.
------------------------------------------------------------------------------
Momotaro.Abilities.MessyEater = function(player, params)
    if not AbilityModule.isOffCooldown(player, "MessyEater") then return end
    local rootPart = getRootPart(player)
    if not rootPart then return end

    AbilityModule.startCooldown(player, "MessyEater", M.MessyEater.CooldownSeconds)

    local saruPos = rootPart.Position - Vector3.new(0, 2, 0)
    local saru = spawnCompanion(
        "Saru",
        nil,                              -- no asset ID yet — Brady will provide later
        Color3.fromRGB(240, 220, 80),     -- yellow placeholder fallback
        Vector3.new(2, 2, 2),
        saruPos,
        workspace
    )
    EffectsService:Play("MomotaroSaruEat", saruPos)

    task.wait(M.MessyEater.SaruEatSeconds)
    if saru and saru.Parent then saru:Destroy() end

    -- Drop the banana peel where Saru was.
    local peel = Instance.new("Part")
    peel.Name = "BananaPeel"
    peel.Size = Vector3.new(2, 0.3, 2)
    peel.Color = Color3.fromRGB(240, 220, 80)
    peel.Material = Enum.Material.SmoothPlastic
    peel.Anchored = true
    peel.CanCollide = false
    peel.Position = saruPos
    peel.Parent = workspace
    EffectsService:Play("MomotaroBananaDrop", peel.Position)

    local triggered = false
    peel.Touched:Connect(function(hit)
        if triggered then return end
        local model = hit:FindFirstAncestorOfClass("Model")
        if not model then return end
        local victim = Players:GetPlayerFromCharacter(model)
        if not victim or not isYokai(victim) then return end
        local h = getHumanoid(victim)
        if not h then return end
        triggered = true

        EffectsService:Play("MomotaroBananaSlip", peel.Position)

        -- Ragdoll: zero out movement and put the humanoid in PlatformStanding,
        -- which acts like a knockdown.
        local originalWalk = h.WalkSpeed
        local originalJump = h.JumpPower
        h.WalkSpeed = 0
        h.JumpPower = 0
        h:ChangeState(Enum.HumanoidStateType.PlatformStanding)

        task.delay(M.MessyEater.SlipSeconds, function()
            if h and h.Parent then
                h.WalkSpeed = originalWalk
                h.JumpPower = originalJump
                h:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
        peel:Destroy()
    end)

    Debris:AddItem(peel, M.MessyEater.PeelLifetimeSeconds)
end

------------------------------------------------------------------------------
-- F — KIBI DANGO
-- Heal yourself for 30, or if a Warden teammate is within 5 studs, heal
-- them for 40. Also cures any bleed on the target.
------------------------------------------------------------------------------
Momotaro.Abilities.KibiDango = function(player, params)
    if not AbilityModule.isOffCooldown(player, "KibiDango") then return end
    local rootPart = getRootPart(player)
    local humanoid = getHumanoid(player)
    if not rootPart or not humanoid then return end

    AbilityModule.startCooldown(player, "KibiDango", M.KibiDango.CooldownSeconds)

    -- Look for the nearest living Warden teammate inside the range.
    local nearestTeammate, nearestHumanoid, nearestDistance = nil, nil, math.huge
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and isWarden(other) then
            local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
            local otherHumanoid = getHumanoid(other)
            if otherRoot and otherHumanoid and otherHumanoid.Health > 0 then
                local distance = (otherRoot.Position - rootPart.Position).Magnitude
                if distance <= M.KibiDango.TeammateRangeStuds and distance < nearestDistance then
                    nearestTeammate, nearestHumanoid, nearestDistance = other, otherHumanoid, distance
                end
            end
        end
    end

    if nearestHumanoid then
        nearestHumanoid.Health = math.min(
            nearestHumanoid.MaxHealth,
            nearestHumanoid.Health + M.KibiDango.TeammateHeal
        )
        if M.KibiDango.CuresBleed then BleedService:Cure(nearestHumanoid) end
        local pos = nearestTeammate.Character
            and nearestTeammate.Character:FindFirstChild("HumanoidRootPart")
            and nearestTeammate.Character.HumanoidRootPart.Position
        EffectsService:Play("MomotaroKibiDangoTeammate", pos)
    else
        humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + M.KibiDango.SelfHeal)
        if M.KibiDango.CuresBleed then BleedService:Cure(humanoid) end
        EffectsService:Play("MomotaroKibiDangoSelf", rootPart.Position)
    end
end

------------------------------------------------------------------------------
-- PASSIVE — BIRD'S EYE VIEW
-- Kijiro the pheasant follows Momotaro at all times. Every 45 seconds he
-- highlights all Yokai for 6.5 seconds.
------------------------------------------------------------------------------
function Momotaro:StartPassives(player)
    local rootPart = getRootPart(player)
    local character = player.Character
    if not rootPart or not character then return end

    -- 1. Spawn Kijiro near Momotaro and have him track Momotaro's position
    --    every Heartbeat (parented to the character so he dies with him).
    local kijiroSpawnPos = rootPart.Position + M.BirdsEyeView.FollowOffset
    local kijiro = spawnCompanion(
        "Kijiro",
        M.BirdsEyeView.KijiroAssetId,
        Color3.fromRGB(180, 60, 60),
        Vector3.new(1, 0.7, 1.5),
        kijiroSpawnPos,
        character
    )

    local kijiroAnchor = companionAnchor(kijiro)
    if kijiroAnchor then
        kijiroAnchor.Anchored = true
        kijiroAnchor.CanCollide = false
    end

    task.spawn(function()
        while kijiro.Parent and player:GetAttribute("Character") == Types.Character.Momotaro do
            local currentRoot = getRootPart(player)
            if currentRoot and kijiroAnchor then
                local target = currentRoot.CFrame * CFrame.new(M.BirdsEyeView.FollowOffset)
                if kijiro:IsA("Model") then
                    kijiro:PivotTo(target)
                else
                    kijiroAnchor.CFrame = target
                end
            end
            RunService.Heartbeat:Wait()
        end
        if kijiro and kijiro.Parent then kijiro:Destroy() end
    end)

    -- 2. The actual Bird's Eye View: highlight Yokai every IntervalSeconds.
    task.spawn(function()
        while player:GetAttribute("Character") == Types.Character.Momotaro do
            task.wait(M.BirdsEyeView.IntervalSeconds)
            if player:GetAttribute("Character") ~= Types.Character.Momotaro then break end

            EffectsService:Play("MomotaroBirdsEyeView", nil)

            -- TODO: highlights are currently visible to all players, not just
            -- Momotaro. To make them Momotaro-only, swap this for a remote
            -- that tells Momotaro's client to create the highlight locally.
            local highlights = {}
            for _, other in ipairs(Players:GetPlayers()) do
                if isYokai(other) and other.Character then
                    local h = Instance.new("Highlight")
                    h.FillColor = Color3.fromRGB(255, 0, 0)
                    h.OutlineColor = Color3.fromRGB(255, 150, 150)
                    h.Adornee = other.Character
                    h.Parent = other.Character
                    table.insert(highlights, h)
                end
            end

            task.wait(M.BirdsEyeView.HighlightSeconds)
            for _, h in ipairs(highlights) do
                if h.Parent then h:Destroy() end
            end
        end
    end)
end

return Momotaro
