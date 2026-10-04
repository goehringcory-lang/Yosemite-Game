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
| **James Lamon** | 1817–1875 | Lamon Homestead | Lamon apples |
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
| **Maria Lebrado (Totuya)** ✦ | c. 1840–1931 | Near the Ahwahnee | A Register entry |
| **John Muir** | 1838–1914 | Cathedral Lakes trailhead | Ice axe, crampons, pine nuts |
| **Carrie Bethel** ✦ | 1898–1974 | Soda Springs | Pine nuts |

Dates marked blank are unconfirmed. Every character's `sources` field lists what to verify. Royal Robbins died recently (2017), so confirm his portrayal with his family, following the living and recently deceased rule in STORY.md.

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
| Lamon Homestead (your camp) | lamon_homestead | Clark, Lamon |
| Camp 4 and Swan Slab | yosemite_village · `camp_4` | Leonard, Eichorn, Robinson, Robbins, Salathé, a Camp 4 climber; Swan Slab |
| Degnan's Bakery | yosemite_village · `degnans_bakery` | Bridget Degnan |
| Best's Studio | yosemite_village · `bests_studio` | Ansel Adams |
| Yosemite Museum | yosemite_village · `yosemite_museum` | Lucy Telles |
| Ranger station (Wilderness Center) | yosemite_village · `ranger_station` | Clare Hodges |
| Cook's Meadow | yosemite_village · `cooks_meadow` | a motorist |
| The black oaks | yosemite_valley | Tabuce |
| Camp Curry | curry_village · `registration_porch` | Jennie Curry, a camper, the Pavilion cook, a ranger-naturalist, a tourist; a shopper in the store and a climber in the Mountain Shop |
| El Capitan Meadow | yosemite_valley · `el_capitan_meadow` | Harding, Johnson; The Nose |
| Happy Isles | yosemite_valley · `happy_isles` | Anderson; Snake Dike |
| The Ahwahnee / Royal Arches | yosemite_valley · `the_ahwahnee` | Maria Lebrado; Royal Arches |
| The Ahwahnee grounds (walk north from the homestead: `ahwahnee_trail`, then `the_ahwahnee`) | the_ahwahnee · `front_door`, `rose_garden`, `tea_lawn`, `cascade`, `ahwahnee_meadow` | No one yet: the hotel's doors are a sign, and its grounds have no inside. Stoneman Meadow (`ahwahnee_trail` · `meadow`, `bridge_east`) is empty too. |
| Mirror Lake | yosemite_valley · `mirror_lake` | Tenaya |
| Glacier Point Apron | yosemite_valley · `apron_base` | the Apron climb |
| Glacier Point | glacier_point | McCauley, Enid Michael, a painter |
| Tuolumne Meadows | tuolumne_meadows | Muir, Carrie Bethel, a backpacker; Cathedral Peak, Lyell Glacier |
| El Portal railyard | el_portal | The Model A axle (pickup), a railroad passenger |
| Wawona Hotel | wawona | The stagecoach couple |

Yosemite Village is the hand-made hub you arrive at when you drive to the Valley. Its buildings, the Village Store clerk, and the Camp 4 traders come from `tools/hubs`. Rebuilding that hub never touches the story overlay, `scenes/story/content/yosemite_village.tscn`.

## Quest chains

All gear comes from quests. Other quests trade in **materials**: food and one-of-a-kind items that you carry from one person to another. `tests/cast_test.tscn` walks the chain and checks that every climb's gear is in hand by the time a quest asks for it.

```
Chapter 1 · Arrival (Valley floor)
  Clark: The Guardian's Register ─┬─ Lamon: Lamon's Garden ............ onions + berries → 4 apples
                                  ├─ Tenaya: Ahwahnee ✦ ............... carry his account to Clark → Register entry
                                  └─ Degnan: Bread for the Valley ...... deliver to Leonard + Curry → 3 bread, starter
                                        └─ Curry: Let the Bread Rise ... starter → 6 apples
  Tabuce: Acorns for the Winter → The Chuckah ✦ ........................ acorns → chuckah + acorn recipes
  Leonard: The Rock Climbing Section ................................... Swan Slab + trail food → rope, harness, 2 cams
      ▼ climb the Glacier Point Apron → Glacier Point

Chapter 2 · The rim (all need Leonard's quest)
  McCauley: The Fall of Fire ...... ask Curry about the Firefall → 2 bread, Register entry
  Enid Michael: Leave Some Behind . 2 yerba buena → elderberry sauce, toasted toyon, manzanita cider recipes
  Hodges: Mounted Patrol .......... check on Anderson and Michael → 2 quickdraws
  Ansel Adams: Monolith ........... climb the Apron, report back → 2 quickdraws

Chapter 3 · The domes
  Eichorn: The Cathedral Spires ... lead the Apron, hear Robinson → 2 cams, 2 quickdraws
  Anderson: Anderson's Iron ....... food worth 60 energy → Anderson's eyebolt (material)
  Robbins: Clean Climbing ......... show the eyebolt, climb Royal Arches → belay device, 2 cams, 2 quickdraws
      ▼ Snake Dike → the top of Half Dome

Chapter 4 · The big walls
  Lucy Telles: The Big Basket ✦ ... her name in the Register → 2 acorn cakes
  Salathé: Hard Steel ............. Snake Dike + the Model A axle from El Portal → 2 cams
  Harding: Siege Supplies ......... 4 batches of acorn cakes + 150 energy of food → aiders, haul bag
  Johnson: Self-Reliance .......... 30 acorns stored + 2 acorn cakes → ascenders, portaledge
  Harding: The Nose ............... climb the Nose → Tioga Road opens (hub:tuolumne_meadows)

Chapter 5 · High country
  Muir: Cathedral Peak ............ food + Cathedral Peak → ice axe, crampons
  Carrie Bethel: Over the Crest ✦ . 4 acorn flour → 10 pine nuts
  Muir: Living Ice ................ Lyell Glacier → pine nuts, Register entry
  Maria Lebrado: Where the Villages Were ✦ ... carry her account to Clark → Register entry

Chapter 6 · The last page
  Clark: The Last Page ............ ask Tabuce and Lebrado what they want written (and what they'd rather keep) → ending
```

### Gear curve

| Route | Needs | Earliest source |
|---|---|---|
| Swan Slab | nothing (top rope) | start |
| Glacier Point Apron | rope, harness, 2 cams | Leonard |
| Royal Arches | + 4 cams, 4 quickdraws | + Eichorn |
| Snake Dike | + belay device, 6 quickdraws | + Robbins, and Hodges or Adams |
| Cathedral Peak | 4 cams, 4 quickdraws | (already have) |
| The Nose | 8 cams, 6 quickdraws, 2 aiders, 2 ascenders, haul bag, portaledge | + Salathé, Harding, Johnson |
| Lyell Glacier | + ice axe, crampons | + Muir |

The side quests from Hodges and Adams matter. You need at least one of them to have enough quickdraws for Snake Dike and the Nose.

### Materials

| Item | From | Used for |
|---|---|---|
| Lamon apple | Lamon, Jennie Curry | Climbing food (12 energy, keeps 12 days) |
| Degnan's bread | Degnan, McCauley | Climbing food (25 energy, keeps 4 days) |
| Sourdough starter | Degnan | Jennie Curry's quest |
| Anderson's eyebolt | Anderson | Robbins's quest (shown, not taken; a keepsake) |
| Model A axle | Pickup at the El Portal railyard | Salathé forges it into cams |
| Pine nuts | Carrie Bethel, Muir | High-country food (20 energy, keeps 30 days) |

### New quest mechanics

- **`return` step:** done as soon as you talk to the quest giver again. It closes delivery rounds ("take bread to Leonard and Curry, then come back").
- **`hub:<id>` unlock reward:** opens a locked hub. Harding's *The Nose* uses `hub:tuolumne_meadows`.
- **Story pickups** (`scenes/story/pickup.tscn`): a one-of-a-kind item lying in the park, picked up once and remembered in the save. Give each one a unique node name.

## Before release

- **Tribal review** for Tenaya, Tabuce, Lucy Telles, Maria Lebrado, and Carrie Bethel: their looks, dialogue, the acorn and pine nut practices, and the Register entries about Ahwahnee and the village sites. It covers whether each person appears at all.
- **Verify** every character's `sources`, and fill in the blank dates (Degnan, McCauley, Tabuce).
- **Permission:** Royal Robbins's family (he died in 2017).
- **Confirm** the Firefall's origin story (McCauley's family is the usual account, and it's told several ways).
