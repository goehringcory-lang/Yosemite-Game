# Valley Days

A cozy pixel exploration game set in Yosemite, built with **Godot 4.7** (GDScript). You meet real people from the park's history, hear their stories, and earn the climbing gear that opens up more of the park.

## Running it

```bash
sudo pacman -S godot        # one-time install
godot project.godot         # opens the editor; press F5 to play
```

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD / arrow keys | Left stick / D-pad |
| Run | Hold Shift | Hold B or RT |
| Talk, read, pick up, use | E, Space, X, C, or click | A or X |
| Give a gift (facing someone) | G | LB |
| Fish (facing water, with a fly rod): cast, stop the meter (back cast, then forward cast) / reel in (hold) / give up | E / E, E / hold E / Esc | A / A, A / hold A / B |
| Park and area map | M (Tab or mouse wheel switches tabs) | Back (LB / RB switch tabs) |
| Journal (the Register, friends, the calendar, the field log, guidebook, perks) | J | Y |
| Quests | Q | Y, then LB / RB |
| Press Book (the plants you've pressed, and where the rest grow) | P | Y, then LB / RB |
| Backpack (gear, food, forage) | B | Y, then LB / RB |
| Pause menu (save, settings, every control) | Esc | Start |
| Back out of a menu | Esc | B |
| Menus: choose / confirm | Up/Down / E or Enter | Stick or D-pad / A |
| Settings: change a value | Left/Right (or E) | Stick or D-pad left/right (or A) |
| Dialogue: show the whole page / next | E (first press / second press) | A |
| Climbing: climb up, up-left, up-right | W / A / D (or arrows) | Stick up / left / right |
| Climbing: place a cam or clip / eat at a ledge, shake out on a jug, or chalk up / retreat | Space or C / E / Esc | X / A / B |
| Climbing: aid a hard move, or jug a fixed rope | Shift + arrow | Y + stick |
| Slackline: lean back (hold the side away from the tip) / trick / step off | Left / Right / E / Esc | Stick left / right / A / B |
| Binoculars: look about / zoom / step back | Arrows (Shift faster) or drag with the mouse / E or mouse wheel / Esc | Stick / A / B |
| *Debug:* skip 1 hour / sleep now / unlock and go to Glacier Point | F2 / F3 / F4 | |

A prompt above the player's head shows what the interact button will do (a drawn E key, then "Read: Camp 4"), and it switches to the pad's buttons when you use a gamepad. Every menu's hint line (pause menu, journal, conversations, maps, title, credits, the day's page) follows the same switch. Keys are drawn as little pixel buttons rather than names in brackets: cream keycaps for the keyboard (arrow keys as arrows), and for a pad the colored A, B, X and Y discs, shoulder pills and a D-pad with the arms in use lit (`scripts/ui/button_hints.gd`).

**The title screen** comes up first, over a pixel painting of the Valley (El Capitan, Half Dome, Bridalveil Fall, which shimmers; `assets/ui/title_background.png`): Continue (when there's a save), New Game, Settings, Credits and Quit. New Game asks first if there's a save, and the old save stays on disk until your first save or night's sleep replaces it, so quitting before then loses nothing. Credits has two pages: the credits (the map data, elevation, font and engine), which scroll by themselves, and Licenses, the full license texts the game has to carry (Godot's and its libraries', read from the engine, and the font's). The code is `scripts/ui/title_screen.gd` and `scripts/ui/credits.gd`; `SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/title_shot.tscn` photographs them (`docs/ui_title.png`, `docs/ui_credits.png`).

**Settings** are on the pause menu (Esc, then Settings) and on the title screen, and are kept in `user://settings.cfg`, apart from your save: text speed (Slow, Normal, Fast, Instant), full screen, window size (whole steps of 480x270, up to what fits your screen), whether your next main-story step shows under the clock, button prompts (Auto, or always keyboard or always gamepad), the font (DotGothic16, a pixel font that matches the art, with its Latin letters set proportionally by `tools/fonts/proportional.py`, by default, or smooth Noto Sans), graphics (High runs the Forward+ renderer; Low runs the simpler Compatibility renderer for older computers, and takes effect the next time the game starts, through the override file `user://graphics.cfg` that `project.godot` reads at start-up; a computer without Vulkan falls back to Compatibility on its own), and four volumes (the whole game, music, sound effects, and ambience, in steps of 10%). The code is `scripts/ui/settings.gd`.

Controls are set in **Project > Project Settings > Input Map**.

**The renderer.** The game runs on Godot's Forward+ renderer, which brings real 2D lights, shadows and glow (the lit-diorama work builds on it). `tools/shots/renderer_compare.sh` takes a screenshot tour of the park (`tools/shots/renderer_tour.tscn`: fourteen areas in the morning, at sunset and at night) under the Compatibility renderer and under Forward+, and compares them picture by picture (`tools/shots/compare_shots.gd`); the Renderer workflow (`.github/workflows/renderer.yml`) runs it on every pull request with software drivers and uploads the pictures and their differences.

**Real light (High graphics).** Every outdoor area is lit by real 2D light on the art's own relief. `python3 tools/normals/normals.py --outdoors` paints a normal map for each sprite those areas use (`assets/normals/`, mirroring `assets/sprites/`) by reading the painted shading back as height and rounding each shape's edge; glows, windows and shadows get none. `LitSprites` (`scripts/world/lit_sprites.gd`) puts them on the sprites through `assets/shaders/lit.gdshaderinc`. `SunLight` follows the `Sun` across the sky, so the morning sun catches the east sides of roofs, trunks and rocks and the evening sun the west, and the lamps (`NightLight`) light the sides of things facing them. After dark, `AirGlow` gives the lights real glow in the night air in place of the halo sprites. Low graphics keeps the painted look, with the halos.

Rooms are lit too (`--indoors` paints their maps): by day `SunLight` is the window light falling from the back of the room, and as the day outside fades `RoomLight` dims the room to a warm low light while its lamps, stoves and hearths (`LampLights.LIGHTS`) come up and light the floor and furniture round them, glowing in the air; the Ahwahnee's Great Lounge is lit by its two hearths. On the climbing screen, `ClimbLight` (`scripts/climb/art/climb_light.gd`) draws the wall on its own canvas item through `assets/shaders/lit_luma.gdshader`, which reads the relief from the painted rock as it draws, so the sun rakes across the face from its side of the sky and after dark the climber's headlamp throws a real pool of light on the stone. The Lighting workflow (`.github/workflows/lighting.yml`) photographs every outdoor area at dawn, noon, dusk and night, a few rooms by day and at night, and the climbing wall through the day, unlit and lit side by side, on every pull request.

## The core loop

Start at the Mountain Shop in Curry Village. The clerk, Marty Kessler, trades you a climbing guidebook for food (after you fetch the new printing from the Registration porch), then fits you with your first kit: climbing shoes, a chalk bag, a harness, and five quickdraws. Marty sends you to Wren Alvarez, a new hire looking for a partner, and the two of you climb **Firefall Slab**, a bolted route on the Glacier Point Apron, for your first tick. The guidebook lists every route, its grade, and the gear it needs, and you tick a route off when you top it out. The main story is that tick list: each main quest ends on a climb. Talk to people around the valley. Their quests reward you with climbing gear, recipes, and skills, and the climbers at Camp 4 trade more gear for food. Each climbing route needs certain gear before you can start it. Climbs lead to new parts of the park: the Glacier Point Apron, for example, opens Glacier Point.

Climbing runs on food. Each morning, wild forage appears around your camp, depending on the season and habitat. Fresh greens and berries give quick energy but spoil in days, so throw them in the cooking pot at any campfire: like Breath of the Wild, whatever you put in makes a dish worth more than the raw food, that keeps longer, and sometimes helps on the wall (see Cooking in the pot below). In fall, gather black oak acorns and store them in a chuckah (a granary) where they never spoil. Then grind them at the bedrock mortar, leach them at the basin, and cook them into mush or long-lasting acorn cakes at the campfire. The main screen stays clear: everything else is in a book with four tabs. Press J for the Journal (the Register, the guidebook's tick list, and perks), Q for your Quests, P for the Press Book, and B for the Backpack, which shows your gear, food, and forage as a grid of slots. Tab flips between them.

**The press book** is the other half of the story. Enid Michael, at the Museum's wildflower garden in Yosemite Village, hands you an old plant press, and from then on you can walk up to any of the park's 133 plants and press a sprig (a plant you haven't pressed yet glints, and a rare one glints gold). Each grows where and when it really does, the food plants of your forage among them: redbud and buckeye down at El Portal, sequoia in the Mariposa Grove, Jeffrey pine on Sentinel Dome, white heather at Tuolumne, wildflowers only in their season. Plants are common, uncommon, rare or very rare: a common plant grows in three patches in each place it grows, an uncommon one in two, and a rare or very rare one in a single patch, often in one season and one place. You take a sprig and leave the plant; the protected ones (the snow plant, the orchids, the park's own endemics like Congdon's lewisia and the Yosemite bog orchid) you only sketch, and poison oak you sketch from a careful step away. The Press Book tab shows every plant as a slot with its rarity: the ones you have, with where you found them, and the rest as shadows that say where and when to look, with a tally of your rare finds. Naturalists and rangers ask for plants the way climbers ask for ticks, and the old press's labels ("Collected for the Guardian of Yosemite") are a mystery that runs to the end of the game. The code is `scripts/story/herbarium.gd` (the plants and the book), `scripts/world/plant_spawner.gd` (where they grow) and `scripts/objects/plant_specimen.gd`.

As you play, the valley teaches you **perks**: small, permanent bonuses earned from people and experience, never bought. Foraging 25 finds earns *Enid's Eye* (one more find each morning), learning to belay from Dick Leonard earns *Leonard's Belay* (more rest at each ledge), two weeks of mornings earns *Muir's Stride* (a quicker walk), and so on. The Journal lists all nine and how to earn the rest. They're in `scripts/story/perks.gd`, and [docs/DESIGN.md](docs/DESIGN.md#perks) has the table.

Sleep in the tent to end the day, which also saves the game. First comes the day's page: the date, then what the day brought, counted out one by one (see [Game feel](#game-feel)). You can also save any time from the pause menu (Esc, then Save game): it keeps where you're standing, the time of day, and everything you're carrying, and Continue on the title screen picks up right there. If you're still up at 2 AM you pass out, and the game moves to the next day anyway. Once you have a wilderness permit you can also sleep out at the backcountry camp in Little Yosemite Valley (see *The first night out and Half Dome*).

## Game feel

The small touches that make the Valley feel alive, in the spirit of Stardew Valley. [docs/POLISH.md](docs/POLISH.md) goes through Stardew's hallmarks one by one: what this game does for each, where it lives, how it's checked, and what isn't done. The tests are in `tests/polish_test.tscn`, and `SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/polish_shot.tscn` photographs each one.

- **Item cards.** Whatever you pick up, cook, buy, or are given slides in on a card at the top left (clear of the description message at the bottom left): its picture, its name, and how many. A second strawberry while the card is up counts it ("Wild Strawberry x2") with a little bump instead of stacking another card. New gear gets a brighter chime. Forage and story items hop up off the ground and fly into your pack. The cards drop below the place name while it shows and hide under the book (`scripts/ui/item_toasts.gd`, `scripts/world/pickup_pop.gd`).
- **Portraits and voices.** Everyone who talks has a portrait in a frame at the right of the conversation box, in one of four moods (neutral, happy, sad, surprised) that each line picks, by name (`"mood": "happy"`) or from its words (`Portraits.mood_for`), painted by `tools/npcgen/portraits.gd` from the same look data as their walking sprite (`docs/cast_portraits.png` shows the whole cast). Their words type out with soft blips at a pitch of their own (`scripts/story/portraits.gd`), the box rises in with a swish, and choosing and confirming click like the other menus.
- **Friends and gifts.** Each person has up to five hearts, earned by talking each day, finishing their quests, and a gift once a week: face them and press G (LB on a gamepad), then pick something from your pack. Everyone likes good food, and each person loves a couple of things from their story (John Muir's dry bread crusts and tea, Enid Michael's wild greens); nothing ever loses you a heart. Hearts show in the Journal's Friends section, rise over the person as they grow, and are listed on the day's page (`scripts/story/friendship.gd`, `gift_giving.gd`).
- **Daily routines.** Visitors head home in the evening, each at their own hour between 8 and 10 PM, come back out at 7 AM, and about half stay in when it rains, so the Valley empties at night. People with quests stay out: you can always find them, at their spot through the middle of the day (`NPC.is_out`).
- **Timetables.** In Curry Village and Yosemite Village the townsfolk keep a day of their own, like Stardew's villagers: the cook goes to the Pavilion at 7:40, the lifeguard to the pool, the postmaster to the post office and on to the store and Degnan's, and everyone walks home at night and goes in. A stop is a time and a spot (`timetable = ["9:00 plaza", ...]` on an NPC in the story overlay); they walk there round buildings and props on a walk grid (`scripts/world/walk_grid.gd`) and stroll about it until the next.
- **The cast keeps a day too.** In the two towns, people with quests have their own errands morning and evening and are at the spot the Journal names from about 9 to 4, lunch aside: Ansel Adams walks out to Cook's Meadow for the morning and evening light, Salathé fetches his bread at Degnan's, Clare Hodges patrols Camp 4 and the falls trail, Jennie Curry lunches at the Pavilion. Evenings draw a crowd: Leonard, Salathé and Hodges round the Camp 4 fire, Jennie Curry, Jules Eichorn and the camp at the amphitheater. Native characters keep to their places; their days are for the tribal review to shape. Overnight they stand at their spot and doze (`timetable` on the NPC, as for visitors).
- **Faces over heads.** People show what they feel in a little bubble as they talk, as Stardew's villagers do: **!** when surprised, a note when glad, a heart for thanks, a drop when it's hard to say, **?** at a question, "..." while they think (`scripts/story/emote.gd`; `DialogueBox.say` tells whoever is speaking, `NPC.on_line` and `Vendor.on_line` pick the bubble from the line's mood). A friend (a heart or more) waves when you walk up, once a day; people blink and glance about while they stand; and late at night the cast dozes on their feet, eyes shut, "Zzz".
- **People move like people.** Everyone's sprite sheet (`tools/npcgen`) has a column for each pose: standing, two steps, a blink, two running strides, crouching, arms up, reaching out, carrying someone (standing and two steps) and talking (`CharacterSheet` in `scripts/player/character_sheet.gd` reads them, and falls back to the first three columns on a sheet that hasn't got them). Walking is a four-frame cycle (a step, passing, the other step, passing); running has its own longer, leaning strides and kicks up a spray of dust behind you. Stand about and you blink, look round now and then, and after a while stretch (with a yawn late at night). You crouch to pick up forage, a story item or a plant for the press; on the bank your rod goes back over your shoulder on the back cast, out over the water on the forward cast, and the line lies on the water and runs taut (the rod bowing) while you reel, with the arms up to show the fish off; you hunch under whoever you carry on a rescue; you lie down to sleep and stretch on waking. People talk with their mouths while their line is up (shopkeepers too), wave a friend in with an arm up, and kick up dust and leave prints in the snow as they walk (`Footfall`, quietly). A rescue's lost hiker waves both arms. Bears and deer walk on four frames too, bears root about with their noses and deer chew with an ear flicked back and flick their tails up while they watch you (`tools/npcgen/bear_art.gd`, `deer_art.gd`). `docs/character_poses.png` shows the poses; `tools/shots/anim_shot.tscn` takes screenshots of them in the game.

![Every pose, for the player and three of the cast](docs/character_poses.png)
![Crouching for forage, asleep, reeling in, and carrying someone home](docs/character_actions.png)
- **The story's moments.** When one of the Guardian sightings comes true, the next time you're free the screen letterboxes and shows it as its witness saw it: Lamon looking up from his orchard at a speck on the Apron at sunrise, the Apron from Camp Curry, Nutcracker in the afternoon, the wreck at El Portal, the figure in Ansel Adams's print (in black and white), a headlamp on the Nose at night, a climber by Muir's stakes on the Lyell ice. The view rises slowly, painted by the climbing screen's sky and skyline painters; the witness's face and words (the sighting's own, so nothing new is said for anyone) type out below, over a music sting. Each plays once; confirm or cancel skips it (`scripts/story/story_moments.gd`, `story_vista.gd`; `SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/moments_shot.tscn` photographs them).
- **The wild ground.** Outside the towns the forest floor isn't bare: drifts of needles and cones under the lodgepoles, twigs, ferns and seedlings under the Wawona pines, leaf litter and dry grass in the El Portal foothills, polished slabs and lichen on the granite, now and then a log or a stump, and at every campsite somebody's gear, no two alike (a cooler, folding chairs, a lantern, a water jug, a stove, boots, a clothesline); Camp 4's sites have crash pads, rope coils and haul bags. `tools/hubs/wild_clutter_art.gd` draws them, `tools/hubs/dress_wilds.gd` lays them out (seeded, never on a road, trail or lot, never crowding a spot, door or sign, and nothing solid where you couldn't walk round it) in `scenes/regions/dressing/wild/`, and `Region` adds each area's layout when it loads, so no builder rebuild loses it. The flat things turn with the seasons like the painted ground. Rebuild with `tools/hubs/rebuild_wild_dressing.sh` (after any builder that moves things about).
- **Towns that look lived in.** Crates, milk cans, trash cans, picnic tables, flower beds, an ice chest, firewood, a mailbox and worn lawn fill both towns' plazas and shop fronts (`tools/hubs/town_clutter_art.gd` draws them, `tools/hubs/dress_towns.gd` places them in `scenes/regions/dressing/`), and the parked cars stand up in 3/4 view.
- **Quest bubbles.** Someone with something for you wears a bobbing speech bubble: an orange **!** for a new quest (or a quest that sent you to them) and a blue **?** when talking to them finishes one (`QuestLog.marker_for`, `scripts/story/quest_marker.gd`). Shopkeepers with quests have one too, and people give a small hop when you start talking.
- **The clock's sky.** Beside the time, a little window of sky: the sun climbs over Half Dome and sets, the moon and stars follow at night, the sky turns from dawn to gold to dusk, and the day's clouds, rain or snow show in it (`scripts/ui/clock_dial.gd`).
- **Music.** Six short pieces, one for each season by day, one for the night, and the title theme. They play the way Stardew's do: a piece now and then, with the birds and wind on their own in between. Music rests in the rain and on the wall, comes in softer indoors, and fades when the hour or the season calls for another piece. See [Sound](#sound).
- **The day's page.** When you sleep, a page comes up over the black before morning: what you found and were given (with pictures), new gear, first ascents, finished quests, perks, recipes, and dishes cooked, or "A quiet day in the Valley" (`scripts/story/day_log.gd`, `scripts/ui/day_summary.gd`).
- **Birds and butterflies.** Steller's jays, juncos, robins and California quail hop and peck about on open ground and flutter off as you come near; butterflies drift over on fair spring and summer days (`scripts/world/critters.gd`, sprites from `tools/npcgen/critter_art.gd`).
- **Bears wander by.** Walk about outdoors and now and then a black bear ambles in from the edge of the view, stops to nose at the ground, and goes off the other side. Like most of Yosemite's black bears it's usually brown or cinnamon, sometimes blond, only now and then black, and in spring and summer a mother may have a cub or two at her heels. They come round most in fall, when they're fattening up for winter, and at dawn and dusk (more so by a campground with bear boxes), hardly ever in winter, and not in the dark of night. Come too close and the bear lifts its head to look at you (and you're reminded to give it 50 yards), then moves off away from you, at a lope if you run at it. A good look puts it in the field log. They never hurt you (`scripts/world/bears.gd`, `scripts/world/bear.gd`, sprites from `tools/npcgen/bear_art.gd`).
- **Mule deer graze across.** More often than the bears, and all year (many come down to the Valley for the winter), a doe or two or three graze their way across the view, most at dawn and dusk. In summer a doe may have a spotted fawn or two; from summer into winter a buck may come by alone, his forked antlers in velvet in summer. Their coats are reddish in spring and summer and gray from fall. Come close and they lift their heads and stare, big ears up, then go off in the stiff-legged bounds mule deer are known for, fawns and all. They're in the field log too, with the reminder that deer hurt more visitors than bears do (`scripts/world/deer.gd`, `scripts/world/mule_deer.gd`, sprites from `tools/npcgen/deer_art.gd`). Bears and deer share their wandering in `scripts/world/wanderers.gd` and `scripts/world/wanderer.gd`; `SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/bear_shot.tscn` takes the pictures below.
- **Plants rustle.** Ferns, bracken, shrubs and flowers sway and rustle when you brush past them (`scripts/world/rustle.gd`).
- **Pictures in the shops and at the fire.** Every trade and every dish in a choice list shows its picture (`DialogueBox.choose` takes an icon per option).
- **Every food has a picture.** The acorn chain and the campfire dishes are drawn by `tools/ui/food_icons.gd` in the forage icons' style.

![Item cards](docs/polish_toasts.png)
![A conversation with a portrait](docs/polish_dialogue.png)
![The day's page](docs/polish_day_summary.png)
![Birds on the plaza](docs/polish_critters.png)
![A cinnamon mother and cubs, and a brown bear looking up, in Leidig Meadow](docs/bears_meadow.png)
![A doe grazing with her fawns, a gray buck staring, and a buck bounding off](docs/deer_meadow.png)
![A shop with pictures](docs/polish_shop.png)
![Giving Wren a gift: the prompt, the choice, her thanks, and the Friends page](docs/polish_gifts.png)
![The clock's sky at 7 AM, 1 PM, 7 PM and 11 PM](docs/polish_clock_dial.png)

![Tuolumne's campground: no two sites alike](docs/wild_tuolumne_campground.png)
![Camp 4's sites, with crash pads, ropes and haul bags](docs/wild_camp4_gear.png)
![Ferns, cones and seedlings by the Mariposa Grove](docs/wild_wawona_floor.png)
![Emotes over the people outside Degnan's](docs/emotes.png)
![A story moment: Lamon sees a speck on the Apron at sunrise](docs/moment_apron_sunrise.png)
![A story moment: the figure in Ansel Adams's print](docs/moment_adams_print.png)
![A story moment: a headlamp on the Nose](docs/moment_nose_headlamp.png)

## Valley life: the board, the field log, fishing and festivals

Four things to do between climbs, borrowed from the cozy games and fitted to the park.

- **The Camp 4 bulletin board.** Like Stardew Valley's Help Wanted board, it pins up a note or two each morning from people you've talked with, asking for something in season: wild strawberries for Bridget Degnan's tarts, yerba buena for John Muir's tea, chanterelles for the Ahwahnee's kitchen. Read the board to take them (up to three at once). A note for something that grows only in the high country waits until you can travel to Tuolumne. They go in your Quests with how many you have and how long you've got (a note stays good three days), and you hand the things over just by talking to whoever wrote it, for trail food and a fifth of a heart. Only the Valley's settlers, climbers and staff post; the Native cast don't until their lines have had the tribal review (`scripts/story/board_requests.gd`, `scripts/objects/bulletin_board.gd`).
- **The field log.** A page in the Journal, like Alba's or Animal Crossing's critterpedia, of the animals you've met: the four birds and four butterflies that come and go around you (walk, don't run, close enough for a good look before they fly off), a mountain chickadee and a great horned owl you only hear (stand still outdoors a few seconds and listen, by day or after dark), the mule deer and the black bear you see wandering by (or the bear's tracks you find after a night out), and the fish you catch. Each has its Latin name, where you first logged it and a line of natural history; the ones still to find say when and where to look. New ones go on the day's page (`scripts/story/field_log.gd`).
- **Fishing.** Greg, Curry Village's fishing guide (an invented character, like Wren), is all over the camp: on the Merced bank below Stoneman Meadow at dawn and again in the evening, at the store for coffee, the Pavilion at lunch, the Mountain Shop talking flies with Marty, the pool, the evening program, and around the plaza through the middle of the day. He's lost his fly box on the bank by the river; bring it back (his side story *Tight Lines*) and he gives you his old cane rod and shows you how to cast, then asks to see a brown trout and gives you an Elk Hair Caddis for it. Face a river, creek or lake with the rod and press use to cast. The cast is two stops on a timing meter, like a crux on the climbing screen: a marker sweeps a bar and you stop it in the green, first for the **back cast** and then, once the line has unrolled behind you, for the quicker **forward cast**. The green's bright middle is a perfect stop. Miss the back cast and the fly hangs up in the willows behind you; miss the forward cast and the line slaps down and spooks the pool. Otherwise the two stops decide whether anything rises: **two perfect casts always bring a fish up**, quickly, and set the hook hard so the line starts well along; a perfect and a good one bring one up about 70% of the time, two good ones about 40%. If a fish takes the fly you play it in on a bar beside you, as in Stardew Valley: hold use to lift your green band, let go and it sinks, and keep the fish in it until the line fills. The fish are the park's own and follow its rules: rainbow trout in the Merced (native, and catch and release in the Valley, so they go back), brown trout (stocked from Europe; yours to keep), Sacramento suckers (native bottom feeders, spring to fall; let go), and brook trout at Tuolumne (stocked in high-country waters that had no fish; keep them). Each catch has a length in inches, and a fish near the top of its size is a trophy. Kept fish go in the cooking pot like any savory food. A cast takes 15 minutes (`scripts/fishing/fishing.gd`, `fishing_minigame.gd`).
- **Holes and rapids.** Where the fly lands decides what takes it (`FishingWater`, `scripts/fishing/fishing_water.gd`), and the Fish prompt names the water. The Merced widens into seven deep **holes**: Leidig Hole, El Capitan Hole, Housekeeping Hole, Stoneman Hole (below Stoneman Meadow, where Greg fishes at dawn and dusk), Sentinel Hole by Yosemite Village, El Portal Hole and South Fork Hole at Wawona. They're dark in the middle, rings spread where something sips a bug, and they hold the big brown trout and the Sacramento suckers; fish run larger there (a brown up to 24 inches). The **rapids** at Happy Isles, in the Merced canyon at El Portal and below the Big Oak Flat Road junction are white water over boulders: rainbow water, never a sucker, and anything hooked in the current fights harder. The rest of the river is a plain run with a bit of everything. `tools/fishing/river_pools.py` cut the holes out of the bank (the ground picture, the tiles and the clutter), and refuses one that would swallow a tree, a road or a spot.
- **Flies.** After *Tight Lines*, talk to Greg to trade for better flies; the best one you own is tied on (`Fishing.FLIES`). The **Elk Hair Caddis** (his reward) widens the green a little and the rainbows love it; the **Parachute Adams** (36 energy of food) widens it more and brings more fish up to a fair cast; the **Woolly Bugger** (a swap for 2 brown trout) sets the hook harder and brings up browns twice as often; and his own favorite, the **Royal Wulff** (a swap for 2 brook trout from Tuolumne), is the best of all. A fly never saves a missed stop. Greg's trades are `data/shops/greg_flies.tres`; any NPC can trade this way with a `shop` (NPC.shop), and a ShopOffer can ask for items (`trade`) instead of food energy.
- **Festivals.** One a season, each from the park's real history, listed in the Journal's Valley calendar with a countdown: Enid Michael's **Wildflower Walk** (Spring 12, at her garden; she led wildflower walks as a ranger-naturalist from 1921), **the Fourth at Camp Curry** (Summer 4, supper and then the Firefall), **the Yosemite Facelift** (Fall 20, the climbers' fall cleanup since 2004: litter turns up around the Valley, and Wren trades you for five pieces) and **the Bracebridge Dinner** (Winter 24, the Ahwahnee's Christmas pageant since 1927, which Ansel Adams staged). On the day a morning note says what's on, a first talk with anyone counts double, and the host has something for you while it's on, once a year. Native gatherings wait for the tribal review (`scripts/story/festivals.gd`).

![The rapids in the Merced canyon at El Portal](docs/fishing_rapids.png)
![El Capitan Hole, where the Merced widens and deepens](docs/fishing_hole.png)
![Greg at Stoneman Hole](docs/fishing_stoneman_hole.png)
![The back cast on the cast meter](docs/valley_life_back_cast.png)
![A perfect back cast, then the forward cast](docs/valley_life_forward_cast.png)
![Playing a brown trout on the Merced](docs/valley_life_reel.png)
![Notes on the Camp 4 bulletin board](docs/valley_life_board.png)
![The Valley calendar and the field log in the Journal](docs/valley_life_journal_log.png)

`SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/valley_life_shot.tscn` takes these. The fly rod's icon and the trout and litter pictures are drawn by `godot --headless --path . -s res://tools/ui/valley_life_icons.gd`; Greg's flies and fly box by `tools/ui/fishing_icons.gd`. The hole and rapids pictures come from `tools/shots/area_shot.tscn`.

## Search and rescue from Camp 4

Camp 4 climbers have helped with park rescues since the 1970s, and the rescue site is still in the campground. Here it's one more way to spend a day, using what the game has already taught you: reading the ground, climbing, carrying, and knowing the trails. Everyone gets found. Nobody dies.

- **Joining.** Once you can belay (*The Rock Climbing Section*), Ranger Hodges sends you to **Jo Tolliver** (an invented character, like Wren and Greg), who keeps the radio at the Camp 4 rescue site (*The Rescue Site*). Jo's first quest, *First Call*, is your first rescue: a nine-year-old chased a deer off the Cook's Meadow boardwalk.
- **Calls.** After that, some mornings the radio calls (about half of them): talk to Jo and the call is yours, until 4 PM. Calls come by season and weather, and the ones on a climb only once you've ticked that route and only when the rock is dry. There are eight: the boy in Cook's Meadow, a hiker overdue on the Four Mile Trail, a turned ankle at Mirror Lake, a soaked camper at Happy Isles (winter and spring), a snowshoer going in circles in El Capitan Meadow (winter), and parties stuck on Swan Slab, the Glacier Point Apron and Royal Arches. A call you haven't finished by **9 PM** goes to the night team, who find everyone by headlamp; you just don't get the credit. The call underway is a card in the Quests tab, and on the rescue site's sign.
- **Tracking.** A search starts where the person was last seen. Their boot prints lead off across the ground, toe first the way they went, but you can only read them close around you, so you follow them print by print. They're dark in dust and mud and blue-grey in snow.
- **Food and carrying.** Some people need something to eat before they can move: share food worth 6 to 10 energy from your pack. Others need carrying: they ride on your back and you walk at 60% speed until you hand them over to Jo, across areas and on the shuttle if you like.
- **Lowering.** On a climbing call, walk to the route's start and climb it on the climbing screen to reach the stuck party (a fall leaves the call open to try again, and a rescue climb keeps you at the foot, not the top). Then you **lower** them, on a screen painted like the climbing screen: the route's own granite for the hour with the valley beyond, you braced at the anchor feeding rope through the brake, and them sitting in their harness on the rope as the view follows them down past the flakes to the ground, the speed and brake gauges standing at the right. Hold use to let the rope run through the brake, let go to brake. Three flakes stick out of the face: ease them past each one slowly or they bump into it and you have to stop. Run the rope fast for too long and the brake gets hot and locks until it cools. A lower always reaches the ground; it's just smoother or bumpier, and Esc hands the rope to the team.
- **After.** Jo logs each rescue and gives you trail mix and a little friendship. The next morning a thank-you note from the person you helped is pinned on the Camp 4 bulletin board, with a small gift tucked behind it. The Journal keeps a **Rescue log** of everyone you've helped, rescues go on the day's page, and five rescues teach you the **Long Carry** perk (you walk faster while carrying someone).

The calls, their text and the rules are `scripts/story/rescues.gd` (autoload `Rescues`); the prints, the person and the rider on your back are `scripts/story/rescue_field.gd` and `rescue_subject.gd`; the lower is `scripts/climb/rescue_lower.gd`. The people you rescue are invented visitors, not historical figures.

![Jo Tolliver at the Camp 4 rescue site](docs/rescue_site.png)
![Following the boy's prints through Cook's Meadow](docs/rescue_prints.png)
![Carrying him back to Camp 4](docs/rescue_carry.png)
![Lowering a stuck scrambler off Swan Slab](docs/rescue_lower.png)

`SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/rescue_shot.tscn` takes these.

## The map of Yosemite

The park map is built from real data: elevation comes from the USGS 3D Elevation Program, and rivers, roads, trails, meadows, buildings, and place names come from OpenStreetMap. The places you walk are hand-made, laid out like the real ones, and trees change with elevation: oaks and gray pine at El Portal, ponderosa and incense cedar in the Valley, red fir at Glacier Point, lodgepole in Tuolumne, and giant sequoias in the Mariposa Grove.

The game has five **hubs**, each its own map:

| Hub | Elevation | Reached by |
|---|---|---|
| **Yosemite Valley** (main hub) | 4,000 ft | Start. Your camp is the Lamon Homestead, through the gate by Curry Village. The Valley is many small hand-made areas joined by trail scenes (see below). |
| **El Portal** | 2,000 ft | El Portal Road (Hwy 140), 30 min. Or walk Northside Drive west to the Big Oak Flat Road junction and keep straight on (15 min from there). |
| **Wawona** | 4,000 ft | Wawona Road (Hwy 41), 1 hr |
| **Glacier Point** | 7,214 ft | Glacier Point Road, 1 hr. Locked until the player climbs the Glacier Point Apron. Road open about May to November. |
| **Tuolumne Meadows** | 8,600 ft | Big Oak Flat and Tioga roads, 1.5 hr. Locked until you climb the Nose for Warren Harding. Road open about June to November. Or turn right at the Big Oak Flat Road junction, up Highway 120 to Crane Flat (20 min), and take the Tioga Road east from there (70 min). |

To travel, use a map kiosk at a parking area or walk off the edge of a hub on a road. Pick a destination on the park map. A few roads drive straight on without the map, where the way you turn is the choice: at the Big Oak Flat Road junction straight on is El Portal, and the Tioga Road out of Crane Flat goes to Tuolumne (`RegionExit.drive_to`, with the minutes and miles left from there; its closures and locks hold as on the map). A road some way to the next scene, like Big Oak Flat Road up to Crane Flat, moves the clock on by its `minutes`. Drive times come from the real road distances and match the park's published estimates. Travel advances the clock, and you can't set out if you'd arrive after 1 AM. Press **M** anywhere to see the park map, or press **Tab** for a detailed map of the area you're in. Interpretive signs mark real landmarks; interact to read them. If you pass out away from home, a ranger drives you back to camp.

Road closures are in `Park.SEASONAL` (`scripts/autoload/park.gd`). Hub locks come from `starts_locked` on each hub's `.tres` in `data/park/hubs/`. Call `Park.unlock_hub("glacier_point")` to open one.

**Moving the player from code** (for example at the end of a climb): `get_tree().call_group("world", "go_to_region", "glacier_point", "apron_top")`. Every hub has an `arrival` spot. There are more in each region's `Markers` (or a generated map's `Map/Spawns`), such as `apron_trailhead` in Curry Village, `camp_4` in Yosemite Village and `the_nose` in El Capitan Meadow.

**Adding things to a hub:** open `scenes/regions/<hub>.tscn`. Put NPCs and objects in **Entities**, and named Marker2D spots in **Markers**, which take priority over generated spawns with the same name. Don't edit inside the **Map** child. It's generated and gets overwritten.

**Regenerating the maps** (after changing a hub's bounds, scale, or content):

```bash
godot --headless --path . res://tools/mapgen/mapgen.tscn -- art park regions
```

- Hub bounds, scale, and walkable elevation band are in `data/park/hubs/*.tres`.
- Signs, place names, kiosks, spawn points, and where roads lead are in `tools/mapgen/hub_content.gd`.
- **Land patches** (`"land_patches"` in `hub_content.gd`, applied by `tools/mapgen/land_patches.gd`) correct the land cover by hand in lon/lat polygons: `clear` drops the OpenStreetMap buildings there and plants dense forest, `unpave` also takes up the roads, lots and walks there that don't lead through (or to a spawn, shuttle stop, kiosk or door), `slabs` paints the cliff as smooth granite slabs with walkable slab at its foot, and `talus` lays a band of talus along the cliff foot. The Valley's entry (the foot of the Glacier Point Apron) is kept for reference only: the Valley is hand-made now and mapgen skips it, and the Apron's foot is part of Curry Village. Mapgen applies them; to apply them to a generated map already in the project without regenerating it (which needs the downloads and undoes hand edits), run `tools/mapgen/patch_land.sh <hub>` on the committed map (Pillow and numpy; about five minutes). It patches the scene, repaints the ground and pastes just the patched part into the 32px picture.
- After an `art park` run, `python3 tools/mapgen/pixel_map.py` turns the park map's smooth relief into pixel art (a small palette of shade ramps with ordered dithering; nothing moves).
- Downloads are cached in `tools/mapgen/cache/`, which is git-ignored. The first run needs an internet connection.
- To add a new area, such as a summit for a climb, add a `HubData` (use `road_access = false` for climb-only areas) and an entry in `hub_content.gd`, then regenerate.

**The Valley map** is the map the player navigates. Pressing **M** anywhere in the Valley (including the Village and the homestead) opens an illustrated, Stardew-style picture of the whole Valley, seen from the south with the real terrain height. Arrow keys move between the 23 labeled places and show a note about each; **Tab** switches to the park map. Kiosks and road exits still open the park map first, for driving. Valley shuttle stops open this map too: choose a stop and press **E** to ride there (free, 15 minutes). Markers show map kiosks, climbs you have the gear for (gold) or not yet (gray), and you.

The picture, `assets/map/areas/yosemite_valley.png`, and its data, `yosemite_valley_view.json` (labels, kiosks, route starts, and the projection) plus `yosemite_valley_relief.png` (ground height, so `ParkMap` can place the player on the picture), are made by a Node script from the cached elevation and OpenStreetMap data:

```bash
cd tools/mapgen/oblique && node gen.js   # needs node and ImageMagick (magick)
```

Labels and their hand-placed positions are in `tools/mapgen/oblique/points.js`. The `art` step of mapgen skips any hub that has a `<hub>_view.json`, so it never overwrites this picture. A hub without one keeps the flat relief map.

### Yosemite Village: the Valley's central hub

Driving to Yosemite Valley brings you to **Yosemite Village**, a walking-scale central hub. It fits the real layout of the Valley between Camp 4 and the Village into one map, from the granite north wall down to the Merced River. Distances are squeezed, but what sits next to what follows the real Valley:

- **Camp 4**: the climbers' walk-in campground, laid out as real sites under the pines. Each has its tents, a Park Service picnic table, a bear box and a steel fire ring, and they sit around a shared fire where you cook. The tents span the camp's history: 1950s canvas wall tents, a 1970s climber's tarp shelter, and modern domes. **Columbia Boulder** stands at the back by the talus, with **Midnight Lightning** (Ron Kauk, 1978) chalked up its overhanging face, the lightning bolt beside the start and a crash pad below. The **rescue site** is in the middle of camp, with Jo Tolliver and her radio (see Search and rescue from Camp 4). There's also a slackline between two pines (slacklining started here in the early 1980s), and its sign opens a minigame with three lines to walk: keep your balance with Left/Right, meet the bucks the line warns you of, build flow by staying steady, and press E for tricks when you're centered. Each crossing wins a bronze, silver or gold medal by score, the first walk of the Camp 4 Line wins the six-pack of King Cobra on the far stump, walking it opens the windy Long Line, and five crossings earn the *Slackliner's Feet* perk. Win gold on any of the three and Wren Alvarez (her side story *Gold on the Line*) gives you her own slackline, which you can rig between two sturdy trees anywhere in the park: walk up to a trunk with another tree a few strides off to one side and choose "Rig your slackline"; the bulletin board where the walk-in path arrives, the Park Service sign, the two gear traders, and a 1970s van in the lot. After dark the fires burn and throw sparks, and lanterns glow in the tents and on the cook tables.
- **Yosemite Valley Lodge**, south of Northside Drive and west of Yosemite Creek, with a path down to **Swinging Bridge**.
- **Lower Yosemite Fall** and **Yosemite Creek**, crossed by a footbridge and the Northside Drive bridge. The fall trail runs from Northside Drive up the east bank to the foot of the fall.
- **The Village mall**: a pedestrian mall with, west to east along its north side, the **Welcome Center** (the shuttle stop and a flag out front), the **Yosemite Museum** (a granite ground story under dark timber), **Best's Studio** (now the Ansel Adams Gallery), the **Wilderness Center**, and the **Post Office**. At the east end, **Degnan's** (a steep chalet roof and a patio of umbrella tables) and the long log **Village Store** with its porch face a plaza shaded by oaks, with the store's parking lot beside it.
- **The Indian Village** behind the museum: umachas (bark homes), a chuckah (acorn granary), and a grinding rock you can use. Its text has been through tribal review.
- **Yosemite Cemetery** across the mall from the museum: a fenced plot of granite and wooden headstones, and Galen Clark's grave among the giant sequoias he planted round it.
- **Cook's Meadow** between the creek and Sentinel Drive, its boardwalk starting across the road from the Welcome Center and running on to **Sentinel Bridge** (with the Half Dome view). **Camp 6**, the Village's day-use lot, is east of Sentinel Drive; drivers arrive there.
- **Yosemite Chapel** (1879) on Southside Drive, across the Merced, with its bell tower and lancet windows lit at dusk.

Roads out of the hub lead onto the trail scenes to its neighbors (see *The Valley floor* below). Rebuild the hub with `tools/hubs/rebuild_village.sh`: it runs the 16px builder (`res://tools/hubs/build_hubs.tscn`), upgrades every picture it drew to the 32px art (`tools/art32/upgrade.py --fresh`), moves the scene onto the 32px grid (`tools/art32/migrate_built.py`), and puts back the hand-edited shop data. That rewrites the hub scene, so put NPCs in `scenes/story/content/yosemite_village.tscn` and place them by marker name. The layout is in `tools/hubs/build_yosemite_village.gd`. The village is drawn in the Ahwahnee's style (see below): granite-footed timber buildings with mossy shingle roofs and lit windows at dusk (`tools/hubs/valley_art.gd`), Camp 4's boulders, tents, fire rings and camp gear (`camp4_art.gd`), the granite wall of the Valley with Lower Yosemite Fall animated down it (`valley_land_art.gd`), and the painted ground, trees, plants and boulders shared with the hotel grounds.

### Curry Village: your first stop

Leave the Lamon Homestead by its gate and you walk out of the old apple orchard into **Curry Village**, a hand-made hub at the foot of the wall below Glacier Point. Nothing here is to scale: the few hundred real tent cabins become about fifty, in the real order, with the wall behind, the cabins below it, the Camp Curry buildings in the middle, and Stoneman Meadow and the Merced in front.

- **Tent cabins** in three winding rows, each with a wooden deck, a numbered plate and its own dressing (a chair, a cooler, boots, a lantern), plus a block of wood cabins. The cabins nearest the wall are roped off, with a sign about the rockfalls.
- **The village green**: the Registration Office, the Pavilion, the **Camp Curry Store**, the **Mountain Shop**, a pizza deck, the pool (an ice rink in winter), the Camp Curry amphitheater with the Firefall board, a fire pit you can cook at, patio tables, planters, string lights, and a flagpole.
- **The Camp Curry Store** and **Mountain Shop** have insides you walk into. The store clerk trades food that keeps (pilot bread, cheddar, apricots, jerky, chocolate, trail mix, and a can of King Cobra) for forage that doesn't. The Mountain Shop clerk trades quickdraws, cams, and big-wall gear for food. Like the Camp 4 traders, the shop only rounds out a rack: every offer needs gear you already own, so the piece that opens a tier still comes from a quest. Offers are in `data/shops/curry_store.tres` and `curry_mountain_shop.tres`.
- **The way in and out**: the Camp Curry arch and parking lot with a map kiosk and a shuttle stop, roads west (to Housekeeping Camp and the Village) and east (to Upper Pines and Happy Isles), the Glacier Point Apron climb at the trailhead, the homestead gate, and the **Ledge Trail**.
- **The Ledge Trail**, at the head of the path west of the closed cabins, is the historic trail (built in 1872, closed for decades because of rockfall) straight up the gully beside the Apron to Glacier Point: three hours, arriving beside the Mountain House footings. Its trailhead is there from the start, but it opens only once Glacier Point is unlocked by climbing the Apron, so it never skips that climb (`needs_hub` on `RegionDoor`). Before that, reading it tells you why.
- **People**: Jennie Curry, a camper, the Pavilion cook, a ranger-naturalist and a tourist outside; a shopper in the store and a climber in the Mountain Shop. Wren Alvarez waits with a rope at the foot of **Firefall Slab**, beside the Apron trail, and a pair of lost rental shoes lies out front of the upper tent cabins. Greg the fishing guide is all over the camp (and his lost fly box is on the Merced bank below Stoneman Meadow). The overlays are `scenes/story/content/curry_village.tscn`, `curry_store.tscn` and `curry_mountain_shop.tscn`.
- **After dark** lamps, windows, tents and the fire pit glow (`scripts/world/night_light.gd`), chimneys smoke in the cold months, mist rises at the foot of Staircase Falls, and fireflies come out over the meadow (`scripts/world/ambient_fx.gd`).

Rebuild it with `godot --headless --path . res://tools/hubs/build_curry.tscn`. That redraws every sprite (`tools/hubs/curry_art.gd`, `interior_art.gd`, on `pixel_kit.gd`), paints the whole ground as one picture (`tools/hubs/ground_art.gd`), and rewrites `curry_village.tscn`, `curry_store.tscn` and `curry_mountain_shop.tscn`. The layout is in `tools/hubs/build_curry_village.gd`. To look at a region the way the player sees it, run `SHOT_REGION=curry_village SHOT_SPAWNS=arrival,plaza godot --path . res://tools/shots/region_shot.tscn` (it needs a window). `SHOT_HOUR=21` shoots at night. In-game pictures are in `docs/curry_village_plaza.png`, `curry_village_cabins_dusk.png` and `curry_mountain_shop.png`, and every sprite is laid out in `docs/curry_art_preview.png` (`tools/hubs/preview_art.gd`).

### The Valley floor: one scene for each place, and trails between

Every place in the Valley is in one scene only. There is no big Valley overworld: the areas are joined by short trail scenes you walk through, like the Stoneman Meadow trail. Leave a scene by its west edge and you come in at the east edge of the next, so a road keeps its heading. The wall of the Valley is always at the top of a scene, as in Curry Village, whichever side of the Valley it really stands on, so El Capitan Bridge, which crosses the Merced between El Capitan Meadow and Bridalveil Fall, is at the bottom of both. The bridge itself is in El Capitan Meadow only, and you walk over it off the bottom edge; in Bridalveil Fall the road down to it ends at the river's bank, so there is one bridge and you cross it once. It goes one way, north to south: Bridalveil Fall has no exit back over it, so from there you go on by Southside Drive.

```
[drive: Tuolumne] - Crane Flat
                         |  (Big Oak Flat Road, Hwy 120, 20 min)
[drive: El Portal] - Big Oak Flat Road Junction
                                |
[drive: Wawona] - Tunnel View   El Capitan Meadow
                     |          :      |
              Bridalveil Fall ..:   Leidig Meadow
                     |   (El Capitan Bridge)   |
              Four Mile Trailhead - Yosemite Village - Ahwahnee Meadow - The Ahwahnee
                                         |                                  |
                                Housekeeping Camp - Curry Village - Homestead (Stoneman Meadow trail)
                                                          |
                                Upper Pines - Happy Isles - Tenaya Creek - Mirror Lake
                                                 |  (Mist Trail, 3 hr)
                                     Little Yosemite Valley
                                                 |  (Half Dome Trail, 1.5 hr)
                                     Half Dome: Sub Dome, the cables, the summit
```

- **El Capitan Meadow**: El Capitan over its meadow, with the Nose at the toe of the buttress and the Nutcracker on Manure Pile Buttress; Warren Harding and Beverly Johnson; a shuttle stop. Northside Drive west leaves the Valley, down to the Big Oak Flat Road junction; El Capitan Bridge, at the east end, crosses the Merced to Bridalveil Fall.
- **Big Oak Flat Road Junction**: a fork in the road below the Valley, in the Merced's canyon. Straight on, El Portal Road (Highway 140) drives on down the river to El Portal; turn right and Big Oak Flat Road (Highway 120) climbs up a ravine in the canyon wall to Crane Flat. Signs at the fork, on Big Oak Flat Road (the 1874 wagon road and the 1940 tunnels) and on the All-Year Highway; a turnout; the Merced for fishing.
- **Crane Flat**: a meadow in the fir forest at about 6,200 feet, where Big Oak Flat Road meets the Tioga Road. Back down Big Oak Flat Road to the junction; the Tioga Road east drives on to Tuolumne Meadows, locked until the Nose and shut in winter as on the map; Big Oak Flat Road west leaves the park for Groveland. Out here, past the edge of the illustrated Valley map, **M** opens the park map instead.
- **Tunnel View**: the overlook at the Wawona Tunnel, with El Capitan, Half Dome far up the Valley, and Cathedral Rocks with Bridalveil Fall across the view: the title painting itself, seen through the drop (see the overlook views under Glacier Point); the lot and its map kiosk; Separate Reality above the road. The tunnel leaves for Wawona and Glacier Point Road.
- **Happy Isles**: the Merced splitting round its islands under footbridges; the John Muir Trail sign; the Mist Trail up to Glacier Point (open once you've climbed the Apron, and shut for snow in winter; the Panorama Trail comes down here); the Mist Trail past Vernal and Nevada Falls to Little Yosemite Valley (open from the start, shut for snow in winter); Snake Dike; George Anderson; a shuttle stop.
- **Little Yosemite Valley** and **Half Dome**: the backcountry. See *The first night out and Half Dome* below.
- **Mirror Lake**: the lake filling in under the wall, Tenaya, Astroman on Washington Column, a shuttle stop.
- **Trails**: Leidig Meadow (Northside Drive under the Three Brothers), Four Mile Trailhead (Southside Drive under Sentinel Rock and Sentinel Fall, with the Four Mile Trail up to Glacier Point, open like the Ledge Trail once you've climbed the Apron and shut for snow in winter, and the Steck-Salathe), Bridalveil Fall (the fall blowing down Cathedral Rocks, and the Higher Cathedral Spire), Ahwahnee Meadow (its black oaks drop acorns; Maria Lebrado), Housekeeping Camp (its canvas-roofed cabins on the Merced), Upper Pines (campsites with tents, tables and bear boxes), and Tenaya Creek.

#### The first night out and Half Dome

Above Nevada Fall the Merced runs slow and sandy through **Little Yosemite Valley**, under the back of Half Dome and Liberty Cap: a fir forest with a backcountry camp (a tent site, a fire ring to cook at, the bear-storage sign) three hours up the Mist Trail from Happy Isles. The Half Dome Trail goes on from its north-east corner, an hour and a half up through the forest to **Half Dome**, which is one tall scene: the forest and the granite steps of Sub Dome at the bottom, the saddle where the cables start, the steep back of the Dome (darker rock, streaked down the fall line; no one walks on it), the summit, big and nearly flat, and the lip of the northwest face along the top with nothing beyond it but haze. **The Diving Board** juts out from the shoulder west of the saddle.

- **Sleeping out.** Ranger Hodges's side story *The First Night Out* (after her patrol) asks you to pack two days' food, then hands you a **wilderness permit** (a story item) and lends you a **bear canister** (gear). With the permit your tent is pitched at the camp (`BackcountryCamp`), and sleeping in it ends the day there instead of at home: you wake up in Little Yosemite Valley and the game saves there (`World.sleep(passed_out, camp_spawn)`). Overnight the canister holds the best 12 things you carry to eat; anything that doesn't fit stays in your pack, and a bear eats about half of it (`Backcountry.night_out`). Without a canister the whole pack is fair game. Passing out on the trail still gets you walked down and driven home by a ranger. The way down the Mist Trail is open all year, so a camper is never shut in by the first snow.
- **The cables.** Two steel cables on posts, 400 feet up the back of the Dome (`HalfDomeCables`, a `RegionDoor` between the saddle and the summit). Going up is a minigame (`CablesMinigame`): ten pulls from board to board, each a stop on a timing meter like a cast or a crux. A perfect pull gets you your breath back, a good one costs a little grip, a miss skates your boots on the polished rock and costs a lot; run out of grip and you back down to the foot. At first light you have the cables to yourself and the green is wide; on a late-spring or summer middle of the day there's a line of hikers on them and the green is narrow and quick (`CablesMinigame.crowd_for`). They need the permit and dry rock, and they're down from mid-October to late May (`Park.SEASONAL["half_dome_cables"]`): the posts are pulled and the cables lie flat. Coming down is a walk, open all year.
- **The summit.** The first time you walk out onto it, by the cables or off the top of **Snake Dike** (which now tops out here, `RouteData.destination_region`, instead of being walked off), the view down the Valley plays: Glacier Point across the gulf, North Dome below, El Capitan far off at the end (`SummitMoment`, `Backcountry.SUMMIT_VIEW`).
- **The Diving Board.** Look out from it at the Dome's face. Between 3 and 5 in the afternoon the light is on it, and the view turns into Ansel Adams's photograph (`DivingBoard`).
- **Quests.** *The First Night Out* (Clare Hodges), then *Anderson's Cables* (George Anderson: go up the cables that follow his eyebolts) and *The Diving Board* (Ansel Adams, after *Monolith*: see the face in the afternoon light). Each first (a night out with your food in the canister, the summit, the cables, the light from the Diving Board) is a QuestLog unlock, in `scripts/story/backcountry.gd`. Tested in `tests/half_dome_test.tscn`.

![The foot of the cables, from the saddle](docs/half_dome_cables.png)
![The first time on top: the view down the Valley](docs/half_dome_summit.png)
![The backcountry camp in Little Yosemite Valley at dusk (no permit yet, so a ring of stones where the tent goes)](docs/little_yosemite_camp.png)

The two areas are built like the other trail scenes, by `_little_yosemite_valley` and `_half_dome` in `tools/hubs/build_valley_floor.gd` (`ONLY=little_yosemite_valley,half_dome tools/hubs/rebuild_valley_floor.sh`, then `git checkout` the shared tree PNGs it redraws); their grounds are painted by `tools/art32/ground32/paint.py` (Half Dome's `"steep"` and `"drop"` settings shade the steep rock and paint the drop off the face), and the cables, the summit view and the Diving Board are in `scenes/story/content/half_dome.tscn`. The icons for the canister and the permit are drawn by `tools/ui/backcountry_icons.gd`.

Rebuild them all with `tools/hubs/rebuild_valley_floor.sh` (it runs `res://tools/hubs/build_valley_floor.tscn`, then moves the art and scenes onto the 32px grid; its Python steps need Pillow and numpy). The layout is in `tools/hubs/build_valley_floor.gd`; walls and falls come from `valley_land_art.gd` (its `seed_offset` gives each wall its own rock) and go to `assets/sprites/valley/`. People and climbs are in `scenes/story/content/<region>.tscn`. The old generated Valley map is gone: mapgen skips the Valley (`"hand_made"` in `hub_content.gd`), a save made on it picks up in Yosemite Village (`World.RETIRED_REGIONS`), and the Valley hub's main scene is its arrival area (`HubData.scene_path()`). To look at a scene whole: `SHOT_REGION=el_capitan_meadow SHOT_OUT=/tmp/elcap.png godot --path . res://tools/shots/ahwahnee_overview.tscn`, or part of one with `tools/shots/area_shot.tscn` (`SHOT_RECTS="name:x,y,w,h"`).

### The Ahwahnee look: one style for every Valley area

The Ahwahnee's art is the reference for the whole Valley: ramp-shaded, ordered-dithered pixel art lit from the upper left, warm highlights over cool shadows, granite and stained timber, moss on the shingles, a dark rim round every sprite, and a ground painted as one picture from the terrain grid. Every hand-made Valley area now uses it, through one shared base (`tools/hubs/ahwahnee_style.gd`, which holds the tree, plant and rock scattering and the ground painting):

| Area | Rebuild with | What is drawn in the Ahwahnee style |
|---|---|---|
| Lamon Homestead | `res://tools/hubs/build_homestead.tscn` | painted ground, a tree line and boulders round the edge, meadow flowers; the five oaks show all four seasons (`tree_oak_seasons.png`) and still drop acorns |
| Curry Village | `res://tools/hubs/build_curry.tscn` | painted ground with a mown green, Registration, Pavilion, Store, Mountain Shop, Pizza Deck, amphitheater, entrance arch, tent and wood cabins (`curry_ahwahnee_art.gd`), the granite wall with Staircase Falls, trees and plants, wrought-iron lamps |
| Camp Curry Store and Mountain Shop (insides) | `build_curry.tscn` | stained plank floors, window frames and wrought lanterns (`interior_ahwahnee_art.gd`) |
| Yosemite Village and Camp 4 | `tools/hubs/rebuild_village.sh` | the Village Store, Welcome Center, Museum, Best's Studio, Wilderness Center, Post Office, Degnan's, Lodge and Chapel, porches and flags, the cemetery's headstones and sequoias, the Indian Village shapes, Camp 4 (Columbia Boulder, tents, fire rings, tables, board, sign, slackline, van), the wall and Lower Yosemite Fall, trees, plants, lamps |
| The Ahwahnee and Stoneman Meadow | `res://tools/hubs/build_ahwahnee.tscn` | the original |

![Yosemite Village](docs/yosemite_village_ahwahnee_style.png)
![The Village mall](docs/yosemite_village_mall.png)
![Degnan's and the Village Store at dusk](docs/yosemite_village_dusk.png)
![Curry Village](docs/curry_village_ahwahnee_style.png)
![Lamon Homestead](docs/lamon_homestead_ahwahnee_style.png)
![Camp 4 and Columbia Boulder](docs/camp4_columbia_boulder.png)
![Camp 4 after dark](docs/camp4_night.png)

Rebuilding rewrites each area's scene, so story NPCs stay in `scenes/story/content/`. To look at the village art on its own: `godot --headless --path . -s res://tools/hubs/preview_valley_art.gd` writes `docs/valley_art_preview.png`, and `preview_camp4_art.gd` writes `docs/camp4_art_preview.png`.


### Glacier Point: the overlook

Top out the Apron (or drive up Glacier Point Road once it's open) and you're on **Glacier Point**, a hand-made hub laid out like the real one and squeezed so it can be walked. To the north and east the map drops away 3,200 feet to a painting of the view: across the canyon Half Dome, the Valley's north wall with Yosemite Falls, Royal Arches and North Dome, the forest and meadows of the floor far below with the Merced winding through, and from Washburn Point, Mount Broderick and Liberty Cap with Nevada, Vernal and Illilouette falls, all shimmering.

- **The overlook** on its granite point, railed in with a granite parapet and pipe railing, with coin viewers, signs for Half Dome and the Firefall, and **Overhanging Rock** jutting off its west side (closed, so you look at it from behind the rail). Its view frames Half Dome's face across the canyon. The Apron climb tops out here.
- **The walk** south from the point past the **Geology Hut** (1924) on its knob, the footings of the **Glacier Point Hotel** and McCauley's **Mountain House** (both burned in 1969), and the stone **amphitheater**, to the plaza with the **snack stand**, the restrooms and picnic tables, and the parking lot with its map kiosk at the end of Glacier Point Road.
- **Washburn Point**, a railed pullout on the east rim where the road comes in, framing Nevada Fall under Liberty Cap, Vernal Fall below it and Illilouette Fall to the right.
- **Sentinel Dome**, a bare granite dome to the southwest, with the fallen Jeffrey pine Ansel Adams photographed still lying on its summit, and its trailhead pullout on the road.
- **Trails**: the **Four Mile Trail** west along the north rim (crossing Sentinel Creek above Sentinel Fall) down to the Valley, the **Panorama Trail** off the east rim down to Happy Isles, the **Ledge Trail** from beside the hotel site down to Curry Village (two hours), and the **Pohono Trail** to Sentinel Dome and on toward Taft Point. The trails down are always open from the top, so a climber who tops out before the road opens can walk home.
- **The overlook views.** Past the rim is a painting of the view, not a map of the floor below: `tools/hubs/glacier_vista_art.gd` paints it (`assets/sprites/glacier/vista.png`, drawn larger than the screen), and `assets/shaders/vista.gdshader` shows it wherever the drop is (`GlacierArt.view_below` draws the drop: the lit lip, the cliff's shadow, and a marker color the shader paints over). The painting hangs nearly still as you walk, sliding a quarter as far as the camera, so the tip of the point frames Half Dome, the Four Mile Trail looks across at Yosemite Falls, and Washburn Point frames the falls. Tunnel View uses the same shader with the title painting. The builders set it up with `AhwahneeStyle._vista`.
- **The viewers.** The three coin-operated viewers on the railing can be looked through (`scripts/objects/scenic_viewer.gd`, which opens `scripts/ui/binocular_view.gd`). The whole view from the point is painted as one panorama, about three screens wide, by the climbing screen's sky and skyline painters for the hour and the day's weather: Sentinel Rock and El Capitan down the Valley to the west, Yosemite Falls and Yosemite Point, the Royal Arches with North Dome and Basket Dome over them and Mount Hoffmann behind, Washington Column, Mount Watkins, Clouds Rest and Half Dome up Tenaya Canyon, Liberty Cap and Mount Broderick, the snowy crest with Mounts Florence, Maclure and Lyell, Vernal and Nevada falls, Mount Clark, Mount Starr King and Illilouette Fall to the southeast, and Curry Village and the Merced 3,200 feet straight down. You see it through two round lenses (`assets/shaders/binoculars.gdshader`: a dithered vignette, a cool coated rim, a glint, and a focus pull as it opens and when you zoom). Pan along the skyline, tilt down to the floor (the lip of the point comes into view at the bottom as you lean over), and switch between 8x and 16x. Every landmark stands at its true bearing from the railing, on a compass tape that runs across the top. Hold one in the crosshairs and the viewer names it: corner brackets close in round it, and the brass plaque below gives its name, its height (or a fall's drop), how far off it is and its bearing, and a line about it (Yosemite Falls has its own line in the fall, when it runs dry). Everything you name stays named, marked on the skyline from then on, with a tally of the 25 at the side (`Park.spotted_peaks`, saved). The sun and moon stand where they really would (sunrise behind the Clark Range, sunset down the Valley), the falls shimmer, ravens ride the updraft, and on a stormy day the far peaks go into cloud. Each viewer starts pointed its own way: Yosemite Falls from the west side of the point, Half Dome from the tip, the falls of the Merced from the east. `SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/binocular_shot.tscn` photographs it at a few bearings and hours.
- **The rim forest**: red fir and Jeffrey pine with lodgepole and silver snags on a floor of needle duff, Jeffrey pines in the granite, and manzanita and huckleberry oak on the rocky rims. The granite is drawn as smooth slabs peeling in sheets.

Rebuild it with `tools/hubs/rebuild_glacier_point.sh` (its Python steps need Pillow and numpy; set `PYTHON=` to pick an interpreter). It runs the 16px builder (`res://tools/hubs/build_glacier_point.tscn`), upgrades the pictures it drew to the 32px art and moves the scene onto the 32px grid, like the Village's. The layout is in `tools/hubs/build_glacier_point.gd`, and the art (the buildings, the railing, the rim trees, and the view over the edge) is in `tools/hubs/glacier_art.gd`, written to `assets/sprites/glacier/`. The painting of the view goes through the 32px upgrade like the title painting (Scale2x, then the palette with a light dither). Story NPCs go in `scenes/story/content/glacier_point.tscn`, placed by marker name. The map generator skips Glacier Point now (`"hand_made"` in `tools/mapgen/hub_content.gd`).

![Glacier Point overlook, with Half Dome across the canyon](docs/glacier_point_overlook.png)
![Washburn Point: Half Dome from the south, over the Merced's canyon](docs/glacier_point_washburn.png)
![Glacier Point, the whole map](docs/glacier_point_overview.png)
![Through a viewer: Half Dome named, with Clouds Rest behind it](docs/glacier_point_binoculars.png)
![Through a viewer, tilted down: Curry Village 3,200 feet below](docs/glacier_point_binoculars_floor.png)

### El Portal, Wawona and Tuolumne Meadows

The hubs down the roads out of the Valley are hand-made too, in the same Ahwahnee look, laid out like the real places and squeezed so they can be walked. Both are reached by driving (the park map); their roads out open it again.

**El Portal** (`tools/hubs/build_el_portal.gd`) lies along the Merced River canyon, 2,000 feet below the Valley, with the canyon's north wall at the top as in the Valley scenes:

- **The town**: the El Portal Market with its gas pumps and lot (the arrival and the map kiosk), the post office and its flag, and the park's staff houses on Rancheria Flat and along the road.
- **The railroad yard** across Highway 140, where the Yosemite Valley Railroad ended (1907-1945): a stretch of track with a caboose standing on it, the freight platform where Degnan's flour waits, the site of the Hotel Del Portal, and the rusted Model A whose axle Salathé wants.
- **The Yosemite View Lodge** on the river at the west end, and the road west out of the park.
- **The river**: the Merced over granite boulders, with gravel bars and a swimming beach east of town.
- **Arch Rock**: the road turns up the canyon past the Arch Rock entrance station and the park sign and threads between the two leaning boulders of Arch Rock, where the road on to the Valley opens the park map.
- **Foothill woodland**: gold grass under blue oaks, interior live oaks, gray pines and buckeyes; chaparral (chamise, toyon, whiteleaf manzanita) with redbud on the slopes; white alders and willows on the river.

**Wawona** (`tools/hubs/build_wawona.gd`), north at the top:

- **The Wawona Road** comes down from the Valley and crosses the South Fork of the Merced on its bridge.
- **The Wawona Store** (the arrival and the map kiosk) and, over the **Wawona Covered Bridge** (drawn cut away so you can see yourself walk through it), the **Yosemite History Center**: a homestead cabin, the Wells Fargo office, an artist's studio, the blacksmith's shop and the jail round a dirt yard, with a Concord stagecoach at the hitching rail.
- **The Wawona Hotel** across the river: the white main building (1879) with its two tiers of verandas, on the site of Galen Clark's station, with its lawn, fountain and benches, Clark Cottage, Washburn Cottage, and Thomas Hill's Studio, under black oaks.
- **Wawona Meadow** across the road, with the golf course's fairways and flags, split-rail fence, and the meadow loop trail.
- **The Mariposa Grove** down the road: the welcome plaza with its shuttle and kiosk, then the trail up through the giant sequoias past the Fallen Monarch, the Bachelor and Three Graces, the Grizzly Giant (where the sequoia cone lies) and the California Tunnel Tree (you can walk through it) to the grove museum cabin.
- **Mixed conifer forest**: ponderosa and sugar pine, incense cedar, white fir and black oak, with dogwood, and willows and alders along the river.

**Tuolumne Meadows** (`tools/hubs/build_tuolumne.gd`), north at the top, at 8,600 feet:

- **The meadow**, one of the largest in the Sierra, painted as a sedge meadow in midsummer rather than a lawn: fine upright blades over low hummocks, an olive green with tawny drifts on the drier rises, a few shooting stars, lupine, buttercups and yampah, and now and then a Belding's ground squirrel burrow. The wet patches are darker, with low willows, corn lilies and small pools of snowmelt, and glacial erratics lie in the grass.
- **The river**: the Tuolumne meanders west through the meadow and the Dana Fork comes in from the east. The water is clear snowmelt: granite cobbles show through the shallows, it runs teal and then deep blue, darkest in the pools, and current lines drift downstream across it while sun glints twinkle (the ground shader's `flow`, switched on by the region's `water_flow` metadata). The river cuts its banks in the sod, so the north banks show a face of dark earth and the south banks hang over the water; the inside of each bend is a bar of cobbles and gravel. The meadow trail crosses on the plank footbridge, and the spur to the Lembert Dome lot on a road bridge with granite parapets.
- **The domes**: Lembert Dome over its parking lot, a roche moutonnée: the glacier rode over it from the east, smoothing the long, gentle slope into polished slabs that catch the sun, and plucked the west end into the steep face under the summit. Its granite peels in sheets that follow the surface. The trail to Dog Lake goes up behind it, and Pothole Dome sits at the meadow's west end.
- **The lodgepole forest** all around the meadow. Murray lodgepoles, drawn as they grow here: ruler-straight, slender trunks of thin orange-grey bark, bare low down but for dead twig stubs, under narrow, ragged crowns of short limbs tipped with yellow-green needle clumps, in four forms (an old tree, a mature one, a young one with limbs nearly to the ground, and a tall, thin one from a crowded stand). The floor is pale granite sand (grus) in grey and buff grains, with soft drifts of rusty needle duff, cones, grey twigs and quartz grit, and grass and sedge reaching in under the trees near the meadow. Whitebark pines, several pale stems swept up from one base with their needles bunched at the tips, grow on the granite.
- **Soda Springs** in its log enclosure, **Parsons Memorial Lodge** of local granite and the **McCauley Cabin**, on the rise north of the river, reached by the old road from the Lembert lot or the footbridge across the meadow.
- **Along the Tioga Road**, asphalt with a double yellow line and white edge lines: the visitor center (the arrival and its kiosk) and the Cathedral Lakes trailhead (John Muir), the store and grill under a canvas roof, the campground's loops, and the canvas cabins and dining tent of the **Tuolumne Meadows Lodge**, where the Lyell Canyon trail (the Lyell Glacier climb) starts. The road west opens the park map; east, it goes over Tioga Pass.
- **South of the road**: Fairview Dome, and **Cathedral Peak** at the end of its trail, where the Cathedral Peak climb starts at the foot of the rock. The peak is a steep pyramid of jointed granite faceted into flat faces, lit on the west and shaded on the east, with its summit spire, Eichorn Pinnacle off the west shoulder, the towers of the east ridge, vertical cracks and ledges, late snow in the shaded gullies, and a cone of fallen blocks at its foot.
- The domes and the peak are solid (CLIFF tiles under their pictures).

The ground is painted by `tools/hubs/tuolumne_ground.gd`, which extends the Ahwahnee ground painter with the high country's own meadow, forest floor, river, banks, bars and road. Every color it uses is one of the palette's, and none of its textures is a one-pixel checker, which the 32px pass's Scale2x would turn into little diamond glyphs.

Rebuild them with `tools/hubs/rebuild_el_portal.sh`, `tools/hubs/rebuild_wawona.sh` and `tools/hubs/rebuild_tuolumne.sh` (Pillow and numpy; set `PYTHON=` to pick an interpreter), which work like Glacier Point's. All three builders extend `tools/hubs/build_outer_hub.gd`, which borrows the Valley floor builder's helpers. The buildings, props, domes and peak are in `tools/hubs/el_portal_art.gd`, `tools/hubs/wawona_art.gd` and `tools/hubs/tuolumne_art.gd` (written to `assets/sprites/el_portal/`, `assets/sprites/wawona/` and `assets/sprites/tuolumne/`). The new trees and shrubs (live oak, blue oak, gray pine, buckeye, redbud, white alder, chamise, toyon, sugar pine, the mature giant sequoias, the Grizzly Giant, the Tunnel Tree and the Fallen Monarch, the four lodgepoles and the whitebark pine, and the meadow willows) are in `tools/hubs/foothill_flora_art.gd`, written beside the Valley's trees in `assets/sprites/ahwahnee/`, so any builder can scatter them. The deciduous ones follow the seasons through `SeasonalDressing`: the blue oaks and alders go gold and then bare, the buckeye blooms in spring, browns by summer and stands bare with its seeds hanging, and the redbud blooms magenta in spring. Oaks join the `black_oak` group, so the ground under them counts as oak woodland for foraging and the press book. Story NPCs, items and climbs go in `scenes/story/content/el_portal.tscn`, `wawona.tscn` and `tuolumne_meadows.tscn`. The map generator skips all three hubs now (`"hand_made"` in `tools/mapgen/hub_content.gd`).

![El Portal: the market, the post office and the railroad yard](docs/el_portal_town.png)
![Arch Rock and its entrance station](docs/el_portal_arch_rock.png)
![The Wawona Hotel and its lawn](docs/wawona_hotel.png)
![The Wawona Store, the covered bridge and the History Center](docs/wawona_history_center.png)
![The Mariposa Grove](docs/wawona_grove.png)
![Tuolumne Meadows: Soda Springs and Parsons Lodge above the river](docs/tuolumne_soda_springs.png)
![Lembert Dome and Dog Lake](docs/tuolumne_lembert_dome.png)
![Cathedral Peak at the end of its trail](docs/tuolumne_cathedral_peak.png)
![The campground and the lodge](docs/tuolumne_lodge.png)
![The Tuolumne over its cobble bed, the footbridge, and the sod banks](docs/tuolumne_river.png)
![The Tioga Road at the visitor center, under the lodgepoles](docs/tuolumne_tioga_road.png)

### Graphics pipeline for the generated hubs, UI and people

The generated hubs (El Portal, Wawona, Tuolumne Meadows and Glacier Point, before they were built by hand) and the Valley map used to show flat tile ground and simple placeholder trees and huts. They now share the Ahwahnee look:

- **Painted ground.** `tools/mapgen/ground_upgrade.gd` reads each map's terrain tiles and hillshade, paints one detailed picture with `tools/hubs/ahwahnee_ground.gd` (golden foothill grass, chaparral, red-fir needles, granite grit, shaded slopes, rivers with foam, road edges), and adds it to the map scene as `GroundArt`. The tile layer stays underneath, hidden, for collision and foraging. Run `godot --headless --path . res://tools/mapgen/upgrade_hubs.tscn -- paint`, then `godot --headless --path . --import`, then `... upgrade_hubs.tscn -- attach`. Re-run it after regenerating a map. The pictures are in `assets/map/ground/`.
- **Flora atlas.** `tools/mapgen/flora_hd.gd` draws every tree, shrub, boulder, tent and cabin in `assets/sprites/flora.png` (and their lit windows in `flora_glow.png`) with the Ahwahnee ramps and dithering, in the same 32x48 frames, so no scene changed. Run `godot --headless --path . res://tools/mapgen/paint_flora.tscn` (it also writes the info sign, trailhead and map kiosk, and `docs/generated_flora_preview.png`).
- **Buildings.** A hub cell is 35 to 45 m, so a cabin on every OpenStreetMap footprint cell made dense overlapping grids. The map generator now leaves building cells out of the Flora layer, and `tools/mapgen/hub_buildings.gd` adds one building to each footprint under `Map/Buildings`: a wide lodge for a run of big-building cells, the long white Wawona Hotel with its verandas beside the hotel marker, and otherwise one cabin, house, tent cabin or cottage to every 3 x 2 cells, never overlapping. Each is a y-sorted sprite with its own collision (`Footprints`), dark glass by day and lit windows that glow after dark (`flora_glow.png`, `assets/sprites/hub_buildings/`). To redo the maps already in the project without regenerating anything: `godot --headless --path . res://tools/mapgen/rebuild_buildings.tscn -- paint`, then `godot --headless --path . --import`, then `... rebuild_buildings.tscn -- place` (a map that already has `Buildings` is skipped).
- **Valley scenes.** The Village, Camp 4, Curry Village, the homestead and the Stoneman trail got finer ground: trampled-duff campground, a gravel lot with worn lanes, curbs and contact shadows where plazas meet grass, and the Indian Village grinding rock now has its bedrock-mortar sprite. After changing `ahwahnee_ground.gd`, run `godot --headless --path . res://tools/hubs/repaint_ground.tscn` (repaints the pictures without rebuilding scenes).
- **Shop interiors and hotel grounds.** The Store and Mountain Shop rooms get a lamp-lit vignette, a ceiling-beam shadow, woven lozenge rugs with fringe, and lit furniture (`interior_ahwahnee_art.gd`; redraw with `res://tools/hubs/repaint_interiors.tscn`). The hotel grounds' lawn has wide mown swaths with clover and drier patches, and its road gets shoulders (`repaint_ground.tscn -- the_ahwahnee`).
- **Climbing and the Valley map.** Every climbing wall gets a final grade pass (`ClimbRock._finish`: contrast, warm lights and cool shadows, shade turning toward the corner). The Valley map picture is color-graded with `python3 tools/mapgen/oblique/grade.py` (run it once after `gen.js`), and its labels have drop shadows and lit edges.
- **Camp 4 and the Indian Village.** Umachas have overlapping bark courses with shadows, a sooted smoke hole, a lintel and a woven door mat; the chuckah has a basket-weave body, cord bands and layered thatch; the bear boxes are riveted steel with a latch and worn paint. Redraw with `res://tools/hubs/repaint_village_art.tscn`.
- **Village buildings and Curry cabins.** Every Valley village building gets window flower boxes and a wall lantern; the tent cabins have stained, worn canvas, sag creases, patches and stovepipes. Redraw with `repaint_village_art.tscn`.
- **Curry Village buildings and wood cabins.** The Registration Office, Store, Mountain Shop, Pavilion and Pizza Deck have roof lichen and moss, rain streaks under the eaves, moss at the footing, porch lanterns and hanging flower baskets. The wood cabins gain a stone chimney, a firewood stack, a log step and a lantern.
- **UI.** Panels are a nine-slice timber frame with a brass line (`tools/ui/ui_art.gd` writes `assets/ui/panel.png`), and the whole UI uses the Noto Sans font at size 10, set in `assets/ui/theme.tres`. `tools/shots/ui_shot.tscn` saves screenshots of the HUD, the journal's three tabs, the pause menu with its Settings and Controls pages, a conversation and a choice, and the maps (`SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/ui_shot.tscn`). The HUD is only the clock, the place name, and a hint line naming the J, Q and B keys, which fades a few seconds after you arrive somewhere or close a menu; your next main-story step is on the Quests tab and the pause menu. Conversations type out at the chosen text speed with a blinking "[E] Next"; menu choices are marked with "> " as well as gold, so they read without the color.
- **People.** `tools/npcgen/npcgen.gd` now lights each figure from the upper left, tints the outline from the color it touches, and bakes in a ground shadow. The player is drawn by the same script (`Looks.PLAYER`).

#### The polish pass

A later pass brought every generator closer to Stardew Valley's finish: hue-shifted color ramps (cool shadows, warm lights), texture in small clusters instead of per-pixel speckle, and outlines tinted from the color they touch.

- **Ground** (`ahwahnee_ground.gd`). Roads, paving and rivers follow a signed distance field built at tile resolution, so their edges curve instead of stepping along tiles while one-tile roads and streams keep their width. Water deepens from teal shallows to blue, with a thin foam line and clustered ripples and glints. Grass, dirt, snow and rock are painted in four discrete tones with checkered transitions, with grass tufts and small flower drifts. The plaza stones are staggered slabs of varied size.
- **Trees, buildings and props.** The generated hubs' trees are built from round leaf clumps and drooping conifer tiers, and their cabins are larger with shingles, foundations and woodpiles (`flora_hd.gd`). The lodges have log walls and the Wawona Hotel has railed verandas (`hub_building_art.gd`). The Valley buildings have log walls and arched doors (`valley_art.gd`). Curry Village has shingle roofs, carved signs and dome umbrellas, and its two shops have stocked shelves, wainscoting and patterned rugs (`curry_ahwahnee_art.gd`, `interior_ahwahnee_art.gd`). The Valley's rocks, wildflowers and conifers are redrawn, and the oaks are unchanged (`ahwahnee_flora_art.gd`). The granite walls and waterfalls are clearer and brighter (`ahwahnee_land_art.gd`, `valley_land_art.gd`).
- **Light** (`world.tscn`'s day gradient, `night_light.gd`, `weather.gd`, `ambient_fx.gd`). Dawn is a cool gold, late afternoon a warm gold, dusk a soft rose, and night a readable deep blue. Lamps throw soft warm pools. Fireflies come out on summer nights only, and summer afternoons have faint light motes.
- **UI and maps.** Panels are a beveled wooden frame with brass studs and a drop shadow. A speaker's name sits on a tab above the dialogue box, a bobbing arrow marks "Next", and a highlight bar marks the chosen menu row (`ui_art.gd` writes `panel.png`, `plaque.png`, `tag.png`, `select.png` and `next.png`). The map screens have a wooden frame, parchment labels, a bobbing "you are here" pin, and outlined icons, and they redraw only when something changes (`park_map.gd`).
- **Climbing** (`scripts/climb/art/`). Skies have more bands and shaded clouds, distant walls haze toward blue, figures have colored outlines, and holds have a lit top and a dark underside.

#### The native 32px finish: ground, water, cars, walls and light

Every hand-made outdoor area except Tuolumne Meadows then gets a finish painted for the 32px game rather than doubled from 16px art (Tuolumne keeps its own ground, cars and running river):

- **Ground** (`tools/art32/ground32/`). The ground picture is painted again from the terrain grid in the scene's `Ground` layer, so walking, collision and foraging are unchanged. It is painted on art pixels of 2x2 (the grain of every sprite standing on it), in flat clusters of tone with the texture in small hand-shaped motifs, then rounded off with Scale2x as the sprites were: Valley meadow as tufts of blades with seed heads and a few lupine, yarrow, buttercups and shooting stars; ponderosa and cedar needle duff with cones and twigs, lying under the crowns of the trees that stand there (`shadows.canopy_field`) with grass in the openings; mown lawn in stripes with clover; oak litter and grass cured gold in the foothills; red fir duff, cones and granite grit at Glacier Point; chaparral soil with manzanita leaves; talus as a field of lit blocks on grey grit; granite slabs peeling in sheets, with cracks and lichen; and grass leaning over every edge it meets. Roads are traced rather than blurred from the tiles (`roads.py`): the road tiles are thinned to one middle line, driveways and pull-outs are cut off it (they stay as plain asphalt aprons into their lots), and each road is painted at one steady width, one or two tiles, round that smoothed line, so stair-stepped roads run as clean curves, roads carry on across their bridges and trail crossings, and a road that ends at a lot meets it square. Each road gets one unbroken double yellow line down its middle that runs straight through a T, stops at the edge of the road it runs into and a tile short of a dead end, worn white fog lines broken where a driveway, lot or bridge opens off it, patched repairs and gravel shoulders; lots are striped round the cars parked in them, with oil stains; walks and plazas are concrete poured in slabs with saw-cut joints and granite curbs; the Ahwahnee keeps its cut stone, gravel entrance circle and cobble curb. The Merced deepens from a cobbled bed in the shallows to emerald pools, with current streaks, glints, a broken foam line and dark wet banks; creeks run paler and the lake stiller. Footbridges with no sprite of their own are plank decks with rails, road bridges get granite parapets, and the Cook's Meadow boardwalk is boards. Under every tree, building, rock, car and bench there is a shadow, cast down and to the right, on the ground's own color ramps (`shadows.py`). Rebuild after a hub builder has repainted its ground:

  ```bash
  godot --headless --path . res://tools/art32/ground32/dump.tscn -- /tmp/ground32   # terrain grids and sprite placements
  python3 tools/art32/ground32/paint.py /tmp/ground32 [region ids]               # repaints assets/sprites/ahwahnee/ground_*.png
  godot --headless --path . --import
  ```

  `paint.py --out DIR` writes somewhere else to look first, and `tools/art32/ground32/shots.sh DUMP OUT region:marker ...` lays each area's sprites over a screen-sized crop of the new ground round a marker (`BEFORE=1` also over the old), without starting the game. Per-area choices (the homestead's orchard, El Portal's oak woodland, Curry Village's green, the Ahwahnee's circle and beds) are in `REGIONS` at the top of `paint.py`; the ramps are in `ramps.py`.
- **Moving water.** `assets/shaders/seasonal_ground.gdshader` (already on every area's ground) drifts bands of brighter ripples along the painted water and winks glints on and off; `SeasonalDressing.STILL_WATER` lists the areas that don't get it (Tuolumne Meadows, whose river runs by its own `water_flow`). The fall and winter grades now recognize the Merced's teal and leave it alone.
- **Light.** `scripts/world/atmosphere.gd` lays an outdoor grade over the picture (`assets/shaders/atmosphere.gdshader`): cool shadows, warm lights, a gentle S-curve and soft corners, read pixel for pixel so the art stays crisp. It's off indoors and in Tuolumne Meadows. On top of it, the light follows the sun:
  - **The sun and moon.** `Sun` (`scripts/world/sun.gd`) works out sunrise and sunset for the date (the valley's real year: sunset after 8 PM in July, around 5 PM in January, sliding smoothly between seasons, and landing on Horsetail Fall's firefall in late winter), the sun's height (72 degrees at a summer noon, 32 in winter) and direction (east to south to west), and the moon's phase. `DayNight` stretches its gradient over those times, so winter evenings get dark early, and full-moon nights are brighter and more silver than moonless ones.
  - **The grade by hour.** Golden hour warms and richens the colour; alpenglow turns bare granite and snow pink for the half hour after sunset (it finds them by their colour with the day's tint taken back out); at night what the lamps don't reach goes silver-blue while lamplight keeps its warmth; summer heat and fall smoke put a haze in the afternoon air.
  - **Cast shadows.** `SunShadows` (`scripts/world/sun_shadows.gd`, one per outdoor region, under its Entities) lays every upright sprite (trees, plants, rocks, signs, buildings, people) flat along the ground away from the sun: long to the west in the morning, short and to the north at midday, long to the east in the evening, longer in winter, faint ones from the full moon, none under thick cloud. Casters are found by their art standing on the node's origin, so nothing has to be added to a scene. It's a CanvasGroup, so overlapping shadows don't double up.
  - **Lamps and fires.** `LampLights` (`scripts/world/lamp_lights.gd`) gives a `NightLight` to every painted street lamp, camp lantern and fire ring that didn't have one (its `LIGHTS` table says where the flame sits), and every `NightLight` now has a soft halo round the lamp head. The player carries a dim `Lantern` after dark outdoors, so a moonless meadow is dark but never black.
  - **Mist and light shafts.** `ValleyAir` (`scripts/world/valley_air.gd` with `assets/shaders/valley_air.gdshader`) lays banks of mist over the ground in the hour round sunrise on most spring and fall mornings (thickest on the meadows and by water, and after a wet day) and burns it off as the sun climbs; in the first and last hour of sun, soft shafts of light slant through the air, brightest through the mist. Like the cloud shadows it works in world pixels, in flat steps.

  ![Morning mist, the sun's shadows through the day, alpenglow: before and after](docs/lighting_day.png)
  ![A full-moon night, the Village's street lamps, a late-winter dusk at Glacier Point: before and after](docs/lighting_night.png)
- **Cars.** `python3 tools/art32/cars32.py` paints the twelve parked cars into `assets/sprites/cars/`: a sedan, a station wagon with a roof box, a pickup with a cooler and a duffel in the bed, a hatchback with a bike on the roof and a two-tone camper van, seen from above and behind (hood, windshield, roof sheen, rear window, tail lights, plate, bumper, tyres) in the muted paints of a real lot. `sheet OUT.png` lays them side by side (`docs/cars32.png`).
- **Granite walls.** `python3 tools/art32/rock32.py FILE...` cleans the Valley's cliff walls (`assets/sprites/valley/*_wall.png`, the Royal Arches, the Village's and Curry Village's walls): speckle in the granite gives way to the tone around it, so the rock gathers into planes of light and shade, while cracks, outlines, ledge pines and falls stay as drawn. The walls are now painted from the real terrain instead (`walls32/paint.py`, below), so this is only for a wall a builder has redrawn and that isn't repainted.

![Yosemite Village: before and after](docs/ground32_yosemite_village.png)
![El Portal: before and after](docs/ground32_el_portal.png)
![Wawona: before and after](docs/ground32_wawona.png)
![Glacier Point: before and after](docs/ground32_glacier_point.png)
![Roads: before and after (Yosemite Village, Glacier Point, El Capitan Bridge, Wawona)](docs/roads_before_after.png)

#### The real park: trees, cliffs, vistas and skylines

The trees, the cliffs and every distant view are then painted as the real things, from the real terrain:

- **Trees** (`tools/art32/trees32/`). Every tree is its own species, painted natively at 32px: ponderosa pines in three ages (one an orange-barked old "yellow belly", one a young "blackjack"), Jeffrey pines, sugar pines with their long cones hanging from the tips of level limbs, lodgepoles in four forms, gray pines forked and see-through, white and red firs in whorled tiers, incense cedars, giant sequoias (the Grizzly Giant with its great elbow limb and dead top, the Tunnel Tree, the Fallen Monarch), snags, and the broadleaf trees from a branching skeleton: black, blue and live oaks, alders with catkins, dogwoods with white bracts, redbud, buckeye in its candles, willow thickets, apple trees. Each sprite keeps its canvas and anchor; the deciduous ones have a picture for each season that `SeasonalDressing` swaps in. `python3 tools/art32/trees32/paint.py` (`--list`, `--out DIR`, or names).
- **Cliff walls** (`tools/art32/walls32/paint.py`). Each region's wall is a perspective rendering of the USGS 3D Elevation Program's lidar heights (two metres a sample) for the cliff that really stands there, seen from its foot: El Capitan with the Nose and the North America Wall's diorite, the Three Brothers, Sentinel Rock, Cathedral Rocks and Bridalveil, the Royal Arches and Washington Column, the Glacier Point Apron, Mirror Lake's walls, the Merced's foothill canyon at El Portal. The light comes from each pixel's real surface facing; over it go water streaks below the rim's notches, tan staining, fresh scars, cracks, exfoliation, forest on the benches and talus. Each picture keeps its size and the scene's cliff line (so collision is unchanged), with its falls lined up under the animated ones.
- **Vistas** (`tools/art32/walls32/vista.py`). Glacier Point's backdrop and the title screen's Tunnel View are rendered from the terrain with OpenStreetMap's land cover (forest, meadow, scree, bare rock, water) placing each tree and talus slope; the falls' shimmers are placed where the map has them, and Horsetail Fall is painted dry.
- **Tuolumne's domes** (`tools/art32/walls32/masses.py`). Lembert, Pothole and Fairview domes and Cathedral Peak, each from where people see it, with lodgepoles planted one by one where the map has woods and their outlines covering the granite tiles the scene was built with.
- **Skylines** (`tools/art32/walls32/skylines.py`). The landmarks the climbing screen, the Glacier Point binoculars, the slackline and the story scenes paint past the wall's edge get their real silhouettes, as seen from where the game looks at them (Half Dome from down the Valley, El Capitan from the Cathedral Spires, Tuolumne's needles from Cathedral Peak; the binoculars from Glacier Point itself), with their true proportions drawn a little taller, the light on each face, the sheer walls that carry streaks, and where their falls and features stand. It writes `scripts/climb/art/landmark_shapes.gd`, which `ClimbLandscape` reads.

The heights come from The National Map's 3DEP elevation service and the map from the OpenStreetMap API, fetched once and cached in `tools/art32/walls32/cache/` (git-ignored; a couple of gigabytes). `dem.py`, `osm.py` and `elevation.py` hold the fetching, the land-cover rasterizer and the ray-marched views. Rebuild:

```bash
python3 tools/art32/trees32/paint.py                                              # the trees
godot --headless --path . res://tools/art32/ground32/dump.tscn -- /tmp/ground32   # terrain grids and falls
python3 tools/art32/walls32/paint.py /tmp/ground32 [region ids]                  # the cliff walls
python3 tools/art32/walls32/vista.py                                              # Glacier Point and Tunnel View
python3 tools/art32/walls32/masses.py /tmp/ground32                               # Tuolumne's domes
python3 tools/art32/walls32/skylines.py                                           # the landmarks' skylines
godot --headless --path . --import
```

`paint.py`, `vista.py` and `masses.py` take `--out DIR` to write somewhere else first; `paint.py --preview DIR` shows a wall's bare render with its anchors marked; `skylines.py --preview DIR` draws every silhouette at its size in the climbing screen, and `--views DIR` renders the terrain round each landmark with its own rock tinted.

To rebuild everything after changing a generator, run these in order: `ui_art.tscn`, `npcgen.gd`, `gear_icons.gd`, `paint_flora.tscn`, `rebuild_buildings.tscn -- paint`, `--import`, `build_ahwahnee.tscn`, `build_seasonal_art.gd`, `build_homestead.tscn`, `build_curry.tscn`, `build_hubs.tscn`, `rebuild_glacier_point.sh`, `rebuild_el_portal.sh`, `rebuild_wawona.sh`, `rebuild_tuolumne.sh`, `rebuild_interiors.sh`, `repaint_village_art.tscn`, `repaint_interiors.tscn`, `repaint_ground.tscn`, `rebuild_wild_dressing.sh`, `upgrade_hubs.tscn -- paint`, `--import`, `upgrade_hubs.tscn -- attach`, `--import`, then the native 32px finish above (`ground32/dump.tscn` and `paint.py`, `cars32.py`), the real park's trees, cliffs, vistas, domes and skylines (`trees32/paint.py`, `walls32/paint.py`, `vista.py`, `masses.py`, `skylines.py`) and `--import`. The hub builders also rewrite the region scenes, plus `scenes/objects/shuttle_stop.tscn` and the shop and food data in `data/`. Only the node IDs differ in the scenes, but the data can lose hand edits, such as the Camp 4 trader's offers. So keep only the art: `git restore -- scenes/ data/`.

![Pause menu](docs/ui_pause_menu.png)
![Settings](docs/ui_pause_settings.png)
![The HUD](docs/ui_hud.png)
![The Backpack](docs/ui_backpack.png)
![A choice in a conversation](docs/ui_dialogue_choice.png)

The hand-built areas follow the seasons too, without being rebuilt. When a region loads, `scripts/world/seasonal_dressing.gd` swaps its black oaks, dogwoods, garden beds, meadow grass and conifers for the season's drawing (in `assets/sprites/ahwahnee/seasons/`, made by `godot --headless --path . -s res://tools/hubs/build_seasonal_art.gd`), hides lupine, paintbrush and wildflowers in winter and dries them in fall, and grades the painted ground with `assets/shaders/seasonal_ground.gdshader`: dry and golden in fall, cool and frosted in winter. Only sprites change, so collision and foraging stay the same.

**Seasons you can see.** Beyond the trees and the light, the land itself changes through the year, all worked out from the calendar and each day's weather (`scripts/world/seasons.gd`), so nothing is saved and no scene is rebuilt:

- **Snow that lies.** Each snowy winter day adds to the snow on the ground and it settles back between storms, so early winter is patchy and late winter is white; once it has snowed, patches stay all winter, and it melts in the first days of spring (`Seasons.snow_cover()`). The ground shader lays it in drifts with blue shadowed edges, leaving the ploughed asphalt, its painted lines and the open water dark, and a second little shader (`assets/shaders/snow_cap.gdshader`) caps the tops of roofs, cars, rocks, logs, benches and signs, thicker as it deepens (`SeasonalDressing` picks which sprites can hold snow). Walk through it and you leave boot prints that stay for the day, until fresh snow fills them in (`footfall.gd`).
- **Waterfalls that follow the snowmelt.** The falls rise through spring to a roar at the end of May, thin all summer, and stand dry through most of fall until the November storms; the small ones off the rim (Sentinel, Staircase, Royal Arch Cascade) dry up by late July, Yosemite Falls by September, and Bridalveil never quite stops (`Seasons.waterfall_flow()`). `scripts/world/seasonal_falls.gd` thins each fall's drawing to its own middle (`assets/shaders/waterfall_flow.gdshader`), turns a dry one into a still dark stain, and scales its mist, spray and roar. The water they feed dries too: Yosemite Creek's bed below the Lower Fall turns to cobbles, and Mirror Lake shrinks from its shore to the sand and sedge meadow it becomes each late summer (the ground shader's `dry_rect`; you can't fish where it's dry).
- **Horsetail Fall's firefall.** In winter a thin ribbon of snowmelt runs down El Capitan's east shoulder. On clear evenings in the second half of winter (February), from 5:20 to 5:50 PM, the setting sun lights it orange and red from top to bottom (`GameClock.is_horsetail_time()`, `scripts/world/horsetail_fall.gd`, placed by the El Capitan Meadow overlay). The El Capitan sign tells you when to look.

![Winter in the Village parking lot, late in the season](docs/seasons_snow_village.png)
![Lower Yosemite Fall in late spring and dry in fall](docs/seasons_falls.png)
![Mirror Lake shrinking in late summer and a meadow in fall](docs/seasons_mirror_lake.png)
![Horsetail Fall lit at sunset in February](docs/seasons_horsetail_fall.png)

**Living water and sky.** The painted rivers, creeks and lakes move and mirror the world around them, and the night sky on the climbing screens is a real Sierra sky:

- **Reflections.** `scripts/world/water_surface.gd` (with `assets/shaders/water_surface.gdshader`) draws one view-sized rectangle just under the cloud shadows that reads the screen. The region's painted ground says where the water is, and a pixel only counts as water while the screen still shows that water, so people, boulders and anything else in front of it are left alone. Below each bank it mirrors whatever stands there (the bank, cattails, trees, rocks), pulled side to side by ripples and broken into rows, fading out a few dozen pixels from shore. Open water takes the sky's colour from `ClimbSky.palette` (blue by day, purple and gold at dusk, with sun glints in the sun's colour), dulls on overcast days, and on clear nights holds twinkling stars. It works in art pixels (2 world pixels) so it stays crisp, and is off indoors.
- **Waterfall spray and rainbows.** `SeasonalFalls` adds a `FallSpray` (`scripts/world/fall_spray.gd`) beside each fall's mist: droplets flung out of the plunge, more of them the harder the fall runs, and on a fair day a rainbow arching over the spray while the sun is behind you (Bridalveil in the late afternoon, 3 to 6:20 PM; Yosemite Falls and the cascades off the north wall in the morning). The rainbow needs at least 0.3 of the spring flow, so it's gone by late summer. It's drawn in 2px cells with dithered edges, like the Moonbow.
- **The night sky.** `NightSky` (`scripts/climb/art/night_sky.gd`) paints the Milky Way rising out of the southern ridges (clumpy star clouds, the dark Great Rift, a warm glow toward the galaxy's centre) and hundreds of stars of every brightness in four colours, thickest along the band, into the sky behind the climbing, slackline and bivy screens. On the climbing and bivy screens it also twinkles the brightest stars each frame (they flare into little crosses) and sends a shooting star across now and then. Stars fade in with the dusk (`ClimbSky.stars(pal)`).

Shoot it with `SHOT_REGION=mirror_lake SHOT_AT=1200,640 SHOT_HOURS=11,19,22.5 xvfb-run -a godot --path . res://tools/shots/water_sky_shot.tscn` (forces a clear day; `SHOT_PLAIN=1` leaves the water off, for comparing).

![Mirror Lake by day, at dusk and at night](docs/water_mirror_lake.png)
![A rainbow in Bridalveil Fall's spray on a spring afternoon](docs/water_rainbow.png)
![The Milky Way over El Capitan from the Nose](docs/night_sky_climb.png)
![A night on the portaledge under the stars](docs/night_sky_bivy.png)

**Weather and atmosphere.** Each day's weather comes from the date (`Weather.today()` in `scripts/world/weather.gd`), so it survives a reload: most winter days it snows, now and then a spring or fall day rains, and the rest are fair. Outdoors, `Weather` drifts a few dozen hand-simulated pixels through the air in world space (they wrap round the camera, so you walk through the snow rather than dragging it along): snowflakes at three depths, slanted rain, tumbling apple-blossom petals in spring, cottonwood fluff on summer days and blinking fireflies on summer nights, and swinging gold and red leaves in fall. On fair days, cloud shadows slide over everything (`scripts/world/cloud_shadows.gd` with `assets/shaders/cloud_shadows.gdshader`, sampled per world pixel in two flat steps of shade so the art stays crisp); they fade at dusk and vanish when it's overcast. `day_night.gd` grades the light a touch by season (warm summer, golden fall, cool winter) and greys it on wet and snowy days. The player kicks up a little dust at each step (snow on snowy days, a splash in the rain, nothing on frozen ground) and breathes fog on cold mornings and all winter (`scripts/player/footfall.gd`). All of it is skipped indoors. Shoot it with `region_shot.tscn` and `SHOT_SEASON`, `SHOT_DAY` and `SHOT_WAIT=1`.

![Snow at the Lamon Homestead](docs/weather_winter_snow.png)

### The Ahwahnee: north from the homestead

The Lamon Homestead has a second gate, in the hedge at its north side, opening onto a trail that runs to the **Ahwahnee Hotel**. It is two hand-made regions, and nothing in them is to scale:

- **Stoneman Meadow** (`ahwahnee_trail`): a long walk north from the gate. First a mixed forest of ponderosa, incense cedar, black oak and dogwood, with ferns, bracken, mossy boulders and fallen logs. Then Stoneman Meadow itself, open and full of lupine, shooting stars, cornlily and tall grass, with a bench and an overlook on the gravel bar. The Merced runs past, broad and clear, and you cross it on **Stoneman Bridge**, a three-arch granite bridge (the real one is from 1933) with parapets you can't climb over and the arches, cutwaters and foam drawn on its south face. Willows and cattails line the far bank, and the trail climbs north to the hotel.
- **The Ahwahnee** (`the_ahwahnee`): the hotel's grounds, under the cliff. The hotel is a large, detailed sprite (448 px wide, about a screen wide): granite ground story, stained-timber upper floors, the tall Great Lounge windows, a painted Native-inspired band, shingled gables, stone chimneys, and the porte-cochère with its amber doors. Its front doors tell the hotel's story (`MainEntrance`, at `front_door`) and open into the lobby: six rooms inside (see [Inside the buildings](#inside-the-buildings)). Around it are a gravel entrance circle with a tiered fountain and a curbed lawn island, terrace urns and topiary, clipped hedges, lamp posts, a rose garden with four flower beds, an arbor, a sundial and a birdbath, a tea lawn with striped umbrellas, stone gate posts and the hotel's sign at the foot of the drive, and the meadow of its East Lawn (Ahwahnee Meadow itself is west of the hotel, its own scene on Northside Drive). Behind it stands the wall of the Valley, with the **Royal Arches** as a stack of giant curved steps in the granite, Washington Column beside them, and the **Royal Arch Cascade** (an animated, looping waterfall with mist) falling to a plunge pool. Royal Arch Creek runs from it through the woods and out the west edge, and a stone-and-gravel road leads west across Ahwahnee Meadow to the Village (the Northside Drive exit). A Valley shuttle stop stands at the foot of the entrance circle. After dark the hotel's windows and the lamp posts glow (`scripts/world/night_glow.gd`).

Spots for story overlays (`scenes/story/content/<region_id>.tscn`, placed by marker name): on the trail `south_entry`, `north_entry`, `bridge_west`, `bridge_east`, `meadow`, `river_bank`; at the hotel `south_entry`, `west_road`, `front_door`, `entrance_circle`, `rose_garden`, `tea_lawn`, `ahwahnee_meadow`, `cascade`.

Rebuild both with `godot --headless --path . res://tools/hubs/build_ahwahnee.tscn`. It redraws the sprites, paints both grounds as one picture each (`tools/hubs/ahwahnee_ground.gd`), rewrites `ahwahnee_trail.tscn` and `the_ahwahnee.tscn`, and, the first time only, opens the homestead's north gate. The art is in three modules on `pixel_kit.gd`: `ahwahnee_hotel_art.gd` (the hotel, its glow, gate posts, sign, lamp), `ahwahnee_land_art.gd` (the Royal Arches wall, cascade and mist, Stoneman Bridge), and `ahwahnee_flora_art.gd` (trees, plants, rocks, logs, and the formal garden pieces). `docs/ahwahnee_*_preview.png` show each set, and `docs/ahwahnee_grounds_overview.png` and `docs/ahwahnee_trail_overview.png` show each whole region (made by `tools/shots/ahwahnee_overview.tscn`). To look at a region the way the player sees it: `SHOT_REGION=the_ahwahnee SHOT_SPAWNS=south_entry@52:41 godot --path . res://tools/shots/ahwahnee_shot.tscn` (needs a window; `name@x:y` puts the player on that tile). The painted band on the hotel follows the real beams and has passed tribal review.

**Valley shuttle.** Green shuttle stop signs at the Village, Camp 4, the Ahwahnee, the Lamon Homestead, Curry Village, Happy Isles, Mirror Lake, and El Capitan Meadow take you to any other stop in 15 minutes. The stop list is in `scripts/objects/shuttle_stop.gd`.

**Trading.** Money is gone, so traders take food instead. The Camp Curry Store and the Mountain Shop (see Curry Village above) work the same way. A price is an amount of food energy, and they take whatever in your pack spoils soonest first. The Village Store swaps fresh forage for trail mix and dried apples, which keep much longer. The Camp 4 traders round out a rack you already have (extra cams, quickdraws, and big-wall gear once you can aid climb), but the piece that opens a new climbing tier still comes from a quest. Offers are in `data/shops/*.tres`, each with the gear it requires and a maximum you can own.

**Bridges.** When a river cuts off a walkable area on a generated hub map, the map generator builds a bridge at the shortest crossing (`MIN_CUT_OFF_AREA` and `MAX_BRIDGE` in `tools/mapgen/region_builder.gd`).

### Inside the buildings

Every main building in the park has an inside you can walk into: walk up to its front door and press the interact button ("Enter: Degnan's"). Facing the door, the door wins over the building's sign; the rest of the front still reads it. Inside are furniture, things on the walls, and signs, exhibit panels and pieces of furniture you can read, with the building's history. Walk out the front doorway and you're back on the doorstep. Shops, museums and the History Center keep hours and say when they open; the hotels and lodges never close.

| Where | Rooms |
|---|---|
| Yosemite Village | the Welcome Center (a relief model of the Valley), the Yosemite Museum (Lucy Telles's great basket and cases of baskets), Best's Studio (Virginia Best's piano), the Wilderness Center (bear canisters, the trail board), the Post Office, Degnan's (Bridget Degnan's bakery, ice cream, café tables), the Village Store, the Yosemite Valley Lodge lobby and Yosemite Chapel (pews, lancet windows, the pulpit) |
| Curry Village | the Registration Office (Mother Curry, the Firefall photographs) and the Pavilion dining hall, beside the Camp Curry Store and Mountain Shop |
| The Ahwahnee | six rooms: the Lobby, with a doorway each side into the **Great Lounge** (77 feet long, a walk-in fireplace at each end, stained glass over ten tall windows, the grand piano) and the **Dining Room** (granite piers, sugar pine trusses, the Bracebridge Dinner table), and a back door to the **Elevator Lobby** (Robert Boardman Howard's mural), whose elevator goes up to a **Guest Room** with Half Dome in the window; the Great Lounge opens onto the **Solarium** |
| Glacier Point | the Gifts & Snacks stand and the Geology Hut (a telescope on Half Dome, a model of the view) |
| El Portal | the Market, the Post Office and the Yosemite View Lodge |
| Wawona | the Wawona Hotel's lobby (its parlor piano) and dining room, Clark Cottage, Washburn Cottage, Thomas Hill's Studio, the Wawona Store, the History Center's Hodgdon cabin, Wells Fargo office (a safe, a telegraph, wanted posters), artist's studio, blacksmith's shop (a glowing forge) and jail, and the Mariposa Grove Museum |
| Tuolumne Meadows | Parsons Memorial Lodge, the McCauley Cabin, the visitor center, the store and grill under canvas, and the lodge's dining tent |

Rebuild them with `tools/hubs/rebuild_interiors.sh` (Pillow and numpy; `ONLY_ROOMS=degnans,yosemite_chapel` rewrites just those scenes). Each room is one entry in `rooms()` in `tools/hubs/build_interiors.gd`: its size, floor and walls, what hangs on them, its rugs, its furniture, what you can read, and its doors. The art is drawn by `tools/hubs/interiors_art.gd` (room shells, wall decor, and a furniture library shared by every room) in the Store and Mountain Shop's materials, then upgraded to the 32px art like the hubs'. The rooms are written to `scenes/regions/<room id>.tscn`, and the doors outside to `scenes/story/doors/<region>.tscn`: a `BuildingDoor` (`scripts/objects/building_door.gd`) on each doorstep and the spot outside it, `<room id>_door`. They are placed from where each building stands in its region's scene, so they follow a rebuilt hub; `StoryContent` adds them to the region with its story overlay. Put people for a room in `scenes/story/content/<room id>.tscn`, by marker name (`door`, and `from_lobby` and the like by the doors between rooms). To look at every room as you walk in: `SHOT_DIR=/tmp/rooms xvfb-run -a godot --path . res://tools/shots/interiors_shot.tscn`. The Ahwahnee's six rooms are then painted again natively at 32px by `tools/hubs/ahwahnee32/paint.py` (the script's last step): cut granite, board-formed concrete stained like redwood, polished plank and tile floors, the painted basket-pattern beams, tall windows onto Half Dome and the Valley with stained glass above them, fringed kilims, sunlight falling across the floor, lamp and fire light, and a shadow under every piece of furniture. Its furniture (the files with an `ahw` look in `build_interiors.gd`, so no other room shares them) is painted into the canvas the builder made, so the scenes' collisions stay right; the Great Lounge's fireplaces have a two-frame fire. `paint.py preview DIR` lays each room out with its furniture without starting the game. Every other room is painted the same way by `tools/hubs/interiors32/paint.py` (the step after it), straight from its spec in `build_interiors.gd`: board-and-batten, log, lap-sided, plaster, fieldstone, granite and tent-canvas walls; plank, flagstone, tile, carpet and packed-earth floors; sash and lancet windows onto each place's own view (the Valley, Half Dome, forest or meadow) with daylight across the floor; framed paintings, photographs, maps and menus, shelves of goods, peg rails, post-office boxes; and fire and lamp light that warms the stone round it. It also paints the Camp Curry Store and the Mountain Shop (its rope wall, El Cap topo and shoe wall) and the ~100 pieces of furniture the rooms share (`furniture.py`, `fittings.py`, `goods.py`), each in the canvas the builder made so collisions stay put. The rooms are lived in: table lamps with mica shades that throw a pool of warm light, rocking chairs with a wool blanket, coat trees, firewood boxes by the stoves and hearths, a chainsaw-carved bear; on the walls, screen-printed park posters (Half Dome at sunset, Yosemite Falls, the big trees, a high meadow, El Capitan at night), old snowshoes and Badger Pass skis, and a patchwork quilt; and in the shops and visitor centers, tables of field guides and folded park shirts, bins of plush black bears and stands of sun hats and beanies (`goods.py` and the end of `decor.py`; `python3 tools/hubs/interiors32/goods.py sheet OUT.png` lays the new pieces side by side). Rebuilding Curry Village redraws the Store and Shop at 16px, so run `python3 tools/hubs/interiors32/paint.py` after it. The Museum's text about the Valley's weavers and the Ahwahnee's basket patterns have been through tribal review.

![The Ahwahnee's Great Lounge](docs/interiors_ahwahnee_great_lounge.png)
![Degnan's](docs/interiors_degnans.png)
![Yosemite Chapel](docs/interiors_yosemite_chapel.png)
![The Wawona Hotel's lobby](docs/interiors_wawona_hotel_lobby.png)

## The climbing screen

![Firefall Slab at dawn](docs/climb_firefall_slab_dawn.png)
![The route card](docs/climb_route_card.png)
![The Great Roof](docs/climb_great_roof.png)
![Reaching the Glacier Point rim](docs/climb_glacier_point_rim.png)
![A night on El Capitan](docs/climb_night_on_the_wall.png)
![Lyell Glacier](docs/climb_lyell_glacier.png)

Each of the 14 routes is its own little game, set where the real climb is. Before you start, a **route card** shows a postcard of the view, the pitches (marked where there's a crux), the gear you need (and what you have) and how much food to bring. Then you climb: a granite wall with its ragged edge against the sky, the real skyline behind it (Half Dome from the Apron, El Capitan and Bridalveil from the Nose, the Cockscomb from Cathedral Peak, Mount Lyell from the glacier), the valley floor far below sinking as you gain height, and clouds drifting past. The light follows the game clock: pink at dawn, blue at midday, orange at dusk, stars and a headlamp at night. The whole screen has the game's 32px finish: every picture is doubled the way the rest of the art was, and each formation's granite gets its own grain at full resolution (see "Weather on the wall" and the art table below).

**Weather on the wall.** Each day's weather (`Weather.today()`) reaches the wall (`scripts/climb/wall_weather.gd`), and the route card, the sign at the foot of the route and the guidebook's tick list all give the day's forecast:

- **Wet rock.** On a rainy day it rains on the wall. The morning after, the rock stays wet until the sun has been on it for a couple of hours (each route's profile knows when its face gets the sun: Astroman's east face in the morning, the Apron in the afternoon, Sentinel's north face never, so it stays wet until 3 pm). Wet rock looks dark and streaked, drips, narrows the crux meter's green, and makes slab, dike and knob moves cost 1 more.
- **Wind.** Some days are windy up high: on the upper pitches of the long routes and on the high-country ones. The climber and the rope sway, grit blows across the face, the crux marker gusts, and the green narrows.
- **Heat.** In summer, a face in the midday sun (noon to 4 pm) is hot: every move costs 1 more. Start early or pick a shady wall.
- **High-country storms.** On most summer afternoons (and some in spring and fall) thunderheads build over Tuolumne, some time between 1:30 and 3:30. When the storm comes, thunder warns you, it rains, and every move costs more; an hour later the lightning sends you down wherever you are. The route card names the hour, so start before 10 am.

The glacier's snow still goes to slush after noon.

Your climber works up the face on a rope that runs through every quickdraw, cam or old piton to your belayer, who is the person from the story who sent you (Wren, Dick Leonard, Jules Eichorn, Royal Robbins, John Salathé, Beverly Johnson, Warren Harding, George Anderson, John Muir...). The climber shows what you own: red climbing shoes, a chalk bag, a harness with your cams (colored by size) and quickdraws, a belay device, aiders, a portaledge roll, an ice axe and crampons.

**Controls:** arrows climb (up, up-left, up-right); **Space** clips a bolt or places a cam; **E** eats at a belay ledge (not when you're full), shakes out on a jug when you're pumped, or chalks up on rock; **Shift + an arrow** aids a hard move (aiders) or jugs a fixed rope (ascenders); **Esc** asks if you want to retreat (**E** says yes, **Esc** again keeps climbing). Rings mark the holds you can reach, with what each costs after your shoes and chalk; the toolbar at the bottom is your rack, and lights up what you can do right now.

**Reading the line.** Every hold is a jug (big, cheap), an edge, or a crimp (small, costly). Crimps and cruxes **pump** your forearms, and every point of pump (the meter beside your stamina) adds 1 to every move and narrows the crux meter. A jug lets you recover a little; shaking out on one (**E**, once a hold, 3 minutes) drains most of the pump, and a stance or a belay clears it. Placing gear is cheap from a jug (-1) and strenuous off a crimp (-5), and a fall more than three moves above your last piece ends the climb. So on the harder routes the cheapest-looking hold isn't always the right one: plan a line that strings jugs between the crimps, protect from good holds, and eat at the belay for the pitch you can see ahead. The first slabs stay forgiving: on easy pitches edges don't pump you, and the hold beside every bolt is good enough to clip from.

**What each piece of gear does** (so the gear you earn in the story changes how you climb):

| Gear | In the climb |
|---|---|
| Climbing shoes | Every move costs 1 less (not on ice); wider crux windows |
| Chalk bag | Once a pitch, the next 2 moves cost 3 less; wider crux windows while chalked |
| Harness + rope | You can lead. A top rope (Swan Slab) makes falls safe |
| Quickdraws | Clip bolts on slabs, and the old 1934 pitons on the Spire and other cam routes |
| Cams | Place in cracks; fewer cams means longer runouts |
| Belay device | Your partner's catches are soft (+10 stamina after a fall), the belay restful (+6), and you rappel to retreat |
| Aiders | On a wall (the Great Roof, Changing Corners), pull through a hard move for a cam and 12 minutes; it costs you a free ascent |
| Ascenders | Jug a fixed rope (the Nose's first pitches): safe, steady, slow |
| Haul bag + portaledge | On the Nose: the bag swings below you, and the two nights on the wall (El Cap Tower's ledge, the Great Roof's hanging camp) each need a real meal, 30 energy or more. Eating at the belays leaves those meals alone, and the route card counts them ("Night meals: 4 of 2"). A night lasts until 6:30 the next morning, so the Nose ends on the third day and the calendar moves on |
| Ice axe + crampons | On the glacier: kick steps for cheap moves, and the axe stops a slide |

**Pitch styles** change the rules as well as the art: friction **slab** (Firefall Slab, Swan Slab), **crack** and **flake** (the Grack, Nutcracker, Astroman), **chimney** (Steck-Salathé's Chockstone Chimney and Narrows, Astroman's Harding Slot: alternate Left and Right), **roof** (Separate Reality, the Great Roof: the picture runs sideways), **dike** (Snake Dike: stay on the ribbon, bolts are far apart), **knobs** (Cathedral Peak), **snow** and **ice** (Lyell Glacier: crevasses, and slush after noon).

**Crux moves** ask for a short skill check: stop a marker in the green zone (Firefall Slab's bulge, Separate Reality's lip), tap Up for a mantel (Nutcracker), or alternate Left and Right to the beat (the Narrows, the King Swing, the Pendulum). Hit the middle of the green for stamina back (and a little pump off). Arrive pumped and the green is narrower. Miss the green and you're spent: you eat something from your pack right there (`E`) before you can try the move again, and with nothing to eat you come off onto the rope. Each harder climb has more crux points (the route card shows a `*` for each one on a pitch) and a faster marker, but it never crosses the green in less than a tenth of a second, and every miss makes the next try a little wider and slower. Nothing is timed against you otherwise.

**Midnight Lightning** (V8, Ron Kauk, 1978) is a boulder problem: start it from the sign by the crash pads under Columbia Boulder in Camp 4, with climbing shoes and a chalk bag. There's no rope and no gear. Chongo spots you, and every miss lands you on the pad. The holds are the same every time, laid out along the real line: polished start holds, the lightning bolt hold, the one good ledge, the swing to a fingertip hold, and the mantel over the lip almost 16 feet up. All three hard moves are crux checks, with the swing's green narrowed, and the mantel needs 13 fast taps. Miss any of them and you're off; there's no hanging on to eat. You get five tries a session. Each fall leaves you a little more tired for the next try, and a fall off the top moves takes more out of you. Grab the cheapest holds and skip the shake-out on the ledge, and you run out of arms on the mantel. Climb it on your first try for a *flash*. Once you've finished the Apron with Wren Alvarez, she dares you to try it (her side story *Midnight Lightning*).

![Midnight Lightning, with Chongo spotting](docs/climb_midnight_lightning.png)

**Style** is rated on the result card: an *onsight* (no falls), *hard-won* (falls but free), or *aided*. The Nose can be done free, as the story asks, or with aid.

Where things are:

| What | File |
|---|---|
| Rules (stamina, protection, cruxes, aid, nights, weather) | `scripts/climb/climb_state.gd` |
| Each route's place, rock, skyline, belayer, facts and pitches | `scripts/climb/climb_profiles.gd` |
| The screen (input, phases, effects) | `scripts/climb/climb_minigame.gd` |
| The day's weather on the wall and the forecast | `scripts/climb/wall_weather.gd` |
| Pictures | `scripts/climb/art/`: `climb_rock.gd` (granite, cracks, dikes, roofs, ice), `climb_landscape.gd` (the skyline), `climb_scenes.gd` and `climb_props.gd` (bases and summits), `climb_sprites.gd` (climber, belayers, hardware: jams in cracks, laybacks up flakes, a mantel onto the top), `climb_hud.gd`, `climb_ui.gd`, `climb_night.gd`, and `climb_hires.gd` (the 32px finish: Scale2x, each formation's granite grain, wet rock) |

The font is Noto Sans (SIL Open Font License, `assets/fonts/`). To photograph a route: `SHOT_ROUTE=the_nose SHOT_PITCH=6 SHOT_HOURS=7,19 godot --path . res://tools/shots/climb_shot.tscn` (needs a window; `SHOT_INTRO=1` shoots the route card, `SHOT_SPECIAL=crux|result|pause|night` the others). `tools/shots/climb_walls.tscn`, `climb_landmarks.tscn` and `climb_figures.tscn` show the rock, the skyline and the people on their own. More in [docs/CLIMBING_MINIGAME.md](docs/CLIMBING_MINIGAME.md).

## Sound

Every sound is synthesized by `tools/audio/build_sounds.gd` into `assets/audio/` (16-bit mono WAVs, each from a fixed seed), so nothing is recorded or downloaded and there's nothing to license. To change one, edit its function there and rebuild:

```bash
godot --headless --path . -s res://tools/audio/build_sounds.gd
godot --headless --path . --import
```

The `Sound` autoload (`scripts/autoload/sound.gd`) plays them on four buses (Master, Music, Effects, Ambience), each with a volume on the Settings page.

The music is composed and synthesized the same way, by `tools/audio/build_music.gd` (about a minute; `MUSIC_ONLY=music_fall` builds one piece):

```bash
godot --headless --path . -s res://tools/audio/build_music.gd
godot --headless --path . --import
```

Each piece is 16 bars in four phrases (A A' B A''). A two-bar motif is made up from the piece's seed (mostly stepwise, a leap answered by a step back, strong beats on chord tones), carried as a sequence over the next chords, answered by a new motif, and brought home to the tonic. Under it: plucked arpeggios from a Karplus-Strong string (a guitar, a harp, or bells at night), a soft pad, a bass on the downbeats, and a little room reverb. The tune is on flute in spring, a whistle in summer, clarinet in fall (Dorian), and a music box in winter (minor). The world pieces are played once with a rest of 30 to 75 seconds between them; the title theme is built as a seamless loop. The strings are tuned with an all-pass filter in the loop and decay-stretched so high notes ring as long as low ones (Jaffe and Smith), and each is plucked from a triangle shape, so every note is within 2 cents of true pitch and no note of an arpeggio drops out; the polish test measures both. Each tune sits at 0.8 to 1.0 times the level of its accompaniment, so it carries without shouting.

- **Ambience.** Four loops fade into each other: birds by day (mountain chickadees, a warbler, a far-off Steller's jay), crickets and a great horned owl at night, wind, and rain. Their mix follows the hour (crossing over at dawn and dusk), the season (fewer birds and no crickets in winter, more wind), the day's weather, and the place: indoors you hear only rain on the roof, and Glacier Point and Tuolumne are windy. Up on the climbing screen the wind rises.
- **Campfires and waterfalls.** `scripts/world/sound_emitter.gd` places a looping sound in the world that gets louder as you walk up to it. Every fire's sparks crackle, every waterfall's mist roars (Lower Yosemite Fall, Staircase Falls, Royal Arch Cascade), and on the hub maps each Place named for a fall gets one (Yosemite Falls, Bridalveil, Illilouette). Falls are loudest in spring and down to a trickle by fall. Rivers and creeks run too: a softer loop of water over cobbles at the river nearest the middle of each stretch of the Merced, the Tuolumne or Tenaya Creek, so walking the bank you're never out of earshot (`SoundEmitter.attach_rivers`).
- **Story moments** open on a sting: a slow, warm chord under a high chime (`story_sting`).
- **Footsteps.** Each step (`scripts/player/footfall.gd`) is dirt and duff, a squelch in the rain, a crunch in snow or on frozen winter ground, or boards indoors.
- **Climbing.** Moves scrape on the granite; clipping a bolt, placing a cam, chalking up, eating, aiding or jugging, falling onto the rope, a perfect crux and topping out each have their own sound (hooked into `_events()` in `climb_minigame.gd`).
- **Menus.** A soft tick to move and a wooden knock to choose, on the title screen, pause menu and conversations, and a swish as a conversation or the day's page opens.
- **Getting things and talking.** A bubbly pop for an item, a chime for new gear, a jingle for a finished quest, and the talking blip, pitched for each speaker.

## Story

The story is in [STORY.md](STORY.md), and the mechanics are in [docs/DESIGN.md](docs/DESIGN.md). Galen Clark gives you the Guardian's Register, and you fill it with the stories of real people from the park's history. Native characters and practices are flagged for review by the tribes traditionally associated with Yosemite.

Two storylines run side by side: the climbing guidebook's **tick list** and the **press book**. The ending needs both. Once the Register's last page is written and the press is full, Clark sends you to a gap in the talus under the Royal Arches, behind the Ahwahnee (`scenes/regions/guardian_cave.tscn`, built by `godot --headless --path . res://tools/hubs/build_guardian_cave.tscn`), where the mystery of the lost Guardian of Yosemite is answered (`scripts/story/guardian_mirror.gd`).

**The Guardian's Year.** After the mirror comes a second year: the Guardian's work, one arc a season, each ending in a change you can see on the map. The journal's Quests tab and the pause menu say whose work is next and when.

- **Spring, trail crew.** George Anderson at Happy Isles hands you a rock bar. Reset four washed-out granite steps at the foot of the Mist Trail: three heaves on a timing meter (pry it out, lever it over, drop it square), and a miss lets the block slip back into the rut. The new steps stay set, and the Mist Trail sign says so.
- **Summer, Cook's Meadow.** Enid Michael has you pull six invasive plants (Himalayan blackberry, bull thistle, velvet grass), each told from the native one your press book taught you, then rope off three shortcuts walkers have worn across the wet ground. The season after, the weed patches flower and the paths grow over.
- **Fall, fire in the big trees.** Galen Clark, who counted the Mariposa Grove in 1857 and never saw young sequoias come up, has you clear the fuel from round four giants by the Grizzly Giant and light a slow burn with a drip torch. The ground stays black, and the spring after, seedlings come up in the ash.
- **Winter, the bear boxes.** Ranger Hodges has four new steel lockers to set at Camp 4, Curry Village, Upper Pines and Housekeeping Camp, where the last campers of the year leave their coolers out. The boxes stay, and you can read them.
- **The year's end.** With all four done, Clark has one more talk, and your own page goes in the Register.

The work spots and what they leave behind draw themselves (`scripts/story/work_spot.gd`), placed by `Stewardship` (`scripts/story/stewardship.gd`) on each region's first visit, so no map is rebuilt. Quests ask for them with a `work` step. The rock bar's meter is `scripts/story/rock_work.gd`. The fire arc's Register note says that the people who lived here burned these woods long before the park, and that how the game tells it waits on tribal review; none of the year's lines are in a Native character's voice.

[docs/CAST.md](docs/CAST.md) lists the cast (22 historical people and 15 visitors from different eras), where each one lives, and the quest chains from the first morning to the cave. The character sprites are drawn by `tools/npcgen/`.

There are a few hidden touches in the valley (night, moon, and season events). Developers can find them in the "Easter eggs" section of [docs/DESIGN.md](docs/DESIGN.md).

## Yosemite items

Every item is a native Sierra plant or food, with a short natural-history note that shows when you find it. Energy is what it restores on a climb, and "keeps" is how many days it lasts in your pack (see `scripts/story/food_db.gd`).

**Wild forage** (spawns each morning, by season and habitat)

| Item | Season | Habitat | Energy | Keeps |
|---|---|---|---|---|
| Miner's Lettuce | Spring (a few in late winter) | under black oaks | 8 | 2 days |
| Sierra Onion | Spring (a few in summer) | meadows | 6 | 5 days |
| Wild Strawberry | Spring, Summer | meadows | 10 | 2 days |
| Blue Dicks Corm | Spring | meadows | 7 | 7 days |
| Cow Clover | Spring (a few in summer) | meadows | 5 | 1 day |
| Morel Mushroom | Spring | under black oaks | cook first | 3 days |
| Yerba Buena | Spring, Summer (a few in fall) | along the river | 2 (or brew tea) | 3 days |
| Blue Elderberries | Summer | along the river | cook first | 2 days |
| Manzanita Berries | Summer (a few in fall) | beside manzanita shrubs | 10 | 3 days |
| Sierra Plum | Summer | under black oaks | 11 | 4 days |
| Yampah | Summer, Fall | meadows | 12 | 7 days |
| Black Oak Acorn | Fall (a few left in winter) | under black oaks | leach first | 14 days, forever in a chuckah |
| Toyon Berries | Fall, Winter | beside manzanita shrubs | toast first | 5 days |
| California Blackberry | Summer | along the river | 12 | 2 days |
| Whitebark Raspberry | Summer | conifer forest | 11 | 2 days |
| Thimbleberry | Summer | conifer forest | 9 | 1 day |
| Sierra Gooseberry | Summer | beside manzanita shrubs | 7 | 4 days |
| Coyote Mint | Summer | beside manzanita shrubs | 2 (or cook it) | 3 days |
| Sierra Bilberry | Summer, Fall | high country (Tuolumne) | 10 | 3 days |
| Whitebark Pine Nut | Fall (a few in summer) | high country (Tuolumne) | 14 | 30 days |
| Chokecherry | Fall (a few in summer) | along the river | 4 (better cooked) | 3 days |
| King Bolete | Fall | conifer forest | cook first | 3 days |
| Hazelnut | Fall | conifer forest | 12 | 30 days |
| Wood Rose Hips | Fall, Winter | meadows | 5 | 12 days |
| Chanterelle | Fall, Winter | under black oaks | cook first | 3 days |
| Cattail Root | Fall, Winter | along the river | roast first | 10 days |
| Hedgehog Mushroom | Winter (a few in fall) | conifer forest | cook first | 4 days |

"A few" is an item's lean season (`lean_seasons` on its ItemData): half as many come up, but always at least one. Winter is still the hungry season, but every part of the Valley has something in it: cattail roots by the river and hedgehog mushrooms in the pines, beside the rose hips. To see what each area grows a day in each season, and what it's worth in energy, run `godot --headless --path . res://tools/forage/forage_audit.tscn`.

Forest and high-country forage only grows on the hub maps (Wawona, El Portal, Glacier Point, the Valley, Tuolumne), not around your camp. The berries, nuts, roots, mushrooms and mint are drawn by `tools/ui/wild_food_icons.gd`.

### Cooking in the pot

Every campfire has a cooking pot as well as the recipes you've learned. It works like Breath of the Wild's: put in up to five ingredients from your pack, no recipe needed, and the dish depends on what went in. Five blackberries make Simmered Berries; three kinds of berry make a Copious Berry Medley; mushrooms on their own make a Mushroom Skewer, with greens a Mushroom Sauté; leached acorn meal and berries make Berry Acorn Cakes; jerky with roots and onions makes Camp Stew; and so on (17 dishes). Raw acorns or acorn flour ruin the pot (Bitter Mush, the Dubious Food of the Sierra).

Cooking is worth the time:

- **More energy.** Every ingredient gives more cooked than raw, and each different ingredient adds 2 more. Five blackberries are 60 energy raw, 80 as Simmered Berries, and mushrooms and boletes that can't be eaten raw at all are good food in the pot.
- **It keeps.** Fresh berries spoil in a day or two; cooked they keep four or five days, Berry Acorn Cakes ten, Nut and Berry Bars two weeks.
- **One meal for the wall.** A meal worth 30 energy or more counts as a night's meal on a big wall, so a pot of forage can stand in for store food.
- **Effects.** Some ingredients carry an effect, named on the dish ("Steady Mushroom Skewer"). More of them makes it last longer (5 climbing moves each, up to 30), but two different effects in one pot cancel out:

| Effect | From | On a climb |
|---|---|---|
| Hearty | King Bolete, Pine Nuts | fills your stamina all the way and clears the pump |
| Steady | Yerba Buena, Coyote Mint (counts double) | each move pumps you 1 less |
| Keen | Sierra Bilberry, Blue Elderberries, Chocolate Bar | a wider green on the crux meter |
| Warming | Sierra Onion, Wood Rose Hips | storms and slush don't slow you, and a cold bivy without a portaledge can't chill you |
| Nimble | Thimbleberry, Sierra Gooseberry | every move costs 1 less |

When E picks what to eat at a belay, a cooked meal whose effect you don't already have going comes before plain food (night's meals are still saved for the nights), and its effect shows over the stamina bar with the moves it has left. On a cold night the bivy picks a Warming meal if you carry one. The pot shows what a dish will be only once you've cooked it; the **Cookbook** at the bottom of the Backpack tab shows every dish you've found, the best you've cooked of each, and how many are left to find.

A cooked meal is an ordinary item whose id says what it is (`meal.simmered_berries.80.none.0`), so meals stack, spoil, save and trade like anything else. The rules, ingredients and dishes are in `scripts/story/cooking.gd`, the pot's menu in `scripts/story/station.gd`, and the effects in `scripts/climb/climb_state.gd` (`boosts`).

Black oaks change color with the seasons: new pale leaves in spring, gold and rust in fall, bare in winter.

## Project layout

```
project.godot            960×540 view on a 32px tile grid (menus lay out on 480×270, see docs/ART32.md), scaled up in whole-number steps with nearest-neighbor filtering
scenes/
  ui/title_screen.tscn   main scene: the title screen (Continue, New Game, Settings, Credits, Quit)
  world/world.tscn       the game: loads one region at a time, plus player, lighting, HUD, park map
  regions/               one scene per hub, plus lamon_homestead.tscn (your camp)
  regions/generated/     generated hub terrain (don't edit; rebuilt by tools/mapgen)
  player/player.tscn     the player (CharacterBody2D + camera)
  objects/               tent (sleep), black oak, forageable pickup,
                         info sign, map kiosk (travel point), region door
  ui/hud.tscn            date/time, location, key hints, messages, sign text, fades
  story/                 NPC, cooking station, chuckah; story/content/<region>.tscn places them,
                         story/doors/<region>.tscn the doors into its buildings (generated)
  climb/                 climbing minigame and route starts
scripts/
  autoload/              global singletons, always loaded
    game_clock.gd        time, days, seasons (28 days each)
    inventory.gd         what you are carrying
    item_db.gd           registry of all items (forage + prepared food)
    save_manager.gd      JSON save/load (user://save.json)
    park.gd              hubs, routes, seasonal road closures, hub unlocks
    sound.gd             buses, volumes, one-shot sounds, and the ambience beds
  ui/title_screen.gd     the title screen; ui/credits.gd the credits and licenses
  world/sound_emitter.gd a looping sound in the world (campfires, waterfalls)
  world/forage_spawner.gd  daily wild forage, placed by season and habitat
  world/world.gd         loads regions, travel, sleep sequence
  world/region.gd        a map the player can be in (hub or smaller area)
  ui/park_map.gd         park and area map screens
  world/day_night.gd     time-of-day lighting (edit the gradient in the Inspector), graded by season and weather
  world/weather.gd       each day's weather and the snow, rain, petals, leaves and fireflies in the air
  player/player.gd       movement, facing, interaction
  story/                 quests, gear, food, chuckah, recipes, dialogue, journal, perks, the Guardian's Year (autoloads: Gear, QuestLog, FoodDB, Larder, Granary, Recipes, Perks, Stewardship)
  climb/                 climbing rules (climb_state.gd) and screen
  data/item_data.gd      ItemData resource definition (name, description, icon, forage rules)
data/items/*.tres        one file per forage item
data/food/*.tres         one file per prepared food
data/quests, characters, gear, recipes, routes   story data (see docs/DESIGN.md)
data/park/hubs/*.tres    one file per hub: name, description, location, map bounds
data/park/routes.json    generated driving routes between hubs
assets/map/              generated park map and area maps
tools/mapgen/            the map generator
tools/audio/             the sound synthesizer (writes assets/audio/)
assets/audio/            every sound in the game (generated)
assets/sprites/          placeholder pixel art, meant to be replaced (items.png holds the 16×16 item icons)
assets/tiles/            TileSet (collision + "open_ground" flag per tile, where forage can land)
tests/                   headless tests; tests/run_all.sh runs them all
export_presets.cfg       Windows, macOS and Linux export presets (see Builds)
.github/workflows/       CI: tests on every pull request, builds on demand or on a tag
```

## How to add things

**A new forage item:** draw a 16×16 icon (add it to `tools/ui/wild_food_icons.gd`), then duplicate a forage `.tres` in `data/items/` (for example `black_oak_acorn.tres`). Under **Foraging**, set its seasons, habitat, how many spawn per day, and any lean seasons when only a few turn up. Add it to `ITEMS` in `item_db.gd`, give it an energy and shelf life in `scripts/story/food_db.gd`, and, if it can go in the cooking pot, a line in `INGREDIENTS` in `scripts/story/cooking.gd` (its cooked energy, its kind, and any effect). Habitats are worked out from the map: *meadow* is any open grass, *oak woodland* is the ground just south of a black oak, *chaparral* is next to manzanita shrub tiles, and *riverside* is next to water. To add a new habitat, extend `ItemData.Habitat` and `_find_habitats()` in `forage_spawner.gd`.

**A new plant for the press book:** add it to `PLANTS` in `scripts/story/herbarium.gd` (its name, a line of natural history, its seasons, its habitat, its rarity, and the regions it grows in, each with a named spot to grow near), give it a drawing in `tools/plants/plant_art.gd` (a function named after its id), and redraw the sheet with `godot --headless --path . res://tools/plants/plant_art.tscn`, upgrade it to the 32px art with `python3 tools/art32/upgrade.py assets/sprites/plants.png` (add `--fresh` if the sheet grew a row), then `--import`. `tests/press_test.tscn` checks it has a drawing and comes up where and when you said. A quest asks for plants with a `pressed` step (see `scripts/story/quest_data.gd`).

**Editing the homestead:** open `scenes/regions/lamon_homestead.tscn`, select the **Ground** layer, and paint with the TileMap panel at the bottom. Grass tiles have the `open_ground` custom data flag, which is where forage can land. Water, boulders, and shrubs have collision. The generated hubs get their collision from the hidden **Blocker** layer instead.

**A new piece of Guardian's Year work:** add a task to `TASKS` and its spots to `SPOTS` in `scripts/story/stewardship.gd` (each spot's region, its position on open ground, and its kind), draw the kind's before and after in `scripts/story/work_spot.gd`, and ask for it from a quest with a `work` step (`{"type": "work", "task": ..., "count": ...}`). A run of work steps opens one after another without a trip back to the giver. `tests/exit_access_test.tscn` checks every spot can be walked up to, and `tests/guardian_year_test.tscn` that every task has enough spots.

**Saving a new system:** add the node to the `persist` group and give it `save_data() -> Dictionary` and `load_data(data)`. SaveManager picks it up automatically.

**Replacing the art:** overwrite the PNGs in `assets/sprites/` with the same layout. The player sheet uses 16×24 frames, with columns stand / step A / step B and rows down / up / left / right. Aseprite is the usual tool for this.

## Testing

To run everything (each test prints its own PASS/FAIL lines to a log; this prints a summary and exits non-zero if any fail):

```bash
tests/run_all.sh                       # GODOT=/path/to/godot if it isn't on the PATH
```

GitHub Actions runs the same script on every pull request and push to main (`.github/workflows/tests.yml`), with Godot 4.7 and xvfb for the climbing screen test. It takes about five minutes. The tests one by one:

```bash
godot --headless --path . res://tests/smoke_test.tscn
```

It walks, checks each season's forage and where it grows, picks things up, sleeps, saves, reloads, and checks season changes. It prints PASS/FAIL for each step and uses its own save file. Run it after big changes.

```bash
godot --headless --path . res://tests/travel_test.tscn
```

It loads every hub and checks that spawn points are walkable. It also walks through the homestead gate, drives between hubs, and checks locks, seasonal closures, the late-night cutoff, saving the current region, and passing out away from home.

```bash
godot --headless --path . res://tests/exit_access_test.tscn
```

It walks every region with the player's real body, from its arrival spot, and checks that every road and doorway out can be walked into, every trail sign, building door, shuttle stop and map kiosk can be walked up to and used, and every spot a way in lands on (a road, trail, door, shuttle, climb or drive) is connected to the rest, so no way in strands you. Then it fits the regions together like puzzle pieces: every region has a way in and a way out, and from every region you can get to every other one by its roads, trails and doors, the Valley shuttle, the park map's drives and the climbs that top out somewhere new.

```bash
godot --headless --path . res://tests/ahwahnee_test.tscn
```

It walks the way from the homestead's north gate through Stoneman Meadow, over Stoneman Bridge (parapets and river included), and up to the Ahwahnee, and checks that every spot is reachable, the hotel's front doors lead into its lobby, and the cascade and evening glow are in place.

```bash
godot --headless --path . res://tests/story_test.tscn
godot --headless --path . res://tests/world_story_test.tscn
godot --headless --path . res://tests/cast_test.tscn
godot --headless --path . res://tests/climb_access_test.tscn   # every climb can be walked to, at the foot of a wall
godot --headless --path . res://tests/climb_test.tscn   # every route, every piece of gear
xvfb-run -a godot --path . res://tests/climb_screen_test.tscn   # plays all 13 on the real screen (needs a window)
godot --headless --path . res://tests/eggs_test.tscn
godot --headless --path . res://tests/perks_test.tscn
godot --headless --path . res://tests/cooking_test.tscn   # the new forage, the cooking pot, and meal effects on a climb
godot --headless --path . res://tests/settings_test.tscn
godot --headless --path . res://tests/side_quests_test.tscn   # seasonal and time-of-day side stories
godot --headless --path . res://tests/half_dome_test.tscn     # the first night out, the cables, the summit
godot --headless --path . res://tests/title_test.tscn
godot --headless --path . res://tests/audio_test.tscn
godot --headless --path . res://tests/polish_test.tscn
godot --headless --path . res://tests/interiors_test.tscn   # every building's door, room, and way back out
godot --headless --path . res://tests/living_test.tscn   # the wild ground, emotes, the cast's days, story moments, rivers
godot --headless --path . res://tests/binocular_test.tscn   # Glacier Point's viewers: every landmark found and named
godot --headless --path . res://tests/valley_life_test.tscn   # the bulletin board, field log, fishing and festivals
godot --headless --path . res://tests/fishing_test.tscn   # the cast meter, the flies, and Greg's quest and trades
godot --headless --path . res://tests/seasons_test.tscn   # snow on the ground, the falls and Mirror Lake drying, Horsetail Fall
godot --headless --path . res://tests/lighting_test.tscn   # the seasonal sun, cast shadows, lamps, the lantern, morning mist
godot --headless --path . res://tests/rescue_test.tscn   # search and rescue: Jo, the calls, prints, carrying, the lower
```

The story test covers quests, gear, food spoilage, the chuckah, recipes, and the climbing rules. The world story test boots the real game and checks that people, climbs, and cooking spots are placed, the first quest works, and the Journal opens. The cast test checks that every quest's people, items, gear, and routes exist, that the gear curve lets you finish every quest, and that everyone stands on open ground. The eggs test checks the Easter eggs in docs/DESIGN.md (it takes about 15 seconds). The cooking test checks the summer berries and fall mushrooms, which dish each mix of ingredients makes, that cooking beats eating raw, effects and their cancelling, meals as items (names, pictures, spoiling, saving), the pot's menu, and what each effect does on the wall. The perks test earns each perk, checks its effect where it's hooked in, the HUD message and Journal section, and that perks survive a save. The settings test saves and reloads the settings (in its own file), drives the pause menu's Settings page with keys, and checks pinned button prompts, the HUD hiding under the journal, and the dialogue reveal and skip. The press test covers the press book: every plant has a drawing and grows in each region and season it should, the press quests run beside the tick list from Enid Michael's garden to the full press, the Press Book tab, and the finale (the gap in the talus stays shut until Clark sends you, the mirror, and everyone gathered in the cave). The side quests test plays the side stories that depend on the season or the hour (Clark at the Mariposa Grove, Enid Michael at dawn, Hodges in fall, Degnan in winter, Muir after dark) and checks their Register pages say what is real. The title test drives the title screen with keys (with and without a save, New Game asking first, Settings and Credits), checks the credits carry the OpenStreetMap credit and the license texts, and that a new game starts fresh without deleting the old save. The audio test checks that every sound the game plays exists, that loops repeat over their whole length, that the buses follow the volume settings, how the ambience follows the hour, season, weather and place, and that fires, waterfalls, footsteps and the climbing screen make their sounds. The polish test checks that every item has a picture, that item cards count and stack, that everyone who speaks has a portrait and a voice of their own, the quest bubbles' ! and ?, the clock's sun and sky, that the music fits the hour, season, weather and title screen, and that the day's page counts the day, is saved, and starts over each morning. The living test checks that every area outside the towns has its ground clutter, that nothing of it stands on a road, trail or lot and none of it cuts a spot off (walking each area's spots with and without it), that the flat clutter turns with the seasons, which emote each kind of line shows and that only the speaker shows it, people blinking, glancing about and waving to a friend once a day (with an arm up), that the cast's days start and end at their spot and keep them there through the middle of the day (and that none of them is a day awaiting tribal review), the evening crowd at the Camp 4 fire, that each story moment is a sighting and uses its words, queues once, waits for the player to be free, plays, closes and is saved, and that the rivers are heard along their banks. The binocular test checks that the viewers' compass runs one way and agrees with every landmark's bearing, that each of the 25 landmarks can be found in the crosshairs from the railing (none hidden behind a nearer ridge or off the end of the panorama), that naming one takes a steady hand and is kept in the save, that the screen zooms and closes, and that the three viewers on the point open it and give the player back. The valley life test checks the bulletin board's notes (only from people you know, in season, one each, taken by reading the board, handed over by talking, run out after three days, and saved), the field log (every critter has an entry, a close look logs a bird, listening by day and night, bear tracks, the Journal page and the day's page), the bears (more in fall and at dusk, hardly any in winter and none at night, mostly brown coats, a cub keeping up with its mother, logged when in sight, stopping to look and then moving off when you come close, gone once out of sight with a wait before the next, and none carried into a new area), the mule deer (about all year but not at night, more often than bears, summer and winter coats, a doe's fawns bounding off with her), fishing (every fish is in the field log and is kept or let go, the reel lands a fish you follow and loses one you don't, casting needs a rod and water in front of you, and landing a fish), and the festivals (one a season, the hours, the host's lines and reward once a year, double talk points, the calendar, the Facelift's litter, and saving). The fishing test checks the cast meter (no double taps as it opens, perfect, good and missed stops, a dropped line, a missed back cast snagging and a missed forward cast spooking, two perfect casts always bringing a fish up and setting the hook hard, the odds for good casts), the flies (gear with pictures, the best one tied on, a wider green, more rises, a harder hook set, favored fish), the water (rainbows in the rapids and never a sucker, browns and suckers in the holes, bigger fish and trophies there, a harder fight in the current, every hole cut into the bank and painted as water, the rapids on the river, and a fly landing in each fishing it), and Greg (staff with a portrait, gifts and a line in the cave; his quest from the lost fly box to the rod, the brown trout and the caddis; his trades for food and for fish; his day around Curry Village and on the river at dawn and dusk; his spot on the bank and the fly box placed by the water). The Guardian's Year test plays the year after the finale: each arc offered in its own season and only once the Guardian is found, the rock bar's meter (a perfect fit, a good heave, a slip, tired arms), each arc's work spots from hidden to worked to done, the meadow's weeds before its shortcuts and the fuel before the burn without a trip back, the press book naming each weed's native look-alike, the meadow greening a season later and the seedlings the spring after the burn, the new bear boxes you can read, the journal naming the next season's work, Clark's last talk and your Register page, saving, and the signs that say what changed. The seasons test checks the snow (none outside winter and the first days of spring, building up over the winter with each snowy day, on the painted ground and the tops of roofs and cars but not trees or lit windows, gone in summer), boot prints that last the day, the falls' flow through the year (Yosemite Falls dry by September, the small falls weeks before, Bridalveil never), the dressed falls, mist and roar, Yosemite Creek and Mirror Lake drying (and no fishing there when dry), and Horsetail Fall's firefall (only on clear late-winter evenings at sunset, the message, the light coming and going, and the El Capitan sign). The rescue test checks search and rescue from Camp 4: Jo Tolliver (staff with art, a portrait, gifts and a line in the cave), Hodges sending you to her and her first call, every call's text and stages, that each search's prints start and end at real spots with a walkable way between, that each climbing call's route starts in its area, following the boy's prints in the real Valley (shown only near you), finding him, carrying him slower on your back and handing him to Jo, sharing food, the radio's calls by season, weather and ticks, the lower (bumps, a clean lower, a hot brake, handing off), nightfall, the thank-you notes on the board, the Long Carry perk, the Journal's rescue log and call card, the sign, and saving.

### Performance bench

```bash
godot --headless --fixed-fps 60 --path . res://tools/perf/bench.tscn
godot --headless --fixed-fps 60 --path . res://tools/perf/bench.tscn -- only=wawona frames=300   # one region
```

It boots the real world, visits every region, and prints a table: first-visit load time, the first frame there, a return visit, a new day's forage, opening the map, and frame times (average, 99th percentile, peak) by day and at night. Then it opens the climbing screen on four routes and times painting it and its frames. The numbers also go to `user://bench.json`. Headless has no GPU, so these are CPU costs (scripts, physics, scenes); run it before and after a change on the same machine and compare. It takes about a minute.

**Smooth walking.** `xvfb-run -a godot --path . res://tools/perf/walk_profile.tscn` walks the player round a region (`PERF_REGION`, `PERF_SPAWN`, `PERF_HOUR`, `PERF_SECONDS`) and prints frame, script and GPU times, then how many frames the walker stood still or jumped while the camera glided; `PERF_OFF=SunShadows,Atmosphere` switches nodes off to see what each costs, and `--gpu-profile` breaks the GPU time down by pass. Headless it runs at about 145 frames a second, like a fast monitor, which is where judder shows. The player and the townsfolk move on the 60 Hz physics tick, but `SmoothMotion` (`scripts/player/smooth_motion.gd`) draws them between their last two ticks, and the camera follows the drawn player, so they glide every frame while their bodies and the doorways they walk into stay on the tick. And `AirGlow` only sets its environment while something glows, since any environment sends the whole 2D picture through the 3D pipeline (a depth pass and tonemap over the full screen each frame).

Things that keep it fast: World loads the regions next door on a background thread (`_preload_neighbors`), a forage spawner reads its map's habitats once, a Region keeps its list of Places, the map keeps each hub's sign layout, and the climbing screen paints the far landscape on a worker thread while it paints the wall.

## Map data credits

The maps are made from data under these licenses. The credit is on the game's credits screen (`CREDITS` in `scripts/ui/credits.gd`); keep it there:

- Map data © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors, available under the Open Database License (ODbL).
- Elevation: USGS 3D Elevation Program (public domain), from the [AWS Terrain Tiles](https://registry.opendata.aws/terrain-tiles/) open dataset.

## Builds

`export_presets.cfg` has three presets: **Windows** (x86_64), **macOS** (universal, ad-hoc signed) and **Linux** (x86_64, which also covers the Steam Deck). Each packs the game into one file, leaves out `docs/` and `tests/`, and carries the font's license text for the Licenses page. To build locally, install the Godot 4.7 export templates (Editor > Manage Export Templates), then:

```bash
mkdir -p build/windows build/macos build/linux
godot --headless --path . --export-release "Windows" "build/windows/Valley Days.exe"
godot --headless --path . --export-release "macOS" "build/macos/Valley Days.zip"
godot --headless --path . --export-release "Linux" "build/linux/YosemiteGame.x86_64"
```

On GitHub, run the **Build** workflow from the Actions tab (`.github/workflows/build.yml`) to get all three as downloadable artifacts. Pushing a tag such as `v0.1.0` does the same and also drafts a GitHub release with the three zips; nothing is published until you publish the draft. The macOS build isn't notarized, so the first time players open it with right-click > Open; notarizing needs an Apple Developer account (the `codesign/` and `notarization/` options in the macOS preset). The Windows build keeps Godot's icon, since setting the .exe icon needs rcedit (`application/modify_resources`).

## Road to Steam

1. Keep building. Next up: more quest chains and routes up the gear ladder in docs/DESIGN.md, real art for people and the climbing screen, and, written with the associated tribes, what the Native characters say in the finale.
2. Put up a Steam store page early. Wishlists drive visibility at launch.
3. Set up [Steamworks](https://partner.steamgames.com/). The Steam Direct fee is $100 per game.
4. Add [GodotSteam](https://godotsteam.com/) for achievements and cloud saves.
5. Export builds: the Windows, macOS and Linux presets are set up (see Builds above), and the Build workflow makes all three. Before release, notarize the macOS build and give the Windows .exe the game's icon.
6. Upload builds with SteamPipe.
