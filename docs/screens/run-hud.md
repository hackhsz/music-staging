# Run HUD (pad)

**What it is.** What the player sees while dancing: song card and difficulty, score, life, a timeline, the combo with its grade call-out, the on-screen WASD and CLAP keys, the rival card in versus, the ability cards, and a song bar with accuracy, rank and Fever. The floor itself is a world object, not UI.

**Where.** `StarterGui.PadHud` (place file), one frame per layout: `Desktop` and `PhoneLandscape`. Bound by:

| Module | Part |
| --- | --- |
| `UI/Screens/PadHud.luau` | the top block |
| `UI/Screens/StepPad.luau` | the keys |
| `UI/Screens/RivalPortrait.luau` | the `RivalCard` |
| `UI/Screens/AbilityBar.luau` | each layout's `Abilities` frame |
| `UI/Screens/SongBar.luau` | built in code, not authored |
| `UI/AuthoredRunHud.luau` | the `Derail.HUD` HUD, used when `USE_AUTHORED_HUD` is true in `HUDController.luau` |
| `UI/Screens/RunHud.luau` | code-built fallback, only made when the authored HUD is off |

**Names the code needs.** A layout missing a required one warns and does not draw.

- PadHud, per layout: `SongCard.{Title, Difficulty.Label}`, `ScorePanel.Value`, `LifePanel.Track.Fill`, `Pause`, `Combo.{Body.Number, Row.{Label, Multiplier, Shield}}`, `GradeLine.{Grade, Detail}`, `TimeLine.{Head, Fill}`, `VersusLine.{You, Rival, RivalFill}` with `Face` and `Initial` under each of You and Rival. Optional: `LifePanel.Track.Ghost`, `Fill.Shine`, `Combo.Body.Burst`, `Combo.{BeatRing, Sparkle, Shatter, HitBurst}`, `EdgeGlow.{Fever, Danger, Break}`, `TimeLine.{Elapsed, Total}`.
- StepPad, per layout: `Keys` cluster with `Clap`, `Up`, `Left`, `Down`, `Right`; each key needs `Back.Fill`, `Cap`, `Flash` (optional `Letter`).
- RivalPortrait: `RivalCard.{Back, Avatar (ViewportFrame), Bubble.{Light, Dark, Text}, Headshot, RivalName}`, optional `Art`.
- AbilityBar: `Abilities.Slot1..Slot4`, each with `Icon`, `Title`, `Timer`; optional `Badge`, `Charge.Fill`.

**States.** Layout by viewport (desktop or phone landscape); block and keys shown separately (`BlockShown`, `KeysShown` attributes); solo or versus; combo tiers, milestones, break; low life; Fever; keys guided (tile, clap), pressed; ability cards idle, running, on the floor.

**Still needed.** From `docs/UI_REQUIREMENTS_CORE_LOOP.md` 3.4: a title card and entrance sequence at song start (only a count-in text exists, `RunHud.showCountdown`), a fail sequence before Results, and a reduced-motion mode (no module reads `ReducedMotionEnabled`).
