# Hints

**What it is.** The controls hint and the onboarding tip line, in the lobby and during a run.

**Where.** `UI/Screens/HintBar.luau`. In a run: `StarterGui.GameHud.RunHint`. In the lobby and on results: `StarterGui.Lobby`. If the Lobby bars are missing, `HintBar` builds its own in code.

**Names the code needs.**

| Place | Paths |
| --- | --- |
| Lobby | `Hint.HintLabel`, `Onboarding.OnboardingLabel` |
| GameHud | `RunHint.ControlsHint`, `RunHint.Onboarding` (both TextLabel) |

**States.** Lobby, run and results layouts; small, touch and phone flags in `HintBar.luau` (the hint text can differ by device); onboarding tip shown or faded out.

**Still needed.** Nothing known.
