extends SceneTree
## Draws the icons for photography: the Box Brownie Ansel Adams lends you
## (assets/sprites/gear/camera.png) and his two extra lenses
## (assets/sprites/gear/camera_lenses.png), 64x64 like the other gear. Each
## is drawn on a half-size grid and doubled, with a dark rim, like the fly
## rod in tools/ui/valley_life_icons.gd.
## Run: godot --headless --path . -s res://tools/ui/camera_icons.gd

const OUT := "res://assets/sprites/gear/%s.png"
const OUTLINE := Color("2a1f1a")

var im: Image


func _init() -> void:
	for icon in ["camera", "camera_lenses"]:
		im = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
		call("_" + icon)
		_outline(Rect2i(0, 0, 32, 32))
		var big := im.duplicate()
		big.resize(64, 64, Image.INTERPOLATE_NEAREST)
		big.save_png(ProjectSettings.globalize_path(OUT % icon))
	print("drew camera and camera_lenses")
	quit()


func rect(x: int, y: int, w: int, h: int, hex: String) -> void:
	im.fill_rect(Rect2i(x, y, w, h), Color(hex))


func px(x: int, y: int, hex: String) -> void:
	im.set_pixel(x, y, Color(hex))


## A disc of [param hex] centered on (cx, cy), [param r] pixels across.
func disc(cx: float, cy: float, r: float, hex: String) -> void:
	for y in range(int(cy - r) - 1, int(cy + r) + 2):
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r and x >= 0 and y >= 0 and x < 32 and y < 32:
				px(x, y, hex)


## A Kodak Box Brownie, seen from the front corner: a black leatherette box
## with a carrying strap, the lens in its round plate, two little finder
## windows, and the winding key on the side.
func _camera() -> void:
	# the strap, looping over the top
	for x in range(9, 23):
		px(x, 5 if x > 10 and x < 21 else 6, "6a4a2e")
	px(9, 7, "6a4a2e")
	px(22, 7, "6a4a2e")
	# the box: front, the lit top edge, and the shadowed side
	rect(5, 8, 20, 18, "33302f")
	rect(5, 8, 20, 2, "4b4745")
	rect(25, 10, 3, 16, "24211f")
	rect(25, 9, 2, 1, "33302f")
	# leatherette grain
	for p in [Vector2i(8, 13), Vector2i(21, 12), Vector2i(7, 22), Vector2i(22, 23), Vector2i(10, 24), Vector2i(20, 20)]:
		px(p.x, p.y, "423e3c")
	# the lens plate and the lens
	disc(15.0, 18.0, 5.6, "8f8a82")
	disc(15.0, 18.0, 4.4, "56524e")
	disc(15.0, 18.0, 3.0, "1c1e2a")
	px(13, 16, "8fb2d8")
	px(14, 16, "c8dcf0")
	px(13, 17, "5a7aa8")
	# the two finder windows
	rect(7, 10, 3, 2, "9ab8d0")
	px(7, 10, "d8e8f4")
	rect(20, 10, 3, 2, "9ab8d0")
	px(20, 10, "d8e8f4")
	# the winding key and the shutter lever
	rect(27, 13, 2, 3, "b8a070")
	px(29, 14, "d8c090")
	px(24, 22, "b8a070")
	px(24, 23, "8a7850")


## Two lenses side by side: a short wide one with a big front glass, and a
## long one in brass, lying at a slant.
func _camera_lenses() -> void:
	# the wide lens, facing you
	disc(10.0, 20.0, 7.6, "3a3634")
	disc(10.0, 20.0, 6.4, "8f8a82")
	disc(10.0, 20.0, 5.2, "2c2a30")
	disc(10.0, 20.0, 4.0, "1c2238")
	px(7, 17, "c8dcf0")
	px(8, 17, "8fb2d8")
	px(7, 18, "8fb2d8")
	px(12, 22, "3c4c78")
	# the long lens: a brass barrel from lower left to upper right
	for i in 15:
		var x := 13 + i
		var y := 16 - int(i * 2.0 / 3.0)
		rect(x, y - 3, 1, 7, "b08a3c")
		px(x, y - 3, "e0c070")
		px(x, y - 2, "d0aa54")
		px(x, y + 3, "7a5c24")
	# its rings and its front glass
	for i: int in [2, 7, 12]:
		var x := 13 + i
		var y := 16 - int(i * 2.0 / 3.0)
		rect(x, y - 4, 1, 9, "4a3a20")
	rect(28, 3, 2, 9, "33302f")
	rect(29, 5, 1, 5, "5a7aa8")
	px(29, 5, "c8dcf0")


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
