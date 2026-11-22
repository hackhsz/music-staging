# Changelog

What changed in Dance Dance Step, newest first.

One line per change a player or another developer would notice. Say what changed and what it means,
not which function moved. Skip refactors, formatting and comment edits. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions count from the first published
place; until then everything sits under Unreleased.

## Unreleased

### Changed

- This Week board, Lobby HUD and Stage Pass rebuilt to GPT mockups (in the Encore UI Brief): a bigger left rail with HOME first, a wider SOLO PLAY aligned over PLAY, the Stage Pass season line shows when the season ends. Quest rows fill the Quests window, and Rewards gift tiles stack time, icon, reward and timer top to bottom with the code field across the bottom.
- Robux purchases are granted on the server: dev products go through ProcessReceipt (each receipt granted once, saved before Roblox is told), and 2x Beat Coins and 2x XP passes now double song coins and XP. Sales go live per offer once its pass or product id is filled in `ShopCatalog`; VIP and the song pack stay coming soon.
- The Stage Pass is sold as a one-season R$ 99 product: its shop card opens the Pass window, and the window's UNLOCK PASS button prompts the purchase.
- The shop's Featured section leads with the Stage Set Road (Blooming Sky): six fixed looks bought in order, the first free, one already owned pays 100 coins instead. No random items.
- The lobby player card is a slim bar now (avatar, rank, name and coins on one row, the XP line under it) instead of a tall box, and the top icons carry labels like the left rail. The rank hint and SETLIST link are gone; the XP line still opens the setlist.
- The shop's Featured page is laid out like the Miro board: the Set Road as a tall card on the left, four offer cards in a 2x2 grid beside it, shorter offer lines, and corner badges kept inside the cards.
- Shop item cards (Outfits, Emotes, Stages) show their price on a glossy button that greys out when the item can't be bought.
- The loading screen, the "To the stage" cover, the first-join lesson card and the reward toast use the menu look: purple gradient, glossy buttons and bar, Fredoka text.
- Shop tabs follow the Miro board: FEATURED, OUTFITS, EMOTES, STAGES, PASSES, COINS; animation packs sit under Emotes, and bought passes and one-time offers read OWNED.
- New squared button art (glossy purple, rounded-rectangle) on the lobby PLAY and SOLO PLAY, every stage-screen PLAY and CHALLENGE, Travel and Market; each has a pressed look and a greyed locked look, and the player card's `+` is purple instead of green. Art and asset ids live in the Encore UI Brief's `art` folder.
- Menu windows share one new clean background (no tiled notes, no divider), the cyan picks and lime buttons are pink, the stray note stickers hanging off the windows are gone, and window titles are white-pink instead of mint.
- Quests is redrawn with the new art: glossy row cards (a dimmed card once done), a square rank badge, a calmer rank strip and gold-rim reward boxes. Tabs in Quests, Wardrobe, Loadout and Settings use the new squared tab art.
- The Shop is rebuilt to a clean mockup: no disco balls or ribbons behind items, calm card panels, purple squared buy buttons instead of green, pink tags and white headings.
- 52 new icons replace the emoji placeholders: every shop offer and coin pack, every cosmetic, emote, pose and arena, and every ability (also on the in-run ability cards).
- Every menu window's cards, rows and tiles spring in one after another when it opens, like the song picker; Reduced Motion skips it. Close buttons are bigger, title tabs no longer stretch oddly, buttons across Rewards, Group, Loadout, Wardrobe and Settings use the squared art, and the loud pink rows and cards are calmer.
- Travel, Wardrobe, Rewards and Settings are rebuilt to mockups: Travel loses the leftover swoosh art and stray rail and gets a proper detail panel with a greyed YOU ARE HERE button; item and place cards use new resting, picked and locked card art; Wardrobe fills short lists with locked "GET MORE IN THE SHOP" slots and shows the avatar on a lit pedestal; the play-time gifts use the new icons; the code box is calm and the settings sliders are pink with round knobs.
- The stage screens (setlist, song browser, rank road) drop the torn-paper look for the same window style as the menus: one framed window, calm song rows with thumbnails, new song covers and pink NEW chips. The run HUD, pause menu and results XP panel are restyled to match, and pause now draws above the HUD instead of under the combo. Window and panel rims are about half as thick.
- The lobby rail, player card and SOLO PLAY slide away under the setlist, roadmap and song browser, and SOLO PLAY hides under menu windows, so nothing shows through them.
- Lobby performance: the island's spinning quest icon, bobbing arrow and music rings now animate on each client instead of the server streaming their moves every frame; the unused Workspace copy of Music Ring (and its 3-minute song) is gone, the three animator scripts hunting for the old `Islands_9_3` island are deleted, and bouncy pads no longer print on every touch.

### Added

- Weekly League: each week (Monday 00:00 UTC) players race in a group of their tier (Bronze to Superstar) on the sum of their best five songs, one score per song. At the week's end the top 5 move up and the bottom places move down (only in groups of 10 or more), with 150 / 75 / 25 coins for up / stay / down. Shown on the This Week board.
- Daily streak: finishing a song on consecutive days counts up a streak, shown on the This Week board.
- FOLLOW EVENT on the Saturday Live Show card RSVPs to the next Roblox experience event (made in Creator Hub); the button hides when none is scheduled.
- This Week board, opened from the rail's new HOME button: the Saturday Live Show (date and countdown), today's challenges with the 2x XP first song, three picks from the shop, the weekly league top five with your place, and Stage Pass progress with the next free and pass rewards.
- Stage Pass (Blooming Sky season, 4 weeks): every finished song that earns XP also earns 20 pass points, every 200 points is a tier, and each of 15 tiers has a free reward and a pass reward (coins or a cosmetic) you claim in the new Pass window, opened from the ticket button by the player card. The server checks every claim and saves the track; it resets when the season changes. The pass row stays locked ("coming soon") until Robux sales and pass ownership are built. Studio playtests: set the `StagePassPoints` number on Workspace to try tiers; live servers ignore it.
- The stages roadmap (ALL STAGES) follows the rank road mockup: one squared panel with each stage's requirement and unlocks under its marker, then a rank-up song card, an XP-per-song table and a Next Goal card with a PLAY button for the song to play next. Song bests now also keep your best accuracy.

### Fixed

- Picking a tab in Quests, Wardrobe, Shop, Settings or the loadout now moves the highlight to it; before, the first tab stayed lit whichever one was open.
- Floor charts come from a pattern library (`scripts/music/library.py`): 17 authored patterns (routes, either/or pairs, board zones, holds) make up about three quarters of each chart, generated bars on the beat fill the rest, and every step passes a reach rule against every tile you might be standing on. No danger tiles, claps, rushes, slides or items on these charts. Any-tile sets can now be up to 10 tiles. `chart-audio.py --generator walk` keeps the old floor.
- Just a Little Static and Do You Read Me are recharted from the library on all four difficulties; each step carries its pattern id (`pid`).
- Every target on the pad lights in the same pink (any-tile, hold and clap keep their icons); danger stays red.
- The pad shows the whole step pattern you are in: the tiles still to come glow pink with a thin outline, fading with distance. A zone of more than 4 tiles is never previewed, by the glow or the next-note outline. Easy and normal no longer draw an arrow from you to the next tile.
- New UI art imported into the place (`StarterGui`): round icon rail and top buttons, a new player card with the rank bar inside it, a new PLAY button, new menu windows with open effects and an animated Featured card. The lobby's daily panel and Stage Challenge mode tile are gone; the old screens are kept in `ServerStorage.UIBeforeImport_2026-11-19`.
- After the UI import: hover on the new round rail and top buttons no longer swaps in a stretched old tab image, square and round buttons grow without tilting, a button with the designer's own scale animation keeps it, shop tabs show which one is picked, the coin gain stays on the taller card, and Shop, Wardrobe and Loadout fit the screen again. Every screen is relinked to the `UIStyles.Design` sheet the import had dropped.
- Studio playtests print each pattern as it comes up (`[DanceDanceStep] pattern CH-SIDE (#12) from beat 40.39`).
- Studio playtests: tick the `UnlockAllCharts` attribute on Workspace to open every song and difficulty regardless of rank. Live servers ignore it.
- The chart generator has 14 new step patterns (weave, notch, kick, S-bend, cane, crenel, ledge, comb, peak, figure-8, and diagonal bowtie, lightning, hourglass, chevron), so a chart uses about 23 kinds of move instead of 13. Just a Little Static and Do You Read Me are recharted with them on all four difficulties.
- The stage screens fly in block by block from their side of the screen, tilted and small, and snap upright with a little overshoot while the backdrop fades; a menu window rises and pops when opened and slides when switched to. Reduced Motion skips it.
- A fifth sprite set, `Icon_` (16 hand-cut icons), replaces the emoji on daily quests, achievements and the play-time gifts, and the coin, gift and group icons in the lobby and windows.
- T opens and closes the setlist board between runs, and Backspace or gamepad B closes whichever stage screen is on top (reveal, prompt, mode list, browser, roadmap, setlist). The song picker binds a `Songs.SetlistButton` for the same board once it is authored.
- Stages: each rank is a stage with its own setlist and a challenger (HANA, MIRA, SOL). Fill the XP bar, then beat the challenger's song at its grade to move up. The lobby gets a mode tile and a PLAY button, the rank strip opens the setlist board, and a stage-up reveal replaces the rank-up card.
- Stage Challenge and Free Play modes: PLAY starts your next stage song straight away (a challenger asks first), or opens the song browser. The choice is saved.
- A stage-up reveal you left before dismissing plays again in the lobby, and each stage's "now pays 50% XP" notice shows on the setlist board until closed. Both are saved.
- Pack 2: Just a Little Static and Do You Read Me, on all four difficulties, and they join the stage setlists. Both are Suno takes and stay off public release until their paid-plan proof is recorded.
- Song browser (ALL SONGS on the setlist board): every chart by stage with its FULL XP or 50% XP chip, what a locked stage needs, and the XP a run would pay.
- Stages roadmap (ALL STAGES on the setlist board): every stage on one path, who guards it and what it opens.
- A challenge prompt before a challenger's song once the bar is full, and an XP panel beside the results with each line of the run's XP.
- A fourth sprite set, `Stage_` (58 sprites: rows, tiles, frames, stickers, chips, paint, 16 icons, four challenger portraits and two song covers), on its own four atlas pages; the Stages screens now draw from it and show each challenger's portrait.
- `StarterGui.Stages` holds the new screens. The locked zone gate and the in-world challenger card are laid out but not wired; nothing in the hub uses them yet.
- Ranks replace levels: finished songs fill a Rank bar, then a rank-up song at the set grade moves you up and opens new difficulties and songs.
- Results, the lobby card and Quests now show what you gained: XP breakdown, coins, new best, your next goal, a rank-up card and achievement toasts.
- Grades come from weighted accuracy (S 95%, A 85%, B 70%, C 30%). Under 30% or a failed run earns no XP.
- The UI sprite sheets are cut into 92 named sprites in three sets (Pastel, Neon, Comic), packed into 17 atlas pages with grey tintable copies, and available in `ServerStorage.UISprites` and `UI/UiSprites`.
- Every live screen now draws its art from those atlases: the AI-made banners, cards, tabs, close buttons, rail, pedestal and results art are replaced with sheet sprites, and rail buttons light up pink on hover.
- The pause menu matches the lobby windows: the title tag, a big Resume, icons on every button and a red Leave.
- The quests window matches the shop: Daily and Achievements tabs with done counts, a level strip with your XP, and full-width quest rows.
- The loadout matches the shop and wardrobe: your four equipped abilities in a strip at the top, group tabs and the ability grid below, and the picked ability's card with a big READY button.
- The wardrobe matches the new shop: pill tabs across the top (All, Outfit for wands, trails and auras, Moves, Arenas), owned items on the left and your avatar trying the picked one on, with a big EQUIP button.
- The shop is one scrolling page, Featured, Passes, Coins and Style (wands, trails, auras, arenas and moves together); the tabs across the top jump to each part, and tapping an item opens its try-on popup. Coin packs show their name, a gold amount and the bonus.
- Play-time gifts in the Rewards window, once per visit: coins at 5, 10, 20 and 45 minutes, and four shop items at 15, 30, 60 and 90 (Mint Bubble Wand, Equalizer Trail, Sunset Star Wand, Midnight Moon Wand; coins if already owned). The code box stays.
- A Group button next to Rewards opens the new Group Rewards window: Like and Favorite pay 50 coins, joining the group 150 plus the Group Star Aura, and the daily gift is now 50 (100 in the group).
- Settings' Controls tab now matches your device: rebind controller buttons, or on a phone pick the step button size and turn floor tapping off. Keyboard players still rebind keys.
- Player UGC stalls on the sky islands: claim a free stall, list up to 8 avatar items you made (pick them under MY ITEMS, or paste an item id), and visitors buy them through Roblox. Signs over the stalls show who sells what. Live servers stay closed until the UGC policy is signed off; Studio playtests are open.
- Arenas: whole environments around the dance floor, sold in a new Arenas shop tab. Neon Main Stage is free; Neon Candy (800), Sakura Concert (1500) and School Idol (2500) cost coins; Summer Pop (149) and Pixel Galaxy (199) are Robux premium arenas (coming soon). In a match everyone sees the host's arena.
- Each arena brings its own sky and lighting and its props move to the beat (spinning portal, swaying lanterns, chasing lights); the shop and wardrobe show a turning preview of it.
- The Roblox player list shows each player's Level and Best score.
- Hub leaderboards fill in the rank column, show each player's headshot where a row has an Avatar image, and pick out your own row in yellow.
- Loading screen (ReplicatedFirst): a lit mini floor, progress bar, rotating tips and a SKIP after six seconds, while the UI art preloads and the HUD starts.
- First-join dance lesson: five short drills (step, any tile, hold, clap, avoid), each with a looping demo and no rival, replayed until three of four tries land. It pays nothing and never ranks; passing the last drill pays a one-time 150-coin starter gift (skipping does not). Players who had already finished a song skip it.
- After the lesson: a 12-beat timing check sets your offset, then a PLAY button starts Our Hearts on easy (now open to everyone).
- Tips appear when they're useful, with a beam or a ringed button: the quest board after your first clear, the shop once you can afford a wand, the wardrobe after your first buy. Set Workspace `SkipOnboarding` to start Studio playtests past the lesson and tips.
- The pad reads better: blue any-tile, purple hold and yellow clap tiles (they were all pink), holds drain as you stay on them, the count stays up after you arrive, easy and normal draw an arrow from you to the next tile, and the grade line says DODGED! or EARLY - LAND ON THE BEAT.
- Onboarding, shop and run funnels go to the Creator Dashboard (FunnelCatalog); Studio prints each step instead.
- Four new lobby windows: Quests (daily challenges, achievements, level), Travel (spots on the main island and the sky islands), UGC Market (six creator stalls, coming soon) and Rewards (codes, thank-you coins, daily gift). The rail gains Quests and Travel, and the gift button opens Rewards.
- Island prompts: Shop, Quests, DJ Booth, Teleport Garden and every UGC stall open their window. Stations are models under Workspace.Stations with a Window attribute and an Anchor part.
- Promo codes WELCOME and ENCORE, paid once per player.
- Wardrobe window (rail button next to Shop): every item you own by kind, tried on your avatar, with EQUIP and UNEQUIP. Taking off a jacket or shoes now puts your own colours back.
- The lobby buttons are split: the left rail keeps Play, Shop, Wardrobe, Loadout and Quests as bigger buttons, and Travel, Rewards (with a red dot when the daily gift is ready) and Settings sit beside the player card. Home and the big DAILY GIFT button are gone.
- Group reward: joining the group pays 50 coins and the Group Star Aura, and members get a double daily gift. Set SocialRewards.GroupId to turn on the membership check and the join prompt.
- The top 3 on the STATS island dance on their podiums, and an empty podium shows a PLAY TO RANK silhouette instead of standing bare.
- The shop is laid out like a Roblox store: a category sidebar, a Featured page with a Starter Pack banner (one-time offer, -60% badge, old price struck out) and popular passes, a Passes page of game-pass cards, a Coins page of coin pack tiles with bonus and best-value badges, and item pages with the try-on preview. Offers are placeholders (Starter Pack, VIP, 2x Coins, 2x XP, Season Pass, Song Pack), and Robux sales stay closed (ShopCatalog.RobuxSalesOpen) until the server grants them.
- Coin-shop wands, trails and auras, plus coming-soon emotes, entrances and victory poses; items show a rarity. The shop sells no outfits: four wands (Mint Bubble, Sunset Star, Midnight Moon, Golden Star) replace the shoes and jackets, and share the hand with the lightstick.
- Emoji placeholder icons on abilities, items, quests and islands. Set an item's `icon` to an uploaded image to replace its emoji.

- The STATS island's boards show the weekly perfects, top scores and a new top-level board, and the top 3 scorers stand on the podiums as their avatars.
- Click your player card in the lobby to see your stats: best score, best combo, songs played, perfects and your ranks.
- You can step diagonally on the 5x5: press two keys together (W+D), or two on-screen keys at once. A key you are still holding from the last step never bends the next one.
- Our Hearts has new charts on every difficulty with diagonal steps (diamonds, zigzags, triangles) and far fewer danger tiles and claps. Its blue shapes now come in many forms, mostly 3 and 4 tiles, instead of the same 2-tile pair. The chart generator's `--intensity flow` builds them.
- I Don't Wait and Under the Starlight are recharted the same way, on every difficulty. The generator no longer steps diagonally off a hold.
- All three songs are recharted with more blue shapes (three new ones: a long L, a Z and a corner zigzag) and more kinds of moves (snake, U-turn, spiral, long L, slalom, crown), and a move used lately comes up less.
- Easy and normal are slower and easier on every song: about half the steps, all on the beat, no fast runs, jumps or claps on normal, and easy steps at most every other beat.
- Our Hearts' steps now land on its snares and claps, more of them as the song builds, on every difficulty (`chart-audio.py --follow snares`).
- Our Hearts on hard and expert has fewer fast runs and diagonal steps, and hard and expert targets light up 3 beats ahead instead of 2.
- Every Our Hearts step and fast run now sits on a hit you can hear; before, up to a quarter of expert's steps landed on silence or a weak off-beat.
- Our Hearts keeps dancing where the drums drop back (around 2:00): steps follow the vocal and synth notes there, and a loud stretch is never charted as calm. Easy steps at most every other beat again.
- Expert Our Hearts is busier at the song's peak: quick half-beat steps on the drop's and chorus's snares (never more than four in a row) and more fast runs there.
- On the pad only the tile to reach now is lit; the one after it is a faint outline instead of a white tile.
- Charts made from audio were about 25 ms early on every step; the generator now times hits where they really are.
- The number on the pad's target tile counts down from 3 at most; the tile still lights up as early as before.
- On the pad, an ability pickup is always green with its name floating above it, and no arrow points from you to the next tile.
- The shop's pedestal shows your own avatar, turning slowly and trying on the picked item (the lightstick, or the jacket and sneaker tints), and pops when a purchase goes through.

- Going to the stage and back fades through a cover (TO THE STAGE / BACK TO THE ISLAND) while the lighting, camera and position switch, instead of flashing the island under club lights.

- Full settings, saved to the profile: volume sliders for music, sound effects, dance sounds and menu sounds, effects quality (auto, high, medium, low), background blur and camera shake, and rebindable dance-pad keys on a Controls tab (keyboard players only; arrows and the D-pad always work too), across Audio, Graphics, Controls and Gameplay tabs with a RESET TAB button. Every row is authored in StarterGui.Menu so it can be restyled in Studio.

- The menus have sound, from Roblox's own UI sound set: a soft tick on hover (not on touch), a click on press, a whoosh when a window opens and a pop when it closes, a sweep when switching windows, a chime on a purchase and a buzz when something is locked or a purchase fails. The cues live in SFXController with the rest.

- The lobby rail's Loadout, Shop and Settings open the designer's windows (StarterGui.Menu) in place of the old pixel panels: four ability slots with group tabs and a detail card, a shop grid with the picked item on a pedestal, buy/equip and your equipped items, and the timing offset. Each window carries the rail, Home closes it, and Song opens the picker.

- The lobby HUD is the designer's art (StarterGui.Lobby): an icon rail on the left (Home, Song, Loadout, Shop, Settings) and the player card, daily challenges, daily gift and play mode on the right. It slides off during a run, and the match status only shows in a real match.

- Hub places (Workspace.DanceHub, set in Music Game): players walk the island with their own controls, camera and lighting; a station's Pick a Song prompt opens the picker, a song takes them down to the stage under the club lighting, and LEAVE (pause menu or results) brings them back to the station. The old DDS game is switched off, and its XP and coins fold into the profile once per player. The stage and floor are Persistent models so streaming always sends them.
- The stage can sit anywhere in a place: Workspace's DanceFloorOrigin attribute sets where the dance floor is (default 0, 0, 0). Music Game now holds the arena, dance floor, pad HUDs, song picker and effects, under its island; Argon keeps place-only scripts in ServerScriptService and StarterPlayerScripts so its hub scripts survive a sync.
- The song picker shows your best grade letter on each song and difficulty, and its BEST panel shows your best score and combo (kept per chart in the profile's stats.songBests). Each chart is rated 1 to 5 stars from its note density, tempo and difficulty, so songs no longer all show the same stars.
- The dance floor now sits on the urban street stage (Workspace.Arena.Street, sorted into Ground, Platform, Speakers, Fences and Props), and its speakers pump on the beat. To keep the scene calm, the ranking and how-to-play panels, the LED wall's equalizer bars and the street's screens, monitors, clutter and graffiti went to ServerStorage.ArenaRemoved.
- Disco stage: a raised deck with a neon edge that chases the beat, a flown truss with four moving heads sweeping coloured beams through the haze, and two spinning mirror balls beside the title. The lighting is now a hazier, more saturated night-club grade.
- The rival dances on a raised podium of its own, a solid deck trimmed in its colour, set back on the left of the stage so the floor camera keeps it in frame.
- A depth-of-field blur keeps the floors sharp and softens the stage and crowd behind them, so the eye stays on the game.
- A night city skyline with slow red rooftop beacons now stands around the street where the black back wall was, under a deep navy after-sunset sky with purple haze instead of a black one. The background blur is off on the Low performance tier.
- The 5x5 dance floor is authored in the place as Workspace.DanceFloor, so it can be seen and restyled in Studio; each player's floor is a copy snapped to the board's real position.
- New song Our Hearts (120 bpm, four difficulties), our own track, charted from its audio.
- Three particle bursts from the place's effect pack, kept for big moments only: confetti-style PartyPop over the dancer when a song is cleared, hearts (LovePop) when Fever starts, and a yellow splash (YellowBurst) at combo 25, 50 and every 100. They scale down on the lower quality tiers. The pack lives in ReplicatedStorage.BurstVfx, and Argon now keeps place-only children of ReplicatedStorage.
- The song picker's pack tabs work: STARTER holds Candy Pop Warmup and Neon Heartline, PACK 2 holds I Don't Wait and Under the Starlight, and the open tab takes STARTER's art. Tabs lift and tilt on hover and squash on a click, and song rows squash when clicked.
- The song picker's empty background now drifts with faint SELECT A SONG lines and twinkling stars; rows, badges, CONTINUE and BACK grow on hover, and what is not there yet reads grey (the other packs, empty rank boxes, locked songs). Long titles shrink onto one line in their row instead of wrapping over the BPM.
- The song picker plays each highlighted song's preview on a loop, fading between songs, while equalizer bars in the preview box bounce to its beat. The pack tabs answer a tap: STARTER holds every song and the other packs say SOON.
- The song picker is the designer's new select screen (`StarterGui.Songs`): one row per song with its difficulties as badges, the title in letter tiles, and the goal and length. It slides in, the selected row pops, the page pulses to the song's BPM, and CONTINUE launches the song with its title held centre screen until the run sweeps it away. Arrows browse, Enter starts, L or BACK closes and L reopens.
- Timing tunes itself: after each song the game measures how early or late your timed presses landed, moves your timing offset most of the way there, and says so on the results screen ("HITS 18 MS LATE  OFFSET +13 MS").
- The run HUD's score bar and song card share new neon art: the outline's colours sweep round and glow on every beat, and an equalizer bounces behind the song's timeline. The rival card has a matching tilted frame in the rival's mood colour.
- Grades (PERFECT, GREAT, MISS and the rest) are chrome italic text in their own colour with a glow; each one slams in at a tilt with a light sweeping up it. Perfect is now lime-yellow everywhere.
- Every combo hit kicks: the number tilts and shines, the burst spins on, the COMBO row bounces and diamonds burst in the combo's colour. The burst spins faster as the combo climbs and flashes pink in Fever, milestones wobble, and the COMBO text shimmers to the beat.
- The combo has a comic burst behind its number, a burst of neon diamonds on milestones, and shatters like ice when a combo of 5 or more breaks.
- Neon Heartline, I Don't Wait and Under the Starlight are back in the song list next to Candy Pop Warmup. I Don't Wait and Under the Starlight are re-charted with the current generator and now have an expert chart too; their beat grid was checked against the audio and stays within about 10 ms.
- Nan An Doraga (120 BPM, made with Suno) is charted on all four difficulties but waits in ArchivedSongs: Roblox moderation rejected its audio.
- Abilities: 16 to choose from, four per run (ABILITIES in the lobby or K), no buttons: a charged ability drops onto a free tile beside an upcoming note and fires when you step on it. The cards, a compact 2x2 block at the left, show charge, ON FLOOR! and the time left; firing one calls it out on screen with a flash, a camera kick and a cheer. Runs start with 25 charge. The server decides every one, and a run that uses one pays but does not rank.
- A crowd stand beside your floor, in the pad shot. Crowd hype decides how many fans are on their feet; a hold raises every lightstick, a run sends a wave down the row as you go, a clap gets clapped back, and finishing a hold or run gets the row jumping and cheering.
- Studio autoplay for playtests: set Workspace.Autoplay (and AutoplayAbilities, to also step onto ability pickups) to have the game play the chart through the real input. It plans from the tile the dancer actually stands on, so a refused hop no longer throws off the rest of the run.
- On the pad a ring closes onto your next target and turns green on the beat, so pressing on green is pressing on time.
- On the pad the rival's avatar sits in a card at the top right and dances along with them. It nods and says
  NICE! on a hit, shakes on a miss, gets smug when ahead, worried when behind, and says WOW! at your milestones.
- Every direction on the pad has a third dance move (disco point, fist pump, chest pop, shoulder shimmy), so
  steps cycle through three moves instead of two.
- When you race a rival, the results screen says who it was, their score, and whether you won.
- Rival bots wear free Roblox catalog hair, shirts and pants, so they look like other players.
- The rival bot keeps the race close: when well ahead it sometimes slips a grade, when well behind it sometimes
  lifts one.
- The rival bot dances with the player's own move set (step strikes, stumbles, spins, a flourish at milestones)
  instead of looping one emote.
- The crowd dances to the beat: it bounces harder as your combo grows, sways its lightsticks, sends a stadium
  wave down the row on milestones and drops its arms on a miss.
- Notes on the pad have two-tone fills, a neon rim, a slow shimmer and an icon per kind (ring, diamond, pause, clap,
  chevrons), so each move reads by shape as well as colour.
- The pad HUD and the on-screen WASD and CLAP keys use the authored art, and on phones the combo moves under the score
  instead of crowding the top centre.
- The pad HUD and keys are authored in `StarterGui.PadHud` (desktop and landscape-phone layouts) so they can be
  edited and previewed in Studio; the game is landscape only on phones.
- On desktop the song, life and score panels and the combo are bigger, the WASD and CLAP keys scale with the screen,
  and the multiplier and shield read as plain coloured text.
- On desktop the song and time sit in one card top left (with the elapsed and total time), and the spot under the
  score shows the life bar, or the 1v1 meter when a real player is your rival; the lines along the top edge are gone. The time bar, labels and idle
  keys are grey so the note colours, life and combo stand out.
- Results: the hint moves to the bottom left with just INVITE and PHOTO MODE (RETRY and NEXT SONG have buttons).
- Daily challenges list progress first and no longer run under the song list.
- The colour legend under the pad shows each colour name in its own colour and fits on one line.
- The desktop keys are laid out like a keyboard (W over A S D, with a wide SPACE / CLAP bar under them) and are solid
  instead of see-through.
- Phones get a two-thumb layout: song card top left, score and life (or the 1v1 meter) top right, the combo and
  grade small at the top centre, a big cross D-pad bottom right and a big CLAP bottom left; the pad is framed
  clear of all of it.
- Phones: the camera frames the whole pad beside the on-screen keys, the keys are a compact block with a square CLAP,
  and the rival's floor and the hint bar hide during a run.
- The pad camera comes alive: it closes in on the dancer during green holds, leans into purple runs, sweeps on drops
  and choruses and punches on combo milestones, and always keeps the whole pad in view.
- Green phrase-end holds are real breaks (about 2.5-2.8 s on easy and normal, 3 beats on hard and expert) with a clap
  or two on the snare inside; every generated song is recharted.
- Pad steps have direction: the dancer crouches, strides and lands on bent knees, and on back steps turns side-on
  and looks over the shoulder instead of gliding backwards.
- Hops have weight: every landing on the pad adds a soft low thump, a deeper tile dip and a small downward camera nudge.
- Steps on the pad tick a soft hi-hat instead of a clap, so the clap sound belongs to clap notes and the song stays
  clear. Purple runs and green holds lost their busy sounds (one ding when a run finishes, a chime when a hold
  completes), and the hard-mode click is softer.
- Pad runs get a cleaner HUD: a big combo top centre with the grade under it, a thin time line and versus line along
  the top, song and life top left, score top right, and nothing over the floor.
- K-pop 96 gets an expert chart and busier normal and hard: purple runs follow the drum fills and build into every
  drop, more red walls in the drops, holds on long vocal notes, and a beat grid 23 ms more accurate.
- Purple runs, green holds and yellow claps get their own dance moves (sprint strides and a finishing spin, a
  grooving power pose that pops or slumps, big claps that jump on long combos) and short success bursts on the floor.
- Purple runs, green holds and yellow claps have their own sounds: a whoosh and climbing blips through a run, a rising
  swell, beat ticks and a chime on a held hold, and a crisp clap on the beat (a dull thud when off it).
- K-pop 96, a high-energy K-pop track from DistroKid's Creator Store catalogue, second in the song list with easy,
  normal and hard charts. Marked not ready for public release until its rights are checked.
- Under the Starlight, a K-pop track from DistroKid's official Creator Store catalogue, with easy, normal and hard
  charts made from its audio. Marked not ready for public release until its rights are checked.
- Purple chains are a run: hit the first tile on the beat, then run the rest of the lit path at your own pace before
  the purple fuse runs out. Every tile you reach is a Perfect.
- Charts: purple is a fast half-beat chain with no wait before it, poses became green holds you step onto, claps only
  come while you stand still, hard and expert have no fast loose steps, two-tile hops or quick back-and-forth, and every
  special except blue picks is rarer (blue is more common).
- Green holds: step on when full, then a white level drains with the beats left; step off on the white flash. Tile
  numbers are bigger.
- Every difficulty of the four generated songs can now be picked from the song list (easy, normal, hard and, where
  charted, expert), each playing the song's own audio. A playtest switch, `SongCollection.UnlockRules.UnlockAll`,
  opens every song; set it to false to bring the unlock rules back.
- Every note fills up toward its beat (step, clap or let go when it's full), rush tiles fill one after another, poses
  fill white while you hold, the note after the next is outlined in its own colour, and the on-screen keys fill in step.
- Hard and expert click on every note's beat, so the rhythm can be heard as well as read.
- Charts: normal rushes go one tile a beat, easy and normal get blue picks again, and every difficulty gets more red
  tiles (a second wall on normal plus single red tiles beside the path).
- New moves on the dance pad, each with its own colour and dancer move: green poses (stand still while your tile
  fills), yellow claps (press SPACE, gamepad X or the on-screen CLAP key on the beat) and purple rushes (a short path
  you run at half-beat speed). Charts put claps on the snare, poses at phrase ends and rushes in choruses on normal
  and up; off the pad they drop out or play as plain steps.
- Floor events: songs break into short mini games mid-song (floor is lava, spotlight, memory and freeze), announced
  with a banner and a 3-2-1 and scored like normal notes.
- Timing fix: a press on the beat you hear is now Perfect. The run clock follows the music, the 80 ms land-delay bias
  is gone, and the device default offsets are small. Hops are quicker and remember two presses.
- Targets show a closing frame, flash on the beat and pop their countdown numbers; the glowing key ticks on the beat.
  Targets appear a beat earlier on normal, hard and expert.
- Easy and normal charts breathe: fewer notes, regular rests and no back-to-back jumps.
- Pad dancing reworked: each step plays a clear move toward where you went, the hop tucks the legs and lands with a
  knee bend, quick steps blend into each other, and the groove between steps never stands still.
- On-screen WASD keys are back at the side of the pad on every device. They light up as you press, and the key that
  moves you toward the next tile glows pink, brighter as its beat nears. They replace the touch-only arrow lanes.
- The pad camera is lower and closer so you can see your dancer. In a run it leans after you, sways and bobs on the
  beat, swings wider in choruses and Fever, zooms in with your combo and shakes on a miss or a drop. The arena's
  how-to-play screen now explains the pad rules.
- Pad charts dance to the song: calm verses, quick runs in choruses, zig-zags and jumps, a rest before drops, and sweeping
  danger walls. Combo Fever plays the Music Game's hand-made pad chart.
- Your character dances on the pad: a move for each step direction, spins on Perfects, a stumble on misses, and a groove
  that grows with the combo and Fever.
- The pad and arena move with the music: beat pulses, landing ripples, colour waves for chorus, drop and Fever, a dim
  flash on a miss, and arena lights and crowd that follow along.
- Gold item tiles in choruses give bonus score and hype if you step on them; combo milestones get a banner and a cheer.
- Solo runs have a rival bot dancing the same song on a small pad beside yours, racing your score on the versus bar.
- The dance pad is back as the main mode and plays like the Music Game: each arrow hops one tile, and you're judged on when you
  land against the beat (early is a Good, a short grace if late). Tiles count down and light up pink or cyan, a clap plays as you
  step onto the target, and the camera looks down over the whole pad. Highway mode is still there with `CoreMode = highway`.
- Highway hits splash by grade, holds glow and sparkle while kept, missed notes grey out, and the arrows spring when pressed.
- Highway HUD shows live accuracy, rank and misses under the time bar; Fever makes the bar pulse gold, and a broken 10+ combo flashes red.
- Results count up your score and stamp your rank in its colour, with Full Combo and New Best badges and a Songs button. Song select has proper song cards.
- Sounds from the Music Game place: every caught note plays a clap on top of the song, an empty press
  taps softly, and the crowd cheers at the start, on Fever and at the end. Countdown says ready and go.
- Combo Fever from the Music Game place, its hand-made chart turned into lanes. Silent until the song's
  owner lets this experience use the audio.
- Two K-pop style Creator Store tracks to try out, I Don't Wait (141 BPM) and Intro-Retro KPOP (121 BPM),
  unlocked and charted from their audio. Not cleared for release yet.
- `scripts/chart-audio.py` charts any audio file for the highway: it finds the tempo and beats, keeps the
  strongest hits, and lays notes out by pitch. Needs numpy and soundfile.
- New song: Neon Heartline, an original K-pop style dance track at 128 BPM with a sung hook, pre-chorus
  build, dance break and bridge. Unlocked from the start; it plays the normal chart.
- Scores can set "sound": "pop" for a fuller produced sound (layered drums, 808, supersaws, a sung
  "ah" voice, sidechain and reverb). Rendering those needs numpy.
- Highway notes now follow the song's melody instead of ticking on the drums: low notes land left, high
  notes right, and the drums fill in where the tune rests. Candy Pop Warmup easy goes from 132 to 208 notes.
- Missing a note in the highway muffles the music for a moment, so you hear it as well as see it.
- The Down lane now lights the tile under the dancer, since the tile in front was hidden under the camera.
- The highway has an FNF-style top bar: a big song clock, and in a 1v1 a tug-of-war bar with both
  players' faces that follows the score. The combo now sits beside the dancer and the grade above them.
- The highway dancer now really dances: a dance loop runs under the arrow poses, poses hold for most
  of a beat like FNF's, hold notes keep their pose until you let go, and Fever switches to a bigger dance.
- The highway HUD has colour: each grade gets its own (SICK! gold, GOOD! green, OK blue, BAD violet,
  MISS red), the combo climbs from white to blue, green, gold and a rainbow at 100, and lanes are tinted.
- The highway HUD dances to the music like FNF's: the whole HUD zooms in on every bar and eases back,
  the score, combo and song text bop on every beat, the panels rock side to side, and each grade is
  thrown up and falls away. The numbers are FNF's own.

- The highway now looks and plays like Friday Night Funkin': left, down, up and right arrows in FNF's
  colours, grey receptor arrows in the HUD's keys that press, confirm and glow the way FNF's do,
  W A S D or the arrow keys, FNF-style grades (SICK! / GOOD! / OK / BAD / MISS), and notes moving at
  FNF's usual speed, about twice as fast as before.

- Hold notes in the highway: a note with a tail you keep the key down through. The key stays lit
  while you hold, the tail drains into it, and letting go early greys the tail out. Holding at least
  60% still earns a Good. Charts keep holds sparse on easy (about one note in twelve).

- Candy Pop Warmup is now a full 2½-minute song with verses, choruses, a breakdown and a bridge,
  and its notes run the whole way. The chart now comes from the same score as the audio.

- In highway mode your character really dances: a pose per key, a groove on the beat, a slump on a miss, a cheer every 10 combo, and the camera frames them big and left of centre.
- The run HUD animates and nothing overlaps it: panels slide in, keys squash, combo bumps, score counts up.
- A Funky Friday style mode, `highway`: arrows scroll up four lanes on screen and you hit each one as
  it reaches the top. Your character stays on stage and steps toward every arrow you press, and
  wobbles on a miss. Turn it on with the `CoreMode` attribute; existing charts play on it.
- Highway notes now land on the HUD's own A S D F keycaps, drawn in the keys' art, and on touch you
  tap the keys themselves. The lanes are A S D F, nothing else, so a key always means its keycap.
- In the highway the camera is a stage shot of your dancer: it sways with the music, punches on the
  beat, closes in as your combo grows and circles the dancer during Fever.
- The song panel shows the song you are playing instead of a placeholder title.
- In the highway the dance floor plays along: a note about to land glows on the tile beside your
  dancer in its lane's colour, every press flashes that tile, a Perfect ripples light across the
  floor, a miss flashes red underfoot, and Fever turns the floor into a party.

- Two floors to test against the 5x5, picked with the `BoardLayout` attribute: a 3x3 dance pad
  (`pad3`) and four lanes with a note highway (`lanes4`). Every tile has its own key or button, so a
  note is one press and a diagonal stops costing two. Existing charts are remapped onto them.
- A frame that lands on its tile exactly on the beat, so you read timing from where it is. On the
  lanes it slides down the highway instead.
- A landing sound on every hop, played the instant you land rather than when the verdict arrives.
- On touch, the pad mirrors the floor on the new layouts: a 3x3 grid, or four lane buttons.

- The client now reports when its own step landed, on the clock the server shares
  (`ReportArrival`). The server only sees a replicated position 140-300 ms late, which is far too
  coarse to grade a landing against a beat. A claim is trusted only while it stays near that
  player's running delay estimate, so shifting one buys at most about 80 ms.
- The judge now grades plain steps through the active core mode, so flipping the `CoreMode`
  attribute in Studio changes how the game plays without a code change. Early/late milliseconds are
  reported for plain steps too, not just holds and slides.
- The server prints one line per finished run: mode, song, rank, grade counts, how early or late the
  landings sat, why misses happened, and the measured client-to-server delay. It is what the core
  mode gets chosen on.
- Three core-loop modes to compare in the real game (`Shared/CoreRules.luau`), because standing still
  carries no timing skill today, so arriving early and waiting is always the best play. `standWait`
  is today's behaviour, `arriveOnTime` grades *when* you land rather than how long you waited, and
  `onBeat` drops standing entirely and grades the landing against the beat.
- A test runner for the pure modules (`ServerStorage/Tests/`) that runs in Edit mode with no Play.
  17 tests so far, including ones asserting that waiting longer can never buy a better grade.
- `docs/GAMEPLAY_PLAN.md`, a handoff plan to make the core loop fun before building more on it, and
  `docs/REFERENCE_GAMES.md`, the research on other rhythm games behind it.
- A match now plays one song together. The host (player 1) picks it, the server starts it for both
  players on the same start time, and a rematch replays it. Only the host can restart; the guest is told
  who picks. Pause is still off in a match.
- A floor per player. One player has the centre floor; in a two-player match each player gets their own
  5x5, side by side, the server puts each player on theirs, and each camera centres on its own floor.
  The shared 5x10 floor is not being built.
- A live ghost of the rival's floor in a match: their grades flash on it as the server reports them.
- Two screens either side of the floor: the rankings on the left, and a four-line reminder of the
  stand-still rule on the right. The rankings used to sit behind the camera where no one could see them.
- A settle ring on the target tile. It fills while you stand on it and turns gold when you have
  stood long enough for a Perfect, so the waiting is something you can see.
- Touch controls: an on-screen step pad, a Pause button, a Settings button for calibration, a
  tappable song list, and Next song and Replay on the results screen. Every shortcut that was
  keyboard-only now has a button.
- Gamepad: the D-pad and left stick move one tile at a time.
- Quick presses queue the next step instead of being dropped, and holding a direction keeps walking.
- Tapping a far tile walks the path to it, one step at a time.
- Expert difficulty, above hard. The tightest windows in the game and the harshest life drain.
- The authored UI's art now loads. 93 of its images belonged to another account, so the experience
  had no permission to use them and every panel, icon and frame drew blank while the text showed.
  They are re-uploaded to the group and all 314 references point at them.
- `tools/scripts/reimport-assets.py` re-imports assets into the group that owns the experience, and
  `emit-repoint-luau.py` turns its map into a script that repoints the references. Upload as
  `Image`, never `Decal`: a Decal id is accepted but `ImageLabel.Image` will not draw it.
- A music pipeline. One score file per song in `assets/scores/` renders both the track and every
  difficulty's chart, so the two can never drift apart:
  `python scripts/generate-rhythm-map.py assets/scores/<song>.json`.
- Charts are now checked for reachability, not just the travel budget: whether the avatar can cross
  in time at the difficulty's step time, and whether a Perfect is possible at all.
- This changelog, and the rule for keeping it: one line per noticeable change, in the same commit.
- Three subagents in `.claude/agents/` so cheap work runs on cheap models.

### Changed

- The song picker and the stage screens show one at a time: opening one closes the other, and the lobby's mode tile and PLAY step aside while the picker is up. In Stage Challenge the picker opens on the stage's next song; in Free Play on the last one played.
- NEXT SONG on the results (and N) plays the stage's next song in Stage Challenge, through the challenge prompt when it is the challenger's; in Free Play it still cycles the song list.
- The lobby's rank strip reads the same numbers and words as the setlist board: total XP over the stage's threshold, then "200 XP TO HANA" or "CHALLENGE HANA READY".
- Songs from a stage you have already left pay half the finish and grade XP (first-finish and friend bonuses stay whole).
- The first-join lesson, timing check and tips are switched off for now (`OnboardingCatalog.Enabled`); turning it back on gives them to everyone who hasn't done them.
- Settings has one layout on every device and stands alone (no rail): tabs down the left, rows that each say in a few words what they do, and RESET TAB in the footer. Text sizes are fixed, so it reads the same on any monitor and stays readable on phones. Its buttons are style-sheet pills, so nothing looks stretched. There is no DONE; changes save as you make them and X closes. On touch the menu rail's buttons are bigger too.
- The Settings window is relaid out: taller tabs, and the right-hand card holds the setting's name, its description and RESET TAB, clear of the DONE art. Lesson cards hide while a lobby window is open.
- The lesson card is authored in StarterGui.Lesson in the song card's neon style. Each try lights a pip and gets a call-out (NICE!, TOO LATE, ON THE RED!), and drills count in from 2 with the first step sooner.
- The loading screen is authored in StarterGui.Loading, so it can be seen and restyled in Studio; the script only animates it.
- The island-to-stage transition matches the loading screen: same backdrop, a lit mini floor, the caption in the title style and GET READY.
- Only cleared runs with no abilities and no anti-cheat flags reach the score and weekly perfects boards.
- UI pass: every lobby window shares one layout (full-width tabs, top-aligned lists, detail centred on the right), Rewards and the lobby's daily rows use the purple cards, SOLO PLAY is a pink pill, and the pause screen drops the old pixel font for the menu style. Code-built screens now use Oswald too, and the results screen's HUB and RETRY buttons match. Travel, Market, Rewards, Shop and Settings show the picked item on a detail card, the Shop grid fits three bigger cards a row, and the timing meter is a proper bar.
- New shared style sheet `ReplicatedStorage.UIStyles`: tag an element `Card`, `Chip`, `Pill` and so on to style it, and change the look everywhere from its tokens (see docs/UI_STYLE.md).
- The Quests window is laid out like the Shop: pill tabs on top, a wide list of purple quest cards with a reward chip and a green tick when done, and a level card on the right. Finished quests sink to the bottom, each tab shows how many are done, bars fill in when the window draws, and reward chips show the coin or the cosmetic's icon.
- The pad shows only two tiles ahead: the next target in pink and the one after it in white, with one line from you to the pink tile. Everything else stays dark: no outlines, trails, chevrons, timing ring, fuses, sparks or shine. A hit is one short flash that goes out as soon as you step off; ability pickups keep their colour but lose the floating name.
- Easy and normal never ask for a diagonal: every target is on your row or column. A diagonal in the chart becomes two steps on two beats (a corner first), or moves onto the line when there is no room. Hard and expert are unchanged.
- On PC the grade call-out (PERFECT, GREAT, MISS and its reason) is about twice as big and sits just below the combo and life bar. Phones keep their layout. The change is in `StarterGui.PadHud.Desktop.GradeLine`, so save the place.
- The combo can be heard and felt: it counts up the moment you step instead of a round trip later, and your hits fill out as it grows (a shaker from 25, a drum from 50).
- The crowd is louder and cheers every 10 combo between the big milestone cheers. It has its own place in the mix and follows the Sound Effects slider.
- The song leads the mix: it plays louder, and the effect and menu sounds sit under it. The volume sliders still work on top.
- Sound works like osu!: only hitting a note makes a sound, and it lands on the beat. Moving, the grade pings (they came a round trip late) and the click on every note are gone. Hit sounds are quieter in calm parts, and the combo-break sound plays only after a 20+ combo.
- The floor arrow that shows where to go now takes the diagonal when one gets there, instead of always bending in an L.
- The floor uses fewer colours: every tile you must reach is pink (rush, hold and pose keep their icons), cyan is a choice of tiles, yellow a clap and red a tile to avoid.
- Loadout reads at a glance: cards, slots and tabs take their ability group's colour, the slots are numbered, equipped cards say which slot they are in, and clicking one jumps to that slot instead of swapping it. A filled slot pops.

- The lobby windows read better: bigger card text and two visible rows in Loadout, which also names the slot you are filling and each ability's group; the Shop marks the picked card, dims locked ones and shows the price on BUY; Settings has an offset meter and a RESET.

- The lobby hint is muted for now (the Muted attribute on StarterGui.Lobby.Hint; clear it to bring the hint back).

- Only the songs with real music are in for now: Our Hearts (the default), I Don't Wait and Under the Starlight. Candy Pop Warmup and Neon Heartline moved to ServerStorage.ArchivedSongs.

- On the results the camera eases round to a close front shot of the dancer, so photo mode actually centres the avatar. The results' buttons and the pause menu's buttons grow and tilt on hover and dip on press, and both screens animate out instead of vanishing. The results' combo, accuracy and grade counts sit together beside the score instead of across the slash.

- The results screen is the designer's authored StarterGui.Derail.Result in place of the code-built panel, and it animates: the slash sweeps in, the score counts up, the rank stamps down and sways, stats and XP fill, and the buttons rise in. The lobby menu and hint stay off it, and the server now sends level progress and the rank's XP bonus for its XP bar.
- Songs no longer cut off: a finished song rings out over 3 seconds instead of stopping on the last note, and the song-picker preview loops at least 20 seconds, ending on a bar line, with softer fades.
- Our Hearts has a new, longer instrumental version (3:03, was 2:15), evened out onto one steady tempo so the steps stay on the music to the end, with fresh charts for every difficulty.
- Crown Points (CP) are now called Fans: the third pack tab reads PACK 3 · 20 FANS, and the design docs use the new name.
- The song picker reacts to the music harder: a new song deals its right-side panels in one by one, loud hits jolt the preview box and burst backdrop stars, a star pops on every beat, and every four beats a title tile spins.
- More life in the song picker: SELECT's letters bounce in a wave, the selected row's number shimmers and its stars twinkle in turn on the beat, PREVIEW blinks like a recording light, the A SONG tag wobbles, and the goal score counts up when you change song or difficulty.
- The run HUD's equalizer bars now move with the song's actual loudness. The hotter the combo, the harder the panels
  bop and shake, the number sways and the edges glow; the crowd hops on every hit, fist pumps from a 10 combo and goes rainbow in Fever.
- The arena is a full house: bleachers of painted fans on both sides of the floor and a row in front of the stage, dancing with the rest of the crowd.
- The pad camera sits closer, so the floor fills the space between the HUD and the keys.
- The life panel has new art, and the rival's mood bubble (NICE!, OOPS! and the rest) is now a tilted comic box that shakes in:
  white when it's good news for you, black when it's theirs.
- The ability cards are purple neon cards instead of the yellow ones, with more room between them, a bigger icon and a
  thin charge bar in place of the percentage, all in the HUD's own font, in the same purple as the other panels; the
  rival's name now sits above their card.
- The life bar shines along with the beat, shakes and flashes when you take a hit, and leaves a red trail of the life you
  lost; the pause key bops on the beat.
- Starting a song from the picker blends into the run: the title holds over GET READY and the difficulty, then the screen leans in, the title's tiles burst away one by one and the picker fades through to the stage as the countdown starts. The picker now sits above the run HUD, so nothing shows through it.
- The song picker's preview bars follow the song itself: they show the preview's loudness, newest in the middle and rippling out, and the title bounce and pulses keep to the song's real beat instead of a clock.
- The song picker's right side moves with the music: a bounce runs along the title's letters on each beat, the unpicked badges, info bar, goal bar and CONTINUE rock gently, and a drifting purple backdrop fills the gap in the background art where the 3D world used to show through.
- The song picker's list is bigger and lines up under the pack tabs, and each row's title runs up to its stars, so long titles stay readable.
- The pad and floor now draw each beat on your calibrated timing, the clock the judge uses, so the ring turns green exactly when a press counts as on time; before, a timing offset moved the judge but not the picture.
- The run clock follows the music more closely: it averages Roblox's chunky playback readings instead of trusting the first one and ignoring anything under 50 ms, so it no longer sits up to 15 ms off for a whole run or drifts up to 50 ms before correcting.
- The pad's arrow keys now sit bottom left and CLAP bottom right, on desktop and phone; the ability cards moved above CLAP.
- The pad HUD moves with the music: the combo beats like a heart, a sound wave runs inside the song card, score and
  life panels, a faint ring pushes out from the combo, a sparkle marks milestones, and the screen edges glow in Fever,
  at low life and on a combo break. Each is a placeholder in `StarterGui.PadHud` for the designer to replace.
- The pause screen, settings panel, in-run hints and floor-event banner are authored in `StarterGui.GameHud` so a
  designer can restyle them in Studio. Pause has a Settings button, and its dim now covers the whole screen.
- The pad camera frames only the player's own floor, so it sits closer; the rival's ghost floor stays at the side.
- The rival card moved beside the song card so it no longer covers the score, life bar or combo.
- Candy Pop's green holds now sit on the tune's long notes and let go half a beat before the next one, instead of a fixed 5-beat break that ran over the melody. Purple runs only land on melody notes or snare hits, so they play the 3-note chorus figure and the snare roll into each chorus.
- The pad camera sits lower and closer, the desktop combo is a compact strip at the top, and on phones the HUD uses the top bar's row. The rival card is a narrow photo with the name and reaction under it, no panel.
- Easy and normal stay on the song's beat: on easy a hold lets go in time for the next phrase's first beat, so no phrase starts on beat 2; the step hi-hat of a tile you reach early waits for its beat, and the guide tick now plays on easy too.
- Holds and runs share one timer: a white fuse that burns down, round the hold's tile or along the run's path. The timing ring steps along a run tile by tile on the beat, closes over the gap since the last note when that is under a beat, and has a dark edge so it reads on green holds.
- The song list is down to Candy Pop Warmup (easy, normal, hard, expert) while the core is tuned; every other song is kept in ServerStorage.ArchivedSongs.
- Charts dance the same steps when the music repeats: a phrase that comes back (second verse, every chorus) replays its earlier moves, turned to fit the floor. Easy no longer asks for claps during a hold.
- Shared is split into Songs/, Catalogs/ and Policies/, and the client's loose modules into Audio/, Dance/, Floor/, Effects/ and World/; the chart scripts now write to Shared/Songs. Reconnect Argon after pulling.
- Candy Pop Warmup and Neon Heartline charts now step only where the music hits: no steps on silence, claps only on snares and claps, and steps slide onto the off-beat where the song accents it.
- Normal difficulty now clicks on every note's beat, like hard and expert, so the rhythm can be heard.
- On desktop the pad camera pulls back to fit the rival's floor beside yours, so the bot is never half off screen.
- The on-screen keys and CLAP are smaller on phones, so the pad no longer covers half the screen.
- Highway notes are your HUD's own keycap art, and the feedback animates the real pieces instead of
  drawing over them: the bar under each key fills as its note comes in, keys tint and tilt on a press,
  and the panel behind them pulses on the beat.

- The highway's keys are 35% bigger and its notes about twice as tall, with a white stripe that
  marks the exact moment to press.
- Generated charts are gentler, as other lane games pace them: easy is a note every other beat,
  normal every beat, and only hard and expert use off-beats. The warmup no longer has mines.

- Highway notes scroll about a third slower (2.4 s on easy down to 1.4 s on expert) and land
  centre-on-centre on their key. Presses had been landing 82 ms early on average.

- The lobby no longer shows an empty score column. Score, combo, hype, life and the goal bar now
  leave the screen between runs instead of sitting at zero over the song list.
- The side menu is one colour. Four different accents made it a rainbow and buried the coin balance,
  the only live value in that column.
- Song rows are one size and left-aligned. `TextScaled` had been sizing each row on its own, so a
  short title rendered much larger than a long one and the list looked broken.
- A locked track with no stated requirement no longer says LOCKED twice on the same row.
- A new arena: a dark violet room with pink as the one accent and gold for highlights, instead of a
  pastel for every surface plus magenta and cyan neon. Everything is axis-aligned and mirrored, so the
  diagonal light beams, sloped stage edges and tilted 45 degree diamonds are gone.
- Calmer lighting: bloom, haze and saturation are down, so the pink no longer washes the screen and
  the lit floor is the brightest thing in frame.
- The dance floor tiles drop their four neon corner marks. The gaps between tiles read as a thin grid
  and one pink rim frames the floor.
- The arena is real parts in `Workspace.Arena`, one folder per area, instead of being generated each run.
  It can be moved and recoloured by hand in Studio, and the code just binds to it by name. It is built
  from `World/` (one module per area), and a place with no arena still builds it at runtime.
- The avatar steps tile to tile in the difficulty's step time (0.14 s on easy down to 0.09 s on
  expert). It used to walk at 16 studs a second, about half a second a tile. The client moves its
  own character and Roblox's default walking is off; the server still judges where you stand.
- Holds and slides start on their own when you are standing on the tile as the beat lands.
- A run hides the shop, daily and mode buttons, so the screen is the floor and the score column.
- Key hints (R, N, B, O, P and so on) only show on a device with a keyboard.
- Fixed HUD overlaps: the life gauge sat on the song progress, the daily list covered the Daily
  button, and the mode button overlapped the multiplayer panel on small screens.
- The client is split into `UI/` (drawing), `Input/` (devices), `Controllers/` (logic) and `Net/`.
  `Main.client.luau` is wiring only, and the 1,400-line HUD is one module per screen.
- The easiest difficulty is called easy now, not beginner, so timing and the life gauge use the
  same names. Old charts still work; `beginner` is kept as an alias.
- Rewrote CLAUDE.md, README.md and UI_STYLE.md. They described a tank artillery game built on a
  framework this project doesn't use.
- UI_STYLE told people to build screens in Studio. Everything here is built in code, and it says
  so now.
- The Argon project is called Dance Dance Step, not Tank Game.

### Removed

- The rank-up card's code (`ProgressPopups.showRankUp`) and the unused `LobbyController.openChart`; the stage-up reveal does that job. `Progress.RankUp` and `Progress.Dim` are only hidden now and can be deleted in Studio.
- The old DDS game's disabled server code: hub, progression, shop and settings handlers, the unit tests that covered it, the DDS client and its rival-bot template. `ReplicatedStorage/DDS` stays until FallGuard's fade template moves out of it.
- The unused SkillGapTestMaps and RhythmTypes modules, and a dozen functions nothing called.
- Everything the camera never showed: the practice lobby behind it (kiosks, seats, cloud panels, crowd
  rows, the photo spot), the LED pixel grid and backdrop hidden behind the back wall, the truss, and
  the client-built spawn pad. The stage part budget drops from 340 to 200.
- `PracticeLobbyCatalog`, which only fed that lobby.
- The `RequestTileMove` remote and the server's `MoveTo` walking, now that the client steps its own
  character.
- `scripts/layout/`, a migration tool for the tank game's folder structure.
- `GameDocumentation/`, an empty leftover.
- `tools/scripts/__pycache__/`, an ignored build artefact.

### Fixed

- A player who already held a rank before stages now sees the "now pays 50% XP" notice once, and an old save with a finished but ungraded chart no longer breaks the stages screens.
- PLAY pressed before the song list has arrived says TRACK NOT READY instead of doing nothing.
- The stage-up reveal no longer flashes up under the results and then plays a second time, and leaving the results (HUB, LEAVE, RETRY, NEXT SONG) takes the reveal, the setlist or a challenge prompt opened over them along.
- The lobby's mode tile and PLAY no longer stay hidden after a challenge prompt was closed by opening a window.
- The song picker opens a song on its easiest open difficulty when the main chart is still locked, so a new player no longer lands on a locked chart.
- Rank-ups to Trainee III and Rising Star I could never be passed and normal charts were open from rank 1: the rules looked for `-normal` chart ids, but a song's normal chart uses the bare song id.
- Lobby windows no longer get stuck in the phone layout on a monitor when Play starts while the window is still resizing.
- The loading screen covers the whole screen on phones, notch and corners included, like the transition.
- The lobby rail, player card and daily challenges no longer flash up between lesson drills; the stage, camera and run HUD stay put, and the lesson card hides while paused.
- The arena's rankings screen fits all three boards, shows levels as LV. n, and draws its boards even when the authored screen has none.
- The lobby's daily challenges, coins, stats and ability loadout show up on join again; before, they could stay empty until something changed.
- Closing a lobby window brings the lobby HUD straight back instead of after a pause.

- The lightstick sits in the fist and points forward like a held tool, instead of floating up the arm (on R6 it was at the shoulder).

- You spawn standing on the island, facing the stage with the camera behind you: the spawn pad is invisible and on the ground instead of floating, and the island camera no longer starts from the stage camera's angle.

- Commits were blocked by the hygiene hook: Studio's ProgressionBackup folder is now git-ignored, and the RivalBot Animate copy is back to its cleaned version.

- Leaving the stage no longer leaves the run HUD (song card, score, pad keys) on the island, or the camera zoomed in.

- The dancer can no longer step around the floor once a run is over (failed or cleared) while the results are up.

- No walking or jumping while dancing: on the stage the character's own walk and jump are off (keyboard, touch button, after a respawn, and in places like Music Game that run Roblox's controls without a PlayerModule); both come back on the hub's island. Picking a song switches to the stage camera at once, so the island camera no longer swings after the player on the way down.
- Going back to the songs after a run no longer leaves its guide ticks, step sounds and crowd cues playing over the menu, and the song preview plays again: a finished song now ends the run on the client too.
- The hi-hat for a step you reach early now lands on the music's beat; with a timing offset set it used to come late by that offset.
- The run HUD's song card, score bar and life panel no longer stretch out of shape on wide or phone screens.
- Grade text (PERFECT, MISS and the rest) is solid now instead of see-through near the top, and the combo is bolder.
- The floor chart generator no longer puts a long note, or the step after one, half a beat from another step on difficulties without eighths. Some tracks would not chart at all because of it.
- The floor chart check no longer rejects a hold whose length rounds up by half a millisecond, which stopped Under the Starlight from charting.
- The pad HUD no longer shows its placeholder combo, keys and score over the lobby when the player spawns slowly; it
  ships switched off and the client waits up to a minute for it.
- On desktop the pad camera keeps the floor below the combo and grade line, so they no longer cover the top row of targets.
- The mode button no longer covers the top of the results panel on short screens.
- The pad HUD (song card, score, life) no longer stays on screen behind the results.
- The grade line's outline no longer lingers on its own after the text fades, and HUD outlines scale with the text
  instead of being too heavy on phones and too thin on the big combo number.
- The pad dancer moves smoothly: no joint pops during a hop, feet stay planted after landing, back steps turn and
  settle naturally, and the arms no longer fly off before the first step of a run.
- The Fever start whoosh plays again; its old built-in sound never loaded.
- A step the server saw you make is never thrown away for an odd report time any more; its time is pulled back
  into the allowed band instead, which removes most of the remaining wrong Misses.
- Charts keep a steady pulse: each section repeats one two-bar rhythm and every four bars end with a breath, so the
  speed no longer swings mid-song. Easy and normal only ever ask for the next tile over, normal stays on the beat,
  and quick half-beat notes start at hard.
- The dance pad is simpler: only the next tile lights up, with a big beats-left number and an arrow from your
  dancer; the tile after it is a plain white outline (pink only ever means step here now), blue groups share one outline and danger is a red X. The approach frames,
  order labels, ripples, colour sweeps and the burst under the dancer are gone.
- Pad HUD moved off the floor: combo and grade (now with early/late ms) sit in the right column, milestones, combo
  breaks and banners in a slim strip under the song bar, and the WASD keys sit lower.
- Floor mini games are switched off while the plain notes are tuned; the charts were regenerated without them.
- Standing on the lit tile no longer breaks your combo when a landing report goes missing: the server now checks
  where it saw you at the beat, allowing for network delay, instead of where you are when it judges.
- Step reports now carry real clock times, so the server stops rejecting them when the music runs a little late;
  the music's offset moves the judged beat instead.
- The client never got the song's difficulty, so the telegraph, the hop speed and the note speed
  always used normal's numbers.

- `onBeat` judged the landing, one hop after the press, so a press dead on the beat graded Great
  (Good on easy). It now judges the press.
- A landing report that reached the server before the character's position was thrown away, so the
  new modes quietly fell back to the late server view. Reports now wait up to half a second for it.
- In `onBeat` the next note's telegraph waited for the verdict on the last one, which on a busy chart
  showed it almost on its own beat. It now moves on as soon as the press window closes.

## Baseline

Imported in one commit on 2026-10-18, so there is nothing before it. The game already had:

- The 5x5 stand-and-wait core loop, with holds, slides, bonus tiles and danger tiles.
- Score and combo, crowd hype, a Fever window, and a life gauge that can fail a run.
- A chart schema, a pattern vocabulary, a generator, and four tracks with difficulty variants.
- Solo, two co-op layouts and a battle mode, with a queue, party codes and rematch.
- Coins, cosmetics, song unlocks, XP and levels, dailies, achievements and leaderboards.
- A HUD and a lowpoly concert stage, both built in code, with per-grade effects.
- Server-side judging of every beat, with rate limits and anti-cheat counters.
