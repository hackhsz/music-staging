# UI Style

How the game looks: the HUD, the dance floor, the stage and the effects. Follow it for every new or
reworked screen so the game reads as one thing. What each system does is in
[../CLAUDE.md](../CLAUDE.md).

## What is code and what is in the place

The dance floor, the lighting and most of the HUD are built in code. Each module under `UI/Screens/` draws
one part of the HUD, and `UI/HUDController` composes them. The pad run HUD and the on-screen keys are the
exception: they are authored in `StarterGui.PadHud`, so they can be laid out and previewed in Studio, and
`PadHud`, `StepPad` and `SongBar` only find them by name and drive them.
`StageLighting` configures Lighting and the post-effects.

The arena is the exception: it is ordinary parts in `Workspace.Arena`, in a folder per area, so it can
be moved and recoloured by hand in Studio. The code only finds those parts by name and animates them
(see "The stage" below). Edit it in Studio, not here, and save the place.

The screens only draw. They never fire a remote or decide a rule; the controllers in `Controllers/`
call them and bind their buttons.

That means two things when you add a screen:

- You write a module in `UI/Screens/`, build its widgets with `UiKit`, store them on its fields, and
  add it to `HUDController.new()`. Its logic goes in a controller, not in the screen.
- Authored screens (everything in `StarterGui`) live in the place file, so save the place after editing them.
  Their look comes from the shared styles below.

If an element needs to move or resize on a phone, it goes in the screen's `applyLayout`, which
`HUDController.applyDeviceLayout` calls, not in the constructor.

Anything a keyboard can do has a button as well. Key labels go through `UiKit.keyHint`, which is empty
on a device without a keyboard, so a touch player never reads a letter they cannot press.

## Colours

Every colour in the game comes from one of four tables. Do not invent a new one at a call site. HUD
colours are the named tokens in `UiKit.Colors`.

| Table | Where | Covers |
|---|---|---|
| `GRADE_STYLES` | `UI/Screens/RunHud` | The judgement popup per grade |
| `TileState.PixelPalette` | `Shared/TileState` | Every state a floor tile can be in |
| `VFXCatalog.Effects` | `Shared/Catalogs/VFXCatalog` | Particles and flashes per event |
| `ArenaPalette` | `Client/World/ArenaPalette` | The arena: surfaces, the one accent, moods |

### HUD surfaces

| Token | Value | Use |
|---|---|---|
| Panel | `24, 25, 42` | Every panel and bar background, at 0.15 to 0.4 transparency |
| Deep | `6, 7, 20` | Full-screen overlays, such as pause |
| Track | `36, 37, 61` | The empty part of a progress bar |
| Hot yellow | `255, 226, 76` | Score, combo, the performance-goal fill, pause text |
| Cyan | `83, 224, 255` | Song progress and anything time-related |
| Life green | `106, 255, 128` | The life gauge fill |
| White | `255, 255, 255` | Body text, labels inside a bar, the screen flash |

Yellow is the game's accent. Unlike most of this studio's projects, yellow text is correct here: it
is the arcade read. Keep it for score, combo and goal state, and use white for anything long enough
to be a sentence.

### Judgements

The same five colours carry a grade everywhere it appears: the popup, the tile flash, the particles
and the sound.

| Grade | Fill | Stroke | Feel |
|---|---|---|---|
| Perfect | `255, 211, 92` gold | `120, 78, 16` | Biggest punch, 1.3x scale |
| Great | `106, 255, 128` green | `20, 82, 40` | 1.2x scale |
| Good | `86, 222, 255` cyan | `20, 64, 92` | 1.1x scale |
| Bad | `168, 132, 150` mauve | `58, 40, 48` | Shakes, does not grow |
| Miss | `255, 76, 91` red | `92, 18, 26` | Shakes, red screen flash |

Bad is deliberately desaturated. It should feel like a near miss, not a reward.

### The floor

`TileState.PixelPalette` maps every tile state to a colour, and `BoardView` reads it. The rule that
governs the whole floor: **the base stays dark so the target reads.** Tiles are `22, 19, 38` on a
lighter `70, 62, 112` underlay, so the gaps between them read as a thin grid, and the only bright
thing on the floor is one pink rim. There are no corner marks on the tiles.

The telegraph is the subtle part. A target does **not** light up brightly and wait to be chased. It
starts at 0.82 transparency, a faint "go stand here", and fills in to 0.25 as the beat approaches,
staying below solid so the on-beat flash reads as the light finally turning on. Preserve that curve
if you touch `setApproach`.

### The stage

Art direction is `dark_violet_one_accent`. The arena is a dark violet room: floor `20, 17, 36`, wall
`26, 22, 46`, structure `44, 38, 76`. **Pink `255, 127, 191` is the one accent**, the same pink as
the UI. Gold `255, 200, 87` is for highlights only (the performer's ring, Fever), and lilac
`201, 188, 230` is the calm in-between. Neon is for trim, bars and lights, never for a surface.

Every player dances on a floor of their own (`Board.originFor`): one player gets the centre floor, two
get one a side, and the arena is built for that. The deck, stage, wall and speakers are wide enough
for two floors; each client's camera centres on its own floor and the rival's floor shows beside it.

Everything is axis-aligned. There are no diagonal light beams, sloped bevels, tilted props or 45°
diamonds; a light is a pool on the floor and a bar is vertical. Mirrored left and right, so the eye
settles on the floor.

The arena only contains what the camera can see, which is the floor, the stage and wall behind it,
and a screen and some audience either side. A part that is out of frame costs memory for nothing, so
there is no lobby behind the camera and no hidden LED grid. The left screen shows the rankings and the
right one reminds the player of the one rule of the game.

Lighting is a dark violet ambient with low bloom (`0.18`), no saturation boost and a thin haze, so the
pink never washes the screen (`StageLighting.Config`).

`World/` has one module per area: `ArenaFloor`, `ArenaLights`, `ArenaBackdrop`, `ArenaStage`,
`ArenaCrowd` and `ArenaScreens`, joined by `Arena`. Each has two halves:

- `build(kit)` lays the area out as named parts, using `ArenaKit`. Run `Arena.build(workspace, quality)`
  once in Edit mode to author `Workspace.Arena`. It does not replace an existing arena, so delete the
  old folder first when you rebuild. The game also runs it when a place has no arena, with a warning,
  so a fresh clone still plays.
- `bind(arena)` runs in the game. It finds the parts by name and returns what reacts: an `onBeat`, a
  `setMood`, or both. A part you delete is skipped, and one you move or recolour just works.

Part names are the contract between the two, so keep the names when you edit in Studio. The moods
move parts relative to where you leave them, so adjusting the arms or crowd in Studio is safe.

Per-track themes live in `StageThemeCatalog`, each with a palette, props, tile VFX and its own risk
notes. Every theme repeats one warning, and it is the real constraint: **keep the floor base dark
enough that the decor never hides the active tile.**

## Shared styles

`ReplicatedStorage.UIStyles` is the one place to restyle the authored UI. Every ScreenGui except `Derail` and
`Import` has a `StyleLink` named `UIStyles` pointing at its `Design` sheet.

- `Tokens` holds the palette, gradients, corner radii, stroke widths and spacing as attributes. Change a value
  there and everything using it follows.
- `Design` holds one rule per component, keyed by a CollectionService tag. Tag an element to give it that look:

| Tag | Look |
|---|---|
| `Card` | Purple gradient card with a lilac outline (list rows). Add `Done` for the green outline |
| `Panel` | Dark gradient panel (side cards, the pause card) |
| `Tile` | Rounded icon tile behind a glyph |
| `Chip` | Yellow reward chip |
| `Pill` | Flat dark pill (buttons, timers). Add `Primary` for the pink one |
| `Badge` | Round pink gradient badge (the level) |
| `Count` | Small pink count bubble on a tab |
| `Tick` | Green done tick |
| `BarTrack`, `BarFill` | A progress bar's track and fill |
| `Field` | Text input box |
| `Inset`, `ListInset`, `ChipInset` | Padding, large, small and chip-sized |
| `Outlined` | Dark text outline |

Two engine rules decide whether a style shows:

- A property set on the instance beats the style. A styled surface keeps `BackgroundColor3` at the class default
  (`163, 162, 165`) for flat looks, or white for gradient looks, and gets its colour from the sheet.
- The sheet adds its own `UICorner`, `UIStroke`, `UIGradient` and `UIPadding`. Don't add one by hand to a tagged
  element, or it gets two. A gradient tints text too, so text surfaces (`Pill`, `Count`, `Tick`) are flat.

Code toggles state by tag (a finished quest gets `Done`) rather than setting colours, so the look stays in the sheet.

## Sprite atlases

The UI art (buttons, pills, panels, icons, banners) comes in four sets, `Pastel_`, `Neon_`, `Comic_` and `Stage_`
(the Stages screens' parts, challenger portraits `Stage_Portrait<Name>` and song covers), packed
into 1024 px atlases: sprites up to 508 px, backdrops a page each. Each sprite also has a grey copy in a twin atlas
with the same layout, for tinting with `ImageColor3` or a `UIGradient`; use the grey one wherever code recolours the
art (rarity stars, loadout slots). In Studio, `ServerStorage.UISprites` holds every sprite as a named ImageLabel, one
tab per set, with the grey atlas in its `TintImage` attribute: copy one into a screen rather than retyping the rect.
Authored elements carry the sprite's name in a `Sprite` attribute.

Sprites share pages, so swapping art means swapping the rect too: code goes through `UiKit.setImage(label, name)`
(`"Neon_PillDark"`, `"Neon_PanelSquare_Tint"`, a saved `UiKit.imageState`, or a plain asset id), and attributes that
name swap art (`HoverImage`, `TabImage`, `PickedTabImage`, `SlotImage`, `PickedImage`) hold sprite names. To add or
change art, cut the sprites into a folder as `Name.png` and `Name_Tint.png` and run
`tools/scripts/upload-ui-sprites.py` on it. It repacks, uploads the pages that changed, and rewrites
`assets/ui-sprites.json` and `UI/UiSprites`. It rewrites the whole map from that one folder, so the folder has to hold
every set's PNGs; a set whose PNGs are missing drops out of the map.

## To replace

Placeholders still in the authored UI, for the UI artist. Keep the instance names when swapping art.

- **Detail frame** `rbxassetid://98608431433852`: the plain black square behind the picked item in Loadout and
  Wardrobe (`DetailIcon`). The other windows use a styled `Tile` there now.
- **Emoji icons**: quest rows, reward chips, Rewards' social rows and the Travel, Market and Wardrobe cards draw an
  emoji until the catalog entry gets an uploaded `icon`.
- **Tab pills** (`TabImage`, `PickedTabImage` on each `Tabs`): stretched to every width. A 9-slice version (with
  `ScaleType` Slice) would keep the round ends.
- **Pause card** (`GameHud.Pause.Card`): styled from the sheet, no art yet.
- **Results secondary button**: HUB and RETRY borrow one art piece; they need their own.
- **Market and Travel cards**: "ITEM 1 / COMING SOON" and the palm-tree spawn art are stand-ins.
- **Run HUD**: `TimingDelta` is not authored yet (the binder warns at startup).
- **Loadout, Shop, Settings**: their cards and rows still carry hand-made corners and strokes; move them onto
  `UIStyles` tags.
- **Cleanup**: `StarterGui.Import` (disabled, old menu) and the empty `StarterGui.ScreenGui` look unused.
- **Check in game**: the transition cover shows a lighter band across the top in the Studio viewport.

## Type

One font: Oswald Bold (`UiKit.FontFace`), `TextScaled` on. Code-built screens get it from `UiKit.label` and
`UiKit.button`; authored screens set it on each label.

- Labels are centred and anchored at `0.5` on x.
- Text that states a value is upper case: `SCORE 0  COMBO 0  HYPE 0`.
- Text on art or a light surface carries a dark outline (`Outlined`). Outline every sibling in a group or none.

## Layout

On the dance pad the run HUD is a slim top block (`UI/Screens/PadHud`, sizes in pixels for a 720 px tall screen,
scaled with the height) that ends above the pad's far edge, about 0.26 of the screen height:

- Top left: one song card with the song and difficulty and a progress bar with the elapsed and total time.
- Top right: the score, then the pause button. Under the score sits the life bar (red and pulsing below 25%), or,
  when a real player is your rival, the you-versus-rival meter in its place (your face left, theirs right). The
  solo practice bot never takes the spot.
- Top centre: the big combo in its tier colour, with COMBO, the multiplier and the shield under it, and the
  grade line (grade plus early or late in ms) under that. Combo breaks, shield saves, milestones, the
  countdown and floor-event banners all show in this block. Nothing sits on the sides or over the pad.

The pad block and the on-screen WASD and CLAP keys live in `StarterGui.PadHud`, one frame per layout: `Desktop`
(sized from the screen height) and `PhoneLandscape` (pixel offsets; the combo and grade line sit small at the top centre;
a cross D-pad bottom left and a big CLAP bottom right). In both, CLAP sits outside `Keys` under the right thumb with
the ability cards above it. Flip a frame's Visible to preview it; the code picks one from the
viewport at runtime. Rename nothing inside them: the code binds by name. The game is landscape only
(`StarterGui.ScreenOrientation` is LandscapeSensor). A backup sits in `ServerStorage.UIBackup_*`.

Each layout also carries the placeholders the music drives: `Combo.BeatRing`, `Combo.Sparkle`, a `Wave` of bars in
the song card, score and life panels, and `EdgeGlow.Fever`, `.Danger` and `.Break`. The code fades and scales
whatever art is inside them and sets each wave bar's height, so a designer replaces the art and keeps the names.

The other in-run screens live in `StarterGui.GameHud`: `Pause` (its `Card` holds the resume, restart and settings
buttons), `Settings` (the timing offset), `RunHint` (the run's controls hint and onboarding tip), `EventBanner`
(the game sets only its height, so it lands in the grade line's strip) and `PauseButton`, which shows only when
the run HUD has no pause button. The code sets their text, colours and visibility and plays their pops and fades;
everything else is the designer's.

The song picker is `StarterGui.Songs`. `SongButton` is a row and `SongButton2` the selected row: the code clones one
of each per song and fills the number, `SongLabel`, the label with `Bpm` in its name, the star row and
`APanel`. The title is spelled in copies of the `SongsFrame` tiles, `SongsFrame4` holds one badge per difficulty
(the picked one grows and turns black), and `BestPanel` shows the chart's goal until per-song bests are saved.
`SongsPanel.BackgroundFx` sits inside the background art: its `Marquee` rows drift and its `Sparkle` stars
twinkle, so the empty side never looks bare. `SongsPanel2.Visualizer` holds the `Bar` frames that bounce to the highlighted song, low bars on the beat and
high ones between, while its preview plays.
Panels slide in from their nearest edge; on CONTINUE everything but the title clears, the title holds the middle
until the run starts, then the cover sweeps off left.

The lobby HUD is `StarterGui.Lobby`, made from the designer's art in `Derail.Holder`: the icon `Rail` on the left
(Home, Song, Loadout, Shop, Settings; a button glows with the image in its `HoverImage` attribute), and the
`RightColumn` on the right with the player `Card` (avatar, level, name, coins and the + that opens the shop), the
`Daily` challenge rows and the `Actions` row (daily gift and play mode). `Status` shows only in a real match, and
`Hint` and `Onboarding` are the lobby's hint bars. The rail and column slide off while a run plays.

The rail opens the windows in `StarterGui.Menu`, built from the designer's Loadout and Wardrobe art in `Derail`:
`Root.Holder` holds a copy of the rail and one window at a time, `Loadout` (four `Slots`, group `Tabs`, a card grid
cloned from `Grid.List.RowTemplate`, the detail on the right; each slot has its `SlotNumber`, and cards, slots and group tabs take
the ability's group colour through their gradient), `Shop` (pill tabs across the top over one scrolling `Page`, and
an `ItemPopup` with the picked item on the `Pedestal` and a `Pill` `BuyButton`; see `docs/screens/shop.md`) and `Settings`. On the Shop pedestal,
`Preview` is a ViewportFrame holding a copy of the player's avatar wearing the picked item, turning slowly; a track or
an item a copy cannot show (trails and auras are particles) falls back to `DetailIcon`. The lobby steps aside while
one is open. Loadout's slots' resting and picked art are attributes on their frame (`SlotImage`, `PickedImage`); the Loadout,
Shop, Wardrobe and Settings tabs are style-sheet `Pill`s that take `Primary` when picked, and the pause screen keeps its own settings panel in `GameHud.Settings`.

Every window shares one grid, in scale of the window, so a new one lines up with the rest: the tab strip at
`(0.025, 0.085)`, 0.072 tall and at most 0.48 wide, with equal tabs; the list or grid at `(0.025, 0.155)`, 0.47
wide and 0.77 tall (Quests runs 0.6 wide beside its level card); the detail column centred at x `0.745`, in the
right half of the art, on a `Panel` (`DetailCard`) from y `0.155`, 0.55 tall, with a small lilac header and the
item in a `Tile`; the big action button bottom right. Lists get 8 px between rows and the `ListInset` tag. The Shop
fills a row with as many cards as its `RowTemplate` holds (`Card1`, `Card2`...), three for now.

The Settings window is authored in full, so it can be restyled in Studio. `Tabs` holds one tab per
`PlayerSettings.Sections` entry (Tab1 audio, Tab2 graphics, Tab3 controls, Tab4 gameplay; controls only shows with a
keyboard) and `Pages` one page each. Every setting has its row on its page, named by its id (`musicVolume`, `keyUp`
and so on), in one of four shapes: a slider (`Label`, a `Track` with `Fill` and `Knob`, `ValueLabel`), a toggle (`Label`,
a `Switch` with `PillLabel`), a choice (`Label`, `PrevButton`, `ValueLabel`, `NextButton`) or a key (`Label`, a
`KeyButton` with `PillLabel`). Restyle the rows freely and keep the names. `Settings.Templates` holds one of each shape:
a new setting with no row yet gets a copy, so it shows up before it is laid out. The gameplay page holds the timing
offset and its `Meter`. On the right, `DetailTitle` and `About` describe the hovered setting and `ResetTabButton` puts
the open tab back to its defaults. A new setting is an entry in `PlayerSettings`, a row, and a line in
`SettingsController` for what it changes.

The layout below is the highway HUD, which is still built in code.

The run HUD is a single centred column down the top of the screen, measured in **pixels from the GUI
inset**, not in scale, so it keeps its spacing on every aspect ratio. The rows do not overlap; the
numbers live in `RunHud.LAYOUT`:

| Offset from inset | Height | Element |
|---|---|---|
| 12 | 40 | Score, combo and hype |
| 56 | 18 | Life gauge |
| 78 | 26 | Song progress |
| 108 | 28 | Performance-goal bar |
| 142 | | Grade popup |
| 188 | | Timing delta, early or late in milliseconds |
| 216 | | Fever |
| 262 | | Combo break |

Widths are in scale, so they breathe with the window. A viewport under 900 wide or 600 tall counts as
small (`UiKit.isSmallViewport`) and widens the column from roughly 0.34 to 0.46 of the screen, because
a narrow phone screen needs the text bigger, not the column narrower.

The corners are fixed in pixels too, so they hold on a phone:

- **Bottom left**: the on-screen step pad, touch devices only, and only during a run.
- **Bottom right**: Next song and Replay on the results screen, under the right thumb.
- **Bottom centre**: the hint bar. On touch it narrows to half the width so it stays between the pad
  and the results buttons. On results it moves to the bottom left, clear of the buttons.

A run hides everything that is not part of it (`HUDController.setRunActive`). Panels that are not the
column (shop, song select, settings, results) are centred frames over the dark panel colour. Every tap
target is at least 44 px (`UiKit.MinTouchTarget`).

## Motion and effects

The one rule that outranks everything else in this file:
**an effect must never cover the next prompt.** The player is reading the floor two beats ahead. A
burst that hides the next target is a bug, not a flourish.

`VFXCatalog.EventMatrix` states the budget per event, and the numbers are short on purpose:

- Perfect: a tile burst under 0.6 s.
- Great: a smaller burst and a tile flash under 0.5 s.
- Bad: edge-of-screen only.
- Miss: a red flash and a shake, nothing on the floor.
- Fever: an aura and spotlights for the bonus window only, in gold, pink and cyan.
- Song end: confetti, and only after gameplay has stopped.

`VFXController` picks a quality tier at startup and runs an FPS watchdog that drops it when frame
rate sags. Dynamic PointLights go first, then rings and dust. Any new effect must degrade the same
way: add it to the tier table rather than emitting unconditionally.

## Performance

`PerformanceBudget` is binding, not advisory: 30 fps floor, 60 fps target, 340 runtime stage parts,
170 dance floor parts, 16 stage lights, 700 MB client memory. New stage decoration goes through a
quality profile so it can be dropped on a weak device, and anything decorative and distant gets the
`StreamedVFX` CollectionService tag so `FarVFXCuller` turns it off when the player is far away.

Prefer a Beam to a chain of parts for a light shaft. The old fake ForceField beams were replaced with
Beam instances precisely because they cost no parts.

## Working on a screen

1. Read this file, then read the screen under `UI/Screens/` that owns the element you are changing.
2. Build it in code with `UiKit`. Store it on `self`. Add its device adjustments to the screen's
   `applyLayout`.
3. Press Play and look at it at both desktop and phone proportions. There is no Edit-mode preview,
   because nothing is authored.
4. Check the effect does not cover the next target at the fastest chart you have, which is Neon Idol
   Rush on hard.
5. Run `scripts/check-clean.sh` before you finish.
