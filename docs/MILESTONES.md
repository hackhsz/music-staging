# Contract Milestones & Payments

Three contract milestones, each triggering an instalment. This list is separate from the product roadmap (M1–M3) in `MASTER_PLAN.md`.

| Milestone | Deliverables | Instalment |
| --- | --- | --- |
| **1** | (a) Core music and gameplay framework architecture<br>(b) Input synchronization and rhythm mechanic implementation | US$766 |
| **2** | (a) Player progression and reward systems<br>(b) Social interaction and lobby systems | US$766 |
| **3** (final) | (a) Supporting gameplay features implementation<br>(b) Bug fixing, performance optimization, and integration polish | US$768 |

Total: US$2,300. Each instalment is paid on Acceptance of its milestone, not on delivery.

A Performance Award may be paid on top, at the Company's discretion (for example, for consistently on-time
delivery or an extraordinary contribution), as agreed in writing under clause 2.3.

## Where each deliverable lives

A working map from deliverable to the code and docs that cover it. It is a proposal for planning, not part of the contract wording.

| Deliverable | Code | Docs |
| --- | --- | --- |
| 1a. Music and gameplay framework | `Shared/` (`Board`, `Timing`, `RhythmSession`, `SongSchema`, `SongMapCatalog`), `RemoteContract`, `RemoteBootstrap`, `Backend` | Master Plan, `CLAUDE.md` |
| 1b. Input sync and rhythm mechanic | `RhythmService`, `HitValidator`, `Timing` (stand-and-wait judging, four difficulties), `InputController`, `AudioController`, calibration offsets | Master Plan pillars, UI Requirements §3.4 |
| 2a. Progression and rewards | `RewardService`, `Progression`, `PlayerLevels`, `Scoring`, `ScoreSummary`, `PlayerDataService`, `LeaderboardService` | Player Progression & Mastery |
| 2b. Social and lobby | `MultiplayerService`, `MultiplayerModes`, `PracticeLobbyCatalog`, hub stations | Hub Layout, Master Plan (coop/PvP) |
| 3a. Supporting gameplay features | `LifeGauge`, `CrowdHype`, `FeverSystem`, cosmetics, emotes, abilities (`AbilityService`, `AbilityCatalog`), shop and monetization catalogs | Selling Animations, Player Progression §4 |
| 3b. Bug fixing, performance, polish | `PerformanceBudget`, `VFXController` quality tiers, `FarVFXCuller`, hygiene check | Open Questions & Risks |

## To do

- Confirm the acceptance criteria for each deliverable with the client before work starts on that milestone.
- Decide what counts as "done" for 1b: judging windows tuned, calibration working, and the latency approach tested on real devices.
- Keep AI-generated music rights proof on file for every shipped track (`AudioCatalog` `rights` and `rightsProof`).
