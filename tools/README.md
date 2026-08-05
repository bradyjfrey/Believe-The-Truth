# tools/ — Roblox Studio helper scripts

These are little scripts you paste into the **Command Bar** in Roblox Studio.
They are NOT game code — they're helpers we run by hand to inspect or build
character rigs. Nothing here runs during the game.

**How to run any of them:** open the script, copy the whole thing, paste it into
the Command Bar, press Enter. Most need you to **select a model in the Explorer first**
(read the comment at the top of each file — it says what to select).

⚠️ **Judge a freshly-dressed character in solo Play, or in a test with clients — not from a
server-only run.** Observed 2026-08-04 on Tomino: he looks correct in solo Play and correct once
clients are added, but watching him during a server-only start shows him in pieces. That view is an
artifact, not a broken rig, and chasing it wastes time.

Also worth knowing, though it wasn't the cause above: every dresser parks its result in
`StarterPlayer.StarterCharacter`, and `RoundService.spawnPlayerAt` **claims and deletes that same
slot** when spawning a dressed character (`RoundService.lua:121-136`). Once a character is promoted
into `ReplicatedStorage.CharacterModels` and added to `DRESSED_ENABLED`, rounds spawn them properly.

## Inspectors (read-only, change nothing)

**There are only two, on purpose.** `inspect-character` answers "what IS this thing" before you
dress it. `inspect-welds` answers "what is this dressed thing attached to" after. If you need
something a bit different, extend `inspect-character` rather than adding a third file — we had
four overlapping inspectors by 2026-08-04 and consolidated them.

| Script | What it does |
|---|---|
| `inspect-character.luau` | **The one inspector.** Select any model(s) — a kid-built pile of meshes, a finished CharacterModel, several at once — and it reports: Humanoid/rig type, R6 vs R15 body-part shape, standard joint presence, part/anchor/weld census, dead welds, stray scripts, whether every part holds together, size vs the finished cast, prefix-scheme coverage, which axis is left/right, a per-part table with bottom/top heights, and likely left/right pairs. Ends with a compact block to paste back to Claude. Replaced `inspect-new-characters`, `inspect-summary`, and `inspect-okiku`. |
| `inspect-welds.luau` | Weld MAP of a dressed character: prints which body limb each costume part is attached to. Select the model first. |

## Builders (change things — commit / back up first)

| Script | What it does |
|---|---|
**Dressers are ONE PER CHARACTER, on purpose** — the opposite of the inspector rule above, because
each character's recipe really is different (Tomino's chain has to stay on one limb, Okiku needed a
skeleton built and a float, Rokurokubi needed a neck chain and frozen arms). Each file is also the
permanent record of how that character was built. Copy `dress-character.luau` as the starting point,
then make it that character's own. **Don't** try to serve two characters from one file: the tunables
live at the top, so dressing B after A silently applies A's float or A's overrides.

| Script | What it does |
|---|---|
| `dress-character.luau` | **The TEMPLATE to copy for a new character.** Holds both strategies and picks one. **Rig already exists** (R6 or R15): keeps it and welds each loose costume part to the nearest limb, with name hints sending hair/face to the head and shirt/skirt to the torso. **No rig at all**: builds an invisible R6 skeleton scaled to the model and welds by the name prefixes `Head_`, `Torso_`, `LeftArm_`, `RightArm_`, `LeftLeg_`, `RightLeg_`, refusing to run and listing offenders if a part lacks one. `FLOAT_LIFT` above 0 for characters that hover, `FACE_FLIP` if it walks backwards. |
| `dress-tomino.luau` | Tomino's recipe. Keeps his complete 16-joint **R15** rig (he's the only R15 character) and welds his 89 loose costume parts onto it. Has an `OVERRIDES` table (part name → limb) for the ones nearest-limb gets wrong — his 15-piece `MeshPart` chain must all ride ONE limb or it tears at the elbow, and his weapon `Handle` belongs in a hand. **Fix by editing `OVERRIDES` and re-running, not with `reweld.luau`**, or the fix is lost on the next run. |
| `dress-okiku.luau` | *(Not kept — she was dressed with the template before the split, and her recipe is written up in full in `CHECKLIST.md`. Rebuild from `dress-character.luau` if she ever needs re-dressing: no rig, prefix scheme, `FLOAT_LIFT = 4`.)* |
| `dress-girla.luau` / `dress-momotaro.luau` / `dress-otohime.luau` / `dress-rokurokubi.luau` | The original recipes for the first four, and the record of how each was built. |
| `fix-momotaro-rig.luau` | Renames Momotaro's root joint `Root Hip`→`RootJoint` + the duplicate costume `Torso`. **Re-run if his model is ever re-exported** (the bad names come back). |
| `rebuild-rokurokubi-neck.luau` | Rebuilds the NeckJoint Motor6Ds on Rokurokubi's 12 neck segments, in place. **Re-run if her model is ever re-exported** and the neck goes stiff. |
| `reweld.luau` | Re-welds selected clothing part(s) to a body part (edit `TARGET` at the top). The fix-up tool for bad welds (e.g. Okiku). |
| `rigdogs.luau` | Adds a quadruped rig (HumanoidRootPart + joints) to the dog models. Only needed if we ever give the dogs a real walk cycle (wishlist). |

## Live-script disk copies (do not run — they already live in Studio)

| Script | Where it lives in Studio |
|---|---|
| `companion-bird.server.luau` | Script inside ReplicatedStorage > Companions > Hawk. This file is the backup copy. |

*Pruned 2026-07-26: one-off diagnostics for solved bugs (jump, Saru, Otohime sizing,
companion wiring, bundled-script hunts) and the superseded neck-wave preview chain.
They're all in git history if ever needed.*

*Pruned 2026-08-04: `inspect-new-characters`, `inspect-summary` and `inspect-okiku` folded into
the single `inspect-character`; `dress-okiku` folded into `dress-character`. They overlapped
heavily and the per-character naming was leading straight to a fifth and sixth of each. Also in
git history.*

**Rule going forward:** diagnostics are named for the JOB and there is one of each — if a model
needs something `inspect-character` can't do, extend it rather than adding a file. Dressing is the
exception: those are per-character recipes and records, copied from `dress-character.luau`.
