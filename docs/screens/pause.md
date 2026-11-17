# Pause

**What it is.** A dimmed overlay over a card in the lobby windows' style: the PAUSED title tag, a big pink RESUME, then RESTART, SETTINGS and a red LEAVE, each with an icon (`Glyph`), and the key hint at the bottom. The timing-offset panel (`GameHud.Settings`) opens below the card.
**Where.** `StarterGui.GameHud.Pause`. Bound by `UI/Screens/PauseOverlay.luau`. The small settings panel it opens is `GameHud.Settings` (see `settings.md`).

**Names the code needs.**

| Path | Notes |
| --- | --- |
| `Pause` | overlay; its transparency is the dim |
| `Pause.Card.{ResumeButton, RestartButton, SettingsButton, KeyHint}` | required |
| `Pause.Card.LeaveButton` | optional |
| `GameHud.PauseButton` | stands in only when the run HUD has no pause button of its own |

**States.** Closed; open; closing (short animation); button replaced by the HUD's own `Pause`.

**Still needed.** From the requirements doc (3.4): a 3-beat count-in on resume, and a Retry/Quit split that leads to song select. `PauseOverlay.luau` has Restart and Leave but no count-in; check the controller before building one.
