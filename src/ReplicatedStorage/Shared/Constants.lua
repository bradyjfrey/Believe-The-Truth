-- Constants.lua
-- Every tunable number for Believe the Truth lives here.
--
-- Want to make Momotaro's katana hit harder? Change Momotaro.Katana.Damage.
-- Want Rokurokubi to wrap from farther away? Change Rokurokubi.NeckWrap.RangeStuds.
-- You don't need to read any other file to tune the game.
--
-- After you save this file, Argon syncs it to Studio automatically.

local Constants = {}

------------------------------------------------------------------------------
-- Round settings
------------------------------------------------------------------------------
Constants.Round = {
    MinPlayers = 2,                  -- need this many players for a round to start
    LobbyTimeSeconds = 20,           -- countdown before a round auto-starts
    RoundLengthSeconds = 3 * 60,     -- if Wardens survive this long, they win
    EndOfRoundDelaySeconds = 5,      -- pause after a round before going back to lobby
}

------------------------------------------------------------------------------
-- Camera
------------------------------------------------------------------------------
Constants.Camera = {
    -- How far players can zoom the third-person camera OUT, in studs. Capped so nobody can pull
    -- back to a bird's-eye view and spot other players across the map. (Roblox default is 128.)
    -- Our characters are ~2.4x normal size, so this is a little roomier than a normal-rig game.
    MaxZoomDistance = 28,
}

------------------------------------------------------------------------------
-- Jumping
------------------------------------------------------------------------------
Constants.Jump = {
    -- Default jump for characters, forced on at spawn. The dressed rigs came in inconsistent (some
    -- with jumping disabled or near-zero, and the big ~2.4x bodies need it set explicitly), so only
    -- Girl A could jump before. Kept modest ON PURPOSE: a small hop that can't clear the map walls.
    -- Raise carefully -- too high and players can jump out of the map. (Roblox default 50.)
    Power = 50,

    -- Per-character overrides. 0 = jumping fully disabled for that character.
    -- Rokurokubi FLOATS, so she never jumps.
    PerCharacter = {
        Rokurokubi = 0,
    },
}

------------------------------------------------------------------------------
-- Movement speeds (Roblox default WalkSpeed is 16)
------------------------------------------------------------------------------
Constants.Speed = {
    -- Wardens
    WardenWalk = 20,
    WardenSprint = 28,

    -- Rokurokubi can stalk or chase. Both speeds are above Warden equivalents
    -- so she's always a threat, even when walking.
    RokurokubiWalk = 25,
    RokurokubiSprint = 33,

    -- Girl A
    GirlAWalk = 21,
    GirlARun = 30,                   -- 1.5x walk (per spec)
    GirlAIncognitoRun = 39,          -- 1.3x her run (per spec)
}

------------------------------------------------------------------------------
-- STAMINA (for sprinting -- hold Shift). Drains while you run, refills when you don't.
-- When it hits 0 you drop back to walk until it recovers a bit. Tune freely.
------------------------------------------------------------------------------
Constants.Stamina = {
    Max = 100,
    DrainPerSecond = 25,             -- ~4 seconds of sprint from full
    RegenPerSecond = 18,             -- ~5.5 seconds to refill
    RegenDelaySeconds = 0.8,         -- short pause after sprinting before it starts refilling
    MinToSprint = 15,                -- once drained, must recover this much before you can run again
}

------------------------------------------------------------------------------
-- MOMOTARO (Warden, Support + Stunner)
------------------------------------------------------------------------------
Constants.Momotaro = {
    MaxHealth = 110,

    Katana = {
        Keybind = Enum.KeyCode.Q,
        CooldownSeconds = 0,  -- no cooldown for now; the kids will pick a real value later (spec was 25)
        WindupSeconds = 0.5,
        DashStuds = 30,
        DashDurationSeconds = 0.25,  -- how long the forward dash lasts
        StunSeconds = 3,
        Damage = 15,
        HitboxWidth = 6,             -- half-width of the swing's hit zone
    },

    GuardDog = {
        Keybind = Enum.KeyCode.E,
        CooldownSeconds = 30,
        DetectRangeStuds = 50,
        MinDamage = 1,
        MaxDamage = 5,
        BarkIntervalSeconds = 1,     -- one bark per second while a Yokai is in range
        SlowMultiplier = 0.5,        -- Yokai moves at 50% of their speed while near Inuta
        InutaHealth = 40,
        InutaLifetimeSeconds = 60,
        InutaAssetId = 5192647128,   -- Creator Store 3D Asset / Character for Inuta the dog
    },

    MessyEater = {
        Keybind = Enum.KeyCode.R,
        CooldownSeconds = 15,
        PeelLifetimeSeconds = 60,
        SlipSeconds = 2,             -- how long a Yokai is ragdolled after slipping
        SaruEatSeconds = 0.5,        -- short delay so it looks like Saru ate it
        SaruAssetId = 9230969826,    -- Creator Store character model for Saru the monkey
    },

    KibiDango = {
        Keybind = Enum.KeyCode.F,
        CooldownSeconds = 20,
        SelfHeal = 30,
        TeammateHeal = 40,
        TeammateRangeStuds = 5,      -- if a teammate is this close, heal them instead
        CuresBleed = true,           -- Kibi Dango wipes out any bleed effect
    },

    BirdsEyeView = {
        -- Passive: Kijiro the pheasant pings Yokai locations every so often.
        HighlightSeconds = 6.5,
        IntervalSeconds = 45,
        KijiroAssetId = 13656715867,  -- Creator Store model for Kijiro the bird (replaced earlier horror-duck asset)
        FollowOffset = Vector3.new(2, 4, -2),  -- bird position relative to Momotaro
    },
}

------------------------------------------------------------------------------
-- ROKUROKUBI (Yokai)
------------------------------------------------------------------------------
Constants.Rokurokubi = {
    MaxHealth = 2000,

    NeckWrap = {
        Keybind = Enum.KeyCode.Q,
        CooldownSeconds = 29,
        WindupSeconds = 2,
        -- Spec says 3 studs but that's melee-arm's-length. Bumped to 30 since
        -- she's supposed to be reaching with her stretchy neck. Tune freely.
        RangeStuds = 30,
        MaxWrapSeconds = 60,
        DamagePerSecond = 2,
        EscapePresses = 11,          -- mash space (PC) or button (mobile) this many times
    },

    Bite = {
        -- Bite is bound to left-mouse-button (handled in AbilityInput).
        CooldownSeconds = 1,
        WindupSeconds = 0.3,
        RangeStuds = 6,
        BleedDamagePerSecond = 2,
        BleedDurationSeconds = 10,
        MaxBleedStacks = 2,          -- biting a 3rd time has no extra effect
        RefreshOnReapply = true,     -- biting again resets the bleed timer
    },

    Disguise = {
        Keybind = Enum.KeyCode.R,
        CooldownSeconds = 20,        -- starts AFTER the disguise drops
        ChargeUpSeconds = 5,         -- she's frozen during this charge-up
        DurationSeconds = 19,
        EyeGlowIntervalSeconds = 4,  -- how often the eye-glow tell shows up
        EyeGlowDurationSeconds = 0.4,
    },

    Strangle = {
        -- Same key as Neck Wrap (Q) but only fires while she's disguised.
        ChokeSeconds = 2,
        DamagePerSecond = 1,
        RangeStuds = 5,              -- close enough to choke
    },

    HiddenHunger = {
        -- Passive: when a Warden is within this range, they hear a stomach growl.
        AudibleRangeStuds = 40,
    },
}

------------------------------------------------------------------------------
-- GIRL A (Yokai, paid character — playable for everyone in this build)
------------------------------------------------------------------------------
Constants.GirlA = {
    MaxHealth = 1700,

    Slash = {
        -- Bound to left-mouse-button.
        CooldownSeconds = 1.5,
        RangeStuds = 10,
        Damage = 15,
        LungeStuds = 4,              -- small forward step per spec ("lunges forward slightly")
    },

    BreachOfPrivacy = {
        Keybind = Enum.KeyCode.Q,
        CooldownSeconds = 25,
        PopupSeconds = 7,
        EarlyCloseDamage = 25,
        SlowMultiplier = 0.75,       -- Girl A is slowed (Slowness 1) while popup is up
    },

    StrayBlade = {
        Keybind = Enum.KeyCode.E,    -- hold to aim, release to throw
        CooldownSeconds = 10,
        RangeStuds = 30,
        TravelSeconds = 1,
        Damage = 35,
        AimSlowMultiplier = 0.75,    -- -25% movement while aiming
        BleedDamagePerSecond = 1,
        BleedDurationSeconds = 8,
    },

    IncognitoMode = {
        Keybind = Enum.KeyCode.R,
        CooldownSeconds = 15,
        DurationSeconds = 8,
        NearestHotspotCount = 3,     -- how many hotspots show up highlighted to her
    },

    Hotspots = {
        Count = 4,                   -- how many placeholder hotspots to spawn at round start
        DeactivationSeconds = 30,    -- how long a hotspot stays off after a Warden's task
    },
}

------------------------------------------------------------------------------
-- OTOHIME (Warden, Support / Medic)
-- 2nd survivor. Heals teammates and pelts Yokai with a slow "Dark Moon" projectile
-- (inspired by Elden Ring's Ranni's Dark Moon -- a slow, dramatic drifting moon).
-- NOTE: these numbers are NOT from the spec doc (she was never written up) -- they're sensible
-- starting values. Tune freely; the kids can set her real HP / numbers later.
------------------------------------------------------------------------------
Constants.Otohime = {
    MaxHealth = 110,                 -- placeholder, same as Momotaro for now

    HealingPulse = {
        Keybind = Enum.KeyCode.E,
        CooldownSeconds = 12,
        HealAmount = 20,             -- HP restored to each nearby ally
        RadiusStuds = 20,            -- how far the heal reaches (gameplay, not the visual size)
        ForwardStuds = 4,            -- push the orb VISUAL this far in front of her (so it's not on her body)
        -- Heals other Wardens in range, NOT Otohime herself (she plays as a team medic).
    },

    DarkMoon = {
        Keybind = Enum.KeyCode.Q,
        CooldownSeconds = 8,
        Damage = 25,                 -- to the first Yokai the moon touches
        RangeStuds = 70,             -- how far the moon drifts before it fades
        TravelSeconds = 3,           -- slow, dramatic drift (the Ranni's Dark Moon feel)
        HitRadius = 14,              -- how close the moon must get to a Yokai to hit (match the visual size)
        MoonScale = 1,               -- shrink/grow the moon visual if the template is too big/small
        StartForwardStuds = 3,       -- how far in front of her the moon conjures
        StartUpStuds = 2,            -- how high above her the moon conjures
    },
}

return Constants
