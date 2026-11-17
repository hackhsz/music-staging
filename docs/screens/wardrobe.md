# Wardrobe

**What it is.** The window for what the player owns: four tabs across the top: ALL, OUTFIT (wands, trails, auras), MOVES (emotes, entrances, poses) and ARENAS, the owned items as cards on the left, and the picked one on the right, tried on your avatar on the pedestal, with EQUIP or UNEQUIP. With nothing owned in a tab it reads NOTHING HERE YET and the button becomes SHOP.

**Where.** `StarterGui.Menu.Root.Holder.Wardrobe`. Bound by `UI/Screens/WardrobePanel.luau`; `Controllers/WardrobeController.luau` sends the change. The tabs come from `CosmeticsCatalog.WardrobeTabs`.

**Layout.** The same shell as the shop: a standalone `Panel` at 1.35:1 (2:1 on touch), never larger than 980 x 740, header row (title, X) at 0.07, the tab bar at 0.135 (four `Pill` tabs, `Primary` while open), and `Page` from 0.225. On the page the card grid (`Grid`, four cards a row) takes the left 0.56; `DetailCard`, a `Card`, the right 0.4, holding the pedestal and preview, name, rarity and kind, state, and a `Pill` `EquipButton` (`Primary` for EQUIP and SHOP, plain for UNEQUIP).

**Names the code needs** (under `Wardrobe`).

| Path | Notes |
| --- | --- |
| `Tabs.Tab1..`, `CloseButton` | each tab's `TabLabel` is filled from `WardrobeTabs` |
| `Page.Grid.List`, `Page.Grid.List.RowTemplate` | card grid (`Card1..Card4`); the list measures its layout, so it scrolls to the last row |
| `Page.{Preview (ViewportFrame) with WorldModel, DetailIcon.Glyph, DetailName, DetailTag, DetailState}` | |
| `Page.EquipButton.EquipLabel` | |

**States.** Tab picked; item picked; equipped or not; empty (nothing owned).

**Still needed.** Shoes, jackets, mics and hair clips have no tab of their own and show under ALL only. An arena's state line reads WEARING IT like a worn item.
