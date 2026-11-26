extends Node
## Earned fast travel. The park's trailheads, campgrounds and parking areas
## (res://data/park/trailheads.json) are found by walking up to them, however
## you got there. From any one you've found (its sign, or the map kiosk at a
## parking area) you can plan a trip to any other: the route is the quickest
## open way over the park's roads, trails and shuttle (TravelNet), the clock
## moves on by its real minutes, and the trip map plays it (World._journey).
## So the walk is still the game; trips only skip the ground you've covered.
##
## Points at a kiosk already in their region name it ("node"); the rest get
## a TrailheadSign put down beside a spot ("spawn") when their region is in
## the world, so no region scene is edited for them. The map can draw
## all() and travel with travel_to().

signal registered(id: String)

const DATA := "res://data/park/trailheads.json"
## How near (in pixels) you must come to a point to find it.
const REACH := 112.0
## Seconds between looks for a point the player has walked up to.
const LOOK_EVERY := 0.25
## A trip between two points in the same area: minutes per pixel of walking
## (about 0.46 m a pixel at 75 m a minute).
const MINUTES_PER_PIXEL := 0.006
const SIGN_SCRIPT := preload("res://scripts/objects/trailhead_sign.gd")

## Ids of the points found.
var known: Dictionary = {}
## Off in the tests that walk the world without wanting signs or toasts.
var enabled := true

var _points: Array[Dictionary] = []
var _by_id: Dictionary = {}
## False until a save's data (or a new game) has been taken in: a save from
## before trailheads gets the points in the areas it has already seen.
var _settled := false
var _wait := 0.0
var _world: Node = null


func _ready() -> void:
	add_to_group("persist")
	_load_points()


func start_new_game() -> void:
	known.clear()
	known["home"] = true
	_settled = false


## Every point: {id, name, region, spawn, pos (Vector2, in its region),
## lonlat (Vector2), kind ("home", "parking", "trailhead", "campground"),
## known}.
func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for point in _points:
		var entry := point.duplicate()
		entry.known = is_known(point.id)
		out.append(entry)
	return out


func get_point(id: String) -> Dictionary:
	return _by_id.get(id, {})


func is_known(id: String) -> bool:
	return known.has(id) or id == "home"


func count_known() -> int:
	var n := 0
	for point in _points:
		if is_known(point.id):
			n += 1
	return n


func total() -> int:
	return _points.size()


## The points in [param region_id].
func points_in(region_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for point in _points:
		if point.region == region_id:
			out.append(point)
	return out


## The point at the kiosk [param node_name] in [param region_id], or {}.
func point_at_node(region_id: String, node_name: String) -> Dictionary:
	for point in points_in(region_id):
		if point.get("node", "") == node_name:
			return point
	return {}


## Marks a point found. Returns true if it's new.
func register(id: String, announce := true) -> bool:
	if not _by_id.has(id) or known.has(id):
		return false
	known[id] = true
	registered.emit(id)
	if announce:
		get_tree().call_group("hud", "show_message", "Trailhead found: %s (%d of %d). Plan trips from any trailhead sign or map kiosk." % [_by_id[id].name, count_known(), total()])
		Sound.play("story_sting", -8.0, 0.0)
	return true


## The trip from where the player is (or [param from_region]) to the point
## [param id]: {minutes, miles, via, on_foot, arrive (clock text), too_late}.
## {} if there's no open way.
func trip_to(id: String, from_region := "", from_pos := Vector2.INF) -> Dictionary:
	var point := get_point(id)
	if point.is_empty():
		return {}
	var world := _find_world()
	if from_region == "" and world and world.region:
		from_region = world.region.region_id
		from_pos = world.region.to_local(world.player.global_position)
	var trip := {}
	if from_region == point.region:
		var far := 600.0 if from_pos == Vector2.INF else from_pos.distance_to(point.pos)
		trip = {"minutes": maxi(5, roundi(far * MINUTES_PER_PIXEL)), "miles": 0.0, "via": "", "steps": []}
		trip.on_foot = true
	else:
		trip = TravelNet.route(from_region, point.region)
		if trip.is_empty():
			return {}
		var on_foot := true
		for step: Dictionary in trip.steps:
			if step.mode in ["road", "drive", "shuttle"]:
				on_foot = false
		trip.on_foot = on_foot
	trip.arrive = GameClock.get_time_string() if trip.minutes == 0 else _clock_after(trip.minutes)
	trip.too_late = GameClock.is_too_late_for(trip.minutes)
	return trip


## Goes to the point [param id], on the trip map, with the clock moving on by
## the trip (see trip_to). Returns false if it can't be done now.
func travel_to(id: String) -> bool:
	var world := _find_world()
	var point := get_point(id)
	if world == null or point.is_empty() or not is_known(id) or world.get("_busy"):
		return false
	var trip := trip_to(id)
	if trip.is_empty():
		get_tree().call_group("hud", "show_message", "There's no open way to %s right now." % point.name)
		return false
	if trip.too_late:
		get_tree().call_group("hud", "show_message", "It's too late to set out for %s tonight." % point.name)
		return false
	var info := {"title": trip.via if trip.via != "" else point.name, "miles": trip.miles, "on_foot": trip.on_foot}
	await world.go_to_region(point.region, point.spawn, trip.minutes, info)
	return true


## The trip planner at the point [param from_id]: pick a found point and go.
## [param with_map] adds the park map (the kiosks' old drive between hubs).
func plan_trip(player: Player, from_id: String, with_map := false) -> void:
	register(from_id)
	player.can_act = false
	var options: Array = []
	var details: Array = []
	var targets: Array = []
	if with_map:
		options.append("Park map")
		details.append({"title": "Park map", "rows": [], "note": "Drive to another part of the park, or look the roads over."})
		targets.append("map")
	var choices: Array[Dictionary] = []
	for point in _points:
		if point.id == from_id or not is_known(point.id):
			continue
		var trip := trip_to(point.id)
		if trip.is_empty():
			continue
		choices.append({"point": point, "trip": trip})
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (a.point.id == "home") != (b.point.id == "home"):
			return a.point.id == "home"
		return a.trip.minutes < b.trip.minutes)
	for choice in choices:
		var trip: Dictionary = choice.trip
		options.append(str(choice.point.name))
		var length := Park.format_minutes(trip.minutes)
		if float(trip.miles) > 0.0:
			length += ", %s mi" % str(trip.miles)
		details.append({
			"title": choice.point.name,
			"rows": [[null, length, false], [null, "Arrive about %s" % trip.arrive, trip.too_late]],
			"facts": ("By " + trip.via) if trip.via != "" else ("On foot" if trip.on_foot else ""),
			"note": "Too late to set out tonight." if trip.too_late else "",
		})
		targets.append(choice.point.id)
	options.append("Stay here")
	details.append({})
	targets.append("")
	var here := get_point(from_id)
	var prompt := "%s. Where to? You've found %d of %d trailheads, campgrounds and parking areas." % [here.get("name", "Trailhead"), count_known(), total()]
	if choices.is_empty():
		prompt += " Find more and you can plan trips between them from here."
	var box := DialogueBox.open(player)
	var picked := await box.choose(prompt, options, "", [], details)
	box.close()
	player.can_act = true
	if picked < 0 or targets[picked] == "":
		return
	if targets[picked] == "map":
		get_tree().call_group("world", "open_travel_map", "")
		return
	await travel_to(targets[picked])


func save_data() -> Dictionary:
	return {"known": known.keys()}


func load_data(data: Dictionary) -> void:
	known.clear()
	known["home"] = true
	for id in data.get("known", []):
		known[str(id)] = true
	_settled = true


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or not enabled:
		return
	_wait = LOOK_EVERY
	var world := _find_world()
	if world == null or world.region == null or not is_instance_valid(world.player):
		return
	if not _settled:
		_settled = true
		_backfill()
	_place_signs(world.region)
	var neighbor: Variant = world.get("seam")
	if neighbor and neighbor.get("neighbor"):
		_place_signs(neighbor.neighbor)
	var at: Vector2 = world.region.to_local(world.player.global_position)
	for point in points_in(world.region.region_id):
		if not known.has(point.id) and at.distance_to(point.pos) < REACH:
			register(point.id)


## A save from before trailheads: the points in areas it has seen are found.
func _backfill() -> void:
	for key: String in Discoveries.found:
		var region_id := key.get_slice("/", 0)
		for point in points_in(region_id):
			known[point.id] = true


## Puts down the signs of [param region]'s points that have no kiosk.
func _place_signs(region: Region) -> void:
	if region == null or not is_instance_valid(region) or region.entities == null:
		return
	for point in points_in(region.region_id):
		if point.has("node"):
			continue
		var sign_name := "Trailhead_" + str(point.id)
		if region.entities.has_node(sign_name):
			continue
		var trail_sign: Node2D = SIGN_SCRIPT.new()
		trail_sign.name = sign_name
		trail_sign.set("point_id", point.id)
		trail_sign.set("label", point.name)
		trail_sign.position = point.pos
		region.entities.add_child(trail_sign)


func _find_world() -> Node:
	if not is_instance_valid(_world) or not _world.is_inside_tree():
		_world = get_tree().get_first_node_in_group("world")
	return _world


func _clock_after(minutes: int) -> String:
	var at := posmod(GameClock.minutes + minutes, 24 * 60)
	var h12 := floori(at / 60.0) % 12
	return "%d:%02d %s" % [12 if h12 == 0 else h12, at % 60, "AM" if at < 12 * 60 else "PM"]


func _load_points() -> void:
	_points.clear()
	_by_id.clear()
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not read %s" % DATA)
		return
	for raw: Dictionary in data.get("points", []):
		var point := raw.duplicate()
		var pos: Array = raw.get("pos", [0, 0])
		point.pos = Vector2(pos[0], pos[1])
		var lonlat: Array = raw.get("lonlat", [0, 0])
		point.lonlat = Vector2(lonlat[0], lonlat[1])
		point.spawn = str(raw.get("spawn", "arrival"))
		_points.append(point)
		_by_id[point.id] = point
	known["home"] = true
