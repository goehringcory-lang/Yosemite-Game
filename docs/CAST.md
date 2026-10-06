# Cast & Quest Chains

This is the full cast of people the player meets, where they live in the park, and the quest chains that trade stories, food, and materials for the climbing gear that opens the map. [STORY.md](../STORY.md) is the narrative frame, and [DESIGN.md](DESIGN.md) covers the mechanics.

![The cast, facing down](cast_lineup.png)

*Left to right, top to bottom. Row 1: Clark, Lamon, Tenaya, Tabuce, Degnan, Leonard, Eichorn, Robinson. Row 2: J. Curry, Anderson, Hodges, Adams, Telles, Lebrado, McCauley, Michael. Row 3: Robbins, Salathé, Harding, Johnson, Muir, Bethel, then the stagecoach visitors. Row 4: the other visitors.*

## Art

- Every person has a 48×96 walking sheet in `assets/sprites/npcs/<id>.png`, laid out like the player's: 16×24 frames, with columns stand / step A / step B and rows down / up / left / right.
- The sheets are drawn in code by `tools/npcgen/npcgen.gd` from the looks in `tools/npcgen/looks.gd` (hair, hat, clothes, era props). To regenerate them:
  ```bash
  godot --headless --path . -s res://tools/npcgen/npcgen.gd
  godot --headless --path . --import
  ```
  You can replace any PNG with hand-drawn art in the same layout.
- Looks follow each person's era and period photographs. Native people are drawn in the everyday clothes they wore in photos from their time, **never regalia**. Their looks are placeholders pending tribal review, like their dialogue.
- Story item icons are in `assets/sprites/story_items.png`, drawn by the same tool.

## Placing people

NPCs go in a hub's story overlay (`scenes/story/content/<hub>.tscn`). Each NPC has:

| Property | What it does |
|---|---|
| `character` | A `CharacterData` from `data/characters/` |
| `spot` | A marker name in the hub (`camp_4`, `curry_village`, …). They follow the marker if the map is regenerated. |
| `offset` | Offset from the spot, so several people can share one |
| `wander_radius` | How far they stroll from where they start. 0 means they stay put. They stop and face you when you talk. |

`tests/cast_test.tscn` checks that everyone stands on open ground.

## The cast

✦ = flagged `needs_tribal_review`. Their dialogue is marked **[Placeholder dialogue pending tribal review]** and must be written or approved with the associated tribes before release.

| Person | Years | Where | Gives |
|---|---|---|---|
| **Galen Clark** | 1814–1910 | Lamon Homestead gate | The Register (start), The Last Page (ending) |
| **James Lamon** | 1817–1875 | Lamon Homestead | Lamon apples, dried apples |
| **Tenaya** ✦ | d. 1853 | Tenaya Creek, near Mirror Lake | A Register entry |
| **Tabuce (Maggie Howard)** ✦ | | The black oaks | Chuckah and acorn recipes |
| **Bridget Degnan** | | Degnan's Bakery | Bread, sourdough starter |
| **Dick Leonard** | 1908–1993 | Swan Slab, Camp 4 | Rope, harness, 2 cams |
| **Jules Eichorn** | 1912–2000 | Camp 4 | 2 cams, 2 quickdraws |
| **Bestor Robinson** | 1898–1987 | Camp 4 | (story only) |
| **Jennie Curry** | 1861–1948 | Camp Curry | Lamon apples |
| **James McCauley** | | Glacier Point | Bread, a Firefall entry |
| **Enid Michael** | 1883–1966 | Sentinel Dome | 3 cooking recipes |
| **Clare Marie Hodges** | 1890–1970 | Ranger station | 2 quickdraws |
| **Ansel Adams** | 1902–1984 | Best's Studio | 2 quickdraws |
| **George Anderson** | d. 1884 | Happy Isles | Anderson's eyebolt |
| **Royal Robbins** | 1935–2017 | Camp 4 | Belay device, 2 cams, 2 quickdraws |
| **Lucy Telles** ✦ | c. 1885–1955 | Yosemite Museum | Acorn cakes, a Register entry |
| **John Salathé** | 1899–1992 | Camp 4 | 2 cams (hard steel) |
| **Warren Harding** | 1924–2002 | El Capitan Meadow | Aiders, haul bag, the road to Tuolumne |
| **Beverly Johnson** | 1947–1994 | El Capitan Meadow | 2 ascenders, portaledge |
| **Maria Lebrado (Totuya)** ✦ | c. 1840–1931 | The meadow by the Ahwahnee | A Register entry |
| **John Muir** | 1838–1914 | Cathedral Lakes trailhead | Ice axe, crampons, pine nuts |
| **Carrie Bethel** ✦ | 1898–1974 | Soda Springs | Pine nuts |

Dates marked blank are unconfirmed. Every character's `sources` field lists what to verify. Royal Robbins died recently (2017), so confirm his portrayal with his family, following the living and recently deceased rule in STORY.md.

### Mountain Shop staff

Two invented people work at the Curry Village Mountain Shop. They're not historical figures and never appear in the Register, but unlike visitors they give quests (`staff = true`, listed in `QuestLog.STAFF`, in `data/characters/staff/`):

- **Marty Kessler** runs the counter (the shop's Vendor; quests reach him through the shop's `talk_target`, `mountain_shop`). He trades you the guidebook and fits you with your first kit.
- **Wren Alvarez** started at the shop this week, doesn't know anyone in the Valley, and waits at the foot of Firefall Slab with a rope, looking for a partner.

**Firefall Slab** is an invented route too: a stand-in for the many bolted friction climbs on the lower Glacier Point Apron, named for the Firefall that poured from the cliff above.

### Visitors

Visitors are everyday people from each era who wander the trails and roads: a stagecoach couple at Wawona (1880s), a railroad passenger at El Portal (1910s), a motorist (1920s), a CCC worker and an angler (1930s), a camper (1950s), a Camp 4 climber and a backpacker (1970s), and a landscape painter (1900s) at Glacier Point.

They're the **only** people in the game who aren't historical figures. So they:
- never give quests or appear in the Register (`visitor = true`),
- never stand in for a real person,
- are never Native. The game doesn't invent Native characters.

Talking to a visitor gets one random line.

## Places

| Place | Region · spot | Who's there |
|---|---|---|
| Lamon Homestead (your camp) | lamon_homestead · `gate`, `home` | Clark, Lamon (by your tent) |
| Camp 4 and Swan Slab | yosemite_village · `camp_4` | Leonard, Salathé, a Camp 4 climber; Swan Slab |
| Degnan's Bakery | yosemite_village · `degnans_bakery` | Bridget Degnan |
| Best's Studio | yosemite_village · `bests_studio` | Ansel Adams |
| Yosemite Museum | yosemite_village · `yosemite_museum` | Lucy Telles |
| Ranger station (Wilderness Center) | yosemite_village · `ranger_station` | Clare Hodges |
| Cook's Meadow | yosemite_village · `cooks_meadow` | a motorist |
| The black oaks | yosemite_valley | Tabuce |
| Camp Curry | curry_village · `registration_porch`, `apron_trailhead` | Jennie Curry, Jules Eichorn and Bestor Robinson (at the foot of the Apron trail), a camper, the Pavilion cook, a ranger-naturalist, a tourist; a shopper in the store and a climber in the Mountain Shop |
| El Capitan Meadow | yosemite_valley · `el_capitan_meadow` | Harding, Johnson; The Nose |
| Happy Isles | yosemite_valley · `happy_isles` | Anderson; Snake Dike |
| The Ahwahnee / Royal Arches | yosemite_valley · `the_ahwahnee` | Maria Lebrado; Royal Arches |
| The Ahwahnee grounds (walk north from the homestead: `ahwahnee_trail`, then `the_ahwahnee`) | the_ahwahnee · `front_door`, `rose_garden`, `tea_lawn`, `cascade`, `ahwahnee_meadow` | Royal Robbins and the Royal Arches start behind the hotel. The hotel's doors are still a sign, with no inside. |
| Mirror Lake | yosemite_valley · `mirror_lake` | Tenaya |
| Glacier Point Apron | yosemite_valley · `apron_base` | the Apron climb |
| Firefall Slab | curry_village · `apron_trailhead` | Wren Alvarez; the Firefall Slab climb. The lost rental shoes lie out front of the upper tent cabins. |
| Glacier Point | glacier_point | McCauley, Enid Michael, a painter |
| Tuolumne Meadows | tuolumne_meadows | Muir, Carrie Bethel, a backpacker; Cathedral Peak, Lyell Glacier |
| El Portal railyard | el_portal | The Model A axle (pickup), a railroad passenger |
| Wawona Hotel | wawona | The stagecoach couple |

Yosemite Village is the hand-made hub you arrive at when you drive to the Valley. Its buildings, the Village Store clerk, and the Camp 4 traders come from `tools/hubs`. Rebuilding that hub never touches the story overlay, `scenes/story/content/yosemite_village.tscn`.

## Quest chains

### The main line: the guidebook and its tick list

The main storyline is one chain of quests (marked ★ in the Journal). Each one ends on a **tick**: a route topped out and logged in the climbing guidebook. The giver hands over the reward when you report back, so no main quest finishes without a climb. The only exceptions are the first (fetching the guidebook) and the last (the ending).

Gear arrives in the order the routes need it, and a quest can hand over gear as each of its steps is finished (a step's `gear` key). `tests/cast_test.tscn` plays the chain and checks every climb's gear is in hand when it comes up.

```
★ 1  The Guidebook ........ Clark sends you to the Curry Village Mountain Shop.
★ 1a A Guidebook of Your Own  Marty Kessler (Mountain Shop) ... fetch the box from Jennie Curry, trade 20 energy of food → guidebook
                              Without it no route will start: you have no tick list to log it in.
★ 1b Fitted Out ............ Marty Kessler .................... lost rental shoes + 40 energy of food → climbing shoes,
                              chalk bag, harness, 5 quickdraws. Marty points you to Wren.
★ 1c Looking for a Partner . Wren Alvarez, foot of the Apron .. food, then TICK Firefall Slab (Wren belays, brings the rope)
★ 2  Rock Climbing Section  Leonard, Swan Slab ................ food, then TICK Swan Slab → rope, 2 cams
★ 3  Up the Apron .......... Eichorn, at Curry Village ........ TICK Glacier Point Apron → 2 cams, 2 quickdraws (and opens Glacier Point)
★ 4  The Cathedral Spires .. Eichorn; Robinson's story first .. TICK Higher Cathedral Spire → 2 quickdraws
★ 5  Clean Climbing ........ Robbins, at the Ahwahnee ......... TICK Royal Arches → belay device, 2 cams, 2 quickdraws
★ 6  Hard Steel ............ Salathé, Camp 4 ................. Model A axle from El Portal, then TICK Snake Dike → 2 cams
★ 7  The Nose .............. Harding, El Capitan Meadow ....... acorn cakes → aiders; food → haul bag;
                              then Beverly Johnson → ascenders + portaledge; then TICK The Nose → the road to Tuolumne
★ 8  Cathedral Peak ........ Muir, Tuolumne ................... TICK Cathedral Peak → ice axe, crampons
★ 9  Living Ice ............ Muir ............................ TICK Lyell Glacier
★ 10 The Last Page ......... Clark: after Lucy Telles's and Maria Lebrado's stories → you write the last page
                              (pick one of four entries, or leave it blank; it's saved and shown in the journal)
```

Geography is part of the progression. You leave the Lamon Homestead: south to Curry Village (guidebook, then the Apron behind it), north to the Ahwahnee (Royal Arches), then out across the Valley (Camp 4, Happy Isles, El Capitan Meadow) and finally up the Tioga Road.

### Side stories

These stay available alongside the main line, and every chapter opens at least two (`tests/cast_test.tscn` checks this). The ones that start at the rim (McCauley, Enid Michael, Hodges) open after the Apron.

```
Clark's guidebook errand ─┬─ Lamon: Lamon's Garden ............ onions + berries → 4 apples
                          │     └─ (after the Apron) Lamon: Laying By ... yampah + manzanita → dried apples, apples
                          ├─ Tenaya: Ahwahnee ✦ ............... carry his account to Clark → Register entry
                          └─ Degnan: Bread for the Valley ...... deliver to Leonard + Curry → 3 bread, starter
                                └─ Curry: Let the Bread Rise ... starter → 6 apples
Tabuce: Acorns for the Winter → The Chuckah ✦ .................. acorns → chuckah + acorn recipes (needed for the Nose)
After Swan Slab:
  Wren Alvarez: The Rest of the Apron ... food, then climb the Apron with Wren → chocolate, apricots
                                          (pays off Wren's promise; the same tick finishes Eichorn's quest)
  Ansel Adams: Monolith ........... climb the Apron to the rim, report back → 2 quickdraws
  Anderson: Anderson's Iron ....... food worth 60 energy → Anderson's eyebolt (keepsake)
After the Apron:
  McCauley: The Fall of Fire ...... ask Curry about the Firefall → 2 bread, Register entry
  Enid Michael: Leave Some Behind . 2 yerba buena → elderberry sauce, toasted toyon, manzanita cider recipes
  Hodges: Mounted Patrol .......... check on Anderson and Michael → 2 quickdraws
After Royal Arches:
  Robbins: Old Iron ............... show him Anderson's eyebolt, ask Harding about bolts, report back → wall food
  Anderson: The Top of the Dome ... climb Snake Dike, tell him about the summit → pilot bread
After the Nose (Tuolumne open):
  Beverly Johnson: Ten Days Alone . 4 pine nuts from the high country, pack 60 energy → apricots, chocolate
  Ansel Adams: High Country Light . ask Muir, climb to the Lyell Glacier, report back → trail mix, cheese
Other:
  Lucy Telles: The Big Basket ✦ ... her name in the Register → 2 acorn cakes
  Carrie Bethel: Over the Crest ✦ . 4 acorn flour → 10 pine nuts
  Maria Lebrado: Where the Villages Were ✦ ... carry her account to Clark → Register entry
```

### Gear curve

| Route | Needs | Comes from |
|---|---|---|
| Firefall Slab | climbing shoes, chalk bag, harness, 5 quickdraws (Wren brings the rope) | Marty Kessler (Mountain Shop) |
| Swan Slab | nothing (top rope) | start |
| Glacier Point Apron | rope, harness, 2 cams | + Leonard |
| Higher Cathedral Spire | rope, harness, 4 cams, 2 quickdraws | + Eichorn (Apron) |
| Royal Arches | + 4 cams, 4 quickdraws | + Eichorn (Spires) |
| Snake Dike | 2 cams, 6 quickdraws, belay device | + Robbins |
| The Nose | 8 cams, 6 quickdraws, 2 aiders, 2 ascenders, haul bag, portaledge | + Salathé, Harding, Johnson |
| Cathedral Peak | 4 cams, 4 quickdraws | (already have) |
| Lyell Glacier | + ice axe, crampons | + Muir |

The Mountain Shop and Camp 4 traders sell more of the same pieces for food, but never the one that opens a new tier.

### Materials

| Item | From | Used for |
|---|---|---|
| Lamon apple | Lamon, Jennie Curry | Climbing food (12 energy, keeps 12 days) |
| Degnan's bread | Degnan, McCauley | Climbing food (25 energy, keeps 4 days) |
| Sourdough starter | Degnan | Jennie Curry's quest |
| Rental climbing shoes | Pickup by the Curry Village tent cabins | Marty Kessler's *Fitted Out* |
| Anderson's eyebolt | Anderson | Robbins's *Old Iron* (shown, not taken; a keepsake) |
| Model A axle | Pickup at the El Portal railyard | Salathé forges it into cams |
| Pine nuts | Carrie Bethel, Muir | High-country food (20 energy, keeps 30 days) |

### New quest mechanics

- **Guidebook and ticks:** `Guidebook` (`scripts/story/guidebook.gd`) lists every route with its grade and gear. A step with `"unlock": "guidebook"` hands it over, and `ClimbStart` won't start a route without it. `QuestData.main_line` marks the main story. A step can also carry `gear`, `unlock`, or `items` to hand over when it's done. A shop's `talk_target` lets a quest send you to a shopkeeper.
- **`pay` step:** trade food worth `energy` when you turn it in (the soonest to spoil goes first). The Mountain Shop uses it to sell the guidebook and the starter kit.
- **Partners:** `RouteData.partner_quest` names a quest whose giver is your partner. The route only starts while that quest is underway or done (Firefall Slab: Wren's *Looking for a Partner*).
- **Bolted routes:** `RouteData.protection = "bolts"` puts a bolt every 2 moves on the line; each takes a quickdraw.
- **`return` step:** done as soon as you talk to the quest giver again. It closes delivery rounds ("take bread to Leonard and Curry, then come back").
- **`hub:<id>` unlock reward:** opens a locked hub. Harding's *The Nose* uses `hub:tuolumne_meadows`.
- **Story pickups** (`scenes/story/pickup.tscn`): a one-of-a-kind item lying in the park, picked up once and remembered in the save. Give each one a unique node name.

## Before release

- **Tribal review** for Tenaya, Tabuce, Lucy Telles, Maria Lebrado, and Carrie Bethel: their looks, dialogue, the acorn and pine nut practices, and the Register entries about Ahwahnee and the village sites. It covers whether each person appears at all.
- **Verify** every character's `sources`, and fill in the blank dates (Degnan, McCauley, Tabuce).
- **Permission:** Royal Robbins's family (he died in 2017).
- **Confirm** the Firefall's origin story (McCauley's family is the usual account, and it's told several ways).
