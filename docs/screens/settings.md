# Settings

**What it is.** The settings window (audio, graphics, controls, gameplay) with the timing offset on the gameplay page. During a run the pause screen opens a small offset-only panel instead.

**Where.** Two pieces. The window is `StarterGui.Menu.Root.Holder.Settings`; the pause panel is `StarterGui.GameHud.Settings`. Both bound by `UI/Screens/SettingsPanel.luau`. `SettingsController` applies and saves, `CalibrationController` owns the offset. The options and defaults live in `src/ReplicatedStorage/Shared/PlayerSettings.luau`.

**Layout.** One layout on every device: desktop, phone and tablet. It is a standalone window (the rail hides while it is open), a `Panel` at 1.9:1 (2.3:1 on touch through `PhoneAspect`), never larger than 900 x 474, with tabs down the left and nothing that needs hover.

```
[SETTINGS tag]                                          (X)
  ( AUDIO  )   AUDIO                       <- Heading
  (GRAPHICS)   | MUSIC               ====o   100% |
  (CONTROLS)   | The song and its preview.         |
  (GAMEPLAY)   | ... rows 50 pt tall, scroll        |
  [RESET TAB]  Changes save as you make them.   <- Footer
```

Everything sits on one grid: a 0.025 margin, a left column 0.18 wide (tabs and RESET TAB), and a content column from 0.235 to 0.975 (heading, rows, footer tip).

| Element | Position | Size | Notes |
| --- | --- | --- | --- |
| `TitleTag` | 0.025, 0.1 (anchor 0, 0.5) | 0.28 x 0.14 | the SETTINGS art |
| `CloseButton` | 0.975, 0.1 (anchor 1, 0.5) | 10% of the height, square (16% on touch) | the only way out |
| `Tabs` | 0.025, 0.2 | 0.18 x 0.6 | vertical list, left aligned; each `Tab` is a `Pill` at 3.2:1, `Primary` (pink) while open |
| `Heading` | 0.235, 0.2 | 0.5 x 0.07 | the open tab's name in pink (TIMING OFFSET on gameplay), capped at 26 |
| `Pages` | 0.235, 0.285 | 0.74 x 0.6 (0.54 tall on touch) | one scrolling page per tab |
| rows | full page width | 50 pt tall (52 on touch), 6 pt apart | `Card` frames: `Label` and `Blurb` on the left half, the control on the right |
| `Footer` | 0.025, 0.955 (anchor 0, 1) | 0.95 x 0.09 (0.13 on touch) | `ResetTabButton` under the tabs at the same width, `About` under the rows |

Inside a row: `Label` 0.03..0.53 (top), `Blurb` 0.03..0.58 (bottom), slider `Track` 0.6..0.87 with `ValueLabel` at the right edge; `Switch` 0.16 wide and `KeyButton` 0.22 wide at the right edge; a choice is `PrevButton`, `ValueLabel`, `NextButton` at 0.64, 0.78 and 0.92.

**Type scale.** Every label is `TextScaled` with a `UITextSizeConstraint` cap, so text stays the same size on any monitor and only shrinks on small screens:

| Text | Cap | Measured on a phone (pt) |
| --- | --- | --- |
| Tab labels | 22 | 19 to 22 |
| Row names | 22 | 21 |
| Values (100%, AUTO) | 20 | 20 |
| RESET TAB | 20 | |
| Footer tip | 18 | |
| Row descriptions | 16 | 15 |

Keep descriptions under about 36 characters (`PlayerSettings.luau`), or they shrink below 12 pt on an iPhone SE.

Touch targets measured on a phone: tabs 38 to 45 pt tall, rows 52 pt, X 38 to 45 pt, RESET TAB 33 to 39 pt.

Checked in Edit at desktop, iPhone 14 (844 x 390) and iPhone SE (667 x 375).

**Names the code needs.**

| Path | Notes |
| --- | --- |
| `Tabs.Tab1..` | one per section in `PlayerSettings.luau` |
| `Pages.<section page>` | one page per section; rows are named by setting id, and a setting with no row gets a copy of `Templates.{SliderRow, ToggleRow, ChoiceRow, KeyRow}` |
| row `Label`, `Blurb`, and `Track` / `Switch` / `PrevButton`, `ValueLabel`, `NextButton` / `KeyButton` | by the setting's kind; a controller button row uses `KeyButton` too |
| `Pages.GameplayPage` with `Meter.Marker`, `EarlyLabel`, `LateLabel` | timing offset meter |
| `Value`, `MinusButton`, `PlusButton` (inside the offset control, and inside `GameHud.Settings`) | offset nudge |
| `Heading` | the open tab's name |
| `Footer.About`, `Footer.ResetTabButton` | the footer |
| `CloseButton` | there is no DONE: changes save as they are made |
| `GameHud.Settings.Hint` | pause panel |

**Controls by device.** The Controls tab shows only the rows for the device the player last used, and switches when they pick up another: keyboard keys (heading KEYBOARD), controller buttons (CONTROLLER: D-pad and X by default, Start and Select can't be bound, the left stick always steps), or touch options (TOUCH: button size, and whether tapping a floor tile walks to it). Each setting's `device` in `PlayerSettings.luau` decides where it shows.

**States.** Section tab picked; waiting for a key or button press (6 s timeout); the footer tip changes with the tab (save note, key binding help, or the offset advice). Lesson cards hide while the window is open.

**Art to replace.** Nothing in the window is stretched art any more. The window is a `Panel`, rows are `Card`s, and every button (tabs, RESET TAB, switches, arrows, key buttons, -10 and +10) is a `Pill` from `ReplicatedStorage.UIStyles`. A picked tab or an ON switch gets the `Primary` tag, so restyle `Pill` and `Primary` in the sheet to reskin them all. Slider tracks are 9-slice (`SliceScale` 0.2 for a 10 pt track). Only `TitleTag` and `CloseButton` are images.

**Still needed.** The requirements doc asks for a first-run calibration prompt; this screen only offers the manual offset and the post-run auto-tune.
