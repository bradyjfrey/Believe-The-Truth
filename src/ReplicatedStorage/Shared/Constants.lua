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
-- MOMOTARO (Warden, Support + Stunner)
------------------------------------------------------------------------------
Constants.Momotaro = {
    MaxHealth = 110,

    Katana = {
        Keybind = Enum.KeyCode.Q,
        CooldownSeconds = 25,
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

return Constants
