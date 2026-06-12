# Plan: wire the dressed character models into the round spawn

**Goal:** when a round starts, each player becomes their real dressed model (GirlA / Rokurokubi /
Momotaro) from `ReplicatedStorage.CharacterModels`, instead of the placeholder recolored avatar —
through the real game flow, not the StarterCharacter test harness.

**Good news (already in place):**
- The per-player mapping exists: `RoundService` sets `playerCharacter[userId]` =
  `"Momotaro"/"Rokurokubi"/"GirlA"` and `playerTeam[userId]` in `_enterRound`
  (`src/ServerScriptService/Services/RoundService.lua` ~lines 264–272).
- There's ONE spawn seam to change: `spawnPlayerAt(player, baseCFrame)` (~line 85), which today just
  calls `player:LoadCharacter()`. `_enterRound`, `_enterLobby`, and `OnPlayerJoined` all go through it.
- A companion spawner already exists: `Characters/Momotaro.lua` → `spawnCompanion()` clones from
  `ReplicatedStorage/Companions/<name>`. The Hawk slots into this.
- The thing that stomps the costume is `CharacterAppearance.apply(player, name)`, called from
  `Bootstrap.server.lua` `applyCharacterStats` on `CharacterAdded` (~line 120). Skip it for dressed models.

## Step 0 — DO THE HOMEWORK FIRST (don't guess — see the StarterCharacterScripts saga)
Verify these Roblox behaviors before writing the spawn code, because the whole approach hinges on them:
- When you set `player.Character = clonedModel` (instead of `LoadCharacter`), **do `StarterCharacterScripts`
  still get injected?** (Rokurokubi's neck wave lives there.) If NOT, the per-character scripts must move
  (e.g. clone them into the character at spawn, or drive behavior from a server service).
- Does the default **Animate** get added to a manually-assigned character? (Wanted for GirlA/Momotaro
  walking; Rokurokubi supplies her own + freezes limbs.)
- Camera / control scripts / **network ownership** latching onto a hand-assigned character.
- Confirm via docs + a tiny spike, not by iterating through full round tests.

## Step 1 — spawn-from-model helper (wire ONE character first: Momotaro)
In `RoundService`, branch `spawnPlayerAt` (or add `spawnDressed`):
- If `ReplicatedStorage.CharacterModels:FindFirstChild(playerCharacter[userId])` exists → clone it,
  set `player.Character = clone`, `clone.Parent = workspace`, `PivotTo` the team spawn (+scatter).
  Wait for the Humanoid; reconnect Died→respawn handling.
- Else fall back to `player:LoadCharacter()` (keeps placeholders working for anything not yet dressed).
- Prove Momotaro end-to-end (spawns, walks, camera, his StarterCharacterScripts behavior runs) BEFORE
  touching the other two.

## Step 2 — skip the recolor for dressed models
Gate `CharacterAppearance.apply` in `Bootstrap.applyCharacterStats` so it's skipped when the character
came from a dressed model (e.g. tag the clone with an attribute `Dressed=true` and check it). Keep
`applyCharacterStats`' HP/speed/passive setup running.

## Step 3 — repeat for GirlA + Rokurokubi
- GirlA: fire VFX + (later) hatchet weld.
- Rokurokubi: her neck wave must run (depends on Step 0's StarterCharacterScripts answer); she floats +
  arms frozen already baked into the model.

## Step 4 — companions
- Spawn the **Hawk** next to the Momotaro *player* via the existing `spawnCompanion` path. Repoint
  `tools/companion-bird.server.luau` from "find a Workspace object named Momotaro" to "follow THIS
  player's character" (pass the target in, or parent the bird under the character).
- Dogs come with the same plumbing once re-rigged.

## Step 5 — edges
Round transitions, death/respawn, mid-round joiners (wait in lobby), lobby vs round appearance
(probably normal/default in lobby, dressed on round start). Test with Server + 2 Clients.

## Estimate
One focused session (~2–4 hrs), risk of a second if Step 0's manual-`player.Character` gotchas bite.
De-risk by doing ONE character (Momotaro) fully through the real flow first, then replicating.
