# Selling Animations — Monetization × Core Gameplay

> **The idea.** Animations — poses, dances, entrances, and timed/achievement FX — are our most on-brand sellable content, because in a rhythm game the flex moment is mid-performance. This doc defines what we sell, where each animation fires inside the core loop, and how it feeds progression.

> Reference (from Nya — "animations, poses, and timed/achievement FX, super fun energy"): https://youtu.be/iBgs3uiBqO4

## 1. The catalog — five animation product families

| Family | What it is | Fires when | Sellable? |
| --- | --- | --- | --- |
| **Entrance animations** | Your walk-on when the match loads | Song start, all players watch | Shop + gacha (premium) |
| **Victory poses** | Struck on the results screen + share card | Song end / photo card | Shop + gacha |
| **Timed FX (achievement FX)** | Auto-fire visual bursts tied to play: Perfect-hit burst, combo-milestone flare (x10/x25/x50), full-combo finale | **During gameplay, triggered by performance** | Shop + gacha + grade exclusives |
| **Emotes / signature dances** | Manual expression in hub + between songs (emote wheel) | Player-triggered | Shop + gacha + UGC-adjacent |
| **Idle poses** | How you stand in hub / on podium plinths | Passive, always visible | Shop; podium poses = status |

## 2. Integration into the core loop (the important part)

The rule from the SSOT stays: **no animation grants score.** They are performance *decoration* — but tied to performance, which is what makes them desirable:

- **Beat ring (seconds):** equipped Perfect-hit FX fires on every Perfect — owning a better burst makes *good play look better*. This is the moment-to-moment sell.
- **Song ring:** combo-milestone flares at `x10/x25/x50` — visible to coop partners/PvP opponents. Full-combo finale plays only on a no-miss run: **an animation you can only show if you're good.** That's the genius of achievement FX — the item is a proof-of-skill display.
- **Session ring:** results-screen victory pose + share card (social export).
- **Status ring:** podium plinths play your idle pose + aura for everyone in the hub; Legend-grade entrance is never sold, only earned.

## 3. Acquisition mix (three doors, one catalog)

1. **Bought** (Robux / coins): the broad catalog — entrances, poses, standard FX tiers. This is the revenue line.
2. **Earned** (grades/achievements): exclusive tiers that money can't buy — grade auras, full-combo finales per song pack, Legend entrance. Protects status credibility, which protects the *value* of bought items.
3. **Gacha:** seasonal FX sets with rarity tiers; duplicates convert to coins. The variable-reward hook.

**Official-only rule holds:** gameplay-fired animations/FX are exclusively official catalog (UGC stays cosmetic-static, hub-only) — this is the moat that keeps our catalog deep and premium next to a UGC market.

## 4. Production notes (for Nya / animation pipeline)

- Timed FX are **short** (`≤ 0.5s` bursts) and must never occlude the next telegraph — same constraint as judgement VFX in the GDD.
- Entrances `≤ 3s`, skippable server-side on repeat.
- Rig-agnostic: build on the standard R15 rig until the avatar fork is final.
- Each family needs a **preview surface** in shop + wardrobe (the UI brief includes VFX preview in item detail).

## 5. Open decisions

1. Emote wheel size (2 slots at Lv7 → grow with levels?).
2. Can FX be equipped per-slot (Perfect burst + combo flare + finale separately) or as one "FX set"? Recommend slots — more collection depth, more sales.
3. First sellable set at M2: propose `2` entrances, `3` victory poses, `2` Perfect bursts, `1` full-combo finale, `4` emotes — confirm with Nya's capacity.
4. Pricing pass once coin economy is tuned.
