---
name: add-weapon-swing
description: Add a code-driven weapon swing in Believe the Truth (no uploaded animation) via WeaponSwing.client.lua. Use when a weapon needs an attack animation. Weld the weapon first with the weld-prop skill.
---

# Code-driven weapon swing (no uploaded animation)

Swings are animated in code by `WeaponSwing.client.lua`. The character module fires the
`WeaponSwing` RemoteEvent with `:FireAllClients(player, "<StyleName>")`; every client plays that
style on that player's body, so all players see it. The weapon must already be welded to the arm
(see the `weld-prop` skill).

## Steps
1. **Weld the weapon to the correct arm** first (see `weld-prop`).
2. **Add a `CONFIG` entry** in `WeaponSwing.client.lua` keyed by style name:
   - `Duration` — total swing time (seconds)
   - `WindupFrac` — fraction spent winding up before the chop (0..1)
   - `WindupAngle`, `SwingAngle` — degrees
   - `PrimaryArm` — `"Right"` or `"Left"`
   - `TwoHanded` — if true, the off-hand swings along too
   - `Axis` — `"X"` / `"Y"` / `"Z"` (which plane the arm swings in)
3. **Fire the remote** from the character's attack code:
   `swingRemote:FireAllClients(player, "<StyleName>")`.

## THE key lesson: pose `C0`, not `Transform`
Every R6 character runs Roblox's built-in `Animate` script, which drives the shoulder
`Motor6D.Transform` every frame for walk/idle. If you pose the arm via `.Transform` (or on the
server), Animate stomps it and nothing visibly moves. Instead pose the shoulder's `.C0` in a client
`RenderStepped` connection — it runs AFTER the default animation each frame, and the animator never
touches `C0`, so the swing wins. Cache each joint's resting `C0` in a weak table, rotate off it, and
restore it when the swing ends.

## Gotchas
- **R6 joint names (not R15):** `Right Arm`/`Left Arm` are the parts; `Right Shoulder`/`Left Shoulder`
  are the Motor6D joints, parented to `Torso`.
- Wrong swing direction (backwards) → flip the SIGN of the angles.
- Wrong plane (sideways vs overhead) → change the `Axis` letter.
- Two-handed: the off-hand shoulder is built mirrored, so its angle is NEGATED to sweep the same way.
