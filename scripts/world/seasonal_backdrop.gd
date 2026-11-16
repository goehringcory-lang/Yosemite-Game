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

var _showing := ""


func _ready() -> void:
	_dress()
	GameClock.day_started.connect(func(_d: int, _s: int, _y: int) -> void: _dress())


func _dress() -> void:
	var snowy := GameClock.season == GameClock.Season.WINTER or GameClock.season == GameClock.Season.SPRING
	var want := winter if snowy else summer
	if want == _showing or want == "":
		return
	_showing = want
	texture = load(want)
