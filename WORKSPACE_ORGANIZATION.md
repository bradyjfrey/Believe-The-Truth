# Workspace Organization — ✅ Done (2026-06-06)

This was a one-time cleanup of the Studio Workspace from a flat dump into named,
organized groups. **It's complete.** Kept here as a record + a few principles worth
holding onto. For the *next* phase (wiring her models into the game), see
`PLAN_character_models.md`.

---

## What got done

- **Workspace tidied** into named folders (`Maps`, `Environment`, etc.); auto-named
  junk (`Model`, `Part`, `Custom Sign Text2`, orphan decals/emitters) renamed or removed.
- **All scenery grounded** — trees/objects dropped onto terrain (mix of a raycast
  Command Bar script + manual Move-tool + Collisions; the script struggled with
  drooping branches and dense forests, so manual finished it).
- **Orphan cluster cleared** — the exploded character-test remains (`Humanoid`, loose
  hair/tie/accessories, orphan decals, duplicate `The Mimic Vine`) deleted; confirmed
  unreferenced by code first.
- **Real character assets sorted** into role-based folders and **moved to
  `ReplicatedStorage`**:
  - `CharacterModels` — GirlA, Rokurokubi, Momotaro
  - `CharacterModels Self Insert` — skins (Token, Toastful)  *(rename → `Skins` next)*
  - `Weapons`, `Companions` (2 dogs), `Effects` (GirlASlash)
- **All characters + dogs rigged** (Humanoid + HumanoidRootPart + Motor6D joints);
  Rokurokubi and the dogs rigged from scratch via Command Bar scripts.

---

## Principles we settled (keep these)

- **Organize by *role*, not by character.** The engine treats a body (cloned as the
  player), a weapon (welded to a hand), a companion (spawned in the world), and an
  effect (play-then-destroy) completely differently — so they live in separate folders.
- **Name what it is — kill all Studio auto-names.** `Sign_GirlA`, not `Custom Sign Text2`.
- **Folder = tidiness (no position). Model = moves/clones as a unit (has a pivot).**
- **Masters live in `ReplicatedStorage` (git-synced); don't keep live duplicate models
  in Workspace** — they drift, aren't backed up, and a Humanoid model in Workspace spawns
  as a stray NPC. To edit visually, drag a copy out, edit, drag back, delete the copy.
- **`Workspace` is NOT in `project.json`, so it's not in git** — `.rbxl` backups + Studio
  Save are the only safety net for Workspace work.

---

## Next phase

Not workspace cleanup anymore — it's getting her models into the game. See
`PLAN_character_models.md`: Argon two-way sync → commit the models → flatten the buried
rigs into clean clone-targets → wire each character to spawn. The dogs also need a
hand-made walk-cycle animation (custom quadruped rig).
