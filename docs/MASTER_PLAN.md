# Master Plan — Dance Dance Step

> **The bet.** A mastery-driven rhythm dance game for Roblox: read the floor, stand on the beat, and climb from slow-walking beginner songs to insanely fast expert charts — in a dreamy sky-concert world where your outfit shows everyone exactly how good you are. Skill is the product; cosmetics are the receipt.

**Name.** Working title *Dance Dance Step*; the pitch decks call it *Encore*. Both stay until a final name is picked.

*Companions: `PLAYER_PROGRESSION.md` (full progression spec), `UI_REQUIREMENTS_CORE_LOOP.md`, `HUB_LAYOUT.md`, `SELLING_ANIMATIONS.md`, `OPEN_QUESTIONS_AND_RISKS.md`, `MILESTONES.md`. Core loop mechanics live in the Core Gameplay & Patterns GDD; in code they live in `RhythmService.server.luau` and `Shared/Timing.luau`.*

## Design pillars

1. **Mastery you can feel.** Difficulty = movement pressure. Easy songs walk slow; expert songs demand near-perfect routing at speed. Every rank-up is earned and displayed.
2. **Waiting is rewarded, chasing is punished.** The stand-on-beat core loop (see GDD) stays sacred at every difficulty — speed raises the routing challenge, never the input noise.
3. **Show, don't tell status.** Every meaningful achievement has a visible form: crowns on songs, grades on nameplates, swag on bodies, avatars on podiums.
4. **Official items play the game with you.** Our catalog items carry in-game animation + VFX hooks (petal trails, perfect-hit bursts). UGC items carry breadth and community. Both markets thrive because they sell different things.

## System map by milestone

**M1 — First Public Test (core loop + skeleton progression)**

- Core gameplay: 5×5 floor, stand-and-wait judging, travel windows (shipped ✅)
- Song list with per-song, per-difficulty **crowns** (Clear / Full Groove / Perfect Groove)
- Player XP + level with first-15-levels reward table
- Soft currency (Beat Coins) + run rewards by rank
- Leaderboards: weekly + all-time, top-3 podium avatars in hub

**M2 — Beta (mastery engine + economy)**

- **Dance Grades** (Taiko Dan-i-style 3-song rank courses) with nameplate display + exclusive swag
- Special items (consumables) + item shop; walk-speed difficulty curve tuned across the four difficulties
- Official cosmetics catalog v1: shoes/swag with gameplay VFX; gacha crates
- Song unlock economy (crown points gate song packs)
- Coop/PvP first social mode

**M3 — Launch+ (UGC + live ops)**

- **UGC Runway Market**: player stalls in hub, browse/try/buy as outfits walk past
- Weekly song drops; seasonal grade resets + seasons of swag
- Events: themed stages, licensed idol collabs (parked — licensing)

*Note: these product milestones (M1–M3) are the game's roadmap. The contract milestones that trigger payments are a separate list in `MILESTONES.md`.*

## Core loop across rings

| Ring | Timescale | The reward |
| --- | --- | --- |
| Beat | seconds | Perfect/Great pops, combo climbing, tile VFX |
| Song | 3–4 min | Rank + crown progress + coins + XP; "one more song" |
| Session | 20–40 min | Level-up unlock, crown-point milestone, daily quests, gacha pull |
| Day | daily | Daily quest chain, featured song bonus, streak reward |
| Week | weekly | Leaderboard settle + podium placement, new song drop, weekly quest |
| Long | months | Dance Grade climb, song-pack completion, catalog collection, season titles |

Every ring has a visible next-goal signal: next crown, next level reward (always previewed), next grade course, next song pack.

## Reward economy outline

Two mastery tracks (full spec in the Progression doc):

- **Song Mastery** (breadth): crowns per song per difficulty → crown points → **new songs + achievements → leaderboard position**. Content + Status.
- **Level Mastery / Dance Grades** (depth): rank courses → grade on nameplate → **exclusive special items + swag**. Power + Expression + Status.

Currencies: **Beat Coins** (soft, earned by playing) · **Robux** (hard, cosmetics/gacha/convenience) · **Fans** (mastery meta-currency, never purchasable).

Rule (from the Grass Valley lens): every level and grade unlocks something the player can *see, use, or show off* — never a bare stat.

## Dependency / critical path

1. Core loop ✅ → 2. Crowns + XP/levels + coins (M1, unblocks everything) → 3. Leaderboard + podium (M1, live) → 4. Grade courses (M2, needs 12+ songs at 3 difficulties) → 5. Item system + shop (M2) → 6. Gacha + official catalog (M2) → 7. UGC market (M3, needs healthy official catalog first) → 8. Seasons (M3).

**Sequencing logic:** official catalog ships *before* UGC market — the official items establish that cosmetics have gameplay presence (animation/VFX), so UGC arriving later reads as "more variety" rather than "the whole catalog."

## Structural decisions to make first

1. **P2W stance (gates item + shop design).** Current call: consumable helper items are buyable with coins AND Robux — casual-friendly, Roblox-normal. **Guardrail: leaderboards and Dance Grade courses run items-off (or flagged "assisted").** Mastery displays stay pure-skill; convenience sells without corrupting status. This keeps "open to pay-to-win" commercially real while protecting the thing that makes status worth buying into.
2. **Song unlock model (gates content pacing).** Recommended: small free rotating set + crown-point-gated packs + occasional coin/Robux instant unlock.
3. **UGC platform mechanics** (M3 but affects hub layout now): stall count, placement, upload flow — see Progression doc §6.

## Milestone experience goals

- **M1:** "I cleared my first songs, hit level 8, saw my name on the weekly board — and I know exactly what the next three unlocks are."
- **M2:** "I'm grinding gold crowns to unlock the next pack, running my first Grade course for the exclusive aura, and I bought slow-time charms for that one brutal song."
- **M3:** "I sell my own outfit at my stall, wear a rainbow-crown title, and log in Mondays to defend my podium spot."

## Open decisions (ranked)

1. Leaderboard purity rule — confirm items-off for ranked/graded play (recommended above).
2. Song unlock model — crown-gated packs vs free-with-rotation vs hybrid.
3. Gacha odds + pity system, and Roblox policy compliance pass.
4. Grade course count + names at Beta (proposal in Progression doc).
5. Licensed characters/collabs — parked until licensing strategy exists.
6. Offline/absence hook — what pulls a lapsed player back (daily streak insurance? weekly free crate?) — deliberately thin right now, revisit at M2.
