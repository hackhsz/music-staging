# Open Questions & Risks

## Resolved 2026-10-18

Decisions made while reconciling the docs with the code:

- **Difficulty count** (Encore deck conflict 1): four difficulties — Easy, Normal, Hard, Expert. Code ids `easy`, `normal`, `hard`, `expert` in `Shared/Timing.luau`; `LifeGauge` has a matching profile for each. The old 1–5 stars are a per-song rating, not a difficulty ladder. Charts that said `easy` were silently falling back to Normal timing because only `beginner` existed; that is fixed.
- **How a step is played** (conflict 2): stand-and-wait, as in the GDD and the code. The arrow buttons in the decks are the movement d-pad, not tap-on-the-beat input. The decks should be corrected.
- **Name** (conflict 4): *Dance Dance Step* is the working title and *Encore* the pitch name; both stay until a final name is picked.

## Resolved 2026-10-19: multiplayer floors

- **Floor model:** every player gets their own 5x5 floor, side by side (`Board.originFor`). The shared
  5x10 floor is not being built. One player has the centre floor to themselves.
- **Player cap:** two players first (1v1 and 2-player co-op). Floors are slots in a row, so 2v2 is more
  slots, not a redo.
- **Rival view:** the rival's floor is shown live as a ghost floor, and their grades flash on it as the
  server reports them (`RivalResult`).

- **Shared start:** in a match the host (player 1, who queued first or hosted the party) picks the song,
  and the server starts it for both players on one start time. Restart is the host's too, and a rematch
  replays the host's last song automatically. Pause stays off in a match.

Still open for multiplayer:

- **No ready check.** The song starts for the guest as soon as the host picks, with the countdown as the
  only warning. A guest in the shop or settings is pulled into the run.
- **A song locked for the guest is rejected silently.** The host's pick does nothing and no one is told why.
  It needs a message, or the song list should grey out songs the guest does not own.
- **The host can strand a guest** by picking a song they dislike. A vote or a swap each round is the
  alternative if that feels bad in playtests.
- **The rival's telegraph is not shown**, only their grades. It needs both players on the same chart.
- **Collision:** two avatars on separate floors never overlap, but nothing yet stops a player stepping
  onto the other floor.
- **Teams:** 2v2 and bots filling empty seats need more slots and a seat-assignment rule.

## Open Questions

- Final game name / title (see above).
- Core concept and pitch.
- Expert tuning: the windows (Perfect 55 ms) and life drain are first guesses and need playtesting.
- Difficulty unlock levels (5 / 9 / 13) were carried over from the five-star ladder and need a re-tune.

## Risks

*TBD.*

## Conflicts raised by Zhong's design pass — 2026-09-21

Three of Zhong's notes contradict something already written. Recorded, not resolved — each needs a person to pick a side.

1. **UI style vs. the approved art board.** Zhong: the UI is "too pastel, not modern." Environment Art Direction — Reference Board makes saturated candy-pastel the north star — Bubblegum `#FF7FBF`, "鲜艳，但不刺眼," rounded soft forms. One of the two moves. If the hub keeps the pastel board and only the UI chrome goes modern, say so explicitly, or the artists will get contradictory briefs. Owner: Zhong, with the UI designer once they are back.
2. **An A-to-B speed power-up vs. the difficulty axis.** Zhong wants a skill that moves the avatar faster between tiles. Player Progression & Mastery §1 makes avatar step time (`140ms` → `90ms`) the difficulty dial itself. A purchasable speed item sells difficulty reduction directly, which §4's guardrail (`score ×<1` on all helpers) contains but does not resolve. Decide whether speed is a tunable the player can buy at all. Owner: Zhong + ak.
3. **Smooth dance animation vs. discrete tile stepping.** Zhong: movement is stiff — "A to left, A to right, left left." That stiffness is the `90–140ms` snap that makes the timing window readable. Smoothing the interpolation without moving the judgement window is the narrow path; anything more trades accuracy legibility for looks. Owner: Nya + ak.

## Open questions added by the same pass

- Rewarded ads: allowed under Roblox policy at our age rating, and at what frequency? Nothing is designed against them until this is answered.
- Stage and board skins are a monetization family that the Selling Animations catalog does not cover — does it become a sixth family, or its own system?
- Does the hub need the tree portal at all, or does shrinking the main stage remove the problem it solves?

## Conflicts raised by the monetization pass — 2026-09-21

Zhong's monetization catalog (customization + progression; free/paid split for dance pads). Two items in it contradict approved rules. Recorded, not resolved.

1. **Premium song packs sell content, and the crown ladder assumed they were earned.** Song packs unlock at Fan thresholds `8 / 20 / 40 / 70` in Progression §2, and those numbers were tuned on the assumption that packs are earned, not bought. Make them purchasable and Fans stop being an unlock ladder and become a leaderboard only — a legitimate choice, but a different game from the one §2 specs. Cleanest resolution on the table: a pack unlocks at its threshold **or** can be bought early, so money buys time rather than access. "Premium beat maps" is a separate and much smaller question — selling a harder chart for a song you already own touches Difficulty Templates, not the ladder. The two are currently being carried as one line item. Owner: Zhong.
2. **"Victory celebrations for top scorers" is on the paid list; §3 reserves it as earned.** Selling Animations §3 keeps top-performer results-screen content money-can't-buy precisely to protect the status credibility that makes the bought catalog worth buying. Three resolutions: sell it and accept weaker earned status, earn it and drop it from the paid list, or sell a *skin* that only renders on an earned slot. Owner: Zhong, with Nya.

## Open questions added by the monetization pass

- **"Standard progression" for free players** — the same XP curve as a payer, or a slower one? A slower free curve is a fundamentally different business model from cosmetic-only monetization, and the phrase does not say which.
- **Whose board skin renders on a shared board?** Owner-only, host's choice, each player sees their own, or a vote. "Each player sees their own" is safest for readability and worst for the flex, which is the whole reason to buy one.
- **Two status ladders on one nameplate.** VIP tags and name colours are sold; animated nameplates and grade auras are earned. Nothing decides how they are kept visually distinct, and if the paid one wins the grade ladder quietly stops meaning anything.
- **Rewarded ads and gacha both need a Roblox policy pass before design, not after** — rewarded video eligibility against our age rating, and paid-random-reward disclosure rules.
- **Battle Pass needs a season, and Music Game has no clock.** No season length, theme cadence or rollover exists. A pass also cannot spend Fans, which §2 defines as never spent.
- **Song requests are blocked on Song Library & Rights.** A paying player cannot queue music the game has no right to play.

## Conflicts raised by the Encore pitch decks — 2026-10-13

The Encore decks and the DDS design docs say different things. Owner: Zhong. Items 1, 2 and 4 are resolved above (2026-10-18); item 3 is still open.

1. ~~**Difficulty count.**~~ Resolved: four. (GDD §13 defined three; the decks and the 2026-09-24 email to Louise promise four.)
2. ~~**How a step is played.**~~ Resolved: stand-and-wait; arrows are the d-pad.
3. **Public test date.** The Encore deck roadmap puts the public test in early October and launch in late October; its ask asks Roblox to feature the "first public test" in late October. Still open.
4. ~~**Name.**~~ Resolved for now: both names kept.
