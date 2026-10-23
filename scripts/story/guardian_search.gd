class_name GuardianSearch
extends RefCounted
## The missing Guardian: the main story's mystery (STORY.md, "The missing
## Guardian"). On the first morning Galen Clark tells the player that the
## valley's Guardian, the one for now, hasn't been seen in a long while, and
## everyone who ever had a hand in making the park is worried.
##
## As the tick list moves on, people pass on what they've heard: someone on
## the Apron at sunrise, someone who climbed Nutcracker without leaving a
## scratch. Every sighting is something the player did. The Journal keeps them
## under the Register, and the mirror in the Guardian's cave says whose they
## were. Witnesses are never Native characters: their words wait on tribal
## review, so nothing is put in their mouths here.
##
## The Journal also lists the keepers the player has met: everyone in the
## Register, in the order of the years they had a hand in making the park
## (CharacterData.legacy and legacy_year).

## Main-line quest -> what people said about the Guardian once it was done,
## in story order. "who" is a character id; the same words are their story
## beat, so the Journal remembers sightings the player walked past.
const SIGHTINGS: Array[Dictionary] = [
	{"quest": "clark_register", "who": "galen_clark",
		"text": "Nobody has seen the Guardian in a long while. Their camp at Lamon's was standing empty when you pitched your tent in it."},
	{"quest": "partner_apron", "who": "james_lamon",
		"text": "Somebody climbed the Apron at sunrise, a speck on the granite above the orchard. Lamon's first thought was that the Guardian had come back."},
	{"quest": "eichorn_apron", "who": "jennie_curry",
		"text": "A guest at Camp Curry watched someone walk up the Apron all the way to the rim, without the trail and without the toll. The old-timers say the Guardian used to go up that way."},
	{"quest": "robbins_clean", "who": "bridget_degnan",
		"text": "A climber at the bakery followed someone up Nutcracker and found not a scratch, not a sling left behind. He said only the Guardian climbs like that."},
	{"quest": "salathe_steel", "who": "clare_hodges",
		"text": "A ranger found the old wreck at El Portal with one axle gone and nothing else touched. Whoever took it knew what they wanted and why."},
	{"quest": "johnson_astroman", "who": "ansel_adams",
		"text": "Ansel Adams has a figure on Washington Column in one of his negatives, high in the last light. He's printed it three times and still can't make out the face."},
	{"quest": "harding_summit", "who": "mountain_shop",
		"text": "For three nights there was a headlamp on the Nose. Half of Curry Village was sure it was the Guardian."},
	{"quest": "muir_glacier", "who": "john_muir",
		"text": "Muir told the sheepherders about a climber on the Lyell ice, out beside his stakes. Every one of them said: that'll be the Guardian."},
]

## The line under the sightings once the cave is found.
const ANSWER := "Every one of them was you."


## The sightings so far, as {"who": display name, "text"}.
static func sightings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sighting: Dictionary in SIGHTINGS:
		if QuestLog.is_completed(sighting.quest):
			var who := QuestLog.get_character(sighting.who)
			result.append({"who": who.display_name if who else sighting.who,"text": sighting.text})
	return result


## The keepers the player has met: people in the Register (not staff or
## visitors) they've talked with, earliest legacy first.
static func keepers() -> Array[CharacterData]:
	var met: Array[CharacterData] = []
	for character: CharacterData in QuestLog.CHARACTERS:
		if character.legacy != "" and int(Friendship.points.get(character.id, 0)) > 0:
			met.append(character)
	met.sort_custom(func(a: CharacterData, b: CharacterData) -> bool: return a.legacy_year < b.legacy_year)
	return met
