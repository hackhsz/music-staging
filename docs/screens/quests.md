# Quests

**What it is.** Two tabs, DAILY and ACHIEVEMENTS (each with a done count), a strip with the player's rank and XP, and the quests as full-width rows with progress bars and their reward.

**Where.** `StarterGui.Menu.Root.Holder.Quests`. Bound by `UI/Screens/QuestsPanel.luau`; `QuestController` builds the rows from the profile.

**Layout.** The same shell as the shop: a standalone `Panel` at 1.35:1 (2:1 on touch), never larger than 980 x 740, header row (title, X) at 0.07. The tab bar at 0.135: two `Pill` tabs (`Primary` while open) with a `Count` each, and `ResetLabel` (NEW CHALLENGES IN ...) on the right. `LevelCard`, a `Card` strip (0.025, 0.225, 0.95 x 0.16): the badge on its pedestal, YOUR LEVEL and the level, the XP bar and label, the hint on the right. `Grid` fills 0.405 to 0.98 with rows at 10:1.

**Names the code needs** (under `Quests`).

| Path | Notes |
| --- | --- |
| `Tabs.Tab1..` (each with `Count`), `CloseButton` | tab keys are `daily` and `achievements` |
| `Grid.List`, `Grid.List.RowTemplate` (rows have `Bar.Fill`) | |
| `LevelBadge.Glyph`, `DetailName`, `XpLabel`, `XpBar.Fill`, `ResetLabel` | level, XP and reset timer |

**States.** Daily or achievements tab; row in progress or done.

**Still needed.** The requirements doc (3.1) lists a claimable state for daily quests; `QuestsPanel.luau` has no claim code, so rewards are not claimed here.
