extends SceneTree
## Draws the 16x16 icons for the summer berries, nuts, mushrooms, roots and herbs
## (assets/sprites/wild_items.png) and for every dish the cooking pot makes
## (assets/sprites/meal_items.png, frames in Cooking.DISHES order), in the
## forage icons' style: three-tone shading lit from the upper left and a dark
## rim. Then upgrade both to the 32px palette art:
##
##   godot --headless --path . -s res://tools/ui/wild_food_icons.gd
##   python3 tools/art32/upgrade.py assets/sprites/wild_items.png assets/sprites/meal_items.png
##   godot --headless --path . --import

const Art = preload("res://tools/mapgen/art.gd")
const FORAGE_OUT := "res://assets/sprites/wild_items.png"
const MEAL_OUT := "res://assets/sprites/meal_items.png"
## Frame order in each sheet. Forage ids are resources in data/items/.
const FORAGE := [
	"california_blackberry", "whitebark_raspberry", "thimbleberry", "sierra_gooseberry",
	"sierra_bilberry", "wood_rose_hips", "chanterelle", "king_bolete", "coyote_mint",
	"hazelnut", "whitebark_pine_nuts", "hedgehog_mushroom", "cattail_root", "blue_dicks_corm",
	"cow_clover", "sierra_plum", "chokecherry",
]
const MEALS := [
	"simmered_berries", "berry_medley", "baked_fruit", "wilted_greens", "root_hash",
	"mushroom_skewer", "mushroom_saute", "herb_tea", "berry_acorn_cakes", "berry_cobbler",
	"mountain_flatbread", "camp_stew", "nut_berry_bars", "roasted_pine_nuts",
	"chocolate_berries", "foragers_hash", "bitter_mush",
]

var art := Art.new()


func _init() -> void:
	art.rng.seed = 11
	_sheet(FORAGE, FORAGE_OUT)
	_sheet(MEALS, MEAL_OUT)
	print("Icons written. Upgrade them with tools/art32/upgrade.py, then --import.")
	quit()


func _sheet(ids: Array, out: String) -> void:
	var im := Image.create_empty(16 * ids.size(), 16, false, Image.FORMAT_RGBA8)
	for i in ids.size():
		call("_" + ids[i], im, i * 16)
		art.outline(im, Rect2i(i * 16, 0, 16, 16), Art.OUTLINE)
	im.save_png(out)


# ------------------------------------------------------------ shared pieces

func c(hex: String) -> Color:
	return Color(hex)


## One round berry, lit on the upper left.
func _berry(im: Image, x: float, y: float, r: float, dark: String, mid: String, light: String) -> void:
	art.blob(im, x, y, r, r, c(dark), c(mid), c(light))


## A bramble berry: a cluster of drupelets, [param cols] colors dark to light.
func _drupes(im: Image, ox: int, cx: int, cy: int, cols: Array) -> void:
	for p in [[-2, -3], [0, -3], [-3, -1], [-1, -1], [1, -1], [-2, 1], [0, 1], [2, 1], [-1, 3], [1, 3]]:
		var x: int = cx + p[0]
		var y: int = cy + p[1]
		art.rect(im, ox + x, y, 2, 2, c(cols[1]))
		art.px(im, ox + x + 1, y + 1, c(cols[0]))
		art.px(im, ox + x, y, c(cols[2]))


func _leaf(im: Image, x: int, y: int, w: int, h: int, dark: String, light: String) -> void:
	art.ellipse(im, x + w / 2.0, y + h / 2.0, w / 2.0, h / 2.0, c(dark))
	art.ellipse(im, x + w / 2.0 - 0.5, y + h / 2.0 - 0.5, w / 2.0 - 1.0, h / 2.0 - 1.0, c(light))


## A clay or wooden bowl, rim at [param top].
func _bowl(im: Image, ox: int, top: int, body: String, shade: String) -> void:
	for y in range(top, 14):
		var half := 7 - maxi(0, (y - top - 1)) / 2 - (1 if y == 13 else 0)
		for x in range(8 - half, 8 + half):
			art.px(im, ox + x, y, c(shade) if x > 8 + half - 4 or y >= 12 else c(body))
	art.rect(im, ox + 2, top + 1, 2, 2, c(body).lightened(0.25))


## Small round things heaped in a bowl: [param spots] are [x, y] pairs.
func _bowl_of(im: Image, ox: int, spots: Array, cols: Array) -> void:
	_bowl(im, ox, 8, "a87a4a", "7a5432")
	for p: Array in spots:
		_berry(im, ox + p[0] + 0.5, p[1] + 0.5, 1.6, cols[0], cols[1], cols[2])


func _steam(im: Image, ox: int, xs: Array) -> void:
	for x: int in xs:
		art.px(im, ox + x, 3, Color(1, 1, 1, 0.45))
		art.px(im, ox + x + 1, 2, Color(1, 1, 1, 0.35))
		art.px(im, ox + x, 1, Color(1, 1, 1, 0.3))


## A flat cooking stone.
func _stone(im: Image, ox: int) -> void:
	art.ellipse(im, ox + 8, 11.5, 7.4, 3.4, c("6a6a72"))
	art.ellipse(im, ox + 7.5, 10.9, 6.6, 2.6, c("8c8c94"))


## A tin camp cup with a handle on the right.
func _cup(im: Image, ox: int, body: String, shade: String, drink: String) -> void:
	art.rect(im, ox + 3, 6, 8, 8, c(body))
	art.rect(im, ox + 8, 6, 3, 8, c(shade))
	art.rect(im, ox + 4, 6, 1, 7, c(body).lightened(0.3))
	art.rect(im, ox + 3, 5, 8, 2, c(drink))
	art.rect(im, ox + 4, 5, 3, 1, c(drink).lightened(0.3))
	art.rect(im, ox + 3, 4, 8, 1, c(body).lightened(0.15))
	art.rect(im, ox + 11, 7, 2, 1, c(shade))
	art.rect(im, ox + 12, 8, 1, 3, c(shade))
	art.rect(im, ox + 11, 11, 2, 1, c(shade))


const BLACKBERRY := ["1e1430", "3a2650", "6a5a90"]
const RASPBERRY := ["6a1a3a", "a83050", "d87090"]


# ------------------------------------------------------------ the forage

func _california_blackberry(im: Image, ox: int) -> void:
	# two glossy black drupe clusters on a thorny cane
	for x in range(1, 14):
		art.px(im, ox + x, 3 + x / 4, c("7a4a3a"))
	art.px(im, ox + 4, 3, c("c8a080"))
	art.px(im, ox + 10, 5, c("c8a080"))
	_leaf(im, ox + 9, 1, 6, 4, "2c5c37", "5c8f3c")
	_drupes(im, ox, 5, 9, BLACKBERRY)
	_drupes(im, ox, 11, 10, ["2a1e1a", "6a1a3a", "a83050"]) # one still ripening


func _whitebark_raspberry(im: Image, ox: int) -> void:
	# a dark purple cap on a pale, whitish cane
	for y in range(1, 9):
		art.px(im, ox + 3 + y / 3, y, c("d8d4cc"))
	_leaf(im, ox + 8, 1, 7, 5, "2c5c37", "84b04a")
	_drupes(im, ox, 8, 9, ["2a1438", "4a2a68", "8a6ab0"])
	art.px(im, ox + 8, 6, c("aecb62"))


func _thimbleberry(im: Image, ox: int) -> void:
	# a soft red cap, hollow underneath, in front of a big maple-like leaf
	art.ellipse(im, ox + 8, 4, 7, 3.6, c("2c5c37"))
	art.ellipse(im, ox + 7.5, 3.5, 6, 2.6, c("5c8f3c"))
	for p in [[2, 3], [8, 0], [14, 3]]:
		art.px(im, ox + p[0], p[1], c("437f45"))
	art.blob(im, ox + 8, 9.5, 5.6, 4.6, c("8a1e28"), c("c83a3a"), c("ea7a6a"))
	for p in [[5, 9], [8, 8], [11, 10], [7, 11], [10, 12], [5, 12]]:
		art.px(im, ox + p[0], p[1], c("8a1e28"))
	art.rect(im, ox + 6, 13, 4, 1, c("6a1a1a"))


func _sierra_gooseberry(im: Image, ox: int) -> void:
	# spiny red-purple berries hanging from a stem
	art.rect(im, ox + 7, 1, 1, 4, c("6b4829"))
	_leaf(im, ox + 1, 1, 6, 4, "2c5c37", "5c8f3c")
	for b in [[5, 9], [11, 10]]:
		_berry(im, ox + b[0], b[1], 3.2, "6a1a2a", "a8304a", "d87a7a")
		for s in [[-3, -2], [3, -2], [0, -4], [-3, 2], [3, 2], [0, 4]]:
			art.px(im, ox + b[0] + s[0], b[1] + s[1], c("e8c8a0"))
	art.px(im, ox + 7, 5, c("6b4829"))
	art.px(im, ox + 6, 6, c("6b4829"))
	art.px(im, ox + 9, 6, c("6b4829"))


func _sierra_bilberry(im: Image, ox: int) -> void:
	# small dusty-blue berries on a low twig of tiny leaves
	for x in range(2, 14):
		art.px(im, ox + x, 6 - x / 6, c("7a4a2a"))
	for p in [[3, 3], [7, 2], [11, 2]]:
		_leaf(im, ox + p[0], p[1], 4, 3, "2c5c37", "84b04a")
	for b in [[4, 9], [8, 11], [11, 8], [7, 7]]:
		_berry(im, ox + b[0], b[1], 2.2, "235679", "4a6aa8", "9fb8d8")
		art.px(im, ox + b[0], b[1] - 1, c("2b2a30"))


func _wood_rose_hips(im: Image, ox: int) -> void:
	# glossy orange-red hips with dried sepals, on a bare stem
	for y in range(1, 14):
		art.px(im, ox + 8 + (1 if y > 7 else 0), y, c("7a3a2a"))
	for b in [[5, 6], [11, 10]]:
		art.ellipse(im, ox + b[0] + 0.5, b[1] + 0.5, 2.8, 3.4, c("8a1e18"))
		art.ellipse(im, ox + b[0], b[1], 2.0, 2.6, c("d9472a"))
		art.px(im, ox + b[0] - 1, b[1] - 1, c("f7a64a"))
		for s in [-1, 0, 1]:
			art.px(im, ox + b[0] + s, b[1] - 4, c("2a1b14"))


func _chanterelle(im: Image, ox: int) -> void:
	# two golden trumpets with wavy caps and false gills
	for m in [[5, 5, 4.0], [11, 7, 3.2]]:
		var x: int = m[0]
		var y: int = m[1]
		var r: float = m[2]
		art.ellipse(im, ox + x + 0.5, y + 0.5, r, 1.8, c("ad7a22"))
		art.ellipse(im, ox + x, y, r - 0.6, 1.2, c("f1cf6a"))
		for dy in range(2, 8):
			var half := maxi(1, int(r) - dy / 2)
			for dx in range(-half, half):
				art.px(im, ox + x + dx, y + dy, c("d8a63b") if dx < 0 else c("ad7a22"))
		art.px(im, ox + x - 1, y + 2, c("7e531c"))
		art.px(im, ox + x + 1, y + 3, c("7e531c"))


func _king_bolete(im: Image, ox: int) -> void:
	# a fat brown cap on a thick white stalk
	art.ellipse(im, ox + 8, 12, 4, 3, c("bdb8ae"))
	art.rect(im, ox + 5, 7, 6, 6, c("e4ddcc"))
	art.rect(im, ox + 9, 7, 2, 6, c("bdb8ae"))
	for y in [9, 11]:
		art.px(im, ox + 6, y, c("bdb8ae"))
		art.px(im, ox + 8, y + 1, c("bdb8ae"))
	art.blob(im, ox + 8, 5, 7, 4, c("5e3a1c"), c("8a5a2c"), c("b0844a"))
	art.rect(im, ox + 2, 7, 12, 1, c("d6bd88"))


func _coyote_mint(im: Image, ox: int) -> void:
	# a round head of lavender flowers over grey-green leaves
	art.rect(im, ox + 7, 6, 1, 9, c("5c8f3c"))
	_leaf(im, ox + 2, 9, 6, 3, "437f45", "aecb62")
	_leaf(im, ox + 8, 11, 6, 3, "437f45", "aecb62")
	art.blob(im, ox + 7.5, 4.5, 4.2, 3.6, c("6f5aa6"), c("9a8ac8"), c("d4c8ec"))
	for p in [[5, 2], [9, 3], [7, 6], [4, 5], [10, 6]]:
		art.px(im, ox + p[0], p[1], c("f5eee0"))


func _hazelnut(im: Image, ox: int) -> void:
	# two round brown nuts, one still in its frilly green husk
	art.blob(im, ox + 5, 10, 3.6, 3.4, c("6a3e1c"), c("a0662e"), c("d49a5a"))
	art.rect(im, ox + 4, 6, 3, 1, c("c8b088"))
	art.blob(im, ox + 11, 7, 3.0, 2.8, c("6a3e1c"), c("a0662e"), c("d49a5a"))
	for p in [[8, 4], [9, 3], [11, 3], [13, 3], [14, 4], [8, 6], [14, 6]]:
		art.px(im, ox + p[0], p[1], c("84b04a"))
	art.rect(im, ox + 9, 2, 5, 2, c("5c8f3c"))
	art.px(im, ox + 11, 1, c("437f45"))


func _whitebark_pine_nuts(im: Image, ox: int) -> void:
	# a purple-brown cone, and the fat seeds shaken out of it
	art.blob(im, ox + 6, 6, 4.0, 4.6, c("3a2438"), c("6a4a5a"), c("9a7a8a"))
	for p in [[4, 4], [7, 3], [5, 7], [8, 6], [6, 9]]:
		art.px(im, ox + p[0], p[1], c("2a1828"))
	for p in [[10, 11], [13, 12], [11, 13], [8, 13]]:
		art.ellipse(im, ox + p[0] + 0.5, p[1] + 0.5, 1.5, 1.1, c("8a5a2c"))
		art.px(im, ox + p[0], p[1], c("d8b47a"))


func _hedgehog_mushroom(im: Image, ox: int) -> void:
	# a buff, lumpy cap with little teeth under it, on a pale stalk
	art.rect(im, ox + 6, 8, 4, 6, c("efe6d2"))
	art.rect(im, ox + 9, 8, 1, 6, c("cbbfa4"))
	art.blob(im, ox + 8, 5, 6.4, 3.4, c("b07a3a"), c("dca868"), c("f4d49a"))
	for x in range(3, 14, 2):
		art.px(im, ox + x, 8, c("e8c890"))
		art.px(im, ox + x + 1, 9, c("c89a5a"))


func _cattail_root(im: Image, ox: int) -> void:
	# a jointed pale rhizome with a green shoot and a few rootlets
	for x in range(2, 14):
		art.rect(im, ox + x, 9 + int(x % 3 == 0), 1, 3, c("e4d4b0"))
		art.px(im, ox + x, 12, c("b09a72"))
	for x in [5, 9]:
		art.rect(im, ox + x, 9, 1, 4, c("a08a64"))
	for p in [[3, 13], [7, 14], [11, 14], [13, 13]]:
		art.px(im, ox + p[0], p[1], c("8a7458"))
	for y in range(1, 9):
		art.px(im, ox + 11 - y / 4, y, c("5c8f3c"))
		art.px(im, ox + 12 - y / 4, y + 1, c("2c5c37"))


func _blue_dicks_corm(im: Image, ox: int) -> void:
	# a round brown corm with its violet flower head still on the stalk
	art.blob(im, ox + 7, 11, 4.0, 3.2, c("5e3a1c"), c("8a5a2c"), c("c8946a"))
	art.px(im, ox + 5, 13, c("e8d8b8"))
	art.px(im, ox + 8, 14, c("e8d8b8"))
	for y in range(3, 8):
		art.px(im, ox + 9 + y / 4, y, c("5c8f3c"))
	art.blob(im, ox + 11, 3, 2.6, 2.2, c("5a3a98"), c("8a6ad0"), c("c0a8f0"))


func _cow_clover(im: Image, ox: int) -> void:
	# three-part leaves and a rose-purple clover head
	for p in [[3, 9], [6, 11], [4, 12]]:
		art.ellipse(im, ox + p[0] + 0.5, p[1] + 0.5, 1.8, 1.4, c("437f45"))
		art.px(im, ox + p[0], p[1], c("84b04a"))
	for p in [[11, 11], [13, 12], [12, 13]]:
		art.ellipse(im, ox + p[0] + 0.5, p[1] + 0.5, 1.6, 1.3, c("2c5c37"))
	for y in range(6, 14):
		art.px(im, ox + 8, y, c("5c8f3c"))
	art.blob(im, ox + 8, 4.5, 3.6, 3.4, c("7a2a5a"), c("b84a8a"), c("e8a0c8"))
	for p in [[7, 2], [9, 3], [6, 5], [10, 5]]:
		art.px(im, ox + p[0], p[1], c("f4d0e4"))


func _sierra_plum(im: Image, ox: int) -> void:
	# two small red plums on a thorny twig
	for x in range(2, 14):
		art.px(im, ox + x, 3 + x / 5, c("5a3a2a"))
	art.px(im, ox + 4, 2, c("5a3a2a"))
	art.px(im, ox + 12, 4, c("5a3a2a"))
	_leaf(im, ox + 8, 0, 6, 3, "2c5c37", "5c8f3c")
	for b in [[5, 9], [11, 10]]:
		art.blob(im, ox + b[0], b[1], 3.2, 3.4, c("6a1a1a"), c("c0302a"), c("f07a5a"))
		art.px(im, ox + b[0], b[1] - 4, c("5a3a2a"))


func _chokecherry(im: Image, ox: int) -> void:
	# a hanging string of dark, shiny cherries
	for y in range(1, 13):
		art.px(im, ox + 8, y, c("6a4a2a"))
	_leaf(im, ox + 1, 1, 6, 3, "2c5c37", "5c8f3c")
	for b in [[6, 5], [10, 6], [6, 9], [10, 10], [8, 13]]:
		_berry(im, ox + b[0], b[1], 1.8, "1a0a14", "4a1a2a", "a04a5a")


# ------------------------------------------------------------ the dishes

func _simmered_berries(im: Image, ox: int) -> void:
	_bowl(im, ox, 8, "b06a40", "84482a")
	art.rect(im, ox + 2, 8, 12, 1, c("5a1a3a"))
	_bowl_of(im, ox, [[4, 7], [7, 6], [10, 7], [6, 8], [9, 8]], ["3a1430", "8a2a4a", "c86a8a"])
	_steam(im, ox, [6])


func _berry_medley(im: Image, ox: int) -> void:
	_bowl(im, ox, 9, "a87a4a", "7a5432")
	var cols := [BLACKBERRY, RASPBERRY, ["235679", "4a6aa8", "9fb8d8"], ["8a1e18", "d9472a", "f7a64a"]]
	var spots := [[3, 8], [6, 6], [9, 7], [12, 8], [5, 9], [8, 4], [11, 5], [7, 8]]
	for i in spots.size():
		var col: Array = cols[i % cols.size()]
		_berry(im, ox + spots[i][0] + 0.5, spots[i][1] + 0.5, 1.7, col[0], col[1], col[2])


func _baked_fruit(im: Image, ox: int) -> void:
	_stone(im, ox)
	for a in [[5, 8], [11, 9]]:
		art.blob(im, ox + a[0], a[1], 3.4, 3, c("8a1e18"), c("b3362b"), c("e8805a"))
		art.px(im, ox + a[0], a[1] - 3, c("47301f"))
		art.px(im, ox + a[0] - 1, a[1] - 1, c("ffd48a")) # split, and the soft inside
		art.px(im, ox + a[0], a[1], c("ffd48a"))


func _wilted_greens(im: Image, ox: int) -> void:
	_bowl(im, ox, 9, "6a6a72", "47464d")
	for p in [[4, 8, "437f45"], [7, 7, "5c8f3c"], [10, 8, "2c5c37"], [6, 9, "84b04a"], [11, 9, "5c8f3c"]]:
		art.ellipse(im, ox + p[0] + 0.5, p[1] + 0.5, 2.4, 1.4, c(p[2]))
	_steam(im, ox, [5, 10])


func _root_hash(im: Image, ox: int) -> void:
	# a cast-iron pan of browned root cubes
	art.ellipse(im, ox + 7, 10, 6.6, 3.8, c("2b2a30"))
	art.ellipse(im, ox + 7, 9.6, 5.6, 2.8, c("47464d"))
	art.rect(im, ox + 13, 9, 3, 1, c("2b2a30"))
	for p in [[4, 9], [7, 8], [9, 10], [5, 11], [10, 8], [7, 10]]:
		art.rect(im, ox + p[0], p[1], 2, 1, c("d8a63b"))
		art.px(im, ox + p[0], p[1], c("f1cf6a"))
		art.px(im, ox + p[0] + 1, p[1], c("ad7a22"))


func _mushroom_skewer(im: Image, ox: int) -> void:
	for x in range(1, 15):
		art.px(im, ox + x, 15 - x, c("8a6a40"))
	for m in [[5, 10, "ad7a22", "f1cf6a"], [8, 7, "5e3a1c", "b0844a"], [11, 4, "ad7a22", "f1cf6a"]]:
		art.ellipse(im, ox + m[0], m[1], 2.6, 2.0, c(m[2]))
		art.ellipse(im, ox + m[0] - 0.5, m[1] - 0.5, 1.6, 1.0, c(m[3]))


func _mushroom_saute(im: Image, ox: int) -> void:
	art.ellipse(im, ox + 7, 10, 6.6, 3.8, c("2b2a30"))
	art.ellipse(im, ox + 7, 9.6, 5.6, 2.8, c("47464d"))
	art.rect(im, ox + 13, 9, 3, 1, c("2b2a30"))
	for p in [[4, 9, "d8a63b"], [8, 8, "8a5a2c"], [6, 11, "d8a63b"], [10, 10, "8a5a2c"]]:
		art.ellipse(im, ox + p[0] + 0.5, p[1] + 0.5, 1.6, 1.1, c(p[2]))
	for p in [[6, 8], [9, 11], [3, 10]]:
		art.px(im, ox + p[0], p[1], c("84b04a"))
	_steam(im, ox, [7])


func _herb_tea(im: Image, ox: int) -> void:
	_cup(im, ox, "93918f", "6a6a72", "aecb62")
	art.px(im, ox + 5, 3, c("6f5aa6"))
	art.px(im, ox + 6, 2, c("9a8ac8"))
	art.px(im, ox + 6, 3, c("5c8f3c"))
	_steam(im, ox, [8])


func _berry_acorn_cakes(im: Image, ox: int) -> void:
	for i in 2:
		var y := 11 - i * 4
		var x := ox + (1 if i == 0 else 3)
		art.ellipse(im, x + 6, y + 1, 6, 2.6, c("6a4426"))
		art.ellipse(im, x + 6, y, 6, 2.6, c("9a6a3c"))
		art.ellipse(im, x + 5, y - 0.5, 3.6, 1.4, c("b8844c"))
		for p in [[3, 0], [6, -1], [8, 1]]:
			art.px(im, x + p[0], y + p[1], c("4a2a68"))


func _berry_cobbler(im: Image, ox: int) -> void:
	# a dutch oven of purple fruit under a golden crust
	art.rect(im, ox + 1, 7, 14, 7, c("2b2a30"))
	art.rect(im, ox + 2, 7, 12, 2, c("6a1a3a"))
	for p in [[3, 7, 4], [8, 7, 4], [5, 9, 5]]:
		art.ellipse(im, ox + p[0] + p[2] / 2.0, p[1] + 0.5, p[2] / 2.0, 1.2, c("d8a63b"))
		art.px(im, ox + p[0] + 1, p[1], c("f1cf6a"))
	art.rect(im, ox, 9, 1, 2, c("2b2a30"))
	art.rect(im, ox + 15, 9, 1, 2, c("2b2a30"))
	_steam(im, ox, [6, 11])


func _mountain_flatbread(im: Image, ox: int) -> void:
	art.ellipse(im, ox + 8, 10, 7.4, 4, c("ad7a22"))
	art.ellipse(im, ox + 7.5, 9.5, 6.4, 3.2, c("d8a63b"))
	art.ellipse(im, ox + 6, 8.6, 3.4, 1.4, c("f1cf6a"))
	for p in [[5, 10], [9, 9], [11, 11], [7, 12]]:
		art.px(im, ox + p[0], p[1], c("7e531c"))
	for p in [[10, 10], [6, 11]]:
		art.px(im, ox + p[0], p[1], c("5c8f3c"))


func _camp_stew(im: Image, ox: int) -> void:
	# a tin billy pot on a bail handle
	art.rect(im, ox + 3, 7, 10, 7, c("93918f"))
	art.rect(im, ox + 9, 7, 4, 7, c("6a6a72"))
	art.rect(im, ox + 4, 7, 1, 6, c("bdb8ae"))
	art.rect(im, ox + 3, 6, 10, 2, c("86694b"))
	for p in [[5, 6, "d8a63b"], [8, 6, "5c8f3c"], [10, 6, "b3362b"]]:
		art.px(im, ox + p[0], p[1], c(p[2]))
	for x in range(3, 13):
		var y := 3 if x > 4 and x < 11 else 4
		art.px(im, ox + x, y - (1 if x > 5 and x < 10 else 0), c("47464d"))
	_steam(im, ox, [6])


func _nut_berry_bars(im: Image, ox: int) -> void:
	for b in [[1, 9], [5, 5]]:
		art.rect(im, ox + b[0], b[1], 10, 5, c("86694b"))
		art.rect(im, ox + b[0], b[1], 10, 1, c("d6bd88"))
		art.rect(im, ox + b[0] + 8, b[1] + 1, 2, 4, c("5e4a38"))
		for p in [[2, 2], [5, 3], [7, 2], [3, 4]]:
			art.px(im, ox + b[0] + p[0], b[1] + p[1], c("e4ddcc"))
		art.px(im, ox + b[0] + 4, b[1] + 2, c("6a1a3a"))
		art.px(im, ox + b[0] + 6, b[1] + 4, c("4a2a68"))


func _roasted_pine_nuts(im: Image, ox: int) -> void:
	_bowl(im, ox, 9, "a87038", "6a4020")
	for p in [[4, 7], [6, 6], [8, 7], [10, 6], [12, 8], [5, 9], [9, 9], [7, 8], [11, 9]]:
		art.ellipse(im, ox + p[0] + 0.5, p[1] + 0.5, 1.4, 1.0, c("ad7a22"))
		art.px(im, ox + p[0], p[1], c("f1cf6a"))


func _chocolate_berries(im: Image, ox: int) -> void:
	_stone(im, ox)
	for b in [[4, 8], [8, 7], [12, 8], [6, 10], [10, 10]]:
		art.ellipse(im, ox + b[0] + 0.5, b[1] + 0.5, 1.8, 1.8, c("b3362b"))
		art.ellipse(im, ox + b[0] + 0.5, b[1] + 1.2, 1.8, 1.1, c("47301f"))
		art.px(im, ox + b[0], b[1] - 1, c("5c8f3c"))


func _foragers_hash(im: Image, ox: int) -> void:
	_bowl(im, ox, 8, "a87a4a", "7a5432")
	for p in [[4, 7, "d8a63b"], [7, 6, "5c8f3c"], [10, 7, "8a2a4a"], [6, 8, "8a5a2c"], [11, 8, "84b04a"], [8, 8, "f1cf6a"]]:
		art.ellipse(im, ox + p[0] + 0.5, p[1] + 0.5, 1.6, 1.2, c(p[2]))
	_steam(im, ox, [5, 10])


func _bitter_mush(im: Image, ox: int) -> void:
	_bowl(im, ox, 8, "6a6a70", "47464d")
	art.rect(im, ox + 2, 7, 12, 2, c("5e4a38"))
	art.rect(im, ox + 4, 7, 4, 1, c("86694b"))
	# a sour green bubble and a curl of dark smoke
	art.px(im, ox + 10, 6, c("84b04a"))
	art.px(im, ox + 6, 4, Color("47464d", 0.7))
	art.px(im, ox + 7, 3, Color("47464d", 0.6))
	art.px(im, ox + 6, 2, Color("47464d", 0.5))
