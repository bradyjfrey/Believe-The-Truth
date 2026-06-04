# Plan: Swap to Your Daughter's Hand-Built Character Models

**Decided 2026-06-03.** Goal: stop building character looks + weapons in code, and use
the real models she designed in Studio instead. Keep all the ability/behavior code
(Slash, Breach of Privacy, Stray Blade, Neck Wrap, the dogs, etc.) — we're only
replacing the *appearance*, not the game mechanics.

This is a PLAN, not done work. Nothing was changed in code yet.

---

## The big idea

Right now `CharacterAppearance.lua` welds together fake weapons out of plain Roblox
parts (a katana, a cleaver, a folding fan, Rokurokubi's stretched neck). Those were
always placeholders — the file literally says "TODO when art lands" in a dozen spots.
The art has landed. Her models replace those placeholders.

The models live in the Studio place right now (that baseplate in the screenshot). They
need to come into this git project so the code can use them. Then on spawn, instead of
*building* a look, we *clone* her model.

---

## Step 1 — Get her models into the project (you / the team, in Studio)

1. In Studio, make a folder in **ReplicatedStorage** named `CharacterModels`.
2. Drag each of her models into it. Suggested names (code will look for these exact
   names, so keep them simple and consistent):
   - `GirlA`         — her Girl A character
   - `GirlA_Hatchet` — Girl A's hatchet weapon
   - `Momotaro`      — Momotaro character
   - `Momotaro_Dog`  — one dog (we clone it twice for the two dogs)
   - `Rokurokubi`    — Rokurokubi character
   - (add more as she builds them)
3. Turn on **Argon two-way sync** so Studio changes save back into the `src/` files.
   Brady runs `argon serve` from the terminal — the two-way flag is set there. Once on,
   her models will appear as files under `src/ReplicatedStorage/CharacterModels/` and
   I'll be able to see + edit them.
4. Commit that to git so we have a safe snapshot of her work.

> Until this step is done, I can't see her models from my side at all — Argon only
> pushed files *into* Studio before, never pulled models *out*.

## Step 2 — Tell me how each model is built (when we resume)

This is the one thing I genuinely need to know before writing the swap, because it
changes the approach completely:

- **Are the CHARACTERS (Girl A, Momotaro, Rokurokubi) full Roblox avatars** — i.e. do
  they have a Humanoid and the normal moving joints, so they can walk and be played? Or
  are they static "statue" builds with no Humanoid?
- **Are the WEAPONS + DOGS separate models** (a hatchet model, a dog model), meant to be
  attached to a hand / spawned next to the player?

The screenshot suggests the characters look avatar-shaped (good) and the hatchet/dogs
are separate builds (also good). But I need to confirm, because a playable character in
Roblox needs a Humanoid + a root part, and our whole game already assumes that
(Humanoid HP is a locked-in architecture decision).

## Step 3 — Replace appearance with her models (me, in code)

Once the models are in and I know their structure:

- **Add a small `applyModel` path** that clones her `CharacterModels/<Name>` and uses it
  as the player's look on spawn, instead of the welded-parts code.
- **Retire the placeholder builders** in `CharacterAppearance.lua` (the `SwordInHand`,
  `CleaverInHand`, `FanInHand`, `StretchedNeck`, `Satchel`, `Sash` blocks). I'll keep the
  file's overall shape so it's still the one place you edit looks — it just points at her
  models now instead of building fakes.
- **Attach her weapons** (hatchet, etc.) to the character's hand with a weld, the same way
  the placeholder weapons were attached — so the ability code that already assumes "there's
  a weapon in her hand" keeps working.

## Step 4 — Reconcile the naming (small but worth doing)

Her labels and the code's names don't quite line up. None of this is broken, it's just
worth matching up so the team isn't confused:

| Her label (screenshot) | Code name today        | Plan                                            |
|------------------------|------------------------|-------------------------------------------------|
| "Girl A's hatchet"     | `CleaverInHand`        | Rename the weapon prop to Hatchet, keep ability |
| "Girl A's attack m1"   | `Slash` ability        | Same thing — "m1" = left-click. Wire her effect |
| "Momotaro's dogs"      | one `GuardDog` / Inuta | She drew TWO dogs — decide: two visuals, one     |
|                        |                        | ability? Or does each dog do something?         |
| "Rorokubi" / Rokurokubi| `Rokurokubi`           | Just a spelling fix on her label                |

The one real design question in here: **the dogs.** Code currently spawns one guard dog
(Inuta). She built two. Easy version: two dog visuals, same single ability. We can decide
when we get there — no rush.

---

## What I am NOT doing

- Not deleting anything yet (especially not in Studio — we commit to git first, always).
- Not changing any ability logic / balance numbers (those live in `Constants.lua` and are
  fine).
- Not touching the round system, picker UI, or disguise system.

## First thing to do next session

1. Confirm Step 1 is done (models in ReplicatedStorage/CharacterModels, two-way sync on,
   committed).
2. Answer Step 2 (how the models are built).
3. There's currently an uncommitted change in `CharacterPickerUI.client.lua` — commit or
   stash it first so we start from a clean base.

Then I'll do Step 3.
