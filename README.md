# Yosemite Game

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
| Talk, read, pick up, use | E, Space, X, C, or click | A or X |
| Park and area map | M (Tab or mouse wheel switches tabs) | Back (LB / RB switch tabs) |
| Journal (quests, gear, food) | J | Y |
| Pause menu with every control | Esc | Start |
| Back out of a menu | Esc | B |
| Menus: choose / confirm | Up/Down / E or Enter | Stick or D-pad / A |
| Climbing: climb up, up-left, up-right | W / A / D (or arrows) | Stick up / left / right |
| Climbing: place a cam / eat at a ledge / retreat | Space or C / E / Esc | X / A / B |
| *Debug:* skip 1 hour / sleep now | F2 / F3 | |

A prompt above the player's head shows what the interact button will do ("E  Read: Camp 4"), and it switches to gamepad button names when you use a gamepad.

Controls are set in **Project > Project Settings > Input Map**.

## The core loop

Start at the Mountain Shop in Curry Village for a climbing guidebook. It lists every route, its grade, and the gear it needs, and you tick a route off when you top it out. The main story is that tick list: each main quest ends on a climb. Talk to people around the valley. Their quests reward you with climbing gear, recipes, and skills, and the climbers at Camp 4 trade more gear for food. Each climbing route needs certain gear before you can start it. Climbs lead to new parts of the park: the Glacier Point Apron, for example, opens Glacier Point.

Climbing runs on food. Each morning, wild forage appears around your camp, depending on the season and habitat. Fresh greens and berries give quick energy but spoil in days. In fall, gather black oak acorns and store them in a chuckah (a granary) where they never spoil. Then grind them at the bedrock mortar, leach them at the basin, and cook them into mush or long-lasting acorn cakes at the campfire. Press J to open the Journal, which shows your quests, gear, and food.

Sleep in the tent to end the day, which also saves the game. If you're still up at 2 AM you pass out, and the game moves to the next day anyway.

## The map of Yosemite

The park is built from real data. Elevation comes from the USGS 3D Elevation Program, and rivers, roads, trails, meadows, buildings, and place names come from OpenStreetMap. Cliffs, talus, and valley floors follow the real terrain, and trees change with elevation: oaks and gray pine at El Portal, ponderosa and incense cedar in the Valley, red fir at Glacier Point, lodgepole in Tuolumne, and giant sequoias in the Mariposa Grove.

The game has five **hubs**, each its own map:

| Hub | Elevation | Reached by |
|---|---|---|
| **Yosemite Valley** (main hub) | 4,000 ft | Start. Your camp is the Lamon Homestead, through the gate by Curry Village. |
| **El Portal** | 2,000 ft | El Portal Road (Hwy 140), 30 min |
| **Wawona** | 4,000 ft | Wawona Road (Hwy 41), 1 hr |
| **Glacier Point** | 7,214 ft | Glacier Point Road, 1 hr. Locked until the player climbs the Glacier Point Apron. Road open about May to November. |
| **Tuolumne Meadows** | 8,600 ft | Big Oak Flat and Tioga roads, 1.5 hr. Locked until high-country climbing. Road open about June to November. |

To travel, use a map kiosk at a parking area or walk off the edge of a hub on a road. Pick a destination on the park map. Drive times come from the real road distances and match the park's published estimates. Travel advances the clock, and you can't set out if you'd arrive after 1 AM. Press **M** anywhere to see the park map, or press **Tab** for a detailed map of the area you're in. Interpretive signs mark real landmarks; interact to read them. If you pass out away from home, a ranger drives you back to camp.

Road closures are in `Park.SEASONAL` (`scripts/autoload/park.gd`). Hub locks come from `starts_locked` on each hub's `.tres` in `data/park/hubs/`. Call `Park.unlock_hub("glacier_point")` to open one.

**Moving the player from code** (for example at the end of a climb): `get_tree().call_group("world", "go_to_region", "glacier_point", "apron_top")`. Every hub has an `arrival` spot. There are more in each map's `Map/Spawns` node, such as `apron_base`, `camp_4`, and `happy_isles` in the Valley.

**Adding things to a hub:** open `scenes/regions/<hub>.tscn`. Put NPCs and objects in **Entities**, and named Marker2D spots in **Markers**, which take priority over generated spawns with the same name. Don't edit inside the **Map** child. It's generated and gets overwritten.

**Regenerating the maps** (after changing a hub's bounds, scale, or content):

```bash
godot --headless --path . res://tools/mapgen/mapgen.tscn -- art park regions
```

- Hub bounds, scale, and walkable elevation band are in `data/park/hubs/*.tres`.
- Signs, place names, kiosks, spawn points, and where roads lead are in `tools/mapgen/hub_content.gd`.
- Downloads are cached in `tools/mapgen/cache/`, which is git-ignored. The first run needs an internet connection.
- To add a new area, such as Half Dome's summit for a climb, add a `HubData` (use `road_access = false` for climb-only areas) and an entry in `hub_content.gd`, then regenerate.

**The Valley map** is the map the player navigates. Pressing **M** anywhere in the Valley (including the Village and the homestead) opens an illustrated, Stardew-style picture of the whole Valley, seen from the south with the real terrain height. Arrow keys move between the 23 labeled places and show a note about each; **Tab** switches to the park map. Kiosks and road exits still open the park map first, for driving. Valley shuttle stops open this map too: choose a stop and press **E** to ride there (free, 15 minutes). Markers show map kiosks, climbs you have the gear for (gold) or not yet (gray), and you.

The picture, `assets/map/areas/yosemite_valley.png`, and its data, `yosemite_valley_view.json` (labels, kiosks, route starts, and the projection) plus `yosemite_valley_relief.png` (ground height, so `ParkMap` can place the player on the picture), are made by a Node script from the cached elevation and OpenStreetMap data:

```bash
cd tools/mapgen/oblique && node gen.js   # needs node and ImageMagick (magick)
```

Labels and their hand-placed positions are in `tools/mapgen/oblique/points.js`. The `art` step of mapgen skips any hub that has a `<hub>_view.json`, so it never overwrites this picture. A hub without one keeps the flat relief map.

### Yosemite Village: the Valley's central hub

Driving to Yosemite Valley brings you to **Yosemite Village**, a walking-scale central hub. It fits the real layout of the Valley between Camp 4 and the Village into one map, from the granite north wall down to the Merced River:

- **Camp 4**: the climbers' campground, with tents, Columbia Boulder, a fire ring for cooking, and two gear traders.
- **Lower Yosemite Fall** and **Yosemite Creek**, crossed by a footbridge and the Northside Drive bridge.
- **The Village**: the Village Store, Welcome Center, Yosemite Museum, Best's Studio, Degnan's, and the Wilderness Center.
- **The Indian Village** behind the museum: umachas (bark homes), a chuckah (acorn granary), and a grinding rock you can use. Its text is a placeholder until tribal review.
- **Cook's Meadow** with its boardwalk, and the Merced with **Sentinel Bridge** and **Swinging Bridge**.

Roads out of the hub lead back onto the full Valley map, and doors on that map (at the Village, Camp 4, and Cook's Meadow) lead back in. Rebuild the hub with `godot --headless --path . res://tools/hubs/build_hubs.tscn`. That rewrites the hub scene, so put NPCs in `scenes/story/content/yosemite_village.tscn` and place them by marker name. The village is drawn in the Ahwahnee's style (see below): granite-footed timber buildings with mossy shingle roofs and lit windows at dusk (`tools/hubs/valley_art.gd`), the granite wall of the Valley with Lower Yosemite Fall animated down it (`valley_land_art.gd`), and the painted ground, trees, plants and boulders shared with the hotel grounds.

### Curry Village: your first stop

Leave the Lamon Homestead by its gate and you walk out of the old apple orchard into **Curry Village**, a hand-made hub at the foot of the wall below Glacier Point. Nothing here is to scale: the few hundred real tent cabins become about fifty, in the real order, with the wall behind, the cabins below it, the Camp Curry buildings in the middle, and Stoneman Meadow and the Merced in front.

- **Tent cabins** in three winding rows, each with a wooden deck, a numbered plate and its own dressing (a chair, a cooler, boots, a lantern), plus a block of wood cabins. The cabins nearest the wall are roped off, with a sign about the rockfalls.
- **The village green**: the Registration Office, the Pavilion, the **Camp Curry Store**, the **Mountain Shop**, a pizza deck, the pool (an ice rink in winter), the Camp Curry amphitheater with the Firefall board, a fire pit you can cook at, patio tables, planters, string lights, and a flagpole.
- **The Camp Curry Store** and **Mountain Shop** have insides you walk into. The store clerk trades food that keeps (pilot bread, cheddar, apricots, jerky, chocolate, trail mix) for forage that doesn't. The Mountain Shop clerk trades quickdraws, cams, a belay device, and big-wall gear for food. Like the Camp 4 traders, the shop only rounds out a rack: every offer needs gear you already own, so the piece that opens a tier still comes from a quest. Offers are in `data/shops/curry_store.tres` and `curry_mountain_shop.tres`.
- **The way in and out**: the Camp Curry arch and parking lot with a map kiosk and a shuttle stop, roads west and east onto the Valley map, the trail up to the Glacier Point Apron, and the homestead gate.
- **People**: Jennie Curry, a camper, the Pavilion cook, a ranger-naturalist and a tourist outside; a shopper in the store and a climber in the Mountain Shop. The overlays are `scenes/story/content/curry_village.tscn`, `curry_store.tscn` and `curry_mountain_shop.tscn`.
- **After dark** lamps, windows, tents and the fire pit glow (`scripts/world/night_light.gd`), chimneys smoke in the cold months, mist rises at the foot of Staircase Falls, and fireflies come out over the meadow (`scripts/world/ambient_fx.gd`).

Rebuild it with `godot --headless --path . res://tools/hubs/build_curry.tscn`. That redraws every sprite (`tools/hubs/curry_art.gd`, `interior_art.gd`, on `pixel_kit.gd`), paints the whole ground as one picture (`tools/hubs/ground_art.gd`), and rewrites `curry_village.tscn`, `curry_store.tscn` and `curry_mountain_shop.tscn`. The layout is in `tools/hubs/build_curry_village.gd`. To look at a region the way the player sees it, run `SHOT_REGION=curry_village SHOT_SPAWNS=arrival,plaza godot --path . res://tools/shots/region_shot.tscn` (it needs a window). `SHOT_HOUR=21` shoots at night. In-game pictures are in `docs/curry_village_plaza.png`, `curry_village_cabins_dusk.png` and `curry_mountain_shop.png`, and every sprite is laid out in `docs/curry_art_preview.png` (`tools/hubs/preview_art.gd`).

### The Ahwahnee look: one style for every Valley area

The Ahwahnee's art is the reference for the whole Valley: ramp-shaded, ordered-dithered pixel art lit from the upper left, warm highlights over cool shadows, granite and stained timber, moss on the shingles, a dark rim round every sprite, and a ground painted as one picture from the terrain grid. Every hand-made Valley area now uses it, through one shared base (`tools/hubs/ahwahnee_style.gd`, which holds the tree, plant and rock scattering and the ground painting):

| Area | Rebuild with | What is drawn in the Ahwahnee style |
|---|---|---|
| Lamon Homestead | `res://tools/hubs/build_homestead.tscn` | painted ground, a tree line and boulders round the edge, meadow flowers; the five oaks show all four seasons (`tree_oak_seasons.png`) and still drop acorns |
| Curry Village | `res://tools/hubs/build_curry.tscn` | painted ground with a mown green, Registration, Pavilion, Store, Mountain Shop, Pizza Deck, amphitheater, entrance arch, tent and wood cabins (`curry_ahwahnee_art.gd`), the granite wall with Staircase Falls, trees and plants, wrought-iron lamps |
| Camp Curry Store and Mountain Shop (insides) | `build_curry.tscn` | stained plank floors, window frames and wrought lanterns (`interior_ahwahnee_art.gd`) |
| Yosemite Village and Camp 4 | `res://tools/hubs/build_hubs.tscn` | the Village, Welcome Center, Museum, Best's Studio, Degnan's, Wilderness Center and Lodge, the Indian Village shapes, camp props, the wall and Lower Yosemite Fall, trees, plants, lamps |
| The Ahwahnee and Stoneman Meadow | `res://tools/hubs/build_ahwahnee.tscn` | the original |

![Yosemite Village](docs/yosemite_village_ahwahnee_style.png)
![Curry Village](docs/curry_village_ahwahnee_style.png)
![Lamon Homestead](docs/lamon_homestead_ahwahnee_style.png)

Rebuilding rewrites each area's scene, so story NPCs stay in `scenes/story/content/`. To look at the village art on its own: `godot --headless --path . -s res://tools/hubs/preview_valley_art.gd` writes `docs/valley_art_preview.png`.

### The Ahwahnee: north from the homestead

The Lamon Homestead has a second gate, in the hedge at its north side, opening onto a trail that runs to the **Ahwahnee Hotel**. It is two hand-made regions, and nothing in them is to scale:

- **Stoneman Meadow** (`ahwahnee_trail`): a long walk north from the gate. First a mixed forest of ponderosa, incense cedar, black oak and dogwood, with ferns, bracken, mossy boulders and fallen logs. Then Stoneman Meadow itself, open and full of lupine, shooting stars, cornlily and tall grass, with a bench and an overlook on the gravel bar. The Merced runs past, broad and clear, and you cross it on **Stoneman Bridge**, a three-arch granite bridge (the real one is from 1933) with parapets you can't climb over and the arches, cutwaters and foam drawn on its south face. Willows and cattails line the far bank, and the trail climbs north to the hotel.
- **The Ahwahnee** (`the_ahwahnee`): the hotel's grounds, under the cliff. The hotel is a large, detailed sprite (448 px wide, about a screen wide): granite ground story, stained-timber upper floors, the tall Great Lounge windows, a painted Native-inspired band, shingled gables, stone chimneys, and the porte-cochère with its amber doors. **You can't go inside yet**: its doors are an interpretive sign (`MainEntrance`, at `front_door`), ready to become a door. Around it are a gravel entrance circle with a tiered fountain and a curbed lawn island, terrace urns and topiary, clipped hedges, lamp posts, a rose garden with four flower beds, an arbor, a sundial and a birdbath, a tea lawn with striped umbrellas, stone gate posts and the hotel's sign at the foot of the drive, and Ahwahnee Meadow to the east. Behind it stands the wall of the Valley, with the **Royal Arches** as a stack of giant curved steps in the granite, Washington Column beside them, and the **Royal Arch Cascade** (an animated, looping waterfall with mist) falling to a plunge pool. Royal Arch Creek runs from it through the woods and out the west edge, and a stone-and-gravel road leads west to the Valley map (the Northside Drive exit). After dark the hotel's windows and the lamp posts glow (`scripts/world/night_glow.gd`).

Spots for story overlays (`scenes/story/content/<region_id>.tscn`, placed by marker name): on the trail `south_entry`, `north_entry`, `bridge_west`, `bridge_east`, `meadow`, `river_bank`; at the hotel `south_entry`, `west_road`, `front_door`, `entrance_circle`, `rose_garden`, `tea_lawn`, `ahwahnee_meadow`, `cascade`.

Rebuild both with `godot --headless --path . res://tools/hubs/build_ahwahnee.tscn`. It redraws the sprites, paints both grounds as one picture each (`tools/hubs/ahwahnee_ground.gd`), rewrites `ahwahnee_trail.tscn` and `the_ahwahnee.tscn`, and, the first time only, opens the homestead's north gate. The art is in three modules on `pixel_kit.gd`: `ahwahnee_hotel_art.gd` (the hotel, its glow, gate posts, sign, lamp), `ahwahnee_land_art.gd` (the Royal Arches wall, cascade and mist, Stoneman Bridge), and `ahwahnee_flora_art.gd` (trees, plants, rocks, logs, and the formal garden pieces). `docs/ahwahnee_*_preview.png` show each set, and `docs/ahwahnee_grounds_overview.png` and `docs/ahwahnee_trail_overview.png` show each whole region (made by `tools/shots/ahwahnee_overview.tscn`). To look at a region the way the player sees it: `SHOT_REGION=the_ahwahnee SHOT_SPAWNS=south_entry@52:41 godot --path . res://tools/shots/ahwahnee_shot.tscn` (needs a window; `name@x:y` puts the player on that tile). The painted band on the hotel is a placeholder inspired by the real beams and is **flagged for tribal review** with the rest of the Native-inspired content.

**Valley shuttle.** Green shuttle stop signs at the Village, Camp 4, the Lamon Homestead, Curry Village, Happy Isles, Mirror Lake, and El Capitan Meadow take you to any other stop in 15 minutes. The stop list is in `scripts/objects/shuttle_stop.gd`.

**Trading.** Money is gone, so traders take food instead. The Camp Curry Store and the Mountain Shop (see Curry Village above) work the same way. A price is an amount of food energy, and they take whatever in your pack spoils soonest first. The Village Store swaps fresh forage for trail mix and dried apples, which keep much longer. The Camp 4 traders round out a rack you already have (extra cams, quickdraws, a belay device, and big-wall gear once you can aid climb), but the piece that opens a new climbing tier still comes from a quest. Offers are in `data/shops/*.tres`, each with the gear it requires and a maximum you can own.

**Bridges.** When a river cuts off a walkable area on a generated hub map, the map generator builds a bridge at the shortest crossing (`MIN_CUT_OFF_AREA` and `MAX_BRIDGE` in `tools/mapgen/region_builder.gd`).

## Story

The story is in [STORY.md](STORY.md), and the mechanics are in [docs/DESIGN.md](docs/DESIGN.md). Galen Clark gives you the Guardian's Register, and you fill it with the stories of real people from the park's history. Native characters and practices are flagged for review by the tribes traditionally associated with Yosemite.

[docs/CAST.md](docs/CAST.md) lists the cast (22 historical people and 10 visitors from different eras), where each one lives, and the quest chains from the first morning to the last page. The character sprites are drawn by `tools/npcgen/`.

There are a few hidden touches in the valley (night, moon, and season events). Developers can find them in the "Easter eggs" section of [docs/DESIGN.md](docs/DESIGN.md).

## Yosemite items

Every item is a native Sierra plant or food, with a short natural-history note that shows when you find it. Energy is what it restores on a climb, and "keeps" is how many days it lasts in your pack (see `scripts/story/food_db.gd`).

**Wild forage** (spawns each morning, by season and habitat)

| Item | Season | Habitat | Energy | Keeps |
|---|---|---|---|---|
| Miner's Lettuce | Spring | under black oaks | 8 | 2 days |
| Sierra Onion | Spring | meadows | 6 | 5 days |
| Wild Strawberry | Spring, Summer | meadows | 10 | 2 days |
| Morel Mushroom | Spring | under black oaks | cook first | 3 days |
| Yerba Buena | Spring, Summer | along the river | 2 (or brew tea) | 3 days |
| Blue Elderberries | Summer | along the river | cook first | 2 days |
| Manzanita Berries | Summer | beside manzanita shrubs | 10 | 3 days |
| Yampah | Summer, Fall | meadows | 12 | 7 days |
| Black Oak Acorn | Fall | under black oaks | leach first | 14 days, forever in a chuckah |
| Toyon Berries | Fall, Winter | beside manzanita shrubs | toast first | 5 days |

Black oaks change color with the seasons.

## Project layout

```
project.godot            480×270 base resolution, scaled up in whole-number steps with nearest-neighbor filtering
scenes/
  world/world.tscn       main scene: loads one region at a time, plus player, lighting, HUD, park map
  regions/               one scene per hub, plus lamon_homestead.tscn (your camp)
  regions/generated/     generated hub terrain (don't edit; rebuilt by tools/mapgen)
  player/player.tscn     the player (CharacterBody2D + camera)
  objects/               tent (sleep), black oak, forageable pickup,
                         info sign, map kiosk (travel point), region door
  ui/hud.tscn            date/time, status strip, bag, location, messages, sign text, fades
  story/                 NPC, cooking station, chuckah; story/content/<region>.tscn places them
  climb/                 climbing minigame and route starts
scripts/
  autoload/              global singletons, always loaded
    game_clock.gd        time, days, seasons (28 days each)
    inventory.gd         what you are carrying
    item_db.gd           registry of all items (forage + prepared food)
    save_manager.gd      JSON save/load (user://save.json)
    park.gd              hubs, routes, seasonal road closures, hub unlocks
  world/forage_spawner.gd  daily wild forage, placed by season and habitat
  world/world.gd         loads regions, travel, sleep sequence
  world/region.gd        a map the player can be in (hub or smaller area)
  ui/park_map.gd         park and area map screens
  world/day_night.gd     time-of-day lighting (edit the gradient in the Inspector)
  player/player.gd       movement, facing, interaction
  story/                 quests, gear, food, chuckah, recipes, dialogue, journal (autoloads: Gear, QuestLog, FoodDB, Larder, Granary, Recipes)
  climb/                 climbing rules (climb_state.gd) and screen
  data/item_data.gd      ItemData resource definition (name, description, icon, forage rules)
data/items/*.tres        one file per forage item
data/food/*.tres         one file per prepared food
data/quests, characters, gear, recipes, routes   story data (see docs/DESIGN.md)
data/park/hubs/*.tres    one file per hub: name, description, location, map bounds
data/park/routes.json    generated driving routes between hubs
assets/map/              generated park map and area maps
tools/mapgen/            the map generator
assets/sprites/          placeholder pixel art, meant to be replaced (items.png holds the 16×16 item icons)
assets/tiles/            TileSet (collision + "open_ground" flag per tile, where forage can land)
tests/                   headless tests (smoke, story, travel, world_story, ahwahnee)
```

## How to add things

**A new forage item:** draw a 16×16 icon, then duplicate a forage `.tres` in `data/items/` (for example `black_oak_acorn.tres`). Under **Foraging**, set its seasons, habitat, and how many spawn per day. Add it to `ITEMS` in `item_db.gd`, and give it an energy and shelf life in `scripts/story/food_db.gd`. Habitats are worked out from the map: *meadow* is any open grass, *oak woodland* is the ground just south of a black oak, *chaparral* is next to manzanita shrub tiles, and *riverside* is next to water. To add a new habitat, extend `ItemData.Habitat` and `_find_habitats()` in `forage_spawner.gd`.

**Editing the homestead:** open `scenes/regions/lamon_homestead.tscn`, select the **Ground** layer, and paint with the TileMap panel at the bottom. Grass tiles have the `open_ground` custom data flag, which is where forage can land. Water, boulders, and shrubs have collision. The generated hubs get their collision from the hidden **Blocker** layer instead.

**Saving a new system:** add the node to the `persist` group and give it `save_data() -> Dictionary` and `load_data(data)`. SaveManager picks it up automatically.

**Replacing the art:** overwrite the PNGs in `assets/sprites/` with the same layout. The player sheet uses 16×24 frames, with columns stand / step A / step B and rows down / up / left / right. Aseprite is the usual tool for this.

## Testing

```bash
godot --headless --path . res://tests/smoke_test.tscn
```

It walks, checks each season's forage and where it grows, picks things up, sleeps, saves, reloads, and checks season changes. It prints PASS/FAIL for each step and uses its own save file. Run it after big changes.

```bash
godot --headless --path . res://tests/travel_test.tscn
```

It loads every hub and checks that spawn points are walkable. It also walks through the homestead gate, drives between hubs, and checks locks, seasonal closures, the late-night cutoff, saving the current region, and passing out away from home.

```bash
godot --headless --path . res://tests/ahwahnee_test.tscn
```

It walks the way from the homestead's north gate through Stoneman Meadow, over Stoneman Bridge (parapets and river included), and up to the Ahwahnee, and checks that every spot is reachable, the hotel can't be entered, and the cascade and evening glow are in place.

```bash
godot --headless --path . res://tests/story_test.tscn
godot --headless --path . res://tests/world_story_test.tscn
godot --headless --path . res://tests/cast_test.tscn
godot --headless --path . res://tests/eggs_test.tscn
```

The story test covers quests, gear, food spoilage, the chuckah, recipes, and the climbing rules. The world story test boots the real game and checks that people, climbs, and cooking spots are placed, the first quest works, and the Journal opens. The cast test checks that every quest's people, items, gear, and routes exist, that the gear curve lets you finish every quest, and that everyone stands on open ground. The eggs test checks the Easter eggs in docs/DESIGN.md (it takes about 15 seconds).

## Map data credits

The maps are made from data under these licenses. Keep this credit in the game's credits screen:

- Map data © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors, available under the Open Database License (ODbL).
- Elevation: USGS 3D Elevation Program (public domain), from the [AWS Terrain Tiles](https://registry.opendata.aws/terrain-tiles/) open dataset.

## Road to Steam

1. Keep building. Next up: more quest chains and routes up the gear ladder in docs/DESIGN.md, real art for people and the climbing screen, and tribal review of Native characters and content.
2. Put up a Steam store page early. Wishlists drive visibility at launch.
3. Set up [Steamworks](https://partner.steamgames.com/). The Steam Direct fee is $100 per game.
4. Add [GodotSteam](https://godotsteam.com/) for achievements and cloud saves.
5. Export builds: **Project > Export**. Install export templates, then add Windows, Linux, and macOS presets. The Linux build also covers the Steam Deck.
6. Upload builds with SteamPipe.
