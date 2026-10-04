extends StaticBody2D
## A California black oak. Its canopy changes color with the seasons, and
## the Forage node drops acorns and morels beneath it.

## Canopy tint per season, for the older light-gray canopy art. A canopy sheet
## with four frames (spring, summer, fall, winter), like the Lamon Homestead's
## oaks, is already in color: this picks its frame and leaves the tint alone.
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
		if canopy.hframes >= 4:
			canopy.frame = clampi(_season, 0, canopy.hframes - 1)
			canopy.modulate = Color.WHITE
		else:
			canopy.modulate = SEASON_COLORS[_season]
