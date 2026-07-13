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

-- Sits a spawned thing (Model or Part) flat on the floor: its LOWEST point rests on
-- groundY, centered over (x, z). Props like the banana peel need this because our rigs
-- are ~2.4x size, so "drop it at the player's feet" actually lands around thigh height.
local function groundOnFloor(thing, x, z, groundY)
    if thing:IsA("Model") then
        if not thing.PrimaryPart then
            thing.PrimaryPart = thing:FindFirstChildWhichIsA("BasePart")
        end
        local boxCF, boxSize = thing:GetBoundingBox()
        local newCenter = Vector3.new(x, groundY + boxSize.Y / 2, z)
        thing:PivotTo(thing:GetPivot() + (newCenter - boxCF.Position))   -- slide it, keep its facing
    elseif thing:IsA("BasePart") then
        thing.Position = Vector3.new(x, groundY + thing.Size.Y / 2, z)
    end
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

    -- Tell every client to play his katana swing on his body (his katana is on his LEFT arm).
    local swingRemote = ReplicatedStorage.Remotes:FindFirstChild("WeaponSwing")
    if swingRemote then swingRemote:FireAllClients(player, "MomotaroKatana") end

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

    -- The two dogs stand guard as a PAIR at Momotaro's feet. This spot is the
    -- "guard post": we measure how far away Yokai are from here, and both dogs
    -- sit around it. (They're both just the LOOK of this one ability -- there's
    -- a single shared bark/slow/HP behavior, not one per dog.)
    -- Drop to foot level, and push the post a few studs IN FRONT of Momotaro so
    -- the dogs aren't standing inside his back.
    local guardCenter = rootPart.Position
        - Vector3.new(0, 2, 0)
        + rootPart.CFrame.LookVector * M.GuardDog.DeployForwardStuds

    -- Spawn every dog model the daughter built, lined up left-to-right and
    -- centered on the guard post. If none of the models are found in
    -- ReplicatedStorage.Companions, spawnCompanion drops a brown placeholder so
    -- the ability still works.
    local dogs = {}
    local names = M.GuardDog.DogModelNames
    for i, dogName in ipairs(names) do
        local sideStep = (i - (#names + 1) / 2) * M.GuardDog.DogSpacingStuds
        local dogPos = guardCenter + rootPart.CFrame.RightVector * sideStep
        local dog = spawnCompanion(
            dogName,
            M.GuardDog.InutaAssetId,
            Color3.fromRGB(120, 80, 40),     -- brown placeholder fallback
            Vector3.new(3, 2, 4),
            dogPos,
            workspace
        )
        -- Face each dog the way Momotaro is looking, so they guard "outward". If
        -- a dog ends up facing the wrong way, its model's built-in front differs
        -- from ours -- spin it in Roblox Studio, or tell me and I'll add a facing
        -- tweak like the Hawk's.
        if dog:IsA("Model") and dog.PrimaryPart then
            dog:PivotTo(CFrame.lookAt(dogPos, dogPos + rootPart.CFrame.LookVector))
        end
        -- Freeze the dog in place. There's no walk animation yet, so anchoring
        -- every part keeps it standing at its post instead of collapsing under
        -- gravity or drifting.
        for _, part in ipairs(dog:GetDescendants()) do
            if part:IsA("BasePart") then part.Anchored = true end
        end
        if dog:IsA("BasePart") then dog.Anchored = true end
        table.insert(dogs, dog)
    end

    EffectsService:Play("MomotaroInutaDeploy", guardCenter)

    -- The pair shares ONE pool of HP (the spec's 40). Nothing damages the dogs
    -- yet, but when something does, subtract from here -- at 0 they leave early.
    local health = M.GuardDog.InutaHealth

    local startTime = tick()
    local slowedYokai = {}    -- {humanoid = originalWalkSpeed}
    local active = true

    local function despawn()
        active = false
        for yokaiHumanoid, originalSpeed in pairs(slowedYokai) do
            if yokaiHumanoid and yokaiHumanoid.Parent then
                yokaiHumanoid.WalkSpeed = originalSpeed
            end
        end
        for _, dog in ipairs(dogs) do
            if dog and dog.Parent then dog:Destroy() end
        end
    end

    -- Which Yokai humanoids are within range of the guard post right now?
    local function yokaiInRange()
        local found = {}
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if isYokai(otherPlayer) then
                local otherRoot = otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart")
                if otherRoot and (otherRoot.Position - guardCenter).Magnitude <= M.GuardDog.DetectRangeStuds then
                    local h = getHumanoid(otherPlayer)
                    if h then found[h] = true end
                end
            end
        end
        return found
    end

    -- Detection loop: every Heartbeat, slow Yokai in range (and restore anyone
    -- who walked back out). Ends the whole pair when time's up or HP hits 0.
    local detectionConn
    detectionConn = RunService.Heartbeat:Connect(function()
        if not active then
            if detectionConn then detectionConn:Disconnect() end
            return
        end
        local elapsed = tick() - startTime
        if elapsed >= M.GuardDog.InutaLifetimeSeconds or health <= 0 then
            if detectionConn then detectionConn:Disconnect() end
            despawn()
            return
        end

        local inRange = yokaiInRange()
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

    -- BITE loop: once per BarkIntervalSeconds, the dogs bite every Yokai in range
    -- for a little damage. Kept on a STEADY beat so the damage rate stays balanced
    -- (spec: 1-5 damage every second). No sound here -- the barking is its own loop.
    task.spawn(function()
        while active do
            task.wait(M.GuardDog.BarkIntervalSeconds)
            if not active then break end
            for h in pairs(yokaiInRange()) do
                local biteDamage = math.random(M.GuardDog.MinDamage, M.GuardDog.MaxDamage)
                h:TakeDamage(biteDamage)
            end
        end
    end)

    -- BARK-SOUND loop: while any Yokai is near, the dogs bark on a loose, RANDOM
    -- rhythm from a RANDOM one of the two dogs -- so it sounds like two real dogs,
    -- not one metronome. Purely audio; the biting above is what actually hurts.
    task.spawn(function()
        while active do
            -- Wait a random gap so the barks aren't a perfect beat.
            local gap = M.GuardDog.BarkGapMin
                + math.random() * (M.GuardDog.BarkGapMax - M.GuardDog.BarkGapMin)
            task.wait(gap)
            if not active then break end
            -- Only bark if there's actually a Yokai in range to bark at.
            if next(yokaiInRange()) then
                EffectsService:Play("MomotaroInutaBark", guardCenter)
                local dog = dogs[math.random(1, #dogs)]   -- a random one of the dogs
                local soundRemote = ReplicatedStorage.Remotes:FindFirstChild("PlaySound")
                if dog and soundRemote then
                    soundRemote:FireAllClients(companionAnchor(dog), M.GuardDog.BarkSoundId, M.GuardDog.BarkVolume)
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

    -- The drop spot sits a few studs IN FRONT of Momotaro. Spawning at his own position
    -- hid Saru inside his legs (and the collision shoved Momotaro upward).
    local dropSpot = rootPart.Position
        + rootPart.CFrame.LookVector * M.MessyEater.SaruForwardStuds

    -- Find the floor under the drop spot (raycast straight down). Our rigs are ~2.4x size,
    -- so the HumanoidRootPart sits high off the ground -- without this Saru and the peel
    -- would float at thigh height. (Ignore Momotaro himself so the ray hits the ground.)
    local groundParams = RaycastParams.new()
    groundParams.FilterType = Enum.RaycastFilterType.Exclude
    groundParams.FilterDescendantsInstances = { player.Character }
    local groundHit = workspace:Raycast(dropSpot, Vector3.new(0, -50, 0), groundParams)
    local groundY = groundHit and groundHit.Position.Y or (rootPart.Position.Y - 3)

    local saru = spawnCompanion(
        "Saru",
        M.MessyEater.SaruAssetId,
        Color3.fromRGB(240, 220, 80),     -- yellow placeholder fallback
        Vector3.new(2, 2, 2),
        dropSpot,
        workspace
    )
    -- Saru is a brief visual -- never let his body shove players around.
    for _, part in ipairs(saru:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    if saru:IsA("BasePart") then saru.CanCollide = false end
    -- Grow the kids' monkey so he reads next to our ~12-stud rigs. Scale BEFORE
    -- grounding so he still ends up standing flat on the floor.
    local saruScale = M.MessyEater.SaruScale
    if saruScale and saruScale ~= 1 then
        if saru:IsA("Model") then
            saru:ScaleTo(saruScale)
        elseif saru:IsA("BasePart") then
            saru.Size = saru.Size * saruScale
        end
    end
    groundOnFloor(saru, dropSpot.X, dropSpot.Z, groundY)
    EffectsService:Play("MomotaroSaruEat", saru:GetPivot().Position)

    task.wait(M.MessyEater.SaruEatSeconds)
    if saru and saru.Parent then saru:Destroy() end

    -- The VISIBLE peel: the real banana-peel mesh if we can get it, else a yellow block.
    -- It's purely a LOOK -- anchored + no-collide -- resting flat on the floor. (Same 3-tier
    -- loader the companions use: a ReplicatedStorage.Companions model first, then the Creator
    -- Store asset, then the fallback block.)
    local peelVisual = spawnCompanion(
        "BananaPeel",
        M.MessyEater.BananaPeelAssetId,
        Color3.fromRGB(240, 220, 80),
        Vector3.new(2, 0.3, 2),
        Vector3.new(dropSpot.X, groundY, dropSpot.Z),
        workspace
    )
    for _, part in ipairs(peelVisual:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
        end
    end
    if peelVisual:IsA("BasePart") then
        peelVisual.Anchored = true
        peelVisual.CanCollide = false
    end
    -- Grow it so it reads in the grass (the mesh is small next to our ~2.4x world). Do this
    -- BEFORE grounding, since scaling changes its size and we want it sitting flat afterward.
    local scale = M.MessyEater.BananaPeelScale
    if scale and scale ~= 1 then
        if peelVisual:IsA("Model") then
            peelVisual:ScaleTo(scale)
        elseif peelVisual:IsA("BasePart") then
            peelVisual.Size = peelVisual.Size * scale
        end
    end
    groundOnFloor(peelVisual, dropSpot.X, dropSpot.Z, groundY)

    -- The hidden TRIGGER PAD: an invisible flat part on the floor that does the actual
    -- "step on it" detection. Detecting here (not on the fancy mesh) keeps the slip reliable
    -- no matter what shape the peel model is.
    local pad = Instance.new("Part")
    pad.Name = "BananaPeelTrigger"
    pad.Size = M.MessyEater.TriggerPadSize
    pad.Anchored = true
    pad.CanCollide = false
    pad.Transparency = 1
    pad.Position = Vector3.new(dropSpot.X, groundY + pad.Size.Y / 2, dropSpot.Z)
    pad.Parent = workspace

    EffectsService:Play("MomotaroBananaDrop", pad.Position)

    -- Remove BOTH the peel and its pad together (when someone slips OR when time's up).
    local function cleanup()
        if peelVisual and peelVisual.Parent then peelVisual:Destroy() end
        if pad and pad.Parent then pad:Destroy() end
    end

    local triggered = false
    pad.Touched:Connect(function(hit)
        if triggered then return end
        local model = hit:FindFirstAncestorOfClass("Model")
        if not model then return end
        local victim = Players:GetPlayerFromCharacter(model)
        if not victim or not isYokai(victim) then return end
        local h = getHumanoid(victim)
        if not h then return end
        triggered = true

        EffectsService:Play("MomotaroBananaSlip", pad.Position)

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
        cleanup()
    end)

    -- Auto-remove after its lifetime if nobody slipped.
    task.delay(M.MessyEater.PeelLifetimeSeconds, cleanup)
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

    -- 1. Spawn Momotaro's Hawk (Kijiro) beside him. The "Hawk" model in ReplicatedStorage.Companions
    --    carries its OWN behavior script (flaps + rides beside a target + cancels the baked flight
    --    circle), so we just clone it and hand it the character to follow via a "FollowTarget" value.
    --    We deliberately do NOT move it from here -- two controllers would fight every frame. It's
    --    parented under the character so it's cleaned up automatically when Momotaro despawns.
    --    (Shoulder offset / facing are tuned at the top of the Hawk's own script, not here.)
    local companions = ReplicatedStorage:FindFirstChild("Companions")
    local hawkTemplate = companions and companions:FindFirstChild("Hawk")
    if hawkTemplate then
        local hawk = hawkTemplate:Clone()
        local follow = Instance.new("ObjectValue")
        follow.Name = "FollowTarget"
        follow.Value = character
        follow.Parent = hawk
        -- Parent to Workspace, NOT under the character. An ANCHORED part living inside the character
        -- model stops the Humanoid from jumping -- that's why only Momotaro (the one with the Hawk)
        -- couldn't jump. The client follower finds the bird by its tag wherever it lives, so this is
        -- purely about keeping the anchored bird out of his rig.
        hawk.Parent = workspace

        -- Since it's no longer a child of the character, clean it up ourselves when he dies or the
        -- round swaps his character out (otherwise dead Hawks would pile up in Workspace).
        local function cleanupHawk()
            if hawk then hawk:Destroy() hawk = nil end
        end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.Died:Connect(cleanupHawk) end
        character.AncestryChanged:Connect(function()
            if not character:IsDescendantOf(game) then cleanupHawk() end
        end)
    else
        warn("[Momotaro] No 'Hawk' model in ReplicatedStorage.Companions -- skipping companion bird.")
    end

    -- 2. The actual Bird's Eye View: highlight Yokai every IntervalSeconds.
    task.spawn(function()
        while player:GetAttribute("Character") == Types.Character.Momotaro do
            task.wait(M.BirdsEyeView.IntervalSeconds)
            if player:GetAttribute("Character") ~= Types.Character.Momotaro then break end

            EffectsService:Play("MomotaroBirdsEyeView", nil)

            -- Reveal the Yokai to MOMOTARO ONLY. We send a private message to his
            -- client for each Yokai, and his client draws the red glow locally (see
            -- HighlightReveal.client.lua). If the server drew the glow, everyone --
            -- including the Yokai -- would see it, which would give the reveal away.
            local showHighlight = ReplicatedStorage.Remotes:FindFirstChild("ShowHighlight")
            if showHighlight then
                for _, other in ipairs(Players:GetPlayers()) do
                    if isYokai(other) and other.Character then
                        showHighlight:FireClient(player, other.Character, {
                            Fill = Color3.fromRGB(255, 0, 0),
                            Outline = Color3.fromRGB(255, 150, 150),
                            Seconds = M.BirdsEyeView.HighlightSeconds,
                        })
                    end
                end
            end

            -- Wait out the reveal window before the next scan, so the timing (a
            -- brief peek every so often) stays the same as before.
            task.wait(M.BirdsEyeView.HighlightSeconds)
        end
    end)
end

return Momotaro
