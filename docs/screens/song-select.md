# Song select

**What it is.** The song picker: one row per song, a tab per pack, difficulty badges for the picked song, the player's best on it, an audio preview with a visualizer, and a Continue button.

**Where.** `StarterGui.Songs` (place file). Bound by `UI/Screens/SongSelectScreen.luau`; `LobbyController` shows it and handles the pick.

**Names the code needs** (under `Songs`).

| Path | Notes |
| --- | --- |
| `Holder.HolderFrame.HolderframeList` (ScrollingFrame) | rows are clones of `SongButton`, or `SongButton2` when selected; a row reads `SongLabel` and `APanel` |
| `SongsFrame2` | pack tabs: every GuiButton in it, in layout order, is a pack |
| `SongsFrame` (title strip), `SongsFrame3`, `SongsFrame4` (one badge per difficulty) | |
| `BestPanel.{BestLabel, ALabel, BestpanelLabel, ComboLabel, ClearLabel}` | rank, score, combo, status |
| `EncoreOriginalBpmPanel.EncoreOriginalBpmLabel` | song info |
| `SongsPanel` (ImageLabel, with `BackgroundFx`), `SongsPanel2.{PreviewLabel, Visualizer}`, `ASongPanel`, `Backdrop.UIGradient` | backdrop, preview |
| `ContinueButton`, `BackButton` | |

**States.** Row selected or not; locked song (greyed, with the requirement text such as UNLOCKS AT TRAINEE II); locked difficulty badge; best "NEW" or "CLEAR"; a pack tab with no songs shakes and shows a "soon" text; keyboard moves song and difficulty.

**Still needed.** From `docs/UI_REQUIREMENTS_CORE_LOOP.md` 3.2, not in the module: crowns per difficulty, Fans and the next pack threshold, next-crown line, weekly board rank, sort and filter, reopening on the last song and difficulty. The module's comments and tags still use the old working name "Encore" (`EncoreOriginalBpmPanel`); keep the name until the GUI is renamed in Studio.
