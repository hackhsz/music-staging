# Player Progression & Mastery — Spec

> **Built so far.** Levels are replaced by Ranks: the table, XP values and rank-up songs are in `Shared/Catalogs/RankCatalog.luau`, which wins over the level table below. Crowns, Fans and mastery are not built.

> **What it is.** The full progression system: how difficulty scales, the two mastery tracks (modeled on Taiko no Tatsujin's crowns + Dan-i Dojo), special items, the level reward table, and how UGC and official cosmetics coexist. Written for AK to build against. Tunable numbers are in `code` and are starting points, not finals.

## 1. The difficulty axis: movement pressure

**Player experience.** Easy songs feel like a relaxed walk — targets are near, windows are long. Hard songs feel like choreography at sprint speed — long travel distances, short windows, dense patterns. The input never changes; the *routing pressure* does.

**Rules & parameters.** Difficulty raises movement pressure via the GDD's existing dials — travel window `W` (4/2/1 beats), target distance (up to `W−1` tiles), pattern density, BPM (`70–140`) — plus one new dial: **walk speed tiers**. There are **four difficulties** (decision 2026-10-18). Code ids and judgement windows live in `Shared/Timing.luau`, which owns every number:

| Difficulty | Code id | Feel | W | Avatar step time | Distances |
| --- | --- | --- | --- | --- | --- |
| Easy | `easy` | stroll | 4 | `140ms` relaxed | 1 tile |
| Normal | `normal` | walk/dance | 2 | `120ms` | up to 2 tiles |
| Hard | `hard` | sprint | 1 | `100ms` snappy | up to 2, dense |
| Expert | `expert` | insane | 1 | `90ms` | up to 2, near-continuous |

Hard and Expert share W = 1; Expert separates from Hard by tighter judgement windows (Perfect 55 ms vs 65 ms), higher density and the step-time snap. The step-time column is a design target and was not found in `Timing.luau`; check that it exists in code before relying on it. The expert numbers are a first guess and need playtesting.

The old 1–5 star scale is now a **per-song rating** shown in song select (how hard that chart is within its difficulty). It is not a separate difficulty ladder.

At Hard and Expert perfect play requires either mastery **or special items** — that overlap is deliberate: it's where the item economy earns its keep.

**Interlocks.** Difficulties gate crown tiers; crown points gate song packs; grade courses sample fixed difficulties.

## 2. Track A — Song Mastery (crowns)

*Taiko model: silver/gold/rainbow crowns per song per difficulty (crown system).*

**Rules.** Every song × difficulty stores your best result as a crown: **Clear** (finish with life remaining) · **Full Groove** (no Miss) · **Perfect Groove** (all Perfects). Crowns win **Fans**: `1 / 2 / 3` per crown tier (upgrades award the difference). Fans are a lifetime mastery meta-currency — **never purchasable, never spent**; they only unlock.

**Unlocks (Content + Status).** Song packs unlock at Fan thresholds (`8 / 20 / 40 / 70…` — pack of 4–6 songs each). Achievements fire on collection milestones ("gold-crown one full pack"). **Leaderboards:** weekly per-song score boards + an all-time Fans board; top-3 avatars display on hub podiums.

**Serves rings.** Song (crown progress), session (point milestones), week (board settle), long-term (collection).

**Variable reward.** Run-end crate odds improve with rank (S-rank doubles rare odds) — the slot-machine moment lands on the results screen.

## 3. Track B — Level Mastery: Dance Grades

*Taiko model: Dan-i Dojo — fixed 3-song gauntlet courses with conditions; rank displays on your nameplate; each clear awards a costume (Dan-i Dojo).*

**Rules.** A Grade course = `3` songs back-to-back at fixed difficulty with pass conditions (e.g. "≥ 85% acc total, ≤ 10 Miss across all three, no items"). Fail any condition → course over, retry freely (`cooldown: none` at first; consider daily attempts for top grades). **Items are disabled in courses** — grades are pure skill, that's what makes the swag mean something.

**Grade ladder (proposal, 10 ranks):** Trainee I–III → Rising Star I–III → Idol I–II → Superstar → **Legend**. Grade shows on nameplate + leaderboard rows + podium plinths.

**Unlocks (Expression + Status + Power-adjacent).** Every grade awards an exclusive, never-sold item: grade-tinted aura trail → exclusive shoes w/ signature VFX → animated nameplate → entrance animation (Superstar) → Legend crown aura + hub statue eligibility. Early grades also grant item-slot capacity (`1→2→3` consumable slots) — the one power-ish reward, and it comes from skill, not money.

**Serves rings.** Session (attempts), long-term (the climb). **Depends on** 12+ songs across difficulties → M2.

## 4. Special items (consumables)

**What they are.** Run-scoped helpers for the speed wall at Hard and Expert: **Slow-Time Charm** (song `−8%` speed, score `×0.8`) · **Step Magnet** (auto-pull to target from 1 tile away, `×0.85`) · **Groove Shield** (absorb `3` Misses, combo survives, `×0.9`) · **Double Coins** (`×2` coins, score unchanged) · **XP Boost** (`×1.5`).

**Economy + P2W stance.** Purchasable with **Beat Coins AND Robux** — convenience is sellable (open-to-P2W honored). **Guardrails:** score multipliers < 1 on helpers (assisted clears never outscore clean ones); items **off** in Grade courses; ranked weekly boards run clean-only (or assisted runs flagged with an icon). You can buy your way *through* content, never *onto* the podium.

**Interlocks.** Coins (play) → items → harder songs → crowns → packs → more play. Robux → items/gacha → same loop, faster.

## 5. Player level & XP — first 15 levels

XP per run = `base 40 + rank bonus (S:60/A:40/B:25/C:10) + first-clear 50`. Every level unlocks something visible (Power/Content/Expression/Status — never a bare stat):

| Lv | Unlock | Type |
| --- | --- | --- |
| 2 | Daily quests board | Content |
| 3 | First aura trail (starter) | Expression |
| 4 | Item shop + 1 consumable slot | Power |
| 5 | Normal difficulty + Sakura Sneakers (petal-step VFX) | Content+Expr |
| 6 | Gacha crate access + 1 free pull | Content |
| 7 | Emote wheel (2 slots) | Expression |
| 8 | Weekly leaderboard eligibility | Status |
| 9 | Hard difficulty | Content |
| 10 | **Dance Grades unlock** + nameplate | Status |
| 11 | Photo mode + result-share card | Expression |
| 12 | 2nd consumable slot | Power |
| 13 | Expert difficulty | Content |
| 14 | Styling mirror wardrobe presets | Expression |
| 15 | "Contender" title | Status |

Difficulty unlock levels (5 / 9 / 13) are carried over from the old star ladder and need a re-tune now that there are four difficulties. Level cap soft at `50`; post-15 cadence: cosmetic/status every level, capacity every ~5.

## 6. UGC market vs. official catalog

**The positioning problem.** We want a player UGC economy (longevity engine — the Farming Simulator lesson: community content keeps games alive for years) without hollowing out our own deep catalog.

**The answer: two different products.**

- **Official catalog sells performance.** Only official items get **gameplay hooks**: step VFX, perfect-hit bursts, combo auras, entrance animations, equip-effects live during songs. Sold via direct shop + gacha; earned via grades/achievements. Deep, curated, seasonal.
- **UGC sells identity.** Player-made clothing/accessories — cosmetic-only by policy (no gameplay VFX hooks). Infinite breadth we could never author.

**The venue: Runway Market (M3).** A hub zone of player **stalls** ("shop-it" model): creators rent/claim a stall, upload their Roblox UGC items to its rack; shoppers browse stalls, **try-on in the styling mirror**, buy on the spot as people come and go. Featured-stall rotation weekly (curation + discovery); creator leaderboard by sales. Stall rental in Beat Coins (small sink); sales revenue via standard Roblox UGC commissions.

**Why officials stay premium:** in a rhythm game the flex moment is *mid-performance* — and only official items animate there. UGC owns the hub; officials own the stage. The catalogs compound instead of competing.

**Open question for AK:** stall implementation — Roblox Marketplace deep-links vs in-experience merchant surfaces; needs a policy check on in-experience UGC selling.

## 7. Design-lens check

- Nested rings ✓ (each system tagged) · Interlocks ✓ (coins→items→crowns→packs; grades→slots; UGC→hub traffic→social proof) · Variable reward ✓ (rank-scaled crates, gacha) · No dead-end systems · Every level unlocks a visible thing ✓ · Next-goal always previewed ✓ · Monetization: convenience + cosmetics + gacha, with skill-purity guardrails on status ✓

## 8. Open decisions

1. Assisted-run handling on weekly boards: separate board vs flag icon vs clean-only. (Recommend: flag icon at M2, revisit.)
2. Grade attempt limits for top ranks (daily cap adds weight; none adds accessibility).
3. Gacha: pity counter + duplicate handling (convert to coins?) + Roblox compliance pass.
4. Song pack thresholds tuning (`8/20/40/70`) once we know real crown velocity.
5. Runway Market policy check + stall count for M3.
6. Whether Expert requires items for average players by design, or must be clean-clearable by top skill (I recommend: always clean-clearable — items compress the gap, never define the ceiling).
