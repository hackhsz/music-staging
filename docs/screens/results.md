# Results

**What it is.** The end-of-run screen: a banner (STAGE CLEAR, FULL GROOVE or STAGE FAILED), the score counting up, the rank, grade counts, max combo, accuracy, XP and level, and buttons for the next song, retry and the way back. Failed runs use the same screen.

**Where.** `StarterGui.Derail.Result` (place file). Bound by `UI/Screens/ResultsScreen.luau`. Every piece is found by name and a missing one is skipped.

**Names the code needs** (under `Result`).

| Path | Shows |
| --- | --- |
| `ResultPanel`, `ResultPanel.FullGrovePanel.FullGroveLabel` | slash and banner |
| `ResultPanel.ResultpanelPanel.{ResultpanelpanelLabel, SLabel, AssistedRunLabel}` | score, rank tag, accuracy line (adds ASSISTED RUN) |
| `ResultPanel2.SFrame.SLabel` | rank badge |
| `PerfectPanel.{PerfectLabel, GoodLabel, MissLabel}` | counts (Good is Great + Good + Bad) |
| `ResultPanel3.StatLabel`, `ResultPanel4.StatLabel` | max combo, accuracy |
| `XpFrame.{XpLabel, BaseRankSLabel, XpframePanel.LvPanel.LvLabel}` | XP, breakdown, rank (the bar is `LvPanel`'s hard-edged `UIGradient`, moved by its Offset) |
| `GainPanel.{NewBest.NewBestLabel, Coins.CoinsLabel, GoalLabel}` | new best, coins earned, next goal |
| `NextSongButton`, `RetryButton`, `HubButton.HubLabel` | actions |
| `ResultCrateButton` | forced hidden by the code |

**States.** Hidden; revealing (timed sequence, each beat cancelled if the screen closes, a tap jumps to the end); idle (rank sways, Next pulses); photo mode; cleared, full groove, failed; assisted run.

**Still needed.** From `docs/UI_REQUIREMENTS_CORE_LOOP.md` 3.5, not shown by `show()`: crown and Fans, weekly board place, share card, quest ticks, and the result crate (hidden on purpose). The reveal timings are constants in `ResultsScreen.luau`, not the doc's timeline.
