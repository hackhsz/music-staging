# Islands (Travel)

**What it is.** The Travel window: a tab per area (the main island's spots, the sky islands), a card per place, and the picked place on a pedestal with a TRAVEL button.

**Where.** `StarterGui.Menu.Root.Holder.Islands`. Bound by `UI/Screens/IslandsPanel.luau` (up to 2 tabs); `IslandController` sends the trip.

**Names the code needs** (under `Islands`).

| Path | Notes |
| --- | --- |
| `Tabs.Tab1..Tab2`, `CloseButton` | |
| `Grid.List`, `Grid.List.RowTemplate` | cards |
| `DetailIcon.Glyph`, `DetailName`, `DetailTag`, `DetailState` | |
| `TravelButton.TravelLabel` | |

**States.** Tab picked; place picked; travel available or not (`DetailState`).

**Still needed.** Nothing known.
