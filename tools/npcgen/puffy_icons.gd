extends SceneTree
## Draws the down puffy's icons: the mended jacket as gear
## (assets/sprites/gear/puffy_jacket.png, 64×64, drawn on a 32×32 grid and
## doubled like the climbing shoes) and the torn demo jacket you find at
## Camp 4 (torn_puffy.png, 32×32, a story item). See Warmth.
## Run: godot --headless --path . -s res://tools/npcgen/puffy_icons.gd

const OUT := "res://assets/sprites/gear/"
const OUTLINE := Color("2a1f1a")
## Shell colours, light to dark: a warm red, light from the upper left.
const SHELL_HI := "f07a52"
const SHELL := "d0482c"
const SHELL_DK := "9a3020"
const SHELL_DEEP := "6e2018"
const ZIP := "2a2a30"
const ZIP_HI := "c8c4bc"
const PATCH := "3a6a8a"
const PATCH_HI := "5a8aaa"
const DOWN := "f4efe4"

var im: Image


func _init() -> void:
	var mended := jacket(true)
	var big := mended.duplicate()
	big.resize(64, 64, Image.INTERPOLATE_NEAREST)
	big.save_png(ProjectSettings.globalize_path(OUT + "puffy_jacket.png"))
	print("drew puffy_jacket")
	jacket(false).save_png(ProjectSettings.globalize_path(OUT + "torn_puffy.png"))
	print("drew torn_puffy")
	quit()


func rect(x: int, y: int, w: int, h: int, hex: String) -> void:
	im.fill_rect(Rect2i(x, y, w, h), Color(hex))


func px(x: int, y: int, hex: String) -> void:
	im.set_pixel(x, y, Color(hex))


## The jacket laid flat, front on: a stand-up collar, a body of fat
## horizontal baffles, sleeves out to the sides, a dark centre zip. Mended,
## the left sleeve carries a blue patch; torn, a baffle is split on the chest
## and feathers drift out of it.
func jacket(mended: bool) -> Image:
	im = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	# Sleeves: angled down and out, each a stack of puffs.
	for i in 5:
		var y := 9 + i * 3
		rect(4 - i / 2, y, 6, 3, SHELL)
		rect(22 + i / 2, y, 6, 3, SHELL)
		rect(4 - i / 2, y, 6, 1, SHELL_HI)
		rect(22 + i / 2, y, 6, 1, SHELL)
		rect(4 - i / 2, y + 2, 6, 1, SHELL_DK)
		rect(22 + i / 2, y + 2, 6, 1, SHELL_DEEP)
	# Cuffs.
	rect(2, 24, 6, 2, SHELL_DEEP)
	rect(24, 24, 6, 2, SHELL_DEEP)
	# Body: six baffles, each lit on top and shaded below.
	for i in 6:
		var y := 7 + i * 3
		rect(9, y, 14, 3, SHELL)
		rect(9, y, 14, 1, SHELL_HI)
		rect(9, y + 2, 14, 1, SHELL_DK)
		# the right side of the body is in shade
		rect(19, y + 1, 4, 1, SHELL_DK)
	# Hem.
	rect(9, 25, 14, 2, SHELL_DEEP)
	# Collar, standing up round the neck, open at the top.
	rect(11, 3, 10, 4, SHELL)
	rect(11, 3, 10, 1, SHELL_HI)
	rect(14, 3, 4, 3, SHELL_DEEP)
	rect(14, 5, 4, 2, "4a1810")
	# Zip down the middle, with its pull at the chest.
	rect(15, 6, 2, 21, ZIP)
	px(15, 10, ZIP_HI)
	px(15, 11, ZIP_HI)
	# A little chest pocket on the left (the jacket packs into it).
	rect(10, 10, 4, 1, SHELL_DEEP)
	# A small square label on the chest, light on the red.
	rect(19, 9, 3, 2, "efe6cf")
	px(19, 9, "8ab0c8")
	px(21, 10, "6e5a8a")
	if mended:
		# The patch over the old tear, on the left sleeve.
		rect(4, 14, 4, 4, PATCH)
		rect(4, 14, 4, 1, PATCH_HI)
		px(4, 15, "efe6cf")
		px(7, 17, "efe6cf")
	else:
		# The split baffle: a dark gash across the chest, down spilling out.
		rect(10, 16, 5, 1, "3a1410")
		px(11, 15, DOWN)
		px(13, 15, DOWN)
		px(9, 14, DOWN)
		px(12, 13, DOWN)
		px(7, 12, DOWN)
		px(10, 11, DOWN)
		px(14, 17, DOWN)
	_outline()
	return im


func _outline() -> void:
	var edge: Array[Vector2i] = []
	for y in 32:
		for x in 32:
			if im.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < 32 and p.y < 32 and im.get_pixel(p.x, p.y).a > 0.0 \
						and im.get_pixel(p.x, p.y) != OUTLINE:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixelv(p, OUTLINE)
