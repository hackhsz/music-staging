# Dance Dance Step

A 5x5 tile rhythm game for Roblox, written in Luau and synced into Studio with Argon.

Pick a track and step onto the lit dance floor. Each beat telegraphs a target tile a couple of beats
early; you walk there and **stand** on it. The beat is judged by where you are standing and how long
you settled, not by tapping on time. Combo, crowd hype and Fever build as you land beats, and a life
gauge drains on misses until the run fails. Holds ask you to stay put, slides ask you to cross a
path, and danger tiles ask you to be anywhere else.

Coins, cosmetics, unlocked songs, achievements, XP and lifetime stats persist. The dance floor does
not.

Two players can share a session in co-op (two floors, or one shared floor) or battle for the higher
score. Everything is original: the tracks are generated and owned by the project, and no music,
likeness, choreography or branding is borrowed from anyone.

## Setup

1. Install [Argon](https://argon.wiki/) (VS Code extension or CLI).
2. Open the place in Roblox Studio and install the Argon Studio plugin.
3. From the repo root, run `argon serve`, then connect from the Studio plugin.
4. Only `src/` is synced, as mapped by `default.project.json`. It also pins
   `SoundService.RespectFilteringEnabled`.
5. Press Play. The stage, the dance floor and the entire HUD are built from code at runtime, so an
   empty baseplate is enough to start.

In Studio, profile loads and saves are skipped and leaderboards fall back to in-memory boards, so
every play test starts from a fresh default profile. Test persistence in a real server.

## Controls

| Input | Does |
|---|---|
| WASD, arrows, D-pad | Move one tile |
| Tap a tile | Walk to that tile (touch) |
| 1 / 2 / 3 | Pick a song |
| N | Next song |
| R | Restart the run |
| P | Pause during a run, photo mode on the results screen |
| B | Shop |
| O | Settings, then `-` and `=` to calibrate timing offset |
| E | Emote |
| G | Host a private party, Y to rematch |

## Layout

```
src/
  ServerScriptService/Server    the server's only Script: boots ServerStorage.Server.Inits
  StarterPlayerScripts/Client   the client's only LocalScript: boots ReplicatedStorage.Client.Inits
  ReplicatedStorage/Shared/     the rules, the charts and the catalogs, plus Packages/ and Utility/, loaded by both sides
  ReplicatedStorage/Client/     Inits/ (Main wiring and the client inits), plus UI, Input, Controllers and Net layers and the view, audio and VFX controllers
  ServerStorage/Server/         Inits/ (RemoteBootstrap, Backend, RhythmService...) plus Services/ (classes, constructed in Backend)
  ServerStorage/Tests/          specs for the pure Shared modules
docs/                           the design plan, progression spec, hub layout, UI style, changelog
scripts/                        hygiene check and git hook setup
tools/scripts/                  image helpers for UI art
```

## Architecture in one page

- **Two entry scripts and a lifecycle.** `ServerScriptService.Server` and
  `StarterPlayerScripts.Client` boot their side's `Inits` through `Shared/Utility/Lifecycle`:
  `Inits/Priority` runs first through `Init()`, then every other init's `Start()` is spawned. Each
  init is a ModuleScript; nothing else under `src/` runs on its own.
- **The server inits.** `RemoteBootstrap` (priority) creates the RemoteEvents, `Backend` wires the
  services together and owns profiles and purchases, `RhythmService` judges every run, and
  `FeatureRegistry` loads the catalogs so they validate at boot. `RhythmService` reaches the
  Backend through `BackendInit.Get()`; there are no globals.
- **The network contract is a table.** `Shared/RemoteContract.luau` declares every event, its
  direction, its payload keys and its rate limit. Entries are keyed by name, so adding one is safe
  anywhere in the table.
- **The server is the judge.** It reads the player's real character position, grades the beat,
  applies score, life, hype and Fever, and sends the result. The client animates ahead of the
  verdict and defers to it. Suspicious input is counted on the session, not just dropped.
- **Timing lives in one file.** `Shared/Timing.luau` owns the judgement windows, the three
  difficulty profiles and the stand-and-wait grading.
- **Charts are data.** A song is a table of steps with a beat, an x and a y, validated by
  `SongSchema`. `BeatPatterns` holds an authored 5x5 vocabulary and `ChartGenerator` stitches it
  into full tracks whose consecutive targets are always one tile apart.
- **Data is a DataStore profile.** `PlayerDataService` owns the schema, backfills new keys into old
  profiles on load, and autosaves every 60 seconds.
- **The HUD, floor and lighting are code; the arena is in the place.** `Workspace.Arena` holds the
  stage, wall, crowd and screens as ordinary parts, and the client binds and animates them. There is
  no authored ScreenGui.

## Pitfalls

- `require()` caches for the whole Studio session. Edit a catalog and require it again in Edit mode
  and you get the old table.
- Audio owned by a different user or group than the universe will not load. Entries in
  `AudioCatalog` without an `audioAssetId` play silent on purpose.
- Only one song's audio is prepared at a time, by design. Don't preload the catalog.
- The camera is scriptable and fixed over the floor, so moving the board origin moves the shot.
- Stage parts are budgeted. Check `PerformanceBudget` before adding decoration, and tag anything
  distant and decorative with `StreamedVFX` so it gets culled.

## Contributing

- Read [CLAUDE.md](CLAUDE.md) first. It is the full architecture and style contract, not just a note
  for AI tools.
- `--!strict` on new modules, tabs, double quotes, `PascalCase` modules, `camelCase` locals,
  `UPPER_SNAKE` constants, `task.*` never `wait`/`spawn`/`delay`.
- Comments default to none. Write code that explains itself; comment only a non-obvious *why*.
- Server authority, always. Controllers display; the server decides.
- Timing, scoring and economy numbers belong in their module, never inline at a call site.
- No real music, likeness or branding. See the rights policy section in CLAUDE.md.
- Run the hygiene check before finishing: `sh scripts/check-clean.sh` or
  `powershell scripts/check-clean.ps1`.
- Enable the pre-commit hook once per clone: `sh scripts/setup-hooks.sh` or
  `powershell scripts/setup-hooks.ps1`.
- Small, focused commits with imperative subjects. Never commit `.rbxl`/`.rbxm` or large binaries.
