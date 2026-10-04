extends Node
## Yosemite's hubs, the roads and trails between them, and the seasonal
## closures that decide which ones are open.
##
## Routes come from res://data/park/routes.json, which tools/mapgen builds by
## pathfinding along the real OpenStreetMap road network.

const MAIN_HUB := "yosemite_valley"
## Your camp: where new games start and where you wake up each morning.
const HOME_REGION := "lamon_homestead"
const HOME_SPAWN := "home"

## Roads and trails that close for part of the year. "open" and "close" are
## [season, day], inclusive (seasons: 0 Spring, 1 Summer, 2 Fall, 3 Winter).
## The dates are typical ones; in the real park they depend on the snow.
const SEASONAL := {
	"tioga_road": {
		"name": "Tioga Road",
		"open": [1, 1],
		"close": [2, 23],
		"reopens": "late May or June",
		"why": "Tioga Road is closed for winter. It usually reopens in late May or June, once plows clear the snow.",
	},
	"glacier_point_road": {
		"name": "Glacier Point Road",
		"open": [0, 22],
		"close": [2, 23],
		"reopens": "May",
		"why": "Glacier Point Road is closed beyond Badger Pass for winter. It usually reopens in May.",
	},
	"four_mile_trail": {
		"name": "Four Mile Trail",
		"open": [0, 19],
		"close": [2, 28],
		"reopens": "spring",
		"why": "The upper Four Mile Trail is closed for snow and ice. It usually reopens in spring.",
	},
}

signal hub_unlocked(id: String)

var routes: Array[Dictionary] = []
## Ids of hubs opened during play (see HubData.starts_locked).
var unlocked_hubs: Dictionary = {}

var _hubs_by_id: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	for hub in ParkAtlas.HUBS:
		_hubs_by_id[hub.id] = hub
	_load_routes()


func start_new_game() -> void:
	unlocked_hubs.clear()


func get_hub(id: String) -> HubData:
	return _hubs_by_id.get(id)


func is_hub_unlocked(id: String) -> bool:
	var hub := get_hub(id)
	return hub != null and (not hub.starts_locked or unlocked_hubs.has(id))


## Opens a locked hub for travel, for example after the climb that leads there.
func unlock_hub(id: String) -> void:
	if unlocked_hubs.has(id):
		return
	unlocked_hubs[id] = true
	hub_unlocked.emit(id)


## Is this seasonal road or trail open on the current game date?
func is_open(closure: String) -> bool:
	var rule: Dictionary = SEASONAL.get(closure, {})
	if rule.is_empty():
		return true
	var today := _date_index(GameClock.season, GameClock.day)
	return today >= _date_index(rule.open[0], rule.open[1]) and today <= _date_index(rule.close[0], rule.close[1])


## Every way to leave [param hub_id], seen from that hub. Each entry has:
## to, mode ("drive" or "hike"), via, miles, minutes, open, locked,
## closed_reason, path (Array of Vector2 lon/lat, starting here), and spawn
## (the arrival point's name).
func legs_from(hub_id: String) -> Array[Dictionary]:
	var legs: Array[Dictionary] = []
	for route in routes:
		var forward: bool = route.a == hub_id
		if not forward and route.b != hub_id:
			continue
		var destination: String = route.b if forward else route.a
		var locked := not is_hub_unlocked(destination)
		var reason := get_hub(destination).locked_hint if locked else ""
		for closure: String in route.closures:
			if reason == "" and not is_open(closure):
				reason = SEASONAL[closure].why
		var path: Array[Vector2] = []
		for point: Array in route.path:
			path.append(Vector2(point[0], point[1]))
		if not forward:
			path.reverse()
		legs.append({
			"id": route.id,
			"to": destination,
			"mode": route.mode,
			"via": route.via,
			"miles": route.miles,
			"minutes": int(route.minutes_ab if forward else route.minutes_ba),
			"open": reason == "",
			"locked": locked,
			"closed_reason": reason,
			"path": path,
			"spawn": route.spawn_b if forward else route.spawn_a,
		})
	return legs


## The quickest open-or-closed leg from one hub to another, or {} if none.
func best_leg(from_hub: String, to_hub: String, mode := "") -> Dictionary:
	var best := {}
	for leg in legs_from(from_hub):
		if leg.to != to_hub or (mode != "" and leg.mode != mode):
			continue
		if best.is_empty() or (leg.open and not best.open) or (leg.open == best.open and leg.minutes < best.minutes):
			best = leg
	return best


static func format_minutes(minutes: int) -> String:
	var hours := floori(minutes / 60.0)
	if hours == 0:
		return "%d min" % minutes
	if minutes % 60 == 0:
		return "%d hr" % hours
	return "%d hr %d min" % [hours, minutes % 60]


func save_data() -> Dictionary:
	return {"unlocked_hubs": unlocked_hubs.keys()}


func load_data(data: Dictionary) -> void:
	unlocked_hubs.clear()
	for id in data.get("unlocked_hubs", []):
		unlocked_hubs[str(id)] = true


func _date_index(season: int, day: int) -> int:
	return season * GameClock.DAYS_PER_SEASON + day - 1


func _load_routes() -> void:
	var path := "res://data/park/routes.json"
	if not FileAccess.file_exists(path):
		push_warning("No routes yet. Run tools/mapgen to build %s." % path)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not read %s" % path)
		return
	for route: Dictionary in data.get("routes", []):
		routes.append(route)
