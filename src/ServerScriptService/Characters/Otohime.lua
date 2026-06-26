-- Otohime.lua
-- Otohime is the 2nd survivor (Warden) -- a support / medic. Two abilities:
--   * Healing Pulse (E) — pulses out and heals nearby ALLIES (+20 HP), but NOT herself.
--                         Effect template: ReplicatedStorage.Effects.OtohimeHealingPulse.
--   * Dark Moon     (Q) — fires a slow, dramatic moon that drifts forward and damages the first
--                         Yokai it touches (inspired by Elden Ring's Ranni's Dark Moon).
--                         Effect template: ReplicatedStorage.Effects.OtohimeDarkMoon.
-- Numbers live in Constants.Otohime (they weren't in the spec doc -- sensible starting values).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local AbilityModule = require(ReplicatedStorage.Shared.AbilityModule)
local Types = require(ReplicatedStorage.Shared.Types)
local EffectsService = require(ServerScriptService.Services.EffectsService)

local Otohime = {}
Otohime.Abilities = {}

local O = Constants.Otohime

------------------------------------------------------------------------------
-- Little helpers
------------------------------------------------------------------------------

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

------------------------------------------------------------------------------
-- E — HEALING PULSE
-- Pulses out from Otohime and heals every OTHER Warden within range (+20 HP).
-- She does NOT heal herself -- she's a team medic.
------------------------------------------------------------------------------
Otohime.Abilities.HealingPulse = function(player, params)
    if not AbilityModule.isOffCooldown(player, "HealingPulse") then return end
    local root = getRootPart(player)
    if not root then return end

    AbilityModule.startCooldown(player, "HealingPulse", O.HealingPulse.CooldownSeconds)
    -- Visual sits in FRONT of her (-Z is forward); the heal radius below still measures from her.
    EffectsService:Play("OtohimeHealingPulse", nil, {
        CFrame = root.CFrame * CFrame.new(0, 0, -O.HealingPulse.ForwardStuds),
    })

    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and isWarden(other) then
            local h = getHumanoid(other)
            local r = getRootPart(other)
            if h and r and h.Health > 0
                and (r.Position - root.Position).Magnitude <= O.HealingPulse.RadiusStuds then
                h.Health = math.min(h.MaxHealth, h.Health + O.HealingPulse.HealAmount)
            end
        end
    end
end

------------------------------------------------------------------------------
-- Q — DARK MOON
-- Conjures a slow moon in front of her that drifts forward. The first Yokai it
-- drifts into takes damage, then the moon fades. (Ranni's Dark Moon vibe.)
------------------------------------------------------------------------------
Otohime.Abilities.DarkMoon = function(player, params)
    if not AbilityModule.isOffCooldown(player, "DarkMoon") then return end
    local root = getRootPart(player)
    if not root then return end

    AbilityModule.startCooldown(player, "DarkMoon", O.DarkMoon.CooldownSeconds)

    local dm = O.DarkMoon
    local lookVector = root.CFrame.LookVector

    -- An invisible anchored "mover" part. The Dark Moon visual rides on it (welded), and we slide
    -- the mover forward each frame; the visual follows.
    local moon = Instance.new("Part")
    moon.Name = "DarkMoon"
    moon.Size = Vector3.new(1, 1, 1)
    moon.Transparency = 1
    moon.CanCollide = false
    moon.Anchored = true
    moon.CFrame = root.CFrame * CFrame.new(0, dm.StartUpStuds, -dm.StartForwardStuds)
    moon.Parent = workspace

    EffectsService:Play("OtohimeDarkMoon", nil, {
        AttachTo = moon,
        Parent = moon,                 -- so destroying the mover cleans up the visual too
        Scale = dm.MoonScale,
        Lifetime = dm.TravelSeconds + 1,
    })

    local startPos = moon.Position
    local startTime = tick()
    local done = false
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if done then conn:Disconnect() return end

        local t = (tick() - startTime) / dm.TravelSeconds
        if t >= 1 then
            -- Drifted its full range without hitting anyone -- fade out.
            done = true
            if moon.Parent then moon:Destroy() end
            return
        end

        local newPos = startPos + lookVector * (dm.RangeStuds * t)
        moon.CFrame = CFrame.new(newPos, newPos + lookVector)

        -- First Yokai within HitRadius takes the hit, then the moon is spent.
        for _, p in ipairs(Players:GetPlayers()) do
            if isYokai(p) then
                local r = getRootPart(p)
                local h = getHumanoid(p)
                if r and h and h.Health > 0 and (r.Position - moon.Position).Magnitude <= dm.HitRadius then
                    h:TakeDamage(dm.Damage)
                    done = true
                    if moon.Parent then moon:Destroy() end
                    return
                end
            end
        end
    end)
end

------------------------------------------------------------------------------
-- PASSIVE — none. Bootstrap calls this; left as an extension point.
------------------------------------------------------------------------------
function Otohime:StartPassives(player)
    -- No passive yet.
end

return Otohime
