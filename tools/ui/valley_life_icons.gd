extends SceneTree
## Draws the icons for fishing and the festivals: the fly rod
## (assets/sprites/gear/fly_rod.png, 64x64 like the other gear) and the
## brown trout, brook trout and Facelift litter
## (assets/sprites/valley_life_items.png, 32x32 frames in ITEMS order). Each
## is drawn on a half-size grid and doubled, with a dark rim, like the shoes
## in tools/npcgen/gear_icons.gd.
## Run: godot --headless --path . -s res://tools/ui/valley_life_icons.gd

const ROD_OUT := "res://assets/sprites/gear/fly_rod.png"
const ITEMS_OUT := "res://assets/sprites/valley_life_items.png"
const ITEMS := ["brown_trout", "brook_trout", "litter"]
const OUTLINE := Color("2a1f1a")

var im: Image


func _init() -> void:
	im = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	_fly_rod()
	_outline(Rect2i(0, 0, 32, 32))
	_doubled(im).save_png(ProjectSettings.globalize_path(ROD_OUT))
	im = Image.create_empty(16 * ITEMS.size(), 16, false, Image.FORMAT_RGBA8)
	for i in ITEMS.size():
		call("_" + ITEMS[i], i * 16)
		_outline(Rect2i(i * 16, 0, 16, 16))
	_doubled(im).save_png(ProjectSettings.globalize_path(ITEMS_OUT))
	print("drew fly_rod and %s" % ", ".join(ITEMS))
	quit()


func rect(x: int, y: int, w: int, h: int, hex: String) -> void:
	im.fill_rect(Rect2i(x, y, w, h), Color(hex))


func px(x: int, y: int, hex: String) -> void:
	im.set_pixel(x, y, Color(hex))


func _doubled(image: Image) -> Image:
	var big := image.duplicate()
	big.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return big


## A cane fly rod laid corner to corner: a cork grip and reel at the foot,
## the blank tapering to the tip, and a loop of line with a fly on it.
func _fly_rod() -> void:
	for i in 24:
		var x := 4 + i
		var y := 27 - i
		px(x, y, "8a5a2e" if i > 6 else "6a4020")
		if i < 14:
			px(x, y + 1, "b07a44")
	# the cork grip and the reel
	for i in 5:
		rect(3 + i, 26 - i, 2, 2, "d8b880")
	rect(2, 28, 4, 3, "4a4a52")
	px(3, 29, "9a9aa2")
	# guides along the blank
	for i in [10, 15, 20]:
		px(4 + i, 28 - i, "c8c8d0")
	# the line, looping down from the tip, and the fly
	var points := [Vector2i(28, 3), Vector2i(29, 7), Vector2i(29, 11), Vector2i(28, 15), Vector2i(26, 18)]
	for p: Vector2i in points:
		px(p.x, p.y, "f0e8d8")
	px(29, 5, "f0e8d8")
	px(29, 9, "f0e8d8")
	px(29, 13, "f0e8d8")
	px(27, 17, "f0e8d8")
	rect(24, 18, 2, 2, "c8502e")
	px(23, 19, "e8c84a")


func _trout(x0: int, back: String, belly: String, spots: String, fin: String) -> void:
	# a fish facing left: body, tail, and spots along its back
	rect(x0 + 2, 6, 10, 4, back)
	rect(x0 + 3, 5, 7, 1, back)
	rect(x0 + 3, 9, 8, 2, belly)
	rect(x0 + 1, 7, 1, 2, back)
	rect(x0 + 12, 5, 2, 6, fin)
	px(x0 + 14, 4, fin)
	px(x0 + 14, 11, fin)
	px(x0 + 3, 7, "15141c")
	for p in [Vector2i(5, 6), Vector2i(7, 7), Vector2i(9, 6), Vector2i(10, 8), Vector2i(6, 8)]:
		px(x0 + p.x, p.y, spots)


func _brown_trout(x0: int) -> void:
	_trout(x0, "8a6a34", "e0c070", "3a2414", "7a5a2a")
	px(x0 + 8, 8, "c8502e") # the red spots browns have too


func _brook_trout(x0: int) -> void:
	_trout(x0, "4a5a3a", "e07a3a", "d8d070", "c8502e")
	px(x0 + 8, 8, "e84a4a") # red spots in blue halos
	px(x0 + 9, 9, "f0f0f0") # white-edged fins


## A crushed soda can and a scrap of wrapper: what the Facelift picks up.
func _litter(x0: int) -> void:
	rect(x0 + 3, 4, 6, 8, "b8b8c0")
	rect(x0 + 4, 5, 4, 6, "c8302e")
	rect(x0 + 3, 7, 6, 1, "8a8a92") # the crumple
	rect(x0 + 3, 4, 6, 1, "e0e0e8")
	rect(x0 + 9, 9, 4, 3, "e8d84a")
	px(x0 + 12, 8, "e8d84a")
	px(x0 + 10, 10, "4a8ad8")


func _outline(area: Rect2i) -> void:
	var edge: Array[Vector2i] = []
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if im.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if area.has_point(p) and im.get_pixel(p.x, p.y).a > 0.0 and im.get_pixel(p.x, p.y) != OUTLINE:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixelv(p, OUTLINE)
