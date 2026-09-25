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
    EliminatedRespawnSeconds = 3,    -- how long a caught player lies there before waking up in the lobby
}

Constants.DeveloperOnlyCharacters = {
    Okiku = true,
    Tomino = true,
    TwoTimePrime = true,
    Verity = true,
}

------------------------------------------------------------------------------
-- Camera
------------------------------------------------------------------------------
Constants.Camera = {
    -- How far players can zoom the third-person camera OUT, in studs. Capped so nobody can pull
    -- back to a bird's-eye view and spot other players across the map. (Roblox default is 128.)
    -- Our characters are ~2.4x normal size, so this is a little roomier than a normal-rig game.
    MaxZoomDistance = 28,
    -- Some characters are taller and need more room to fit in frame. Rokurokubi floats AND has
    -- the long neck, so her face sits way above her body -- 28 studs cuts it off. Give her more.
    -- Anyone not listed here uses MaxZoomDistance above. (Keyed by character name.)
    PerCharacter = {
        Rokurokubi = 45,
        Okiku = 70,
        Tomino = 55,
        Bobzilla = 140,
    },
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
        Okiku = 0,
        Verity = 0,
        Bobzilla = 0,
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

    OkikuWalk = 23,
    OkikuSprint = 31,

    TominoWalk = 24,
    TominoSprint = 32,

    VerityWalk = 25,
    VeritySprint = 33,

    BobzillaWalk = 22,
    BobzillaSprint = 28,
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
        CooldownSeconds = 24,  -- the kids' pick (spec said 25)
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
        BarkIntervalSeconds = 1,     -- how often the dogs BITE (deal damage) while a Yokai is in range
        -- The bark SOUND is separate from the bite, on a loose random rhythm from a random dog, so it
        -- sounds like two real dogs instead of one metronome. Each gap is a random time in this range:
        BarkGapMin = 0.6,            -- shortest gap between barks (seconds)
        BarkGapMax = 1.4,            -- longest gap between barks (seconds)
        SlowMultiplier = 0.5,        -- Yokai moves at 50% of their speed while near Inuta
        InutaHealth = 40,
        InutaLifetimeSeconds = 60,
        InutaAssetId = 5192647128,   -- Creator Store 3D Asset / Character for Inuta the dog (fallback only)
        -- Momotaro's daughter built TWO dog models. They're both just the LOOK of
        -- this one Guard Dog ability -- both trot out together and guard as a pair,
        -- sharing the single bark/slow/HP behavior above. These are the exact model
        -- names inside ReplicatedStorage.Companions. (If you rename them in Roblox
        -- Studio, update these to match.)
        -- Order matters: the FIRST name goes to Momotaro's LEFT, the second to his
        -- RIGHT (see DogSpacingStuds below). So larger-on-left, smaller-on-right.
        DogModelNames = { "Momotaro's larger dog", "Momotaro's smaller dog" },
        DeployForwardStuds = 5,      -- how far IN FRONT of Momotaro the pair plants (so their noses aren't in his back)
        BarkSoundId = "rbxassetid://115130102707678",  -- Creator Store dog bark, plays from the dogs each bark tick
        BarkVolume = 3,              -- how loud the bark is (Roblox sound volume goes 0..10; default is 0.5)
        DogSpacingStuds = 30,        -- total left-right gap between the two dogs, centered on the post -- 30 means each dog sits 15 studs out to its own side
    },

    MessyEater = {
        Keybind = Enum.KeyCode.R,
        CooldownSeconds = 15,
        PeelLifetimeSeconds = 60,
        SlipSeconds = 2,             -- how long a Yokai is ragdolled after slipping
        SaruEatSeconds = 2,          -- how long Saru is on screen "eating" before the peel drops
        SaruAssetId = 9230969826,    -- Creator Store character model for Saru the monkey
        SaruScale = 3,               -- the kids' monkey is ~3.5 studs tall; grown so he's clearly bigger than the peel. Tune to taste.
        SaruForwardStuds = 8,        -- Saru pops in this far in FRONT of Momotaro (at his own spot he hid inside the legs)
        BananaPeelAssetId = 2795329450,  -- Creator Store banana-peel mesh (the trap's LOOK). Falls back to
                                         -- a ReplicatedStorage.Companions "BananaPeel" model, then a yellow block.
        BananaPeelScale = 4,         -- grow the peel so it's not lost in the grass (1 = its natural size). Tune to taste.
        TriggerPadSize = Vector3.new(5, 3, 5),  -- the invisible "slip zone" a Yokai must step into. Bigger = easier to hit.
    },

    KibiDango = {
        Keybind = Enum.KeyCode.F,
        CooldownSeconds = 20,
        SelfHeal = 30,
        TeammateHeal = 40,
        TeammateRangeStuds = 5,      -- if a HURT teammate is this close, heal them instead
        CuresBleed = true,           -- Kibi Dango wipes out any bleed effect
        EffectForwardStuds = 3,      -- the dango visual floats this far in front of the healed player
        EffectUpStuds = 1,           -- ...and this far up (0,0 would bury it inside their chest)
        EffectSideStuds = -3,        -- slide it sideways (flip the sign to switch sides)
        EffectScale = 5,             -- the kids built it small; blow it up so it reads on screen
        EffectTiltDegrees = 90,      -- stand the stick UPRIGHT (0 = however it was built, which
                                     -- pointed straight out of the chest -- no thank you)
        EffectLeanDegrees = -30,     -- casual sideways lean once upright; flip the sign to lean the other way
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
        RangeStuds = 12,             -- center to center; she floats ~4 studs above a Warden's center, so 6 never landed (fixed 2026-09-24)
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
        GrowlEverySeconds = 2,       -- how often the growl can repeat while a Warden is close
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
        RangeStuds = 12,             -- how far ahead the swing reaches
        SwingWidthStuds = 6,         -- how far to EACH side of her the swing still counts
        PassThroughGraceStuds = 4,   -- targets this far BEHIND her still count -- she lunges
                                     -- forward before the hit check, so without this a
                                     -- point-blank swing lunges PAST the victim and whiffs
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
        HitRadiusStuds = 6,          -- how close the flying cleaver must pass to count as a hit
                                     -- (was 3, too tight -- her tall model throws above a
                                     -- standard rig's torso, so near-misses looked like
                                     -- pass-throughs; playtest 2026-07-19)
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

-------------------------------------------------------------------------------
-- OKIKU (Yokai, DEVELOPER-marked — no abilities yet)
-------------------------------------------------------------------------------
Constants.Okiku = {
    MaxHealth = 1800,
    FloatLift = 4,               -- studs added to HipHeight so she hovers instead of walking (she has no legs)
}

-------------------------------------------------------------------------------
-- TOMINO (Yokai, DEVELOPER-marked)
-------------------------------------------------------------------------------
Constants.Tomino = {
    MaxHealth = 1750,

    WhipLash = {
        CooldownSeconds = 1.3,       -- kids' number
        Damage = 24,                 -- kids' number; 5 lashes downs a 110 HP survivor
        RangeStuds = 20,             -- reach in front of him; he's 21 studs tall and the whip is long
        SwingWidthStuds = 8,         -- how far to EACH side the lash still counts
        PassThroughGraceStuds = 4,   -- targets this far behind his root still count (point-blank hits)
        BleedDamagePerSecond = 2,
        BleedDurationSeconds = 5,
        MaxBleedStacks = 1,          -- re-lashing refreshes the timer instead of stacking
    },

    WhipSlam = {
        CooldownSeconds = 24,        -- kids' number
        WindupSeconds = 0.4,         -- the whip rises before it lands, so survivors get a tell
        Damage = 27,                 -- kids' number
        RadiusStuds = 30,            -- Brady 2026-09-24; kids said 4-6, which barely cleared his own body
        RagdollSeconds = 2,          -- same knockdown length as the banana slip
    },

    PinTrap = {
        CooldownSeconds = 32,        -- kids' number
        PlaceForwardStuds = 8,       -- how far in front of him the pin goes down
        TriggerPadSize = Vector3.new(14, 3, 3), -- invisible tripwire: wide across his facing, thin along it
        TripSeconds = 2,             -- knockdown length when a survivor walks into it
        LifetimeSeconds = 60,        -- unsprung traps vanish after this; placing a new one also removes the old
    },

    BombPin = {
        Charges = 3,                 -- kids' "3 pins"; shown as a count on the HUD icon
        CooldownSeconds = 31,        -- per pin: each spent pin comes back on its own after this long
        ThrowRangeStuds = 60,        -- max throw distance; a wall in the way stops it short
        FlightSeconds = 0.5,         -- time in the air; the patch (and its damage) starts on landing
        ArcHeightStuds = 12,         -- how high above the straight line the throw peaks
        SpinsPerSecond = 3,          -- end-over-end tumble while flying; visual only
        PoolRadiusStuds = 10,        -- size of the blood patch
        DamagePerSecond = 3,         -- kids' number; overlapping patches stack
        PoolSeconds = 8,             -- how long each patch stays harmful
    },

    Effects = {
        FlashSeconds = 0.3,          -- how long one-shot visuals (slam ring, lash crack) stay solid
        LingerSeconds = 1,           -- extra time for particles already in the air to finish fading
    },

    PanicStruck = {
        RangeStuds = 40,             -- survivors this close have slowed stamina refill; matches Rokurokubi's growl range
        RegenScale = 0.5,            -- multiplier on Stamina.RegenPerSecond while in range; does NOT speed up draining
        CheckEverySeconds = 0.5,     -- how often range is re-checked, so the debuff lags leaving by up to this long
    },
}

-------------------------------------------------------------------------------
-- TWO TIME PRIME (Warden, DEVELOPER-marked — no abilities yet)
-------------------------------------------------------------------------------
Constants.TwoTimePrime = {
    MaxHealth = 110,             -- a survivor, so same fragile range as Momotaro/Otohime
}

-------------------------------------------------------------------------------
-- VERITY (Yokai, DEVELOPER-marked — no abilities yet)
-------------------------------------------------------------------------------
Constants.Verity = {
    MaxHealth = 1600,
    FloatLift = 6,               -- studs added to HipHeight; she's a floating globe, not a walker
}

-------------------------------------------------------------------------------
-- BOBZILLA (Yokai, FREE pick — the slow brute who can't hide)
-- His speed is the price the Heat Ray pays for. If anyone speeds him up, the
-- beam needs rebalancing too.
-------------------------------------------------------------------------------
Constants.Bobzilla = {
    MaxHealth = 2500,            -- highest in the game; he's meant to survive being focused

    HeatRay = {
        Keybind = Enum.KeyCode.Q,
        CooldownSeconds = 30,
        WindupSeconds = 0.6,     -- glow in his mouth BEFORE the beam — this is the survivors' warning, don't cut it
        DurationSeconds = 2,     -- how long the beam stays out
        TickSeconds = 0.25,      -- how often it re-aims and re-checks who's in it
        DamagePerTick = 12,      -- 8 ticks x 12 = 96 total, just short of killing a 110 HP survivor from full
        RangeStuds = 150,        -- how far the beam reaches if nothing blocks it
        HitRadiusStuds = 25,     -- how close to the beam's centre line you must be to get hit. Also sets how far apart the trail fires drop
        MouthHeightStuds = 64,   -- where the beam starts, measured UP FROM HIS FEET (not from his root). Tuned in-game 2026-08-05
        MouthForwardStuds = 28,  -- how far in front of his centre the beam starts. Too small and it fires from inside his body
        MouthPitchDegrees = -25, -- negative tilts the beam DOWN; at 0 it flies over every survivor's head
        BeamRollDegrees = 0,     -- spins the beam mesh about its own length; purely cosmetic
        FiringSpeedMultiplier = 0.15,  -- his walk speed while firing. NOT 0 — at 0 he can't turn, so the beam can't track
        TracksAim = true,        -- true = the beam follows where he's facing; false = it locks to the direction he fired
        WindupScale = 0.4,       -- size of the mouth-glow effect (1 = the template's built size)
        HitLifetimeSeconds = 4,  -- how long each fire burns where the beam lands
        HitBurstSeconds = 1.5,   -- seconds of particles dumped in instantly so the fire starts BIG instead of building up
        HitLingerSeconds = 8,    -- after the fire stops, how long the smoke and cinders keep rising before the effect is removed
        WindupBurstSeconds = 0.5,-- same idea for the mouth glow, which only lives 0.6s and has no time to fill
    },
}

------------------------------------------------------------------------------
-- Lobby whiteboard -- draw on it with the mouse while standing nearby.
-- (Server side: WhiteboardService. Client side: Whiteboard.client.lua.)
------------------------------------------------------------------------------
Constants.Whiteboard = {
    PartName = "Whiteboard",         -- the board's name in Workspace. Can be a single part OR a model (the kids'
                                     -- Whiteboard model works: the part with the biggest flat face becomes the surface).
    Face = "Back",                   -- which face of that part is the writing surface. The kids' board slab
                                     -- faces the lobby with its BACK face. If drawing ever comes out mirrored
                                     -- or invisible, flip between "Back" and "Front".
    PixelsPerStud = 50,              -- canvas resolution (more = sharper lines, slightly more work to render)
    DrawRangeStuds = 20,             -- how close a player must stand to draw
    DotSizePixels = 10,              -- marker thickness
    SendsPerSecond = 10,             -- how often a drawing player flushes stroke points to the server
    MaxPointsPerSend = 40,           -- server safety cap: bigger batches than this are dropped
    MaxPointsTotal = 6000,           -- the board is "full" past this; strokes are ignored until someone wipes it
    WipeHoldSeconds = 1,             -- hold the "Wipe the board" prompt this long

    -- Each player's marker color comes from this list (picked by their UserId), so
    -- everyone's scribbles look different without needing a color-picker UI. Add or
    -- change colors freely.
    MarkerColors = {
        Color3.fromRGB(30, 30, 30),      -- marker black
        Color3.fromRGB(230, 60, 60),     -- red
        Color3.fromRGB(60, 110, 230),    -- blue
        Color3.fromRGB(40, 160, 80),     -- green
        Color3.fromRGB(240, 150, 40),    -- orange
        Color3.fromRGB(160, 70, 200),    -- purple
    },
}

------------------------------------------------------------------------------
-- Omamori (the earned in-game currency) + the Skin Store.
-- The WHOLE economy lives here, per the design doc (SKIN_STORE_MONEY.md):
-- changing "25 for a win" to "30 for a win" is a ten-second edit, not a rebuild.
--
-- PHASE-0 NOTE: only the store UI exists so far (StoreUI.client.lua). The Earn
-- table below is the decided design of record but is NOT wired to gameplay yet;
-- the UI runs on a fake session wallet (StartingOmamori) that resets every join.
------------------------------------------------------------------------------
Constants.Omamori = {
    -- How you earn (NOT WIRED YET -- documented here so wiring is a lookup, not a design meeting).
    Earn = {
        FinishRound = 5,             -- win or lose; leaving mid-round earns nothing
        TeamWin = 25,                -- the big one, same for both teams
        SurviveOneMinute = 10,       -- Wardens, once per round
        YokaiCatch = 10,             -- per Warden reduced to 0 HP
        MoveUse = 2,                 -- per successful move (it has to do something to somebody)
        MoveUseCapPerRound = 10,     -- anti-cheesing cap on move money
        FirstWinOfDay = 20,          -- kids' addition
        BossKill = 40,               -- kids' addition -- DORMANT until the hellverse boss exists
    },
}

Constants.SkinStore = {
    StartingOmamori = 300,           -- PHASE-0 fake wallet: enough to demo buying a Common + a Cool
    PromptName = "SkinStorePrompt",  -- the ProximityPrompt (in the lobby store house) that opens the UI
    ComingSoonSlots = 4,             -- locked "coming soon" cards shown after the real catalog

    -- The three price tiers the kids approved.
    Tiers = {
        Common = { Price = 150, Label = "COMMON" },
        Cool   = { Price = 400, Label = "COOL" },
        Rare   = { Price = 900, Label = "RARE" },
    },

    -- What's on the shelves. ModelName = a model inside ReplicatedStorage.SkinModels
    -- (a card shows a "?" placeholder until that model exists, so this list can lead the art).
    -- The Common entry is an EXAMPLE for the kids to replace with a real color-swap skin.
    Catalog = {
        { Id = "NightRobe", DisplayName = "Night Robe", Tier = "Common", ModelName = "NightRobe" },
        { Id = "Token",     DisplayName = "Token",      Tier = "Cool",   ModelName = "Token" },
        { Id = "Toastful",  DisplayName = "Toastful",   Tier = "Rare",   ModelName = "Toastful" },
    },
}

return Constants
