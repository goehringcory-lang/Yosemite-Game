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
## often it takes the fly in each kind of water (FishingWater: "run", the
## plain river; "rapids"; "hole", the deep pools), how hard it fights (0 to
## 1), its length in inches (smallest and largest you'll catch), and the
## item you keep, or "" to let it go.
##
## The Merced's fish are the park's real ones. Rainbow trout are native, hold
## in the fast water and take a fly anywhere; brown trout were stocked from
## Europe and lie deep in the holes; Sacramento suckers, native too, graze the
## bottom of the slow pools in the warmer months. Brook trout were packed up
## to Tuolumne, which had no fish at all.
const FISH := [
	{"id": "rainbow_trout", "hubs": ["yosemite_valley", "el_portal", "wawona"], "seasons": [0, 1, 2, 3],
		"waters": {"run": 4, "rapids": 9, "hole": 2}, "fight": 0.55, "inches": [7, 18],
		"keep": "", "release": "Native to the Merced, and catch and release here. You wet your hands and ease it back into the current."},
	{"id": "brown_trout", "hubs": ["yosemite_valley", "el_portal", "wawona"], "seasons": [0, 1, 2, 3],
		"waters": {"run": 3, "rapids": 1, "hole": 6}, "fight": 0.75, "inches": [9, 24],
		"keep": "brown_trout", "release": ""},
	{"id": "sacramento_sucker", "hubs": ["yosemite_valley", "el_portal", "wawona"], "seasons": [0, 1, 2],
		"waters": {"run": 1, "rapids": 0, "hole": 4}, "fight": 0.3, "inches": [10, 20],
		"keep": "", "release": "A native bottom feeder, all lips and patience. Back it goes."},
	{"id": "brook_trout", "hubs": ["tuolumne_meadows"], "seasons": [0, 1, 2],
		"waters": {"run": 5, "rapids": 5, "hole": 5}, "fight": 0.45, "inches": [6, 13],
		"keep": "brook_trout", "release": ""},
]

## How the water changes a fish on the line: rapids add this to its fight,
## and holes grow bigger fish (the length is drawn nearer the top of its
## range: the power below, lower is bigger). A fish in the top TROPHY of its
## range is a trophy.
const RAPIDS_FIGHT := 0.15
const SIZE_POWER := {"run": 1.6, "rapids": 1.3, "hole": 0.6}
const TROPHY := 0.85

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
## The cast underway, while it's on screen: the angler in the world swings
## the rod with it (see _pose_angler and _draw), and where the fly lands.
var _game: FishingMinigame
var _fly_at := Vector2.ZERO
var _time := 0.0

const ROD_COLOR := Color("8a5a2e")
const ROD_TIP := Color("c8a060")
const LINE := Color(0.93, 0.9, 0.8, 0.85)
const ROD_LENGTH := 26.0
## Where the rod hand is (from the angler's feet) with the rod back over the
## shoulder and held out in front, by facing (CharacterSheet's poses).
const HAND_UP := {Vector2i.LEFT: Vector2(4, -40), Vector2i.RIGHT: Vector2(-6, -40), Vector2i.DOWN: Vector2(8, -40), Vector2i.UP: Vector2(-10, -40)}
## Which way the rod points from the hand, by facing: up over your
## shoulder on the back cast, and out over the water (off to one side when
## you face the screen, so it shows).
const ROD_BACK := {Vector2i.LEFT: Vector2(0.45, -1), Vector2i.RIGHT: Vector2(-0.45, -1), Vector2i.DOWN: Vector2(0.4, -1), Vector2i.UP: Vector2(-0.3, -1)}
const ROD_OUT := {Vector2i.LEFT: Vector2(-1, -0.5), Vector2i.RIGHT: Vector2(1, -0.5), Vector2i.DOWN: Vector2(0.7, 0.55), Vector2i.UP: Vector2(0.45, -1)}
const HAND_OUT := {Vector2i.LEFT: Vector2(-12, -22), Vector2i.RIGHT: Vector2(10, -22), Vector2i.DOWN: Vector2(2, -18), Vector2i.UP: Vector2(4, -26)}


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if not is_instance_valid(_game):
		_game = null
		return
	_time += delta
	_pose_angler()
	queue_redraw()


## The angler follows the cast: rod back over the shoulder on the back cast,
## out in front on the forward cast and while the fly drifts, and leaning
## back into it on the reel.
func _pose_angler() -> void:
	var player := get_parent() as Player
	if player == null:
		return
	match _game.phase:
		FishingMinigame.Phase.BACK_CAST:
			player.pose("arms_up")
		FishingMinigame.Phase.DONE:
			player.clear_pose()
		_:
			player.pose("reach")


## The rod and the line, while a cast is on: the line loops out behind on
## the back cast, unrolls toward the water on the forward cast, lies on the
## water while you wait, and runs taut (the rod bending) on the reel.
func _draw() -> void:
	if _game == null:
		return
	var player := get_parent() as Player
	var facing: Vector2i = player.facing if player else Vector2i.DOWN
	var phase := _game.phase
	var back := phase == FishingMinigame.Phase.BACK_CAST
	var hand: Vector2 = (HAND_UP if back else HAND_OUT)[facing]
	var ahead := Vector2(facing)
	var sweep := _game.meter_pos if _game.meter_dir > 0.0 else 1.0 - _game.meter_pos
	var rod_dir: Vector2 = (ROD_BACK if back else ROD_OUT)[facing].normalized()
	var tip := hand + rod_dir * ROD_LENGTH
	var reeling := phase == FishingMinigame.Phase.REEL
	if reeling:
		# the rod bows toward the fish and shivers as it pulls
		tip += (_fly_at - tip).normalized() * (4.0 + sin(_time * 22.0) * 1.5)
	_pixel_line(hand, tip, ROD_COLOR)
	_pixel_line(tip - rod_dir * 3.0, tip, ROD_TIP)
	match phase:
		FishingMinigame.Phase.BACK_CAST:
			var loop := tip - ahead * (10.0 + 26.0 * sweep) + Vector2(0, -6.0 + 10.0 * sweep)
			_curve(tip, loop, tip + (loop - tip) * 0.5 + Vector2(0, -8))
		FishingMinigame.Phase.FORWARD_CAST:
			var out := tip.lerp(_fly_at, 0.25 + 0.6 * sweep)
			_curve(tip, out, tip.lerp(out, 0.5) + Vector2(0, -10.0 * (1.0 - sweep)))
		FishingMinigame.Phase.WAIT, FishingMinigame.Phase.REEL:
			var sag := 1.0 if reeling else 10.0
			_curve(tip, _fly_at, tip.lerp(_fly_at, 0.5) + Vector2(0, sag))
			# rings spreading where the fly sits
			var ring := fmod(_time * 1.4, 1.0)
			var c := Color(1, 1, 1, 0.5 * (1.0 - ring))
			var r := 2.0 + ring * 6.0
			draw_rect(Rect2((_fly_at + Vector2(-r, -1)).floor(), Vector2(2, 2)), c)
			draw_rect(Rect2((_fly_at + Vector2(r - 2, -1)).floor(), Vector2(2, 2)), c)
			if reeling:
				draw_rect(Rect2((_fly_at + Vector2(-1, -3 + sin(_time * 18.0) * 1.0)).floor(), Vector2(2, 2)), Color(1, 1, 1, 0.8))


## A line of whole pixels from [param a] to [param b].
func _pixel_line(a: Vector2, b: Vector2, c: Color) -> void:
	var steps := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y)) / 2.0))
	for i in steps + 1:
		draw_rect(Rect2(a.lerp(b, float(i) / steps).floor(), Vector2(2, 2)), c)


## The fly line from [param a] to [param b], bellied through [param via].
func _curve(a: Vector2, b: Vector2, via: Vector2) -> void:
	var steps := maxi(2, int(a.distance_to(b) / 2.0))
	for i in steps + 1:
		var t := float(i) / steps
		var p := a.lerp(via, t).lerp(via.lerp(b, t), t)
		draw_rect(Rect2(p.floor(), Vector2(1, 1)), LINE)


func get_prompt() -> String:
	var player := get_parent() as Player
	var water := water_ahead(player) if player else null
	return "Fish %s" % water.title if water and water.title != "" else "Fish"


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


## Where the fly lands from where [param player] stands: the nearest of
## REACH in front of them that's water, or their feet if none is.
static func cast_point(player: Player) -> Vector2:
	var world := player.get_tree().get_first_node_in_group("world")
	var ground := _ground(world) if world else null
	for reach: float in REACH:
		var at := player.global_position + Vector2(player.facing) * reach
		if ground and is_water(ground, at):
			return at
	return player.global_position


## The rapids or hole the fly would land in, or null on a plain run.
static func water_ahead(player: Player) -> FishingWater:
	return FishingWater.at(player.get_tree(), cast_point(player))


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


## How often [param fish] takes [param fly] in [param water] compared with
## the others: its weight there, doubled if the fly favors it.
static func weight_for(fish: Dictionary, fly: Dictionary, water := FishingWater.RUN) -> int:
	return int(fish.waters.get(water, 0)) * (2 if fly.get("favors", "") == fish.id else 1)


## Picks what will rise to a good cast in [param water], weighted by how
## common each fish is there and the fly tied on. The fish comes with its
## "inches" drawn ("length") and its fight for the water. {} if nothing
## lives there.
func pick(hub_id: String, season: int, fly := {}, water := FishingWater.RUN) -> Dictionary:
	var fish := fish_in(hub_id, season).filter(func(one: Dictionary) -> bool: return weight_for(one, fly, water) > 0)
	if fish.is_empty():
		return {}
	var total := 0
	for one in fish:
		total += weight_for(one, fly, water)
	var roll := _rng.randi_range(1, total)
	var chosen: Dictionary = fish[0]
	for one in fish:
		roll -= weight_for(one, fly, water)
		if roll <= 0:
			chosen = one
			break
	return hooked(chosen, water, _rng.randf())


## [param fish] as it comes out of [param water]: a "length" in inches,
## drawn by [param roll] (0 to 1) across its range, bigger in a hole; a
## "trophy" flag; and its fight, harder in the rapids and for a big fish.
static func hooked(fish: Dictionary, water: String, roll: float) -> Dictionary:
	var out := fish.duplicate()
	var share := pow(clampf(roll, 0.0, 1.0), float(SIZE_POWER.get(water, 1.6)))
	var inches: Array = fish.inches
	out["length"] = int(round(lerpf(inches[0], inches[1], share)))
	out["trophy"] = share >= TROPHY
	out["fight"] = clampf(float(fish.fight) + (RAPIDS_FIGHT if water == "rapids" else 0.0) + 0.1 * share, 0.0, 0.95)
	out["water"] = water
	return out


func interact(player: Player) -> void:
	if _busy or not can_fish(player):
		return
	_busy = true
	player.can_act = false
	var world := get_tree().get_first_node_in_group("world")
	var fly := tied_fly()
	var fish := pick(world.region.hub_id, GameClock.season, fly, FishingWater.kind_at(get_tree(), cast_point(player)))
	if fish.is_empty():
		fish = pick(world.region.hub_id, GameClock.season, fly)
	var game := FishingMinigame.new()
	get_tree().root.add_child(game)
	game.start(fish, -1, fly)
	_game = game
	_fly_at = to_local(cast_point(player))
	var caught: bool = await game.finished
	var outcome := game.outcome
	_game = null
	player.clear_pose()
	if caught:
		player.pose("arms_up", 0.9) # holding it up
	queue_redraw()
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
	var size := "%d-inch " % fish.length if fish.has("length") else ""
	var text := "Caught a %s%s%s!" % [size, fish_name, " (new in your field log)" if first else ""]
	if fish.get("trophy", false):
		text += " A trophy!"
	if fish.keep != "":
		Inventory.add(fish.keep)
		text += " It goes in your pack for the pot."
	else:
		text += " " + fish.release
	get_tree().call_group("hud", "show_message", text)
	Sound.play("item_get" if first else "pickup", -2.0, 0.1)
	return text
