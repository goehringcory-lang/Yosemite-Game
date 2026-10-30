class_name Backcountry
extends RefCounted
## Nights out past the trailhead: Little Yosemite Valley and Half Dome.
##
## Ranger Hodges hands you a wilderness permit and lends you a bear canister
## ("hodges_first_night"). With the permit you can pitch your tent at the
## backcountry camp in Little Yosemite Valley (BackcountryCamp) and sleep
## there instead of at the homestead: you wake up in camp, and the game saves
## there. Overnight your food is either in the canister, or in your pack for
## a bear to find (night_out()).
##
## The rest of the trip is Half Dome: the cables up its back (HalfDomeCables,
## shut in winter by Park.SEASONAL "half_dome_cables" and needing the
## permit), the summit, and the Diving Board on its shoulder. Each first is
## kept as a QuestLog unlock, so the quests can ask for it.

const PERMIT := "wilderness_permit"
const CANISTER := "bear_canister"
## Regions past the trailhead. A night out here is a night in the wilderness.
const REGIONS := ["little_yosemite_valley", "half_dome"]
## Firsts, kept in QuestLog.unlocks: a night out with your food in the
## canister, standing on top of Half Dome (by either way up), going up the
## cables, and the afternoon light from the Diving Board.
const NIGHT_OUT := "night_out"
const SUMMIT := "half_dome_summit"
const CABLES := "half_dome_cables"
const DIVING_BOARD := "diving_board_light"
## How many things to eat the canister holds (a real one holds a few days'
## food for one person). It's packed with the best food first; the rest of
## what you carry spends the night in your pack.
const CANISTER_HOLDS := 12
## Half the food left in a pack goes to a bear (rounded up), and a bear comes
## round a full canister on about half the nights.
const BEAR_SHARE := 0.5
const BEAR_VISITS := 0.5
## The hours the Dome's face is lit from the Diving Board (Ansel Adams's
## "about an hour" of afternoon light, given a little room).
const FACE_LIT_FROM := 15
const FACE_LIT_TO := 17


static func is_backcountry(region_id: String) -> bool:
	return region_id in REGIONS


static func has_permit() -> bool:
	return Inventory.count(PERMIT) > 0


static func has_canister() -> bool:
	return Gear.count(CANISTER) > 0


## Marks a first (one of the constants above) as done. True the first time.
static func mark(ability: String) -> bool:
	if QuestLog.is_unlocked(ability):
		return false
	QuestLog.unlocks.append(ability)
	QuestLog.changed.emit()
	return true


## What happens to your food overnight in the backcountry, and the line for
## the morning. What fits in the canister is safe (and the night counts for
## Ranger Hodges); anything left in your pack, a bear eats about half of.
static func night_out(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	# Everything edible, one entry a piece, best first: that's packing order.
	var units: Array[String] = []
	for id in FoodDB.edible_in_inventory():
		for i in Inventory.count(id):
			units.append(id)
	var packed := has_canister()
	if packed:
		mark(NIGHT_OUT)
		units = units.slice(CANISTER_HOLDS)
	if units.is_empty():
		if not packed:
			return "There was nothing to eat in your pack, so there was nothing for a bear either."
		if rng.randf() < BEAR_VISITS:
			FieldLog.spot("black_bear", true, "tracks")
			return "Bear tracks round the canister this morning, and it had rolled off into the manzanita. The lid held: your food is all there."
		return "Your food spent the night in the bear canister, well away from the tent. Nothing touched it."
	var taken := {}
	for i in ceili(units.size() * BEAR_SHARE):
		var pick := rng.randi_range(0, units.size() - 1)
		taken[units[pick]] = taken.get(units[pick], 0) + 1
		units.remove_at(pick)
	var names := PackedStringArray()
	for id: String in taken:
		Inventory.remove(id, taken[id])
		var item := ItemDB.get_item(id)
		names.append(ItemDB.count_name(taken[id], item.display_name if item else id))
	FieldLog.spot("black_bear", true, "tracks")
	if packed:
		return "The canister was full, so some food spent the night in your pack, and a bear found it: it ate %s. The canister holds %d things to eat." % [", ".join(names), CANISTER_HOLDS]
	return "A bear got into your pack in the night and ate %s. Out here, food goes in a bear canister." % ", ".join(names)


## The first time on top: down the Valley from the summit (StoryVista).
const SUMMIT_VIEW := {
	"title": "The top of Half Dome", "hour": 11.0, "rise_from": 0.55, "rise_to": 0.85,
	"view": [{"k": "el_capitan", "x": 250, "s": 0.55, "l": 0}, {"k": "glacier_point", "x": 95, "s": 1.25, "l": 1},
		{"k": "north_dome", "x": 405, "s": 1.15, "l": 1}, {"k": "sierra_crest", "x": 240, "s": 0.7, "l": 0}],
	"ground": "valley_forest",
}
const SUMMIT_WORDS := {"who": "Half Dome, 8,842 feet",
	"text": "Flat as a ballroom and big as a farm, and the whole Valley laid out under the lip: Glacier Point across the gulf, North Dome below you, and El Capitan far off at the end of it all, 4,800 feet down."}
## Half Dome's face from the Diving Board, as Ansel Adams photographed it.
const DIVING_BOARD_VIEW := {
	"title": "From the Diving Board", "rise_from": 0.35, "rise_to": 0.6,
	"view": [{"k": "half_dome", "x": 250, "s": 1.0, "l": 1}, {"k": "clouds_rest", "x": 420, "s": 0.8, "l": 0},
		{"k": "mt_watkins", "x": 80, "s": 0.8, "l": 0}],
	"ground": "half_dome_forest",
}


## Plays a view (StoryVista) with the player held and the clock stopped,
## and waits for it to close.
static func show_view(player: Player, moment: Dictionary, words: Dictionary) -> void:
	player.can_act = false
	var was_paused := GameClock.paused
	GameClock.paused = true
	var vista := StoryVista.new()
	vista.setup(moment, words)
	player.get_tree().root.add_child(vista)
	await vista.finished
	GameClock.paused = was_paused
	if is_instance_valid(player):
		player.can_act = true
