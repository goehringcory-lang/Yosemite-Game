# Polish checklist: measured against Stardew Valley

This is the list of what makes Stardew Valley feel finished, what this game does for each, where it lives, and how it's checked. "Test" means `tests/polish_test.tscn` unless another test is named; "shot" means a screenshot from `tools/shots/polish_shot.tscn` (in `docs/`). The last section lists what is not done, on purpose or not yet.

## Feedback: the game answers everything you do

| Stardew hallmark | Here | Where | Checked by |
|---|---|---|---|
| "Item get" cards at the corner with picture and count | Cards slide in at the top left, clear of the message line; repeats count up ("x2") with a bump; gear gets a brighter chime | `scripts/ui/item_toasts.gd` | test (stacking, counting, at most 3); shot `polish_toasts.png` |
| Things you pick up fly into you | Forage and story items hop up and fly into the player | `scripts/world/pickup_pop.gd` | smoke test picks forage up |
| Every item has a picture | All 38 items, including the 12 cooked foods that showed only names before | `tools/ui/food_icons.gd` | test (every item has an icon) |
| Shop and cooking menus show the goods | Pictures beside every trade and every dish, highlight across the row | `DialogueBox.choose(..., icons)`, `vendor.gd`, `station.gd` | shots `polish_shop.png`, `polish_campfire.png`; story test (long lists fit) |
| A card about the thing under the cursor | Beside the campfire and shop lists: a dish's ingredients with what you have of each (red when short), its energy, yield and time, and its note; a ware's price against the food you carry, how many you own, and what it's for | `DialogueBox.choose(..., details)`, `Station.menu_for`, `Vendor.offer_card` | test (one card per choice, short ingredients in red, fits the screen); shots `polish_campfire.png`, `polish_shop.png` |
| The player's own page | The pause menu shows your portrait, the date, and a tally: food carried, gear, friends and hearts, quests done, climbs | `PauseMenu._build_card`, `card_text` | test (portrait present, tally lines) |
| Menu sounds | Tick to move, knock to choose, swish to open and close (book, pause menu, conversations, the day's page) | `scripts/autoload/sound.gd`, `MenuInput.pop_in` | audio test (every sound played exists) |
| Menus animate | The book, pause menu and conversation box fade and grow or rise into place | `MenuInput.pop_in`, `dialogue_box.gd` | by eye |
| Text never collides | Long place names drop their leading parts so the banner never runs into the clock | `HUD.set_location` | test |
| The place name shows as you arrive | The banner names where you are, then fades after four seconds, and comes back when you go somewhere new | `HUD.set_location` | by eye |
| Interact prompt | "E  Talk to Wren" over the player, in gamepad names on a gamepad | `hud.gd` (existing) | settings test |
| A save message | "Good morning! Your game was saved." | `world.gd` (existing) | smoke test |

## People

| Stardew hallmark | Here | Where | Checked by |
|---|---|---|---|
| Portraits in conversation, with expressions | A portrait for all 40 people (and the player) in four moods (neutral, happy, sad, surprised), painted from the same look data as their sprite; each line picks its mood (named, or read from its words) | `tools/npcgen/portraits.gd`, `scripts/story/portraits.gd` | test (every member of the cast has one, each mood is its own face, lines read as the right mood); `docs/cast_portraits.png`, `docs/portrait_moods.png` |
| Each person sounds like themself | Text types out with blips at a pitch of their own | `Portraits.voice_pitch` | test (same every time, different between people, in a pleasant range) |
| A "!" over people with a quest | Orange "!" for a new quest, blue "?" to hand one in; on shopkeepers too | `QuestLog.marker_for`, `scripts/story/quest_marker.gd` | test (Clark "!" at the start, gone once taken; "?" when ready); shot `polish_quest_marker.png` |
| Friendship hearts and gifts | Five hearts per person, from talking each day, finishing their quests, and one gift a week (G or LB while facing them); everyone has loves drawn from their story (Muir's dry crusts and tea), likes good food, and never thinks less of you; hearts in the Journal's Friends section, a heart pop and chime, and new hearts on the day's page | `scripts/story/friendship.gd`, `gift_giving.gd`, `hearts.gd` | test (daily talk once, loved and liked gifts, weekly limit, hearts one at a time, quest warmth, saved, everyone has real loves, Journal shows hearts); shot `polish_gifts.png` |
| People react when you talk | They turn to face you and give a small hop | `npc.gd` | by eye |
| People stand on the ground | A soft oval shadow under the player, every person and every shopkeeper | `scripts/world/ground_shadow.gd` | shot `polish_gift_prompt.png` |
| People keep hours | Visitors go home between 8 and 10 PM and come back at 7 AM, fading out and in; about half stay in on rainy days. People with quests keep a day near their spot: at their post first thing, strolling about it from 9 to 5, nearer in the evening, standing at it overnight | `NPC.is_out`, `NPC.roam_radius` | test (home at night and can't be talked to, back in the morning, quest givers stand overnight and stroll by day) |
| People walk about | Wanderers stroll round their spot (existing) | `npc.gd` | cast test |
| Villagers keep a timetable | Visitors in Curry Village and Yosemite Village walk a day of stops ("9:00 plaza"): out of home in the morning, to work, lunch and an evening spot, and home again at night, routed round buildings and props on a walk grid. Five townsfolk (a lifeguard, a housekeeper, a postmaster, a baker, a photographer) joined them | `NPC.timetable`, `scripts/world/walk_grid.gd` | `tests/timetable_test.tscn` (every stop reachable from every other, a day played sped up); `tools/shots/timetable_shot.tscn` |

## Time and place

| Stardew hallmark | Here | Where | Checked by |
|---|---|---|---|
| The clock dial | A window of sky: the sun crosses over Half Dome, moon and stars at night, dawn, gold and dusk skies, clouds, rain and snow | `scripts/ui/clock_dial.gd` | test (sun rises left, high at noon, sets right; moon up at night; sky colors); shot `polish_clock_dial.png` |
| The end-of-day tally | The day's page at bedtime: things found and given with pictures, gear, first ascents, quests, perks, recipes, dishes | `scripts/story/day_log.gd`, `scripts/ui/day_summary.gd` | test (counts, saved with the game, clears each morning, opens and closes); shot `polish_day_summary.png` |
| Grass that moves as you walk through it | Ferns, bracken, shrubs and flowers sway in a damped wobble with a soft rustle when you brush past | `scripts/world/rustle.gd` | test (walking through sets a fern swaying; it leans, then settles upright) |
| Critters | Steller's jays, juncos, robins and quail hop and peck, fly off as you come near, and leave at dusk or in rain; butterflies on fair spring and summer days | `scripts/world/critters.gd`, `tools/npcgen/critter_art.gd` | test (by day outdoors only, flee when close, the right birds each season); shot `polish_critters.png` |
| Bears | Black bears (mostly brown or cinnamon) wander through outdoor areas now and then as you walk about, most in fall and at dawn and dusk; a mother may bring cubs; they look up when you come close, then move off | `scripts/world/bears.gd`, `scripts/world/bear.gd`, `tools/npcgen/bear_art.gd` | valley life test (odds by season and hour, field log, notice and leave, cubs follow, cleared off screen and between areas); shot `bears_meadow.png` |
| Deer | Mule deer graze across outdoor areas all year, more often than bears: does in twos and threes, fawns in summer, antlered bucks from summer to winter, summer and winter coats; they stare when you come close, then bound off | `scripts/world/deer.gd`, `scripts/world/mule_deer.gd`, `scripts/world/wanderers.gd`, `tools/npcgen/deer_art.gd` | valley life test (odds by season and hour, coats, field log, stare and bound, fawns follow); shot `deer_meadow.png` |
| Towns that look lived in | Crates, barrels, milk cans, trash cans, picnic tables, a mailbox, a newspaper rack, a sandwich board, flower beds, firewood, an ice chest, luggage and worn lawn about both towns' plazas, shop fronts and lawns | `tools/hubs/town_clutter_art.gd`, `tools/hubs/dress_towns.gd`, `scenes/regions/dressing/` | timetable test (both towns dressed, routes still clear) |
| Cars that stand up | Parked cars in 3/4 view: a cabin with side glass, shaded flanks, a rear face with lights, plate and bumper, tyres under it | `CurryAhwahneeArt.car`, `tools/hubs/draw_cars.gd` | by eye |
| Seasons you can see | Blossom and leaf drift, seasonal trees and ground, snow, waterfalls that run dry (existing) | `seasonal_*.gd`, `ambient_fx.gd`, `weather.gd` | smoke and audio tests |
| Night lighting | Windows, lamps, tents and fires glow; fireflies (existing) | `night_light.gd`, `night_glow.gd` | by eye (`docs/camp4_night.png`) |
| String lights at night | The bulbs strung over Curry Village's plaza glow after dusk with the lit windows | `scripts/world/string_lights.gd` | shot `polish_clock_23.png` |
| Weather | Rain, snow, cloud shadows, overcast tint (existing) | `weather.gd`, `cloud_shadows.gd` | `docs/weather_winter_snow.png` |
| Smooth camera and fades | Camera smoothing, fades between places (existing) | `player.tscn`, `hud.gd` | travel test |

## Sound and music

| Stardew hallmark | Here | Where | Checked by |
|---|---|---|---|
| A piece for each season | Two pieces a season (one for mornings, one from 1 PM, each in its own key, tempo, mode and voice), a night piece, and a looping title theme | `tools/audio/build_music.gd` | test (each is built; the right one plays for the hour, season, rain and the title) |
| Music comes and goes | One piece, then 30 to 75 seconds of ambience alone; quiet in the rain and on the wall, softer indoors, fades on a change | `Sound._update_music` | test (`music_choice`) |
| Music in tune and balanced | Strings within 2 cents of true pitch over the range the pieces use, no note dropping out, each tune at 0.8 to 1.0 times its accompaniment | `_pluck` (all-pass tuning, decay stretching) | test (measured pitch and loudness of rendered notes); the mix was measured when the pieces were built |
| A volume for music | Music has its own bus and setting | `settings.gd`, `pause_menu.gd` | test, settings test |
| Living ambience | Birds, crickets, wind, rain, fires, waterfalls, footsteps by surface (existing) | `sound.gd`, `sound_emitter.gd`, `footfall.gd` | audio test |

## Independent reviews

Two separate reviewers, given only screenshots and asked to be harsh, judged the game against Stardew Valley. The first found text running off the Controls page and both maps, the day's page over the clock, item cards under menus, the gift prompt covering the person, placeholder shopkeepers and a placeholder campfire, ASCII cursors, and a crowded climbing HUD. All of that is fixed, and the second reviewer confirmed it from new screenshots, rating the presentation about 6.5 of 10 against Stardew (up from about 5). Their next round (padding inside panels, the world dimming behind menus, drawn checkboxes and arrows, fades at scroll edges, a card behind messages, at most four item cards, since cut to three of one width) is fixed too.

Their biggest remaining point was typography: Stardew uses one pixel font, and this game uses Noto Sans because a pixel font (Tiny5) was found too hard to read. The game now uses DotGothic16 by default: a pixel font, like Stardew's, whose letters stay distinct at the small sizes (B and G, C and O, 5 and S, 2 and 8 all read apart), so it answers the readability problem that ruled out Tiny5. **Settings > Font** switches back to smooth Noto Sans for anyone who prefers it (`docs/polish_pixel_font.png`). A third review found that the first pixel font tried (Pixelify Sans) joined "fi" into a shape like "A" and that its B read as G, so it was replaced with DotGothic16.

The third reviewer scored the default build 6.5 of 10 against Stardew Valley, before the pixel font became the default, the portraits doubled (and gained richer shading), the volume sliders, the logo, the pixel-art park map and the shared frames on the climbing screen. What they said meets the bar: the world art and props, day and night lighting with lamp and fire glow, the item icons, the frame and tab system across the book and conversations, the friendship hearts, and the day's page.

Three more reviews followed (the fourth, fifth and sixth), each given fresh screenshots of every screen and asked to score fresh against Stardew Valley. They scored 6.5, 6 and 6 of 10. Each found new things, and these were fixed:

- The pixel font is monospaced Japanese DotGothic16, so "i" and "l" floated in gaps ("Vi l lage"). Its Latin letters were made proportional (`tools/fonts/proportional.py`); digits stay one width so the clock reads "1:00", not "100".
- Text at small sizes was unevenly spaced, so text is now placed at subpixel positions.
- Half-cut rows showed at the bottom of the journal, backpack and credits. The scroll fades now go solid at the edge.
- Backpack counts ran into the art; they are now small, in the corner and ringed.
- The day's page ran headings into values; headings now sit in a column.
- The campfire and shops showed long one-line recipes. They now have a card about the choice under the cursor.
- The pause menu was half empty. It now has your portrait and a tally of the game.
- The title's tagline and hints were blurred by heavy outlines. They now sit on soft bands.
- The climb's energy number ran off the screen. Its height bar now has a summit mark, and its move costs are no longer green.
- Nobody had a shadow. Everyone does now.
- The Camp Curry Store's lamp hung over its sign.
- Yosemite Village's buildings were barely two people tall. They were redrawn 1.45 times larger, with doors people fit and paved walks to every door, and cars were parked in the empty lot.
- The paving's flagstones were as wide as a person, so plazas read as walls. The slabs are smaller now.
- String lights stayed dark at night. They now light at dusk.
- Birds stayed out after dark. They now leave at dusk and in rain.
- The place-name banner now fades after you arrive.

A seventh and an eighth review (after the game was named Valley Days) scored 6 and 6.5. What they found and what was done:

- **The HUD didn't show what you trade with.** The clock now shows the food energy you carry, as Stardew keeps your gold under its clock.
- **Portraits looked flat.** They're painted at 80 px with form shading and a rim of light.
- **Menus were text with dead space.** Quests are now cards with the giver's face and a "Looking for help" list. Settings has a card about the chosen setting, Friends have faces, and the gift menu shows who you're giving to.
- **Item cards sat over people.** They're one width, three at most, and hide during a conversation unless fresh.
- **The use prompt covered heads and signs.** It's now a slim bubble.
- **Placeholder-looking art.**
  - Trail mix is now a paper sack.
  - The flag has stripes.
  - Cars have a rear face in 3/4 view.
  - The Mountain Shop has finer floorboards and gear on its walls, and its crash pad no longer has scribbled lettering.
  - Waterfall mist and smoke are pixel puffs.
- **Frame seams.** The panel and plaque edges no longer stretch into light strips.
- **Layout bugs.**
  - A lamp no longer stands in a bench or glows through a tree.
  - A string of lights no longer floats.
  - Map labels keep clear of the pin and markers.
- **The climb.** Slab holds are readable, the energy bar has a bolt instead of an "E", and move costs are no longer green.
- **Music.** Each season has a second, afternoon piece.

A later pass found two more things:

- **A stripe through every menu's first line.** The panel's inset was a gradient that the 42-color palette snapped into two tones, and the lighter tone's last two rows fell in the part of the nine-slice that stretches, so a band one eighth of the panel's height cut through the Journal's and Backpack's first headings and the day's page's subtitle. The lit edge now stays in the unstretched margin and the middle is one color (`tools/ui/ui_art.gd`; test: each panel's middle is flat).
- **The prompt could name the wrong thing.** With a person beside a sign, the use prompt named whichever overlapped first. It now names the one nearest the middle of your reach (`Player.get_target`; test: swapping two things swaps the target), and fades in when it changes.

| Stardew hallmark | Here | Where | Checked by |
|---|---|---|---|
| A pixel font that matches the art | DotGothic16 by default (SIL Open Font License, credited with its license), with its Latin letters made proportional (`tools/fonts/proportional.py`) after a fourth review found the fixed-width "i" and "l" left gaps ("Vi l lage"); Settings > Font switches to Noto Sans | `Settings.ui_font`, `apply_font` | test (switches the theme and the climbing screen, saved, pixel by default, an i narrower than an m, license present; every screen checked to fit with both fonts) |

## Not done

The last five independent reviews scored the game 6 to 6.5 of 10 against Stardew Valley. It is not at Stardew's level. What holds it back, in the reviewers' words and ours:

- **Curry Village's buildings keep their first size.** The outer hubs, the smaller areas and Camp 4 now have their ground clutter and campers' gear (`tools/hubs/dress_wilds.gd`), but the lodgepole floor is still mostly a sweep of sand between the trees, kept calm on purpose.
- **Nobody walks from one area to another.** Townsfolk and, in the two towns, the cast with quests keep a day of stops (errands morning and evening, the Camp 4 fire and the Camp Curry amphitheater after dark), but each keeps to their own area; Stardew's villagers cross the whole map. The cast outside the towns, and the Native characters everywhere, keep to their spots.
- **Portraits are laid out on a 40-dot grid** and painted at the 80 px they show at (round shapes and shading at full resolution, eyes and mouths in two-pixel dots), with five-tone shading; Stardew's are 64 px and hand-drawn. Walking sprites are 16x24 (Stardew's are 16x32); the owner chose to keep that as the game's style, and the buildings were scaled to suit it.
- **No hand-drawn art.** All art is drawn by code in a consistent style; Stardew's is hand-drawn by one artist. That needs an artist: code can match a style, not replace one.
- **The clock is a sky window**, not a dial with a hand.
- **The music was never listened to.** Everything about it was checked by measurement (pitch, loudness, mix balance, loop seams, the notes of each tune printed and read), not by ear. It needs a human listen, and a composer could do better than a seeded motif generator. Stardew has several pieces a season; here there are two.
