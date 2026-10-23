# Valley Days: Design

Working design doc. Farming has been removed from the game. Anything marked **(open)** still needs a decision.

## Core idea

You travel through Yosemite, meet real people from its history, and hear their stories. Their quests give you climbing gear, and the climbers at Camp 4 will trade you more of it for food. New gear opens climbing routes, and those routes lead to new parts of the park. To survive longer climbs, you gather, store, and cook food.

```
Hear a story → Take a quest → Gather / cook / climb → Earn gear
      ↑                                                   ↓
New area & new people  ←  Climb a route  ←  Pack food for the climb
```

## Pillars

1. **Stories first.** Every quest giver is a real historical person, and their quest teaches something true about the park.
2. **Gear opens the map.** Climbing is the main way to reach new areas. The map follows real geography loosely, so walking trails don't let you skip ahead.
3. **Food is fuel.** Short climbs need a snack. Big walls need days of stored, cooked food. Acorns are the staple.
4. **Seasons matter.** The existing clock and seasons stay. Miner's lettuce grows in spring, manzanita berries ripen in summer, and acorns drop in fall.

## Gear progression

Gear comes two ways, and there's no money in the game:

- **Quest rewards.** The key pieces for each tier, the ones that open a new area, come from the people you meet once they trust you.
- **Barter at Camp 4 and the Curry Village Mountain Shop.** Climbers and the shop clerk trade gear for food and forage, a climber's real currency. Trades fill out your rack (extra cams, quickdraws) rather than skipping a tier, so the story still sets the pace: every offer needs gear you already own. The offers are data in `data/shops/*.tres`.

| Tier | Gear | Example routes | Opens up |
|---|---|---|---|
| 0 | Approach shoes | Camp 4 boulders | Valley floor |
| 0½ | Climbing shoes, chalk bag, harness, 5 quickdraws (the Mountain Shop's starter kit; your partner brings the rope) | Firefall Slab (5.5, bolted) | Your first tick |
| 1 | + Rope, 2 cams | Swan Slab (5.6), Glacier Point Apron (5.7) | **Glacier Point** |
| 2 | More cams, quickdraws, belay/rappel device | Nutcracker (5.8), Higher Cathedral Spire (5.9), Steck-Salathé (5.10b); Royal Arches, Snake Dike | North Dome rim, **Half Dome**, Sentinel Rock |
| 3 | Ascenders, portaledge, then aiders and a haul bag | Astroman (5.11c), Separate Reality (5.12a), the Nose free (5.13) | **El Capitan**, the north rim |
| 4 | Ice axe, crampons | Cathedral Peak, Lyell Glacier | **Tuolumne Meadows** and the high country (Mono Lake and the east side are planned, not built) |

How the gear affects the climbing minigame:
- **Rope length** sets how long each pitch can be.
- **Number of cams** sets how many placements you get per pitch. Too few means long runouts and a riskier climb.
- **Quickdraws** clip the bolts on bolted routes, one per bolt. A bolted pitch has a bolt every 2 moves, and you can clip one from your hold or the next one over.
- **Climbing shoes** take 1 stamina off every move. A **chalk bag** lets you chalk up once a pitch (E on the wall) for 2 moves that cost 3 less.
- **Big wall gear** lets a climb last several days, with nights on a portaledge. Multi-day climbs are where food matters most.

## Food, storage & cooking

### Acorns: the long-term staple
The acorn cycle follows traditional Southern Sierra Miwuk and Ahwahneechee practice. All details must be checked with tribal advisors (see below).

1. **Gather** black oak acorns in fall.
2. **Store** them in a **chuckah** (acorn granary) that you build. Stored acorns keep all year. A bigger or second granary holds more.
3. **Process:** crack and shell, grind at a bedrock mortar, then leach the meal with water to remove the bitter tannins.
4. **Cook** with hot stones into mush or cakes. Acorn meals are slow-burning, long-lasting climbing food.

### Seasonal foods: quick energy
They spoil fast (in a day or two), so they're good for short climbs or as a boost partway up.

| Food | Season | Notes |
|---|---|---|
| Miner's lettuce | Spring | Fresh greens |
| Wild strawberries | Late spring | |
| Manzanita berries | Summer | Can also be made into cider |
| Blue elderberries | Late summer | Must be cooked |
| Thimbleberries / gooseberries | Summer | |
| Trout | Most seasons | From the Merced River |
| Pine nuts | Fall | Traded from Paiute people east of the crest (Mono Lake) |
| Lamon orchard apples | Fall | James Lamon's 1860s orchard (now Curry Village) |

### Cooking & meals
- You cook at a **campfire**. A recipe combines ingredients into a meal.
- Every meal has **energy** (stamina on the climb) and **shelf life** (how many days it lasts in your pack).
- Before a climb you **pack a food bag**. The route tells you roughly how many days it takes, and you need enough food to cover it.

| Meal type | Energy | Shelf life | Best for |
|---|---|---|---|
| Fresh forage | Low–medium | 1–2 days | Day climbs, snacks |
| Cooked seasonal dish | Medium | 2–3 days | Day climbs, short multi-pitch |
| Acorn mush / cakes | High | Many days | Big walls, expeditions |

## Perks

Perks are small things the valley teaches you: knowledge from the people you meet, and habits from doing the work. They aren't stats to grind or points to spend. Each one is earned by playing (finishing someone's story, foraging, cooking, climbing, living in the valley), never chosen or bought, and each gives a gentle, permanent bonus. A message on the HUD says when you earn one ("New perk: ..."), and the Journal's **Perks** section lists every perk: earned ones with their effect and a line of history, the rest with how to earn them and your progress.

| Perk | How you earn it | Effect | Hooked in |
|---|---|---|---|
| **Muir's Stride** | Wake up in the valley 14 mornings | Walk 8% faster | `player.gd` |
| **Enid's Eye** | Pick up 25 wild finds | One more piece of forage each morning, in every area | `forage_spawner.gd` |
| **Tabuce's Patience** | Cook acorn mush or cakes 3 times | The mortar and leaching basin take a quarter less time | `recipes.gd` (`Perks.recipe_minutes`) |
| **Lamon's Cellar** | Finish James Lamon's *lamon_winter* story | Food you pick up keeps one more day (food that never spoils still never does) | `food_db.gd` |
| **Trail Cook** | Make 12 dishes at any station | Food eaten at a belay ledge gives 2 more energy | `climb_state.gd` `eat()` |
| **Leonard's Belay** | Finish Dick Leonard's *leonard_belay* | 3 more stamina at every belay ledge | `climb_state.gd` `_finish_pitch()` |
| **Steady Breath** | Climb 5 crux moves perfectly | The crux green zone is 0.03 wider | `climb_state.gd` `crux_window()` |
| **Light Rack** | Tick 6 routes | A move on the wall takes 5 minutes, not 6 | `climb_state.gd` `move()` |
| **Slackliner's Feet** | Walk a Camp 4 slackline end to end 5 times | Moves on a friction slab cost 1 less stamina (never below 1) | `climb_state.gd` `move_cost()` |

Each effect is smaller than a piece of gear's (climbing shoes widen the crux zone by 0.05 and take a whole stamina off every move), so gear still sets the pace of the story and the climbing tests' gear curve holds without perks. Tabuce's Patience is Native content and carries the same tribal-review placeholder as her dialogue.

How it works: the autoload `Perks` (`scripts/story/perks.gd`) holds the definitions (`PERKS`), what's been earned, and the counts no other system keeps (`stats`: forage picked up, mornings, perfect cruxes, slackline crossings, and the slackline's best scores and medals, kept with `Perks.record(...)`; cooking and ticks are read from `Recipes` and `QuestLog`). It checks for new perks when quests change, a dish is made, a day starts, or `Perks.note(...)` counts something, and emits `unlocked(perk)`. Effects are read at the call site with `Perks.bonus("id")`, which is 0 until the perk is earned. It saves through the `persist` group; a save from before perks catches up quietly on load. Messages wait until no conversation, menu or climb covers the HUD. Tested in `tests/perks_test.gd`.

To add a perk: add an entry to `Perks.PERKS` (an `unlock` of `{"quest": id}` or `{"stat": name, "count": n}`, plus `amount`, `how`, `effect`, `flavor`), and read `Perks.bonus("id")` where it applies. A new kind of count goes in `Perks.progress()`, or is counted with `Perks.note("name")`.

## Climbing minigame

The next design is in [Climbing minigame: first design](CLIMBING_MINIGAME.md), with a [standalone playable browser study](climbing-prototype.html). It explores equipment actions and later progression separately from the current Godot implementation, for integration later.

Short, and played one pitch at a time:
- **Holds:** pick your next hold. Harder moves cost more stamina.
- **Protection:** place a cam when you're at a good crack. Cams are limited, and falling far from your last placement hurts more.
- **Stamina:** drops as you climb. Eat from your food bag at belay ledges.
- **Pitches:** a route is a chain of pitches. A big wall adds bivy nights, and each night uses up food.
- **Failure:** you lower off safely and keep your gear. You only lose time and food.

**(open)** Visual style of the minigame: a side-view wall screen that the top-down game switches into is the likely choice.

## Map (loose real geography)

| Area | Reached by | Themes / people |
|---|---|---|
| **Valley floor**: Ahwahnee, Camp 4, the village, meadows | Start | Ahwahneechee homeland, acorn gathering, early climbers |
| **Glacier Point** | Tier 1 climb | Views, early tourism, the Firefall |
| **North Dome / rim** | Tier 2 climb | |
| **Half Dome** | Tier 2 climb | George Anderson's 1875 first ascent |
| **El Capitan** | Tier 3 big wall | Golden-age climbing |
| **Tuolumne Meadows** | Tier 4 | John Muir, Cathedral Peak |
| **Mono Lake / east side** | Tier 4 | Mono Lake Kutzadika'a, Paiute trade routes |
| **Wawona / Mariposa Grove** | **(open)** | Galen Clark, the giant sequoias |

## People

Everyone is a real historical person. This is a starting list. Some of them are only possible NPCs until we confirm permission.

### Native people and nations
The quest line should feature the Ahwahneechee and all seven tribes traditionally associated with Yosemite:

1. American Indian Council of Mariposa County (Southern Sierra Miwuk Nation)
2. Tuolumne Band of Me-Wuk Indians
3. Picayune Rancheria of the Chukchansi Indians
4. North Fork Rancheria of Mono Indians
5. Mono Lake Kutzadika'a Tribe
6. Bishop Paiute Tribe
7. Bridgeport Indian Colony

Possible historical figures:

| Person | Story ideas |
|---|---|
| **Tenaya** | Ahwahneechee leader in 1851 and the Mariposa Battalion. Tell this truthfully, including the violence of removal. |
| **Maria Lebrado (Totuya)** | Tenaya's granddaughter. She returned to the valley in 1929 and identified village sites. |
| **Maggie "Tabuce" Howard** | Mono Lake Paiute. Demonstrated traditional skills at the Yosemite Museum. A natural teacher for the acorn and granary quests. |
| **Lucy Telles** | Basket weaver (Mono Lake Paiute/Miwuk). Her very large basket. |
| **Carrie Bethel** | Mono Lake Paiute basket weaver |
| **Chris Brown (Chief Lemee)** | Miwuk dancer and cultural demonstrator |
| **Julia Parker** | Weaver and acorn demonstrator. Died in 2024, so we need her family's permission. |

### Explorers, naturalists, rangers
| Person | Story / quest ideas |
|---|---|
| **John Muir** | Cathedral Peak (1869), glaciers. Tier 4 gatekeeper. |
| **Galen Clark** | First Guardian of Yosemite, Mariposa Grove |
| **George Anderson** | Drilled his way up Half Dome in 1875 |
| **James Lamon** | First non-Native settler to stay year-round. Orchard (apples). |
| **Clare Marie Hodges** | First woman ranger (1918) |
| **Enid Michael** | Early naturalist and botanist. A plant-ID / foraging mentor, and the one who hands over the plant press (the second storyline: see STORY.md, "The press book"). |
| **Ansel Adams** | Photography quests, views from the rim |

### Climbers
| Person | Story / quest ideas |
|---|---|
| **Jules Eichorn, Dick Leonard, Bestor Robinson** | First technical climbs in the Valley (Cathedral Spires, 1934). Rope and belay basics. **Tier 1 givers.** |
| **John Salathé** | Blacksmith who forged hard steel pitons. Lost Arrow, Salathé Wall. |
| **Allen Steck** | Sentinel with Salathé (1950) |
| **Warren Harding** | First ascent of the Nose (1958). **Tier 3 giver.** |
| **Royal Robbins** | Half Dome NW Face (1957). Clean climbing. |
| **Tom Frost, Chuck Pratt** | Golden-age big walls |
| **Beverly Johnson** | First woman to solo El Cap (1978) |
| *Yvon Chouinard, Ray Jardine, Lynn Hill* | Still living, so we'd need permission (see open questions) |

## Timeline framing

These people lived from before 1851 through the 1990s, and the gear they used changed over that time (hemp rope → steel pitons → cams). Options:

- **A. Timeless valley.** Everyone is present together, and nobody explains how. This is the simplest option.
- **B. Stories as memories.** You find places and objects, and the stories play out as vignettes from their own time.
- **C. The gear follows history.** You move forward through the eras, and your gear modernizes the way real climbing gear did.

**Chosen: A, a timeless valley.** Everyone the player meets is a real historical person, and all of them share one season with no explanation or magic. Each of them lives in their own era, and everyone is treated equally as a living person. The Guardian's Register, which Galen Clark gives the player, works as the quest log and records what really happened. See [STORY.md](../STORY.md).

## Cultural review & rights

- **Tribal consultation.** Before any Native story, character, food practice, or place name ships, it should be reviewed by the associated tribes. The NPS tribal liaison is a good first contact. Until then, their dialogue is placeholder text marked `TRIBAL REVIEW NEEDED`. The game's current Native content has been through this review; only the finale's lines for the Native characters are still to be written.
- **Naming.** Use each tribe's own preferred spelling (Miwuk, Miwok, and Me-Wuk all appear). Avoid depicting ceremonies or sacred objects unless the tribes invite it.
- **Real people.** Deceased historical figures are generally fine to portray respectfully. Living people (Chouinard, Jardine, Hill) and people who died recently (Julia Parker) need permission, or should be left out. This matters especially for a game sold on Steam.

## Easter eggs

Hidden touches, for developers (spoilers). None of them edits a generated hub scene: the moving effects are placed by the story overlays, and the sign changes are added when a region first loads (`scripts/story/easter_eggs.gd`, called from `StoryContent.attach`). All of them are tested in `tests/eggs_test.gd`.

- **Live Firefall** (`scripts/world/firefall.gd`, placed in `scenes/story/content/curry_village.tscn`). Summer nights from 9:00 to 9:15 PM (`GameClock.is_firefall_time()`), a ribbon of orange-gold embers falls down the granite wall above Camp Curry, from a glow pool at the rim where Glacier Point sits. It is drawn in whole pixels with additive blending, so nothing blurs. If the player is in Curry Village, a message announces it once ("Someone calls up to the rim: 'Let the fire fall!'") and the embers start a moment later. The FirefallBoard sign gains a line while it runs. The real show ran from the 1870s until January 25, 1968; in the game's timeless valley Jennie Curry and James McCauley are alive in this shared season, so it still happens. See `docs/curry_village_firefall.png`.
- **Moonbow** (`scripts/world/moonbow.gd`, in `scenes/story/content/yosemite_village.tscn`). The moon is full on day 14 of each 28-day season (`GameClock.moon_phase()`, `is_full_moon()` for days 13 to 15). On a spring full-moon night from 9 PM until 2 AM, a faint white arc forms in the mist at the foot of Lower Yosemite Fall, and the Lower Yosemite Fall sign adds a line about it.
- **Camp 4 at night.** From midnight to 4 AM the Columbia Boulder sign (Midnight Lightning) adds a line about fresh chalk and a headlamp, and a small headlamp glow (`scripts/world/headlamp.gd`) appears on the ledge. The clock stops at 2 AM, so in play this runs from midnight to 2 AM. Bear boxes at Camp 4 and Curry Village become readable signs: food storage is required, and Yosemite has only black bears (no grizzlies since the 1920s).
- **The Camp 4 slacklines.** The slackline's sign also offers "Walk the line" (`scripts/objects/slackline_spot.gd`, put on the generated sign by `EasterEggs`), which opens a side-on screen of the campground: the walls across the Valley (Glacier Point, Sentinel Rock, Cathedral Rocks) lit for the hour, Columbia Boulder and the tents, a campfire, and four climbers watching who cheer, wince and call out. You pick one of three lines (`SlacklineState.LINES`): the knee-high **Short Line** between two young pines, the classic **Camp 4 Line** between two ponderosas, and the **Long Line** across the whole clearing, which opens once you've walked the Camp 4 Line and is the only one the wind gusts on. You walk on by yourself while the line tips you, bucking harder toward the sagging middle, and Left/Right lean you back (`SlacklineState`: an upside-down pendulum with a push). Every buck is felt coming: a ripple runs down the webbing and arrows under the balance meter point the way it will throw you, so a quick hand can meet it; gusts give more warning and a longer shove, with leaves and wind streaks across the screen. Lean past the green and you stop to steady yourself; reach the edge and time slows for a moment so you can save it (a close call, worth points), or you're off. Staying steady builds **flow** (x2 after 2 seconds, x3 after 5; a wobble starts it over), which multiplies the points for each step. When you're centered, interact does a **trick** (drop knee, turnaround, sit down, in turn, spaced along the line): you stop walking and your arms are busy, and if you hold it steady it lands for points times your flow. A crossing earns bronze, and a high enough score silver or gold; the results card counts the score up and stamps the medal. Best scores and medals are kept per line, gold on all three is "Camp 4 Legend", and five crossings earn the Slackliner's Feet perk. The first walk end to end of the Camp 4 Line still wins the six-pack of King Cobra on the far stump (once: the `slackline_walked` unlock), and each walk takes 10 game minutes. A Camp 4 climber's idle line mentions the bet. The code is `scripts/slackline/` (`slackline_state.gd` the rules, `slackline_art.gd` the painted scene on the climbing screen's art kit, `slackline_hud.gd` the overlays, `slackline_minigame.gd` the screen); the sounds (`slack_twang`, `slack_gust`, `slack_cheer`, `slack_medal`) are made by `tools/audio/build_sounds.gd`. Difficulty and medal scores were tuned against simulated players with a human's reaction time. `tests/slackline_test.tscn` checks the rules, the warnings, flow, tricks and medals, the screen, the prize, the perk, and the sign; `SHOT_HOURS=12,19,23 xvfb-run -a godot --path . res://tools/shots/slackline_shot.tscn` photographs each moment.
- **Clark's note.** Once `tenaya_ahwahnee` is done, the Clark's Station sign in Wawona adds a line about a note pinned in the window.
- **Muir's windstorm.** `CharacterData` has optional `rare_lines`, `rare_after_quest` and `rare_chance` fields. After `muir_glacier`, about one idle talk in five has John Muir tell two lines of his windstorm story, a paraphrase of "A Wind-Storm in the Forests" (1878; in *The Mountains of California*, 1894). `QuestLog.talk_to` picks them through `CharacterData.idle_lines_for()`.
- **Crow's Camp.** At the east end of Mirror Lake, where the trail bends up toward the wall, a little stone cairn (a readable sign) marks a faint use trail east along Tenaya Creek, half hidden under the pines. It leads to `crows_camp`, a small area built with the Valley floor (`_crows_camp` in `tools/hubs/build_valley_floor.gd`, art in `tools/hubs/crow_art.gd`): a second cairn, then a winding ribbon of granite slab up through a talus field of fallen blocks, to a camp under a granite overhang (prayer flags, a pad and a red bag, a candle lantern), with a lit fire ring, a stump and a bear box whose sign has its own text. The area is not labelled on the map. Crow, a tattooed camper (`data/characters/visitors/crow.tres`, a visitor, so not in the Register; look in `tools/npcgen/looks.gd`, whose new `tattoos` key inks bare arms and shoulders), stands by the fire day and night (`scripts/story/crow.gd`). The first time he hands you a little piece of paper: say yes and the whole screen, HUD included, swirls, ripples, folds into a kaleidoscope and cycles through every color for ten seconds (`scripts/ui/trip_effect.gd`, a screen-reading shader on a CanvasLayer over everything), then you're back by the fire and he offers a joint: smoke rises from both of you, you cough, and a faint haze lingers for 25 seconds. Later visits offer another paper (once a game day), another joint, or just an idle line. Meeting him is saved as the heard beat `crow:met`. Photographed by `tools/shots/crow_shot.tscn`.
- **Bear tracks.** After passing out at the 2 AM curfew (and not after an ordinary night), the next morning shows "Bear tracks by the fence this morning. Your pack was zipped." once, a few seconds after the usual passed-out message (`World._show_bear_tracks`). Nothing is lost and nothing is saved.

To add another conditional sign line, set the `extra_*` fields on `InfoSign` (`extra_text`, `extra_hours`, `extra_season`, `extra_full_moon`, `extra_after_quest`, or an `extra_when` callable). A sign that leaves them alone behaves as before. `NightLight` has a matching `lit_hours` field for lights that only burn at set hours.

To look at the effects: `SHOT_REGION=curry_village SHOT_SPAWNS=campsite_center@58:5 SHOT_HOUR=21 SHOT_MINUTE=5 SHOT_SEASON=1 SHOT_WAIT=7 godot --path . res://tools/shots/region_shot.tscn` (`SHOT_MINUTE`, `SHOT_DAY` and `SHOT_WAIT` are in `tools/shots/region_shot.gd`).

## What changes in the code

| Keep | Remove / replace | Add |
|---|---|---|
| GameClock (days, seasons) | Farm, crops, hoe/watering/seeds | NPC + dialogue system |
| Inventory, ItemDB, forage spawner | Shipping crate & money | Quest system (steps, rewards) |
| Save system | Farm hotbar | Gear inventory + gear-gated areas |
| Tent (rest/save) | | Chuckah granary, acorn processing |
| Day/night lighting | | Campfire cooking, meals, food bag |
| | | Climbing minigame scene |
| | | Multiple map areas with transitions |

## Built so far

All of this is wired into the World. Each region's people, climbs, and cooking spots live in a story overlay, `scenes/story/content/<region_id>.tscn`, which World adds to the region on first visit (`StoryContent.attach`). Mapgen never touches these files.

| System | Files | Notes |
|---|---|---|
| Gear | `scripts/story/gear.gd`, `data/gear/*.tres` | Autoload `Gear`. You start with approach shoes. The Mountain Shop's *Fitted Out* quest gives climbing shoes, a chalk bag, a harness, and 5 quickdraws. |
| Quests & dialogue | `scripts/story/quest_log.gd`, `quest_data.gd`, `character_data.gd`, `dialogue_box.gd`, `npc.gd` | Autoload `QuestLog`. Quest steps: have, have_food, pay, talk, chuckah, stored, made, climbed, return. Invented staff (the Mountain Shop's two, the Ahwahnee's chef) are in `QuestLog.STAFF`. |
| Food & spoilage | `scripts/story/food_db.gd`, `larder.gd`, `data/food/*.tres` | Autoloads `FoodDB` (energy, shelf life) and `Larder` (spoils food overnight). |
| Chuckah | `scripts/story/granary.gd`, `chuckah.gd` | Autoload `Granary`. Stored acorns never spoil, and one chuckah holds 40. |
| Cooking | `scripts/story/recipes.gd`, `station.gd`, `data/recipes/*.tres` | Stations: campfire, bedrock mortar, leaching basin. Acorn chain: 4 acorns → flour → leached meal → mush or cakes. |
| Climbing | `scripts/climb/*`, `scenes/climb/*`, `data/routes/*.tres` | Rules are in `ClimbState`, pictures in `ClimbScenery`. Cams in cracks, or quickdraws on bolts (`RouteData.protection`). A route can need a partner (`RouteData.partner_quest`). |
| Journal | `scripts/story/journal.gd` | One book, three tabs. J: the Register, the guidebook's tick list, and perks. Q: the main story's next step and open quests. B: the Backpack, a grid of slots for gear, food (with days left), and forage, plus the chuckah. Tab (LB/RB) flips tabs. Pauses the clock. |
| Perks | `scripts/story/perks.gd` | Autoload `Perks`. Nine gentle bonuses earned from people and experience; see **Perks** above. |
| Tests | `tests/story_test.tscn`, `tests/world_story_test.tscn` | Run headless. The world test uses its own save file. |

First playable stretch:
1. **The Mountain Shop:** trade food for a guidebook, then return the lost rental shoes and trade more food for a starter kit. **Wren Alvarez**, the new hire, belays you up **Firefall Slab**, a bolted route on the Apron.
1. **Dick Leonard:** climb Swan Slab and carry some trail food. The reward is a rope and 2 cams.
2. **Tabuce:** gather 12 acorns in fall. She then shows you how to build a chuckah. Build it and store the acorns, and she teaches you the acorn recipes.
3. **The Glacier Point Apron** leads to Glacier Point.

Still open:
- Cams from 1930s climbers: settled by the timeline choice. Gear is described as "what they can spare from their kit," simplified to its modern version.
- Real art for stations and the climbing screen. They're placeholder shapes for now. NPCs have generated pixel sprites (see [CAST.md](CAST.md)); hand-drawn replacements can use the same sheet layout.
