class_name RegisterPages
extends RefCounted
## The Guardian's Register as the player has filled it: one page per story
## heard, shown in the Journal. A page appears when its quest is finished.
##
## Pages marked "front" go before Clark's own page: Tenaya told Clark to write
## his account "at the front of the book, not the back", and Clark says the
## same of Maria Lebrado's. "notes" are later hands in the margin, so a page
## can be annotated or contradicted as the player hears more people.
## "review" pages carry Native people's words and are placeholders until
## tribal review, like their dialogue. Each story also carries a Register
## note (HISTORY) saying what's documented and what's dramatized.

const PAGES: Array[Dictionary] = [
	{"quest": "tenaya_ahwahnee", "front": true, "review": true, "by": "Tenaya",
		"text": "Our villages were here. In 1851 soldiers came, burned our homes and our food, and made us leave."},
	{"quest": "lebrado_villages", "front": true, "review": true, "by": "Maria Lebrado (Totuya)",
		"text": "She was a girl in 1851 when the soldiers came. She remembers where the villages stood: by the river, and below the cliffs."},
	{"quest": "clark_register", "by": "Galen Clark",
		"text": "1864: the valley and the Big Tree Grove granted to California, 'for public use, resort and recreation.' 1866: the State made me Guardian. These pages record what happens here.",
		"notes": [
			{"quest": "tenaya_ahwahnee", "text": "In the margin, in Clark's hand: My pages start after 1851, as if nothing came before."},
			{"quest": "lebrado_villages", "text": "Below that: The places I thought were just meadows were homes. My pages were wrong."},
		]},
	{"quest": "lamon_orchard", "by": "James Lamon",
		"text": "Planted apples on the valley floor. Apples keep.",
		"notes": [
			{"quest": "lamon_winter", "text": "Added later: I didn't learn to lay food by on my own. The people here had been doing it for a very long time."},
		]},
	{"quest": "tabuce_chuckah", "review": true, "by": "Tabuce (Maggie Howard)",
		"text": "Gather acorns in the fall and keep them in a chuckah. Pound them, rinse the flour until the bitterness is gone, and cook it with hot stones."},
	{"quest": "degnan_bread", "by": "Bridget Degnan",
		"text": "Bread for the climbers and the camps. Her starter is older than some of those climbers."},
	{"quest": "leonard_belay", "by": "Dick Leonard",
		"text": "Everything depends on the belay. Let the rope run a little, and you catch your partner gently."},
	{"quest": "eichorn_spires", "by": "Jules Eichorn",
		"text": "1934: Higher Cathedral Spire, with Dick and Bestor and thirty-odd pitons. Everyone said it couldn't be done."},
	{"quest": "bestor_arches", "by": "Bestor Robinson",
		"text": "The Royal Arches, sixteen pitches to the north rim. Not a step up the scale, a step out."},
	{"quest": "mccauley_firefall", "by": "James McCauley",
		"text": "The Firefall: embers pushed off Glacier Point every summer evening, falling like a waterfall of light.",
		"notes": [
			{"quest": "mccauley_firefall", "text": "Underneath, from Jennie Curry: some say it's the finest sight in the park, and some say it's a circus trick. McCauley: Both are true."},
		]},
	{"quest": "enid_leave_some", "by": "Enid Michael",
		"text": "Learn a plant before you gather it, and never take the last one in a patch. People here worked this out over thousands of years."},
	{"quest": "hodges_patrol", "by": "Clare Marie Hodges",
		"text": "Ranger. Yes, a woman ranger. The bears got used to it."},
	{"quest": "ansel_monolith", "by": "Ansel Adams",
		"text": "You can't really see this valley from the floor. The light on Half Dome lasts about an hour.",
		"notes": [
			{"quest": "ansel_high_country", "text": "Added after the high country: That country was never empty. It only looked empty to some of us."},
		]},
	{"quest": "anderson_half_dome", "by": "George Anderson",
		"text": "Up the back of Half Dome, 1875: a hole, an eyebolt, a step, another hole."},
	{"quest": "robbins_clean", "by": "Royal Robbins",
		"text": "Every bolt and piton leaves a mark, and the next party climbs the rock we leave behind. Climb it clean.",
		"notes": [
			{"quest": "robbins_eyebolt", "text": "Warren Harding, across the page: A route should be climbed. Robbins, below him: It costs the rock something. Write both down."},
			{"quest": "robbins_roof", "text": "Added after Separate Reality: Upside down over the river, and nothing left behind. That's the whole idea."},
		]},
	{"quest": "salathe_steel", "by": "John Salathé",
		"text": "Pitons forged from Model A axles, because soft iron bends. Sentinel Rock, 1950, with Allen Steck."},
	{"quest": "johnson_astroman", "by": "Beverly Johnson",
		"text": "If you can climb Astroman, you can live on a big wall.",
		"notes": [
			{"quest": "johnson_solo", "text": "Added later: Scared and ready aren't opposites."},
		]},
	{"quest": "harding_summit", "by": "Warren Harding",
		"text": "The Nose, 1958: forty-seven days, pitons, bolts, and a lot of wine. At the top it wasn't clear who had conquered whom. El Cap looked in better shape than I did."},
	{"quest": "lucy_basket", "review": true, "by": "Lucy Telles",
		"text": "Her name, written in her own hand."},
	{"quest": "muir_cathedral", "by": "John Muir",
		"text": "Cathedral Peak, 1869. This, I may say, is the first time I have been at church in California."},
	{"quest": "muir_glacier", "by": "John Muir",
		"text": "Glaciers made this valley. I didn't always see the people who lived here, and they saw a great deal I missed."},
	{"quest": "bethel_trade", "review": true, "by": "Carrie Bethel",
		"text": "The valley was never cut off. People came and went over the passes long before any road."},
	# Side stories for the seasons, the hours, and the hubs past the Valley.
	{"quest": "clark_big_trees", "by": "Galen Clark",
		"text": "The Mariposa Grove, 1857: I counted the big trees and built a cabin among them. Few young ones come up, and I can't say why."},
	{"quest": "enid_dawn_chorus", "by": "Enid Michael",
		"text": "A dawn count at Sentinel Dome: chickadees, juncos, a Clark's nutcracker. Ordinary days are worth writing down."},
	{"quest": "hodges_bear_season", "by": "Clare Marie Hodges",
		"text": "Fall is bear season. Store food high and covered, pick up the windfalls, and don't teach a bear where you keep your supper.",
		"notes": [
			{"quest": "hodges_bear_season", "text": "Below, from James Lamon: a sow and two cubs in the orchard every night. I pick up the windfalls now."},
		]},
	{"quest": "degnan_snowbound", "by": "Bridget Degnan",
		"text": "Winter: the stage roads close, but the railroad runs. The flour comes up the canyon to El Portal."},
	{"quest": "muir_soda_springs", "by": "John Muir",
		"text": "Soda Springs, 1889: a campfire with Robert Underwood Johnson. He asked why this country wasn't a park. In 1890 it was."},
	{"quest": "clark_last_page", "review": true, "by": "Tabuce (Maggie Howard)",
		"text": "A blank page, kept at her request. Some things stay with her family."},
	{"quest": "clark_last_page", "review": true, "by": "Maria Lebrado (Totuya)",
		"text": "A blank page. The rest belongs to her people."},
]


## Register notes: what really happened, and what the game made up. STORY.md
## asks that every story end with one. Keyed by the quest that writes the
## page; the note goes on that quest's first page. Keep them plain and
## checkable: dates and events that are documented, then what's dramatized.
## Native people's notes stay placeholders until tribal review, like their
## pages. Living people aren't named (STORY.md, "Real people's rights").
const HISTORY := {
	"tenaya_ahwahnee": "In March 1851 the Mariposa Battalion, a state-backed militia, entered the valley, burned villages and stored food, and forced the Ahwahneechee out. That spring Tenaya's youngest son was killed. Tenaya's words in this game are a placeholder pending tribal review by the associated tribes. Bunnell's Discovery of the Yosemite (1880), written by a Battalion member, has to be read critically.",
	"lebrado_villages": "Documented: in 1929 Maria Lebrado, Tenaya's granddaughter, came back to the valley and identified village sites for park staff. Which sites, and how her account is told, waits on tribal review; her words here are a placeholder.",
	"clark_register": "Documented: Lincoln signed the Yosemite Grant on June 30, 1864, and the state's commissioners named Galen Clark Guardian in 1866. Dramatized: the Register itself, which is invented for the game, and Clark's words.",
	"lamon_orchard": "Documented: James Lamon settled at the upper end of the valley around 1859 and planted apple trees there; some still grow near Curry Village. His words here are dramatized.",
	"tabuce_chuckah": "Documented: Maggie Howard (Tabuce) demonstrated acorn preparation and basketry for visitors at the Yosemite Museum for many years. The steps here are simplified for the game, and how they're told waits on tribal review.",
	"degnan_bread": "Documented: Bridget and John Degnan settled in the valley in 1884, and the bread she baked in her kitchen grew into Degnan's bakery and store. Dramatized: her deliveries to climbers, who came decades later.",
	"leonard_belay": "Documented: Dick Leonard learned rope work from Robert Underhill's 1931 Sierra Club Bulletin article, started the Cragmont Climbing Club in Berkeley in 1932, and championed the dynamic belay. Dramatized: Swan Slab as a Section practice day. They mostly practiced on the Berkeley crags, and the grades here are modern.",
	"eichorn_spires": "Documented: Leonard, Eichorn, and Robinson made the first ascent of Higher Cathedral Spire in April 1934, with pitons and carabiners ordered from Europe. Dramatized: the exact piton count and who had the idea. Today it's climbed free at 5.9.",
	"bestor_arches": "Documented: Rock Climbing Section members, Morgan Harris and Kenneth Adam among them, first climbed the Royal Arches in 1936. Bestor wasn't on that climb, and his notebook here is dramatized.",
	"mccauley_firefall": "Documented: James McCauley paid for the Four Mile Trail (1872) and ran the Mountain House at Glacier Point. The Firefall is usually traced to his family, David Curry made it a nightly show, and the Park Service ended it in January 1968. Its start is told several ways.",
	"enid_leave_some": "Documented: Enid Michael worked as a seasonal ranger-naturalist from 1921 to 1942, kept the Museum's wildflower garden, and wrote hundreds of nature notes. Her lines here are dramatized.",
	"hodges_patrol": "Documented: Clare Marie Hodges was hired in 1918 as Yosemite's first woman ranger and patrolled on horseback. Dramatized: the patrol errand.",
	"ansel_monolith": "Documented: Ansel Adams made 'Monolith, the Face of Half Dome' from the Diving Board in April 1927. Dramatized: his quickdraws, which came long after his time.",
	"anderson_half_dome": "Documented: George Anderson, a Scottish-born blacksmith, reached the top of Half Dome in October 1875 by drilling holes, setting iron pins, and roping between them. Later cables roughly follow his line. His beans are dramatized.",
	"robbins_clean": "Documented: Royal and Liz Robbins made the first ascent of Nutcracker in 1967, protecting it with nuts to show that clean climbing worked. Robbins was among the Tahquitz climbers who worked out the decimal grades in the 1950s. His lines here are dramatized; his portrayal is to be confirmed with his family.",
	"salathe_steel": "Documented: John Salathé and Allen Steck climbed Sentinel Rock's north wall over five hot days in July 1950, short of water. Salathé's hard-steel pitons are often said to come from Model A Ford axles; that story is told several ways. The axle errand is dramatized.",
	"johnson_astroman": "Documented: Beverly Johnson made the first all-woman ascent of El Capitan in 1973 and in 1978 soloed the Dihedral Wall in ten days. Washington Column's east face was first climbed with aid in 1959 by a party led by Warren Harding, and freed in 1975 as Astroman. Dramatized: her sending you up it.",
	"robbins_roof": "Documented: Separate Reality's roof crack was first freed in 1978, and climbers still argue over whether it's 5.11d or 5.12a. Dramatized: Robbins sending you there.",
	"harding_summit": "Documented: Warren Harding's team climbed the Nose in 47 days spread over about 18 months, topping out on November 12, 1958, after Harding drilled bolts up the final headwall through the night. Dramatized: the free climb. The Nose wasn't climbed free until 1993, and its real grade is 5.14a; the game calls it 5.13.",
	"lucy_basket": "Documented: Lucy Telles demonstrated weaving at the Yosemite Museum for many years, and between 1929 and 1933 wove one of the largest baskets of its kind, now in the museum's collection. Her words here are a placeholder pending tribal review.",
	"muir_cathedral": "Documented: John Muir climbed Cathedral Peak in September 1869 and wrote in My First Summer in the Sierra that it was his first time at church in California. His lines here paraphrase him.",
	"muir_glacier": "Documented: in 1872 Muir set stakes in the ice on Mount Maclure, next to Mount Lyell, and measured them moving, proof of living glaciers, against Josiah Whitney's claim that the valley floor had simply dropped. Muir often wrote dismissively of Native people; the line on this page is the game's, not his.",
	"bethel_trade": "Documented: Carrie Bethel's baskets won prizes at Yosemite Indian Field Days and are in the Yosemite Museum, and trade across the Sierra passes, pine nuts among it, is well recorded. Her words here are a placeholder pending tribal review.",
	"clark_last_page": "These blank pages are the game's, not a historical record. Families decided what to share with outsiders and what to keep, and the game leaves that choice with them. Placeholder pending tribal review.",
	"clark_big_trees": "Real: Clark settled at Wawona in 1856 and explored the Mariposa Grove in 1857, and the 1864 Grant protected the valley and the grove together. Dramatized: the cone and his words. The answer came a century later: studies in the 1960s found sequoias need fire to open their cones and clear the ground for seedlings, and the park has set careful fires in its groves since the early 1970s.",
	"enid_dawn_chorus": "Real: Enid Michael was one of the first women ranger-naturalists in the Park Service, from 1921, and wrote hundreds of short pieces on Yosemite's birds and flowers for Yosemite Nature Notes. Dramatized: this count, and its trip to Clare Hodges, whose one season as a ranger (1918) came before Michael's.",
	"hodges_bear_season": "Real: Yosemite's black bears feed hard in fall, and the old orchard by Curry Village still draws them. Bears were fed for crowds in the park from the 1920s until 1940; today every campsite has a bear box. Grizzlies are gone from the park; the last is usually dated to the 1890s. Dramatized: this patrol, and Lamon's bears.",
	"degnan_snowbound": "Real: the Yosemite Valley Railroad ran from Merced up the Merced River canyon to El Portal from 1907 to 1945, all year, and made winter trips to the valley practical. The Degnans' bakery fed the valley from the 1880s. Dramatized: this sack of flour, the toyon on the loaves, and the pudding.",
	"muir_soda_springs": "Real: Muir and Johnson camped in Tuolumne Meadows in 1889 and planned a campaign; Johnson's Century Magazine printed Muir's articles, and Congress created Yosemite National Park around the state-held valley in 1890. Muir herded sheep here in 1869 and later called them hoofed locusts. Dramatized: the supper and Muir's words. Those park lines were drawn without asking the Native people whose homeland it was.",
}


## The pages written so far, front pages first, each a Dictionary with "by",
## "text", "notes", "history", and "review". "notes" holds the margin notes
## written so far, then the page's Register note ("Register note: ..."), the
## same text as "history", so the journal shows it with the page.
static func written() -> Array[Dictionary]:
	var front: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	var noted := {}
	for page: Dictionary in PAGES:
		if not QuestLog.is_completed(page.quest):
			continue
		var notes := PackedStringArray()
		for note: Dictionary in page.get("notes", []):
			if QuestLog.is_completed(note.quest):
				notes.append(note.text)
		var history: String = "" if noted.has(page.quest) else HISTORY.get(page.quest, "")
		noted[page.quest] = true
		if history != "":
			notes.append("Register note: " + history)
		var shown := {"by": page.by, "text": page.text, "notes": notes, "history": history, "review": page.get("review", false)}
		(front if page.get("front", false) else rest).append(shown)
	return front + rest


## What to tell the player when [param quest_id] is finished: which pages it
## wrote in the Register, and the Register note. Narrator lines, or [].
static func on_completed(quest_id: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var hands := PackedStringArray()
	for page: Dictionary in PAGES:
		if page.quest == quest_id:
			hands.append(page.by)
	if hands.is_empty():
		return lines
	lines.append({"speaker": "", "text": "New in the Register: %s." % (
		"a page from %s" % hands[0] if hands.size() == 1 else "pages from %s" % " and ".join(hands))})
	if HISTORY.has(quest_id):
		lines.append({"speaker": "", "text": "Register note: " + HISTORY[quest_id]})
	return lines
