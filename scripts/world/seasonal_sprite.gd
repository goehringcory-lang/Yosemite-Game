class_name SeasonalSprite
extends Sprite2D
## A picture that changes in winter: the pool at Curry Village becomes the ice
## rink. Set [member winter_texture]; the sprite's own texture is used the rest
## of the year.

@export var winter_texture: Texture2D

var _summer_texture: Texture2D


func _ready() -> void:
	_summer_texture = texture
	GameClock.day_started.connect(_update.unbind(3))
	_update()


func _update() -> void:
	texture = winter_texture if GameClock.season == GameClock.Season.WINTER and winter_texture else _summer_texture
