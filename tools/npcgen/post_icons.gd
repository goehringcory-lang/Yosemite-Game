extends SceneTree
## Draws the icons for Michael Kochakji's "General Delivery" quest at the
## Tuolumne Meadows post office: a thru-hiker's resupply box
## (assets/sprites/gear/resupply_box.png) and the postcard she sends home
## (hiker_postcard.png). Both 32×32 story items, lit from the upper left like
## the rest of the backpack.
## Run: godot --headless --path . -s res://tools/npcgen/post_icons.gd

const OUT := "res://assets/sprites/gear/"
const OUTLINE := Color("2a1f1a")
const CARD_HI := "e0b878"
const CARD := "c89a58"
const CARD_DK := "9a7038"
const CARD_DEEP := "6e4e26"
const TAPE := "d8d0b0"
const TAPE_DK := "a8a088"
const LABEL := "f4efe4"
const INK := "3a3a5a"
const RED := "c8402e"
const STAMP := "4a7a9a"

var im: Image


func _init() -> void:
	box().save_png(ProjectSettings.globalize_path(OUT + "resupply_box.png"))
	print("drew resupply_box")
	postcard().save_png(ProjectSettings.globalize_path(OUT + "hiker_postcard.png"))
	print("drew hiker_postcard")
	quit()


func rect(x: int, y: int, w: int, h: int, hex: String) -> void:
	im.fill_rect(Rect2i(x, y, w, h), Color(hex))


func px(x: int, y: int, hex: String) -> void:
	im.set_pixel(x, y, Color(hex))


## A cardboard box seen from a little above: the lid in light, the front in
## mid tone, the right side in shadow. Packing tape over the top and down the
## front, an address label, and "PCT" in red marker.
func box() -> Image:
	im = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	# lid (top face), front, right side
	rect(5, 7, 20, 6, CARD_HI)
	rect(5, 13, 20, 13, CARD)
	rect(25, 9, 3, 17, CARD_DK)
	# the side's top edge slants back to meet the lid
	rect(25, 8, 2, 1, CARD_DK)
	rect(5, 25, 20, 1, CARD_DK)
	# tape over the lid seam and down the front
	rect(14, 7, 3, 19, TAPE)
	rect(16, 7, 1, 19, TAPE_DK)
	rect(5, 9, 20, 1, CARD)
	# label with an address, and PCT in red
	rect(6, 15, 7, 6, LABEL)
	rect(7, 16, 5, 1, INK)
	rect(7, 18, 4, 1, INK)
	rect(7, 20, 5, 1, INK)
	# P
	rect(17, 16, 1, 4, RED)
	rect(18, 16, 1, 1, RED)
	rect(18, 18, 1, 1, RED)
	px(19, 17, RED)
	# C
	rect(20, 16, 1, 4, RED)
	px(21, 16, RED)
	px(21, 19, RED)
	# T
	rect(22, 16, 3, 1, RED)
	rect(23, 17, 1, 3, RED)
	rect(17, 22, 8, 1, RED)
	_outline()
	return im


## A picture postcard: a little granite dome under a blue sky on the front,
## a stamp in the corner and a few lines of writing slanting across.
func postcard() -> Image:
	im = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	rect(3, 8, 26, 17, LABEL)
	rect(3, 24, 26, 1, "d8d0c0")
	rect(28, 9, 1, 15, "d8d0c0")
	# the picture half: sky, a dome, a meadow
	rect(4, 9, 12, 14, "8ab8d8")
	for x in 12:
		var h: int = [2, 4, 5, 6, 7, 7, 7, 7, 6, 5, 4, 2][x]
		if h > 0:
			rect(4 + x, 19 - h, 1, h, "c8c4bc" if x < 6 else "a8a49c")
	rect(4, 19, 12, 4, "6a9a4a")
	rect(4, 21, 12, 2, "4a7a3a")
	# divider, stamp, writing
	rect(16, 10, 1, 13, "c8c0b0")
	rect(23, 10, 4, 4, STAMP)
	px(24, 11, LABEL)
	rect(18, 15, 8, 1, INK)
	rect(18, 17, 9, 1, INK)
	rect(18, 19, 6, 1, INK)
	rect(18, 21, 8, 1, INK)
	_outline()
	return im


## A dark outline round everything drawn, like every other icon.
func _outline() -> void:
	var src := im.duplicate()
	for y in 32:
		for x in 32:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p := Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < 32 and p.y < 32 and src.get_pixelv(p).a > 0.0:
					im.set_pixel(x, y, OUTLINE)
					break
