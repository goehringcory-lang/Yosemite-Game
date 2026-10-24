class_name SoundEmitter
extends AudioStreamPlayer2D
## A looping sound placed in the world, louder the closer you are: the crackle
## of a campfire or the roar of a waterfall. AmbientFx adds one to every fire's
## sparks and every waterfall's mist; World adds one at each waterfall Place on
## the hub maps (attach_waterfalls). Plays on the Ambience bus.

## The loop to play (a sound in assets/audio/: "campfire", "waterfall").
@export var sound := "campfire"
## Level at the source, before distance and the waterfall season.
@export var level := 1.0

var _check := 0.0


## An emitter of [param sound] heard out to [param reach] world pixels.
static func make(sound_id: String, reach: float, level_at_source := 1.0) -> SoundEmitter:
	var emitter := SoundEmitter.new()
	emitter.name = "Sound_" + sound_id
	emitter.sound = sound_id
	emitter.level = level_at_source
	emitter.max_distance = reach
	return emitter


## Adds a waterfall's roar at each Place in [param region] that is a fall or
## a cascade ("Bridalveil Fall", "Royal Arch Cascade"; not "...Trailhead" or
## the Firefall). Hand-built areas whose waterfall mist already carries the
## sound are left as they are.
static func attach_waterfalls(region: Region) -> void:
	if not region.find_children("Sound_waterfall", "", true, false).is_empty():
		return
	for place in region.get_places():
		var label := place.display_name
		if not (label.ends_with(" Fall") or label.ends_with(" Falls") or label.ends_with(" Cascade")) or label.contains("Firefall"):
			continue
		place.add_child(make("waterfall", 720.0, 1.0))


## Rivers and creeks: the Merced, the Tuolumne, Tenaya Creek. A soft loop of
## running water at the river tile nearest the middle of each RIVER_BLOCK of
## the map that has river in it, so walking along the bank you're never out
## of earshot and the sound doesn't stack up. Done once, when a region first
## loads; regions with no river (or no tiles) get nothing.
const RIVER_BLOCK := 14
const RIVER_REACH := 460.0
const RIVER_LEVEL := 0.6
const _Terrain := preload("res://tools/mapgen/terrain.gd")


static func attach_rivers(region: Region) -> void:
	if region.indoors or not region.find_children("Sound_river*", "", true, false).is_empty():
		return
	var ground := region.get_ground()
	if ground == null:
		return
	# block -> [best cell, its distance to the block's middle]
	var best := {}
	for cell in ground.get_used_cells():
		if ground.get_cell_source_id(cell) != ForageSpawner.SOURCE_TERRAIN:
			continue
		var kind := ground.get_cell_atlas_coords(cell).y
		if kind != _Terrain.RIVER and kind != _Terrain.CREEK:
			continue
		var block := Vector2i(floori(cell.x / float(RIVER_BLOCK)), floori(cell.y / float(RIVER_BLOCK)))
		var middle := Vector2(block) * RIVER_BLOCK + Vector2.ONE * RIVER_BLOCK / 2.0
		var d := Vector2(cell).distance_squared_to(middle)
		if not best.has(block) or d < best[block][1]:
			best[block] = [cell, d]
	# where a river runs along a block's edge, two blocks' picks can sit side
	# by side: keep the first and drop any within half a block of it
	var placed: Array[Vector2i] = []
	for block: Vector2i in best:
		var cell: Vector2i = best[block][0]
		if placed.any(func(other: Vector2i) -> bool: return Vector2(other).distance_to(Vector2(cell)) < RIVER_BLOCK / 2.0):
			continue
		placed.append(cell)
		var emitter := make("river", RIVER_REACH, RIVER_LEVEL)
		emitter.name = "Sound_river_%d_%d" % [block.x, block.y]
		emitter.position = ground.to_global(ground.map_to_local(cell)) - region.global_position
		region.add_child(emitter)


func _ready() -> void:
	bus = Sound.BUS_AMBIENCE
	stream = Sound.loop_stream(sound)
	attenuation = 1.6
	panning_strength = 0.6
	_refresh_level()


func _notification(what: int) -> void:
	# A region the player left keeps its nodes but leaves the tree, which
	# stops the sound; start it again on the way back in.
	if what == NOTIFICATION_ENTER_TREE and stream:
		_resume.call_deferred()


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 2.0
		_refresh_level()


func _refresh_level() -> void:
	volume_linear = level * (Sound.waterfall_level() if sound == "waterfall" else 1.0)
	_resume()


## Starts the loop at a random point (so two fires don't crackle in step).
func _resume() -> void:
	if stream and not playing and is_inside_tree():
		play(randf() * stream.get_length())
