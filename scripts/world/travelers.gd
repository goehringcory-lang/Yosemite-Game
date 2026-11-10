class_name Travelers
extends Node
## People who walk between the Valley's areas on a day of their own (see
## PLANS): two climbers from Camp 4 out to the foot of El Capitan and back, a
## ranger on rounds out to Curry Village, a kid from Housekeeping Camp sent to
## the Village for groceries and the mail, a hiker off to Mirror Lake, and a
## guest from the Ahwahnee walking to the Village to buy a photograph.
## Everyday people, invented, not historical figures: like the other visitors
## they chat but give no quests and keep no hearts.
##
## Where each one is comes from the clock alone (see day_of): standing at a
## stop, or part way along the walk between two, from how long each walk
## takes at WALK_SPEED. So it holds wherever you are, after a nap or a drive,
## and nothing needs saving. Whoever is in the area you're in, or in the one
## laid beside it at a seam (see Seam), walks there as a Traveler you can talk
## to, and at the seam walks on into the next area with no fade.
##
## The walks (from each stop to the road out of its area, across each area on
## the way, and on to the next stop) are measured on the maps by
## tools/travelers/measure_walks.tscn into WALKS_PATH. Run it again after
## changing a plan or a map; tests/travelers_test checks every walk is there.
## World adds one of these.

const WALKS_PATH := "res://data/park/walks.json"
const CHARACTER_DIR := "res://data/characters/visitors/%s.tres"
## Loaded at spawn, not preloaded: traveler.gd uses Travelers, so a preload
## here is a load cycle ("Parse Error: Busy").
const SCENE_PATH := "res://scenes/world/traveler.tscn"
## Their walking pace (pixels a second): steady, a little slower than
## NPC.TRAVEL_SPEED, since they have all day. With the clock at its usual
## pace (GameClock: 10 minutes every 7 seconds) that's this many pixels a
## minute, which turns a walk's length into its minutes.
const WALK_SPEED := 52.0
const PX_PER_MINUTE := WALK_SPEED * 0.7
## A traveler more than this many legs behind the clock (after a sleep or a
## drive) is put where the clock says, rather than hurrying to catch up.
const MAX_BEHIND := 2
const WARM_SEASONS := [GameClock.Season.SPRING, GameClock.Season.SUMMER, GameClock.Season.FALL]

## Each traveler's day, by visitor id (their CharacterData is
## CHARACTER_DIR % id). "stops" are where they spend it, in order: "at" is
## the time they set off for that stop ("H:MM"; for the first, the time they
## come out), "region" and "spot" where it is (a marker, see Region.get_spawn),
## "offset" where they stand from it (out of the way of the people and things
## already there), "face" which way they look while there, "going" what they
## say on the way and "lines" what they say once there. They go in for the
## night at "home_at", wherever they are. "seasons" (GameClock.Season) and
## "dry" (not on a day of rain or snow) say which days they make the trip; on
## other days they stay at stop "rest" saying "rest_lines", or with "rest" -1
## stay in. "scale" draws them smaller (a child).
const PLANS := {
	"traveler_climber_lead": {
		"seasons": WARM_SEASONS,
		"dry": true,
		"rest": 0,
		"rest_lines": [
			"Rest day. The rock's wet, and my fingers are glad of it.",
			"No climbing in this. We're sorting the rack and telling stories about the last trip.",
		],
		"home_at": "21:30",
		"stops": [
			{"at": "6:00", "region": "yosemite_village", "spot": "camp_4", "offset": [72, 40],
				"lines": ["Rack's sorted, water's filled. We go as soon as my partner finds the other shoe."]},
			{"at": "6:20", "region": "el_capitan_meadow", "spot": "the_nose", "offset": [-64, 40], "face": "up",
				"going": [
					"Off to El Cap. We fix ropes to Sickle Ledge today, sleep in camp, and go for it tomorrow.",
					"Walking out to the Nose. An hour of road, then three thousand feet of rock.",
				],
				"lines": [
					"See the party up on the Stovelegs? That's us tomorrow.",
					"From down here it looks smooth. Up close it's all cracks and ledges, and every one has a name.",
				]},
			{"at": "16:00", "region": "yosemite_village", "spot": "camp_4_fire", "offset": [-48, 36],
				"going": ["Back to Camp 4. My hands are done for the day.", "Ropes are fixed. Now dinner, then sleep, then the real thing."],
				"lines": ["Every pitch up there has a story. Sit down and I'll tell you three.", "Early start tomorrow. Very early. Don't let me talk all night."]},
		],
	},
	"traveler_climber_second": {
		"seasons": WARM_SEASONS,
		"dry": true,
		"rest": 0,
		"rest_lines": [
			"Wet rock and big walls don't mix. I'm patching my pants instead.",
			"Rest days are for eating. I take them very seriously.",
		],
		"home_at": "21:40",
		"stops": [
			{"at": "6:00", "region": "yosemite_village", "spot": "camp_4", "offset": [104, 12],
				"lines": ["Coffee first. Then El Cap.", "Has anybody seen my other shoe? Never mind. It was on my foot."]},
			{"at": "6:22", "region": "el_capitan_meadow", "spot": "the_nose", "offset": [64, 44], "face": "up",
				"going": ["I carry the haul bag, so I set the pace. Slow and steady.", "We'll be at the base before the sun hits the wall."],
				"lines": ["I belay, I haul, I hand up the snacks. Best job on the wall.", "Look up. Keep looking up. It doesn't get any shorter."]},
			{"at": "16:02", "region": "yosemite_village", "spot": "camp_4_fire", "offset": [40, 40],
				"going": ["Back to camp. I've been looking up all day and my neck wants a word."],
				"lines": ["Pass the pot. Climbers eat like bears and sleep like rocks.", "Tomorrow we find out if all that hauling was worth it."]},
		],
	},
	"traveler_ranger": {
		"home_at": "19:00",
		"stops": [
			{"at": "7:30", "region": "yosemite_village", "spot": "ranger_station", "offset": [-56, 44],
				"lines": ["Morning. I walk the river road out to Curry Village today. Anything I should know about?"]},
			{"at": "7:40", "region": "curry_village", "spot": "plaza", "offset": [16, 104],
				"going": [
					"On my rounds to Curry Village. If you see smoke, find a ranger. Don't fight it yourself.",
					"The Merced's snowmelt. Admire it from the bank: it's colder and quicker than it looks.",
					"Stay off the meadows, if you would. Every footprint shows for a season.",
				],
				"lines": [
					"Never keep food in your tent. A bear can smell it from a long way off.",
					"A bear that gets people's food once comes back for more. Keeping them wild is up to all of us.",
				]},
			{"at": "12:30", "region": "yosemite_village", "spot": "ranger_station", "offset": [-56, 44],
				"going": ["Back to the ranger station to write up the day.", "Long walk back. Good day for it, though."],
				"lines": ["Lost and found today: three hats, a thermos, and a very surprised fishing rod.", "Quiet day. That's how I like them."]},
		],
	},
	"traveler_camp_kid": {
		"seasons": WARM_SEASONS,
		"rest": -1,
		"home_at": "20:30",
		"scale": 0.8,
		"stops": [
			{"at": "8:00", "region": "housekeeping_camp", "spot": "camp",
				"lines": ["Mom says if I'm quick to the store I can keep the change."]},
			{"at": "8:10", "region": "yosemite_village", "spot": "village_store", "offset": [36, 52],
				"going": [
					"Going to the Village for eggs and the mail. I'm not supposed to stop and look at stuff.",
					"Eggs, bread, the mail. Eggs, bread, the mail. Don't distract me.",
				],
				"lines": ["They have candy by the register. I'm not supposed to know that.", "Do eggs go bad if you walk slow? Asking for me."]},
			{"at": "9:40", "region": "yosemite_village", "spot": "post_office", "offset": [-36, 52],
				"going": ["Post office next. Grandma writes every week."],
				"lines": ["Nothing from Grandma yet. Maybe tomorrow.", "The man in there says a letter can come all the way from Ohio. Ohio!"]},
			{"at": "10:30", "region": "housekeeping_camp", "spot": "beach",
				"going": ["Back to camp before the eggs get warm.", "Got everything. Mostly. I think."],
				"lines": ["Got everything back, so now I'm allowed to swim. Only up to my knees.", "The river's so clear you can see the fish thinking."]},
		],
	},
	"traveler_day_hiker": {
		"seasons": WARM_SEASONS,
		"dry": true,
		"rest": -1,
		"home_at": "21:00",
		"stops": [
			{"at": "7:00", "region": "upper_pines", "spot": "campground",
				"lines": ["Mirror Lake by breakfast. That's the plan."]},
			{"at": "7:10", "region": "mirror_lake", "spot": "lakeshore", "offset": [-56, 32],
				"going": [
					"Off to Mirror Lake while the water's still. By noon the wind comes up and the mirror's gone.",
					"Up Tenaya Creek to the lake. It's an easy walk if you stop to look at everything, which I do.",
				],
				"lines": [
					"Look at Mount Watkins in the water. It's even better upside down.",
					"In spring it fills right up. By the end of summer it's more meadow than lake.",
				]},
			{"at": "13:00", "region": "upper_pines", "spot": "campground",
				"going": ["Back to camp. The wind's come up and the mirror's gone, so that's my cue."],
				"lines": ["My boots are drying on the picnic table. They earned it.", "Same walk tomorrow, maybe. It's never the same twice."]},
		],
	},
	"traveler_hotel_guest": {
		"dry": true,
		"rest": -1,
		"home_at": "20:00",
		"stops": [
			{"at": "9:00", "region": "the_ahwahnee", "spot": "front_door", "offset": [40, 56],
				"lines": ["The hotel says the Village is a pleasant walk. I've decided to believe them."]},
			{"at": "9:10", "region": "yosemite_village", "spot": "bests_studio", "offset": [-56, 52],
				"going": [
					"Off to the Village to buy a photograph of Half Dome, so they'll believe me back home.",
					"The doorman offered me a car. Imagine seeing all this from a car.",
				],
				"lines": ["Every print in there is better than mine. I'm buying two.", "The light changes every hour here. I'd need a photograph of each one."]},
			{"at": "14:00", "region": "the_ahwahnee", "spot": "tea_lawn", "offset": [32, 24],
				"going": ["Back to the hotel for tea. One mustn't miss tea."],
				"lines": ["Tea on the lawn, with the cliffs for company. I may never go home.", "A deer walked right across the lawn at lunch. Nobody even put down their cup."]},
		],
	},
}

## The walks: {"links": {region: {next region: [exit name, spawn name
## there]}}, "spots": {region: {spot: [x, y]}}, "routes": {region: {"a|b":
## [x, y, x, y, ...]}}}. A route's ends are spots, or "exit:<name>" for the
## way out of the map toward the next area.
static var _walks = null
## Each traveler's day, worked out once a day: [date, segments].
static var _days := {}

## The Traveler walking for each id, while there is one, and for each id the
## [day, segment] they were last seen off in (see _send_in).
var _nodes := {}
var _gone := {}


func _ready() -> void:
	# after the player's tick and the World's seam crossing
	process_physics_priority = 1001


static func walks() -> Dictionary:
	if _walks == null:
		_walks = {}
		if FileAccess.file_exists(WALKS_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(WALKS_PATH))
			if parsed is Dictionary:
				_walks = parsed
	return _walks


## Which areas they walk through from [param from] to [param to], both
## included: the fewest crossings by the walking links in WALKS_PATH. Empty
## if there's no way on foot.
static func region_path(from: String, to: String) -> PackedStringArray:
	var links: Dictionary = walks().get("links", {})
	var came := {from: ""}
	var queue: Array[String] = [from]
	while not queue.is_empty():
		var here: String = queue.pop_front()
		if here == to:
			var path := PackedStringArray()
			var at := to
			while at != "":
				path.insert(0, at)
				at = came[at]
			return path
		var next: Array = links.get(here, {}).keys()
		next.sort()
		for there: String in next:
			if not came.has(there):
				came[there] = here
				queue.append(there)
	return PackedStringArray()


## The name of the point [param id] stands at for [param stop] in
## WALKS_PATH: the spot, or "<spot>@<id>" where they stand off it (see
## "offset" in PLANS).
static func point_of(id: String, stop: Dictionary) -> String:
	return stop.spot + "@" + id if stop.has("offset") else stop.spot


## The walks, one an area, that [param id] takes from stop [param a] to stop
## [param b]: [{"region", "a", "b"}], ends named as in WALKS_PATH's routes.
static func walk_segments(id: String, a: Dictionary, b: Dictionary) -> Array:
	var path := region_path(a.region, b.region)
	if path.size() <= 1:
		return [{"region": a.region, "a": point_of(id, a), "b": point_of(id, b)}]
	var links: Dictionary = walks().links
	var out := []
	var from := point_of(id, a)
	for i in path.size() - 1:
		var link: Array = links[path[i]][path[i + 1]]
		out.append({"region": path[i], "a": from, "b": "exit:" + str(link[0])})
		from = str(link[1])
	out.append({"region": b.region, "a": from, "b": point_of(id, b)})
	return out


## The way from [param a] to [param b] in [param region] (local points), as
## measured; empty if it wasn't.
static func route(region: String, a: String, b: String) -> PackedVector2Array:
	var routes: Dictionary = walks().get("routes", {}).get(region, {})
	var flat: Array = routes.get(a + "|" + b, [])
	var reverse := flat.is_empty()
	if reverse:
		flat = routes.get(b + "|" + a, [])
	var points := PackedVector2Array()
	for i in range(0, flat.size() - 1, 2):
		points.append(Vector2(flat[i], flat[i + 1]))
	if reverse:
		points.reverse()
	return points


## Where [param point] (a spot, or a stand off one: see point_of) is in
## [param region] (local), or INF if not measured.
static func spot_point(region: String, point: String) -> Vector2:
	var at: Array = walks().get("spots", {}).get(region, {}).get(point, [])
	return Vector2(at[0], at[1]) if at.size() == 2 else Vector2.INF


static func length_of(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## The point [param distance] along [param points], and which way it heads there.
static func point_along(points: PackedVector2Array, distance: float) -> Array:
	if points.size() == 1:
		return [points[0], Vector2.ZERO]
	var left := distance
	for i in range(1, points.size()):
		var step := points[i - 1].distance_to(points[i])
		if left <= step or i == points.size() - 1:
			var heading := (points[i] - points[i - 1]).normalized()
			return [points[i - 1] + heading * clampf(left, 0.0, step), heading]
		left -= step
	return [points[points.size() - 1], Vector2.ZERO]


## True if [param plan] makes its trip in [param season] with this weather.
static func travels_on(plan: Dictionary, season: int, wet: bool) -> bool:
	if plan.has("seasons") and not season in plan.seasons:
		return false
	return not (plan.get("dry", false) and wet)


## [param id]'s day in [param season], [param wet] or not: segments in time
## order. A stop {"n", "kind": "stop", "stop" (index), "region", "spot",
## "point" (see point_of), "from", "to"}, or a walk across one area on the
## way to stop "stop" {"n", "kind": "walk", "stop", "region", "a", "b",
## "from", "to"}. Times are minutes since midnight. Empty on a day they stay in.
static func day_of(id: String, season: int, wet: bool) -> Array:
	var plan: Dictionary = PLANS[id]
	var stops: Array = plan.stops
	var home_at := float(_clock(plan.home_at))
	var out := []
	if not travels_on(plan, season, wet):
		var rest: int = plan.get("rest", -1)
		if rest >= 0:
			out.append({"n": 0, "kind": "stop", "stop": rest, "rest": true, "region": stops[rest].region,
				"spot": stops[rest].spot, "point": point_of(id, stops[rest]), "from": float(_clock(stops[0].at)), "to": home_at})
		return out
	var t := float(_clock(stops[0].at))
	for i in stops.size():
		var stop: Dictionary = stops[i]
		if i > 0:
			# they stay at the stop before until it's time to set off (or
			# set off at once, if the walk there ran late)
			t = maxf(t, float(_clock(stop.at)))
			out[-1].to = t
			for walk: Dictionary in walk_segments(id, stops[i - 1], stop):
				var minutes := length_of(route(walk.region, walk.a, walk.b)) / PX_PER_MINUTE
				out.append({"n": out.size(), "kind": "walk", "stop": i, "region": walk.region,
					"a": walk.a, "b": walk.b, "from": t, "to": t + maxf(minutes, 1.0)})
				t += maxf(minutes, 1.0)
		out.append({"n": out.size(), "kind": "stop", "stop": i, "region": stop.region, "spot": stop.spot,
			"point": point_of(id, stop), "from": t, "to": maxf(home_at, t)})
	return out


## [param id]'s day today, worked out once a day.
static func today(id: String) -> Array:
	var date := "%d:%d:%d" % [GameClock.year, GameClock.season, GameClock.day]
	var kept: Array = _days.get(id, [])
	if kept.is_empty() or kept[0] != date:
		var weather := Weather.today()
		var wet: bool = weather.rain > 0.0 or weather.snow > 0.0
		kept = [date, day_of(id, GameClock.season, wet)]
		_days[id] = kept
	return kept[1]


## The segment of [param day] at [param minutes], or {} while they're in.
static func segment_at(day: Array, minutes: float) -> Dictionary:
	for segment: Dictionary in day:
		if minutes >= segment.from and minutes < segment.to:
			return segment
	return {}


## How far along a walk segment is at [param minutes], 0 to 1.
static func progress(segment: Dictionary, minutes: float) -> float:
	if segment.kind != "walk" or segment.to <= segment.from:
		return 1.0
	return clampf((minutes - segment.from) / (segment.to - segment.from), 0.0, 1.0)


## What [param id] might say now, in [param segment]: on the way to a stop,
## at it, or on a rest day.
static func lines_for(id: String, segment: Dictionary) -> Array:
	var plan: Dictionary = PLANS.get(id, {})
	if plan.is_empty() or segment.is_empty():
		return []
	if segment.get("rest", false):
		return plan.get("rest_lines", [])
	var stop: Dictionary = plan.stops[segment.stop]
	var going: Array = stop.get("going", [])
	return going if segment.kind == "walk" and not going.is_empty() else stop.get("lines", [])


## "6:20" as minutes since midnight.
static func _clock(text: String) -> int:
	var parts := text.split(":")
	return int(parts[0]) * 60 + int(parts[1])


## The Travelers out and about now (for tests).
func walkers() -> Array:
	return _nodes.values()


func _world() -> Node:
	return get_parent()


## The regions shown now, by id: the one the player is in, and the one laid
## beside it at a seam.
func _shown() -> Dictionary:
	var shown := {}
	var world := _world()
	if world == null or not "region" in world:
		return shown
	var region: Region = world.region
	if region and region.is_inside_tree() and not region.indoors:
		shown[region.region_id] = region
	var seam: Seam = world.seam if "seam" in world else null
	if seam and seam.neighbor and seam.neighbor.is_inside_tree():
		shown[seam.neighbor.region_id] = seam.neighbor
	return shown


func _physics_process(_delta: float) -> void:
	var shown := _shown()
	var now := GameClock.smooth_minutes()
	for id: String in PLANS:
		_keep(id, shown, now)


## Puts [param id] where the clock says if their area is shown, walks them on
## (over a seam into the next area), or takes them away.
func _keep(id: String, shown: Dictionary, now: float) -> void:
	var day := today(id)
	var segment := segment_at(day, now)
	var node: Traveler = _nodes.get(id)
	if node and (not is_instance_valid(node) or not node.is_inside_tree() or not is_same(node.day, day)):
		_drop(id)
		node = null
	if node:
		_walk_on(id, node, day, segment, shown, now)
		return
	if segment.is_empty() or not shown.has(segment.region):
		return
	# not back for the end of a walk they've just been seen off on
	var gone: Array = _gone.get(id, [])
	if not gone.is_empty() and is_same(gone[0], day) and gone[1] == segment.n:
		return
	node = (load(SCENE_PATH) as PackedScene).instantiate()
	node.name = "Traveler_" + id
	node.character = load(CHARACTER_DIR % id)
	node.plan_id = id
	node.day = day
	(shown[segment.region] as Region).entities.add_child(node)
	node.arrive(segment, progress(segment, now), now)
	_nodes[id] = node


## Keeps a Traveler who's out on their way. Behind the clock (stopped to
## talk, or held up) they hurry through what's left of their own area; far
## behind (after a sleep or a drive) they're put right. At the end of a walk
## they go on to the next part of their day: here, over the seam into the
## area laid beside this one, or (toward an area not shown) out of sight.
func _walk_on(id: String, node: Traveler, day: Array, segment: Dictionary, shown: Dictionary, now: float) -> void:
	if segment.is_empty() and not node.busy():
		_send_in(id, node)
		return
	var target: int = day.size() if segment.is_empty() else segment.n
	if target - int(node.segment.n) > MAX_BEHIND and not node.busy():
		_drop(id)
		return
	node.aim(target, now)
	if not node.finished() or node.segment.n >= day.size() - 1:
		return
	var next: Dictionary = day[node.segment.n + 1]
	if next.region == node.region_id():
		node.start(next)
	elif shown.has(next.region):
		node.hand_over(shown[next.region], next)
	else:
		_send_in(id, node)


## [param node] fades out where they are (gone in for the night, or off along
## the road), and isn't brought back for what's left of that segment.
func _send_in(id: String, node: Traveler) -> void:
	_nodes.erase(id)
	_gone[id] = [node.day, node.segment.n]
	node.go_in()


func _drop(id: String) -> void:
	var node: Traveler = _nodes.get(id)
	_nodes.erase(id)
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent():
		node.get_parent().remove_child(node)
	node.queue_free()


## Forgets the days worked out so far (after the weather or a plan changes,
## in tests).
static func forget() -> void:
	_days.clear()
	_walks = null
