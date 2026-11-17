# Screens

A TLDR per screen: what it is, where it is authored, the names the code needs, its states, and what is missing. Authored means a ScreenGui in the place file that a module binds by name (restyle it in Studio, keep the names). Built means the module creates it in code.

| Screen | File | Authored | Status |
| --- | --- | --- | --- |
| Loading | [loading.md](loading.md) | `StarterGui.Loading` | done |
| Transition | [transition.md](transition.md) | `StarterGui.Transition` | partial (island-stage fade only; no menu wipes) |
| Lobby HUD | [lobby-hud.md](lobby-hud.md) | `StarterGui.Lobby` | partial |
| Hints | [hints.md](hints.md) | `StarterGui.Lobby`, `GameHud.RunHint` | done |
| Menu (window host) | [menu.md](menu.md) | `StarterGui.Menu` | done |
| Loadout | [loadout.md](loadout.md) | `Menu.Loadout` | partial |
| Shop | [shop.md](shop.md) | `Menu.Shop` | done |
| Wardrobe | [wardrobe.md](wardrobe.md) | `Menu.Wardrobe` | done |
| Quests | [quests.md](quests.md) | `Menu.Quests` | partial |
| Islands (Travel) | [islands.md](islands.md) | `Menu.Islands` | done |
| Market (UGC) | [market.md](market.md) | `Menu.Market` | partial (market closed) |
| Rewards | [rewards.md](rewards.md) | `Menu.Rewards` | done |
| Community | [rewards.md](rewards.md) | `Menu.Community` | done |
| Settings | [settings.md](settings.md) | `Menu.Settings`, `GameHud.Settings` | partial |
| Song select | [song-select.md](song-select.md) | `StarterGui.Songs` | partial |
| Run HUD (pad) | [run-hud.md](run-hud.md) | `StarterGui.PadHud`, `Derail.HUD`; SongBar built | partial |
| Note highway | [note-highway.md](note-highway.md) | built | done |
| Event banner | [event-banner.md](event-banner.md) | `GameHud.EventBanner` | done |
| Pause | [pause.md](pause.md) | `GameHud.Pause` | partial |
| Results | [results.md](results.md) | `StarterGui.Derail.Result` | partial |
| Tutorial overlay | [tutorial.md](tutorial.md) | `StarterGui.Lesson` | done |
| Progress pop-ups | built on `ProgressPopups` | `StarterGui.Progress` (`Dim`, `RankUp`, `Toast`) | done |

| Stages (lobby pieces, mode list, setlist, song browser, roadmap, prompt, results XP, stage-up) | below | `StarterGui.Stages` | partial (zone gate and in-world card not bound) |

Statuses are against `docs/UI_REQUIREMENTS_CORE_LOOP.md` and the code as read; done means nothing known is missing.

## Stages

`StarterGui.Stages` holds the 6 Nov Stages handoff, one hidden 16:9 frame per wireframe. `UI/Screens/StagesScreen`
binds `Lobby`, `ModeList`, `Setlist` and `StageUp` and fills them from the server's stages snapshot
(`RankCatalog.stages`, sent in `ProfileSync` and in a run's summary); `UI/Screens/StagePanels` binds `SongSelect`,
`Roadmap`, `ChallengePrompt` and `Results`; `StagesController` wires the buttons. `ZoneGate` and `WorldChallenger`
are layout only. Every element the handoff numbers carries
its id in a `SpecId` attribute (`S2-03`, `R-08`...); keep the names when restyling.

The lobby's rank strip opens `Setlist`; `Lobby.ModeTile` opens `ModeList`; a rank-up plays `StageUp` after the results.
PLAY asks the server for the chart directly (`LobbyController.requestChart`); a challenger's chart with the bar
full goes through `ChallengePrompt` first. `Setlist.Tabs` opens the song browser (`AllSongsTab`) and the roadmap
(`RoadmapTab`). `Results.XpPanel` shows beside the results screen. Keep buttons out of the top 60 px of the
screen: clicks there do not reach our GUI, which is why every BACK button sits on the left edge. Rows are clones of `List.Row1` (`List.RowSelected` when
picked) and reveal cards are clones of `Cards.Card1`. A pip takes its look from `Pip1` (done), `Pip3` (current) or
`Pip4` (locked), and a mode tile from `StageChallengeTile` (picked) or `FreePlayTile` (resting), as authored.
Hidden until there is data for them: friends, the weekly league, duels, the difficulty selector and all art slots.

| Frame | Wireframe | Holds |
| --- | --- | --- |
| `Setlist` | S2 | `StageTitle`, `Pips`, `Friends`, `XpBar`, `Tabs`, `List` (`Row1`, `RowSelected`, `ChallengerRow`), `Detail` (`Difficulty`, `XpPreview`, `ChallengerStrip`, `PlayButton`) |
| `SongSelect` | S8 | `Filters`, `Difficulty`, `Notice`, `List` (section headers, `Row`, `RowSelected`, `LockedRow`; rows carry `XpChip`), `Detail` (`XpBox`, `BestLabel`, `SelectButton`) |
| `Lobby` | S1 | `ModeTile`, `PlayButton`, `DailyChip`, shown with the lobby HUD; `StageBadge`, `StageCard`, `StagesNotice` and `LeagueTile` stay hidden (the lobby card already shows the stage) |
| `ModeList` | S1 mode list | `Dimmer`, `Panel` with `StageChallengeTile`, `FreePlayTile`, `WeeklyLeagueTile`, `DuelsTile`, `BackButton` |
| `Results` | R | `XpPanel`: one line per XP part, `TotalBar`, `XpBar` (`Fill` before, `GainFill` this run), `NextStep`, `NextGrade`, `ChallengeButton`; lines sit in `Lines` and hide when a part is zero |
| `StageUp` | S7 | `StageBadge`, `Title`, `XpRow`, `Beaten`, `Cards` (`Card1`..), `UnlockTag`, `Footer`, `PlayButton`, `TapCatcher` |

| `Roadmap` | PDF p. 11 | `Hero` (current stage, challenger, XP, `ChallengeButton`, `PlayButton`), `Path` (`Node1`..`Node5` with `Stamp`, `YouTag`, `LockTag`), `Card1`..`Card5`; a node and a card take their look from the 1st (done), 3rd (current) and 4th (locked) as authored |
| `ChallengePrompt` | PDF p. 17 | `Panel`: `Portrait`, `NameTag`, `Info` (song, grade needed, XP, `Target`), `ChallengeButton`, `NotNowButton` |
| `ZoneGate` | PDF p. 21 | `Banner`, `LockIcon`, `XpBar`, `NeedLabel`, `OpenButton`; layout only |
| `WorldChallenger` | PDF p. 20 | `CountTag`, `Card`, `PromptButton`, `LockedTag`; layout only |

`Setlist.Notice` is the one-time half-XP notice (S8-09); its `CloseButton` and a dismissed `StageUp` are saved through
the `StageSeen` remote (`stageNoticeSeen`, `stageRevealSeen` in the profile), so a reveal left unseen replays in the lobby.

The art is the `Stage_` sprite set plus flat frames for the panels. Portraits are set by challenger name
(`Stage_PortraitHana`...); song art is one of two generic covers until real covers exist.

## Still needed

Screens the requirements doc or Master Plan call for that no module under `UI/Screens/` implements:

- Count-in and song-start title card (T7). Only a count-in text exists on the run HUD.
- Fail card. A failed run shows STAGE FAILED on Results, with no separate Retry / Song select card or fail sequence.
- Pack unlock in the pop-up queue (requirements 2.8); the rank-up card and achievement and daily toasts are built.
- Pack unlock moment, crowns and Fans on song select and results.
- Result crate opening (the crate button is hidden in code).
- Share card (from Lv 11).
- Announcement ticker and News list.
- Inventory, Achievements (as a screen of their own; they are a tab in Quests now) and Profile / Character screens (requirements v2 scope).
- NPC dialogue (tutorial or quest).
- First-run calibration prompt (calibration exists only as the offset in Settings).
- A leaderboard screen. Boards exist in the world (`World/HubBoards.luau`, `LeaderboardController`), not as a window.
- Disconnect-mid-song return view (an open question in the requirements doc).
- Reduced-motion handling: nothing reads `GuiService.ReducedMotionEnabled`.
