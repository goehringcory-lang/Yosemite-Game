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
## tribal review, like their dialogue.

const PAGES: Array[Dictionary] = [
	{"quest": "tenaya_ahwahnee", "front": true, "review": true, "by": "Tenaya",
		"text": "Our villages were here. In 1851 soldiers came, burned our homes and our food, and made us leave."},
	{"quest": "lebrado_villages", "front": true, "review": true, "by": "Maria Lebrado (Totuya)",
		"text": "She was a girl in 1851 when the soldiers came. She remembers where the villages stood: by the river, and below the cliffs."},
	{"quest": "clark_register", "by": "Galen Clark",
		"text": "The State made me Guardian of this valley in 1866. These pages record what happens here.",
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
		]},
	{"quest": "salathe_steel", "by": "John Salathé",
		"text": "Pitons forged from Model A axles, because soft iron bends. Sentinel Rock, 1950, with Allen Steck."},
	{"quest": "johnson_astroman", "by": "Beverly Johnson",
		"text": "If you can climb Astroman, you can live on a big wall.",
		"notes": [
			{"quest": "johnson_solo", "text": "Added later: Scared and ready aren't opposites."},
		]},
	{"quest": "harding_summit", "by": "Warren Harding",
		"text": "The Nose, 1958: pitons, bolts, and a lot of wine. Somebody said it was the end of Yosemite climbing. It was only the beginning."},
	{"quest": "lucy_basket", "review": true, "by": "Lucy Telles",
		"text": "Her name, written in her own hand."},
	{"quest": "muir_glacier", "by": "John Muir",
		"text": "Glaciers made this valley. I didn't always see the people who lived here, and they saw a great deal I missed."},
	{"quest": "bethel_trade", "review": true, "by": "Carrie Bethel",
		"text": "The valley was never cut off. People came and went over the passes long before any road."},
	{"quest": "clark_last_page", "review": true, "by": "Tabuce",
		"text": "A blank page, kept at her request. Some things stay with her family."},
	{"quest": "clark_last_page", "review": true, "by": "Maria Lebrado (Totuya)",
		"text": "A blank page. The rest belongs to her people."},
]


## The pages written so far, front pages first, each a Dictionary with "by",
## "text", "notes" (the margin notes written so far), and "review".
static func written() -> Array[Dictionary]:
	var front: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for page: Dictionary in PAGES:
		if not QuestLog.is_completed(page.quest):
			continue
		var notes := PackedStringArray()
		for note: Dictionary in page.get("notes", []):
			if QuestLog.is_completed(note.quest):
				notes.append(note.text)
		var shown := {"by": page.by, "text": page.text, "notes": notes, "review": page.get("review", false)}
		(front if page.get("front", false) else rest).append(shown)
	return front + rest
