class_name AmbientFx
extends CPUParticles2D
## Small living touches that need no art: chimney smoke, waterfall mist,
## rising sparks, and fireflies over the meadow after dark. Drop one where it
## should be and pick an [member effect]. Particles are plain pixels, so they
## match the pixel art at any zoom.

## "drift" is blossom petals in spring and falling leaves in fall, and nothing
## the rest of the year.
@export_enum("smoke", "mist", "sparks", "fireflies", "drift") var effect := "smoke"
## Half the width and height of the area it spreads over, in pixels.
@export var area := Vector2(2, 1)

var _tint: CanvasModulate


func _ready() -> void:
	local_coords = false
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = area
	var fade := Gradient.new()
	match effect:
		"smoke":
			amount = 9
			lifetime = 4.0
			direction = Vector2(0.25, -1)
			spread = 14.0
			gravity = Vector2(1.5, -1.0)
			initial_velocity_min = 5.0
			initial_velocity_max = 9.0
			scale_amount_min = 1.6
			scale_amount_max = 3.2
			fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
			fade.colors = PackedColorArray([Color(0.9, 0.9, 0.9, 0.0), Color(0.9, 0.9, 0.9, 0.5), Color(0.75, 0.75, 0.78, 0.0)])
		"mist":
			amount = 18
			lifetime = 2.6
			direction = Vector2(0, -1)
			spread = 30.0
			gravity = Vector2.ZERO
			initial_velocity_min = 2.0
			initial_velocity_max = 6.0
			scale_amount_min = 2.0
			scale_amount_max = 5.0
			fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
			fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(0.92, 0.97, 1.0, 0.32), Color(0.92, 0.97, 1.0, 0.0)])
		"sparks":
			amount = 7
			lifetime = 1.3
			direction = Vector2(0, -1)
			spread = 25.0
			gravity = Vector2(0, -3)
			initial_velocity_min = 8.0
			initial_velocity_max = 16.0
			scale_amount_min = 1.0
			scale_amount_max = 1.4
			fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
			fade.colors = PackedColorArray([Color(1, 0.85, 0.3, 0.0), Color(1, 0.7, 0.25, 1.0), Color(0.9, 0.3, 0.1, 0.0)])
		"fireflies":
			amount = 16
			lifetime = 7.0
			direction = Vector2(1, 0)
			spread = 180.0
			gravity = Vector2.ZERO
			initial_velocity_min = 2.0
			initial_velocity_max = 6.0
			angular_velocity_min = -30.0
			angular_velocity_max = 30.0
			scale_amount_min = 1.0
			scale_amount_max = 1.5
			emitting = false
			fade.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
			fade.colors = PackedColorArray([Color(0.6, 0.8, 0.2, 0.0), Color(0.9, 1.0, 0.4, 0.9), Color(0.9, 1.0, 0.4, 0.9), Color(0.6, 0.8, 0.2, 0.0)])
		"drift":
			amount = 26
			lifetime = 7.0
			direction = Vector2(1, 1)
			spread = 35.0
			gravity = Vector2(3.0, 4.0)
			initial_velocity_min = 1.0
			initial_velocity_max = 4.0
			angular_velocity_min = -60.0
			angular_velocity_max = 60.0
			scale_amount_min = 1.0
			scale_amount_max = 1.6
			emitting = false
			fade.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
			fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	color_ramp = fade
	if effect == "fireflies":
		# Fireflies glow: additive, so they show against the night tint.
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add


func _process(_delta: float) -> void:
	if effect == "drift":
		# Petals of apple blossom in spring, gold leaves in fall.
		match GameClock.season:
			GameClock.Season.SPRING:
				color = Color(0.98, 0.84, 0.88)
				emitting = true
			GameClock.Season.FALL:
				color = Color(0.9, 0.66, 0.22)
				emitting = true
			_:
				emitting = false
	elif effect == "fireflies":
		# Summer nights only: no fireflies in spring, fall or winter.
		emitting = GameClock.season == GameClock.Season.SUMMER and _darkness() > 0.35
	elif effect == "smoke":
		# Chimneys smoke in the cold months and at either end of the day.
		var hour := GameClock.hour
		emitting = GameClock.season >= GameClock.Season.FALL or hour < 9 or hour >= 17


func _darkness() -> float:
	if _tint == null:
		_tint = get_tree().root.find_child("DayNight", true, false) as CanvasModulate
		if _tint == null:
			return 0.0
	if not _tint.visible:
		return 0.0
	var lum := (_tint.color.r + _tint.color.g + _tint.color.b) / 3.0
	return clampf((0.9 - lum) / 0.45, 0.0, 1.0)
