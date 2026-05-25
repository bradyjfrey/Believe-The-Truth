# Believe the Truth — Planning Doc

**Game:** Believe the Truth (Shinjitsu Shinji, 真実信じ)
**Platform:** Roblox (PC + Mobile)
**Genre:** Asymmetric horror — Wardens (survivors) vs. Yokai (killers)

This is the living spec. When the team changes how something works, update this file. It's the source of truth — code reads from `Constants.lua`, but if `Constants.lua` and PLANNING.md disagree, PLANNING.md wins and we change the code.

---

## How a round works

The Wardens have been summoned to protect cursed Inunaki City. They complete Errands around the map. The Yokai try to kill them. Last team standing wins.

### Round flow (this build)

1. **Lobby** — players join a server. Once there are at least 2 players, a lobby timer starts. When it ends, a round begins.
2. **In round** — the game randomly picks 1 player to be Yokai. Everyone else is a Warden. If the chosen Yokai owns more than one Yokai character, they get to choose which one to play. Same idea will apply to Wardens later when there's more than one Warden character.
3. **Win conditions:**
   - **Wardens win** when all Yokai are dead OR the round timer runs out (they survived).
   - **Yokai win** when all Wardens are dead.
4. **End** — short pause, then back to lobby. Everyone respawns.

### Death

When a player dies mid-round, they spectate until the round ends. They don't respawn until the next round.

### Friendly fire

- Wardens can't hurt other Wardens.
- Yokai can't hurt other Yokai.

### Numbers

| Setting | Value |
| --- | --- |
| Minimum players to start | 2 |
| Lobby countdown | 20 seconds |
| Round length | 5 minutes |
| End-of-round pause | 5 seconds |

---

## Characters in this build

Three characters in scope. Momotaro and Rokurokubi are **starter** characters every player owns automatically. Girl A is **paid** (1,255 coins) — for the first playtest she's playable by everyone so we can test her, but eventually only owners will get her.

| Character | Team | Starter? |
| --- | --- | --- |
| Momotaro | Warden | Yes (auto-granted) |
| Rokurokubi | Yokai | Yes (auto-granted) |
| Girl A | Yokai | Paid (1,255 coins) |

---

## Movement & speed

Roblox's default walk speed is 16. We're a little faster so the game feels snappier. Every character has a Sprint key (hold Shift) except where noted. Yokai are always faster than Wardens.

| Character | Walk | Sprint / Run | Notes |
| --- | --- | --- | --- |
| Momotaro (Warden) | 20 | 28 | Hold Shift to sprint |
| Rokurokubi | 25 | 33 | Hold Shift to sprint — she can stalk slow or chase fast |
| Girl A | 21 | 30 | Hold Shift to sprint. Incognito Mode boosts her to 39. |

---

## Momotaro

> "On a quest to conquer the Oni."

**Class:** Multiclass (Support + Stunner)
**HP:** 110
**Cost:** 900 Coins (free for everyone in this build)

Born from an oversized peach and blessed by the gods, the legendary Momotaro is prepared for any foe. Tagging along to help him are Inuta the dog, Sarumi the monkey, and Kijiro the pheasant.

### Passive — Bird's Eye View

> "It is a great advantage for us to have you with us, for you have good wings." — Momotaro

Kijiro the pheasant follows Momotaro and highlights all Yokai (anywhere on the map) every 45 seconds, for 6.5 seconds.

### Q — Katana (25s cooldown)

> "Go with all care and speed. We expect you back victorious!" — Momotaro's Mother

After a 0.5-second windup, Momotaro swings his katana and dashes forward 30 studs. Any Yokai caught in the swing takes 15 damage and is stunned for 3 seconds. The dash stops at walls. It can hit multiple enemies in its path.

### E — Guard Dog / Inuta (30s cooldown)

> "You are a rude man to pass my field without asking permission first." — Inuta the Dog

Inuta drops at Momotaro's feet and stands guard. He detects Yokai within 50 studs. While they're in range, he barks for 1–5 damage every second and slows them by 50%. Inuta has 40 HP. He returns to Momotaro when his HP hits 0 OR after 60 seconds.

### R — Messy Eater (15s cooldown)

> "I heard of your expedition to Onigashima, and I have come to go with you." — Saru the Monkey

Saru briefly appears, eats a banana, and drops the peel where he was standing. Any Yokai who steps on it gets ragdolled for 2 seconds. The peel disappears after being stepped on or after 60 seconds.

### F — Kibi Dango (20s cooldown)

> "Union amongst ourselves is better than any earthly gain." — Momotaro

Momotaro eats a stick of kibi dango to heal 30 HP himself. If a Warden teammate is within 5 studs, the dango goes to them instead and heals 40 HP. Kibi Dango also cures any bleed effects — Rokurokubi's bite, Girl A's stray blade, anything.

---

## Rokurokubi

> "may death do us part.."

**HP:** 2000
**Walking speed:** 25 (Shift to sprint up to 33 — faster than Warden sprint)
**Cost:** Free (starter Yokai)

A long-necked demon born from waste, eating out of hunger; later evolved to feast on humans. Description from the team: *on trails to murder, to starvation, till death do us part, I wish you luck..*

### Passive — Hidden Hunger

When Rokurokubi is within 40 studs of a Warden, that Warden hears a low, terrifying stomach growl. Her own body gives her away.

### Q — Neck Wrap (29s cooldown, 2s windup)

She shoots her neck out and wraps around the nearest Warden in front of her. The victim is stuck and can't move. They take 2 HP per second while trapped, up to 60 seconds max.

**Escape:** mash space (PC) or tap the on-screen escape button (mobile) — **11 presses** to break free.

**Teammate help:** if another Warden hits Rokurokubi (e.g. Momotaro's Katana), the wrap breaks immediately.

| Detail | Value |
| --- | --- |
| Range | 30 studs (spec says 3 but that's melee — using 30; tune freely) |
| Damage per second | 2 |
| Max wrap time | 60 seconds |
| Mash count to escape | 11 |

### M1 (left click) — Bite (1s cooldown, 0.3s windup)

Up-close melee bite that causes Bleed: 2 HP/sec for 10 seconds. Biting again refreshes the bleed timer; she can stack bleed up to **2 times**. Bite always breaks her disguise.

### R — Disguise (20s cooldown, 5s charge-up, lasts 19 seconds)

A picker UI opens — Rokurokubi taps any in-round Warden (including dead ones) to copy. After the 5-second charge-up, she takes on that Warden's full appearance (body + name).

**During charge-up she is frozen** and can't move.

**While disguised:**
- She can see all Wardens through walls (highlighted to her only).
- Her eyes glow briefly every few seconds — that's the tell Wardens can spot.
- Taking any damage breaks the disguise.
- Using Bite breaks the disguise.
- She can do Errands like a real Warden, but she can also sabotage them.
- Inuta the dog still detects her (dogs aren't fooled).

### Q while disguised — Strangle (no cooldown, drops disguise on use)

She grabs the nearest Warden by the throat for 2 seconds. Deals 1 HP per second (2 damage total). A teammate hitting her interrupts. Victim can't fight back.

### Fairness checks (from the team's worksheet)

| Situation | Outcome |
| --- | --- |
| Momotaro Katana hits Rokurokubi while she's wrapping | The wrap breaks |
| Inuta detects disguised Rokurokubi | Yes, dog still barks |
| Kibi Dango on a bleeding teammate | Cures bleed completely |
| Warden vs. Neck Wrap | Mash to escape, or get freed by a teammate |
| Warden vs. Bite | Dodge or hide behind cover |
| Spot disguised Rokurokubi | Watch for the eye glow |

---

## Girl A

> "Do you like the red room?"

**HP:** 1700
**Walk speed:** 21
**Run speed:** 30 (Shift to sprint)
**Cost:** 1,255 coins (paid)

The corpse of an elementary school girl reprogrammed by an AI parasite. Her body warped and distorted, she has one goal: to satiate her constant hunger for bloodshed.

### Passive — Auto Connect

Hotspots are placed around the map at round start (4 placeholder spawns for now; will be repositioned by the team in Studio later). Girl A can teleport to any Hotspot by clicking it **while in Incognito Mode**. Wardens can deactivate Hotspots by completing a task — the tasks haven't been built yet ("building library books" or "collecting spirits" are candidates).

### M1 (left click) — Slash (1.5s cooldown)

> Range: 10 studs · Damage: 15

She lunges forward slightly with her cleaver, hitting any Warden caught in the swing for 15 damage.

### Q — Breach of Privacy (25s cooldown)

> "This ad blocker doesn't do jack!" — Anonymous RRC victim

A pop-up appears on a **completely random** Warden's screen for 7 seconds. While the pop-up is up:
- Girl A sees that Warden highlighted through walls.
- Girl A is slowed (Slowness 1).
- If the Warden closes the pop-up early, they take 25 damage. If they wait it out, no damage.

### E (hold) — Stray Blade (10s cooldown)

> "You think you're safe?" — Girl A

Hold E to aim — Girl A's movement drops by 25% while aiming. Release E to throw her cleaver forward up to 30 studs over 1 second. First Warden hit takes 35 damage and starts Bleeding 1. The cleaver stops on walls. **The cleaver always returns to her** when the throw ends.

### R — Incognito Mode (15s cooldown, 8 seconds duration)

> "Your privacy is a farce." — Girl A

Girl A goes invisible to **all other players** (Wardens and other Yokai). She moves at 1.3× her run speed (39). The 3 nearest Hotspots are highlighted to her — clicking any teleports her there and ends Incognito. Pressing R again also ends Incognito early.

---

## Map ideas

Possible round maps (from the design doc):

- **Aokigahara (The Suicide Forest)** — misshapen trees players can walk along to reach high ground
- **Maruoka Castle** — pillars of flesh inflict status effects when touched
- **The Red Room** — virtual pocket dimension with teleporters and secret passages

---

## Roster (full)

These are the planned characters. The bolded ones exist in code today; the rest are TBD.

**Wardens (Survivors)**
- Otohime
- **Momotaro** ← shipping
- Kintaro
- Hase
- Kaguya
- (3 unnamed slots)

**Yokai (Killers)**
- Chika (The Slit-Mouthed Woman)
- Yasaka (The Eight-Foot-Tall Woman)
- Tomino (Tomino's Hell)
- **Girl A** (The Red Room Curse) ← shipping
- Okiku the Doll
- **Rokurokubi** ← shipping

---

## Architecture decisions (locked)

These are set — don't change without a team discussion.

- **Platform:** PC + mobile (touch buttons via `ContextActionService`)
- **Polish:** Minimum viable; easy for kids to read and tune
- **HP:** Roblox's built-in `Humanoid.Health` and `Humanoid:TakeDamage`. No custom HP system.
- **Round state:** Real `RoundService` (not a stub) with clear extension points for errands and citizens
- **Disguise target:** Picker UI showing all in-round Wardens
- **Companions:** Placeholder Parts (brown for Inuta, yellow for Saru). Code checks `ReplicatedStorage/Companions/<name>` first — drop in a Model there and the code uses it instead, no code change needed.
- **VFX/SFX:** Single `EffectsService` module with empty hook functions. Abilities call `EffectsService:Play("EffectName", position)`. The art team fills in the hooks later.
- **Bleed:** One shared `BleedService` (not per-character) — Kibi Dango clears all sources with one call.

---

## File layout

```
src/
├── ReplicatedStorage/
│   ├── Shared/
│   │   ├── Constants.lua         (every tunable number)
│   │   ├── AbilityModule.lua     (cooldown helpers)
│   │   └── Types.lua             (team & character name constants)
│   ├── Remotes/                  (RemoteEvents folder, created at runtime)
│   └── Companions/               (drop Inuta/Saru models here)
├── ServerScriptService/
│   ├── Services/
│   │   ├── RoundService.lua      (lobby/round/win loop)
│   │   ├── AbilityService.lua    (validates and dispatches ability calls)
│   │   ├── EffectsService.lua    (empty hooks for art team)
│   │   ├── DisguiseService.lua   (Rokurokubi morph)
│   │   └── BleedService.lua      (shared bleed-over-time)
│   ├── Characters/
│   │   ├── Momotaro.lua
│   │   ├── Rokurokubi.lua
│   │   └── GirlA.lua
│   └── Bootstrap.server.lua      (wires it all together)
└── StarterPlayer/
    └── StarterPlayerScripts/
        ├── AbilityInput.client.lua     (keybinds + mobile buttons)
        ├── DisguisePickerUI.client.lua (Rokurokubi target picker)
        ├── BreachPopup.client.lua      (Breach of Privacy popup on the target)
        ├── Sprint.client.lua           (hold-Shift run)
        └── Incognito.client.lua        (renders Girl A invisible locally)
```

---

## Open questions / TODOs

Things the team should decide as they playtest. Not blockers for the first build.

- [ ] **Errands** — what does a Warden errand look like? ("Building library books", "Collecting spirits" are candidates)
- [ ] **Citizens** — non-player NPCs the Yokai also target
- [ ] **Real shop & coin economy** — Girl A is gated by ownership in the long run
- [ ] **Real Hotspot placements** — replace the 4 placeholder spawns
- [ ] **Real companion models** — drop Inuta and Saru models into `ReplicatedStorage/Companions/`
- [ ] **VFX/SFX hooks** — fill in `EffectsService` for each effect name
- [ ] **Voice lines for Girl A** (Fiona's idea)
- [ ] **Real disguise tell** — "eyes glow every few seconds" is currently a red outline; replace with a proper eye-only glow when art's ready
- [ ] **Per-client Bird's Eye highlights** — currently every player sees the highlights; only Momotaro should
- [ ] **Pre-round character picker UI** — when a player owns more than one character on their team

---

## Tuning numbers

All tunable numbers live in `src/ReplicatedStorage/Shared/Constants.lua`. Change a number, hit save, Argon syncs to Studio. Kids can tune without touching any other file.
