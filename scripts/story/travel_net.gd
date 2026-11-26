class_name TravelNet
extends RefCounted
## Every way between the park's areas, as one graph: walking over a seam,
## a door or gate, a trail with minutes (RegionDoor), a road with minutes
## (RegionExit), driving on from a road exit or a parking kiosk along
## Park.routes, and the Valley shuttle. Trailheads prices fast travel off it
## (route), and tests check that every area can be reached and left.
##
## The ways are read straight from the region scenes and their story, door
## and dressing overlays as text, so the graph follows whatever exits the
## scenes have now with nothing to rebuild, and no scene is loaded to read
## it. Closures, locks, perks and the open world flag are applied when a
## route is asked for (Park.legs_from and Park.is_open), not when it is read.

const REGION_DIR := "res://scenes/regions/"
const OVERLAY_DIRS := [
	"res://scenes/story/content/",
	"res://scenes/story/doors/",
	"res://scenes/story/dressing/",
]
## Minutes to walk across an area to the next over a seam, and through a
## door or gate that takes none of its own. A rough walk, so the price of a
## trip counts the areas it crosses.
const WALK_MINUTES := 6
const DOOR_MINUTES := 1

## Properties read off the ways' nodes.
const KEYS := [
	"target_region", "target_spawn", "drive_to", "travel_to", "stop_region",
	"stop_spawn", "minutes", "miles", "closure", "label", "stop_name",
	"region_id", "hub_id", "display_name", "indoors", "walk_minutes",
	"needs_quest", "needs_hub",
]

## region id -> {hub, name, indoors, ways: Array[Dictionary]}
static var _graph: Dictionary = {}
## scene path -> the script its root node runs ("" if none)
static var _root_scripts: Dictionary = {}


## The graph, read once.
static func graph() -> Dictionary:
	if _graph.is_empty():
		_build()
	return _graph


## Forgets the graph, so the next call reads the scenes again (tests).
static func clear() -> void:
	_graph = {}
	_root_scripts = {}


static func has_region(id: String) -> bool:
	return graph().has(id)


static func region_hub(id: String) -> String:
	return str(graph().get(id, {}).get("hub", ""))


## The quickest open way from one area to another: {minutes, miles, steps:
## [{from, to, mode, label, minutes}], via (the roads and trails it takes,
## as text)}. {} if there's no open way, or the two are the same place.
static func route(from_region: String, to_region: String) -> Dictionary:
	var g := graph()
	if from_region == to_region or not g.has(from_region) or not g.has(to_region):
		return {}
	var best := {from_region: 0}
	var came := {}
	var done := {}
	while true:
		var here := ""
		var low := INF
		for id: String in best:
			if not done.has(id) and best[id] < low:
				low = best[id]
				here = id
		if here == "" or here == to_region:
			break
		done[here] = true
		for way: Dictionary in ways_from(here):
			var cost: float = low + way.minutes
			if not best.has(way.to) or cost < best[way.to]:
				best[way.to] = cost
				came[way.to] = way
	if not best.has(to_region):
		return {}
	var steps: Array[Dictionary] = []
	var at := to_region
	var miles := 0.0
	while at != from_region:
		var way: Dictionary = came[at]
		steps.push_front(way)
		miles += float(way.get("miles", 0.0))
		at = way.from
	return {"minutes": int(best[to_region]), "miles": snappedf(miles, 0.1), "steps": steps, "via": via_text(steps)}


## Every open way out of [param region_id] now: {from, to, spawn, minutes,
## miles, mode ("walk", "door", "trail", "road", "drive" or "shuttle"),
## label}.
static func ways_from(region_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var area: Dictionary = graph().get(region_id, {})
	if area.is_empty():
		return out
	var hub: String = area.hub
	for way: Dictionary in area.ways:
		match way.kind:
			"exit":
				if way.target_region != "":
					var minutes := int(way.minutes)
					out.append(_way(region_id, way.target_region, way.target_spawn,
							minutes if minutes > 0 else _walk(way.target_region), "road" if minutes > 0 else "walk",
							way.label, float(way.miles)))
				elif way.drive_to != "":
					var leg := Park.best_leg(hub, way.drive_to, "drive")
					if leg.is_empty() or not leg.open:
						continue
					var to: String = way.stop_region if way.stop_region != "" else _arrival(way.drive_to)
					var minutes := int(way.minutes) if int(way.minutes) > 0 else int(leg.minutes)
					var miles := float(way.miles) if int(way.minutes) > 0 else float(leg.miles)
					out.append(_way(region_id, to, way.stop_spawn if way.stop_region != "" else str(leg.spawn),
							minutes, "drive", way.label if way.label != "" else str(leg.via), miles))
				elif way.travel_to != "":
					out.append_array(_drives(region_id, hub))
			"door":
				if way.closure != "" and not Park.is_open(way.closure):
					continue
				if not _door_unlocked(way):
					continue
				var minutes := int(way.minutes)
				# a gate onto a road (Hetch Hetchy Road) is driven, not hiked
				var trail := "road" if " Road" in str(way.label).get_slice(",", 0) else "trail"
				out.append(_way(region_id, way.target_region, way.target_spawn,
						minutes if minutes > 0 else DOOR_MINUTES, trail if minutes > 0 else "door",
						str(way.label).get_slice(",", 0).strip_edges(), 0.0))
			"kiosk":
				out.append_array(_drives(region_id, hub))
			"shuttle":
				for stop: Dictionary in ShuttleStop.STOPS:
					if stop.name != way.stop_name and stop.region != region_id:
						out.append(_way(region_id, stop.region, stop.spawn, ShuttleStop.RIDE_MINUTES, "shuttle", "Valley shuttle", 0.0))
	# keep the quickest way to each place
	var quickest := {}
	for way in out:
		if graph().has(way.to) and (not quickest.has(way.to) or way.minutes < quickest[way.to].minutes):
			quickest[way.to] = way
	var result: Array[Dictionary] = []
	for to: String in quickest:
		result.append(quickest[to])
	return result


## "Big Oak Flat Road, Tioga Road": the named roads and trails a trip takes,
## in order, without the short walks between.
static func via_text(steps: Array) -> String:
	var names: PackedStringArray = []
	for step: Dictionary in steps:
		if step.mode in ["walk", "door"] or step.label == "":
			continue
		for part in str(step.label).replace(" and ", ", ").split(","):
			var name := part.strip_edges()
			if name != "" and not names.has(name):
				names.append(name)
	return ", ".join(names)


## RegionDoor.is_unlocked, from the scene's text.
static func _door_unlocked(way: Dictionary) -> bool:
	if Park.open_world:
		return true
	if way.needs_quest != "" and not (QuestLog.active.has(way.needs_quest) or QuestLog.is_completed(way.needs_quest)):
		return false
	return way.needs_hub == "" or Park.is_hub_unlocked(way.needs_hub)


## Minutes to walk into [param region_id] and across it: its own
## Region.walk_minutes (a long road or trail walked end to end), or a rough
## walk.
static func _walk(region_id: String) -> int:
	var minutes := int(graph().get(region_id, {}).get("walk_minutes", 0))
	return minutes if minutes > 0 else WALK_MINUTES


static func _drives(region_id: String, hub: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if hub == "":
		return out
	for leg in Park.legs_from(hub):
		if leg.open:
			out.append(_way(region_id, _arrival(leg.to), str(leg.spawn), int(leg.minutes), "drive", str(leg.via), float(leg.miles)))
	return out


static func _arrival(hub_id: String) -> String:
	var hub := Park.get_hub(hub_id)
	if hub == null:
		return hub_id
	return hub.arrival_region if hub.arrival_region != "" else hub.id


static func _way(from: String, to: String, spawn: String, minutes: int, mode: String, label: String, miles: float) -> Dictionary:
	return {"from": from, "to": to, "spawn": spawn, "minutes": minutes, "mode": mode, "label": label, "miles": miles}


static func _build() -> void:
	_graph = {}
	for file in DirAccess.get_files_at(REGION_DIR):
		if not file.ends_with(".tscn"):
			continue
		var id := file.get_basename()
		var nodes := _read(REGION_DIR + file)
		var root: Dictionary = nodes[0] if not nodes.is_empty() else {}
		var props: Dictionary = root.get("props", {})
		var area := {
			"hub": str(props.get("hub_id", "")),
			"name": str(props.get("display_name", id)),
			"indoors": str(props.get("indoors", "false")) == "true",
			"walk_minutes": int(props.get("walk_minutes", "0")),
			"ways": [],
		}
		for dir: String in OVERLAY_DIRS:
			if FileAccess.file_exists(dir + file):
				nodes.append_array(_read(dir + file))
		for node: Dictionary in nodes:
			var way := _as_way(node)
			if not way.is_empty():
				area.ways.append(way)
		_graph[id] = area


## The way [param node] is, or {} if it isn't one.
static func _as_way(node: Dictionary) -> Dictionary:
	var kind := ""
	match str(node.script).get_file():
		"region_exit.gd":
			kind = "exit"
		"region_door.gd", "building_door.gd":
			kind = "door"
		"travel_point.gd":
			kind = "kiosk"
		"shuttle_stop.gd":
			kind = "shuttle"
	if kind == "":
		return {}
	var props: Dictionary = node.props
	var way := {"kind": kind}
	for key in ["target_region", "target_spawn", "drive_to", "travel_to", "stop_region", "stop_spawn", "closure", "label", "stop_name", "needs_quest", "needs_hub"]:
		way[key] = str(props.get(key, ""))
	way.minutes = int(props.get("minutes", "0"))
	way.miles = float(props.get("miles", "0"))
	if kind == "door" and way.target_region == "":
		return {}
	return way


## The nodes of a scene file: [{name, script, props}], the root first. A node
## that is an instance of another scene runs that scene's root script.
static func _read(path: String) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return nodes
	var resources := {}
	var node: Dictionary = {}
	for line in text.split("\n"):
		if line.begins_with("[ext_resource"):
			resources[_attr(line, "id")] = _attr(line, "path")
		elif line.begins_with("[node "):
			node = {"name": _attr(line, "name"), "script": "", "props": {}}
			var instance := _ext_id(line, "instance=")
			if instance != "":
				node.script = _root_script(str(resources.get(instance, "")))
			nodes.append(node)
		elif line.begins_with("["):
			node = {}
		elif not node.is_empty():
			var eq := line.find(" = ")
			if eq <= 0:
				continue
			var key := line.substr(0, eq)
			if key == "script":
				node.script = str(resources.get(_ext_id(line, "ExtResource("), ""))
			elif key in KEYS:
				var value := line.substr(eq + 3).strip_edges()
				if value.begins_with("\""):
					value = value.substr(1, value.length() - 2) if value.ends_with("\"") and value.length() > 1 else value.substr(1)
					value = value.replace("\\\"", "\"")
				node.props[key] = value
	return nodes


static func _root_script(scene_path: String) -> String:
	if scene_path == "" or not scene_path.ends_with(".tscn"):
		return ""
	if _root_scripts.has(scene_path):
		return _root_scripts[scene_path]
	_root_scripts[scene_path] = ""
	var nodes := _read(scene_path)
	var script: String = nodes[0].script if not nodes.is_empty() else ""
	_root_scripts[scene_path] = script
	return script


## name="X" -> X
static func _attr(line: String, attr: String) -> String:
	var start := line.find(" %s=\"" % attr)
	if start < 0:
		return ""
	start += attr.length() + 3
	return line.substr(start, line.find("\"", start) - start)


## ...ExtResource("12_ab")... -> 12_ab
static func _ext_id(line: String, after: String) -> String:
	var start := line.find(after)
	if start < 0:
		return ""
	start = line.find("ExtResource(\"", start)
	if start < 0:
		return ""
	start += 13
	return line.substr(start, line.find("\"", start) - start)
