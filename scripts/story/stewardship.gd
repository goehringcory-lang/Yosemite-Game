extends Node
## The Guardian's Year (autoload "Stewardship"): the work the player does
## for the park in the year after the finale, one arc a season, and the
## changes it leaves on the map.
##
## - Spring, trail crew: George Anderson hands over a rock bar, and you reset
##   washed-out granite steps at the foot of the Mist Trail (RockWork).
## - Summer, Cook's Meadow: Enid Michael has you pull the plants that came in
##   with people (the press book teaches you their native look-alikes) and
##   rope off the shortcuts walkers have worn across the wet ground. The
##   meadow greens up the season after.
## - Fall, fire in the big trees: Galen Clark, who never saw young sequoias
##   come up in his grove, has you clear the fuel from round the giants and
##   light a slow burn. The spring after, seedlings come up in the ash.
## - Winter, the bear boxes: Ranger Hodges has steel food lockers to set at
##   the Valley's campgrounds, where the last campers of the year leave their
##   coolers out.
##
## Each spot is a WorkSpot that StoryContent adds to its region on the first
## visit (see dress()). A spot shows its problem, and can be worked, only
## while a quest step asks for its task (QuestData "work" steps); once done
## it shows the fix for good. What's done is saved here, by spot id, with
## the season and year it was done, so the map can change a season later.

signal changed

## Each task: what the prompt says, the game minutes the work takes, and
## where its spots are (for the journal).
const TASKS := {
	"mist_steps": {"verb": "Reset the step", "minutes": 30, "where": "the foot of the Mist Trail, Happy Isles"},
	"meadow_weeds": {"verb": "Pull", "minutes": 15, "where": "Cook's Meadow, Yosemite Village"},
	"meadow_paths": {"verb": "Rope off the shortcut", "minutes": 20, "where": "Cook's Meadow, Yosemite Village"},
	"grove_fuel": {"verb": "Clear the fuel", "minutes": 40, "where": "round the Grizzly Giant, Mariposa Grove"},
	"grove_burn": {"verb": "Light the burn", "minutes": 180, "where": "below the Grizzly Giant, Mariposa Grove"},
	"bear_boxes": {"verb": "Set a bear box", "minutes": 30, "where": "Camp 4, Curry Village, Upper Pines and Housekeeping Camp"},
}

## The plants pulled from Cook's Meadow: real invaders of Yosemite's
## meadows, each with the native plant the press book teaches you to tell it
## from ("native" is a Herbarium plant id).
const WEEDS := {
	"himalayan_blackberry": {"name": "Himalayan blackberry", "native": "california_blackberry",
		"tell": "the native one trails low with three leaflets; this one arches head-high, with five and thorns like a cat's"},
	"bull_thistle": {"name": "bull thistle", "native": "broadleaf_lupine",
		"tell": "it comes up where the lupine should be, spiny all over, with a purple brush on top"},
	"velvet_grass": {"name": "velvet grass", "native": "deergrass",
		"tell": "the native bunchgrass stands in tall clumps; this one is soft and grey-green, and it creeps until nothing else is left"},
}

## Every work spot: its id (unique, and the key it's saved under), task,
## region, position (feet, on open ground), and what it looks like ("kind").
## Weeds also say which plant they are.
const SPOTS := [
	{"id": "mist_step_1", "task": "mist_steps", "region": "happy_isles", "pos": Vector2(1664, 536), "kind": "step"},
	{"id": "mist_step_2", "task": "mist_steps", "region": "happy_isles", "pos": Vector2(1696, 510), "kind": "step"},
	{"id": "mist_step_3", "task": "mist_steps", "region": "happy_isles", "pos": Vector2(1728, 486), "kind": "step"},
	{"id": "mist_step_4", "task": "mist_steps", "region": "happy_isles", "pos": Vector2(1752, 420), "kind": "step"},
	{"id": "meadow_weed_1", "task": "meadow_weeds", "region": "yosemite_village", "pos": Vector2(1840, 1232), "kind": "weed", "plant": "himalayan_blackberry"},
	{"id": "meadow_weed_2", "task": "meadow_weeds", "region": "yosemite_village", "pos": Vector2(1968, 1264), "kind": "weed", "plant": "bull_thistle"},
	{"id": "meadow_weed_3", "task": "meadow_weeds", "region": "yosemite_village", "pos": Vector2(2096, 1248), "kind": "weed", "plant": "velvet_grass"},
	{"id": "meadow_weed_4", "task": "meadow_weeds", "region": "yosemite_village", "pos": Vector2(2240, 1232), "kind": "weed", "plant": "himalayan_blackberry"},
	{"id": "meadow_weed_5", "task": "meadow_weeds", "region": "yosemite_village", "pos": Vector2(1904, 1520), "kind": "weed", "plant": "velvet_grass"},
	{"id": "meadow_weed_6", "task": "meadow_weeds", "region": "yosemite_village", "pos": Vector2(2176, 1536), "kind": "weed", "plant": "bull_thistle"},
	{"id": "meadow_path_1", "task": "meadow_paths", "region": "yosemite_village", "pos": Vector2(1808, 1376), "kind": "path"},
	{"id": "meadow_path_2", "task": "meadow_paths", "region": "yosemite_village", "pos": Vector2(2032, 1504), "kind": "path"},
	{"id": "meadow_path_3", "task": "meadow_paths", "region": "yosemite_village", "pos": Vector2(2272, 1376), "kind": "path"},
	{"id": "grove_fuel_1", "task": "grove_fuel", "region": "wawona", "pos": Vector2(3168, 2768), "kind": "fuel"},
	{"id": "grove_fuel_2", "task": "grove_fuel", "region": "wawona", "pos": Vector2(3328, 2768), "kind": "fuel"},
	{"id": "grove_fuel_3", "task": "grove_fuel", "region": "wawona", "pos": Vector2(3200, 2912), "kind": "fuel"},
	{"id": "grove_fuel_4", "task": "grove_fuel", "region": "wawona", "pos": Vector2(3344, 2880), "kind": "fuel"},
	{"id": "grove_burn", "task": "grove_burn", "region": "wawona", "pos": Vector2(3248, 2944), "kind": "burn"},
	{"id": "bear_box_camp4", "task": "bear_boxes", "region": "yosemite_village", "pos": Vector2(624, 624), "kind": "bear_box"},
	{"id": "bear_box_curry", "task": "bear_boxes", "region": "curry_village", "pos": Vector2(1328, 688), "kind": "bear_box"},
	{"id": "bear_box_pines", "task": "bear_boxes", "region": "upper_pines", "pos": Vector2(656, 512), "kind": "bear_box"},
	{"id": "bear_box_housekeeping", "task": "bear_boxes", "region": "housekeeping_camp", "pos": Vector2(720, 768), "kind": "bear_box"},
]

## What the HUD says when a spot is done, by kind. Weeds say their own.
const DONE_TEXT := {
	"step": "The block drops onto its bed with a thud you feel in your boots. You stamp the gravel in round it. It doesn't rock.",
	"path": "Two stakes, a rope between them, and a card: Closed for restoration. The worn strip will grow back if people let it.",
	"fuel": "You drag the dead branches and the deep needle litter back from the trunk, and rake a bare line round the tree. The bark is a foot thick and scarred black from fires older than the park.",
	"burn": "The crew calls it, and you walk the drip torch along the line. The fire creeps low through the needles, popping and smoking, never higher than your knee. By dusk the grove floor is black, and the giants stand in it untouched.",
	"bear_box": "You bolt the new steel locker to its pad, stow the cooler and the bag of groceries that were sitting out, and latch it. A card on the lid says why. A black bear can smell a candy wrapper from a long way off.",
}

## The signs that change once an arc is done: region -> sign node name ->
## [quest id, extra paragraph].
const SIGN_NOTES := {
	"happy_isles": {"MistTrailSign": ["anderson_mist_steps",
		"The lowest steps are new this year, set by hand with a rock bar, and they don't wobble."]},
	"yosemite_village": {"CooksMeadowSign": ["enid_cooks_meadow",
		"Ropes close the old shortcuts across the meadow so the wet ground can heal. Thank you for staying on the boardwalk."]},
	"wawona": {"Sign_Grizzly_Giant": ["clark_grove_fire",
		"The ground round the Grizzly Giant is black from a prescribed fire. Sequoias need it: the heat opens their cones and bares the soil their seedlings need."]},
}

## Spot id -> {"season", "year"} it was done in.
var done: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")


func start_new_game() -> void:
	done = {}
	changed.emit()


func get_spot(id: String) -> Dictionary:
	for spot: Dictionary in SPOTS:
		if spot.id == id:
			return spot
	return {}


## The spots for [param task], or in [param region_id] if a region is given.
static func spots_for(task: String, region_id := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for spot: Dictionary in SPOTS:
		if (task == "" or spot.task == task) and (region_id == "" or spot.region == region_id):
			out.append(spot)
	return out


func is_done(spot_id: String) -> bool:
	return done.has(spot_id)


## How many of [param task]'s spots are done.
func count(task: String) -> int:
	var n := 0
	for spot: Dictionary in spots_for(task):
		if is_done(spot.id):
			n += 1
	return n


## True while a quest step is asking for [param task]. A run of work steps
## opens one after another without going back to the giver in between: once
## the fuel is cleared from round the giants, the burn is ready to light.
func is_wanted(task: String) -> bool:
	for quest: QuestData in QuestLog.QUESTS:
		var step := next_work_step(quest)
		if step.get("task") == task:
			return true
	return false


## The first unfinished step in the run of "work" steps starting at
## [param quest]'s current step, or {} if the current step isn't work or the
## whole run is done.
func next_work_step(quest: QuestData) -> Dictionary:
	if not QuestLog.active.has(quest.id):
		return {}
	for i in range(int(QuestLog.active[quest.id]), quest.steps.size()):
		var step: Dictionary = quest.steps[i]
		if step.get("type") != "work":
			return {}
		if count(step.task) < int(step.get("count", 1)):
			return step
	return {}


## Marks a spot done, now. Returns false if it was done already.
func finish(spot_id: String) -> bool:
	if is_done(spot_id) or get_spot(spot_id).is_empty():
		return false
	done[spot_id] = {"season": GameClock.season, "year": GameClock.year}
	changed.emit()
	return true


## Seasons since [param spot_id] was done (0 in the same season), or -1 if
## it isn't.
func seasons_since(spot_id: String) -> int:
	if not is_done(spot_id):
		return -1
	var when: Dictionary = done[spot_id]
	return (GameClock.year * 4 + GameClock.season) - (int(when.year) * 4 + int(when.season))


## True once a spot has had time to heal: the meadow greens up the season
## after it's weeded and roped, and sequoia seedlings come up the spring
## after the burn (the next year).
func grown_back(spot_id: String) -> bool:
	if not is_done(spot_id):
		return false
	var spot := get_spot(spot_id)
	if spot.get("kind") == "fuel" or spot.get("kind") == "burn":
		return GameClock.year > int(done[spot_id].year)
	return seasons_since(spot_id) >= 1


## What the HUD says when [param spot] is done, and whether the press book
## helped tell a weed from its native look-alike.
func done_text(spot: Dictionary) -> String:
	if spot.kind != "weed":
		return DONE_TEXT.get(spot.kind, "Done.")
	var weed: Dictionary = WEEDS.get(spot.get("plant", ""), {})
	var look_alike: Dictionary = Herbarium.get_plant(weed.get("native", ""))
	var text := "You work the roots loose and pull the %s out whole." % weed.get("name", "plant")
	if Herbarium.has(weed.get("native", "")):
		text += " Your press book's %s is how you knew it: %s." % [look_alike.get("name", "native plant"), weed.get("tell", "")]
	else:
		text += " Enid showed you how to tell it from the native %s: %s." % [str(look_alike.get("name", "plant")).to_lower(), weed.get("tell", "")]
	return text


## Puts [param region]'s work spots in its Entities, and the extra lines on
## its signs. StoryContent calls it once, on the first visit.
func dress(region: Region) -> void:
	for spot: Dictionary in spots_for("", region.region_id):
		if region.entities.has_node(WorkSpot.node_name(spot.id)):
			continue
		region.entities.add_child(WorkSpot.make(spot))
	var notes: Dictionary = SIGN_NOTES.get(region.region_id, {})
	for sign_name: String in notes:
		var board := region.find_child(sign_name, true, false) as InfoSign
		if board and board.extra_text == "":
			board.extra_text = notes[sign_name][1]
			board.extra_after_quest = notes[sign_name][0]


func save_data() -> Dictionary:
	return {"done": done}


func load_data(data: Dictionary) -> void:
	done = {}
	var saved: Dictionary = data.get("done", {})
	for id in saved:
		var when: Dictionary = saved[id]
		done[str(id)] = {"season": int(when.get("season", 0)), "year": int(when.get("year", 1))}
	changed.emit()
