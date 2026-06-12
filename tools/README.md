# tools/ — Roblox Studio helper scripts

These are little scripts you paste into the **Command Bar** in Roblox Studio
(View menu → Command Bar). They are NOT game code — they're one-time helpers we
run by hand to inspect or build character rigs. Nothing here runs during the game.

**How to run any of them:** open the script, copy the whole thing, paste it into
the Command Bar, press Enter. Most need you to **select a model in the Explorer first**
(read the comment at the top of each file — it says what to select).

| Script | What it does | Safe? |
|---|---|---|
| `inspect-character.luau` | Prints a character's rig: tree, joints, Humanoid, parts. **Changes nothing.** Select the character model first. | ✅ read-only |
| `inspect-summary.luau` | Quick one-line health check across all the character models at once. | ✅ read-only |
| `dress-girla.luau` | The full recipe that turned bare "Killer GirlA" into a dressed, welded `StarterCharacter`. The pattern we copy for the other characters. | ✏️ builds things |
| `reweld.luau` | Re-welds selected clothing part(s) to a body part (edit `TARGET` at the top). Handy fix-up tool. | ✏️ builds things |
| `rigdogs.luau` | Adds the quadruped rig (HumanoidRootPart + joints) to the two companion dog models. Walking animation is a separate hand-made step. | ✏️ builds things |

⚠️ Before running anything that **builds/changes** (the ✏️ ones), make sure your work
is committed to git or backed up (Download a Copy) — so a bad run is easy to undo.
