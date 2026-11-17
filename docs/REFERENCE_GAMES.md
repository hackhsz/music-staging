# Reference Games

What other rhythm and dance games do, why it works, and what we take from it. Written to inform the core
gameplay decision in [GAMEPLAY_PLAN.md](GAMEPLAY_PLAN.md). Researched 2026-10-18 from web sources; read the
"How solid is this" notes, because several sources are weak.

## How to use this

Before adding a mechanic, check whether a game below already solved it and what went wrong for them. Each
entry ends with **adopt**, **adapt** or **reject** for our game. Our constraints: a 5x5 floor per player, the
player walks tile to tile, it has to work on touch, keyboard and gamepad alike, and the server judges.

## Takeaways

| Game | Lesson | For us |
|---|---|---|
| Crypt of the NecroDancer | One move per beat keeps the player engaged every beat; routing is the puzzle | Adopt as the model for mode B |
| Fortnite Festival | A power-up that is **earned** by clean play, triggered by the player, and timed with teammates | Adapt: one earned meter |
| Hi-Fi Rush | The whole world pulses on the beat; off-beat input still works; on-beat gets a clear cheer | Adopt (feel and forgiveness) |
| Beat Saber | Score the quality of the movement, not just the hit | Adapt: reward routing and timing quality |
| DDR | Avoid-tiles (shock arrows) and holds add variety; the same core for years bored players | Adopt danger tiles; do not rely on new mixes alone |
| Taiko | Crowns and a rank course give long-term goals | Already in the progression docs |
| Beatstar | A trophy road and a season pass retain players; paying to retry after a miss is a bad fit | Reject pay-to-retry |
| Magic Tiles 3 | Battles and tournaments; a subscription paywall in onboarding | Reject the paywall |
| Rhythm Sprout, Flutterdash | Stackable modifiers that each change one rule give replay value | Adopt (later) |
| Funky Friday, Dance Your Blox Off | The big Roblox rhythm and dance games are competitive or social, not tile-routing | Context only |

## Games

### Crypt of the NecroDancer

- **What it does:** each beat gives the player one move, then the enemies act. Moving off the beat costs a turn
  and cuts the gold multiplier. The whole game runs on arrow keys or a dance pad. The floor lights up like a
  disco when you stay on rhythm and goes brown when you lose it.
- **Why it works (critics' reading):** the short decision window means no time to deliberate, so it stays tense
  with almost no stats. Simple enemy patterns still make the best route stressful because of the beat.
- **For us:** the closest match to our floor. Our generated charts already put one adjacent step on each beat,
  which is exactly this. **Adopt** as the model for the `onBeat` prototype (mode B in the plan).
- **How solid is this:** interpretive reviews and forum posts (Killscreen, Buzzsaw, PC Invasion, Destructoid,
  Steam forum), not a developer statement.

### Fortnite Festival

- **What it does:** notes on a highway; a streak raises the multiplier. **Overdrive** is the power-up: glowing
  note strings played without a miss each fill a quarter of the meter, and activating it doubles your
  multiplier briefly. In a band, members save it and use it together for more. In the Battle Stage mode,
  Overdrive also attacks a random opponent, hiding part of their chart; the player in first place is not
  attacked. Four difficulties. A guide criticised the missing practice mode.
- **Design criticism:** the glowing highway can hide notes on harder difficulties.
- **For us:** **adapt** into one earned meter (charge from clean streaks, the player triggers it), keep the
  never-target-the-leader rule for any versus interference, and never hide the telegraph. Add a practice mode.
- **How solid is this:** fan wikis and articles about three years old; the mode has changed since launch.

### Hi-Fi Rush

- **What it does:** the world moves to the beat (steam, lights, the character's finger snaps, the UI pulses),
  so players find the rhythm without the optional metronome. Off-beat attacks still land but on-beat ones hit
  harder, and the character's animation never breaks rhythm. Every on-beat hit gets a cheer and a small visual
  cue. A beat bar and easy early fights teach it.
- **For us:** **adopt**: the arena already pulses on the beat; keep the avatar's animation flowing even on a
  miss, give every Perfect a visible cue, and offer a beat tick that can be switched off.
- **How solid is this:** interviews and critical pieces (Vice, Unwinnable); the GDC talk was behind a paywall.

### Beat Saber

- **What it does:** the game tells you which movement to make and the music tells you when. Score depends on
  how wide and how centred the swing is, so the scoring pushes you toward a good movement.
- **For us:** **adapt**: our movement is routing, so grade routing and timing quality, not just presence.
- **How solid is this:** one design analysis (Road to VR) and reviews. Nothing found on its obstacles or modifiers.

### Dance Dance Revolution

- **What it does:** the series kept plain arrows for most of its life; freeze arrows (holds) were the last big
  new mechanic for several releases, and shock arrows (walls to **avoid**, and stepping on one hides upcoming
  steps briefly) came later.
- **Criticism:** one review said new mixes were fresh covers over the same gameplay.
- **For us:** **adopt** danger tiles and holds, but do not rely on new songs alone to keep it fresh.
- **How solid is this:** Wikipedia and a single SuperNOVA review; opinion, not consensus.

### Taiko no Tatsujin

- **What it does:** crowns per song and difficulty, and a course of several songs with pass conditions whose
  rank shows on your nameplate.
- **For us:** already the model for the progression docs (crowns, Dance Grades). Not a core-loop lesson.
- **How solid is this:** from the existing design docs and general knowledge, not newly researched.

### Beatstar

- **What it does:** a trophy road, song boxes and a season pass (its Tour Pass is the biggest revenue driver);
  ads are close to half of revenue. Missing a note stops the song and asks for gems to retry, rising with each
  miss. The background and notes glow brighter as a perfect streak grows.
- **Criticism:** purchase revenue was reported to be declining for lack of variety in systems and core gameplay.
- **For us:** **adopt** the streak glow (our floor and stage can brighten with streaks). **Reject** paying to
  retry: it contradicts "skill is the product" and our audience.
- **How solid is this:** Naavik, PocketGamer.biz and Music Business Worldwide; mostly 2022, so dated.

### Magic Tiles 3

- **What it does:** tap-to-the-beat with a big song library, online battles and weekly tournaments. The
  business model puts a subscription paywall with a three-day trial into onboarding.
- **For us:** battles and tournaments are the useful part. **Reject** the onboarding paywall.
- **How solid is this:** third-party estimates of downloads and revenue that disagree with each other, and a
  reported US download drop that is a single measurement.

### Rhythm Sprout and Flutterdash

- **What they do:** modifiers that each change exactly one rule (faster notes, no healing, invisible notes,
  mirror, shuffled notes, turbo) and can be stacked for harder runs; Flutterdash can build a level from any
  song's audio.
- **For us:** **adopt**, later: each modifier changes one rule and the multipliers combine visibly.
- **How solid is this:** store listings.

### Funky Friday and Dance Your Blox Off (Roblox)

- **What they are:** Funky Friday is the large rhythm game (competitive play, regular song drops; one tracker
  listing showed about 24K peak concurrent players, 2B visits and a 13.6 minute average session). Dance Your
  Blox Off is described as a social hangout with dance battles. RoBeats is the closest scored rhythm game.
  Most Roblox "dance games" are emote hangouts with no scoring.
- **For us:** a scored rhythm game with a social hub looks like an open niche, but we found no player counts to
  back that up.
- **How solid is this:** blogs, aggregator pages and one tracker that is being retired; treat every number as rough.

## Principles we are taking

1. **Variety comes from the floor and the routing**, not from new inputs. Cross-platform means no mechanic that
   needs a particular device.
2. **Power-ups are earned in play**, triggered by the player, and never bought for score.
3. **Modifiers change one rule each.**
4. **The telegraph is never covered**, and judging has to read as fair.
5. **The room reacts to the beat**, and every good hit gets a visible, audible reward.
6. **A practice mode and a short tutorial exist.**

## Anti-patterns to avoid

- Paying to retry after a miss (Beatstar).
- A subscription paywall in the first minute (Magic Tiles 3).
- No practice mode (Fortnite Festival).
- Shipping new songs as the only source of variety (DDR).

## Not covered

Just Dance and Audition-style avatar dancing were only looked at through chart positions, not studied. Beat Saber's
obstacles, Fortnite Festival's current state, and real retention numbers for any game were not found. For
download or revenue figures, use Sensor Tower or Appfigures directly.

## Sources

Killscreen "Verve and Virtuosity: Crypt of the NecroDancer"; Buzzsaw Magazine review of Crypt of the
NecroDancer; PC Invasion; Destructoid; Wikipedia "Fortnite Festival" and "Dance Dance Revolution"; GameRant
on Fortnite Festival; HonestGamers DDR SuperNOVA review; Road to VR "Beat Saber instructed motion"; Vice and
Unwinnable on Hi-Fi Rush; Naavik "Beatstar: West Finds Rhythm"; PocketGamer.biz on monetising music games;
ScreensDesign and AdMapix on Magic Tiles 3; Epic Games Store listings for Rhythm Sprout; RobloxGo and Rotrends
for the Roblox games; the Roblox DevForum threads on rhythm timing. Researched 2026-10-18.
