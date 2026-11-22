# Islands (Travel)

**What it is.** The Travel window: a tab per area (the main island's spots, the sky islands), the area's map with a numbered pin per place, the places as a numbered list (picture, name, short tag), and the picked place in a detail panel with what is there and a TRAVEL button. An area whose places have no pins (the sky islands) hides the map and the list takes its room.

**Where.** `StarterGui.Menu.Root.Holder.Islands`. Bound by `UI/Screens/IslandsPanel.luau` (up to 2 tabs); `IslandController` sends the trip.

**Names the code needs** (under `Islands`).

| Path | Notes |
| --- | --- |
| `Tabs.Tab1..Tab2`, `CloseButton` | |
| `Map` with `Pin1..8` (`NumberLabel`) and `HereTag` | a pin's place on the map is `IslandCatalog`'s `pin`, each axis 0 to 1 of `Map` |
| `List.Place1..8` (`Thumb`, `NameLabel`, `TagLabel`, `HereChip`) | `List` carries `MapPosition`/`MapSize` and `WidePosition`/`WideSize` for its two placements |
| `DetailScene`, `DetailName`, `DetailState`, `What.Chip1..3` (`Label`) | |
| `TravelButton.TravelLabel` | lit while travel is possible |

**States.** Tab picked; place picked; travel available or not (`DetailState`).

**Still needed.** Nothing known.
