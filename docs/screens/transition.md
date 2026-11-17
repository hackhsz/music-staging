# Transition

**What it is.** A full-screen cover with a caption ("TO THE STAGE", "BACK TO THE ISLAND") that hides the world swap between the island and the stage.

**Where.** `StarterGui.Transition` (place file). Bound by `src/StarterPlayerScripts/Client/UI/Screens/TransitionScreen.luau`, built in `HUDController`. Called by `Controllers/HubController.luau` (`cover` then `reveal`; the caption strings are `TO_STAGE_TEXT` and `TO_ISLAND_TEXT` there).

**Names the code needs.**

| Path | Type |
| --- | --- |
| `Cover` | CanvasGroup (starts hidden; its `GroupTransparency` is tweened) |
| `Cover.Caption` | GuiObject (optional `UIScale` named `Pop` is used for the pop-in) |
| `Cover.Caption.CaptionLabel` | TextLabel |
| `Cover.Floor.Tile1`–`Tile9` | Frame (lit in turn while the cover is up; optional) |

Anything else under `Cover` (`Backdrop`, `Tagline`, the banner image on `Caption`) is decoration and free to restyle.

**States.**

- Hidden.
- Covering: fades in over 0.22 s, caption pops from 0.85 to 1, then the swap callback runs.
- Revealing: fades out over 0.4 s once the player has arrived, then hides.
- No authored cover: the swap runs at once with no fade.

**Still needed.** The requirements doc (`docs/UI_REQUIREMENTS_CORE_LOOP.md` 2.7) also asks for slanted-panel wipes (T1/T2) between song select, loadout and stage; only this fade exists.
