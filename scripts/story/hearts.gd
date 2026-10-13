class_name Hearts
extends RefCounted
## Little pixel hearts for friendship: full and empty 7x6 pictures for the
## Register, and the heart that floats up when someone's fondness grows.

const RED := Color("d83a4a")
const LIGHT := Color("f8a0a8")
const DARK := Color("8a1e2a")
const EMPTY := Color("5a4a40")
const INK := Color("2a1f1a")
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


## A heart picture: full (red) or empty (an outline).
static func texture(full: bool) -> Texture2D:
	if full and _full:
		return _full
	if not full and _empty:
		return _empty
	var im := Image.create_empty(9, 8, false, Image.FORMAT_RGBA8)
	for y in SHAPE.size():
		for x in 7:
			if SHAPE[y][x] == "#":
				var color := (RED if y < 3 else DARK) if full else EMPTY
				if full and (x == 1 or x == 4) and y == 1:
					color = LIGHT
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
