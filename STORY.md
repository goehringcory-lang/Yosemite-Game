# Story: The Guardian's Register

This is the narrative frame for [docs/DESIGN.md](docs/DESIGN.md), which covers climbing, gear, food, and real geography. DESIGN.md sets the mechanics, and this file sets the story.

## Premise

In 1866, California named Galen Clark the first **Guardian of Yosemite**. In this game, Clark gives the player a battered logbook, the **Guardian's Register**, on their first morning in the valley. His instructions are simple: go meet the people of this place, listen, and write down what they tell you.

The player camps at the Lamon Homestead and sets out across Yosemite. Everyone they meet is a real person from the park's history: Ahwahneechee and Paiute people, settlers, rangers, naturalists, and climbers. These people share their stories and teach the player what they know. As the player earns their trust, they hand over the gear that gets the player up the walls and into new parts of the park.

The Register fills up as the game goes on. It starts as Clark's book, and by the end it holds many voices, some of which disagree with each other. The player comes to understand that no single person was ever the valley's guardian. It was always many people, and many of them were never asked to write in the book.

## The timeline: a timeless valley

People from 1851 to the 1970s share a single season. Tenaya, John Muir, Dick Leonard, and Warren Harding are all in the valley at once, each living in their own era: their own clothes, their own tools, their own concerns. The game never explains this. There's no time travel, magic, or ghosts. It's a storytelling convention, like a museum where every exhibit is alive.

Rules that keep this honest:
- **Everyone is equally "out of time."** Native people are never presented as spirits, memories, or a vanished people while settlers and climbers are presented as real. Everyone is a living person going about their work.
- **People speak from their own era.** Muir doesn't know about the Nose, and Leonard doesn't know about cams. When the player gets gear from someone, it's described as "what they can spare from their kit." The game simplifies gear to its modern version so the mechanics stay clear.
- **Every story ends with a Register note** that says what really happened and what was dramatized, with sources. When a quest writes a page in the Register, the narrator says so ("New in the Register: a page from Dick Leonard.") and reads its note before the rewards, and the journal shows the note under the page. The notes live in `RegisterPages.HISTORY` (`scripts/story/register_pages.gd`): documented dates and events first, then what's dramatized. Living people aren't named in them, and notes on Native people's pages say they're placeholders pending tribal review. `tests/story_test.tscn` checks that every page has one.

## Tone

Cozy, curious, and grounded, with real awe at scale: a tent at dawn under Half Dome, a night on a portaledge on El Cap. Walking, gathering, cooking, climbing, and listening are all ways of learning the valley. Hard history is told plainly and never played for drama.

## The player

A newcomer with a tent and a pair of approach shoes. They have no destiny and no special heritage. What they bring is a willingness to show up, carry things, and listen. At first they treat the Register as a checklist of people to meet. Over time they learn that each story belongs to the person telling it, and that some people will choose not to share theirs.

## The main storyline: the tick list

The player's way through the story is the **climbing guidebook**. Clark's first errand sends them to the Mountain Shop in Curry Village. The clerk, Marty Kessler, has them fetch the new printing from the Registration porch and trade food for a guidebook listing every route, its grade, and the gear it takes. Then Marty fits them with a starter kit (climbing shoes, a chalk bag, a harness, and five quickdraws) in exchange for food and a pair of lost rental shoes, and sends them to Wren Alvarez, a new hire looking for a climbing partner. Wren belays the player up **Firefall Slab**, a bolted route on the Glacier Point Apron, and that's the first tick. A route counts only when the player tops it out and ticks it. Every main-line quest after the shop errands ends on a tick, and the person who gave the quest hands over the next piece of gear when they hear about it. The ticks climb the Yosemite Decimal System one grade at a time, so the player feels themselves getting stronger: Firefall Slab (5.5), Swan Slab (5.6), the Glacier Point Apron (5.7), Nutcracker (5.8), Higher Cathedral Spire (5.9), the Steck-Salathé on Sentinel Rock (5.10b), Astroman on Washington Column (5.11c), Separate Reality (5.12a), and the Nose of El Capitan, climbed free (5.13 on the game's ladder; the real free grade is 5.14a). Then the high country: Cathedral Peak and the Lyell Glacier, where the grade matters less than the altitude. Royal Arches and Snake Dike are side stories, classics off the ladder. The full chain is in [docs/CAST.md](docs/CAST.md#quest-chains). Side stories (the people who aren't on the main line) come alongside it.

## Story arc

The chapters follow DESIGN.md's gear tiers. The seasons pace the story: acorns drop in fall, and snow closes the high country in winter.

The full cast (who lives where, with sprites) and every quest chain, with the gear and materials each one trades, are in [docs/CAST.md](docs/CAST.md).

### 1. Arrival: the Valley floor (Tier 0, Spring)

- **Galen Clark** gives the player the Register and his own account of the 1864 Yosemite Grant: Lincoln signing the valley and the Big Tree Grove over to California "for public use, resort and recreation," and the State making him Guardian two years later. He asks the player to write down who told them each story, not just what.
- **James Lamon**, whose cabin and apple orchard became the player's camp, tells how he settled in the valley in the late 1850s.
- **Tenaya's** story comes early and is told plainly. The Ahwahneechee were living in Ahwahnee when the Mariposa Battalion entered it in 1851, and they were forced out. The Grant was signed 13 years later. Clark's first pages leave this out, and noticing that gap sets the direction of the game.
- **Tabuce (Maggie Howard)** teaches the player to gather acorns, build a chuckah, and prepare acorn food. The skill starts now but pays off in the fall (quests: *Acorns for the Winter*, *The Chuckah*).
- At the Mountain Shop the player earns a guidebook and a starter kit, and leads **Firefall Slab** with **Wren Alvarez** on belay. Marty and Wren are invented shop staff, not historical figures: they never appear in the Register.
- The player boulders at Camp 4 and climbs Swan Slab, where **Dick Leonard** belays them from above.

### 2. The rim: Glacier Point (Tier 1, late Spring)

- **Dick Leonard, Jules Eichorn, and Bestor Robinson** of the Sierra Club Rock Climbing Section teach the player to belay. Then they hand over a rope and 2 cams (quest: *The Rock Climbing Section*).
- The **Glacier Point Apron** leads up to the rim.
- At the top: **David and Jennie Curry** and the Firefall (which ended in 1968). People in the game disagree about whether it was a wonder or a spectacle, and the game doesn't pick a side.
- **Clare Marie Hodges**, Yosemite's first woman ranger (1918), and **Enid Michael**, a naturalist who teaches which plants can be gathered and which should be left alone.

### 3. Domes and walls: 5.8 to 5.10 (Tier 2, Summer)

- **Royal Robbins** and the clean-climbing ethic ask whether you can climb without damaging the rock. He sends the player up **Nutcracker** (5.8) with nothing but removable protection, explains how the decimal grades were worked out, and gives them more cams and a belay and rappel device.
- **Higher Cathedral Spire** (5.9), the Rock Climbing Section's 1934 route.
- **John Salathé's** own route, the **Steck-Salathé** on Sentinel Rock (5.10b).
- **Royal Arches** and **Snake Dike** are side stories: long, easy classics off the ladder.
- **George Anderson** drilled his way up Half Dome in 1875. His story is about the marks people leave: bolts, cables, trails, and place names.

### 4. The big walls: 5.11 to 5.13 (Tier 3, Summer into Fall)

- **John Salathé**, the blacksmith who forged hard steel pitons.
- **Beverly Johnson**, the first woman to solo El Cap (1978), teaches self-reliance. She sends the player up **Astroman** (5.11c), then gives them ascenders and a portaledge.
- **Royal Robbins** sends them out a roof: **Separate Reality** (5.12a).
- **Warren Harding** and the Nose (1958). He hands over aiders and a haul bag and makes the case for fixed ropes and siege tactics. Then he dares the player to climb it free, at 5.13.
- Climbs that last several days make food matter. The acorns stored in the chuckah in fall become the acorn cakes that get the player up the wall.
- **Lucy Telles** at the Yosemite Museum, with her weaving and the work of feeding a family.

### 5. High country: Tuolumne and Mono Lake (Tier 4, the next Summer)

- **John Muir** on Cathedral Peak (1869), which he called his first time at church in California, and the living glaciers he found: he staked the Maclure ice in 1872 and watched it move, against Josiah Whitney's claim that the Valley floor simply sank. He came up that first summer with a sheep drive, and says so. He gives the player an ice axe and crampons. His Register page admits what he didn't see, and its note says plainly that his writing often dismissed Native people.
- Over the crest are the **Mono Lake Kutzadika'a** and Paiute trade routes, with pine nuts carried over the passes. **Carrie Bethel's** weaving shows that the valley was always connected to places far beyond it.
- **Maria Lebrado (Totuya)**, Tenaya's granddaughter, returned to the valley in 1929 and identified the village sites. Her story is the emotional turning point: the record gets corrected by the people it left out.

### 6. Return: the last page (Fall)

The player brings the Register back to Galen Clark. The ending is **not** the player becoming the next Guardian. Instead, the player sees how the book has changed: Clark's single account has become many voices that don't always agree. It includes stories told in full, stories told in part, and blank spaces for the stories people chose not to share.

Clark's last talk is personal: he came up into these mountains in 1856 expecting to die of his lungs, lived another fifty years, and spent them thinking he was the one looking after the place. He sends the player to ask Tabuce and Maria Lebrado whether they want anything written, and both ask for blank pages.

The player adds one final entry of their own and can choose what it says: every voice they heard, a thank-you, the tick list, or a blank page like the ones Tabuce and Maria Lebrado asked for. Clark leafs back through the book (how many pages, in how many hands, with Tenaya's still at the front), hands it back ("when you read it, start at the front"), and the season turns. Looking after the valley doesn't end, and it was never one person's job. A closing line tells the player the story is over and that the valley stays open: the tick list isn't finished, and the people they met still have things to say.

### Between the chapters: story beats

People don't only speak when they have a quest. As the main line moves on, the people the player keeps passing react to it, once each, before going back to their usual lines (`CharacterData.story_beats`; only the latest piece of news is told, so someone who rushes ahead never hears stale news). Galen Clark, at the homestead gate, carries most of these: he reacts to the guidebook, the first tick, Glacier Point, Robbins's "leave no mark" (his own name is on Mount Clark, though every peak had a name before the surveyors), Salathé's steel, the Nose, and the return from the glacier, where he reminds the player that not everybody walks up to the gate. The climbing mentors, Wren, Lamon, Jennie Curry, Bridget Degnan, and Muir also have beats, and after the last page each of them says goodbye in their own voice, so the whole valley acknowledges the ending. Native characters have no story beats yet: any new lines for them wait on tribal review.

## The seven associated tribes

The Ahwahneechee and all seven tribes traditionally associated with Yosemite should be part of the story. Their historical figures appear in the chapters above. How each nation appears should be worked out with that nation, including which people, which stories, and whether any at all:

1. American Indian Council of Mariposa County (Southern Sierra Miwuk Nation)
2. Tuolumne Band of Me-Wuk Indians
3. Picayune Rancheria of the Chukchansi Indians
4. North Fork Rancheria of Mono Indians
5. Mono Lake Kutzadika'a Tribe
6. Bishop Paiute Tribe
7. Bridgeport Indian Colony

The game doesn't invent Native characters. Present-day tribal voices come through the review process, through Register notes written with the tribes, and through credits, not through fictional stand-ins.

## Gameplay fit

- **Climbing** is how the story reaches new places. Each tier's big climb comes at a turning point in a chapter.
- **Gear** comes from the people you meet, once they trust you with it, or in trades with the Camp 4 climbers, who swap spare gear for food. It's never bought with money.
- **Food** ties the seasons to the plot. Acorns stored in the fall are what get you up El Cap, and fresh forage gets you through day climbs.
- **Seasons and road closures** are story gates the player can see and understand.
- **The Register** is the quest log and journal. Entries fill in, get annotated, and get contradicted as you hear more people.
- **Choices** decide who you help first, which accounts you trust, and what you write at the end. Native characters' rights and belonging are never the player's decision.

## Writing guardrails

- **Dramatized history.** Stick to documented facts. Where you invent dialogue, keep it plausible and respectful, and let each Register note say what's documented and what isn't.
- **Real people's rights.** Portray deceased historical figures respectfully. Living and recently deceased people (for example Chouinard, Jardine, Lynn Hill, and Julia Parker) appear only with permission.
- **Native content** gets tribal review before it ships. Characters and dialogue carry `needs_tribal_review` until then. Use each nation's preferred spelling. Don't use ceremonies, sacred stories, regalia, or sacred objects as quest material.
- **Don't cast settlers and climbers as simple heroes.** Clark, Muir, and the Grant are part of the history of removal as well as protection. Let people see that differently.
- **No "pristine wilderness saved by one outsider."** People have always lived in, shaped, and looked after this valley.

## Facts to verify before writing

- Galen Clark appointed Guardian (1866), the Yosemite Grant (1864), Clark's Station at Wawona.
- James Lamon's arrival date and his orchard at what's now Curry Village.
- The Mariposa Battalion (1851) and Tenaya's later life. Use sources reviewed with tribal advisors.
- Maria Lebrado's 1929 visit and the sites she identified.
- Maggie "Tabuce" Howard, Lucy Telles, and Carrie Bethel: dates and their work at the Yosemite Museum.
- David and Jennie Curry, and the Firefall's dates and end (1968).
- Rock Climbing Section history and the first ascent of Higher Cathedral Spire (1934), Royal Arches (1936), Anderson on Half Dome (1875), Robbins on the NW Face (1957), Harding on the Nose (1958), Snake Dike (1965), Johnson's solo (1978). Nutcracker (Royal and Liz Robbins, 1967), the Steck-Salathé (1950), the East Face of Washington Column (1959) and its free ascent as Astroman (1975), Separate Reality's free ascent (1978) and its grade (5.11d or 5.12a), and the Nose's first free ascent (1993) and grade.
- Muir on Cathedral Peak (1869) and his glacier work (early 1870s): the Maclure Glacier stakes (1872), the Whitney dispute, and the "mere sheepherder" remark as it's usually told.
- Clark's own account of coming to the mountains in 1856 to die, his 1857 count of the Mariposa Grove, and Mount Clark's naming.
- Harding's summit night on the Nose (bolts up the final headwall, topping out November 12, 1958) and his "who was conqueror" line, from his own account.
- The Royal Arches first-ascent party (1936). Bestor Robinson's side story names Morgan Harris, Ken Adam, and Ken Davis, and other accounts name Hervey Voge as the third; check it against the sources.
