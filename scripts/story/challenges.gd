extends Node
## Small challenges spread over the park, for wandering about:
##
## - Registers: summit registers, survey benchmarks and lookout logbooks, in
##   high places in every corner of the park. Find one and sign it. Every
##   few signatures earn a piece of climbing gear (MILESTONES), the last a
##   big nut, so signing them all is worth the walk.
## - Sketches: a few views are worth drawing, but only at the right hour
##   (alpenglow on Half Dome at dusk, Mirror Lake still in the morning, El
##   Capitan's headlamps at night). Sit at the spot then and the sketch goes
##   in the Logbook's sketchbook; come at the wrong time and the Logbook
##   says when to come back.
##
## (The third kind, the peak-finder, asks at each vista: see Vistas.)
## None of them are timed, can be failed, or come back daily.
##
## The list is res://data/park/challenges.json; ChallengeSpot lays them out.

signal signed_one(register: Dictionary)
signal sketched_one(sketch: Dictionary)
signal changed

const DATA := "res://data/park/challenges.json"
## Gear for signing registers, by how many you've signed.
const MILESTONES: Array[Dictionary] = [
	{"count": 3, "reward": {"nut_mid": 1}},
	{"count": 6, "reward": {"quickdraw": 1}},
	{"count": 9, "reward": {"nut_big": 1}},
]

## Register id -> the day signed ("Y/S/D").
var signed: Dictionary = {}
## Sketch id -> the day sketched.
var sketched: Dictionary = {}
## Sketch ids stood at at the wrong time (so the Logbook can say when).
var tried: Dictionary = {}

var _registers: Array[Dictionary] = []
var _sketches: Array[Dictionary] = []
var _by_id: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	_load()


func start_new_game() -> void:
	signed.clear()
	sketched.clear()
	tried.clear()
	changed.emit()


func registers() -> Array[Dictionary]:
	return _registers


func sketches() -> Array[Dictionary]:
	return _sketches


func get_challenge(id: String) -> Dictionary:
	return _by_id.get(id, {})


## "register" or "sketch".
func kind_of(id: String) -> String:
	return str(_by_id.get(id, {}).get("kind", ""))


func is_signed(id: String) -> bool:
	return signed.has(id)


func is_sketched(id: String) -> bool:
	return sketched.has(id)


func is_tried(id: String) -> bool:
	return tried.has(id)


func signed_count() -> int:
	return signed.size()


func sketched_count() -> int:
	return sketched.size()


func tried_count() -> int:
	return tried.size()


## Is it the right time for sketch [param sketch] (its hours and seasons)?
static func is_sketch_time(sketch: Dictionary) -> bool:
	var seasons: Array = sketch.get("seasons", [])
	if not seasons.is_empty():
		var any := false
		for name: String in seasons:
			if Finds.SEASONS.get(name, -1) == GameClock.season:
				any = true
		if not any:
			return false
	var hours: Array = sketch.get("hours", [])
	if hours.size() == 2:
		var from := int(hours[0]) % 24
		var to := int(hours[1]) % 24
		if not GameClock.hour_in_range(from, to):
			return false
	return true


## Signs register [param id]. Returns the gear earned by it ({id: n}, maybe
## empty), or null if it was signed already or isn't a register.
func sign_register(id: String) -> Variant:
	if signed.has(id) or kind_of(id) != "register":
		return null
	signed[id] = _today()
	var earned := {}
	for milestone: Dictionary in MILESTONES:
		if int(milestone.count) == signed.size():
			earned = milestone.reward
			for gear_id: String in earned:
				if Gear.get_gear(gear_id):
					Gear.add(gear_id, int(earned[gear_id]))
				else:
					Inventory.add(gear_id, int(earned[gear_id]))
	signed_one.emit(_by_id[id])
	changed.emit()
	return earned


## The next milestone not reached yet, or {} once all are.
func next_milestone() -> Dictionary:
	for milestone: Dictionary in MILESTONES:
		if int(milestone.count) > signed.size() and int(milestone.count) <= _registers.size():
			return milestone
	return {}


static func milestone_text(milestone: Dictionary) -> String:
	return Finds.reward_text({"reward": milestone.get("reward", {})})


## Sits down to sketch [param id]: true if it's the right time and it went in
## the sketchbook; false if not (it's remembered as tried).
func sketch(id: String) -> bool:
	if kind_of(id) != "sketch":
		return false
	if sketched.has(id):
		return true
	if not is_sketch_time(_by_id[id]):
		if not tried.has(id):
			tried[id] = true
			changed.emit()
		return false
	sketched[id] = _today()
	tried.erase(id)
	sketched_one.emit(_by_id[id])
	changed.emit()
	return true


## Adds a ChallengeSpot for each register and sketch in [param region].
func dress(region: Region) -> void:
	if region.indoors:
		return
	for entry: Dictionary in _registers + _sketches:
		if entry.region != region.region_id or not entry.has("pos"):
			continue
		var spot := ChallengeSpot.new()
		spot.challenge_id = entry.id
		spot.name = "Challenge_" + entry.id
		spot.position = Vector2(entry.pos[0], entry.pos[1])
		region.entities.add_child(spot)


func _today() -> String:
	return "%d/%d/%d" % [GameClock.year, GameClock.season, GameClock.day]


func save_data() -> Dictionary:
	return {"signed": signed.duplicate(), "sketched": sketched.duplicate(), "tried": tried.keys()}


func load_data(data: Dictionary) -> void:
	signed.clear()
	sketched.clear()
	tried.clear()
	for key in ["signed", "sketched"]:
		var saved = data.get(key, {})
		if saved is Dictionary:
			var into: Dictionary = signed if key == "signed" else sketched
			for id in saved:
				into[str(id)] = str(saved[id])
	for id in data.get("tried", []):
		tried[str(id)] = true
	changed.emit()


func _load() -> void:
	if not FileAccess.file_exists(DATA):
		push_error("No challenge list at %s" % DATA)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not read %s" % DATA)
		return
	for entry: Dictionary in data.get("registers", []):
		entry["kind"] = "register"
		_registers.append(entry)
		_by_id[str(entry.id)] = entry
	for entry: Dictionary in data.get("sketches", []):
		entry["kind"] = "sketch"
		_sketches.append(entry)
		_by_id[str(entry.id)] = entry
