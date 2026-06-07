# Workspace Organization — Cleanup Checklist

A guide for tidying the Studio Workspace from a flat dump into named groups.
Think of it like layer groups in a creative suite: **Folder** = a bin/group,
**Model** = one object that moves as a unit.

---

## ⚠️ Read this first — git does NOT back up Workspace

`project.json` syncs `ReplicatedStorage`, `ServerScriptService`, etc. to git — but
**not `Workspace`.** So nothing in the Workspace is in version control. The usual
"commit to git before deleting" rule can't protect Workspace. Instead:

1. **Save a backup `.rbxl` first** (File → Save a copy) before big surgery.
2. **Publish to Roblox** for Studio version history.
3. **Move questionable things to `_ToSort/`, never straight to trash.**

(Future option: add Workspace to the Argon sync so the map gets versioned too —
bigger decision, not now.)

---

## Target structure

```
Workspace
├─ Camera                  ← leave (Roblox built-in)
├─ Terrain                 ← leave (Roblox built-in)
│
├─ Maps/                   ← Folder
│   ├─ Lobby               (was "lobby")
│   ├─ Forest_Map1         (was "map 1 s forest")
│   └─ Baseplate           (delete once real maps exist)
│
├─ Environment/            ← Folder: scenery, shared props
│   ├─ Barriers/           (the 4 loose "Barrier" parts)
│   ├─ Foliage/            (the 3 "Bush", "Mesh_AlpTrees4")
│   └─ Props/
│
├─ PickerStage/            ← Folder: character-select display
│   └─ Sign_GirlA, Sign_Momotaro, …   (the 6 "Custom Sign Text2")
│
└─ _ToSort/                ← Folder: orphans to investigate, NOT delete yet
    ├─ Humanoid, Accessory (1), DustyGreenTie, RainbowBoyHair,
    │  MeshPartAccessory, Decal ×3       (see "orphan cluster" below)
    └─ The Mimic Vine (the duplicate copy)
```

**Characters move OUT of Workspace** → into `ReplicatedStorage/CharacterModels/`:
`Girl A`, `Girl A's hair`, `Momotaro`, `Rorokubi`, `Dog 1`, `Dog 2`, `Slash`.
That's where the code clones them from, and ReplicatedStorage IS synced to git.
If you want the baseplate "showroom" lineup to stay visible, keep a *copy* in a
`Workspace/Showroom/` folder — but the master template lives in ReplicatedStorage.
(See `PLAN_character_models.md`.)

---

## The orphan cluster — investigate, don't trust

Sitting loose at the Workspace root:
> `Humanoid`, `Accessory (1)`, `DustyGreenTie`, `MeshPartAccessory`,
> `RainbowBoyHair`, `Decal ×3`

A bare `Humanoid` with hair + tie + accessories nearby is usually the **exploded
remains of a character that got ungrouped**, or a morph/avatar pack that unpacked
itself (note the `MorphAssets` folder right above it). Don't delete blind — it might
be pieces pulled off a character on purpose. Move the whole cluster into `_ToSort/`
and review together next session. Same for the **two identical `The Mimic Vine`
folders** — confirm before removing the duplicate.

---

## The naming rule (your "true named patterns")

**Every node names what it is — kill all Studio auto-names.** Auto-names are the tell
that something was inserted and never claimed.

- ❌ `Model`, `Part`, `Decal`, `Custom Sign Text2`, `Accessory (1)`
- ✅ `Sign_GirlA`, `Dog_Inuta`, `Barrier_North`, `GirlA_Hatchet`

Conventions:
- **PascalCase or `Category_Name`** — pick one, hold the line.
- **Prefix sets that belong together** (`Sign_`, `Dog_`, `Barrier_`) so they sort into
  a visual group even before foldering.
- **Never two identical names.** Six `Custom Sign Text2` is the worst offender.

---

## Folder vs. Model

- **Folder** — a bin of stuff. No position, can't be dragged by accident, won't
  transform children. Use for `Maps/`, `Environment/`, `_ToSort/`.
  (Right-click → Insert Object → Folder.)
- **Model** — one object that moves/clones as a unit, with a pivot. Use for a
  character, a dog, a sign. (Select parts → **Ctrl+G**.)

Rule of thumb: would you ever move/clone it as one thing? → Model. Just tidiness? → Folder.

---

## Cleanup workflow (do it incrementally, no marathon)

1. Save a backup `.rbxl` first.
2. Make the top-level folders: `Maps`, `Environment`, `PickerStage`, `_ToSort`.
3. Multi-select loose items → drag into the right folder. Rename as you drop them.
4. Unsure about something → `_ToSort/`, never the trash.
5. Move character templates to `ReplicatedStorage/CharacterModels/` and commit *that*.

## Next session first steps
- Open `_ToSort/` together and decide what each orphan is.
- Confirm the duplicate `The Mimic Vine`.
- Then proceed with the model-swap plan in `PLAN_character_models.md`.
