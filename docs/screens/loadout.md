# Loadout (ability picker)

**What it is.** The window where the player picks the abilities for a run: choose a slot along the top, then an ability from the grid. Tabs filter the grid by group; the right side describes the ability under the pointer.

**Where.** `StarterGui.Menu.Root.Holder.Loadout`. Bound by `UI/Screens/AbilityPicker.luau`; `Controllers/AbilityController.luau` sends the choice.

**Layout.** The same shell as the shop and wardrobe: a standalone `Panel` at 1.35:1 (2:1 on touch), never larger than 980 x 740. Header row at 0.07: `TitleTag` (LOADOUT), the `Header.HeaderSub` line beside it, `CloseButton`. Under it the `Equipped` strip, a `Card` (0.025, 0.135, 0.95 x 0.22): EQUIPPED and the count on the left, the four `Slots` in the middle, a `Pill` RESET on the right. Below, `Grid` takes the left 0.56 (the group `Tabs` as `Pill`s, `Primary` while open, then four ability cards a row), and a `DetailCard` the right 0.365 with the group, icon, name, blurb, cost and a `Pill Primary` READY.

**Names the code needs** (under `Loadout`).

| Path | Type |
| --- | --- |
| `Slots.Slot1..` (each with `Icon.Glyph`) | GuiButton |
| `Grid.List` (ScrollingFrame), `Grid.List.Tabs.Tab1..`, `Grid.List.RowTemplate` with `Card1..` | grid and group tabs |
| `DetailIcon.Glyph`, `DetailGroup`, `DetailName`, `DetailBlurb`, `DetailCost` | TextLabel |
| `Equipped.CountPanel.CountLabel`, `Header.HeaderSub` | TextLabel |
| `Equipped.ResetButton`, `ReadyButton`, `CloseButton` | GuiButton |

A card's `UIGradient` carries the ability's group colour.

**States.** Slot empty or filled; slot picked; group tab picked; card hovered or equipped.

**Still needed.** The requirements doc (3.3) also asks for a run score multiplier with an ASSISTED or CLEAN tag, a "Go clean" action and a locked-slot reason; none of those are in `AbilityPicker.luau`. Treat the doc's skills and items split as undecided (its decision 2).
