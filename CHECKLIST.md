# Believe the Truth — Master Checklist

The running to-do for the game. Grouped by phase. See `PLAN_character_models.md` and
`PLAN_lobby_spawn.md` for the detailed how-tos behind specific items. **Full character specs —
stats, passives, every ability with keybinds/cooldowns/damage — live in `• specs/`** (the planning
.docx). The abilities section below is the build list distilled from it.

## ✅ Done
- [x] GirlA fully dressed (rig flattened, costume welded, fire VFX, hair) — recipe in `tools/dress-girla.luau`
- [x] Momotaro fully dressed (added missing Head + Neck, mask + hair on head, robe/webbing welded) — recipe in `tools/dress-momotaro.luau`
- [x] Rokurokubi fully done (flattened, faces forward, arms folded + frozen, floats) + **segmented 12-piece neck that waves like a cartoon snake** — `tools/dress-rokurokubi.luau`, `build-neck-chain.luau`, `finalize-rokurokubi.luau`, `rokurokubi-NeckWave.luau` (lives in StarterCharacterScripts)
- [x] Momotaro's companion bird (Hawk) — hovers off his shoulder + flaps (`tools/companion-bird.server.luau`)
- [x] Lobby + map spawn flow — hang out in the lobby while waiting; teams split to blue (Warden) / red (Yokai) on round start; back to lobby on round end
- [x] Lobby + in-round music (lobby theme + CODE RED chase theme; chase audio pending Roblox moderation)
- [x] **Killer character-select picker** — "Choose Your Yokai" screen: Grenze Gotisch title, tiled-stripe cards with live 3D `ViewportFrame` models (slow spin, peek above the box), blood-red hover, double border, countdown, locked "COMING SOON" slot. Runtime-built in `src/StarterPlayer/StarterPlayerScripts/CharacterPickerUI.client.lua`; keeps the existing `CharacterPicker` remote contract. Mockup: `mockups/killer-select.html`. Uploaded assets: stripe tile `119070341954890`, lock icon `127360932839161`. Per-character camera knobs live in the `CAMERA` table.
- [x] **Dressed models wired into the round spawn** — on round start each player becomes their real model (Momotaro / GirlA / Rokurokubi); all three spawn, move, and animate. Done via a temp `StarterPlayer.StarterCharacter` swap + `LoadCharacter` (so Roblox injects the R6 `Animate` + StarterCharacterScripts), tagged `Dressed=true` so `Bootstrap` skips the recolor. Toggle per character in `RoundService.DRESSED_ENABLED`; lobby stays normal avatars. (`RoundService.spawnPlayerAt`, `Bootstrap.applyCharacterStats`.)
  - **Model fixes applied (re-run if a re-export drops them):** Rokurokubi's neck `Motor6D`s rebuilt via `tools/rebuild-rokurokubi-neck.luau`; `NeckWave` now waits for the joints to replicate before scanning; Momotaro's root joint renamed `Root Hip`→`RootJoint` and a duplicate costume `Torso` renamed (`tools/fix-momotaro-rig.luau`). These joints/names are invisible in the Explorer unless you expand each part — easy to lose on export.
- [x] **Otohime fully added (2nd survivor) + survivor select screen** — dressed rig (`tools/dress-otohime.luau`) in `CharacterModels`, registered as a Warden, stub ability module, placeholder survivor stats. The picker is now theme-aware: red "CHOOSE YOUR YOKAI" for killers, light-blue "CHOOSE YOUR WARDEN / PROTECT THE TOWN IN" for survivors; every player picks concurrently. Tested 2-player.
- [x] **Camera zoom-out cap** — `player.CameraMaxZoomDistance` set from `Constants.Camera.MaxZoomDistance` (28 studs) on join, so nobody can pull back to a bird's-eye view and scout the map. (Lobby + round.)

## 🐞 Known issues (check later, not blocking)
- [ ] **Jumping is inconsistent** — per playtest (daughter): only **Girl A can jump, and only a little** (stays inside the map, can't jump out); **Momotaro and Rokurokubi can't jump at all**. Likely per-model rig / `Humanoid.JumpPower`(or `UseJumpPower`)/HipHeight differences on the dressed models. Decide intended behavior per character, then normalize.

_(Resolved: "dressed Momotaro can't move in lobby" — lobby now spawns normal avatars, dressed only in-round. "Yokai arm freeze" / "Momotaro frozen" — was Momotaro's rig naming (`Root Hip` root joint + duplicate `Torso`), fixed via `tools/fix-momotaro-rig.luau`.)_

## 🔜 Core build (the critical path to "all three characters real")
- [ ] **Otohime — 2nd survivor (Warden).** Built & wired, **needs a 2-player test:**
  - [x] Rig built + dressed (`tools/dress-otohime.luau`): her parts were a uniform 2.4× R6 rig missing its HumanoidRootPart + all 6 joints; script builds the skeleton (joints scaled 2.4×), keeps her native size, welds the kimono by `body_*`/`sleeve_*` name + respects Brady's hand-welded pants. Model deployed to `ReplicatedStorage.CharacterModels.Otohime` (raw rig kept as `OLD Otohime`).
  - [x] Registered in `Types.Character`/`CharacterTeam` (Warden) + `RoundService.DRESSED_ENABLED`; placeholder survivor stats in `Bootstrap` (mirrors Momotaro, no abilities yet).
  - [x] **Survivor select screen:** `CharacterPickerUI` is now theme-aware — the server sends the role and the screen themes red "CHOOSE YOUR YOKAI / KILLER / THE HUNT BEGINS" for killers, **light-blue "CHOOSE YOUR WARDEN / SURVIVOR / PROTECT THE TOWN IN"** for survivors. Keeps the "COMING SOON" locked slot. `RoundService` now lets *every* player pick (Yokai + all Wardens) concurrently instead of hardcoding Momotaro.
  - [x] **TESTED (2-player):** survivor screen shows Momotaro + Otohime in light blue ("CHOOSE YOUR WARDEN / PROTECT THE TOWN IN"), killer screen red as before; both pick correctly and spawn. Otohime portrait was facing away → fixed with `CAMERA.Otohime.face = 180`. *(Optional later: her card framing sits a touch small/low — tune `CAMERA.Otohime` zoom/drop if desired.)* Her two effects (Healing Pulse, Dark Moon) listed under Effects below.
- [ ] **Momotaro's companion dog(s) — Inuta** (*Guard Dog* ability). Re-rig the quadruped (rig didn't persist). Recipe: `RIG QUADRUPED DOGS script` (Desktop → `tools/`). Walk-cycle animation is **optional for now** — may add with Brady later, or ship without it until later. ⚠️ Confirm how many dogs the kids actually built.
- [ ] **Momotaro's companion bird (Hawk)** — wired into spawn + jitter-fixed, **needs test.** The `Hawk` model lives in `ReplicatedStorage.Companions`; `Momotaro.StartPassives` clones it, sets a `FollowTarget` ObjectValue = the player character, parents it under the character (it was looking for "Kijiro" before, hence the placeholder block). **Follow is now client-driven for smoothness:** the bird's own script (`tools/companion-bird.server.luau`) just anchors it, plays the flap, and tags it `FollowingCompanion`; the per-client `src/StarterPlayer/StarterPlayerScripts/CompanionFollower.client.lua` positions it every render frame (server-driven anchored motion stuttered when replicated). The dogs will reuse the same follower. **TEST:** spawn as Momotaro → Hawk flaps beside his shoulder, follows smoothly, no jitter. **Tune** the bird's spot/facing in `CompanionFollower.client.lua` → `CONFIG.Hawk` (right/up/forward/pinBone/facingYaw). Scale the `Hawk` model itself bigger in Studio if needed.
- [ ] **Build the Effects** (`EffectsService:Play` calls these by name — currently empty stubs):
  - `GirlASlash` (and other per-ability VFX)
  - **Healing Pulse** — Otohime's heal: pulses out from her, heals survivors within a radius (~+20 HP). *(Designed; in workspace.)*
  - **Dark Moon** — Otohime's attack effect. *(Designed; in workspace.)*
  - **Effect templates live in `ReplicatedStorage.Effects`**, each named `<Character><Effect>` to match the name its ability passes to `EffectsService:Play` (e.g. `GirlASlash`, `OtohimeHealingPulse`, `OtohimeDarkMoon`). `EffectsService` is still a print-only stub — when we build effects it'll clone the matching template from that folder by name and play it. (Weapons = held/welded props; Effects = transient spawned visuals.)
- [ ] **Build the Weapons** (GirlA's Hatchet — weld to her hand; pick a grip part, Momotaro had a sword in his design which needs to be added later)

## ⚔️ Abilities & passives (build list — exact numbers/quotes in `• specs/`)
Code already stubs a lot of this: `AbilityService`, `AbilityModule`, `EffectsService` (e.g. `GirlASlash`),
`Incognito.client`, `DisguiseService`, `BleedService`, and Girl A's Hotspots in `RoundService`.
- **Momotaro** — Warden (Support + Stunner), HP 110. Passive **Bird's Eye View** (Kijiro highlights Yokai ~6.5s every 45s). Abilities: **Katana** `Q` (0.5s windup → 30-stud dash, stun 3s + 15 dmg) · **Guard Dog** `E` (drop Inuta to bark/slow) · **Messy Eater** `R` (Saru's banana peel → slip/ragdoll) · **Kibi Dango** `F` (heal 30 self / 40 ally).
- **Girl A** — Yokai, HP 1700, walk 105% / run 150%. Passive **Auto Connect** (teleport between map Hotspots). Abilities: **Slash** `LMB` (15 dmg) · **Breach of Privacy** `Q` (pop-up reveals a Warden; closing early = 25 dmg) · **Stray Blade** `E`-hold (throw cleaver, 35 dmg + Bleed) · **Incognito Mode** `R` (invisible 8s + Hotspot warp).
- **Rokurokubi** — Yokai, HP 2000, ~10% faster than survivors, free starter. Passive **Hidden Hunger** (stomach-growl audio when she's near). Abilities: **Neck Wrap** `Q` (bind + DoT, button-mash escape) · **Bite** `M1` (bleed, stacks ×3) · **Disguise** `R` (look like a Warden) → **Strangle** `Q` while disguised (choke, disguise drops).

## 🚀 After launch (additions, not for first ship)
- [ ] **Saru the monkey** — Momotaro's 3rd companion (*Messy Eater* — banana peel → slip/ragdoll). Deferred to a post-launch addition; build the dog + Hawk for launch, add the monkey later.

## 🎨 UI & lobby
- [ ] **Lobby whiteboard you can actually "write" on** (kids designed the board; needs draw-on-surface interaction)
- [ ] *(Way later)* **Skin store** — buy/equip Token & Toastful skins

## ✨ Wishlist / polish (later)
- [ ] **Killer intros (cinematic):**
  - GirlA — emerges from a computer screen: *"Welcome user, to your demise"* (high-quality scene)
  - Rokurokubi — floats/runs at the victim (shown on the killed player's avatar body), suffocates them with her neck after a few seconds of struggle, then charges
- [ ] **Music for the skin store** — the lobby + in-round chase themes are done (see Done above); the skin store still needs its own track. Pull from Brady's Drive folder (see `reference_music_folder` memory). *(Stretch: per-area map themes, Rokurokubi custom theme.)*
- [ ] **Character animations:**
  - GirlA — floats while dragging her hatchet with one free hand; the other hand can attack / help support the hatchet
  - Rokurokubi — neck sways slightly, arms folded, slides/levitates around the map hunting players

## 🛠 Workflow notes
- **No Argon.** Claude edits code on disk; tells Brady exactly which existing scripts to paste into Studio (disk → Studio), then save. New script files = Claude walks Brady through creating the instance.
- **Models/markers/UI** live Studio-side; backed up via `.rbxm` exports + Download-a-Copy place backups.
- Always **commit before** any risky sync.
