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

## 🐞 Known issues (check later, not blocking)
- [ ] **Dressed Momotaro couldn't move in the lobby** (test as StarterCharacter). He moved fine *in-round* earlier. Could be: spawning stuck in lobby geometry, controls disabled in the Lobby state, or something about the custom character + lobby spawn. Re-check once dressed models are wired into the real spawn flow.
- [ ] **Jumping is inconsistent** — per playtest (daughter): only **Girl A can jump, and only a little** (stays inside the map, can't jump out); **Momotaro and Rokurokubi can't jump at all**. Likely per-model rig / `Humanoid.JumpPower`(or `UseJumpPower`)/HipHeight differences on the dressed models. Decide intended behavior per character, then normalize.
- [ ] **Borrowed body's arms freeze when the player is the Yokai** (during the StarterCharacter test, Momotaro's arms didn't move as Yokai but did as Warden). Likely the Yokai role applies its own arm pose/ability — expected to disappear once each role uses its own real model. Verify when wiring per-role models.

## 🔜 Core build (the critical path to "all three characters real")
- [ ] **Wire dressed models into the round spawn** — all three are dressed now, so they can swap in together. Full grounded plan in **`PLAN_dressed_model_spawn.md`** (seam = `spawnPlayerAt`; mapping already exists; skip `CharacterAppearance.apply`; do Momotaro end-to-end first; ~1 focused session).
- [ ] **Momotaro's companions (per spec there are THREE, not 2 dogs):** **Kijiro the pheasant** = the Hawk (passive *Bird's Eye View*, highlights Yokai — behavior built), **Inuta the dog** (*Guard Dog* ability), **Saru the monkey** (*Messy Eater* banana-slip). ⚠️ Checklist used to say "2 dogs" — confirm whether the kids built 2 dogs or dog + monkey. Re-rig the quadruped(s) (rig didn't persist) + walk-cycle animation (daughter's job). Recipe: `RIG QUADRUPED DOGS script` (Desktop → move to `tools/`).
- [ ] **Momotaro's companion bird (Hawk)** — behavior DONE (`tools/companion-bird.server.luau`): hovers off his right shoulder/above his head and flaps in place (the asset's animation is a baked flight-circle; the script cancels the travel by pinning the body bone). Stored in `ReplicatedStorage.Companions`. STILL TO DO: clone it beside the Momotaro player at spawn (same seam as the dogs) and fine-tune the shoulder offset against the real character.
- [ ] **Build the Effects** (`GirlASlash`, etc. — currently empty stubs that `EffectsService:Play` calls by name)
- [ ] **Build the Weapons** (GirlA's Hatchet — weld to her hand; pick a grip part, Momotaro had a sword in his design which needs to be added later)

## ⚔️ Abilities & passives (build list — exact numbers/quotes in `• specs/`)
Code already stubs a lot of this: `AbilityService`, `AbilityModule`, `EffectsService` (e.g. `GirlASlash`),
`Incognito.client`, `DisguiseService`, `BleedService`, and Girl A's Hotspots in `RoundService`.
- **Momotaro** — Warden (Support + Stunner), HP 110. Passive **Bird's Eye View** (Kijiro highlights Yokai ~6.5s every 45s). Abilities: **Katana** `Q` (0.5s windup → 30-stud dash, stun 3s + 15 dmg) · **Guard Dog** `E` (drop Inuta to bark/slow) · **Messy Eater** `R` (Saru's banana peel → slip/ragdoll) · **Kibi Dango** `F` (heal 30 self / 40 ally).
- **Girl A** — Yokai, HP 1700, walk 105% / run 150%. Passive **Auto Connect** (teleport between map Hotspots). Abilities: **Slash** `LMB` (15 dmg) · **Breach of Privacy** `Q` (pop-up reveals a Warden; closing early = 25 dmg) · **Stray Blade** `E`-hold (throw cleaver, 35 dmg + Bleed) · **Incognito Mode** `R` (invisible 8s + Hotspot warp).
- **Rokurokubi** — Yokai, HP 2000, ~10% faster than survivors, free starter. Passive **Hidden Hunger** (stomach-growl audio when she's near). Abilities: **Neck Wrap** `Q` (bind + DoT, button-mash escape) · **Bite** `M1` (bleed, stacks ×3) · **Disguise** `R` (look like a Warden) → **Strangle** `Q` while disguised (choke, disguise drops).

## 🎨 UI & lobby
- [ ] **Redesign the "choose your character" picker** — Brady designing the look in `StarterGui`; Claude wires it as a template + dynamic cards (option to show the live 3D models via `ViewportFrame`)
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
