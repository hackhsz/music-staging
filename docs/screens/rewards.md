# Rewards

**What it is.** Play-time gifts: eight gifts that unlock after 5, 10, 15, 20, 30, 45, 60 and 90 minutes in one visit, each claimed once per visit. Coins at 5, 10, 20 and 45 minutes (25 to 150); shop items at 15 (Mint Bubble Wand), 30 (Equalizer Trail), 60 (Sunset Star Wand) and 90 (Midnight Moon Wand), each paying coins instead to a player who owns it. Leaving starts them over. A code box sits along the bottom. The red dot on the lobby's Rewards button shows while a gift is ready.

**Where.** `StarterGui.Menu.Root.Holder.Rewards`. Bound by `UI/Screens/RewardsPanel.luau`; `RewardsController` draws the countdowns and asks for each claim. The tiers are `Shared/Catalogs/TimeRewards.luau`. The server (`RewardService`) times the visit from the join and pays through `ClaimReward` with `time:<tier id>`; nothing about the visit is saved.

**Layout.** On the Settings grid: a standalone `Panel` at 1.9:1 (2.4:1 on touch), never larger than 900 x 474.

```
[REWARDS tag]                                        (X)
PLAY TO UNLOCK GIFTS          Timers restart when you rejoin.
 [gift 5 MIN ][gift 10 MIN][gift 15 MIN][gift 20 MIN]
 [gift 30 MIN][gift 45 MIN][gift 60 MIN][gift 90 MIN]
[ TYPE A CODE        ][REDEEM]   code result
```

| Element | Position | Size | Notes |
| --- | --- | --- | --- |
| `TitleTag`, `CloseButton` | as in Settings | as in Settings | |
| `Heading`, `Note` | 0.025 / 0.975, 0.2 | 0.5 / 0.42 x 0.07 | pink heading; the note is right aligned, capped at 16 |
| `Gifts` | 0.025, 0.29 | 0.95 x 0.5 (0.52 tall on touch) | `UIGridLayout`, 4 to a row |
| `CodeField`, `RedeemButton` | 0.025 / 0.4, 0.955 (anchor bottom) | 0.36 / 0.13 x 0.1 (0.12 tall on touch) | `RedeemButton` is a `Pill Primary` |
| `CodeResult` | 0.55, 0.905 | 0.425 x 0.05 | green or red |

A gift tile (`Templates.GiftTile`, a `Card`): `IconTile` with the gift `Glyph` on the left, then `TimeLabel` (5 MIN), `CoinIcon` and `RewardLabel` (+10, gold; an item's name in its rarity colour with the coin hidden), and `ClaimButton` with `ClaimLabel` at the bottom right. Measured on an iPhone SE, a tile is about 139 x 63 pt and its pill only 20 pt tall, so a tap anywhere on a ready tile claims it.

**Names the code needs** (under `Rewards`).

| Path | Notes |
| --- | --- |
| `Gifts` | a tile per tier, authored under the tier's id (`t5` to `t90` are in the place); a tier with no tile gets a copy of `Templates.GiftTile` |
| tile `TimeLabel`, `RewardLabel`, `ClaimButton.ClaimLabel` | |
| `CodeField.CodeBox` (TextBox), `RedeemButton`, `CodeResult` | |
| `CloseButton` | |

**Art.** Each tier's icon is its `glyph` in `TimeRewards.luau` for now (cash, a coin bag, a gift, and each item's own). The art brief is `Art Prompts/Reward Icons - ChatGPT.txt`, next to the repo.

**States.** A gift is waiting (the pill shows the countdown), ready (CLAIM, `Primary`) or claimed (DONE). Code result ok or failed.

## Community

**What it is.** The Group Rewards window (titled GROUP REWARDS): the thank-you coins (Like +50, Favorite +50, Join the group +150 and the Group Star Aura, with the group perks under them) and the daily gift (+50 a day, 2x in the group). Opened by the lobby's Group button (`Lobby.RightColumn.Card.TopButtons.CommunityButton`), whose `Dot` shows while the daily gift is ready.

**Where.** `StarterGui.Menu.Root.Holder.Community`, bound by `UI/Screens/CommunityPanel.luau`; `CommunityController` sends the claims (`social:<id>` and the `daily-lightstick-glow` item through `ClaimReward`) and opens Roblox's join prompt when the group check fails. The rewards are `Shared/Catalogs/SocialRewards.luau`.

**Layout.** The same shell as Rewards: heading THANK-YOU COINS at 0.025, 0.2; `Socials` (0.025, 0.29, 0.55 x 0.52) with three `Card` rows; `GroupPerks` as a `Pill` line at the bottom left; `GiftCard`, a `Card` at 0.6, 0.2 (0.375 x 0.755), on the right.

| Path | Notes |
| --- | --- |
| `Socials.{Like, Favorite, Community}` with `NameLabel`, `RewardLabel`, `ClaimButton.ClaimLabel` | named after the `SocialRewards` action |
| `GroupPerks` | |
| `GiftCard.GiftReward`, `GiftCard.GiftState`, `GiftCard.GiftButton.GiftLabel` | |
| `CloseButton` | |

**States.** Each row open (CLAIM, `Primary`) or done (DONE); the gift ready (OPEN, `Primary`) or waiting (WAIT, with the time left).
