# Gameplay Plan: make the core fun first, then build on it

A handoff for whoever builds this next (another Claude session or a person). It is self-contained: read it,
then [REFERENCE_GAMES.md](REFERENCE_GAMES.md), then [../CLAUDE.md](../CLAUDE.md), and start at Phase A. Tick
the boxes as work lands and keep [CHANGELOG.md](CHANGELOG.md) and
[OPEN_QUESTIONS_AND_RISKS.md](OPEN_QUESTIONS_AND_RISKS.md) current.

## 1. Why this plan exists

The core loop today: a target tile is telegraphed, the player walks there and **stands still**, and the
server judges where they stand when the beat lands. Perfect needs half a beat of settling. The user played it
and said four things are wrong:

1. **Too much waiting.**
2. **Too easy, no tension.** Arriving early and standing is always the best play.
3. **Not tied to the music.** When you move does not depend on the beat.
4. **Unfair or hard to read.** The server sees a player arrive about 0.14 s late while moving and 0.2-0.3 s
   late after standing still (measured in Studio), while Perfect needs 0.5 beat of settling.

All four come from the same place: standing carries no timing skill. So the order is **fix the core feel and
judging first by prototyping and playtesting, then harden it, then build everything else on the winner.**
Tests, multiplayer fixes, content and power-ups all depend on what a "step" means, so none of them go first.

## 2. Decisions already made (do not reopen without the user)

- **Prototype two core variants and compare them in the real game**, with today's behaviour as the control.
- **Merge Fever and the new power-up into one earned meter** (Fortnite Festival's Overdrive), built later on
  the winning core. `FeverSystem` is the base.
- **Lag:** the new modes use client-reported arrival times. The control mode keeps today's judging, and a fixed
  compensation constant is the fallback for it.
- **Bots are deferred.** Nothing needs them to be playable.
- **A failed run pays reduced coins and does not rank or count toward completion stats.**
- **Prototype a Funky Friday style mode as well.** After playing the pad the user said it "isn't fun",
  "it's hard to follow", and they don't like going back and forth across the floor. They chose notes on
  screen with the character dancing in place: "we can still have the arena and do what Funky Friday does".
- **Prototype two floor layouts too,** next to the 5x5 as the control. The user found the 5x5 boring, "especially
  the diagonal one is hard on mobile", and asked for both a pad and lanes: "lets do 1 and 2 both and we will test
  one and then see if I like one or the other".
- **Floor model (already built):** every player has their own floor, side by side; two players first; the
  host (player 1) picks the song and the server starts it for both on one start time; the rival's floor is
  shown as a live ghost.
- Assumed defaults, change them only with the user: grade-weighted accuracy with rank S allowed after a few
  misses; console polish out of scope; the audio-rights proof for two silent songs is the user's to confirm;
  modifier runs get their own leaderboard, later.

## 3. Rules for the agent doing this

- **Follow [CLAUDE.md](../CLAUDE.md).** Server authority, `--!strict` for new modules, tunables in `Shared`,
  few comments, no new `.md` files unless this plan names them, run `scripts/check-clean.sh` before finishing.
- **Start Play in Studio when the user asks for a check or a playtest** (they do), and stop it after. Otherwise
  ask them to press Play, then read `get_console_output` and use `screen_capture`. `Workspace.Autoplay` plays
  the chart for you (see `Controllers/AutoplayController`); clear it before the place is saved. Edit mode is fine. Studio flips between Edit and Play because
  the user drives it; if a call says the datamodel is unavailable, ask them to switch.
- **Do not commit unless asked.** Check `git status` first: the tree has many uncommitted changes from other
  sessions, and **another agent is editing the UI** (`src/StarterPlayerScripts/Client/UI/`) and
  `Controllers/LobbyController.luau`. Read the current file before editing and adapt to it; never overwrite.
- **Edit the repo, not the place**, except for `Workspace.Arena`, which is authored in the place (see
  [UI_STYLE.md](UI_STYLE.md)). Argon syncs `src/` into Studio live when the user has it running.
- Ask the user before big design changes; use their words in the docs.

## 4. Current state (verify before relying on it)

**Architecture.** Client is layered: `Client/UI` (screens, no remotes), `Client/Input`, `Client/Controllers`
(Run, Lobby, Shop, Calibration, Floor; the only code touching remotes), `Client/Net` (`Remotes.luau` lists every
remote), `Client/World` (arena `build` and `bind`), `Main.client.luau` (wiring only). Server: `RhythmService`
(the judge), `Services/MultiplayerService.luau`, `Backend.server.luau`. See CLAUDE.md for the full layout.

**The judge** (`src/ServerScriptService/Server/RhythmService.server.luau`):
- Each heartbeat runs `updatePositionAudit`, then `updateHolding` or `processDueSteps`.
- The **plain-step branch** of `processDueSteps` (tap and bonus) waits until the beat, allows
  `Timing.LateArriveGrace` (0.14 s) for a late arrival, then grades with `Timing.gradeStandAndWait(onTile,
  settleSeconds, beatSeconds)`. `settleSeconds = now - state.coordEnteredAt`, and `coordEnteredAt` is when the
  server **first saw** the player on the tile, which is the late part.
- Holds and slides need a `SubmitHit`; the client sends it automatically when the player stands on the tile at
  the beat (`RunController._tryStartInputStep`). They are graded by packet arrival time with `HitValidator`.
- Danger is judged by avoidance at `target + PerfectWindow`. Bonus has no gameplay beyond +300 score.
- `Bad` is only reachable through hold/slide packet timing.
- `state.suspicious` counters are recorded and never read.

**Numbers are placeholders.** Score/rank/life/Fever values are first guesses (`Scoring`, `ScoreSummary`,
`LifeGauge`, `FeverSystem`, `CrowdHype`). Rank S needs accuracy 1 and zero misses; accuracy is unweighted;
the hype score bonus is defined and never applied; the Fever timer ignores pause.

**Timing.** `Shared/Timing.luau` holds four difficulty profiles (windows, travel window beats, `stepSeconds`)
and `gradeWithWindows`, `gradeStandAndWait`, `getStepSeconds`, `analyzeMap`. The client moves its own
character tile to tile (`Input/StepMover.luau`, steps of 0.14/0.12/0.10/0.09 s) and sends nothing about
movement; the server reads the replicated position.

**Content.** 7 songs (easy 2, normal 3, hard 2, expert 0). Generated expert charts exist in
`Shared/Songs/GeneratedCandyPopWarmup.luau` but are not in the catalog. `Timing.analyzeMap` is never called on
shipped charts; the easy warmup breaks its own travel rule 11 times and Neon Idol Rush once. Two songs have no
audio entry. `docs/audio-rights-and-chart-qa.md`, which `rightsProof` points to, does not exist.
`ChartGenerator` emits taps, holds, gold item pickups and song sections. `AbilityCatalog` holds 16 abilities, four per run, run by `Services/AbilityService`. There are no
modifiers, gimmicks, meter or practice mode. The first-run lesson is `Shared/TutorialChart`.

**Multiplayer defects** (fix in Phase C): restarting or picking a new song in a match leaves stale summaries,
Results state and rematch requests (P0); `leaveMatch(..., false)` does not tell the rival (P0); a disconnect
does not abort the rival's run or really requeue them; matches form mid-run; failed runs are paid and ranked;
co-op shows TEAM CLEAR even if a player failed; the pause block is keyed on `playerCount == 2` even outside
runs; a party code can pull in a busy host; no ready check; a song locked for the guest is rejected silently.

**Tests.** None exist, and no Luau test runner is installed (aftman has `luau-lsp`, `rojo`, `argon` only).

## 5. The core prototype

All three modes share one judge entry point. The active mode is the Workspace attribute `CoreMode`, read at
each song start and sent to clients in the `StartSong` payload (`coreMode`), so the user can flip modes in
Studio without code. In a match both players use the same mode.

| Mode | Idea | Grade |
|---|---|---|
| `standWait` (control) | The original loop | Perfect = settled 0.5 beat before the beat lands |
| `arriveOnTime` (A) | Keep standing and the multi-beat telegraph, add a timing skill | Be on the tile at the beat. **Landing time** sets the grade: landing 0.5 to 0.15 beat before the beat is Perfect, landing much earlier is Great ("rushed"), landing after the beat inside the grace is Good, nobody there is Miss. A window, not a point. Narrower on expert |
| `onBeat` (B, **the default**) | The Music Game's dance pad: each press is one step | The judged moment is the press (landing minus `stepSeconds`) plus `Timing.OnBeatLandDelay` (0 now; the device offset covers latency), so step speed never moves the target. On the tile at the beat: within `onBeatPerfectWindow` (60 ms on normal) Perfect, `onBeatGreatWindow` (140 ms) Great, else Good, so arriving early caps at Good. Off it: a step pressed within `Timing.OnBeatLateGrace` (200 ms) still counts by its landing, else Miss. Being off a danger tile is a Great. Holds and slides start from the landing too |
| `highway` (C) | Funky Friday style: arrows scroll up four on-screen lanes; the character dances in place | Judged by **when you press the arrow's lane**, with the same windows. Nothing is judged by position |

**Mode C, the highway.** Charts are remapped onto four lanes (the `lanes4` remap) whatever the floor is; the
floor is only the stage. The lanes are the HUD's A S D F keycaps (X A Y B on a gamepad; the arrows are deliberately not lanes): notes
fall down a track onto the authored keys and land on them on the beat, and on touch the keys are the
buttons. The keys are bound by the HUD roles `LaneKey1` to `LaneKey4` and `HighwayGroup`; without them the
highway draws its own stand-ins. In a highway run the camera is a stage shot of the dancer that moves with
the music (`CameraController`). Each press goes to the server as `SubmitPress {lane, t}` and is matched to the nearest note
on its lane. A danger note is a mine: pressing its lane near the beat is the Miss. A hold's head is matched like a
tap; letting go is reported as `SubmitRelease {lane, t}`, and the hold keeps the head's grade if held to
its end (within `Timing.HoldReleaseGrace`), a Good if held for `Timing.HoldGoodFraction`, else a Miss. The character steps toward each pressed arrow and springs back (`StepMover.bounce`), and wobbles on a
Miss. Scroll time per difficulty is `highwayLeadSeconds` in `Timing`. The floor plays along: the tile beside the
dancer in a note's direction glows as it is about to land, presses flash it, a Perfect ripples out and Fever
cycles the lane colours (`BoardView.renderStage`). Lane colours and directions live in `Shared/HighwayLanes`. Code: `Client/Controllers/HighwayController`
and `Client/UI/Screens/NoteHighway`.

B fits the existing generated charts (one adjacent step per beat). B changes a design pillar (Master Plan
pillar 2, "waiting is rewarded, chasing is punished"), so the docs change if B wins.

B judges the **press**: the landing minus the hop, which always takes the difficulty's `stepSeconds`
(`CoreRules.judgedOffset`). Judging the landing itself made every press dead on the beat read about 120 ms
late. B also gives its verdict as soon as a confirmed report matches the note, and the client moves its
telegraph on when a note's press window closes rather than waiting for that verdict.

**Floor layouts.** The Workspace attribute `BoardLayout` picks the floor at song start, and it goes to clients
in `StartSong` (`boardLayout`). Charts are authored for the 5x5 and remapped by `Shared/BoardLayouts.luau`.

| Layout | Floor | Input | Remap |
|---|---|---|---|
| `grid5` (control) | today's 5x5 | arrows/WASD move one tile; diagonals take two moves | none |
| `pad3` | 3x3 with a home tile | one key per panel: Q W E / A S D / Z X C or the numpad; touch is a 3x3 grid | each move becomes its direction, played from home |
| `lanes4` | four lanes, frames slide down a highway | one key per lane: D F J K or arrows; touch is four buttons | horizontal position only |

On pad and lanes any tile is one hop away, and pressing the tile you stand on is a step in place, which a
repeated note needs. Mode and layout are independent, but the layouts were built for B.

**Why client-reported timing.** A and B need arrival timing precise to tens of milliseconds, but the server
sees positions 140-300 ms late. So the client reports its landing time on a server-synced clock and the server
checks it is plausible:

- New remote `ReportArrival {x, y, t}`, client to server, rate-limited, sent when a step lands.
- `t` comes from `workspace:GetServerTimeNow()` on the client. The server converts to its own `os.clock` base
  once per run.
- The server compares each claim with when it first saw the player on that tile, keeps a running estimate of
  that player's delay, and only accepts claims within a narrow band around it (about 80 ms), so a cheater can
  shift timing by at most that much. A claim with no matching position is a Miss. Warm up with a wider band
  for the first few reports.
- A report usually arrives before the position it describes, so it waits as pending for up to 0.5 s. A step
  in place has no new position to check, so it is checked against how long reports normally take to arrive,
  with the same band. All of this lives in the pure `Shared/ArrivalLedger.luau`.

## 6. Phase A: core sprint (do only this until the decision gate)

- [x] **A0. Reference doc.** Done: [REFERENCE_GAMES.md](REFERENCE_GAMES.md). Read it before choosing details.
- [x] **A1. Pure rules with tests.**
  - New `src/ReplicatedStorage/Shared/CoreRules.luau`: the three modes as data and a pure
    `grade(mode, landingOffset, standSeconds, beatSeconds, difficulty)`. Reuse `Timing.gradeWithWindows` and the
    windows in `Timing.DifficultyProfiles`. Put the A window fractions in `Timing`/`CoreRules` as tunables.
  - A minimal test runner at `src/ServerStorage/Tests/` (`Runner.luau` plus one spec per module, plain
    ModuleScripts). Run it in Edit mode with `execute_luau` (see section 9). Specs for `CoreRules`, plus
    boundary tests for `Timing` and `StepPlanner`.
- [x] **A2. Arrival reporting.**
  - `Input/StepMover.luau`: add an `onStepLanded(coord, clock)` callback (it knows when each step ends).
  - `Controllers/RunController.luau`: send `ReportArrival` with the server-synced time.
  - Declare the remote in `Shared/RemoteContract.luau` (rate limit about 20 per second) and add it to
    `USED_EVENTS` in `Client/Net/Remotes.luau`. Add `coreMode` to the `StartSong` payload keys.
  - `RhythmService.server.luau`: handler with the usual guards (rate limiter, then type check), plausibility
    band, per-player delay estimate. Guard against claims for steps that are not current.
- [x] **A3. Judge dispatch.** In the plain-step branch of `processDueSteps`, call `CoreRules.grade` for the
  active mode (the control keeps `Timing.gradeStandAndWait`). Return `deltaMs` for plain steps so the HUD's
  EARLY/LATE text works. Holds, slides and danger keep their current judging in the prototype.
- [ ] **A4. Readability** (the user said "hard to read"). An approach ring that closes onto the tile exactly on
  the beat (reuse the settle-ring parts in `Client/Floor/BoardView.luau`; in mode A also mark the arrive window); a
  soft beat tick in `SFXController` that can be switched off; early/late text on every step; a footprint for
  the next two targets. The telegraph is never covered. HUD parts belong to the UI agent's area: coordinate.
  Done so far: an approach frame that lands on its tile on the beat (sliding down the highway on lanes) for
  the next six notes, and a landing sound on every hop. The beat tick and mode A's arrive window are not.
- [x] **A5. Playtest harness.** The server prints one line per run: mode, difficulty, song, grade counts, mean
  and spread of early/late, Miss reasons, the measured delay estimate. Add a short protocol to this file's
  section 8 when done.
- [ ] **A6. Decision gate.** Ask the user to play the same easy, normal and hard song in all three modes and
  rate each 1-5 on: tied to the music, tension, flow, fairness, readability. At the least compare `onBeat` on
  `pad3` and on `lanes4` against `standWait` on `grid5`, and pick a layout as well as a mode. Read the logs. Choose the mode
  that scores best and keeps the numbers sane (the median player on normal reaches rank B, S in about 5-10%
  of runs, early and late roughly balanced). Also check touch and gamepad at expert speed, and that the
  rival's ghost floor stays readable. Then remove the losing modes and the switch, and update the docs
  that describe the loop: [MASTER_PLAN.md](MASTER_PLAN.md) pillar 2, [PLAYER_PROGRESSION.md](PLAYER_PROGRESSION.md),
  [UI_REQUIREMENTS_CORE_LOOP.md](UI_REQUIREMENTS_CORE_LOOP.md), and CLAUDE.md "The core loop, precisely".

**Exit:** one core mode locked, documented and playtested on keyboard and touch.

If neither variant feels better than the control, fall back to Phase E (variety on the control mode) and say so.

## 7. After the core is locked

Same order, all on the winning mode.

- [ ] **Phase B, harden the judge.** Holds, slides and danger judged consistently with the winning mode; a hold
  no longer blocks judging of later steps; danger gets a late grace; `Bad` reachable by timing; consume
  `state.suspicious` (past a threshold the run is flagged unranked and unpaid, no kicking); the meter timer
  stops on pause; scoring, rank, life and meter numbers move into `Shared` data; accuracy becomes
  grade-weighted and the hype score bonus is applied. Pure-module tests first.
- [ ] **Phase C, multiplayer correctness.** One `resetMatch` (summaries, Results state, `rematchRequests`,
  `syncBonus`, `teamHype`) called on restart, new song and rematch; leaving a match notifies the rival; a
  disconnect aborts the rival's run, clears their ghost floor and really requeues them; no match forming
  mid-run; a host timeout and a ready check before the song starts; the pause block keyed on an active run; a
  party code cannot pull in a busy host; failed runs pay reduced coins and do not rank or count
  (`Backend.applySongComplete`, `RewardService`, `LeaderboardService`); co-op shows TEAM CLEAR only if both
  cleared and battle ignores a failed player's frozen score; a guest gets a message for a song they do not own
  and the host's list greys it out. Extract the match rules into a pure module so fake players can test them.
  Then run the 2-client test (section 9).
- [ ] **Phase D, content.** Wire the generated expert charts into `Shared/SongMapCatalog.luau`; fix the easy
  warmup and Neon Idol Rush until `Timing.analyzeMap` is clean; add audio entries for `auto-starlight-run-hard`
  and `auto-aurora-drive-easy`; write `docs/audio-rights-and-chart-qa.md`; extend `ChartGenerator` to emit
  slide, danger and bonus with a minimum travel window before any danger; add `analyzeMap` over every shipped
  chart as a test. Every difficulty ends with at least two songs.
- [ ] **Phase E, fun systems on the winning core**, each with a unit-tested pure core, in this order:
  1. **Practice mode and a first-run tutorial.** Practice: pick a section, loop it, slow the rate, unranked
     and unpaid. Tutorial: a short scripted chart teaching tap, hold, slide and danger. Both run the normal
     `RhythmService` path with an `unranked` flag.
  2. **Danger shapes and floor pickups.** Pre-telegraphed danger shapes (row sweeps, checkerboards). Make
     `bonus` real: a shield that absorbs one danger, a gem route, a life tile.
  3. **The merged earned meter.** Charge from Perfect and Great streaks, drain on a Miss, the player triggers it
     (new rate-limited `ActivateOverdrive` remote; space bar, gamepad button, on-screen button). The server
     validates a full meter and applies a timed multiplier in place of today's flat +220 per hit. In a match,
     simultaneous activation earns a co-op bonus. Build on `Shared/FeverSystem.luau`. Versus interference, if
     ever added, never targets the leader.
  4. **Per-song gimmicks.** A `gimmick` field in song data, one rule per song (mirrored floor, pulsing safe
     zone, dark floor with only the telegraph lit).
  5. **Stackable one-rule modifiers** (Turbo, Mirror, Hidden Danger, No Meter, Sudden Death) with a visible
     combined multiplier and a separate leaderboard. This can slip.
- [ ] **Phase F, tuning and lock.** Only now, from logged playtest data.

## 8. Playtest protocol

The server prints one line per finished run. Set `Workspace.CoreMode` to `standWait`, `arriveOnTime`,
`onBeat` or `highway`, and `Workspace.BoardLayout` to `grid5`, `pad3` or `lanes4`, before pressing Play. Both are string
attributes read at song start, so changing them mid-run does nothing.

    [Playtest] Name mode=arriveOnTime layout=grid5 song=candy-pop-warmup diff=easy rank=A score=18400 acc=0.930
      | P=28 G=9 g=2 B=0 M=3 | delta mean=-84ms sd=61ms n=39 | misses not_on_tile=3 | delay=173ms

- **delta mean** is how early (negative) or late the landings sat against the beat. Roughly balanced is
  the target; a large negative mean in `arriveOnTime` means the band is too late for how people play.
- **sd** is the spread. It should shrink as difficulty rises; if it does not, the chart is unreadable
  rather than hard.
- **delay** is the measured gap between a claimed landing and the server seeing it. It is the reason
  client reporting exists. If it reads `unmeasured`, no claim was accepted and the run was graded on the
  late server view, so treat the line as suspect.
- **misses** separates "could not read it" (`not_on_tile`) from "mistimed it". In `onBeat`, `not_on_tile`
  means no step put the player on that tile by the end of the late grace. In `highway`, `no_press` is a note nobody pressed and `hit_mine` a
  mine that was.

Per mode, play the same easy, normal and hard song. After each mode rate 1-5 on: tied to the music,
tension, flow, fairness, readability. Paste the log lines with the ratings. Autoplay
runs prove a chart is playable, not that it is fun: the ratings come from the user.

Sanity targets before a mode can win: the median player on normal reaches rank B, S lands in roughly
5-10% of runs, and early and late are roughly balanced.

## 9. Tools and how to verify

**Type-check (no Play needed).** There is no script for this in the repo; recreate it:

1. `argon sourcemap default.project.json --output <temp>/sourcemap.json`
2. Download Roblox type definitions once from
   `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau`
3. `luau-lsp analyze --sourcemap <temp>/sourcemap.json --definitions <temp>/globalTypes.d.luau --platform roblox <paths>`

Run it on `src/StarterPlayerScripts/Client`, `src/ReplicatedStorage/Shared` and `src/ServerScriptService/Server`.
The only expected error is an existing one in `FarVFXCuller.client.luau`. Put temp files outside the repo.

**Unit tests (no Play needed).** Studio's `execute_luau` in **Edit** mode can `require` the test runner from
`ServerStorage` and return pass/fail text. Gotcha: Edit mode caches `require`d modules for the session, so after
changing a module, require a **cloned copy** (`Module:Clone()` into a temp folder) or restart Studio, or you
will test stale code.

**Studio checks.** `screen_capture` works in Edit mode with `camera_position` and `look_at_position`; the game
camera is at `floorOrigin + (0, 36, 44)` looking at `floorOrigin + (0, 2, -3)`. Edit-mode lighting differs from
the game's, so judge colours in Play only. The dance floor is built by `BoardView` at runtime, so it does not
appear in Edit captures. `Workspace.Arena` is real parts: inspect and test `Arena.bind` on a clone.

**Roblox facts that bit us:** a part's Front face is -Z, so a `SurfaceGui` that should face the camera (at +Z)
uses `NormalId.Back`. `Player:GetNetworkPing()` is client-only. Client-set properties do not replicate unless
physics-owned, so the client moves its own character by setting `CFrame` on the root part each frame.

**2-client test (Studio Test, Clients and Servers, 2 players), after Phase C:**
1. the host picks a song and both start together on separate floors;
2. restart mid-match, and the results use fresh scores;
3. one player leaves mid-run, and the rival is told and the run aborts;
4. a mode switch or party join notifies the rival;
5. co-op with one failed player does not show TEAM CLEAR;
6. a guest picking a locked song gets a message.

## 10. Risks

- A highway press has no position behind it, so its time is the client's claim, checked only against how long
  that player's presses usually take to arrive. The band caps each press, but a patient cheater could drift
  the estimate. Flag unranked past a threshold (Phase B) before anything competitive ships on it.
- The floor layout is one value for the whole server (`Board.setLayout`), so every run on a server uses the
  same layout. Fine while it is a test switch; it needs to become per-session if layouts ever ship side by side.
- Client-reported timing is a new trust surface. The narrow band caps what a cheater gains, but movement is
  client-owned, so "flag unranked" is a mitigation, not a fix.
- Changing the judge touches the core of `RhythmService`: write tests first.
- The meter, pickups and modifiers can break score balance: keep every number in data.
- Others are editing the UI and `LobbyController` in the same tree.
- Scope creep: no economy or UGC hooks until the core and its fun systems are locked.

## 11. Open items for the user

- Audio-rights proof for the two silent songs.
- If mode B wins, rewrite Master Plan pillar 2.
- Whether modifier runs share the main leaderboard (default: their own, later).
