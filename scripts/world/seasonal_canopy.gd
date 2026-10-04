extends TileMapLayer
## Tints the black oak canopies on this layer for the season. The canopy art
## is drawn in light grays, like the BlackOak scene's.

const BlackOak = preload("res://scripts/objects/black_oak.gd")

var _season := -1


func _process(_delta: float) -> void:
	if GameClock.season != _season:
		_season = GameClock.season
		modulate = BlackOak.SEASON_COLORS[_season]
