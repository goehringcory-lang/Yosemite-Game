extends SceneTree
## Draws the icons for a night out in the backcountry: the bear canister
## (assets/sprites/gear/bear_canister.png, 64x64 like the other gear) and the
## wilderness permit (assets/sprites/backcountry_items.png, 32x32 frames in
## ITEMS order). Drawn on a half-size grid and doubled, with a dark rim, like
## tools/ui/fishing_icons.gd.
## Run: godot --headless --path . -s res://tools/ui/backcountry_icons.gd

const CANISTER_OUT := "res://assets/sprites/gear/bear_canister.png"
const ITEMS_OUT := "res://assets/sprites/backcountry_items.png"
const ITEMS := ["wilderness_permit"]
const OUTLINE := Color("2a1f1a")

var im: Image


func _init() -> void:
	im = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	_bear_canister()
	_outline(Rect2i(0, 0, 32, 32))
	_doubled(im).save_png(ProjectSettings.globalize_path(CANISTER_OUT))
	im = Image.create_empty(16 * ITEMS.size(), 16, false, Image.FORMAT_RGBA8)
	for i in ITEMS.size():
		call("_" + ITEMS[i], i * 16)
		_outline(Rect2i(i * 16, 0, 16, 16))
	_doubled(im).save_png(ProjectSettings.globalize_path(ITEMS_OUT))
	print("drew bear_canister and %s" % ", ".join(ITEMS))
	quit()


func rect(x: int, y: int, w: int, h: int, hex: String) -> void:
	im.fill_rect(Rect2i(x, y, w, h), Color(hex))


func px(x: int, y: int, hex: String) -> void:
	im.set_pixel(x, y, Color(hex))


func _doubled(image: Image) -> Image:
	var big := image.duplicate()
	big.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return big


## A smoky translucent drum standing up, lit from the left, with the dark
## lid and its two coin-slot locks on top, a band of ridges round the
## middle, and the food showing faintly through the plastic.
func _bear_canister() -> void:
	# the drum, shaded left to right
	var ramp := ["5a5e66", "4a4e56", "3e424a", "343840", "2c2f36"]
	for x in range(8, 24):
		var i := clampi((x - 8) * ramp.size() / 16, 0, ramp.size() - 1)
		rect(x, 10, 1, 17, ramp[i])
	rect(9, 10, 2, 17, "6e737c")
	px(9, 11, "8a9098")
	# food through the plastic: a loaf and an apple
	rect(12, 18, 6, 3, "6a5032")
	rect(13, 18, 4, 1, "8a6a44")
	rect(18, 15, 3, 3, "6a2a24")
	px(18, 15, "8a3a2e")
	# ridges round the middle and the rounded foot
	for y in [13, 22]:
		rect(8, y, 16, 1, "24272d")
		rect(9, y - 1, 14, 1, "70757e")
	rect(9, 27, 14, 1, "24272d")
	# the lid, a little wider, with its two locks
	rect(7, 7, 18, 3, "1e2026")
	rect(8, 6, 16, 1, "30333a")
	rect(8, 7, 3, 1, "4a4e56")
	for x in [12, 19]:
		rect(x, 8, 2, 1, "8a8f98")
		px(x, 7, "b8bcc4")


## A folded paper permit with a blue NPS stripe across the top, lines of
## writing, and a signature at the foot.
func _wilderness_permit(ox: int) -> void:
	rect(ox + 3, 2, 10, 12, "efe4c8")
	rect(ox + 3, 2, 10, 2, "3a6a8a")
	px(ox + 4, 2, "5a8aaa")
	rect(ox + 12, 4, 1, 10, "c8b898")
	for y in [6, 8, 10]:
		rect(ox + 5, y, 6, 1, "9a8f7a")
	rect(ox + 5, 12, 2, 1, "2a3a6a")
	px(ox + 7, 11, "2a3a6a")
	px(ox + 8, 12, "2a3a6a")
	px(ox + 9, 11, "2a3a6a")


## A dark rim round everything drawn inside [param area].
func _outline(area: Rect2i) -> void:
	var src := im.duplicate()
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(x, y) + d
				if area.has_point(n) and src.get_pixelv(n).a > 0.0:
					im.set_pixel(x, y, OUTLINE)
					break
