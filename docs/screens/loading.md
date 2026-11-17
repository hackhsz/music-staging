# Loading

**What it is.** The first thing a player sees: a mini lit floor, a progress bar with a status line, a rotating tip, and a SKIP button that appears late. It fades out when the client is ready.

**Where.** `StarterGui.Loading` (place file). Bound by `src/ReplicatedFirst/LoadingScreen.client.luau`, which waits up to 30 s for the GUI to replicate. If it is missing, the script warns, removes the default screen and sets `LoadingDone` anyway.

**Names the code needs.**

| Path | Type |
| --- | --- |
| `Root` | CanvasGroup (faded out at the end) |
| `Root.Column.Floor.Tile1` to `Tile9` | Frame (recoloured pink, yellow or dark) |
| `Root.Column.Bar.Fill` | Frame (width is the progress) |
| `Root.Column.Status` | TextLabel |
| `Root.Tip` | TextLabel |
| `Root.Skip` | TextButton |

`Backdrop` (gradient), `Title` and `Tagline` are not read by the script; restyle them freely.

**States.**

- Loading: bar fills in three phases (place 30%, UI art to 90%, then waits for the player's `ClientReady` attribute).
- Skippable: SKIP shows after 6 s and ends every wait.
- Done: shown at least 2 s, fades over 0.5 s, the GUI is destroyed and the player's `LoadingDone` attribute is set (onboarding waits for it).

Tunables (seconds, tip text, preloaded GUIs) are constants at the top of `LoadingScreen.client.luau`: `MIN_SHOW_SECONDS`, `SKIP_AFTER_SECONDS`, `TIP_SECONDS`, `FLOOR_STEP_SECONDS`, `TIPS`, `PRELOAD_GUIS`.

**Still needed.** Nothing known. The tips are hard-coded in the script, so they will not follow a rule change in `Timing.luau` on their own.
