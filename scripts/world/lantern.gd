class_name Lantern
extends NightLight
## The small warm pool of light round the player after dark outdoors, as if
## they carried a camp lantern, so a moonless meadow is dark but never black.
## Like every NightLight it comes up as the day and night tint darkens, so
## it's off by day and indoors. World puts one on the player.


func _ready() -> void:
	name = "Lantern"
	strength = 0.6
	radius = 88.0
	flicker = 0.08
	halo = 0.0
	outdoor_only = true
	super()
	position = Vector2(5, -12)
	color = Color(1.0, 0.8, 0.55)
