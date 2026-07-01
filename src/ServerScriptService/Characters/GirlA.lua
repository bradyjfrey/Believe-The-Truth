-- GirlA.lua
-- Girl A has four inputs: Slash (left click), Breach of Privacy (Q), Stray
-- Blade (hold E then release), Incognito Mode (R). Her passive lets her
-- teleport between Hotspots while in Incognito Mode.
--
-- Stray Blade is a hold-and-release input. The client sends two events:
--   params.Phase = "Begin" when E is pressed (aim mode starts)
--   params.Phase = "End"   when E is released (cleaver throws)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local AbilityModule = require(ReplicatedStorage.Shared.AbilityModule)
local Types = require(ReplicatedStorage.Shared.Types)
local EffectsService = require(ServerScriptService.Services.EffectsService)
local BleedService = require(ServerScriptService.Services.BleedService)

local GirlA = {}
GirlA.Abilities = {}

local G = Constants.GirlA
local S = Constants.Speed

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function getHumanoid(player)
    local character = player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(player)
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isWarden(player) return player:GetAttribute("Team") == Types.Team.Warden end

-- Find Wardens in front of `attackerRoot` (used by Slash).
local function findWardensInFront(attackerRoot, forwardStuds, sideStuds)
    local hits = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if isWarden(p) then
            local r = getRootPart(p)
            if r then
                local relative = attackerRoot.CFrame:PointToObjectSpace(r.Position)
                if relative.Z < 0 and -relative.Z <= forwardStuds and math.abs(relative.X) <= sideStuds then
                    table.insert(hits, p)
                end
            end
        end
    end
    return hits
end

------------------------------------------------------------------------------
-- M1 — SLASH
-- Small lunge forward, hit any Wardens in the swing for 15 damage.
------------------------------------------------------------------------------
GirlA.Abilities.Slash = function(attacker, params)
    if not AbilityModule.isOffCooldown(attacker, "Slash") then return end
    local attackerRoot = getRootPart(attacker)
    if not attackerRoot then return end

    AbilityModule.startCooldown(attacker, "Slash", G.Slash.CooldownSeconds)
    -- Attach the slash to her weapon arm so it sits ON the hatchet and rides the swing (instead of
    -- sitting in her body -- her lunge below would otherwise dash her into a world-placed effect).
    -- TUNE these if it's off: the CFrame is a LOCAL offset from the Right Arm (0,-1.5,0 = down at
    -- the hand); add a rotation like * CFrame.Angles(0,0,math.rad(90)) if the arc faces sideways;
    -- Scale shrinks the whole effect.
    local rightArm = attacker.Character and attacker.Character:FindFirstChild("Right Arm")
    if rightArm then
        -- Where the slash sits, as an offset from her Right Arm. TUNE by watching, then re-test.
        -- POSITION (studs):
        --   SIDE : + right / - left
        --   DOWN : - toward the hand (arm is 2 tall, hand ~ -1)
        --   FWD  : - in FRONT of the blade (more negative = further out front)
        local SIDE, DOWN, FWD = 0, -1.5, -12
        -- ORIENTATION (degrees): spin the arc until it faces forward. Try values in steps of 90
        -- (0 / 90 / 180 / 270) on each axis until it lines up.
        local ROT_X, ROT_Y, ROT_Z = 240, 0, 90
        local offset = CFrame.new(SIDE, DOWN, FWD)
            * CFrame.Angles(math.rad(ROT_X), math.rad(ROT_Y), math.rad(ROT_Z))
        EffectsService:Play("GirlASlash", nil, {
            AttachTo = rightArm,
            CFrame   = offset,
            Scale    = 0.5,
        })
    else
        EffectsService:Play("GirlASlash", attackerRoot.Position)
    end

    -- Tell every client to play her two-handed hatchet swing on her body. (Server-side
    -- joint posing fights the default Animate script; the client does it in RenderStepped.)
    local swingRemote = ReplicatedStorage.Remotes:FindFirstChild("WeaponSwing")
    if swingRemote then swingRemote:FireAllClients(attacker, "GirlAHatchet") end

    -- Small forward lunge.
    local lookVector = attackerRoot.CFrame.LookVector
    attackerRoot.CFrame = attackerRoot.CFrame + lookVector * G.Slash.LungeStuds

    local hits = findWardensInFront(attackerRoot, G.Slash.RangeStuds, 4)
    for _, victim in ipairs(hits) do
        local h = getHumanoid(victim)
        local r = getRootPart(victim)
        if h and h.Health > 0 then
            h:TakeDamage(G.Slash.Damage)
            EffectsService:Play("GirlASlashHit", r and r.Position)
        end
    end
end

------------------------------------------------------------------------------
-- Q — BREACH OF PRIVACY
-- Pop-up on a random Warden's screen for 7 seconds. Closing it early = 25 dmg.
-- Girl A is slowed while the popup is up; the target is highlighted to her.
------------------------------------------------------------------------------
GirlA.Abilities.BreachOfPrivacy = function(attacker, params)
    if not AbilityModule.isOffCooldown(attacker, "BreachOfPrivacy") then return end
    AbilityModule.startCooldown(attacker, "BreachOfPrivacy", G.BreachOfPrivacy.CooldownSeconds)

    -- Truly random pick from living Wardens.
    local livingWardens = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if isWarden(p) then
            local h = getHumanoid(p)
            if h and h.Health > 0 then
                table.insert(livingWardens, p)
            end
        end
    end
    if #livingWardens == 0 then return end
    local target = livingWardens[math.random(1, #livingWardens)]

    -- Slow Girl A while popup is up.
    local attackerHumanoid = getHumanoid(attacker)
    local originalSpeed = attackerHumanoid and attackerHumanoid.WalkSpeed or S.GirlAWalk
    if attackerHumanoid then
        attackerHumanoid.WalkSpeed = originalSpeed * G.BreachOfPrivacy.SlowMultiplier
    end

    -- Highlight the target so Girl A can see them -- but ONLY on Girl A's screen.
    -- We send a private message to her client, which draws the glow locally (see
    -- HighlightReveal.client.lua). The glow lasts as long as the popup is up, so
    -- the client removes it on its own after PopupSeconds.
    local showHighlight = ReplicatedStorage.Remotes:FindFirstChild("ShowHighlight")
    if showHighlight and target.Character then
        showHighlight:FireClient(attacker, target.Character, {
            Fill = Color3.fromRGB(255, 100, 100),
            Outline = Color3.fromRGB(255, 0, 0),
            Seconds = G.BreachOfPrivacy.PopupSeconds,
        })
    end

    EffectsService:Play("GirlABreachPopup", nil, {Target = target})

    -- The popup UI is shown to the target on the client. The client fires
    -- BreachClose when closed early. We watch the attribute we set.
    target:SetAttribute("BreachPopupActive", true)
    local closedEarly = false
    local conn
    conn = target:GetAttributeChangedSignal("BreachPopupActive"):Connect(function()
        if not target:GetAttribute("BreachPopupActive") then
            closedEarly = true
            if conn then conn:Disconnect() end
        end
    end)

    task.wait(G.BreachOfPrivacy.PopupSeconds)
    if conn then conn:Disconnect() end

    if target:GetAttribute("BreachPopupActive") then
        -- Ran the full duration — auto-close, no damage.
        target:SetAttribute("BreachPopupActive", nil)
    elseif closedEarly then
        local h = getHumanoid(target)
        if h and h.Health > 0 then
            h:TakeDamage(G.BreachOfPrivacy.EarlyCloseDamage)
        end
    end

    if attackerHumanoid and attackerHumanoid.Parent then
        attackerHumanoid.WalkSpeed = originalSpeed
    end
end

------------------------------------------------------------------------------
-- E (hold) — STRAY BLADE
-- Hold E to aim (-25% movement). Release to throw the cleaver 30 studs forward
-- over 1 second. First Warden hit takes 35 damage and starts bleeding. The
-- cleaver returns to Girl A when the throw ends.
------------------------------------------------------------------------------
GirlA.Abilities.StrayBlade = function(attacker, params)
    local phase = params.Phase

    if phase == "Begin" then
        if not AbilityModule.isOffCooldown(attacker, "StrayBlade") then return end
        local attackerHumanoid = getHumanoid(attacker)
        if not attackerHumanoid then return end

        attacker:SetAttribute("StrayBladeAiming", true)
        attacker:SetAttribute("StrayBladeOriginalSpeed", attackerHumanoid.WalkSpeed)
        attackerHumanoid.WalkSpeed = attackerHumanoid.WalkSpeed * G.StrayBlade.AimSlowMultiplier
        local r = getRootPart(attacker)
        EffectsService:Play("GirlAStrayBladeAim", r and r.Position)

    elseif phase == "End" then
        if not attacker:GetAttribute("StrayBladeAiming") then return end
        attacker:SetAttribute("StrayBladeAiming", nil)

        local attackerHumanoid = getHumanoid(attacker)
        local originalSpeed = attacker:GetAttribute("StrayBladeOriginalSpeed")
        if attackerHumanoid and originalSpeed then
            attackerHumanoid.WalkSpeed = originalSpeed
        end
        attacker:SetAttribute("StrayBladeOriginalSpeed", nil)

        AbilityModule.startCooldown(attacker, "StrayBlade", G.StrayBlade.CooldownSeconds)

        local attackerRoot = getRootPart(attacker)
        if not attackerRoot then return end
        EffectsService:Play("GirlAStrayBladeThrow", attackerRoot.Position)

        -- Make the cleaver.
        local cleaver = Instance.new("Part")
        cleaver.Name = "Cleaver"
        cleaver.Size = Vector3.new(1.5, 0.2, 2)
        cleaver.Color = Color3.fromRGB(180, 180, 190)
        cleaver.Material = Enum.Material.Metal
        cleaver.CanCollide = false
        cleaver.Anchored = true
        cleaver.CFrame = attackerRoot.CFrame * CFrame.new(0, 0, -2)
        cleaver.Parent = workspace

        local lookVector = attackerRoot.CFrame.LookVector
        local startPos = cleaver.Position
        local startTime = tick()
        local done = false

        local conn
        conn = RunService.Heartbeat:Connect(function()
            if done then
                if conn then conn:Disconnect() end
                return
            end
            local elapsed = tick() - startTime
            local t = elapsed / G.StrayBlade.TravelSeconds
            if t >= 1 then
                -- Out of range — returns to Girl A.
                done = true
                if cleaver.Parent then cleaver:Destroy() end
                return
            end

            local newPos = startPos + lookVector * (G.StrayBlade.RangeStuds * t)
            cleaver.CFrame = CFrame.new(newPos, newPos + lookVector)

            -- Wall check: ray a short distance from old to new position.
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {cleaver, attacker.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            local rayResult = workspace:Raycast(startPos, lookVector * (G.StrayBlade.RangeStuds * t + 0.1), raycastParams)
            if rayResult then
                local hitModel = rayResult.Instance:FindFirstAncestorOfClass("Model")
                local hitPlayer = hitModel and Players:GetPlayerFromCharacter(hitModel)
                if not hitPlayer then
                    -- Solid object — stop and return to Girl A.
                    done = true
                    if cleaver.Parent then cleaver:Destroy() end
                    return
                end
            end

            -- Hit detection: any Warden within ~3 studs of the cleaver gets hit.
            for _, p in ipairs(Players:GetPlayers()) do
                if isWarden(p) then
                    local r = getRootPart(p)
                    local h = getHumanoid(p)
                    if r and h and h.Health > 0 and (r.Position - cleaver.Position).Magnitude <= 3 then
                        h:TakeDamage(G.StrayBlade.Damage)
                        BleedService:Apply(
                            h,
                            "GirlAStrayBlade",
                            G.StrayBlade.BleedDamagePerSecond,
                            G.StrayBlade.BleedDurationSeconds,
                            1,
                            true
                        )
                        EffectsService:Play("GirlAStrayBladeImpact", r.Position)
                        done = true
                        if cleaver.Parent then cleaver:Destroy() end
                        return
                    end
                end
            end
        end)
    end
end

------------------------------------------------------------------------------
-- R — INCOGNITO MODE
-- Invisible to all other players for 8 seconds. 1.3x her run speed. The 3
-- nearest Hotspots are highlighted to her. Press R again to end early.
-- Click a hotspot (handled by HotspotTeleport ability) to teleport there.
------------------------------------------------------------------------------
GirlA.Abilities.IncognitoMode = function(attacker, params)
    -- Toggle off if already on.
    if attacker:GetAttribute("Incognito") then
        attacker:SetAttribute("Incognito", nil)
        local h = getHumanoid(attacker)
        if h then h.WalkSpeed = S.GirlARun end
        local r = getRootPart(attacker)
        EffectsService:Play("GirlAIncognitoEnd", r and r.Position)
        return
    end

    if not AbilityModule.isOffCooldown(attacker, "IncognitoMode") then return end
    AbilityModule.startCooldown(attacker, "IncognitoMode", G.IncognitoMode.CooldownSeconds)

    attacker:SetAttribute("Incognito", true)
    local attackerHumanoid = getHumanoid(attacker)
    if attackerHumanoid then
        attackerHumanoid.WalkSpeed = S.GirlAIncognitoRun
    end
    local r = getRootPart(attacker)
    EffectsService:Play("GirlAIncognitoStart", r and r.Position)

    -- Incognito.client.lua watches the Incognito attribute and hides her.

    task.wait(G.IncognitoMode.DurationSeconds)

    if attacker:GetAttribute("Incognito") then
        attacker:SetAttribute("Incognito", nil)
        if attackerHumanoid and attackerHumanoid.Parent then
            attackerHumanoid.WalkSpeed = S.GirlARun
        end
        local endR = getRootPart(attacker)
        EffectsService:Play("GirlAIncognitoEnd", endR and endR.Position)
    end
end

------------------------------------------------------------------------------
-- HOTSPOT TELEPORT — Girl A clicks a Hotspot while in Incognito Mode.
-- The client sends the chosen hotspot Part as params.Hotspot.
------------------------------------------------------------------------------
GirlA.Abilities.HotspotTeleport = function(attacker, params)
    -- Per spec: only works during Incognito Mode.
    if not attacker:GetAttribute("Incognito") then return end
    local hotspot = params.Hotspot
    if typeof(hotspot) ~= "Instance" or not hotspot:IsDescendantOf(workspace) then return end

    local attackerRoot = getRootPart(attacker)
    if not attackerRoot then return end

    -- Teleport (offset up so she doesn't clip into the floor).
    local hotspotPos = hotspot:IsA("BasePart") and hotspot.Position or hotspot:GetPivot().Position
    attackerRoot.CFrame = CFrame.new(hotspotPos + Vector3.new(0, 5, 0))
    EffectsService:Play("GirlAHotspotTeleport", hotspotPos)

    -- Teleport ends Incognito.
    attacker:SetAttribute("Incognito", nil)
    local h = getHumanoid(attacker)
    if h then h.WalkSpeed = S.GirlARun end
end

------------------------------------------------------------------------------
-- PASSIVE — AUTO CONNECT
-- Hotspots get spawned by RoundService at round start. The teleport itself
-- only fires during Incognito Mode (per spec wording). So this passive has
-- nothing to spawn here — it just exists conceptually.
------------------------------------------------------------------------------
function GirlA:StartPassives(player)
    -- Intentionally nothing — passive is "Hotspots exist and can be teleported
    -- to via HotspotTeleport during Incognito Mode."
end

return GirlA
