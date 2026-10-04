class_name ClimbState
extends RefCounted
## The rules of the climbing minigame, with no drawing or input, so tests can
## play a climb directly.
##
## A pitch is a grid of holds [member COLUMNS] wide. Row 0 is the belay ledge
## at the bottom, and the last row is the ledge at the top. Each move goes up
## one row: straight up, up-left, or up-right, onto a hold. Moves cost stamina.
## Some holds are cracks, where you can place a cam. If stamina runs out you
## fall to your last cam (or the belay). A short fall only costs time; a long
## one ends the climb, and you lower off safely.

enum Status { CLIMBING, TOPPED_OUT, RETREATED }

const COLUMNS := 5
const MAX_STAMINA := 100
## Stamina regained resting at each belay ledge.
const BELAY_REST := 10
## Stamina you have back after hanging on the rope following a fall.
const AFTER_FALL_STAMINA := 30
## Falling from this many moves above your protection (or more) ends the climb.
const DANGEROUS_RUNOUT := 4
## After this many falls on one pitch, your arms are done and you lower off.
const MAX_FALLS_PER_PITCH := 3
## A night on the wall needs a meal worth at least this much energy.
const BIVY_MEAL_ENERGY := 30
## In-game minutes each action takes.
const MINUTES_PER_MOVE := 6
const MINUTES_PER_CAM := 2
const MINUTES_PER_FALL := 20
const MINUTES_TO_EAT := 5

var route: RouteData
var status := Status.CLIMBING
var pitch := 0
var row := 0
var col := COLUMNS / 2
var stamina := MAX_STAMINA
var cams_per_pitch := 0
var cams_left := 0
## Row of the highest cam placed this pitch (the belay ledge counts as row 0).
var protection_row := 0
## Cells with a placed cam this pitch, for drawing.
var placed_cams: Array[Vector2i] = []
var falls := 0
var falls_this_pitch := 0
var nights_spent := 0
var minutes := 0
## What just happened, for the UI.
var message := ""
## Row -> {column -> {"cost": int, "crack": bool}} for the current pitch.
var holds: Dictionary = {}

var _rng := RandomNumberGenerator.new()


## [param seed] makes the wall the same every time (tests use this).
func _init(p_route: RouteData, cams: int, seed := -1) -> void:
	route = p_route
	cams_per_pitch = 99 if route.top_rope else cams
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	_start_pitch()


var top_row: int:
	get:
		return route.moves_per_pitch


func runout() -> int:
	return row - protection_row


func hold_at(r: int, c: int) -> Dictionary:
	return holds.get(r, {}).get(c, {})


func is_at_belay() -> bool:
	return row == 0


## Moves up one row. [param dx] is -1 (up-left), 0 (straight up), or 1 (up-right).
func move(dx: int) -> bool:
	if status != Status.CLIMBING:
		return false
	var target := hold_at(row + 1, col + dx)
	if target.is_empty():
		message = "No hold there."
		return false
	row += 1
	col += dx
	stamina -= int(target.cost)
	minutes += MINUTES_PER_MOVE
	message = ""
	if stamina <= 0:
		_fall()
	elif row == top_row:
		_finish_pitch()
	return true


func can_place_cam() -> bool:
	return status == Status.CLIMBING and not route.top_rope and cams_left > 0 \
		and hold_at(row, col).get("crack", false) and protection_row < row


func place_cam() -> bool:
	if not can_place_cam():
		message = "You need a crack to place a cam." if cams_left > 0 else "You're out of cams for this pitch."
		return false
	cams_left -= 1
	protection_row = row
	placed_cams.append(Vector2i(col, row))
	stamina -= 1
	minutes += MINUTES_PER_CAM
	message = "Cam placed."
	return true


## Eats one of [param item_id] from the Inventory. Only at belay ledges.
func eat(item_id: String) -> bool:
	if not is_at_belay():
		message = "You can only eat at a belay ledge."
		return false
	var energy := FoodDB.energy(item_id)
	if energy <= 0 or not Inventory.remove(item_id):
		return false
	stamina = mini(stamina + energy, MAX_STAMINA)
	minutes += MINUTES_TO_EAT
	var item := ItemDB.get_item(item_id)
	message = "Ate %s (+%d)." % [item.display_name if item else item_id, energy]
	return true


## Gives up and lowers off. Your gear comes with you.
func retreat(reason := "You lower off and head back down.") -> void:
	status = Status.RETREATED
	message = reason


func _fall() -> void:
	falls += 1
	falls_this_pitch += 1
	minutes += MINUTES_PER_FALL
	if falls_this_pitch >= MAX_FALLS_PER_PITCH:
		retreat("That's %d falls on this pitch. Your arms are done, so you lower off and head down." % falls_this_pitch)
		return
	if route.top_rope:
		stamina = AFTER_FALL_STAMINA
		message = "You slip, and the rope catches you right away. Rest, then keep going."
		return
	var distance := runout()
	if distance >= DANGEROUS_RUNOUT:
		retreat("You fell %d moves past your last protection. Shaken, you lower off and walk back down." % (distance * 2))
		return
	# A leader falls twice as far as they were above their protection.
	row = maxi(protection_row - distance, 0)
	# Back on the ledge you're lowered to the belay; otherwise you grab the nearest hold.
	col = COLUMNS / 2 if row == 0 else _nearest_hold_column(row, col)
	stamina = AFTER_FALL_STAMINA
	message = "You fall, and your %s catches you. Shake it out and try again." % ("belay" if protection_row == 0 else "cam")


func _finish_pitch() -> void:
	pitch += 1
	if pitch >= route.pitches.size():
		status = Status.TOPPED_OUT
		message = "You top out!"
		return
	# A night on the wall after an equal share of the pitches.
	if route.nights > 0 and nights_spent < route.nights:
		var pitches_per_day := ceili(route.pitches.size() / float(route.nights + 1))
		if pitch % pitches_per_day == 0:
			if not _bivy():
				return
	stamina = mini(stamina + BELAY_REST, MAX_STAMINA)
	_start_pitch()
	message = "Belay ledge. Pitch %d of %d." % [pitch + 1, route.pitches.size()] if message == "" else message


## Spends a night on the wall. Returns false if there's no real meal to eat.
func _bivy() -> bool:
	for id in FoodDB.edible_in_inventory():
		if FoodDB.energy(id) >= BIVY_MEAL_ENERGY:
			Inventory.remove(id)
			nights_spent += 1
			stamina = MAX_STAMINA
			minutes += 10 * 60
			var item := ItemDB.get_item(id)
			message = "You spend the night on the wall and eat %s. You wake up rested." % (item.display_name if item else id)
			return true
	retreat("Night is falling and you have no real meal for the wall. You rappel down hungry.")
	return false


func _start_pitch() -> void:
	row = 0
	col = COLUMNS / 2
	cams_left = cams_per_pitch
	protection_row = 0
	falls_this_pitch = 0
	placed_cams.clear()
	_generate_holds(route.pitches[pitch])


func _generate_holds(difficulty: int) -> void:
	holds = {}
	var ledge := {}
	for c in COLUMNS:
		ledge[c] = {"cost": 0, "crack": false}
	holds[0] = ledge
	holds[top_row] = ledge.duplicate()
	var path_col := COLUMNS / 2
	for r in range(1, top_row):
		var rowd := {}
		# A guaranteed line: each row has a hold within reach of the one below.
		path_col = clampi(path_col + _rng.randi_range(-1, 1), 0, COLUMNS - 1)
		rowd[path_col] = _make_hold(difficulty)
		for i in _rng.randi_range(1, 2):
			var c := _rng.randi_range(0, COLUMNS - 1)
			if not rowd.has(c):
				rowd[c] = _make_hold(difficulty)
		holds[r] = rowd
	_remove_dead_ends(difficulty)
	_ensure_cracks(difficulty)


## Gives every hold at least one hold within reach above it, so the player
## can never climb into a dead end.
func _remove_dead_ends(difficulty: int) -> void:
	for r in range(1, top_row - 1):
		for c: int in holds[r].keys():
			var reachable := false
			for dx in [-1, 0, 1]:
				reachable = reachable or holds[r + 1].has(c + dx)
			if not reachable:
				holds[r + 1][clampi(c + _rng.randi_range(-1, 1), 0, COLUMNS - 1)] = _make_hold(difficulty)


func _make_hold(difficulty: int) -> Dictionary:
	return {"cost": 2 + difficulty * 2 + _rng.randi_range(0, 3), "crack": _rng.randf() < 0.3}


## Makes sure a careful climber can protect every stretch of DANGEROUS_RUNOUT
## moves, so no pitch is impossible to climb safely.
func _ensure_cracks(difficulty: int) -> void:
	for start in range(1, top_row, DANGEROUS_RUNOUT - 1):
		var has_crack := false
		for r in range(start, mini(start + DANGEROUS_RUNOUT - 1, top_row)):
			for c: int in holds[r]:
				has_crack = has_crack or holds[r][c].crack
		if not has_crack:
			var r := mini(start + 1, top_row - 1)
			var c: int = holds[r].keys()[0]
			holds[r][c].crack = true


func _nearest_hold_column(r: int, from_col: int) -> int:
	var best := from_col
	var best_distance := COLUMNS + 1
	for c: int in holds.get(r, {}):
		if absi(c - from_col) < best_distance:
			best = c
			best_distance = absi(c - from_col)
	return best
