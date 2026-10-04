extends RefCounted
## Placeholder pixel art for the hand-made central hubs: buildings, umachas,
## camp props, and the store's foods. Drawn in code in the same style as
## tools/mapgen/art.gd; replace any PNG with hand-drawn art of the same size.

const Art = preload("res://tools/mapgen/art.gd")
const DIR := "res://assets/sprites/buildings/"
const ITEM_ICONS := "res://assets/sprites/store_items.png"

var art := Art.new()


static func c(hex: String) -> Color:
	return Color(hex)


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_save(_building(80, 56, c("6a4a32"), c("503624"), c("8f877a"), c("5f5a50"), true, "2f4a36"), "village_store")
	_save(_building(64, 46, c("5a3e2a"), c("45301f"), c("9a7a52"), c("7a5e3e"), true, "3f5a44"), "welcome_center")
	_save(_building(56, 46, c("4a3a2e"), c("3a2c22"), c("9a948a"), c("7a746a"), false, ""), "museum")
	_save(_building(44, 38, c("6e4a2e"), c("583a24"), c("a88a5e"), c("886a44"), false, ""), "bests_studio")
	_save(_building(48, 40, c("7a4a2e"), c("603a24"), c("b09268"), c("8a6e4a"), true, "8a3a2a"), "degnans")
	_save(_building(40, 36, c("3f5a44"), c("2f4634"), c("8a6a44"), c("6a5034"), false, ""), "wilderness_center")
	_save(_building(72, 44, c("5e4632"), c("483424"), c("a08868"), c("806850"), false, ""), "valley_lodge")
	_save(_umacha(), "umacha")
	_save(_chuckah(), "chuckah")
	_save(_boulder(), "big_boulder")
	_save(_picnic_table(), "picnic_table")
	_save(_bear_box(), "bear_box")
	_save(_gear_tarp(), "gear_tarp")
	_save(_shuttle_stop(), "shuttle_stop")
	for i in 3:
		_save(_dome_tent([c("e0b030"), c("3a78c0"), c("c84a3a")][i]), "climber_tent_%d" % i)
	_store_items().save_png(ITEM_ICONS)


func _save(image: Image, sprite_name: String) -> void:
	image.save_png(DIR + sprite_name + ".png")


## A building seen from the front and above: a big roof with a wall below,
## a door, windows, and an optional sign board.
func _building(w: int, h: int, roof: Color, roof_dark: Color, wall: Color, wall_dark: Color,
		sign: bool, sign_color: String) -> Image:
	var im := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var wall_h := int(h * 0.38)
	var wall_top := h - wall_h - 1
	art.shadow(im, w / 2.0, h - 1.5, w / 2.0, 2)
	art.rect(im, 1, wall_top, w - 2, wall_h, wall)
	for x in range(1, w - 1, 6):
		art.rect(im, x, wall_top, 1, wall_h, wall_dark)
	art.rect(im, 1, wall_top, w - 2, 1, wall_dark)
	var door_x := w / 2 - 3
	art.rect(im, door_x, h - 1 - int(wall_h * 0.75), 7, int(wall_h * 0.75), c("3b2a1e"))
	art.rect(im, door_x + 3, h - 1 - int(wall_h * 0.75), 1, int(wall_h * 0.75), c("2a1f16"))
	for x in [6, w - 13]:
		art.rect(im, x, wall_top + 3, 7, 5, c("f2d88a"))
		art.rect(im, x + 3, wall_top + 3, 1, 5, wall_dark)
	# Roof: a trapezoid seen from above, lighter toward the ridge.
	for y in wall_top:
		var inset := int((wall_top - y) * 0.25)
		var shade := roof if y > wall_top / 3 else roof.lightened(0.12)
		art.rect(im, inset, y, w - inset * 2, 1, shade)
		if y % 4 == 0:
			art.rect(im, inset, y, w - inset * 2, 1, roof_dark)
	art.rect(im, int(wall_top * 0.25), 0, w - int(wall_top * 0.25) * 2, 1, roof.lightened(0.25))
	if sign:
		var sw := mini(w - 16, 30)
		art.rect(im, w / 2 - sw / 2, wall_top - 5, sw, 5, c(sign_color))
		for x in range(w / 2 - sw / 2 + 2, w / 2 + sw / 2 - 2, 3):
			art.rect(im, x, wall_top - 3, 2, 1, c("e8dcb8"))
	art.outline(im, Rect2i(0, 0, w, h), Art.OUTLINE)
	return im


## A cone of incense-cedar bark slabs over a pole frame, with a doorway.
func _umacha() -> Image:
	var w := 32
	var h := 44
	var im := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	art.shadow(im, 16, 42, 14, 2)
	var slabs := [c("8a5a3a"), c("7a4a2e"), c("9a6a44"), c("704228")]
	for y in range(6, 42):
		var half := (y - 4) * 0.4
		for x in range(floori(16 - half), ceili(16 + half)):
			var slab: Color = slabs[(x / 3 + (y / 9)) % slabs.size()]
			if x < 16 - half * 0.5:
				slab = slab.lightened(0.08)
			elif x > 16 + half * 0.5:
				slab = slab.darkened(0.15)
			art.px(im, x, y, slab)
	for pole in [[14, 0], [17, 1], [19, 3], [12, 2]]:
		for k in 7:
			art.px(im, pole[0] + (1 if pole[0] > 16 else -1) * (k / 4), pole[1] + k, c("5a3a22"))
	art.rect(im, 13, 32, 6, 10, c("2a1c12"))
	art.rect(im, 14, 31, 4, 1, c("2a1c12"))
	art.outline(im, Rect2i(0, 0, w, h), Art.OUTLINE)
	return im


## An acorn granary: a tall woven store on poles under a thatched cap.
func _chuckah() -> Image:
	var im := Image.create_empty(20, 40, false, Image.FORMAT_RGBA8)
	art.shadow(im, 10, 38, 8, 2)
	for x in [4, 9, 15]:
		art.rect(im, x, 26, 1, 12, c("5a3a22"))
	for y in range(12, 28):
		for x in range(4, 16):
			art.px(im, x, y, c("a88a52") if (x + y) % 3 else c("8a6e3e"))
	for y in range(3, 13):
		var half := (y - 1) * 0.75
		art.rect(im, floori(10 - half), y, ceili(half * 2), 1, c("c8a860") if y % 2 else c("b0924a"))
	art.outline(im, Rect2i(0, 0, 20, 40), Art.OUTLINE)
	return im


func _boulder() -> Image:
	var im := Image.create_empty(56, 40, false, Image.FORMAT_RGBA8)
	art.shadow(im, 28, 37, 26, 3)
	art.ellipse(im, 28, 22, 26, 16, c("7a766c"))
	art.ellipse(im, 27, 21, 25, 15, c("aeaa9e"))
	art.ellipse(im, 21, 14, 12, 7, c("c8c4b8"))
	for k in 10:
		art.px(im, 34 + k, 20 + k / 2, c("86827a"))
	for p in [[18, 24], [22, 18], [30, 26], [36, 16], [26, 28]]:
		art.px(im, p[0], p[1], c("f4f1ea"))
	art.outline(im, Rect2i(0, 0, 56, 40), Art.OUTLINE)
	return im


func _picnic_table() -> Image:
	var im := Image.create_empty(24, 14, false, Image.FORMAT_RGBA8)
	art.shadow(im, 12, 12, 11, 2)
	art.rect(im, 2, 0, 20, 2, c("8a6a44"))
	art.rect(im, 1, 4, 22, 5, c("a0804f"))
	art.rect(im, 1, 6, 22, 1, c("7a5c3a"))
	art.rect(im, 2, 11, 20, 2, c("8a6a44"))
	art.outline(im, Rect2i(0, 0, 24, 14), Art.OUTLINE)
	return im


func _bear_box() -> Image:
	var im := Image.create_empty(16, 12, false, Image.FORMAT_RGBA8)
	art.rect(im, 1, 1, 14, 10, c("5a6a4a"))
	art.rect(im, 1, 1, 14, 2, c("7a8a6a"))
	art.rect(im, 6, 5, 4, 2, c("b8b0a0"))
	art.outline(im, Rect2i(0, 0, 16, 12), Art.OUTLINE)
	return im


## A tarp spread with gear for trade: a rope coil, cams, and carabiners.
func _gear_tarp() -> Image:
	var im := Image.create_empty(28, 16, false, Image.FORMAT_RGBA8)
	art.rect(im, 1, 2, 26, 12, c("3a6aa0"))
	art.rect(im, 1, 2, 26, 1, c("5a8ac0"))
	art.ellipse(im, 7, 8, 4, 3, c("c84a3a"))
	art.ellipse(im, 7, 8, 1.5, 1, c("3a6aa0"))
	for x in [14, 17, 20]:
		art.rect(im, x, 5, 2, 4, c("c0c4c8"))
		art.px(im, x, 9, c("e0a030"))
	for x in [14, 18, 22]:
		art.rect(im, x, 11, 2, 1, c("d8d8d0"))
	art.outline(im, Rect2i(0, 0, 28, 16), Art.OUTLINE)
	return im


func _shuttle_stop() -> Image:
	var im := Image.create_empty(16, 30, false, Image.FORMAT_RGBA8)
	art.shadow(im, 8, 28, 5, 1)
	art.rect(im, 7, 10, 2, 18, c("5a5a60"))
	art.rect(im, 1, 1, 14, 10, c("3f5a44"))
	art.rect(im, 3, 3, 10, 5, c("e8dcb8"))
	art.rect(im, 4, 4, 8, 2, c("3f7a4a"))
	art.px(im, 5, 7, c("2a2a2a"))
	art.px(im, 10, 7, c("2a2a2a"))
	art.outline(im, Rect2i(0, 0, 16, 30), Art.OUTLINE)
	return im


func _dome_tent(color: Color) -> Image:
	var im := Image.create_empty(20, 14, false, Image.FORMAT_RGBA8)
	art.shadow(im, 10, 12, 9, 2)
	art.ellipse(im, 10, 9, 9, 7, color)
	art.ellipse(im, 8, 7, 5, 4, color.lightened(0.15))
	art.rect(im, 8, 8, 4, 5, color.darkened(0.45))
	for y in range(3, 13):
		art.px(im, 10 + (y - 8) / 3, y, color.darkened(0.25))
	art.outline(im, Rect2i(0, 0, 20, 14), Art.OUTLINE)
	return im


## 16x16 icons: trail mix, then dried apples.
func _store_items() -> Image:
	var im := Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
	art.rect(im, 3, 3, 10, 12, c("c89a52"))
	art.rect(im, 3, 3, 10, 2, c("a07a3a"))
	for p in [[5, 8], [8, 10], [10, 7], [6, 12], [11, 12]]:
		art.px(im, p[0], p[1], c("6a4228"))
		art.px(im, p[0] + 1, p[1], c("e8d8a8"))
	art.outline(im, Rect2i(0, 0, 16, 16), Art.OUTLINE)
	for p in [[20, 6], [25, 8], [21, 11], [26, 12]]:
		art.ellipse(im, p[0] + 0.5, p[1] + 0.5, 3, 2.2, c("e8c878"))
		art.ellipse(im, p[0] + 0.5, p[1] + 0.5, 1.2, 0.8, c("c83a2a"))
	art.outline(im, Rect2i(16, 0, 16, 16), Art.OUTLINE)
	return im
