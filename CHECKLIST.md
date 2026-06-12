# Believe the Truth — Master Checklist

The running to-do for the game. Grouped by phase. See `PLAN_character_models.md` and
`PLAN_lobby_spawn.md` for the detailed how-tos behind specific items.

## ✅ Done
- [x] GirlA fully dressed (rig flattened, costume welded, fire VFX, hair) — recipe in `tools/dress-girla.luau`
- [x] Momotaro fully dressed (added missing Head + Neck, mask + hair on head, robe/webbing welded) — recipe in `tools/dress-momotaro.luau`
- [x] Lobby + map spawn flow — hang out in the lobby while waiting; teams split to blue (Warden) / red (Yokai) on round start; back to lobby on round end
- [x] Lobby + in-round music (lobby theme + CODE RED chase theme; chase audio pending Roblox moderation)

## 🐞 Known issues (check later, not blocking)
- [ ] **Dressed Momotaro couldn't move in the lobby** (test as StarterCharacter). He moved fine *in-round* earlier. Could be: spawning stuck in lobby geometry, controls disabled in the Lobby state, or something about the custom character + lobby spawn. Re-check once dressed models are wired into the real spawn flow.
- [ ] **Borrowed body's arms freeze when the player is the Yokai** (during the StarterCharacter test, Momotaro's arms didn't move as Yokai but did as Warden). Likely the Yokai role applies its own arm pose/ability — expected to disappear once each role uses its own real model. Verify when wiring per-role models.

## 🔜 Core build (the critical path to "all three characters real")
- [ ] **Dress Momotaro** (same recipe as GirlA; he also needs a Head added — his rig has none)
- [ ] **Dress Rokurokubi** (same recipe; her rig is deep-nested + her neck is a separate special piece)
- [ ] **Wire dressed models into the round spawn** — graft onto `RoundService._enterRound`: clone the dressed model → set as `player.Character` at the team spot, skip the old recolor, sort the Animate script. *(Do once all three are dressed so they swap in together.)*
- [ ] **Re-rig the 2 companion dogs** (the rig didn't persist) + hand-made walk-cycle animation (daughter's job)
- [ ] **Build the Effects** (`GirlASlash`, etc. — currently empty stubs that `EffectsService:Play` calls by name)
- [ ] **Build the Weapons** (GirlA's Hatchet — weld to her hand; pick a grip part)

## 🎨 UI & lobby
- [ ] **Redesign the "choose your character" picker** — Brady designing the look in `StarterGui`; Claude wires it as a template + dynamic cards (option to show the live 3D models via `ViewportFrame`)
- [ ] **Lobby whiteboard you can actually "write" on** (kids designed the board; needs draw-on-surface interaction)
- [ ] *(Way later)* **Skin store** — buy/equip Token & Toastful skins

## ✨ Wishlist / polish (later)
- [ ] **Killer intros (cinematic):**
  - GirlA — emerges from a computer screen: *"Welcome user, to your demise"* (high-quality scene)
  - Rokurokubi — floats/runs at the victim (shown on the killed player's avatar body), suffocates them with her neck after a few seconds of struggle, then charges
- [ ] **Music** — pull from Brady's Drive folder (see `reference_music_folder` memory); per-area map themes (Claude's choice/make); Rokurokubi gets a custom theme
- [ ] **Character animations:**
  - GirlA — floats while dragging her hatchet with one free hand; the other hand can attack / help support the hatchet
  - Rokurokubi — neck sways slightly, arms folded, slides/levitates around the map hunting players

## 🛠 Workflow notes
- **No Argon.** Claude edits code on disk; tells Brady exactly which existing scripts to paste into Studio (disk → Studio), then save. New script files = Claude walks Brady through creating the instance.
- **Models/markers/UI** live Studio-side; backed up via `.rbxm` exports + Download-a-Copy place backups.
- Always **commit before** any risky sync.
