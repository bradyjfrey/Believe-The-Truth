---
name: add-character
description: Add a new playable character to Believe the Truth (module, Constants, Types enum, Bootstrap wiring, key bindings, HUD label). Use when introducing a new Warden or Yokai.
---

# Add a playable character

A character is a module in `src/ServerScriptService/Characters/` plus wiring in Bootstrap,
Constants, Types, the client input map, and the HUD.

## Steps
1. **Create the module** `src/ServerScriptService/Characters/<Name>.lua` returning a table with
   `.Abilities` and `:StartPassives`. Copy `Otohime.lua` as the cleanest template — keep the
   `local X = Constants.<Name>` alias and the `getHumanoid`/`getRootPart`/`isWarden`/`isYokai`
   helpers.
2. **Add stats to `Constants.<Name>`** — `MaxHealth`, walk/run speeds, and each ability's numbers.
3. **Add the enum** `Types.Character.<Name>`, and its team in `Types.CharacterTeam`.
4. **Wire Bootstrap** (`Bootstrap.server.lua`):
   - `local <Name> = require(ServerScriptService.Characters.<Name>)`
   - add it to the `characterModules` map (`[Types.Character.<Name>] = <Name>`)
   - add an `elseif characterName == Types.Character.<Name> then` branch in `applyCharacterStats`
     that sets `MaxHealth`/`Health`/`WalkSpeed` and calls `<Name>:StartPassives(player)`.
5. **Bind keys** in `AbilityInput.client.lua` (a new keyed list under the character name).
6. **Add a HUD label** — an entry in `CHARACTER_LABEL` in `HUD.client.lua`.

## Gotchas
- **Each `applyCharacterStats` branch must use ITS OWN `Constants.<Name>.MaxHealth`.** A past bug
  had Otohime's branch reading Momotaro's HP — easy to copy-paste wrong.
- **Set `MaxHealth`/`Health` AFTER appearance.** `CharacterAppearance.apply` (ApplyDescription)
  resets Health to 100, so stats must be applied after it. Dressed models skip the recolor entirely
  (the costume IS the model) — they're tagged so Bootstrap doesn't restyle them.
- `:StartPassives` must exist even if empty — Bootstrap calls it on every spawn.
