# Lobby HUD

**What it is.** The HUD between runs: an icon rail on the left, the player card (avatar, rank, name, coins) and the rank strip (next rank, XP bar, what it opens) with Travel, Rewards, Group and Settings buttons, the daily challenges, and the play-mode button with match status. Clicking the card swaps the challenges for the player's stats. It slides off while a run plays.

**Where.** `StarterGui.Lobby` (place file). Bound by `UI/Screens/SideMenu.luau` (rail, card, daily, stats) and `UI/Screens/MultiplayerPanel.luau` (mode button, status). The hint bars in it are bound by `HintBar` (see `hints.md`).

**Names the code needs.**

| Module | Paths |
| --- | --- |
| SideMenu | `Rail.Buttons.{HomeButton, SongButton, LoadoutButton, ShopButton, WardrobeButton, QuestsButton}`; `RightColumn.Card.{LevelLabel, NameLabel, CoinLabel, AddCoinsButton, StatsButton, AvatarFrame.Avatar}`; `RightColumn.Card.TopButtons.{IslandsButton, SettingsButton, GiftButton (with Dot), CommunityButton (with Dot)}`; `RightColumn.RankStrip.{NextLabel, XpLabel, HintLabel, Bar.Fill, RankButton}`; `RightColumn.Card.CoinGain`; `RightColumn.Daily.Row1..`; `RightColumn.Stats` |
| MultiplayerPanel | `Status` (TextLabel); `RightColumn.Actions.ModeButton` with `ModeLabel` |

**States.** Shown or slid off (run active); rank-up ready (the strip takes `Done` and opens the picker on the rank-up song); gains roll in when the menu slides back; daily versus stats view; gift and group dots on or off; mode button label and match status text set by `MultiplayerPanel`.

**Still needed.** From `docs/UI_REQUIREMENTS_CORE_LOOP.md` 3.1: a next-goal line ("6 Fans to Pack 3"), an announcement ticker, and a first-session mode that shows only the essentials. No module implements these.
