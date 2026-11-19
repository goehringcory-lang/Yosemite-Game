class_name Hearts
extends RefCounted
## Little pixel hearts for friendship: shaded 7x6 pictures (full ruby red
## with a glossy highlight, or carved recessed empty) for the Register, and
## the hearts that float up when someone's fondness grows.

const RED := Color("e03c3c")
const LIGHT := Color("ffa8b0")
const DARK := Color("9e212b")
const EMPTY := Color("574131")
const EMPTY_SHADE := Color("3e2d21")
const INK := Color("2a1b14")
const SHAPE := [
	".##.##.",
	"#######",
	"#######",
	".#####.",
	"..###..",
	"...#...",
]

static var _full: ImageTexture
static var _empty: ImageTexture


## A heart picture: full (shaded crimson) or empty (carved recess).
static func texture(full: bool) -> Texture2D:
	if full and _full:
		return _full
	if not full and _empty:
		return _empty
	var im := Image.create_empty(9, 8, false, Image.FORMAT_RGBA8)
	for y in SHAPE.size():
		for x in 7:
			if SHAPE[y][x] == "#":
				var color: Color
				if full:
					color = RED if (y < 3 and x < 5) else DARK
					if (x == 1 and y == 1) or (x == 2 and y == 1) or (x == 1 and y == 2):
						color = LIGHT
					elif x == 4 and y == 1:
						color = RED.lightened(0.22)
				else:
					color = EMPTY_SHADE if y <= 1 else EMPTY
				im.set_pixel(x + 1, y + 1, color)
	# a dark rim
	var rim: Array[Vector2i] = []
	for y in 8:
		for x in 9:
			if im.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < 9 and n.y < 8 and im.get_pixel(n.x, n.y).a > 0.0 and im.get_pixel(n.x, n.y) != INK:
					rim.append(Vector2i(x, y))
					break
	for p in rim:
		im.set_pixelv(p, INK)
	var tex := ImageTexture.create_from_image(im)
	if full:
		_full = tex
	else:
		_empty = tex
	return tex


## A heart rising over [param anchor]'s head, with two small ones beside it.
static func pop(anchor: Node2D) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	for i in 3:
		var heart := Sprite2D.new()
		heart.texture = texture(true)
		heart.z_index = 30
		heart.scale = Vector2.ONE * (2.0 if i == 0 else 1.2)
		anchor.add_child(heart)
		var start := Vector2([0, -18, 18][i], -60 if i == 0 else -52)
		heart.position = start
		heart.modulate.a = 0.0
		var tween := heart.create_tween()
		tween.tween_interval(i * 0.12)
		tween.tween_property(heart, "modulate:a", 1.0, 0.1)
		tween.parallel().tween_property(heart, "position", start + Vector2(0, -28), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(heart, "modulate:a", 0.0, 0.3)
		tween.tween_callback(heart.queue_free)
