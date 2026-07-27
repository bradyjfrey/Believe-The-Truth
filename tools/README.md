# tools/ — Roblox Studio helper scripts

These are little scripts you paste into the **Command Bar** in Roblox Studio.
They are NOT game code — they're helpers we run by hand to inspect or build
character rigs. Nothing here runs during the game.

**How to run any of them:** open the script, copy the whole thing, paste it into
the Command Bar, press Enter. Most need you to **select a model in the Explorer first**
(read the comment at the top of each file — it says what to select).

## Inspectors (read-only, change nothing)

| Script | What it does |
|---|---|
| `inspect-new-characters.luau` | Sweeps Workspace for the kids' new characters (Kasa Obake, Okiku, Tomino, Bobzilla, Two Time Prime, Verity): weld verdict, rig check, size vs finished characters, stray scripts. No selection needed. |
| `inspect-summary.luau` | Compact one-block-per-rig survey of whatever containers you select (CharacterModels, Companions, Skins, Weapons). |
| `inspect-welds.luau` | Weld MAP of a dressed character: prints which body limb each costume part is attached to. Select the model first. |

## Builders (change things — commit / back up first)

| Script | What it does |
|---|---|
| `dress-girla.luau` / `dress-momotaro.luau` / `dress-otohime.luau` / `dress-rokurokubi.luau` | The full recipes that turned each raw kid-built model into a dressed, welded, spawn-ready character. Non-destructive (they clone). **The pattern to copy when dressing the new characters.** |
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
