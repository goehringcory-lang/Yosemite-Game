# Polish checklist: measured against Stardew Valley

This is the list of what makes Stardew Valley feel finished, what this game does for each, where it lives, and how it's checked. "Test" means `tests/polish_test.tscn` unless another test is named; "shot" means a screenshot from `tools/shots/polish_shot.tscn` (in `docs/`). The last section lists what is not done, on purpose or not yet.

## Feedback: the game answers everything you do

| Stardew hallmark | Here | Where | Checked by |
|---|---|---|---|
| "Item get" cards at the corner with picture and count | Cards slide in at the bottom left; repeats count up ("x2") with a bump; gear gets a brighter chime | `scripts/ui/item_toasts.gd` | test (stacking, counting, at most 5); shot `polish_toasts.png` |
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
| People keep hours | Visitors go home between 8 and 10 PM and come back at 7 AM, fading out and in; about half stay in on rainy days | `NPC.is_out` | test (home at night and can't be talked to, back in the morning, quest givers always there) |
| People walk about | Wanderers stroll round their spot (existing) | `npc.gd` | cast test |

## Time and place

| Stardew hallmark | Here | Where | Checked by |
|---|---|---|---|
| The clock dial | A window of sky: the sun crosses over Half Dome, moon and stars at night, dawn, gold and dusk skies, clouds, rain and snow | `scripts/ui/clock_dial.gd` | test (sun rises left, high at noon, sets right; moon up at night; sky colors); shot `polish_clock_dial.png` |
| The end-of-day tally | The day's page at bedtime: things found and given with pictures, gear, first ascents, quests, perks, recipes, dishes | `scripts/story/day_log.gd`, `scripts/ui/day_summary.gd` | test (counts, saved with the game, clears each morning, opens and closes); shot `polish_day_summary.png` |
| Grass that moves as you walk through it | Ferns, bracken, shrubs and flowers sway in a damped wobble with a soft rustle when you brush past | `scripts/world/rustle.gd` | test (walking through sets a fern swaying; it leans, then settles upright) |
| Critters | Steller's jays, juncos, robins and quail hop and peck, fly off as you come near, and leave at dusk or in rain; butterflies on fair spring and summer days | `scripts/world/critters.gd`, `tools/npcgen/critter_art.gd` | test (by day outdoors only, flee when close, the right birds each season); shot `polish_critters.png` |
| Seasons you can see | Blossom and leaf drift, seasonal trees and ground, snow, waterfalls that run dry (existing) | `seasonal_*.gd`, `ambient_fx.gd`, `weather.gd` | smoke and audio tests |
| Night lighting | Windows, lamps, tents and fires glow; fireflies (existing) | `night_light.gd`, `night_glow.gd` | by eye (`docs/camp4_night.png`) |
| String lights at night | The bulbs strung over Curry Village's plaza glow after dusk with the lit windows | `scripts/world/string_lights.gd` | shot `polish_clock_23.png` |
| Weather | Rain, snow, cloud shadows, overcast tint (existing) | `weather.gd`, `cloud_shadows.gd` | `docs/weather_winter_snow.png` |
| Smooth camera and fades | Camera smoothing, fades between places (existing) | `player.tscn`, `hud.gd` | travel test |

## Sound and music

| Stardew hallmark | Here | Where | Checked by |
|---|---|---|---|
| A piece for each season | Spring, summer, fall and winter pieces, a night piece, and a looping title theme | `tools/audio/build_music.gd` | test (each is built; the right one plays for the hour, season, rain and the title) |
| Music comes and goes | One piece, then 30 to 75 seconds of ambience alone; quiet in the rain and on the wall, softer indoors, fades on a change | `Sound._update_music` | test (`music_choice`) |
| Music in tune and balanced | Strings within 2 cents of true pitch over the range the pieces use, no note dropping out, each tune at 0.8 to 1.0 times its accompaniment | `_pluck` (all-pass tuning, decay stretching) | test (measured pitch and loudness of rendered notes); the mix was measured when the pieces were built |
| A volume for music | Music has its own bus and setting | `settings.gd`, `pause_menu.gd` | test, settings test |
| Living ambience | Birds, crickets, wind, rain, fires, waterfalls, footsteps by surface (existing) | `sound.gd`, `sound_emitter.gd`, `footfall.gd` | audio test |

## Two independent reviews

Two separate reviewers, given only screenshots and asked to be harsh, judged the game against Stardew Valley. The first found text running off the Controls page and both maps, the day's page over the clock, item cards under menus, the gift prompt covering the person, placeholder shopkeepers and a placeholder campfire, ASCII cursors, and a crowded climbing HUD. All of that is fixed, and the second reviewer confirmed it from new screenshots, rating the presentation about 6.5 of 10 against Stardew (up from about 5). Their next round (padding inside panels, the world dimming behind menus, drawn checkboxes and arrows, fades at scroll edges, a card behind messages, at most four item cards) is fixed too.

Their biggest remaining point was typography: Stardew uses one pixel font, and this game uses Noto Sans because a pixel font (Tiny5) was found too hard to read. The game now uses DotGothic16 by default: a pixel font, like Stardew's, whose letters stay distinct at the small sizes (B and G, C and O, 5 and S, 2 and 8 all read apart), so it answers the readability problem that ruled out Tiny5. **Settings > Font** switches back to smooth Noto Sans for anyone who prefers it (`docs/polish_pixel_font.png`). A third review found that the first pixel font tried (Pixelify Sans) joined "fi" into a shape like "A" and that its B read as G, so it was replaced with DotGothic16.

The third reviewer scored the default build 6.5 of 10 against Stardew Valley, before the pixel font became the default, the portraits doubled (and gained richer shading), the volume sliders, the logo, the pixel-art park map and the shared frames on the climbing screen. What they said meets the bar: the world art and props, day and night lighting with lamp and fire glow, the item icons, the frame and tab system across the book and conversations, the friendship hearts, and the day's page.

| Stardew hallmark | Here | Where | Checked by |
|---|---|---|---|
| A pixel font that matches the art | DotGothic16 by default (SIL Open Font License, credited with its license), with its Latin letters made proportional (`tools/fonts/proportional.py`) after a fourth review found the fixed-width "i" and "l" left gaps ("Vi l lage"); Settings > Font switches to Noto Sans | `Settings.ui_font`, `apply_font` | test (switches the theme and the climbing screen, saved, pixel by default, an i narrower than an m, license present; every screen checked to fit with both fonts) |

## Not done

- **Walking sprites are small.** Portraits show at 80 px (painted at 40 and doubled, against Stardew's 64) with five-tone shading and highlights. The Yosemite Village buildings were redrawn 1.45 times larger, so a shop stands about three people tall with a door a person fits, but the people themselves are still 24 px, and Curry Village's buildings keep their first size.
- **The name is a working title.** The title screen now has a drawn logo (gold, extruded, with a divider), and the park map is pixel art in the game's frames, as are the climbing screen's notes; the words "Yosemite Game" are still a placeholder for the owner to choose.

- **The music was never listened to.** Everything about it was checked by measurement (pitch, loudness, mix balance, loop seams, the notes of each tune printed and read), not by ear. It needs a human listen, and a composer could do better than a seeded motif generator. Stardew also has several pieces a season; here there is one.
- **Only visitors keep a daily routine.** Visitors head home in the evening, each at their own hour, come back in the morning, and half stay in when it rains; the people with quests stay where they are so you can always find them for their stories. Stardew's villagers walk full timetables between home, work and the saloon.
- **No hand-drawn art pass.** All the art is drawn by code in a consistent style; Stardew's is hand-drawn by one artist.
