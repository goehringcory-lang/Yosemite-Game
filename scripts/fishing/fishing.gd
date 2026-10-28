class_name Fishing
extends Node2D
## Fishing with a fly rod, in Stardew Valley's way: face a river, creek or
## lake with the rod in your pack and press use to cast. After a wait a fish
## takes the fly, and you play it in on FishingMinigame's bar.
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
		if is_water(ground, player.global_position + Vector2(player.facing) * reach):
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


## Picks what takes the fly, weighted by how common each fish is.
func pick(hub_id: String, season: int) -> Dictionary:
	var fish := fish_in(hub_id, season)
	var total := 0
	for one in fish:
		total += int(one.weight)
	var roll := _rng.randi_range(1, total)
	for one in fish:
		roll -= int(one.weight)
		if roll <= 0:
			return one
	return fish[0]


func interact(player: Player) -> void:
	if _busy or not can_fish(player):
		return
	_busy = true
	player.can_act = false
	var world := get_tree().get_first_node_in_group("world")
	var fish := pick(world.region.hub_id, GameClock.season)
	var game := FishingMinigame.new()
	get_tree().root.add_child(game)
	game.start(fish)
	var caught: bool = await game.finished
	game.queue_free()
	GameClock.advance_minutes(CAST_MINUTES)
	if caught:
		land(fish)
	else:
		get_tree().call_group("hud", "show_message", "It threw the hook and was gone.")
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
