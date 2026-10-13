class_name AmbientFx
extends CPUParticles2D
## Small living touches that need no art: chimney smoke, waterfall mist,
## rising sparks, and fireflies over the meadow after dark. Drop one where it
## should be and pick an [member effect]. Particles are plain pixels, so they
## match the pixel art at any zoom.

## "drift" is blossom petals in spring and falling leaves in fall, and nothing
## the rest of the year.
@export_enum("smoke", "mist", "sparks", "fireflies", "drift") var effect := "smoke"
## Half the width and height of the area it spreads over, in pixels (world px).
@export var area := Vector2(4, 2)

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
			gravity = Vector2(3.0, -2.0)
			initial_velocity_min = 10.0
			initial_velocity_max = 18.0
			scale_amount_min = 3.2
			scale_amount_max = 6.4
			fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
			fade.colors = PackedColorArray([Color(0.9, 0.9, 0.9, 0.0), Color(0.9, 0.9, 0.9, 0.5), Color(0.75, 0.75, 0.78, 0.0)])
		"mist":
			amount = 18
			lifetime = 2.6
			direction = Vector2(0, -1)
			spread = 30.0
			gravity = Vector2.ZERO
			initial_velocity_min = 4.0
			initial_velocity_max = 12.0
			scale_amount_min = 4.0
			scale_amount_max = 10.0
			fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
			fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(0.92, 0.97, 1.0, 0.32), Color(0.92, 0.97, 1.0, 0.0)])
		"sparks":
			amount = 7
			lifetime = 1.3
			direction = Vector2(0, -1)
			spread = 25.0
			gravity = Vector2(0, -6)
			initial_velocity_min = 16.0
			initial_velocity_max = 32.0
			scale_amount_min = 2.0
			scale_amount_max = 2.8
			fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
			fade.colors = PackedColorArray([Color(1, 0.85, 0.3, 0.0), Color(1, 0.7, 0.25, 1.0), Color(0.9, 0.3, 0.1, 0.0)])
		"fireflies":
			amount = 16
			lifetime = 7.0
			direction = Vector2(1, 0)
			spread = 180.0
			gravity = Vector2.ZERO
			initial_velocity_min = 4.0
			initial_velocity_max = 12.0
			angular_velocity_min = -30.0
			angular_velocity_max = 30.0
			scale_amount_min = 2.0
			scale_amount_max = 3.0
			emitting = false
			fade.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
			fade.colors = PackedColorArray([Color(0.6, 0.8, 0.2, 0.0), Color(0.9, 1.0, 0.4, 0.9), Color(0.9, 1.0, 0.4, 0.9), Color(0.6, 0.8, 0.2, 0.0)])
		"drift":
			amount = 26
			lifetime = 7.0
			direction = Vector2(1, 1)
			spread = 35.0
			gravity = Vector2(6.0, 8.0)
			initial_velocity_min = 2.0
			initial_velocity_max = 8.0
			angular_velocity_min = -60.0
			angular_velocity_max = 60.0
			scale_amount_min = 2.0
			scale_amount_max = 3.2
			emitting = false
			fade.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
			fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	color_ramp = fade
	if effect == "mist" or effect == "smoke":
		# Puffs (a 7x6 texture shown at 2x, so 2px cells) with a dithered edge, fading in steps, so
		# they read as pixel art and don't blur into a soft blob.
		texture = _puff()
		fade.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		var steps := Gradient.new()
		steps.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		var tint: Color = fade.colors[1]
		steps.offsets = PackedFloat32Array([0.0, 0.15, 0.35, 0.7, 0.88])
		steps.colors = PackedColorArray([Color(tint, tint.a * 0.4), Color(tint, tint.a * 0.75), Color(tint, tint.a), Color(tint, tint.a * 0.6), Color(tint, tint.a * 0.3)])
		color_ramp = steps
		scale_amount_min = 2.0
		scale_amount_max = 2.0
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Fires crackle and waterfalls roar, heard from nearby.
	if effect == "sparks":
		add_child(SoundEmitter.make("campfire", 300.0, 0.8))
	elif effect == "mist":
		add_child(SoundEmitter.make("waterfall", 720.0, 1.0))
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


## A 7x6 puff: a solid middle and a checkered rim.
static func _puff() -> Texture2D:
	var im := Image.create_empty(7, 6, false, Image.FORMAT_RGBA8)
	for y in 6:
		for x in 7:
			var d := Vector2((x - 3.0) / 3.5, (y - 2.5) / 3.0).length()
			if d < 0.62 or (d < 1.0 and (x + y) % 2 == 0):
				im.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(im)


func _darkness() -> float:
	if _tint == null:
		_tint = get_tree().root.find_child("DayNight", true, false) as CanvasModulate
		if _tint == null:
			return 0.0
	if not _tint.visible:
		return 0.0
	var lum := (_tint.color.r + _tint.color.g + _tint.color.b) / 3.0
	return clampf((0.9 - lum) / 0.45, 0.0, 1.0)
