extends Node
## Draws the UI's nine-slice panel (assets/ui/panel.png): a stained-timber
## frame with a brass inner line and brass corner studs round a dark, warm
## interior, lit from the upper left like the rest of the art.
##   godot --headless --path . res://tools/ui/ui_art.tscn
## The theme (assets/ui/theme.tres) stretches it with a 6 px margin.

const SIZE := 24
const MARGIN := 6

const OUTLINE := "1a120c"
const WOOD_LIGHT := "b08450"
const WOOD_MID := "865c38"
const WOOD_DARK := "5a3b24"
const WOOD_SHADE := "3a2616"
const BRASS := "d9b25e"
const BRASS_DARK := "8f6d30"
const FILL := Color(0.105, 0.078, 0.055, 0.95)


func _ready() -> void:
	var im := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_panel(im)
	var path := ProjectSettings.globalize_path("res://assets/ui/panel.png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	im.save_png(path)
	# the same panel with a lighter interior, for banners over busy ground
	var banner := im.duplicate() as Image
	for y in range(MARGIN, SIZE - MARGIN):
		for x in range(MARGIN, SIZE - MARGIN):
			banner.set_pixel(x, y, Color(0.16, 0.12, 0.085, 0.9))
	banner.save_png(ProjectSettings.globalize_path("res://assets/ui/panel_banner.png"))
	print("ui panels painted")
	get_tree().quit()


func _px(im: Image, x: int, y: int, hex: String) -> void:
	im.set_pixel(x, y, Color(hex))


func _panel(im: Image) -> void:
	var last := SIZE - 1
	var corner := 2
	# rounded outline and the three frame rings, drawn as nested rounded rects
	var rings := [[0, OUTLINE], [1, WOOD_MID], [2, WOOD_MID], [3, WOOD_SHADE], [4, BRASS_DARK]]
	for ring: Array in rings:
		var i: int = ring[0]
		for y in range(i, SIZE - i):
			for x in range(i, SIZE - i):
				if x != i and x != last - i and y != i and y != last - i:
					continue
				# notch the corners of the outer rings
				var dx := mini(x - i, last - i - x)
				var dy := mini(y - i, last - i - y)
				if dx + dy < (corner - i) and i < corner:
					continue
				var hex: String = ring[1]
				var lit := (x == i or y == i) and x < last - i and y < last - i
				var shaded := (x == last - i or y == last - i)
				if i == 1 or i == 2:
					hex = WOOD_LIGHT if lit else (WOOD_DARK if shaded else WOOD_MID)
				elif i == 4:
					hex = BRASS if lit else BRASS_DARK
				_px(im, x, y, hex)
	for y in range(5, SIZE - 5):
		for x in range(5, SIZE - 5):
			if im.get_pixel(x, y).a == 0.0:
				im.set_pixel(x, y, FILL)
	# fill the interior (inside the brass ring)
	for y in range(5, SIZE - 5):
		for x in range(5, SIZE - 5):
			if x > 4 and x < last - 4 and y > 4 and y < last - 4:
				im.set_pixel(x, y, FILL)
	# brass studs
	for p: Vector2i in [Vector2i(2, 2), Vector2i(last - 2, 2), Vector2i(2, last - 2), Vector2i(last - 2, last - 2)]:
		_px(im, p.x, p.y, BRASS)
	# soft inner shadow under the brass line
	for i in range(5, SIZE - 5):
		for d: Vector2i in [Vector2i(i, 5), Vector2i(5, i)]:
			im.set_pixelv(d, FILL.darkened(0.35))
