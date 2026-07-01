---
name: build-effect
description: Build a visual effect for Believe the Truth via EffectsService — a named template in ReplicatedStorage.Effects, placement/attach options, and the moving-projectile pattern. Use when adding VFX for an ability.
---

# Build a visual effect (EffectsService)

`EffectsService:Play(effectName, position, extras)` clones a template from
`ReplicatedStorage.Effects` named EXACTLY `effectName`, strips any scripts, wraps it in a Model,
positions/scales it, turns on emitters + sounds, and Debris-cleans it after its lifetime. Effects
are purely visual — the ability code owns all damage/heal/hit-detection.

## Steps
1. **Create the template** — drop a Part, Model, or Folder-of-parts into `ReplicatedStorage.Effects`,
   named exactly what the ability passes (e.g. `GirlASlash`, `OtohimeDarkMoon`).
2. **Add the visuals inside it** — ParticleEmitters, Sounds, PointLights, etc.
3. **Delete any bundled Script/LocalScript/ModuleScript** — free art smuggles in scripts (backdoor
   risk). EffectsService strips them defensively too, but remove them from the template as well.
4. **Optionally set a lifetime** — add an entry to EffectsService's `LIFETIMES` table, or pass
   `extras.Lifetime`.
5. **Call it from the ability** — `EffectsService:Play("<Name>", position, extras)`.

## `extras` options
- `AttachTo` (BasePart) — the effect welds to and RIDES this part (a limb or a mover). With
  `AttachTo`, `extras.CFrame` is a LOCAL offset from that part. Ride-along parts are made
  massless/non-colliding.
- `CFrame` — world placement/orientation (or local offset when combined with `AttachTo`).
- `Scale`, `Lifetime`, `Parent`.

## Projectile pattern (see Dark Moon)
Create an invisible **anchored mover Part**; `Play` the effect with `AttachTo = mover` and
`Parent = mover` (so destroying the mover cleans up the visual); slide the mover forward each frame
in a `Heartbeat` loop (`startPos + lookVector * (range * t)`). First target within `HitRadius` takes
the hit, then destroy the mover.

## Gotchas
- **Fixed-spot placement re-centers by BOUNDING BOX** so the visual middle sits on the target — most
  templates are built off-center, so without this they look shoved to one side or behind the target.
- **Use `AttachTo` whenever the caster moves** (dashes/lunges) or the effect should track a
  limb/projectile — a world-placed effect on a lunging character ends up sideways/inside the body.
- **Hit radius must match the VISUAL size, not the mover.** Dark Moon's tiny radius only registered
  dead-center hits until it was bumped up to match the big moon.
- To scale a too-small asset, use `Model:ScaleTo` (or multiply a BasePart's `Size`) — and scale
  BEFORE positioning so it still lands where you expect.
