# Polish checklist: measured against Stardew Valley

This is the list of what makes Stardew Valley feel finished, what this game does for each, where it lives, and how it's checked. "Test" means `tests/polish_test.tscn` unless another test is named; "shot" means a screenshot from `tools/shots/polish_shot.tscn` (in `docs/`). The last section lists what is not done, on purpose or not yet.

## Feedback: the game answers everything you do

| Stardew hallmark | Here | Where | Checked by |
|---|---|---|---|
| "Item get" cards at the corner with picture and count | Cards slide in at the bottom left; repeats count up ("x2") with a bump; gear gets a brighter chime | `scripts/ui/item_toasts.gd` | test (stacking, counting, at most 5); shot `polish_toasts.png` |
| Things you pick up fly into you | Forage and story items hop up and fly into the player | `scripts/world/pickup_pop.gd` | smoke test picks forage up |
| Every item has a picture | All 38 items, including the 12 cooked foods that showed only names before | `tools/ui/food_icons.gd` | test (every item has an icon) |
| Shop and cooking menus show the goods | Pictures beside every trade and every dish, highlight across the row | `DialogueBox.choose(..., icons)`, `vendor.gd`, `station.gd` | shots `polish_shop.png`, `polish_campfire.png`; story test (long lists fit) |
| Menu sounds | Tick to move, knock to choose, swish to open and close (book, pause menu, conversations, the day's page) | `scripts/autoload/sound.gd`, `MenuInput.pop_in` | audio test (every sound played exists) |
| Menus animate | The book, pause menu and conversation box fade and grow or rise into place | `MenuInput.pop_in`, `dialogue_box.gd` | by eye |
| Interact prompt | "E  Talk to Wren" over the player, in gamepad names on a gamepad | `hud.gd` (existing) | settings test |
| A save message | "Good morning! Your game was saved." | `world.gd` (existing) | smoke test |

## People

| Stardew hallmark | Here | Where | Checked by |
|---|---|---|---|
| Portraits in conversation, with expressions | A portrait for all 40 people (and the player) in four moods (neutral, happy, sad, surprised), painted from the same look data as their sprite; each line picks its mood (named, or read from its words) | `tools/npcgen/portraits.gd`, `scripts/story/portraits.gd` | test (every member of the cast has one, each mood is its own face, lines read as the right mood); `docs/cast_portraits.png`, `docs/portrait_moods.png` |
| Each person sounds like themself | Text types out with blips at a pitch of their own | `Portraits.voice_pitch` | test (same every time, different between people, in a pleasant range) |
| A "!" over people with a quest | Orange "!" for a new quest, blue "?" to hand one in; on shopkeepers too | `QuestLog.marker_for`, `scripts/story/quest_marker.gd` | test (Clark "!" at the start, gone once taken; "?" when ready); shot `polish_quest_marker.png` |
| People react when you talk | They turn to face you and give a small hop | `npc.gd` | by eye |
| People walk about | Wanderers stroll round their spot (existing) | `npc.gd` | cast test |

## Time and place

| Stardew hallmark | Here | Where | Checked by |
|---|---|---|---|
| The clock dial | A window of sky: the sun crosses over Half Dome, moon and stars at night, dawn, gold and dusk skies, clouds, rain and snow | `scripts/ui/clock_dial.gd` | test (sun rises left, high at noon, sets right; moon up at night; sky colors); shot `polish_clock_dial.png` |
| The end-of-day tally | The day's page at bedtime: things found and given with pictures, gear, first ascents, quests, perks, recipes, dishes | `scripts/story/day_log.gd`, `scripts/ui/day_summary.gd` | test (counts, saved with the game, clears each morning, opens and closes); shot `polish_day_summary.png` |
| Grass that moves as you walk through it | Ferns, bracken, shrubs and flowers sway in a damped wobble with a soft rustle when you brush past | `scripts/world/rustle.gd` | test (walking through sets a fern swaying; it leans, then settles upright) |
| Critters | Steller's jays, juncos, robins and quail hop and peck, and fly off as you come near; butterflies on fair spring and summer days | `scripts/world/critters.gd`, `tools/npcgen/critter_art.gd` | test (by day outdoors only, flee when close, the right birds each season); shot `polish_critters.png` |
| Seasons you can see | Blossom and leaf drift, seasonal trees and ground, snow, waterfalls that run dry (existing) | `seasonal_*.gd`, `ambient_fx.gd`, `weather.gd` | smoke and audio tests |
| Night lighting | Windows, lamps, tents and fires glow; fireflies (existing) | `night_light.gd`, `night_glow.gd` | by eye (`docs/camp4_night.png`) |
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

## Not done

- **The music was never listened to.** Everything about it was checked by measurement (pitch, loudness, mix balance, loop seams, the notes of each tune printed and read), not by ear. It needs a human listen, and a composer could do better than a seeded motif generator. Stardew also has several pieces a season; here there is one.
- **No friendship or gifts.** Stardew's hearts and gifting are a game system rather than polish, and the story here is built on quests instead.
- **No daily schedules.** People stay round their spot rather than following a timetable through the day.
- **No hand-drawn art pass.** All the art is drawn by code in a consistent style; Stardew's is hand-drawn by one artist.
