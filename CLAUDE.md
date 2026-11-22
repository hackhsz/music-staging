# Dance Dance Step

A 5x5 tile rhythm game for Roblox, written in Luau and synced into Studio with Argon
(`default.project.json`). A player picks a track and steps onto a lit dance floor. Each beat
telegraphs a target tile ahead of time; the player walks there and **stands** on it, and the beat is
judged by where they are standing and how long they settled. Hitting beats builds combo, crowd hype
and Fever, while misses drain a life gauge that can fail the run early. Coins, cosmetics, songs,
achievements, XP and lifetime stats persist between runs. The dance floor does not.

Two players can share a session in co-op or battle modes. A lone player can play any unlocked track
solo.

The design authority is [docs/MASTER_PLAN.md](docs/MASTER_PLAN.md); the other documents under
`docs/` serve it. Where a design document and the code disagree about something already built, the
code wins and the document needs updating: the core loop lives in `RhythmService.server.luau` and
`Shared/Timing.luau`. Where the code simply has no opinion yet, the plan decides.

The working title is Dance Dance Step, which is what the code logs and what the DataStore is named.
Pitch material calls it *Encore*. Both stand until a final name is picked, so don't rename anything
in `src/` on the strength of either.

## The core loop, precisely

This is the part most likely to be misunderstood, so it is stated first.

**Plain steps are not tapped.** The server telegraphs the target tile a travel window ahead (4 beats
on easy, 3 on normal, hard and expert). The player walks onto it. When the beat lands, the server looks
at where the player is standing:

- Settled on the tile for at least half a beat: **Perfect**
- Settled for at least 150 ms: **Great**
- On the tile but only just arrived: **Good**
- Not on the tile, and still not there after a 140 ms late-arrival grace: **Miss**

That is the stand-and-wait mode. The default is the pad (`CoreRules.Modes.OnBeat` on the 5x5 floor), where
Perfect is kept for a step that **lands on the beat**: standing there early, or dodging a danger tile, is
`CoreRules.StandGrade` / `DodgeGrade` (Great).

**Holds and slides are started by an input.** The client sends `SubmitHit`; the server verifies the
player stays on the tile for the hold's duration, or that they crossed every tile of the slide path.
Leaving a hold early downgrades to Good at 60% held, otherwise Miss.

**Danger steps are judged by avoidance.** Standing anywhere except the danger tile when the beat
lands is a Perfect; standing on it is a Miss.

`Shared/Timing.luau` owns every window and difficulty profile. Never hard-code a timing number
anywhere else.

## Layout

```
src/
  ReplicatedStorage/Shared/        loaded by both sides; plain ModuleScripts
    RemoteContract.luau            THE network contract: every RemoteEvent, its direction and rate limit
    Board.luau                     floor maths for the active layout; coord <-> world position; a floor per player
    BoardLayouts.luau              the floor shapes (5x5, 3x3 pad, four lanes) and the chart remap onto each
    ArrivalLedger.luau             the client's landing reports, held until the server's view confirms them
    StepPlanner.luau               pure step maths: neighbours, tap paths, the buffered step queue
    StraightSteps.luau             keeps easy and normal targets on the dancer's row or column (corner notes)
    TutorialChart.luau             the first-join lesson: one drill per step type (unfailable, unpaid, unranked)
    InputStrategy.luau             per-device modes and the input tunables
    Timing.luau                    judgement windows, difficulty profiles, stand-and-wait grading
    PlayerSettings.luau            every Settings window option: section, kind, default; the server checks changes against it
    CosmeticBuilds.luau            how a cosmetic looks on a character, for the real avatar and the shop's try-on preview
    RhythmSession.luau             per-run beat clock and step cursor
    HitValidator.luau              judges one submitted hit against one step
    Scoring.luau  ScoreSummary     points, combo, per-grade counters, end-of-run rank
    LifeGauge  CrowdHype  FeverSystem    the three run-state meters
    SongSchema  SongMapCatalog  SongCollection    chart validation, the catalog, unlock rules
    Ease                           the easing curves the client animates with
    Abilities                      ability rules: charge, cooldowns, timed effects, verdict changes
    StageBlockout                  where the arena's zones sit (floor, stage, wall, screens, crowd)
    Songs/                         the charts in the catalog, written by scripts/ and never by hand; for now
                                   Our Hearts, I Don't Wait, Under the Starlight, Just a Little Static and Do You Read Me
    Catalogs/                      cosmetics, emotes, characters, stages, themes, audio, VFX, abilities
                                   (AbilityCatalog), achievements, economy, levels and the other content tables
    Policies/                      rights, UGC and monetization guardrails (see Rights, below)
  ServerScriptService/Server/
    RemoteBootstrap.server.luau    creates every RemoteEvent from RemoteContract. Runs first.
    Backend.server.luau            wires the Services together; owns profile sync, purchases, emotes
    RhythmService.server.luau      the judge: sessions, beat heartbeat, anti-cheat, scoring
    FeatureRegistry.server.luau    requires the catalog modules so they load and validate
    Main.server.luau               a boot log line
    Services/                      classes constructed with .new(), not singletons
      PlayerDataService            DataStore profiles, schema migration, autosave
      RewardService                song payouts, achievements, XP, daily challenges, the play-time gifts
      InventoryService             cosmetic purchase and equip
      LeaderboardService           OrderedDataStore boards, weekly rotation
      MultiplayerService           queue, parties, matches, rematch
      CosmeticVisualsService       welds lightsticks, trails and auras to the character
      RateLimiter                  per-player, per-key request buckets
      AbilityService               fires a run's abilities and applies them to its verdicts (for RhythmService)
      StationService               in a hub place, the stations' Pick a Song prompts and the trip back from the stage
      DataStoreRetry               the shared DataStore budget wait and retry loop
      FunnelService                logs FunnelCatalog's funnels to AnalyticsService
      OnboardingService            lesson drills passed, steps and tips done, the one-time gift; pushed to the client
  StarterPlayerScripts/Client/
    Main.client.luau               wiring only: builds the views and controllers, hands each its deps, starts them
    Controllers/                   the game logic, one concern each; the only code that touches remotes
      RunController                one run: session clock, telegraph, settle ring, verdict feedback
      LobbyController              song list, picking a track, play mode, lobby rewards
      ShopController               profile mirror, shop rows, purchase and equip
      CalibrationController        the player's input-latency offset
      FloorController              which floor is the player's own, the camera, and the rival's ghost floor
      SettingsController           applies the Settings window's volumes, quality, blur and camera shake, and saves them
      HighwayController            the highway mode: lane presses to the server, notes on screen, the dance step
      AbilityController            the floor pickup and the ability cards (abilities fire by stepping on them), the loadout picker
      HubController                in a hub place, island (free walk, own camera and lighting) versus stage
      ProgressController           queues what a run gained: the stage-up reveal, then achievement and daily toasts
      StagesController             Stage Challenge between runs: the stages snapshot onto the Stages screens, the play mode
      OnboardingController         first join: lesson drills, timing check, first song, then tips as they become useful
      AutoplayController           Studio only: plays the chart (Workspace.Autoplay) and steps onto ability
                                   pickups (Workspace.AutoplayAbilities) through the real input, for playtests
    Input/                         devices; they turn presses and taps into intents
      InputController              WASD/arrows/D-pad/stick/on-screen pad to steps, taps to tiles
      StepMover                    moves the local character tile to tile; buffers presses
      HotkeyController             keyboard shortcuts that forward to the controllers
      DeviceMode                   touch, keyboard or gamepad
    UI/                            drawing only: no remotes, no game rules
      HUDController                composes the screens; owns run mode and photo mode
      UiKit                        colours, label and button builders, key hints, viewport helpers
      TweenSlots  TextStyles       one tween per key; combo tiers, the rainbow and the grade palette
      HudFx  HudWave  GradeLine    the pad HUD's parts: fades and sprite effects, the music-driven equalizer
                                   bars, and the chrome grade call-out; NeonPanel animates the outlined panels
      AvatarPuppet                 a copy of an avatar in a ViewportFrame that mirrors the live dancer
      Screens/                     RunHud, HintBar, SideMenu, MultiplayerPanel, SongSelectScreen,
                                   ResultsScreen, PauseOverlay, ShopPanel, SettingsPanel, StepPad, NoteHighway, SongBar, PadHud,
                                   RivalPortrait, AbilityBar, AbilityPicker, MenuScreen, ProgressPopups, StagesScreen, StagePanels
    Net/                           Remotes (every remote, resolved once), Telemetry
    Floor/                         BoardView (the dance floor: tile states, telegraph, timing ring, hit
                                   flashes; copies the authored Workspace.DanceFloor) and RivalFloor (the
                                   rival's ghost floor and bot)
    Audio/                         AudioController (the song track, one prepared asset at a time), SFXController,
                                   SoundGroups (the music, effects, dance and menu volumes)
    Dance/                         the dancer: DanceAnimator, the pad's PadDanceMoves, DanceRig (joint posing),
                                   AvatarReactionController (catalog emotes at milestones)
    Effects/                       VFXController (particles, performance tier watchdog), FarVFXCuller.client
    World/                         the arena: build (authors Workspace.Arena) and bind (animates it: the street
                                   stage Arena.Street through ArenaStreet, the disco stage and truss through
                                   ArenaStage and ArenaDisco), plus
                                   StageBlockoutRenderer.client (keeps it on the beat), StageLighting and
                                   CameraController (the floor overview, or the highway's stage shot)
  ServerStorage/Tests/             specs for the pure Shared modules; Runner runs them in Studio Edit mode
  ServerStorage/ArchivedSongs/     every other song and the old ChartGenerator, out of the catalog, kept to bring back
docs/MASTER_PLAN.md                the design authority: the bet, the pillars, the roadmap
docs/GAMEPLAY_PLAN.md              the plan to make the core loop fun first, then build on it; start here to continue
docs/REFERENCE_GAMES.md            what other rhythm games do and what we take from each
docs/PLAYER_PROGRESSION.md         difficulty scaling, mastery tracks, level rewards, UGC
docs/HUB_LAYOUT.md                 the hub's stations, NPCs and size budget
docs/SELLING_ANIMATIONS.md         what animation content is sold and where it fires
docs/MILESTONES.md                 contract milestones and payments, separate from the roadmap
docs/OPEN_QUESTIONS_AND_RISKS.md   decisions taken and what is still unanswered
docs/UI_REQUIREMENTS_CORE_LOOP.md  what must be on screen through the loop, and each screen's states
docs/UI_STYLE.md                   how the HUD and stage look
docs/CHANGELOG.md                  what changed and why, newest first
scripts/                           hygiene check, git hook setup, the chart generators, and push-to-studio.py
                                   (makes the open place match src/ through `argon exec` when Argon stops syncing)
tools/scripts/                     image helpers for UI art
```

`src/ReplicatedFirst` holds the loading screen script, which shows a copy of `ReplicatedFirst.Loading` (authored in the place file, so it is up from the first frame). Everything not under `src/` lives in the place file and is edited in Studio. Anything under
`src/` is overwritten by Argon, so edit it here, not in Studio.

## Architecture

There is **no service framework**. No ModuleLoader, no Knit, no Packet library, no ProfileService,
no Janitor. Do not introduce one, and do not write code that assumes one exists.

- **Requires are instance lookups.** `require(Shared:WaitForChild("Timing"))` on an entry script,
  `require(script.Parent.Timing)` between sibling Shared modules. There is no require-by-string and
  no `@game/...` alias in this project.
- **Server scripts are `*.server.luau` and run top to bottom.** They are ordinary Scripts, not
  lifecycle objects. There is no `Init`/`Start` pair.
- **Services are classes.** `PlayerDataService.new()`, `RewardService.new(playerDataService)`.
  `Backend.server.luau` constructs them once and holds them.
- **`Backend` is published on `_G.DanceDanceStepBackend`,** and `RhythmService` reaches it through
  `getBackend()`. This is the one global in the project and it exists because the two entry scripts
  cannot require each other. Do not add a second global. If you need a new cross-script dependency,
  hang it off the existing `Backend` table.

### Networking

1. **Declare the event in `Shared/RemoteContract.luau` first.** Give it a `name`, a `direction`, the
   `payload` keys, and a `rateLimitPerSecond` for anything client-to-server. Unlike a positional
   packet registry, entries here are keyed by name, so you may add one anywhere in the table.
2. `RemoteBootstrap.server.luau` creates the RemoteEvent under `ReplicatedStorage.Remotes` at boot.
   You never create a RemoteEvent by hand.
3. Both sides look it up with
   `remotes:WaitForChild(RemoteContract.Events.YourEvent.name)`.
4. Every `OnServerEvent` handler starts with the same two guards, in this order: the rate limiter,
   then a type check on the payload.

```lua
someRemote.OnServerEvent:Connect(function(player, payload)
	if not rateLimiter:allow(player, "SomeEvent", RemoteContract.Events.SomeEvent.rateLimitPerSecond) then
		return
	end

	if type(payload) ~= "table" or type(payload.someId) ~= "string" then
		return
	end
	-- ...
end)
```

### Server authority

The server decides every outcome. This is not negotiable and it is the review bar for any change
under `src/`.

- **The server judges every step.** The client animates the board and submits holds and slides; it
  never decides a grade. `RhythmService` reads the player's real character position through
  `Board.worldToCoord` and judges against that.
- **Position is never fabricated.** A player with no character or standing off the board is judged a
  Miss with reason `no_position`, never given an assumed tile.
- **Anti-cheat is recorded, not just rejected.** `recordSuspicious` counts
  `impossible_tile_travel`, `tile_dwell_too_short`, `repeated_step_attempt`,
  `stale_or_future_step_index` and `non_adjacent_tile_move_request` on the session. Keep adding to
  that table rather than silently dropping bad input.
- **Currency, ownership, unlocks and rewards are server-side.** The client gates the UI for
  friendliness; the server rejects the request regardless.
- **Timing offset is clamped** to +/- 0.25 s, and a device default never overrides a calibration the
  player set. After each onBeat run the client tunes it toward the player's median timed press
  (`Timing.AutoTune`), through the same remote as a manual change.

### Data

- `PlayerDataService` wraps `DataStoreService` directly. The store is `DanceDanceStepProfilesV1`.
- The schema is `DEFAULT_PROFILE` at the top of that file, with `CURRENT_SCHEMA_VERSION`. Add a key
  by adding it there with a default; `mergeDefaults` backfills it into existing profiles on load.
  Never rename or remove a saved key without a migration in `migrate`.
- `:get(player)` returns the live table. Mutate it, then call `:markDirty(player)`. Saves are
  batched: every 60 s, on leave, and on `BindToClose`.
- **In Studio, loads and saves are skipped** so play tests start from a fresh default profile.
  Leaderboards fall back to in-memory boards for the same reason. Test persistence in a real server.
- Match state is never saved. Score, combo, life, hype, Fever and the step cursor live in the
  `sessions` table in `RhythmService` and are dropped when the run ends.

### Client

Controllers display and predict; they never decide. The client is layered, and a layer only reaches
down:

- `UI/` draws state and reports taps. A screen never requires a controller, a remote or a game rule.
- `Input/` turns devices into intents (a step, a tapped tile). It does not know what a step means.
- `Controllers/` hold the logic and are the only place a remote is fired or listened to. Remotes come
  from `Net/Remotes`; a controller never looks one up itself.
- `Main.client.luau` builds everything and passes each controller what it needs. Add a controller by
  writing the module and wiring it there. Don't grow `Main` or `HUDController` with logic.

`RunController` holds a local `RhythmSession` purely to drive the telegraph and animation ahead of the
server's verdict. When a `HitResult` arrives, the server's numbers win.

The client moves its own character: `StepMover` steps it tile to tile at the difficulty's
`Timing.getStepSeconds`, and Roblox's default WASD and thumbstick walking is disabled. The server still
judges the replicated position, so nothing the client does can award a grade.

The HUD is **built in code**, one module per screen under `UI/Screens/`, except the pad run HUD and
its on-screen keys: those are authored in `StarterGui.PadHud` (in the place file, not under `src/`), and
`PadHud`, `StepPad`, `SongBar`, `RivalPortrait` (the `RivalCard`) and `AbilityBar` (each layout's `Abilities`
cards, and `Derail.HUD.HudFrame` off the pad) bind to them by name. The other in-run screens (pause, settings, the
run's hints and the floor-event banner) are authored the same way in `StarterGui.GameHud`, bound by `PauseOverlay`,
`SettingsPanel`, `HintBar` and `EventBanner`, and the song picker is `StarterGui.Songs`, bound by
`SongSelectScreen`. The lesson card and timing-check tap pad are `StarterGui.Lesson`, bound by `TutorialOverlay`, and the rank-up card and toasts are `StarterGui.Progress`, bound by `ProgressPopups`. The stage screens (mode tile and PLAY, mode list, setlist board, stage-up reveal) are `StarterGui.Stages`, bound by `StagesScreen`, with its song browser, roadmap, challenge prompt and results XP panel bound by `StagePanels`. The lobby HUD (icon rail, player card, daily challenges, mode button, hint) is
`StarterGui.Lobby`, bound by `SideMenu`, `MultiplayerPanel` and `HintBar`, and the windows its rail opens
(Loadout, Shop, Settings) are `StarterGui.Menu`, bound by `MenuScreen`, `AbilityPicker`, `ShopPanel` and
`SettingsPanel`. The arena is the other way round: it is parts in `Workspace.Arena`,
authored once from `World/` and edited in Studio, and `StageBlockoutRenderer.client.luau` only binds
and animates them. If a place has no arena it is built at runtime from the same code. Where the stage sits is Workspace's `DanceFloorOrigin` attribute (default the world origin). A place
with `DanceHub` set is a hub: the stage is visited from a station rather than being the whole world, and
`Arena` and `DanceFloor` must be Persistent models stamped with a `Parts` attribute so streaming always
delivers them (`World/StreamedModel`). The dance floor works the same way: `Workspace.DanceFloor`
is authored by `BoardView.authorFloor`, and each player's floor is a copy of it snapped to the board's
origin, so moving the model never moves where a step is judged.
The authored screens share one style sheet, `ReplicatedStorage.UIStyles` (in the place file): tag an element
(`Card`, `Chip`, `Pill`...) for its look, and toggle state by tag, not colour.
See [docs/UI_STYLE.md](docs/UI_STYLE.md) before changing how anything looks.

## Luau style

- Start a new module with `--!strict`. Much of the existing code predates this and is untyped; that
  is a known gap, not a licence to add more. Type public function parameters and returns. Use
  `:: any` only at real boundaries (remote payloads, vendored APIs).
- Indent with tabs. Double quotes. Lines up to about 120 characters (`stylua.toml`).
- Names: `PascalCase` modules, types and public methods; `camelCase` locals and local functions;
  `UPPER_SNAKE` constants. Services end in `Service`, controllers in `Controller`.
- File order: `game:GetService` calls, then requires, then remote lookups, then constants, then the
  module table, then state, then functions, then the return.
- No globals beyond the one documented above. No `shared`.
- `task.wait`/`task.spawn`/`task.delay`, never `wait`/`spawn`/`delay`.
- Prefer early returns and guard clauses to nested `if`s.
- Tag warnings with the game name: `warn("[DanceDanceStep] ...")`.
- Clear per-player tables on `PlayerRemoving`. Every service that keys state by `Player` already has
  a `:clear(player)`; call it from the existing handler in `Backend` or `RhythmService`.
- Wrap `DataStore`, `MarketplaceService` and asset loads in `pcall` and handle the failure path.
- Don't invent Roblox APIs.

## Comments: default to none

Write **very few** comments. Code that needs explaining should be rewritten, not annotated: good
names, small functions, named constants. Add a comment **only** for a non-obvious *why*: an engine
quirk, a race condition, a security reason, or a value that has to stay what it is. Most files
deserve zero to three.

Never write comments that restate the code, section banners, commented-out code, changelog or
history comments, `TODO`/`FIXME` without a concrete description, or module header essays. The
pre-commit hook rejects most of these. Don't start comment-only cleanups nobody asked for.

## Rights and content policy

This matters more here than in most projects, because it is a music game.

- **No real K-pop, no licensed music, no celebrity likeness, no real brand or label.** Tracks are
  repo-generated and owned, and every entry in `AudioCatalog` carries a `rights` field and a
  `rightsProof`. `RightsPolicy.luau` lists the rules; `AudioCatalog.isPublicReleaseReady` is the
  gate.
- Art is original pixel art. Characters are fictional placeholders until something is licensed.
- `MonetizationPolicy` keeps gacha disabled and cosmetic-only, and a run that used an ability (`AbilityCatalog`)
  pays but never ranks on a leaderboard. Don't flip those without the policy review the files describe.
- Audio loads one prepared asset at a time (`AudioCatalog.LibraryPolicy`), so a large catalog never
  loads at startup.

## Performance

`PerformanceBudget.luau` holds the targets: 30 fps floor, 60 fps target, 340 runtime stage parts,
170 dance floor parts, 16 stage lights. `VFXController` picks a quality tier at startup and a
watchdog drops it when frame rate sags. New stage decoration goes through a quality profile, and
anything decorative and distant gets the `StreamedVFX` tag so `FarVFXCuller` can cull it.

## Repo hygiene

- Keep diffs minimal and on-task. Don't reformat or rename code you aren't changing.
- No stray files: no `_old`, `backup`, `copy`, `_audit`, `test123` or scratch files. Scratch work
  goes in a temp directory outside the repo.
- Never commit place or model files (`.rbxl`, `.rbxm`) or large binaries.
- Documentation lives in `docs/`. Don't create new `.md` files unless asked; update the existing one.
- Run `scripts/check-clean.sh` (or `scripts/check-clean.ps1`) before finishing a task.
- Turn on the pre-commit hook once per clone: `sh scripts/setup-hooks.sh` or
  `powershell scripts/setup-hooks.ps1`.

## Git

- Small, focused commits, each doing one logical thing.
- Short subject, phrased as a command, no trailing full stop: `Add expert difficulty`, not
  `Added expert difficulty` or `Updates`. Aim for a handful of words; 72 characters is the ceiling,
  not the target.
- Add a body only when the why isn't obvious, wrapped at 72 columns. A couple of plain sentences.
  Say why, not what the diff already shows.
- Check `git status` and `git diff --cached` before committing, and stage only what you meant to
  change.
- Don't commit unless asked. Never skip hooks (`--no-verify`) and never rewrite published history.

### Changelog

Anything a player or another developer would notice gets **one line** in
[docs/CHANGELOG.md](docs/CHANGELOG.md), under **Unreleased**, in the same change that causes it.
That means features, behaviour and balance changes, removals, fixes, and anything that alters the
build or the workflow. Refactors, comment edits and formatting do not.

Write it the way you would tell a teammate: what changed and what it means, in plain words. One
line, two if it genuinely needs it. No restating the diff, no paragraph of justification. When a
place is published, rename **Unreleased** to the version and date and open a fresh one above it.
