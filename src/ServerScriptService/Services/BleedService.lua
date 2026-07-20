-- BleedService.lua
-- One place for any "bleeding" damage-over-time effect. Rokurokubi's Bite
-- and Girl A's Stray Blade both apply bleed, and Momotaro's Kibi Dango
-- cures it. Having one service means:
--   * One place to tune bleed tick speed
--   * Kibi Dango clears ALL bleed sources with one call
--   * Adding a new bleeding character later means no new code
--
-- How it works: every second, every active bleed source ticks damage onto
-- the victim's Humanoid. Sources expire after their duration.

local RunService = game:GetService("RunService")

local BleedService = {}

-- bleeds[humanoid][sourceKey] = {endTime = tick(), damagePerSecond = number, sourceName = string}
local bleeds = {}

local function countSources(humanoid, sourceName)
    local count = 0
    local sources = bleeds[humanoid]
    if not sources then return 0 end
    for _, info in pairs(sources) do
        if info.sourceName == sourceName then count = count + 1 end
    end
    return count
end

-- Apply a bleed to a humanoid. If `refresh` is true and a bleed from the
-- same source is already active, the timer resets instead of stacking.
function BleedService:Apply(humanoid, sourceName, damagePerSecond, durationSeconds, maxStacks, refresh)
    if not humanoid or not humanoid.Parent then return end
    bleeds[humanoid] = bleeds[humanoid] or {}
    local sources = bleeds[humanoid]

    local stacksOfThisSource = countSources(humanoid, sourceName)

    if refresh and stacksOfThisSource > 0 then
        -- Bump the timer on every existing stack from this source.
        for _, info in pairs(sources) do
            if info.sourceName == sourceName then
                info.endTime = tick() + durationSeconds
            end
        end
        -- We still count this as a new application; if we're already at max
        -- stacks we don't add another. If we're under, we add a new stack.
        if maxStacks and stacksOfThisSource >= maxStacks then return end
    end

    if maxStacks and stacksOfThisSource >= maxStacks then return end

    local key = sourceName .. "_" .. tostring(tick()) .. "_" .. tostring(math.random(1, 1e6))
    sources[key] = {
        endTime = tick() + durationSeconds,
        damagePerSecond = damagePerSecond,
        sourceName = sourceName,
    }
end

-- Remove all bleed from a humanoid (Kibi Dango uses this).
function BleedService:Cure(humanoid)
    bleeds[humanoid] = nil
end

-- Is this humanoid currently bleeding from anything? (Kibi Dango uses this to
-- decide whether a full-health teammate still needs the dango.)
function BleedService:IsBleeding(humanoid)
    return bleeds[humanoid] ~= nil
end

-- Tick once per second. Sum up all active bleeds per humanoid and apply.
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
    accumulator = accumulator + dt
    if accumulator < 1 then return end
    accumulator = accumulator - 1

    for humanoid, sources in pairs(bleeds) do
        if not humanoid.Parent then
            bleeds[humanoid] = nil
        else
            local totalDamage = 0
            for key, info in pairs(sources) do
                if tick() >= info.endTime then
                    sources[key] = nil
                else
                    totalDamage = totalDamage + info.damagePerSecond
                end
            end
            if totalDamage > 0 then
                humanoid:TakeDamage(totalDamage)
            end
            if next(sources) == nil then
                bleeds[humanoid] = nil
            end
        end
    end
end)

return BleedService
