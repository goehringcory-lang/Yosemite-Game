class_name Fishing
extends Node2D
## Fly fishing: face a river, creek or lake with the rod in your pack and
## press use to cast. FishingMinigame runs the cast (a back cast and a
## forward cast, each stopped on a timing meter) and, if a fish rises to it,
## the fight on its bar.
##
## Greg, the fishing guide who's all over Curry Village, gives you your first
## rod (his quest "greg_first_rod") and trades you better flies (FLIES) for
## food and fish. The best fly you own is the one tied on.
##
## The fish are the park's real ones, by water: rainbow trout (native) and
## brown trout (stocked from Europe) in the Merced through the Valley, El
## Portal and Wawona, Sacramento suckers in the warmer water downstream, and
## brook trout, stocked in high-country waters that had no fish at all, at
## Tuolumne. In the Valley the Merced's rainbow trout are catch and release,
## as they are in the real park, and so are the suckers: those go in your
## field log and back in the water. Brown and brook trout you can keep for
## the pot.
##
## Player keeps one of these as a child and offers it as the thing to use
## when there's nothing else in front of you (Player.get_target).

const ROD := "fly_rod"
## How far in front of your feet the fly lands.
const REACH := [24.0, 40.0]
## Game minutes a cast takes, caught or not.
const CAST_MINUTES := 15

const Terrain := preload("res://tools/mapgen/terrain.gd")

## Each fish: its field log id, the hubs it's in, the seasons it bites, how
## hard it fights (0 to 1), and the item you keep, or "" to let it go.
const FISH := [
	{"id": "rainbow_trout", "hubs": ["yosemite_valley", "el_portal", "wawona"], "seasons": [0, 1, 2, 3], "weight": 4,
		"fight": 0.55, "keep": "", "release": "Native to the Merced, and catch and release here. You wet your hands and ease it back into the current."},
	{"id": "brown_trout", "hubs": ["yosemite_valley", "el_portal", "wawona"], "seasons": [0, 1, 2, 3], "weight": 3,
		"fight": 0.75, "keep": "brown_trout", "release": ""},
	{"id": "sacramento_sucker", "hubs": ["el_portal", "wawona"], "seasons": [0, 1, 2], "weight": 2,
		"fight": 0.3, "keep": "", "release": "A native bottom feeder, all lips and patience. Back it goes."},
	{"id": "brook_trout", "hubs": ["tuolumne_meadows"], "seasons": [0, 1, 2], "weight": 5,
		"fight": 0.45, "keep": "brook_trout", "release": ""},
]

## The flies Greg trades, plainest first. Each is a piece of gear; the last
## one you own is tied on. "window" widens the green on the cast meter,
## "bite" adds to the chance something rises to a cast that wasn't perfect,
## "hook" sets the hook harder (more line out when the fight starts), and
## "favors" names a fish that takes it twice as often.
const FLIES := [
	{"id": "elk_hair_caddis", "window": 0.04, "bite": 0.1, "hook": 0.0, "favors": "rainbow_trout"},
	{"id": "parachute_adams", "window": 0.06, "bite": 0.15, "hook": 0.05, "favors": ""},
	{"id": "woolly_bugger", "window": 0.06, "bite": 0.2, "hook": 0.1, "favors": "brown_trout"},
	{"id": "royal_wulff", "window": 0.08, "bite": 0.25, "hook": 0.15, "favors": "brook_trout"},
]

## What the HUD says when a cast comes to nothing, by FishingMinigame.outcome.
const MISSES := {
	"snagged": "Your back cast caught the willows behind you. By the time you've picked the fly loose, the pool has had a good look at you.",
	"spooked": "The forward cast slapped down in a heap, and every fish in the pool bolted.",
	"no_rise": "A fair cast, but nothing rose to it. A cleaner loop might do it.",
	"lost": "It threw the hook and was gone.",
	"gave_up": "You reel in your line.",
}

var _rng := RandomNumberGenerator.new()
var _busy := false


func _ready() -> void:
	_rng.randomize()


func get_prompt() -> String:
	return "Fish"


## The fish that bite in [param hub_id] in [param season].
static func fish_in(hub_id: String, season: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fish: Dictionary in FISH:
		if hub_id in fish.hubs and season in fish.seasons:
			out.append(fish)
	return out


static func get_fish(id: String) -> Dictionary:
	for fish: Dictionary in FISH:
		if fish.id == id:
			return fish
	return {}


## True if you can cast from where [param player] stands: rod in the pack,
## outdoors where fish bite this season, and water just in front.
static func can_fish(player: Player) -> bool:
	if Gear.count(ROD) <= 0:
		return false
	var world := player.get_tree().get_first_node_in_group("world")
	var region: Region = world.region if world and "region" in world else null
	if region == null or region.indoors or fish_in(region.hub_id, GameClock.season).is_empty():
		return false
	var ground := _ground(world)
	if ground == null:
		return false
	for reach: float in REACH:
		var at := player.global_position + Vector2(player.facing) * reach
		if is_water(ground, at) and not SeasonalFalls.dried_up(region, at):
			return true
	return false


## True if the ground at [param at] is a river, lake or creek.
static func is_water(ground: TileMapLayer, at: Vector2) -> bool:
	var cell := ground.local_to_map(ground.to_local(at))
	if ground.get_cell_source_id(cell) < 0:
		return false
	var coords := ground.get_cell_atlas_coords(cell)
	if ground.get_cell_source_id(cell) == ForageSpawner.SOURCE_TERRAIN:
		return coords.y in ForageSpawner.WATER_TERRAIN
	return coords == ForageSpawner.WATER_TILE


static func _ground(world: Node) -> TileMapLayer:
	var forage: ForageSpawner = world.forage if "forage" in world else null
	if forage and forage.ground:
		return forage.ground
	return world.region.find_child("Ground", true, false) as TileMapLayer


## The fly tied on: the best of FLIES you own, with its "name", or {} for
## the plain fly that comes with the rod.
static func tied_fly() -> Dictionary:
	for i in range(FLIES.size() - 1, -1, -1):
		var fly: Dictionary = FLIES[i]
		if Gear.count(fly.id) > 0:
			var tied := fly.duplicate()
			tied["name"] = Gear.get_gear(fly.id).display_name
			return tied
	return {}


## How often [param fish] takes [param fly] compared with the others: its
## weight, doubled if the fly favors it.
static func weight_for(fish: Dictionary, fly: Dictionary) -> int:
	return int(fish.weight) * (2 if fly.get("favors", "") == fish.id else 1)


## Picks what will rise to a good cast, weighted by how common each fish is
## and the fly tied on.
func pick(hub_id: String, season: int, fly := {}) -> Dictionary:
	var fish := fish_in(hub_id, season)
	var total := 0
	for one in fish:
		total += weight_for(one, fly)
	var roll := _rng.randi_range(1, total)
	for one in fish:
		roll -= weight_for(one, fly)
		if roll <= 0:
			return one
	return fish[0]


func interact(player: Player) -> void:
	if _busy or not can_fish(player):
		return
	_busy = true
	player.can_act = false
	var world := get_tree().get_first_node_in_group("world")
	var fly := tied_fly()
	var fish := pick(world.region.hub_id, GameClock.season, fly)
	var game := FishingMinigame.new()
	get_tree().root.add_child(game)
	game.start(fish, -1, fly)
	var caught: bool = await game.finished
	var outcome := game.outcome
	game.queue_free()
	GameClock.advance_minutes(CAST_MINUTES)
	if caught:
		land(fish)
	else:
		get_tree().call_group("hud", "show_message", MISSES.get(outcome, MISSES.lost))
		Sound.play("ui_back", -4.0, 0.05)
	player.can_act = true
	_busy = false


## A fish on the bank: into the field log, and into your pack or back in
## the water. Returns the message shown.
func land(fish: Dictionary) -> String:
	var fish_name: String = FieldLog.get_animal(fish.id).get("name", fish.id)
	var first := FieldLog.spot(fish.id, true)
	var text := "Caught a %s%s!" % [fish_name, " (new in your field log)" if first else ""]
	if fish.keep != "":
		Inventory.add(fish.keep)
		text += " It goes in your pack for the pot."
	else:
		text += " " + fish.release
	get_tree().call_group("hud", "show_message", text)
	Sound.play("item_get" if first else "pickup", -2.0, 0.1)
	return text
