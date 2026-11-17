# Tutorial overlay

**What it is.** The first-join cards: a drill card with a looping demo of its move and a pip per try, the timing check's tap pad, a one-action card (PLAY), and tips that can ring a lobby button.

**Where.** Authored in `StarterGui.Lesson`, bound by `UI/Screens/TutorialOverlay.luau`. `Controllers/OnboardingController.luau` drives it; the drills and their call-outs come from `Shared/TutorialChart.luau`.

**Names the code needs.**

| Path | Notes |
| --- | --- |
| `Card` | the song card's art and `Outline`; its authored spot is the in-run one (bottom centre), the lobby puts it up top |
| `Card.Step`, `Title`, `Body`, `Hint` | lesson count, move name, instruction, hint (turns green or red as the per-try call-out) |
| `Card.Demo` with `Tile11..Tile33`, `Dancer`, `Label` | the looping mini floor; the text slides into its place when it stops |
| `Card.Tries.Pip` | template for one pip per try (dim, green, red) |
| `Card.Skip`, `Card.Action` | `Pill` buttons; Action is PLAY on the first-song card |
| `TapPad.Tap`, `TapPad.Count` | the timing check |

**States.** Drill card (demo plays until the first try is judged, pips fill); after a drill (FLAWLESS!, NICE! with the next move, or TRY AGAIN); timing check (tap pad); action card; tip with highlight ring. The card hides while the game is paused or a lobby window is open, except a tip.

**Still needed.** The doc (`UI_REQUIREMENTS_CORE_LOOP.md` 2.8) puts NPC dialogue in the pop-up queue; nothing implements dialogue. The card has no phone layout of its own yet.
