# Arenas: modeller brief

An arena is the whole environment around the dance floor: ground, stage, backdrop, props, sky pieces. Players buy
and equip one in the shop (the Style section); in a match everyone sees the host's. The dance floor itself is not part of
an arena and never changes.

Every arena below exists as a **blockout**: plain parts in the right place, colour and scale. Replace them with real
models; keep the rules.

## Where they are

- In the place: `ReplicatedStorage.Arenas.<id>`, one Model per arena, named by its id. The default arena is
  `Workspace.Arena` (the Neon Main Stage).
- To work on one: drag it from `ReplicatedStorage.Arenas` into Workspace. It appears at the world origin (0, 0, 0),
  away from the hub island, centred on where the floor will be. Drag it back when done.
- To send one to a modeller as a file: right-click it, **Save to File** (.rbxm). Keep .rbxm files out of the git
  repo.

## Rules (the game depends on these)

| Rule | Why |
| --- | --- |
| Keep the Model's name as its id, and its WorldPivot at (0, 0, 0) | The game finds it by name and places the pivot on the floor's centre |
| The floor is 48 x 48 studs centred on the pivot, its top at about y = 0.4. Keep that square, and the air 25 studs above it, clear | Players must always see every tile |
| The camera sits south (+Z) and looks north (-Z). Put the stage and the big set piece north | Same layout as the default arena |
| Every part `Anchored`, `CanCollide` off | Players only ever stand on the dance floor |
| 340 parts and 16 lights at most (mesh parts count as parts) | `PerformanceBudget.luau`; mobile frame rate |
| Lights (Point, Spot, Surface) pulse on the beat automatically. Set each light's brightness to its resting value | `World/ArenaSkins.luau` multiplies it on each beat |
| Keep the floor the brightest thing in frame; dark ground near the floor | Readability is the game |
| Original designs only: no real brands, logos, schools, idols or licensed characters | `Policies/RightsPolicy` |

## Look: sky and lighting

Each arena sets its own lighting while it is on the stage. Set these as **attributes on the arena Model**; anything
left out keeps the default club look (`World/StageLighting.luau`).

| Attribute | Type | What it does |
| --- | --- | --- |
| `ClockTime` | number | Time of day: 0 midnight, 18 sunset, 21 night |
| `Brightness` | number | Sun and sky light |
| `Ambient`, `OutdoorAmbient` | Color3 | Shadow colour indoors and outdoors |
| `AtmosphereColor`, `AtmosphereDecay` | Color3 | Haze colour near and far |
| `AtmosphereDensity`, `AtmosphereHaze` | number | How thick the haze is |
| `TintColor` | Color3 | Colour grade over everything |
| `Saturation`, `Contrast` | number | Colour grade strength |
| `BloomIntensity`, `BloomSize`, `BloomThreshold` | number | Neon glow |
| `Crowd` | bool | Set false to drop the default arena's cheering crowd from this arena |

Put a **Sky** object inside the arena Model to give it its own sky (star count, sun and moon size, or skybox
images). It replaces the sky only while that arena shows.

## Animation

Add these **attributes to any part** to animate it. All of them follow the music's beat.

| Attribute | Type | What it does |
| --- | --- | --- |
| `Spin` | number | Turns the part, degrees per second |
| `SpinAxis` | Vector3 | The axis it turns on, in the part's own space (default 0, 1, 0) |
| `Sway` | number | Swings it side to side by this many degrees, once per beat |
| `Bob` | number | Hops it up this many studs on each beat |
| `BeatFlash` | bool | Lights it on one beat in three, dimmed otherwise; neighbours take turns, so rows chase |

Lights inside the arena also pulse on every beat on their own.

## Layout (studs from the floor centre)

| Zone | Centre | Size |
| --- | --- | --- |
| Deck under the floor | 0, -0.9, 0 | 52 x 1.6 x 52 |
| Main stage | 0, 1.5, -44 | 64 x 3 x 10 |
| Big backdrop / set piece | 0, 10 to 35, -50 to -60 | up to about 85 wide |
| Side screens or boards | ±46, 8.5, -24 | 30 x 15 |
| Corner posts | ±59, 0, ±27 | |
| Ground | 0, -2.1, -25 | 400 x 1 x 400 |
| Sky pieces (moons, planets, hills) | 150 to 300 studs north | |

## The arenas

| Id | Name | Price | Blockout |
| --- | --- | --- | --- |
| `arena-neon-main` | Neon Main Stage | Free | Finished (`Workspace.Arena`) |
| `arena-neon-candy` | Neon Candy Practice | 800 coins | Blockout |
| `arena-sakura-concert` | Sakura Concert | 1500 coins | Blockout |
| `arena-school-idol` | School Idol Studio | 2500 coins | Blockout |
| `arena-summer-stage` | Summer Pop Stage | 149 Robux (coming soon) | Blockout |
| `arena-pixel-galaxy` | Pixel Galaxy | 199 Robux (coming soon) | Blockout |

The design notes for each theme (palette, props, effects, risks) are also in
`src/ReplicatedStorage/Shared/Catalogs/StageThemeCatalog.luau`.

### Neon Candy Practice

- **Feel:** a toy-box dance practice room made of sweets.
- **Palette:** hot pink, candy blue, lemon yellow, mint green, cream; dark plum ground.
- **To model:** giant lollipops (6), wrapped candies (6), two toy speakers beside the stage, cloud-framed mirrors as
  the side screens, heart-shaped seats (4), a candy-stripe stage, and a wall of candy LED pixels behind it.
- **Watch:** pink props must never hide a lit tile; keep the floor contrast high.

### Sakura Concert

- **Feel:** a night-time blossom festival under a full moon.
- **Palette:** sakura pink, blossom blush, warm cream, plum night, soft gold.
- **To model:** a torii gate framing the stage, cherry trees (12), paper lantern rows on both sides, stone lanterns
  (4), paper (shoji) side screens, the moon and distant hills. Petals drift at the sides (particles, already set up).
- **Watch:** keep the floor base dark so blossoms never hide the active tile.

### School Idol Studio

- **Feel:** an after-school club room turned practice stage at sunset.
- **Palette:** chalk white, clubroom teal, uniform navy, sunset coral, gold star.
- **To model:** the room (back and side walls, wood floor, no ceiling so the camera sees in), a practice mirror wall
  with a barre behind the stage, star curtains and a valance, sunset windows, shoe lockers along both walls, a
  bulletin board and a chalkboard as the side screens, ceiling lamps.
- **Watch:** fictional and age-neutral; no real school logos or uniforms.

### Summer Pop Stage

- **Feel:** a beach festival stage at sunset.
- **Palette:** pool cyan, sun yellow, watermelon pink, white sand, night teal.
- **To model:** a sand island in a sea, a boardwalk runway, palm trees, beach umbrellas, floatie speakers (pool rings),
  a juice stand, festival string lights, and a setting sun on the horizon.
- **Watch:** keep water and floor clearly different on mobile; avoid animated water planes.

### Pixel Galaxy

- **Feel:** a concert floating in space.
- **Palette:** deep violet, star white, laser cyan, comet magenta, moon silver.
- **To model:** a neon grid ground, a star-gate portal behind the stage, planet speakers, planets (one ringed), a
  moon, a field of stars, and glowing pillars.
- **Watch:** don't make it too dark; tiles must stay readable. Prefer a few big shapes to a heavy particle field.

The shop and wardrobe preview shows a turning miniature of the arena, leaving out parts over 200 studs (ground, sea,
big planets).

## Not built yet

- The default arena's LED wall animation and leaderboard screen; the new arenas keep only its crowd.
