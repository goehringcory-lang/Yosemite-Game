extends "res://tools/hubs/valley_art.gd"
## The larger buildings of the generated hubs, in the Ahwahnee's style: lodges
## of a few set widths (timber, granite foot, mossy shingles, a cross gable and
## a stone chimney) and the Wawona Hotel (long, white, two stories, a veranda
## on each floor, green roof). Written to assets/sprites/hub_buildings/, each
## with a "_glow" picture of its lit windows. Every window is drawn as day
## glass, so nothing looks lit at noon; the glow comes up after dark.
##
## Every sprite is anchored at its bottom center. Hub_buildings.gd places them.
##   godot --headless --path . res://tools/mapgen/rebuild_buildings.tscn -- paint

const DIR_OUT := "res://assets/sprites/hub_buildings/"
const LODGE_WIDTHS := [48, 72, 104]
const HOTEL_WIDTHS := [96, 128]
const HOTEL_HEIGHT := 70
const DAY_GLASS := Color("56707f")
const WHITE := ["8c8678", "aaa496", "c8c2b2", "dedacc", "eeeae0", "fbf8f0"]
const HOTEL_ROOF := ["16281e", "223c2c", "30543c", "416e4e", "578a64", "76a682"]


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_OUT))
	for w: int in LODGE_WIDTHS:
		_save_pair(lodge(w), "lodge_%d" % w)
	for w: int in HOTEL_WIDTHS:
		_save_pair(wawona_hotel(w), "hotel_%d" % w)


func _save_pair(built: Array, sprite_name: String) -> void:
	built[0].save_png(ProjectSettings.globalize_path(DIR_OUT + sprite_name + ".png"))
	built[1].save_png(ProjectSettings.globalize_path(DIR_OUT + sprite_name + "_glow.png"))


## Every window is day glass; the glow picture lights it.
func window(im: Image, x: int, y: int, w: int, h: int, _lit: bool, sd: int) -> void:
	super(im, x, y, w, h, false, sd)


static func lodge_height(w: int) -> int:
	return 38 if w <= 48 else (42 if w <= 72 else 46)


## Returns [sprite, glow]: a timber lodge [param w] pixels wide.
func lodge(w: int) -> Array:
	var h := lodge_height(w)
	var door := w / 2
	var wins: Array = []
	for wx in range(10, w - 6, 14 if w > 48 else 12):
		if absi(wx - door) > 9:
			wins.append(wx)
	var o := {"size": Vector2i(w, h), "wall": "timber", "seed": 90 + w, "dark": true, "windows": wins,
		"chimney": int(w * 0.8) - 6, "pitch": 12}
	if w >= 72:
		o["gable"] = w / 4 + 2
	return building("", o)


## Returns [sprite, glow]: the Wawona Hotel, [param w] pixels wide. Two
## stories of white clapboard behind a veranda on each floor, a green shingle
## roof with a pedimented center and two chimneys, a stone footing.
func wawona_hotel(w: int) -> Array:
	var h := HOTEL_HEIGHT
	var sd := 301 + w
	var base_timber := timber
	var base_stucco := stucco
	var base_roof := roof
	timber = _ramp(WHITE)
	stucco = _ramp(WHITE)
	roof = _ramp(HOTEL_ROOF)
	windows.clear()
	glass_snap = null
	var im := K.make(w, h)
	var cx := w / 2
	var up_top := 28
	var up_bot := 45
	var low_bot := 62
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 1.0, 2.6, 0.3)

	# Walls: clapboard on both stories, a stone footing under the veranda.
	K.lap(im, 2, up_top, w - 4, low_bot - up_top, timber[4], sd)
	stone_wall(im, 1, low_bot, w - 2, h - low_bot - 1, sd + 2, 0.5, 3, 2, true)
	K.hline(im, 1, low_bot, w - 2, granite[5])
	# Shade under the eaves and the upper deck.
	K.rect(im, 2, up_top, w - 4, 3, Color(0, 0, 0, 0.3))
	K.rect(im, 2, up_bot, w - 4, 3, Color(0, 0, 0, 0.26))

	# Windows with green shutters, one to a bay, and a door at the center of each floor.
	var bay := 16
	for k in range(-(cx / bay), cx / bay + 1):
		var wx := cx + k * bay - 2
		if k == 0 or wx < 6 or wx + 5 > w - 6:
			continue
		for y in [up_top + 5, up_bot + 5]:
			K.window(im, wx, y, 5, 8, timber[5], DAY_GLASS, Color(0, 0, 0, 0), Color("3a5a46"), false)
			_register(im, Rect2i(wx, y, 5, 8), 0.9)
	K.door(im, cx - 3, low_bot - 12, 6, 12, Color("3a5a48"), timber[5], false)
	K.door(im, cx - 3, up_bot - 11, 6, 11, Color("3a5a48"), timber[5], false)

	# Verandas: a deck, a railing, and a post between each pair of bays.
	for deck in [up_bot, low_bot]:
		K.boards(im, 0, deck, w, 3, Color("a8998a"), sd + deck, 5)
		K.hline(im, 0, deck, w, timber[5])
		K.hline(im, 0, deck + 3, w, Color(0, 0, 0, 0.35))
		K.hline(im, 1, deck - 5, w - 2, timber[5])
		for bx in range(3, w - 2, 4):
			K.vline(im, bx, deck - 4, 4, timber[3])
		for k in range(-(cx / bay), cx / bay + 1):
			var px_ := cx + k * bay - bay / 2 - 1
			if px_ < 1 or px_ + 3 > w - 1:
				continue
			K.rect(im, px_, deck - 17, 3, 17, timber[4])
			K.vline(im, px_, deck - 17, 17, timber[5])
			K.vline(im, px_ + 2, deck - 17, 17, timber[2])
	K.hline(im, 0, up_top - 1, w, timber[5])

	# The roof, a pedimented center over the entrance, two chimneys.
	shingle_roof(im, 0, 6, w, up_top - 6, sd + 3, 0.1)
	eave(im, 0, up_top - 2, w)
	gable(im, cx, up_top, mini(16, w / 6), 14, 3, sd + 4, true, 6)
	for chx in [w / 5, w - w / 5 - 12]:
		chimney(im, chx, 1, 14, sd + chx)

	shade(im, w - 9, up_top, 8, low_bot - up_top, granite[0], 0.0, 0.85, 0.3, false)
	K.outline(im, Color("231a16"))
	var glow := _glow_image(im, w, h)
	timber = base_timber
	stucco = base_stucco
	roof = base_roof
	return [im, glow]
