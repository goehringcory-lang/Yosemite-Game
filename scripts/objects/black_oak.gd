extends StaticBody2D
## A California black oak. Its canopy changes color with the seasons, and
## the Forage node drops acorns and morels beneath it.

## Canopy tint per season. The canopy art is drawn in light grays so these
## colors come through cleanly.
const SEASON_COLORS := [
	Color(0.62, 0.85, 0.45), # Spring: fresh, pinkish-green new leaves
	Color(0.38, 0.64, 0.32), # Summer
	Color(0.98, 0.66, 0.22), # Fall: golden-orange
	Color(0.55, 0.46, 0.38), # Winter: bare brown branches
]

var _season := -1

@onready var canopy: Sprite2D = $Canopy


func _ready() -> void:
	add_to_group("black_oak")


func _process(_delta: float) -> void:
	if GameClock.season != _season:
		_season = GameClock.season
		canopy.modulate = SEASON_COLORS[_season]
