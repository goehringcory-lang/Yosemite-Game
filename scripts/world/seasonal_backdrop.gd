class_name SeasonalBackdrop
extends Sprite2D
## A backdrop hung above a map whose far mountains wear the season: the
## [member summer] picture in summer and fall, the [member winter] one (deep
## snow above the trees) in winter and spring. Only the picture in use is
## loaded. Tuolumne Meadows' High Sierra skyline
## (scenes/world/tuolumne_skyline.tscn, painted by
## tools/hubs/tuolumne_skyline.py).

@export_file("*.png") var summer := ""
@export_file("*.png") var winter := ""
## Areas that lie where this backdrop hangs (Glen Aulin, beside Tuolumne's
## north edge): while one is laid out beside the map (WorldStream), the far
## mountains fade away so they don't stand on its ground.
@export var gives_way_to: PackedStringArray = []
## How fast it fades out and back, in alpha per second.
const GIVE_WAY_RATE := 2.5

var _showing := ""
var _world: Node


func _ready() -> void:
	_dress()
	GameClock.day_started.connect(func(_d: int, _s: int, _y: int) -> void: _dress())
	set_process(not gives_way_to.is_empty())


func _process(delta: float) -> void:
	var target := 0.0 if neighbor_laid() else 1.0
	modulate.a = move_toward(modulate.a, target, GIVE_WAY_RATE * delta)
	visible = modulate.a > 0.0


## Is one of [member gives_way_to] laid out beside the map now?
func neighbor_laid() -> bool:
	if not is_instance_valid(_world):
		_world = get_tree().get_first_node_in_group("world")
	if _world == null or not ("stream" in _world) or _world.stream == null:
		return false
	for r: Region in _world.stream.loaded_regions():
		if is_instance_valid(r) and r.region_id in gives_way_to:
			return true
	return false


func _dress() -> void:
	var snowy := GameClock.season == GameClock.Season.WINTER or GameClock.season == GameClock.Season.SPRING
	var want := winter if snowy else summer
	if want == _showing or want == "":
		return
	_showing = want
	texture = load(want)
