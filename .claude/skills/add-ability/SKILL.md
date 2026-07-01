---
name: add-ability
description: Add a new ability to a playable character in Believe the Truth (Constants numbers, the ability function, its effect hook, key binding, and any new Remote). Use when adding or wiring up a character ability.
---

# Add an ability to a character

Abilities live in `src/ServerScriptService/Characters/<Character>.lua` as
`Character.Abilities.<Name>` functions. The client sends key presses through the
`AbilityRequest` RemoteEvent; Bootstrap routes them to `AbilityService:Handle`, which
dispatches to the character module.

## Steps
1. **Add its numbers to `Constants.<Character>`** — at minimum `Keybind`, `CooldownSeconds`,
   and the gameplay values (Damage, Radius, Range, durations…). Never hardcode these in code.
2. **Write the ability function** in the character module, following the standard shape:
   ```lua
   Character.Abilities.<Name> = function(player, params)
       if not AbilityModule.isOffCooldown(player, "<Name>") then return end
       local root = getRootPart(player)      -- bail if missing
       if not root then return end
       AbilityModule.startCooldown(player, "<Name>", C.<Name>.CooldownSeconds)
       EffectsService:Play("<Character><Name>", ...)   -- if it has a visual
       -- gameplay loop over Players:GetPlayers(), gated by isWarden/isYokai
   end
   ```
3. **Build its effect** (optional) — call `EffectsService:Play("<Character><Name>", ...)` and add a
   matching template in `ReplicatedStorage.Effects` named EXACTLY that (see the `build-effect` skill).
4. **Bind the key** in `AbilityInput.client.lua`. The `BINDINGS` table is keyed by character name;
   add an entry to that character's list:
   `{Action = "<Character><Name>", Ability = "<Name>", Key = Enum.KeyCode.X, Label = "…"}`.
   `Key` can be a `KeyCode` OR a `UserInputType` (e.g. `MouseButton1`); add `Hold = true` for
   hold-to-charge abilities.
5. **If the ability needs a new Remote** (e.g. a client mini-game like button-mash, or a
   server→client broadcast): add one `ensureRemote("Name", "RemoteEvent")` line in Bootstrap's
   remotes block. Client→server needs an `OnServerEvent:Connect` handler; server→all-clients uses
   `remote:FireAllClients(...)`; server→one-client uses `remote:FireClient(player, ...)`.

## Gotchas
- The RemoteEvent is auto-created by Bootstrap at runtime — do NOT hand-create it in Studio. If a
  remote seems missing, Bootstrap usually wasn't pasted/updated.
- `params` carries `{Phase = "Begin"/"End"}` for hold abilities and `{}` for taps — handle both.
- Gameplay numbers (damage/heal) go in the ability, never in the effect template.
- Reads of another player's character parts can race with spawns — guard `player.Character` and
  `FindFirstChild("HumanoidRootPart")` before using them.
