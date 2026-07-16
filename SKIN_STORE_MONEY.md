# Skin Store Money — DECIDED

Brady's economy proposal, reviewed and answered by the kids (2026-07-15).
This is now the decided design of record for the store. Nothing here is built yet;
build order is phase-1 free locker (browse + equip + DataStore save), then currency.

## The currency: Omamori

The kids picked **Omamori** (protective charms — on-theme against yokai).
Singular and plural: "20 Omamori."

## How you earn

| What you did | Omamori | Notes |
|---|---|---|
| Finish a round (win or lose) | 5 | Just for playing. Leaving mid-round earns nothing. |
| Your team wins the round | 25 | The big one. Same for Wardens and Yokai. |
| Survive more than 1 minute (Wardens) | 10 | One time per round. |
| Yokai catches someone | 10 | A "catch" = reducing a Warden to 0 HP (elimination — that's the only way anyone goes down in the current game). If a down/revive system is ever built later, the payout moves to the down. |
| Use a move successfully | 2 each | See "what counts" below. Capped at 10 per round. |
| First win of the day | 20 | Kids' addition. Needs a per-player "last win date" saved in the DataStore (same save as the coins). |
| Beat the boss | 40 | Kids' addition — DORMANT until the boss exists. The boss itself (giant skeleton in a hellverse map — Gashadokuro is a real yokai!) is a separate future project on the checklist wishlist. |

A typical round pays roughly 15 to 45 Omamori.

**What counts as "using a move successfully":** the move has to actually do
something to somebody. Katana hits a Yokai: counts. Katana swung at air: doesn't.
Kibi Dango heals a hurt teammate: counts. Healing someone at full health: doesn't.
A banana peel someone actually slips on: counts.

**Why the cap on move money:** without a cap, two friends stand in the lobby
cheesing until they're rich. The cap with cooldown keeps people from farming
without playing the game.

## How you spend

Skins come in three tiers (kids approved):

| Tier | Price | How long to earn it |
|---|---|---|
| Common skin (color swap, small change) | 150 | Around 5 rounds |
| Cool skin (new outfit, like Token) | 400 | Around 12 to 15 rounds |
| Rare skin (full transformation, like Toastful) | 900 | Around 25 to 30 rounds |

Your first skin should come fast (one good play session) so the store feels
alive. The fanciest skins should take long enough that wearing one means something.

**Future spending (kids' picks, skins first):** whiteboard marker colors, taunts, and emotes.

## Rules that keep it fair

1. Omamori are per player and saved forever (leave and come back, still yours).
2. Both teams can earn about the same per round, so nobody is forced to play
   killer (or forced not to) just to afford things.
3. Skins never change stats. A 900 Omamori skin plays exactly like the free look,
   but looks unique.
4. Prices and payouts are all in one settings list (Constants.lua), so changing
   "25 for a win" to "30 for a win" takes ten seconds, not a rebuild.
5. No Robux, no real money, ever — in-game earned Omamori only.

## Kids' answers (2026-07-15, for the record)

1. Currency name? **Omamori.**
2. Payout numbers right? **"They are correct."**
3. Three price tiers right? **Yes.**
4. Bonuses? **First win of the day = 20; beating a boss = 40** ("a giant skeleton
   boss in a hellverse map").
5. Spend on things besides skins? **Marker colors, taunts, and emotes.**
6. What counts as a Yokai catch? **"A downed"** — confirmed with Brady this means
   what the game already does (0 HP = out for the round); nothing new to build.
