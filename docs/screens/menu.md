# Menu (window host)

**What it is.** The shell for the lobby's windows. One window is open at a time beside a rail, over a dimmed backdrop. It only opens, switches and closes; each window's own screen fills it in.

**Where.** `StarterGui.Menu` (place file). Bound by `UI/Screens/MenuScreen.luau`.

**Names the code needs.**

| Path | Notes |
| --- | --- |
| `Root`, `Root.Backdrop`, `Root.Holder` | `Holder` gets a `Pop` UIScale |
| `Holder.Rail.Buttons.{HomeButton, SongButton, LoadoutButton, ShopButton, WardrobeButton, QuestsButton, IslandsButton, SettingsButton}` | Rail buttons; the open one glows |
| `Holder.{Loadout, Shop, Settings, Quests, Islands, Market, Rewards, Community, Wardrobe}` | The windows, hidden until opened |

**Phones and tablets.** The menu picks its layout once, at startup. A phone-sized screen, or a touch screen with no mouse (tablets), gets the touch layout. In Studio, set these on any element, with no code needed:

| Rule | Effect on touch |
| --- | --- |
| A window named `<Name>Phone` next to `<Name>` (none yet) | replaces the desktop window |
| `PhoneSize` attribute (UDim2) on anything under `Root` | its Size |
| `PhoneAspect` attribute (number) | its UIAspectRatioConstraint |

Set now: `Holder` (0.98 x 0.98, aspect 2.4), `Rail.Buttons` (0.95) and each rail button (0.97). The buttons come out about 48 x 55 pt on a phone in landscape; five stacked in that height is the most that fits.

A window with the `Standalone` attribute opens without the rail (Settings does).

**States.** Closed; one window open; blocked (a `blocked` flag in `MenuScreen.luau` stops it opening); closing.

Windows: [loadout.md](loadout.md), [shop.md](shop.md), [settings.md](settings.md), [quests.md](quests.md), [islands.md](islands.md), [market.md](market.md), [rewards.md](rewards.md) (Rewards and Community), [wardrobe.md](wardrobe.md).

**Still needed.** Nothing known for the host. The requirements doc lists Inventory, Achievements (as its own screen), News and Profile windows; none exist (see the README).
