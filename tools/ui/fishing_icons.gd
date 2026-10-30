extends SceneTree
## Draws the icons for Greg's flies (assets/sprites/gear/<fly>.png, 64x64 like
## the other gear) and his lost fly box (assets/sprites/fishing_items.png,
## 32x32 frames in ITEMS order). Drawn on a half-size grid and doubled, with
## a dark rim, like tools/ui/valley_life_icons.gd.
## Run: godot --headless --path . -s res://tools/ui/fishing_icons.gd

const FLY_DIR := "res://assets/sprites/gear/"
const FLIES := ["elk_hair_caddis", "parachute_adams", "woolly_bugger", "royal_wulff"]
const ITEMS_OUT := "res://assets/sprites/fishing_items.png"
const ITEMS := ["greg_fly_box"]
const OUTLINE := Color("2a1f1a")
const STEEL := "b8bcc4"
const STEEL_DARK := "70747c"

var im: Image


func _init() -> void:
	for fly: String in FLIES:
		im = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
		_hook()
		call("_" + fly)
		_outline(Rect2i(0, 0, 32, 32))
		_doubled(im).save_png(ProjectSettings.globalize_path(FLY_DIR + fly + ".png"))
	im = Image.create_empty(16 * ITEMS.size(), 16, false, Image.FORMAT_RGBA8)
	for i in ITEMS.size():
		call("_" + ITEMS[i], i * 16)
		_outline(Rect2i(i * 16, 0, 16, 16))
	_doubled(im).save_png(ProjectSettings.globalize_path(ITEMS_OUT))
	print("drew %s and %s" % [", ".join(FLIES), ", ".join(ITEMS)])
	quit()


func rect(x: int, y: int, w: int, h: int, hex: String) -> void:
	im.fill_rect(Rect2i(x, y, w, h), Color(hex))


func px(x: int, y: int, hex: String) -> void:
	im.set_pixel(x, y, Color(hex))


func _doubled(image: Image) -> Image:
	var big := image.duplicate()
	big.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return big


## A dry-fly hook lying left to right: the eye at the left, the shank under
## the dressing, and the bend and point curling up at the right.
func _hook() -> void:
	rect(7, 18, 2, 2, STEEL)
	px(7, 18, STEEL_DARK)
	rect(9, 19, 15, 1, STEEL)
	rect(24, 19, 1, 4, STEEL)
	rect(19, 23, 5, 1, STEEL)
	rect(18, 21, 1, 2, STEEL)
	px(18, 20, STEEL_DARK)
	px(24, 23, STEEL_DARK)


## Tan body, a brown hackle wound down it, and a wing of pale elk hair swept
## back over the top.
func _elk_hair_caddis() -> void:
	rect(10, 16, 12, 3, "a8875a")
	for x in [11, 14, 17, 20]:
		rect(x, 15, 1, 5, "6a4424")
	for i in 12:
		px(10 + i, 14 - i / 4, "e8d8a8")
		px(11 + i, 13 - i / 4, "d8c088")
	rect(19, 9, 6, 2, "e8d8a8")
	rect(23, 8, 2, 2, "f0e4c0")
	rect(9, 15, 2, 4, "4a3020")


## A grey body and tail, a white post standing up from the thorax, and a
## grizzly hackle wound flat round it like a little parachute.
func _parachute_adams() -> void:
	for i in 6:
		px(21 + i, 18 - i / 3, "8a7a6a")
	rect(11, 16, 11, 3, "8a8a92")
	rect(11, 16, 11, 1, "a8a8b0")
	rect(13, 7, 2, 9, "f5f5f0")
	rect(12, 6, 4, 2, "ffffff")
	rect(8, 13, 12, 2, "8a7058")
	for x in [8, 11, 14, 17]:
		px(x, 13, "e8e0d0")
		px(x + 1, 14, "3a3028")


## A long black marabou tail, an olive chenille body, and a black hackle
## wound down it: a streamer that swims like a leech.
func _woolly_bugger() -> void:
	rect(21, 15, 7, 4, "1e1e24")
	rect(25, 14, 5, 3, "2a2a32")
	rect(27, 17, 4, 2, "1e1e24")
	px(30, 13, "2a2a32")
	rect(10, 15, 12, 5, "5a6a2a")
	rect(10, 15, 12, 1, "7a8a3a")
	for x in [10, 13, 16, 19]:
		rect(x, 13, 1, 8, "15141c")
	rect(9, 16, 2, 3, "15141c")


## The Royal Wulff: a red silk band between two bumps of green-bronze
## peacock, upright white wings, a brown hackle, and a white tail.
func _royal_wulff() -> void:
	rect(22, 16, 6, 2, "f0ece0")
	px(27, 15, "ffffff")
	rect(18, 16, 4, 3, "3a5a2a")
	rect(18, 16, 4, 1, "6a8a3a")
	rect(14, 16, 4, 3, "c8302e")
	rect(14, 16, 4, 1, "e85a4a")
	rect(11, 16, 3, 3, "3a5a2a")
	rect(11, 16, 3, 1, "6a8a3a")
	rect(11, 8, 2, 8, "f5f5f0")
	rect(14, 7, 2, 9, "ffffff")
	rect(9, 14, 8, 2, "7a4a24")
	for x in [9, 12, 15]:
		px(x, 14, "a86a34")


## A dented aluminum fly box with its clasp, and one fly hooked in the lid
## where Greg always leaves his favorite.
func _greg_fly_box(x0: int) -> void:
	rect(x0 + 2, 4, 12, 9, "a8acb4")
	rect(x0 + 2, 4, 12, 1, "d8dce4")
	rect(x0 + 2, 12, 12, 1, "70747c")
	rect(x0 + 2, 7, 12, 1, "80848c")
	rect(x0 + 7, 7, 2, 2, "e0c060")
	px(x0 + 5, 10, "8a8e96")
	rect(x0 + 10, 3, 3, 2, "a8875a")
	px(x0 + 12, 2, "e8d8a8")


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
