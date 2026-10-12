extends SceneTree
## Draws the 16x16 icons for the cooked and prepared foods (the acorn chain
## and the campfire dishes) into assets/sprites/food_items.png, in the same
## style as the forage icons: three-tone shading lit from the upper left and a
## dark rim. Then points each food's ItemData at its frame.
##
##   godot --headless --path . -s res://tools/ui/food_icons.gd
##   godot --headless --path . --import

const Art = preload("res://tools/mapgen/art.gd")
const OUT := "res://assets/sprites/food_items.png"
## Frame order in the sheet. Each id is a resource in data/food/.
const FOODS := [
	"acorn_flour", "leached_acorn_meal", "acorn_mush", "acorn_cake",
	"elderberry_sauce", "manzanita_cider", "roasted_morels", "toasted_toyon",
	"yerba_buena_tea", "spring_greens", "bread_pudding", "dry_crusts",
]

var art := Art.new()


func _init() -> void:
	art.rng.seed = 7
	var im := Image.create_empty(16 * FOODS.size(), 16, false, Image.FORMAT_RGBA8)
	for i in FOODS.size():
		call("_" + FOODS[i], im, i * 16)
		art.outline(im, Rect2i(i * 16, 0, 16, 16), Art.OUTLINE)
	im.save_png(OUT)
	for i in FOODS.size():
		_assign(FOODS[i], i)
	print("Food icons written to %s. Run godot --headless --path . --import next." % OUT)
	quit()


## Writes an AtlasTexture icon for [param id] at frame [param index] into its .tres.
func _assign(id: String, index: int) -> void:
	var path := "res://data/food/%s.tres" % id
	var text := FileAccess.get_file_as_string(path)
	if text.contains("food_items.png"):
		return
	var lines := text.split("\n")
	var out := PackedStringArray()
	for line in lines:
		if line.begins_with("[resource]"):
			out.append('[ext_resource type="Texture2D" path="%s" id="food_icons"]' % OUT)
			out.append("")
			out.append('[sub_resource type="AtlasTexture" id="icon"]')
			out.append('atlas = ExtResource("food_icons")')
			out.append("region = Rect2(%d, 0, 16, 16)" % (index * 16))
			out.append("")
		out.append(line)
	var joined := "\n".join(out).strip_edges() + '\nicon = SubResource("icon")\n'
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(joined)


# ------------------------------------------------------------ shared pieces

func c(hex: String) -> Color:
	return Color(hex)


## A shallow woven basket bowl, rim at [param top]. Returns nothing; the food
## is drawn into it afterwards.
func _basket(im: Image, ox: int, top: int) -> void:
	for y in range(top, 14):
		var half := 7 - maxi(0, y - top - 2)
		for x in range(8 - half, 8 + half):
			var weave := (x + y) % 3 == 0
			var col := c("8a5a2c") if weave else c("a87038")
			if x < 8 - half + 2:
				col = col.lightened(0.12)
			if x > 8 + half - 3 or y == 13:
				col = c("6a4020")
			art.px(im, ox + x, y, col)
	art.rect(im, ox + 1, top, 14, 1, c("c8904c"))


## A clay or wooden bowl, rim at [param top].
func _bowl(im: Image, ox: int, top: int, body: String, shade: String) -> void:
	for y in range(top, 14):
		var half := 7 - maxi(0, (y - top - 1)) / 2 - (1 if y == 13 else 0)
		for x in range(8 - half, 8 + half):
			art.px(im, ox + x, y, c(shade) if x > 8 + half - 4 or y >= 12 else c(body))
	art.rect(im, ox + 2, top + 1, 2, 2, c(body).lightened(0.25))


## A heap of something in a bowl: lit mound from [param left] to [param right].
func _heap(im: Image, ox: int, top: int, dark: String, mid: String, light: String) -> void:
	art.blob(im, ox + 8, top + 1.5, 6.2, 3.2, c(dark), c(mid), c(light))


func _steam(im: Image, ox: int, xs: Array) -> void:
	for x: int in xs:
		art.px(im, ox + x, 3, Color(1, 1, 1, 0.45))
		art.px(im, ox + x + 1, 2, Color(1, 1, 1, 0.35))
		art.px(im, ox + x, 1, Color(1, 1, 1, 0.3))


## A tin camp cup with a handle on the right.
func _cup(im: Image, ox: int, body: String, shade: String, drink: String) -> void:
	art.rect(im, ox + 3, 6, 8, 8, c(body))
	art.rect(im, ox + 8, 6, 3, 8, c(shade))
	art.rect(im, ox + 4, 6, 1, 7, c(body).lightened(0.3))
	art.rect(im, ox + 3, 5, 8, 2, c(drink))
	art.rect(im, ox + 4, 5, 3, 1, c(drink).lightened(0.3))
	art.rect(im, ox + 3, 4, 8, 1, c(body).lightened(0.15))
	# handle
	art.rect(im, ox + 11, 7, 2, 1, c(shade))
	art.rect(im, ox + 12, 8, 1, 3, c(shade))
	art.rect(im, ox + 11, 11, 2, 1, c(shade))


# ------------------------------------------------------------ the foods

func _acorn_flour(im: Image, ox: int) -> void:
	_basket(im, ox, 8)
	_heap(im, ox, 6, "c8b088", "e0cca4", "f4e8cc")
	art.px(im, ox + 6, 6, c("fffaf0"))


func _leached_acorn_meal(im: Image, ox: int) -> void:
	# a sand basin with damp, darker meal and a bead of water
	art.ellipse(im, ox + 8, 10, 7.4, 4.2, c("c4a878"))
	art.ellipse(im, ox + 8, 10.4, 6.2, 3.2, c("a88c60"))
	art.blob(im, ox + 8, 9.5, 5, 2.6, c("8a6a48"), c("a8845c"), c("c4a074"))
	art.px(im, ox + 11, 5, c("9ad0f0"))
	art.px(im, ox + 11, 6, c("6aa8d8"))
	art.px(im, ox + 5, 4, c("9ad0f0"))
	art.px(im, ox + 5, 5, c("6aa8d8"))


func _acorn_mush(im: Image, ox: int) -> void:
	_basket(im, ox, 8)
	art.rect(im, ox + 2, 7, 12, 2, c("9a7048"))
	art.rect(im, ox + 3, 7, 5, 1, c("b88a5c"))
	art.px(im, ox + 9, 8, c("7a5434"))
	_steam(im, ox, [5, 10])


func _acorn_cake(im: Image, ox: int) -> void:
	for i in 2:
		var y := 11 - i * 4
		var x := ox + (1 if i == 0 else 3)
		art.ellipse(im, x + 6, y + 1, 6, 2.6, c("6a4426"))
		art.ellipse(im, x + 6, y, 6, 2.6, c("9a6a3c"))
		art.ellipse(im, x + 5, y - 0.5, 3.6, 1.4, c("b8844c"))
		art.px(im, x + 4, y, c("5a3a20"))
		art.px(im, x + 8, y + 1, c("5a3a20"))


func _elderberry_sauce(im: Image, ox: int) -> void:
	# a small clay pot of dark sauce, a berry sprig beside it
	_bowl(im, ox, 7, "b06a40", "84482a")
	art.rect(im, ox + 2, 7, 12, 1, c("3a2048"))
	art.rect(im, ox + 3, 7, 4, 1, c("6a4a8a"))
	for p in [[11, 4], [14, 4], [12, 1]]:
		art.ellipse(im, ox + p[0] + 0.5, p[1] + 0.5, 1.1, 1.1, c("4a5a98"))
		art.px(im, ox + p[0], p[1], c("9aaad8"))


func _manzanita_cider(im: Image, ox: int) -> void:
	_cup(im, ox, "b8bcc0", "84888c", "d89a3a")
	art.px(im, ox + 1, 12, c("a83a2a"))
	art.px(im, ox + 2, 13, c("c84a32"))


func _roasted_morels(im: Image, ox: int) -> void:
	# two browned morels on a willow skewer
	for x in range(1, 15):
		art.px(im, ox + x, 15 - x, c("8a6a40"))
	for m in [[5, 9], [10, 4]]:
		var cx: float = m[0]
		var cy: float = m[1]
		art.ellipse(im, ox + cx, cy, 2.6, 3.4, c("5a3a1e"))
		for y in range(int(cy) - 2, int(cy) + 3):
			for x in range(int(cx) - 2, int(cx) + 2):
				if (x + y * 2) % 3 == 0:
					art.px(im, ox + x, y, c("9a6a36"))
		art.px(im, ox + int(cx) - 1, int(cy) - 2, c("c8945a"))


func _toasted_toyon(im: Image, ox: int) -> void:
	# a flat cooking stone with a scatter of darkened red berries
	art.ellipse(im, ox + 8, 11, 7.4, 3.6, c("6a6a72"))
	art.ellipse(im, ox + 7.5, 10.4, 6.6, 2.8, c("8c8c94"))
	for p in [[5, 9], [8, 8], [11, 9], [7, 11], [10, 11], [4, 11]]:
		art.ellipse(im, ox + p[0] + 0.5, p[1] + 0.5, 1.4, 1.4, c("8a1e18"))
		art.px(im, ox + p[0], p[1], c("d0503a"))


func _yerba_buena_tea(im: Image, ox: int) -> void:
	# a speckled blue enamel cup, mint leaf on the rim
	_cup(im, ox, "4a6aa8", "34508a", "8aa84a")
	for p in [[5, 9], [7, 12], [9, 8], [4, 11]]:
		art.px(im, ox + p[0], p[1], c("dce4f4"))
	art.px(im, ox + 6, 3, c("5a9a3a"))
	art.px(im, ox + 7, 3, c("7aba4a"))
	art.px(im, ox + 7, 2, c("5a9a3a"))
	_steam(im, ox, [9])


func _spring_greens(im: Image, ox: int) -> void:
	_bowl(im, ox, 8, "a87a4a", "7a5432")
	for p in [[4, 7, "5aa040"], [7, 6, "7ac050"], [10, 7, "4a8a34"], [6, 8, "8ad060"], [11, 8, "6ab048"]]:
		art.ellipse(im, ox + p[0] + 0.5, p[1] + 0.5, 2.2, 1.6, c(p[2]))
	art.px(im, ox + 8, 5, c("e8e0f0"))
	art.px(im, ox + 8, 4, c("a8d07a"))


func _bread_pudding(im: Image, ox: int) -> void:
	# a square enamel dish, golden top, apple pieces
	art.rect(im, ox + 1, 6, 14, 8, c("d8dce0"))
	art.rect(im, ox + 1, 12, 14, 2, c("a0a4a8"))
	art.rect(im, ox + 2, 6, 12, 5, c("d8a050"))
	art.rect(im, ox + 2, 6, 6, 2, c("ecc070"))
	for p in [[4, 8], [9, 7], [11, 9], [6, 9]]:
		art.px(im, ox + p[0], p[1], c("b83a2a"))
		art.px(im, ox + p[0] + 1, p[1], c("f0e0b0"))
	art.px(im, ox + 12, 7, c("a86a30"))


func _dry_crusts(im: Image, ox: int) -> void:
	for p in [[3, 9, 4, 3], [9, 10, 4, 3], [7, 6, 3, 2.4]]:
		art.ellipse(im, ox + p[0] + 0.5, p[1] + 0.5, p[2], p[3], c("8a5a2a"))
		art.ellipse(im, ox + p[0] + 0.5, p[1] + 1, p[2] - 1.2, p[3] - 1.2, c("d8b880"))
		art.px(im, ox + p[0] - 1, p[1] - 1, c("b07a3a"))
