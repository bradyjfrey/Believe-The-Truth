# Believe the Truth (真実信じ / Shinjitsu Shinji)

An asymmetric multiplayer survival-horror game on Roblox: a team of **Wardens**
(survivors) tries to outlast the **Yokai** (killers) hunting them, round after round,
with a shared lobby to hang out in between. PC + mobile.

Built by Brady with an art/design team of young teens who hand-build every character,
map, and effect in Roblox Studio. The code lives here; the models live in Studio.

## Current status (2026-10-18)

**Private / testing era: playable prototype, not yet public.** The core game works
end-to-end and has been playtested multiplayer: lobby → character select → round →
win/lose → back to lobby. Nine characters are pickable and spawn in their real
kid-built models; six of them have abilities, and every ability has a visual effect.

Done and tested:

- **Round loop:** lobby waiting area, themed character-select screens (red "Choose
  Your Yokai" / blue "Choose Your Warden"), team spawns with randomized spawn markers,
  win detection, round/lobby music.
- **Five characters with abilities** (passives, HP/speed stats, tested):
  - **Momotaro** (Warden): Katana dash-stun, Guard Dog (Inuta ×2), Messy Eater
    (Saru + banana peel slip), Kibi Dango heal; Bird's Eye View passive with his
    companion hawk Kijiro.
  - **Otohime** (Warden): Healing Pulse team heal, Dark Moon drifting projectile.
  - **Girl A** (Yokai): hatchet Slash, Breach of Privacy screen pop-up, Stray Blade
    thrown cleaver + bleed, Incognito invisibility; Hotspot warp passive.
  - **Rokurokubi** (Yokai): Bite bleed stacks, Neck Wrap, full model-swap Disguise,
    Strangle while disguised; proximity-growl passive and a 12-segment animated neck.
  - **Bobzilla** (Yokai, the free killer pick): Heat Ray, a mouth beam with a
    telegraphed windup glow, a burning trail where it lands, and a slow-to-a-crawl
    cost while it fires. Deliberately giant, deliberately slow, can't hide.
  - **Tomino** (Yokai): Whip Lash, Whip Slam shockwave, Pin Trap tripwire, Bomb Pin
    (3 charges, thrown, leaves a blood patch); Panic Struck passive slows nearby
    survivors' stamina refill. The only R15 character.
- **Three more characters dressed and pickable, abilities not designed yet:** Okiku,
  Verity (Yokai) and Two Time Prime (Warden, who has a lunge-stab pose on left-click
  but no damage). They spawn in their real models with their own HP and walk speeds;
  their picker cards (and Tomino's, pending purchase gating) show in a gold
  "developer" theme (`Constants.DeveloperOnlyCharacters`).
- **Combat feel:** code-driven weapon swings and poses (no uploaded animations),
  visual-effects pipeline (`EffectsService`) with every ability's effect in place
  (kids' hand-built templates plus code-built ones from `tools/build-effects.luau`),
  effect preloading, elimination-to-lobby on death. Girl A floats and drags her
  hatchet behind her.
- **Cutscenes:** scripted intro scenes (camera + stand-in characters on a
  `CutsceneStage` part, name card, fades) that play for everyone at round start while
  the clock and abilities wait. Momotaro's and Rokurokubi's intros are done; test
  keys 8 and 7 play them from the lobby.
- **HUD & lobby life:** health bar (colorblind-safe by design), sprint + stamina bar,
  ability cooldown squares, a lobby whiteboard you can actually draw on, shopkeeper NPC
  placed in the lobby house.

In progress / next up (full detail in `CHECKLIST.md`):

- **Win and loss cutscenes** in the end-of-round pause (the intro system is built;
  these are new scenes). Also still to see: the intro hookup in a real 2-player round.
- **Waiting on the kids:** kits for Okiku, Verity and Two Time Prime; Girl A's
  computer-screen prop and Tomino's asylum-doorway prop for their intros; Kasa Obake's
  dialogue lines for the lobby talk NPC.
- **Getting the kids playing:** the experience is published under Ava's account
  (`10041070796`); setting the audience to Limited there is the remaining step.
  Transfer to the community is paused.
- **THE YOROZUYA** (the store): economy fully designed in `SKIN_STORE_MONEY.md`.
  **Omamori** currency, earned in-game only, **never Robux/real money**. Build order:
  UI-only demo → free locker with DataStore → currency and prices.
- Parked: giant skeleton boss.

## How this repo works (read before touching anything)

This repo is the source of truth for **code**, and Studio is the source of truth
for **content**: models, maps, UI instances, and effect templates live Studio-side
only, backed up via `.rbxm` exports (`assets/models/`) and place-file downloads. `Believe the Truth.project.json` remains only as a map of which
`src/` folder corresponds to which Roblox service.

Other standing rules (details in `CLAUDE.md`):

- Every tunable number (damage, cooldowns, speeds, HP, prices) lives in
  `src/ReplicatedStorage/Shared/Constants.lua`, never hardcoded in ability code.
- Comments explain **meaning and location, never behavior**: every number in
  `Constants.lua` gets a short note on its units and what it affects, every character
  block gets a section banner, and nothing narrates what the code already says.
- Effects are purely visual; damage and healing always live in character modules.
- Any script bundled inside a free Toolbox/Creator Store asset gets deleted on sight
  (backdoor risk); we keep the mesh and write our own behavior.
- Kids build everything in Workspace; only Brady moves things to their runtime home.

## Repo map

| Path | What it is |
|---|---|
| `src/` | All game code. Folder names map to Roblox services (see below). |
| `CHECKLIST.md` | **The master to-do:** running status of everything, grouped by phase. |
| `CLAUDE.md` | Project conventions and code standards (enforced by Claude Code sessions). |
| `PLANNING.md` | The distilled game design doc (roles, characters, round rules). |
| `• specs/` | The kids' original planning doc (.docx) with full character specs and ability numbers. |
| `SKIN_STORE_MONEY.md` | Decided design of record for the Yorozuya store economy. |
| `KIDS_BUILD_LIST.md` | Art/sound request list for the kids, with exact naming rules. |
| `PLAN_*.md`, `WORKSPACE_ORGANIZATION.md` | Records of completed one-time plans (character models, lobby spawn, Workspace cleanup). |
| `tools/` | Scripts you paste into the Studio **Command Bar** by hand: rig inspectors and the dressing/welding recipes that built each character. See `tools/README.md`. |
| `mockups/` | HTML/PNG design mockups (character picker, store + HUD) and their generator scripts. |
| `assets/` | `.rbxm` model backups; `music/` is gitignored (tracks upload to Roblox directly). |
| `docs/` | Extra workflow notes. |
| `.claude/skills/` | Step-by-step recipes for repeat jobs: add a character, add an ability, build an effect, weld a prop, add a weapon swing. |

## Code layout (`src/` → Roblox services)

| Folder | Studio service | Contents |
|---|---|---|
| `src/ReplicatedStorage/Shared/` | ReplicatedStorage > Shared | Modules both server and client require: `Constants.lua` (every tunable number), `Types.lua` (Character/Team enums), `AbilityModule.lua` (cooldown helpers), `AbilityBindings.lua` (one shared keybind list so input and HUD can't drift), `Cutscenes.lua` (intro/win/loss scene data), `CharacterAppearance.lua`. |
| `src/ServerScriptService/` | ServerScriptService | `Bootstrap.server.lua` is the ONE boot script: creates Remotes, wires services, applies per-character stats on spawn, runs the round tick. |
| `src/ServerScriptService/Services/` | ServerScriptService > Services | Long-lived systems: `RoundService` (lobby/round state machine, spawning, elimination, win checks), `AbilityService`, `DisguiseService`, `EffectsService` (visual-only effect player), `BleedService`, `WhiteboardService`. |
| `src/ServerScriptService/Characters/` | ServerScriptService > Characters | One module per playable character (`Momotaro`, `Otohime`, `GirlA`, `Rokurokubi`, `Bobzilla`, `Okiku`, `Tomino`, `TwoTimePrime`, `Verity`): `.Abilities.<Name>` functions plus `:StartPassives(player)`. The last four are stubs with stats but no abilities yet. |
| `src/StarterPlayer/StarterPlayerScripts/` | StarterPlayer > StarterPlayerScripts | Client scripts: `HUD`, `Sprint`, `AbilityInput`, `WeaponSwing`, `CharacterPickerUI`, `DisguisePickerUI`, `Whiteboard`, `Incognito`, `HighlightReveal`, `NeckWave`, `CompanionFollower`, `BreachPopup`, `JumpControl`, `SoundPlayer`, `PreloadEffects`, `StoreUI`, `Cutscene` (plays the scripted intro scenes), `GirlAHover` (her float + trailing hatchet arm). |
| `src/StarterPlayer/StarterCharacterScripts/` | StarterPlayer > StarterCharacterScripts | Scripts that re-run every spawn, notably the empty `Health` script that disables Roblox's passive HP regen (healing only comes from real heals). |

A few load-bearing architecture notes:

- **Remotes are created at runtime** by `Bootstrap` (`ensureRemote`); never hand-create
  a RemoteEvent in Studio.
- **Team/character identity travels on player attributes** (`Team`, `Character`), and
  client-script → HUD communication goes through attributes too (e.g. `Stamina`).
- **Dressed character models:** the kids' hand-built rigs live in
  `ReplicatedStorage.CharacterModels`; `RoundService` swaps players into them at round
  start via a temporary StarterCharacter. Effect templates live in
  `ReplicatedStorage.Effects`, found **by exact name** (`<Character><Effect>`).
- **Characters are R6 rigs**, except Tomino (R15), which matters for any future
  animation or dressing work on him.
- **A dressed model missing its Humanoid or HumanoidRootPart reads as a dead player**,
  so the other team wins the instant the round starts. `RoundService.spawnPlayerAt`
  now warns by name when that happens; the warning text is indexed under
  **ERROR LOOKUP** in `CHECKLIST.md`.
- **`EffectsService:Play` returns its container**, and takes two optional extras that
  every effect can use but most don't yet: `BurstSeconds` (how much of an emitter's
  output to dump instantly, so a fire starts big instead of building up) and
  `LingerSeconds` (stop emitting at the end of the lifetime but let particles already
  in the air finish their arc, instead of deleting them mid-climb).
