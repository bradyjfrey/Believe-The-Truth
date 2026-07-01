---
name: weld-prop
description: Weld a weapon or prop to a character in Believe the Truth so it travels with the rig on every spawn. Use before adding a weapon swing, or when attaching any held/worn prop.
---

# Weld a weapon/prop to a character

Attach a weapon or prop rigidly to a character so it follows the body on every spawn. This is the
setup step before a code-driven swing (see `add-weapon-swing`).

## Steps
1. **Move the character model and the weapon out to `Workspace`** so you can position by eye.
2. **Position the weapon in the hand** where it should sit.
3. **Add a `WeldConstraint`** — Part0/Part1 order does not matter; it locks the current relative
   position. (For a hatchet, Part0 = the arm, Part1 = the handle works fine.)
4. **Set the weapon parts:** Anchored OFF, CanCollide OFF, Massless ON.
5. **Parent the weapon under the character model** so it travels with spawns.

## Gotchas
- If the prop is too small/large, scale it with `Model:ScaleTo` (or multiply a BasePart's `Size`) —
  a one-off sizing step, not a gameplay tunable.
- Some donated/pre-built weapons already contain internal structure — attachments, trails, even a
  Motor6D (e.g. the katana's `SwordLines`). That's fine: weld the whole weapon to the arm as one
  unit; don't try to disassemble it.
- Delete any bundled Script/LocalScript inside a free/donated weapon before using it (backdoor risk)
  — keep only the mesh/visual.
- R6 arms are named `Right Arm` / `Left Arm`; weld to the matching one for the intended `PrimaryArm`
  in the swing config.
