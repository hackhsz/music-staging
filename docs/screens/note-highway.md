# Note highway

**What it is.** The highway mode's lanes: arrows fall down each lane onto a receptor set into the on-screen key. On touch the whole lane is the button.

**Where.** Built in code by `UI/Screens/NoteHighway.luau`, parented to the PlayerGui and set up in `Main.client.luau` with the run HUD's lane keys (`hud.run:getLaneKeys()`). `Controllers/HighwayController.luau` decides what is on it.

**Names the code needs.** It sits inside the key buttons the run HUD hands it (`getLaneKeys()`), so those keep their names. Built here: notes with `Arrow`, `Mark`, `Tail` (with `Core`) children.

**States.** Hidden; shown with lanes; notes falling, held (tail) and hit; lane pressed or released.

**Still needed.** Nothing known. Drawing only, so any grading rule belongs in `Timing.luau`.
