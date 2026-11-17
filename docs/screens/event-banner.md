# Event banner

**What it is.** The call-out for a floor event: a big title such as FLOOR IS LAVA!, what to do, and a 3-2-1 before it starts.

**Where.** `StarterGui.GameHud.EventBanner`. Bound by `UI/Screens/EventBanner.luau`. The game sets only its height on screen so it lands in the grade line's strip.

**Names the code needs.** `EventBanner.{Title, Detail, Count}` (TextLabels). An optional `UIStroke` on the frame is faded with it; `Pop` UIScales are added to the frame and `Count`.

**States.** Hidden; shown with title and detail; counting down.

**Still needed.** Nothing known.
