# Quests

**What it is.** Two tabs beside the title, DAILY and ACHIEVEMENTS (each with a done count). Daily: a TODAY bar (done count, coins claimed today, time to the reset), the three challenges as rows with their own icon, a progress bar and either the reward, a CLAIM button or a claimed mark, the streak with seven markers, the first-song bonus and the rank strip. Achievements: a summary, a detail card for the picked achievement (it opens on the one closest to done) and a scrolling road of medals, one per `AchievementCatalog` entry in order, three to a row, snaking.

**Where.** `StarterGui.Menu.Root.Holder.Quests`. Bound by `UI/Screens/QuestsPanel.luau`; `QuestController` builds the rows from the profile.

**Layout.** Album style (designs in `Encore UI Brief/screenshots/mockup-window-quests-*.png`). No style-sheet tags are used in this window.

**Names the code needs** (under `Quests`).

| Path | Notes |
| --- | --- |
| `Tabs.Tab1..2` (each with `Count`), `CloseButton` | |
| `Daily.TodayBar.{DoneLabel, CoinsLabel}`, `Daily.ResetChip.Label` | |
| `Daily.Row1..3` (`IconTile.Icon`, `DoneMark`, `NameLabel`, `Bar.Fill`, `ProgressLabel`, `RewardChip`, `RewardLabel`, `ClaimButton.Label`) | a row and its button are lit while the reward waits |
| `Daily.Streak` (`ValueLabel`, `Dot1..7`), `Daily.Bonus.ValueLabel`, `Daily.Rank` (`NumberLabel`, `NameLabel`, `XpLabel`, `Bar.Fill`) | |
| `Achievements.Summary` (`CountLabel`, `Bar.Fill`) | |
| `Achievements.Detail` (`Caption.Label`, `Badge`, `NameLabel`, `GoalLabel`, `Bar.Fill`, `ProgressLabel`, `Reward.{Icon, Label}`) | |
| `Achievements.Road.Canvas` with `MedalTemplate` (`Badge`, `Lock`, `NameLabel`, `RewardLabel`) and `LineTemplate` | the panel clones a medal and a stretch of road per achievement and sizes the canvas to fit |

**States.** Daily or achievements tab. A challenge is in progress, claimable (CLAIM, lit) or claimed. An achievement is earned, in progress or locked; one is picked for the detail card.

**Still needed.** Nothing known. A challenge left unclaimed is paid by the server when the day turns (`RewardService._turnDaily`).
