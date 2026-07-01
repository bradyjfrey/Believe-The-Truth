# Workflow Notes — Believe the Truth

Durable knowledge for this codebase: conventions we settled on, repeatable
procedures, and gotchas with their fixes. Written for a team new to
Roblox/Lua, so it errs toward explaining *why*.

Anything marked **[SITUATIONAL]** was a one-off fix for a single problem — it
is NOT a standard to copy. Everything else is a real convention.

---

## 1. Project shape (where things live)

Source lives under `src/` and maps to Roblox services by folder name:

- `src/ReplicatedStorage/Shared/` — modules both server and client require:
  `Constants.lua` (all tunable numbers), `Types.lua` (Character/Team enums),
  `AbilityModule.lua` (cooldown helpers), `CharacterAppearance.lua`.
- `src/ServerScriptService/Bootstrap.server.lua` — the ONE server boot script.
  It creates Remotes/folders, wires services, applies per-character stats on
  spawn, and runs the round tick.
- `src/ServerScriptService/Services/` — long-lived systems: `RoundService`,
  `AbilityService`, `DisguiseService`, `EffectsService`, `BleedService`.
- `src/ServerScriptService/Characters/` — one module per playable character
  (`Momotaro`, `Rokurokubi`, `GirlA`, `Otohime`). Each returns a table with
  `.Abilities.<Name>` functions and a `:StartPassives(player)` method.
- `src/StarterPlayer/StarterPlayerScripts/` — client scripts: `HUD.client.lua`,
  `Sprint.client.lua`, `WeaponSwing.client.lua`, `AbilityInput.client.lua`.
- `src/StarterPlayer/StarterCharacterScripts/` — scripts that re-run on every
  spawn (e.g. `Health.server.lua`).

### No Argon sync — paste by hand
We do NOT run Argon to sync `src/` into Roblox Studio (it's reconcile-based and
has clobbered uncommitted edits). Workflow: edit files on disk, then Claude
tells Brady exactly which file to copy and its exact Studio destination. Always
give the repo-root-relative disk path (`src/...`) AND the Studio tree location —
never a bare filename.

---

## 2. Conventions we settled on

### Constants.lua holds every tunable number
Damage, radii, cooldowns, speeds, HP — all live in `Constants` in per-character
or per-system tables (e.g. `Constants.Otohime.DarkMoon.Damage`,
`Constants.Stamina.DrainPerSecond`). Character/service code reads from there and
never hardcodes gameplay numbers. This lets the kids tune values in one place.
Indentation in Constants.lua is **4 spaces, not tabs** (an edit failed once on
tab-vs-space mismatch).

### Effects are purely visual; gameplay numbers live in ability code
`EffectsService:Play(name, ...)` only shows something. Healing/damage/hit
detection always live in the character module. Never put damage in an effect
template.

### Character module shape
Every character module follows the same pattern (see `Otohime.lua` as the
cleanest example):
- `local O = Constants.<Character>` alias at top.
- Small local helpers: `getHumanoid`, `getRootPart`, `isWarden`, `isYokai`.
- `Character.Abilities.<Name> = function(player, params) ... end` — each one:
  1. `if not AbilityModule.isOffCooldown(player, "<Name>") then return end`
  2. get root/humanoid, bail if missing
  3. `AbilityModule.startCooldown(player, "<Name>", O.<Name>.CooldownSeconds)`
  4. play effect, then do the gameplay loop over `Players:GetPlayers()`.
- `function Character:StartPassives(player)` — always present, even if empty, as
  an extension point (Bootstrap calls it on spawn).

### Team checks use attributes
Team membership is read via `player:GetAttribute("Team") == Types.Team.Warden`
(or `.Yokai`). Character identity is `player:GetAttribute("Character")`.

### Comment style
Plain-English "why" comments, friendly names, no clever Lua. Header block at the
top of each file explaining what it does and how to extend it.

### Colorblind-safe UI
Brady is colorblind. UI is described and encoded by shape/position/length/number
— never by color alone. HUD themes exist but color is never the only signal.

---

## 3. Remotes: the two-things-named-the-same trap

There are TWO different objects that can share a name; keep them distinct:

- **(A) A client script** in `StarterPlayerScripts` (e.g. `WeaponSwing.client.lua`)
  — you create/paste this file yourself.
- **(B) A RemoteEvent** at `ReplicatedStorage > Remotes > WeaponSwing` — this is
  **auto-created by Bootstrap at runtime** via `ensureRemote(...)`. You do NOT
  hand-create it. If a remote seems missing, the cause is usually that
  Bootstrap wasn't pasted/updated.

When talking about a remote, always say which one (A the script vs B the
RemoteEvent) and its full path.

### Adding a new Remote
Add one `ensureRemote("Name", "RemoteEvent")` line in Bootstrap's remotes block,
and (if client→server) an `OnServerEvent:Connect` handler. Server→client
broadcasts use `remote:FireAllClients(...)`.

---

## 4. Procedure: add a new ability to a character

1. Add its numbers to `Constants.<Character>` (Keybind, CooldownSeconds, and the
   gameplay values like Damage/Radius/Range).
2. Add `Character.Abilities.<Name> = function(player, params)` following the
   cooldown → validate → startCooldown → effect → gameplay-loop shape in §2.
3. If it has a visual, call `EffectsService:Play("<Character><Name>", ...)` and
   build a template named exactly that (see §6).
4. Bind the key in `AbilityInput.client.lua`'s `BINDINGS` table:
   `{Action=..., Ability="<Name>", Key=Enum.KeyCode.X, Label="..."}`. The client
   fires the `AbilityRequest` remote; Bootstrap routes it to
   `AbilityService:Handle`, which dispatches to the module.

---

## 5. Procedure: add a new playable character

1. Create `src/ServerScriptService/Characters/<Name>.lua` returning a table with
   `.Abilities` and `:StartPassives`.
2. Add HP/speed etc. to `Constants.<Name>`, and a `Types.Character.<Name>` enum.
3. In `Bootstrap.server.lua`: `require` the module, add it to the
   `characterModules` map, and add an `elseif characterName == ...` branch in
   `applyCharacterStats` that sets MaxHealth/Health/WalkSpeed and calls
   `StartPassives`. **Gotcha:** each branch must use ITS OWN
   `Constants.<Name>.MaxHealth` — an early Otohime branch mistakenly used
   Momotaro's.
4. Add key bindings in `AbilityInput.client.lua`, and a HUD `CHARACTER_LABEL`
   entry.

---

## 6. Procedure: build a visual effect (EffectsService)

`EffectsService:Play(effectName, position, extras)` clones a template from
`ReplicatedStorage.Effects` named EXACTLY `effectName`, strips any scripts,
wraps it in a Model, positions/scales it, turns on emitters + sounds, and
Debris-cleans it after its lifetime.

To build one:
1. Drop a Part, Model, or Folder-of-parts into `ReplicatedStorage.Effects`,
   named exactly what the ability passes (e.g. `GirlASlash`, `OtohimeDarkMoon`).
2. Put ParticleEmitters / Sounds / PointLights inside it.
3. **Delete any bundled Script/LocalScript/ModuleScript** — free art assets
   smuggle in scripts (backdoor risk). EffectsService also strips them
   defensively, but delete them in the template too. (We hit this with a
   `PoseTexture` script inside `OtohimeHealingPulse`.)
4. Optionally add a lifetime override in EffectsService's `LIFETIMES` table.

`extras` options:
- `AttachTo` (BasePart) — the effect welds to and RIDES this part (a limb or a
  mover). With `AttachTo`, `extras.CFrame` is a LOCAL offset from that part.
  Parts are made massless/non-colliding so they follow cleanly.
- `CFrame` — world placement (or local offset when combined with `AttachTo`).
- `Scale`, `Lifetime`, `Parent`.

Two placement modes and why:
- **Fixed spot** (no `AttachTo`): parts are anchored, then the effect is
  re-centered by BOUNDING BOX so its visual middle sits on the target — most
  templates are built off-center, so without this they appear shoved to one side
  or behind the target.
- **Attached/ride-along**: use this whenever an ability moves the caster (dashes/
  lunges) or the effect should track a limb/projectile. A world-placed effect on
  a lunging character ends up "sideways/in the body."

### Projectile pattern (Dark Moon)
Create an invisible **anchored mover Part**, `Play` the effect with
`AttachTo = mover` and `Parent = mover` (so destroying the mover cleans up the
visual), then slide the mover forward each frame in a `Heartbeat` loop using
`startPos + lookVector * (range * t)`. First target within `HitRadius` takes the
hit, then destroy the mover.
- **Gotcha:** hit radius must roughly match the VISUAL size, not the mover.
  Dark Moon's tiny radius meant only a dead-center hit registered; bumped
  4 → 12 → 14 to match the big moon.

---

## 7. Procedure: code-driven weapon swing (no uploaded animation)

We animate swings in code via `WeaponSwing.client.lua`. Key idea below is the
single most important Roblox lesson from this work.

Flow: character module fires the `WeaponSwing` RemoteEvent with
`:FireAllClients(player, "<StyleName>")`; every client plays that style on that
player so all players see it.

To add a weapon swing:
1. Weld the weapon to the correct arm (see §8).
2. Add a `CONFIG` entry in `WeaponSwing.client.lua`: `Duration`, `WindupFrac`,
   `WindupAngle`, `SwingAngle`, `PrimaryArm` ("Right"/"Left"), `TwoHanded`,
   `Axis` ("X"/"Y"/"Z").
3. In the character's attack code, fire the remote with that style name.

Tuning rules of thumb:
- Wrong swing direction (backwards) → flip the SIGN of the angles.
- Wrong plane (sideways vs overhead) → change `Axis` letter.
- Two-handed: the off-hand shoulder is built mirrored, so its angle is NEGATED
  to sweep the same visual way.

### THE key lesson: pose C0, not Transform
Every R6 character runs Roblox's built-in `Animate` script, which drives the
shoulder `Motor6D.Transform` every frame for walk/idle. If you pose the arm via
`.Transform` (or on the server), Animate stomps it and nothing visibly moves.
Fix: pose the shoulder's `.C0` in a client `RenderStepped` connection (which runs
after the default animation each frame). The animator never touches `C0`, so
our swing wins. We cache each joint's resting `C0` in a weak table, rotate off
it, and restore it when the swing ends.

R6 joint names (not R15!): `Right Arm` / `Left Arm` are the parts;
`Right Shoulder` / `Left Shoulder` are the Motor6D joints, parented to `Torso`.

---

## 8. Procedure: weld a weapon/prop to a character

1. Move the character model and the weapon out to `Workspace` to position by eye.
2. Position the weapon in the hand.
3. Add a `WeldConstraint` — Part0/Part1 order does not matter; it locks the
   current relative position. (For a hatchet: Part0 = the arm, Part1 = the
   handle works fine.)
4. On the weapon parts: Anchored OFF, CanCollide OFF, Massless ON.
5. Parent the weapon under the character model so it travels with spawns.

**[SITUATIONAL]** Some pre-built weapons (Momotaro's katana) already contained
internal structure — attachments, trails, and a `SwordLines` Motor6D. That's
fine; you weld the whole weapon to the arm as one unit. Not a standard we
created, just something to recognize in donated assets.

**[SITUATIONAL]** Scaling a too-small katana: use `Model:ScaleTo` /
`Model:GetScale`. One-off sizing fix, not a general convention.

---

## 9. Gotchas and fixes

- **Damage healed back almost instantly.** Roblox has default Humanoid health
  regen. Disabled it with an (empty) Script named EXACTLY `Health` in
  `StarterPlayer > StarterCharacterScripts` — Roblox treats a script of that
  name as an override for its built-in regen. Must be a Script (not LocalScript).

- **Default health bar showing.** Hide it with
  `StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)` (we run it in a
  small retry loop because it can be too early on first frame). Our custom HUD
  health bar replaces it.

- **Sprint stomping ability slows.** In `Sprint.client.lua`, only write
  `WalkSpeed` on the sprinting↔not-sprinting TRANSITION (`sprinting ~= wasSprinting`),
  not every frame — otherwise it overwrites temporary slows from abilities. Also
  skip while an `Incognito` attribute is set.

- **Client↔HUD stamina.** Sprint sets a `Stamina` attribute (0..1) on the player;
  HUD reads it via `GetAttributeChangedSignal`. Attributes are the pattern for
  client-script → HUD communication.

- **Appearance resets HP.** `CharacterAppearance.apply` (ApplyDescription) resets
  Health to 100, so Bootstrap sets MaxHealth/Health AFTER applying appearance.
  Dressed models skip the recolor entirely (the costume IS the model).

- **Effect appears off-center / behind target.** See §6 bounding-box centering.

- **Effect appears sideways / inside the body on a lunging attacker.** Use
  `AttachTo` the limb instead of world placement (see §6). **[SITUATIONAL]**
  GirlA's slash orientation needed hand-tuned offset knobs
  (`FWD=-12, ROT_X=240, ROT_Z=90`) — those exact numbers are specific to her
  slash, not a formula.

- **Katana cooldown set to 0.** `Momotaro.Katana.CooldownSeconds` was temporarily
  set to 0 (spec was 25) so the kids can pick a real value later. **[SITUATIONAL]**
  — restore a real cooldown before launch.

- **Healing Pulse doesn't heal Otohime herself.** By design — she's a team medic
  (`other ~= player` in the loop). Confirmed intended, not a bug.

- **Free-asset scripts.** Any Script bundled inside a Toolbox/Creator-Store model
  or effect is a backdoor risk — delete it and keep only the mesh/visual. We
  write our own behavior. EffectsService strips scripts from clones as a backstop.

---

## 10. Verification workflow

Because there's no Argon sync, the loop is: edit on disk → tell Brady the exact
`src/...` file and Studio destination to paste → he playtests → he reports back.
Debugging is inspector/print-driven ("search/inspect, don't guess"): when
something doesn't fire, add temporary prints to confirm which branch runs, then
strip them once fixed.
