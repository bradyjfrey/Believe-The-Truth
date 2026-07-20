-- Rokurokubi.lua
-- Rokurokubi has four inputs: Neck Wrap (Q), Bite (left click), Disguise (R),
-- and Strangle (Q while disguised — same key as Neck Wrap, just routed based
-- on whether she's currently disguised).
--
-- The Disguise ability needs a target Warden — the client sends that via the
-- "TargetPlayer" key in params. See DisguisePickerUI.client.lua.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local AbilityModule = require(ReplicatedStorage.Shared.AbilityModule)
local Types = require(ReplicatedStorage.Shared.Types)
local EffectsService = require(ServerScriptService.Services.EffectsService)
local BleedService = require(ServerScriptService.Services.BleedService)
local DisguiseService = require(ServerScriptService.Services.DisguiseService)

local Rokurokubi = {}
Rokurokubi.Abilities = {}

local R = Constants.Rokurokubi

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

-- Find the closest living Warden within `maxRange` of `rootPart`.
local function findNearestWarden(rootPart, maxRange)
    local nearest, distance = nil, math.huge
    for _, other in ipairs(Players:GetPlayers()) do
        if isWarden(other) then
            local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
            local otherHumanoid = getHumanoid(other)
            if otherRoot and otherHumanoid and otherHumanoid.Health > 0 then
                local d = (otherRoot.Position - rootPart.Position).Magnitude
                if d <= maxRange and d < distance then
                    nearest, distance = other, d
                end
            end
        end
    end
    return nearest
end

------------------------------------------------------------------------------
-- Wrap state (one Rokurokubi can wrap one Warden at a time)
------------------------------------------------------------------------------

-- activeWraps[attackerPlayer] = victimPlayer
local activeWraps = {}
-- mashPresses[victimUserId] = current count of mash presses
local mashPresses = {}

-- Called from the client when the wrapped player mashes their key.
function Rokurokubi.RegisterMash(victim)
    if not victim or not victim:GetAttribute("Wrapped") then return end
    mashPresses[victim.UserId] = (mashPresses[victim.UserId] or 0) + 1
end

-- Interrupt anything she's currently holding — Momotaro's Katana calls this
-- when it hits her, to free a wrap victim and end any in-progress Strangle.
function Rokurokubi.InterruptHolds(rokurokubiPlayer)
    local victim = activeWraps[rokurokubiPlayer]
    if victim then
        -- Jump the mash count to the escape threshold so the wrap loop ends.
        mashPresses[victim.UserId] = R.NeckWrap.EscapePresses
    end
    -- Also clear any active Strangle (the choke loop checks this attribute).
    for _, p in ipairs(Players:GetPlayers()) do
        if p:GetAttribute("BeingStrangled") then
            p:SetAttribute("BeingStrangled", nil)
        end
    end
end

------------------------------------------------------------------------------
-- Q — NECK WRAP (or STRANGLE if disguised)
------------------------------------------------------------------------------
Rokurokubi.Abilities.NeckWrap = function(attacker, params)
    -- While disguised, Q does Strangle instead of Neck Wrap.
    if DisguiseService:IsDisguised(attacker) then
        return Rokurokubi.Abilities.Strangle(attacker, params)
    end

    if not AbilityModule.isOffCooldown(attacker, "NeckWrap") then return end
    local attackerRoot = getRootPart(attacker)
    if not attackerRoot then return end

    AbilityModule.startCooldown(attacker, "NeckWrap", R.NeckWrap.CooldownSeconds)

    EffectsService:Play("RokurokubiNeckWrapWindup", attackerRoot.Position)
    task.wait(R.NeckWrap.WindupSeconds)
    if not attacker.Character then return end

    local victim = findNearestWarden(attackerRoot, R.NeckWrap.RangeStuds)
    if not victim then return end
    local victimHumanoid = getHumanoid(victim)
    local victimRoot = getRootPart(victim)
    if not victimHumanoid or not victimRoot then return end

    activeWraps[attacker] = victim
    mashPresses[victim.UserId] = 0
    victim:SetAttribute("Wrapped", true)
    EffectsService:Play("RokurokubiNeckWrapHit", victimRoot.Position)

    -- Freeze the victim.
    local originalWalk = victimHumanoid.WalkSpeed
    local originalJump = victimHumanoid.JumpPower
    victimHumanoid.WalkSpeed = 0
    victimHumanoid.JumpPower = 0

    local wrapStart = tick()
    local damageAccumulator = 0
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        local elapsed = tick() - wrapStart
        local stillValid = activeWraps[attacker] == victim
                           and victimHumanoid.Health > 0
                           and elapsed < R.NeckWrap.MaxWrapSeconds
                           and (mashPresses[victim.UserId] or 0) < R.NeckWrap.EscapePresses

        if not stillValid then
            activeWraps[attacker] = nil
            mashPresses[victim.UserId] = nil
            victim:SetAttribute("Wrapped", nil)
            if victimHumanoid and victimHumanoid.Parent then
                victimHumanoid.WalkSpeed = originalWalk
                victimHumanoid.JumpPower = originalJump
            end
            if conn then conn:Disconnect() end
            return
        end

        damageAccumulator = damageAccumulator + R.NeckWrap.DamagePerSecond * dt
        if damageAccumulator >= 1 then
            local whole = math.floor(damageAccumulator)
            victimHumanoid:TakeDamage(whole)
            damageAccumulator = damageAccumulator - whole
        end
    end)
end

------------------------------------------------------------------------------
-- M1 — BITE
-- Up-close melee. Applies bleed. Breaks disguise.
------------------------------------------------------------------------------
Rokurokubi.Abilities.Bite = function(attacker, params)
    if not AbilityModule.isOffCooldown(attacker, "Bite") then return end
    local attackerRoot = getRootPart(attacker)
    if not attackerRoot then return end

    AbilityModule.startCooldown(attacker, "Bite", R.Bite.CooldownSeconds)
    task.wait(R.Bite.WindupSeconds)
    if not attacker.Character then return end

    local victim = findNearestWarden(attackerRoot, R.Bite.RangeStuds)
    if not victim then return end
    local victimHumanoid = getHumanoid(victim)
    local victimRoot = getRootPart(victim)
    if not victimHumanoid or not victimRoot then return end

    EffectsService:Play("RokurokubiBite", victimRoot.Position)

    -- Per spec: Bite always breaks the disguise.
    if DisguiseService:IsDisguised(attacker) then
        DisguiseService:Drop(attacker)
    end

    BleedService:Apply(
        victimHumanoid,
        "RokurokubiBite",
        R.Bite.BleedDamagePerSecond,
        R.Bite.BleedDurationSeconds,
        R.Bite.MaxBleedStacks,
        R.Bite.RefreshOnReapply
    )
end

------------------------------------------------------------------------------
-- R — DISGUISE
-- The client opens a picker UI and sends back the chosen Warden. After a
-- 5-second charge-up (during which Rokurokubi is frozen), her body and name
-- are swapped to look like the target. Lasts 19 seconds.
------------------------------------------------------------------------------
Rokurokubi.Abilities.Disguise = function(attacker, params)
    -- If she's already disguised, pressing R again cancels it early.
    if DisguiseService:IsDisguised(attacker) then
        DisguiseService:Drop(attacker)
        return
    end

    if not AbilityModule.isOffCooldown(attacker, "Disguise") then return end

    local target = params.TargetPlayer
    if typeof(target) ~= "Instance" or not target:IsA("Player") then return end
    if target:GetAttribute("Team") ~= Types.Team.Warden then return end

    local attackerHumanoid = getHumanoid(attacker)
    local attackerRoot = getRootPart(attacker)
    if not attackerHumanoid or not attackerRoot then return end

    -- Cooldown starts now and includes the disguise duration. So you can't
    -- spam disguise back-to-back; you need to wait the full 19s + 20s.
    AbilityModule.startCooldown(attacker, "Disguise", R.Disguise.CooldownSeconds + R.Disguise.DurationSeconds)

    EffectsService:Play("RokurokubiDisguiseChargeUp", attackerRoot.Position)

    -- Freeze her during charge-up (per Brady's call).
    local originalWalk = attackerHumanoid.WalkSpeed
    local originalJump = attackerHumanoid.JumpPower
    attackerHumanoid.WalkSpeed = 0
    attackerHumanoid.JumpPower = 0

    task.wait(R.Disguise.ChargeUpSeconds)

    -- Restore her movement now that charge-up is done.
    if attackerHumanoid and attackerHumanoid.Parent then
        attackerHumanoid.WalkSpeed = originalWalk
        attackerHumanoid.JumpPower = originalJump
    end
    if not attackerHumanoid or attackerHumanoid.Health <= 0 then return end
    if not target.Parent then return end  -- target left the game

    local applied = DisguiseService:Apply(attacker, target)
    if not applied then return end
    EffectsService:Play("RokurokubiDisguiseApplied", attackerRoot.Position)

    -- Eye-glow tell: every few seconds, briefly outline her in red so a
    -- watchful Warden can spot her. Replace with a proper eyes-only glow
    -- when the art team's ready.
    task.spawn(function()
        while DisguiseService:IsDisguised(attacker) do
            task.wait(R.Disguise.EyeGlowIntervalSeconds)
            if not DisguiseService:IsDisguised(attacker) then break end
            local character = attacker.Character
            if character then
                local highlight = Instance.new("Highlight")
                highlight.FillTransparency = 1
                highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
                highlight.Adornee = character
                highlight.Parent = character
                local glowRoot = getRootPart(attacker)
                EffectsService:Play("RokurokubiEyeGlow", glowRoot and glowRoot.Position)
                task.wait(R.Disguise.EyeGlowDurationSeconds)
                if highlight.Parent then highlight:Destroy() end
            end
        end
    end)

    -- Duration timer — auto-drop after DurationSeconds.
    task.delay(R.Disguise.DurationSeconds, function()
        if DisguiseService:IsDisguised(attacker) then
            DisguiseService:Drop(attacker)
            local pos = getRootPart(attacker)
            EffectsService:Play("RokurokubiDisguiseEnded", pos and pos.Position)
        end
    end)
end

------------------------------------------------------------------------------
-- STRANGLE — fires from the same Q key when she's disguised.
------------------------------------------------------------------------------
Rokurokubi.Abilities.Strangle = function(attacker, params)
    if not DisguiseService:IsDisguised(attacker) then return end
    local attackerRoot = getRootPart(attacker)
    if not attackerRoot then return end

    local victim = findNearestWarden(attackerRoot, R.Strangle.RangeStuds)
    if not victim then return end
    local victimHumanoid = getHumanoid(victim)
    local victimRoot = getRootPart(victim)
    if not victimHumanoid or not victimRoot then return end

    -- Per spec, Strangle drops the disguise as soon as it starts.
    DisguiseService:Drop(attacker)
    EffectsService:Play("RokurokubiStrangle", victimRoot.Position)

    -- Freeze the victim for the choke duration.
    local originalWalk = victimHumanoid.WalkSpeed
    local originalJump = victimHumanoid.JumpPower
    victimHumanoid.WalkSpeed = 0
    victimHumanoid.JumpPower = 0
    victim:SetAttribute("BeingStrangled", true)

    for i = 1, R.Strangle.ChokeSeconds do
        task.wait(1)
        if not victim:GetAttribute("BeingStrangled") then break end
        if victimHumanoid.Health <= 0 then break end
        victimHumanoid:TakeDamage(R.Strangle.DamagePerSecond)
    end

    if victimHumanoid and victimHumanoid.Parent then
        victimHumanoid.WalkSpeed = originalWalk
        victimHumanoid.JumpPower = originalJump
    end
    victim:SetAttribute("BeingStrangled", nil)
end

------------------------------------------------------------------------------
-- PASSIVE — HIDDEN HUNGER
-- When she's within 40 studs of a Warden, that Warden hears a growl.
------------------------------------------------------------------------------
function Rokurokubi:StartPassives(player)
    -- Bootstrap calls this on EVERY spawn -- including the disguise model swaps,
    -- which would stack a second (third, fourth...) growl loop each time. One
    -- loop per player is plenty; the attribute flag makes extra calls harmless.
    if player:GetAttribute("HiddenHungerRunning") then return end
    player:SetAttribute("HiddenHungerRunning", true)

    task.spawn(function()
        while player:GetAttribute("Character") == Types.Character.Rokurokubi do
            task.wait(R.HiddenHunger.GrowlEverySeconds)
            if player:GetAttribute("Character") ~= Types.Character.Rokurokubi then break end
            local rootPart = getRootPart(player)
            if rootPart then
                -- Play ONE growl at her position if ANY Warden is close enough. The growl is a 3D
                -- sound, so distance falloff decides who actually hears it -- playing it once per
                -- nearby Warden would just stack identical growls on top of each other.
                for _, other in ipairs(Players:GetPlayers()) do
                    if isWarden(other) then
                        local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
                        if otherRoot and (otherRoot.Position - rootPart.Position).Magnitude <= R.HiddenHunger.AudibleRangeStuds then
                            EffectsService:Play("RokurokubiHiddenHungerGrowl", rootPart.Position)
                            break
                        end
                    end
                end
            end
        end
        player:SetAttribute("HiddenHungerRunning", nil)
    end)
end

return Rokurokubi
