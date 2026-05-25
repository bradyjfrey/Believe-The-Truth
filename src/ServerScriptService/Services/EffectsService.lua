-- EffectsService.lua
-- All visual effects and sounds happen here. Every function below is empty
-- on purpose — the art team fills them in later. Abilities just call
-- EffectsService:Play("SomeEffectName", position) and the art team has one
-- file to edit when they're ready to add particles, sounds, etc.
--
-- The full list of effect names the abilities currently call:
--
--   MOMOTARO
--     MomotaroKatanaWindup, MomotaroKatanaSwing, MomotaroKatanaHit
--     MomotaroInutaDeploy, MomotaroInutaBark
--     MomotaroSaruEat, MomotaroBananaDrop, MomotaroBananaSlip
--     MomotaroKibiDangoSelf, MomotaroKibiDangoTeammate
--     MomotaroBirdsEyeView
--
--   ROKUROKUBI
--     RokurokubiNeckWrapWindup, RokurokubiNeckWrapHit
--     RokurokubiBite
--     RokurokubiDisguiseChargeUp, RokurokubiDisguiseApplied, RokurokubiDisguiseEnded
--     RokurokubiEyeGlow
--     RokurokubiStrangle
--     RokurokubiHiddenHungerGrowl
--
--   GIRL A
--     GirlASlash, GirlASlashHit
--     GirlABreachPopup
--     GirlAStrayBladeAim, GirlAStrayBladeThrow, GirlAStrayBladeImpact
--     GirlAIncognitoStart, GirlAIncognitoEnd
--     GirlAHotspotTeleport

local EffectsService = {}

-- Play an effect by name. `position` is where it should happen in the world
-- (can be nil for non-positional effects like a global highlight). `extras`
-- is an optional table for things like {ListenerPlayer = player} when the
-- effect should only be heard by one player.
function EffectsService:Play(effectName, position, extras)
    -- TODO: art team — fill this in. For now we print so we can see during
    -- playtest that abilities are firing.
    print(string.format("[EffectsService] %s at %s", tostring(effectName), tostring(position)))
end

return EffectsService
