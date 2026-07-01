# Believe the Truth — Project Conventions

Asymmetric horror Roblox game (Wardens vs. Yokai), built with a team new to Roblox/Lua.
These are the always-true standards for this codebase. Step-by-step procedures (adding an
ability, character, effect, weapon swing, weld) live as skills in `.claude/skills/`.

## Where things live
`src/` maps to Roblox services by folder name:
- `src/ReplicatedStorage/Shared/` — modules server + client both require: `Constants.lua`
  (all tunable numbers), `Types.lua` (Character/Team enums), `AbilityModule.lua` (cooldown
  helpers), `CharacterAppearance.lua`.
- `src/ServerScriptService/Bootstrap.server.lua` — the ONE server boot script: creates
  Remotes/folders, wires services, applies per-character stats on spawn, runs the round tick.
- `src/ServerScriptService/Services/` — long-lived systems (`RoundService`, `AbilityService`,
  `DisguiseService`, `EffectsService`, `BleedService`).
- `src/ServerScriptService/Characters/` — one module per playable character; returns a table
  with `.Abilities.<Name>` functions and a `:StartPassives(player)` method.
- `src/StarterPlayer/StarterPlayerScripts/` — client scripts (HUD, Sprint, WeaponSwing, AbilityInput…).
- `src/StarterPlayer/StarterCharacterScripts/` — scripts that re-run on every spawn (e.g. `Health.server.lua`).

## Workflow: no Argon, paste by hand
We do NOT run Argon to sync (it's reconcile-based and has clobbered uncommitted edits). Edit
files on disk, then tell Brady exactly which file to paste and where: always give the
**repo-root-relative disk path (`src/...`) AND the Studio destination** — never a bare filename.
For a NEW script, say what instance type to create (e.g. LocalScript) and where. Prefer a table
(disk file | Studio location | new/edited) over prose. Never commit unless explicitly told to.

## Code conventions
- **Constants holds every tunable number.** Damage, radii, cooldowns, speeds, HP live in
  per-character/system tables (e.g. `Constants.Otohime.DarkMoon.Damage`). Character/service code
  reads from there and never hardcodes gameplay numbers. Constants.lua is **4-space indent, no tabs**.
- **Effects are purely visual.** `EffectsService:Play(name, …)` only shows something. Healing,
  damage, and hit detection always live in the character module — never in an effect template.
- **Character module shape.** `local X = Constants.<Char>` alias at top; small local helpers
  `getHumanoid`/`getRootPart`/`isWarden`/`isYokai`; `Character.Abilities.<Name> = function(player, params)`
  that goes cooldown-check → validate root/humanoid → `startCooldown` → effect → gameplay loop;
  always a `Character:StartPassives(player)` (even if empty) as an extension point.
- **Team/identity via attributes.** `player:GetAttribute("Team") == Types.Team.Warden`/`.Yokai`;
  character is `player:GetAttribute("Character")`.
- **Remotes are auto-created by Bootstrap** via `ensureRemote("Name", "RemoteEvent")` at runtime —
  never hand-create the RemoteEvent. When discussing a remote, distinguish the client **script**
  (in StarterPlayerScripts) from the **RemoteEvent** (`ReplicatedStorage > Remotes > Name`) by full path.
- **Movement + HUD comms.** Client scripts write `WalkSpeed` only on a state transition, never
  per-frame, so they don't stomp temporary ability slows. Client-script → HUD communication goes
  through player **attributes** + `GetAttributeChangedSignal` (e.g. `Stamina`, `Character`).
- **No passive HP regen.** An empty Script named exactly `Health` in StarterCharacterScripts
  overrides Roblox's built-in regen; HP returns only via real heals.
- **Free-asset scripts = backdoor risk.** Delete any Script/LocalScript/ModuleScript bundled in a
  Toolbox/Creator-Store model or effect; keep only the mesh/visual. We write our own behavior.

## Style
- Plain-English "why" comments, friendly names, no clever Lua; a header block per file saying what
  it does and how to extend it.
- **Debug by inspecting, not guessing.** When something doesn't fire, add temporary prints to confirm
  which branch runs, then strip them once fixed.
