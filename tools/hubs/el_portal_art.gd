extends "res://tools/hubs/valley_art.gd"
## El Portal pixel art in the Ahwahnee's style (the ramps, upper-left light
## and dark rim of valley_art.gd): the El Portal Market and its gas pumps,
## the post office, the park's staff houses, the Yosemite View Lodge on the
## river, the old railroad yard at the end of the Yosemite Valley Railroad (a
## stretch of track, a caboose, the freight platform, and a rusted Model A
## in the weeds), the Arch Rock entrance station, the park sign, and Arch
## Rock itself, two fallen boulders leaning together over the road. Written
## to assets/sprites/el_portal/ at 16px scale; tools/hubs/rebuild_el_portal.sh
## moves them onto the 32px grid. The trees are in foothill_flora_art.gd.

const EP_OUT := "res://assets/sprites/el_portal/"
## The opening under Arch Rock, in px from the sprite's bottom center.
const ARCH_GAP := 44


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EP_OUT))
	var green := ["1c2a22", "2a4030", "3a5640", "4d6e50", "658a64", "84a67c"]
	var brown := ["2e2218", "4a3422", "644630", "7e5c3e", "9a7650", "b89468"]
	var slate := ["24262a", "34383e", "484e56", "5e666e", "7a828a", "9aa2a8"]
	var red := ["2c1814", "48241c", "663226", "844434", "a05a44", "bc765a"]
	_pair("market", {"size": Vector2i(84, 48), "wall": "board", "tone": 3, "label": "EL PORTAL MARKET", "seed": 140,
		"roof": slate, "windows": [12, 24, 60, 72], "gable": 42, "porch": true, "goods": true, "scale": VILLAGE_SCALE})
	_pair("post_office", {"size": Vector2i(48, 38), "wall": "board", "tone": 2, "label": "U.S. POST OFFICE", "seed": 95318,
		"roof": green, "windows": [9, 39], "gable": 24, "scale": VILLAGE_SCALE})
	_pair("house_a", {"size": Vector2i(46, 38), "wall": "board", "tone": 4, "seed": 201, "roof": green, "windows": [9, 37], "gable": 23,
		"porch": true, "scale": 1.3})
	_pair("house_b", {"size": Vector2i(50, 38), "wall": "board", "tone": 2, "seed": 202, "roof": red, "windows": [10, 22, 40], "chimney": 40,
		"scale": 1.3})
	_pair("house_c", {"size": Vector2i(44, 36), "wall": "board", "tone": 3, "seed": 203, "roof": brown, "windows": [9, 35], "gable": 22,
		"chimney": 8, "scale": 1.3})
	_pair("entrance_station", {"size": Vector2i(40, 36), "wall": "stone", "label": "ARCH ROCK", "seed": 1926,
		"roof": brown, "windows": [9, 31], "scale": 1.2, "low": true})
	var lodge := lodge()
	_ep_write(lodge[0], "lodge")
	_ep_write(lodge[1], "lodge_glow")
	_ep_write(caboose(), "caboose")
	_ep_write(track(96), "track")
	_ep_write(freight_platform(), "freight_platform")
	_ep_write(model_a(), "model_a")
	_ep_write(gas_pump(), "gas_pump")
	_ep_write(flagpole(), "flagpole")
	_ep_write(park_sign(), "park_sign")
	_ep_write(arch_rock(), "arch_rock")
	_ep_write(mailboxes(), "mailboxes")
	var flora := FloraArt.new()
	_ep_write(flora.rock(54, 30, 1401, 0.0, 0.3, true, 1.0), "river_boulder_a")
	_ep_write(flora.rock(40, 24, 1402, 0.0, 0.3, true, 1.0), "river_boulder_b")
	_ep_write(flora.rock(30, 20, 1403, 0.0, 0.4, false, 1.2), "river_boulder_c")


func _pair(sprite_name: String, o: Dictionary) -> void:
	var built := building("", o)
	_ep_write(built[0], sprite_name)
	_ep_write(built[1], sprite_name + "_glow")


func _ep_write(im: Image, sprite_name: String) -> void:
	im.save_png(ProjectSettings.globalize_path(EP_OUT + sprite_name + ".png"))


## Yosemite View Lodge, on the river bank: a long two-story lodge of brown
## board and stone, with a balcony along the upper floor for every room and
## a low-pitched roof. Returns [sprite, glow].
func lodge() -> Array:
	var w := 150
	var h := 86
	var sd := 140
	windows.clear()
	glass_snap = null
	var im := K.make(w, h)
	var base_roof := roof
	roof = _ramp(["24262a", "34383e", "484e56", "5e666e", "7a828a", "9aa2a8"])
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 1.0, 2.6, 0.3)
	var wall_top := 30
	var floor2 := wall_top + 24
	board_wall(im, 1, wall_top, w - 2, h - wall_top - 6, sd, 3)
	stone_wall(im, 1, floor2 + 2, w - 2, h - floor2 - 8, sd + 7, 0.55, 4, 3, false)
	stone_wall(im, 1, h - 7, w - 2, 5, sd + 100, 0.5, 3, 2, true)
	_vb_roof(im, 0, 2, w, wall_top - 3, sd + 200, 0.16)
	_vb_eave(im, 0, wall_top - 2, w)
	# the rooms: a window and a door onto the balcony upstairs, a window and
	# a door below, in bays between stone piers
	var bays := 8
	for b in bays:
		var bx := 6 + b * (w - 12) / bays
		_vb_window(im, bx + 2, wall_top + 5, 7, 9, K.hash2(b, sd, 5) < 0.6, sd + b)
		_vb_window(im, bx + 2, floor2 + 7, 7, 8, K.hash2(b, sd, 6) < 0.6, sd + b * 3)
		K.rect(im, bx + 11, floor2 + 6, 4, h - floor2 - 14, timber[1])
		K.vline(im, bx + 11, floor2 + 6, h - floor2 - 14, timber[3])
	# the balcony: a deck on brackets, a rail with balusters, its shadow
	for xx in range(2, w - 2):
		K.px(im, xx, floor2, timber[4])
		K.px(im, xx, floor2 + 1, timber[2])
		K.px(im, xx, floor2 - 6, timber[4])
		if xx % 3 == 0:
			K.vline(im, xx, floor2 - 5, 5, timber[2])
	for px_ in range(2, w - 3, (w - 4) / bays):
		post(im, px_, wall_top - 1, floor2 - wall_top + 1, sd + px_, 3)
	shade(im, 2, floor2 + 2, w - 4, 4, Color("1e1834"), 0.8, 0.0, 0.4)
	# the office at the left end, with its sign
	sign_board(im, w / 2, wall_top - 8, "YOSEMITE VIEW LODGE")
	shade(im, w - 8, wall_top, 7, h - wall_top - 6, timber[0], 0.0, 0.85, 0.34, false)
	K.outline(im, Color("231a16"))
	var glow := _glow_image(im, w, h)
	roof = base_roof
	return [im, glow]


## A stretch of track: dark ties on ballast with two steel rails, [param
## length] px long, meant to lie flat on the ground.
func track(length: int) -> Image:
	var h := 12
	var im := K.make(length, h)
	for xx in length:
		for yy in range(1, h - 1):
			var n := K.hash2(xx, yy, 7)
			K.px(im, xx, yy, Color("7a7266") if n > 0.6 else (Color("5e584e") if n > 0.25 else Color("948c7e")))
	for tx in range(1, length, 5):
		var col := timber[1] if K.hash2(tx, 1, 3) > 0.3 else timber[2]
		K.rect(im, tx, 1, 3, h - 2, col)
		K.vline(im, tx, 1, h - 2, timber[3])
		K.vline(im, tx + 2, 1, h - 2, timber[0])
	for ry in [3, 8]:
		K.hline(im, 0, ry, length, Color("b8b4ac"))
		K.hline(im, 0, ry + 1, length, Color("5a4a3e"))
	return im


## A Yosemite Valley Railroad caboose on its trucks: a boxcar-red body with
## a cupola on the roof, end platforms with railings, and the road's
## initials along its side.
func caboose() -> Image:
	var w := 70
	var h := 40
	var sd := 1907
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 4.0, 2.4, 0.3)
	var body := _ramp(["2c1210", "481c16", "66281e", "843628", "a04a34", "bc6444"])
	var y0 := 13
	var y1 := h - 10
	# the body: vertical car siding, lit on the left
	for xx in range(8, w - 8):
		for yy in range(y0, y1):
			var t := 0.55 - float(xx - 8) / (w - 16) * 0.25 + (K.hash2(xx / 2, yy / 4, sd) - 0.5) * 0.1
			if xx % 3 == 0:
				t -= 0.12
			K.px(im, xx, yy, body[clampi(roundi(t * 5.0), 0, 5)])
	# the roof and the cupola
	K.rect(im, 6, y0 - 2, w - 12, 2, Color("2a2420"))
	K.hline(im, 6, y0 - 2, w - 12, Color("54483e"))
	for xx in range(26, 44):
		for yy in range(4, y0 - 2):
			K.px(im, xx, yy, body[3] if xx < 35 else body[2])
	K.rect(im, 24, 3, 22, 2, Color("2a2420"))
	K.hline(im, 24, 3, 22, Color("54483e"))
	for wx in [29, 37]:
		_vb_window(im, wx, 6, 4, 3, false, sd + wx)
	# windows and doors
	for wx in [16, 50]:
		_vb_window(im, wx, y0 + 4, 5, 6, false, sd + wx)
	K.text(im, 25, y0 + 6, "Y.V.R.R.", Color("e8d8a8"), body[0])
	# end platforms with railings and ladders
	for side in [0, 1]:
		var px0 := 1 if side == 0 else w - 9
		K.rect(im, px0, y1 - 1, 8, 2, Color("3a3430"))
		for k in 3:
			K.vline(im, px0 + 1 + k * 3, y0 + 2, y1 - y0 - 3, Color("2a2626"))
		K.hline(im, px0, y0 + 2, 8, Color("5a524a"))
	# the trucks and wheels on the rail
	for tx in [16, 54]:
		K.rect(im, tx - 8, y1, 16, 3, Color("1e1c1c"))
		for wx in [tx - 5, tx + 5]:
			K.ellipse(im, wx, y1 + 4, 3.2, 3.2, Color("2a2828"))
			K.px(im, wx - 1, y1 + 3, Color("6a6460"))
	K.hline(im, 0, h - 4, w, Color("8a867e"))
	K.outline(im, Color("1e1414"))
	return im


## The freight platform where the flour and the mail came off the train: a
## plank dock with crates, sacks and a barrel on it.
func freight_platform() -> Image:
	var w := 64
	var h := 26
	var sd := 1945
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 2.0, 2.2, 0.3)
	_vb_plank_rows(im, 1, 12, w - 2, 6, sd, 2)
	for xx in range(1, w - 1):
		K.px(im, xx, 18, timber[0])
	for px_ in range(3, w - 3, 10):
		K.rect(im, px_, 18, 3, 5, timber[1])
		K.vline(im, px_, 18, 5, timber[3])
	K.crate(im, 5, 5, 10, 8, timber[3])
	K.crate(im, 15, 7, 8, 6, timber[2])
	K.barrel(im, 44, 4, 7, 9, timber[3])
	for k in 3:
		var sx := 26 + k * 5
		K.rect(im, sx, 7, 5, 6, stucco[4])
		K.vline(im, sx + 4, 7, 6, stucco[2])
		K.hline(im, sx + 1, 6, 3, stucco[3])
	K.outline(im, Color("231a16"))
	return im


## A Model A Ford left to rust by the tracks: the body sagging on its rims,
## fenders gone to brown flakes, and grass grown up through it.
func model_a() -> Image:
	var w := 40
	var h := 28
	var sd := 1928
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 3.0, 17.0, 2.4, 0.3)
	var rust := _ramp(["2a1610", "46241a", "683622", "8a4a2a", "a8643a", "c48452"])
	# fenders and running board
	for side in [0, 1]:
		var fx := 3 if side == 0 else w - 13
		for xx in 10:
			for yy in 5:
				if yy < 2 and (xx < 2 - yy or xx > 7 + yy):
					continue
				K.px(im, fx + xx, h - 11 + yy, rust[clampi(2 + int(K.hash2(xx, yy, sd + side) * 3.0) - yy / 3, 0, 5)])
	K.rect(im, 8, h - 8, w - 16, 2, rust[1])
	# the cab, square and upright, with its windows empty
	for xx in range(9, w - 9):
		for yy in range(5, h - 8):
			var t := 0.6 - float(xx - 9) / (w - 18) * 0.3 + (K.hash2(xx, yy, sd) - 0.5) * 0.4
			K.px(im, xx, yy, rust[clampi(roundi(t * 5.0), 0, 5)])
	K.rect(im, 8, 3, w - 16, 3, rust[1])
	K.hline(im, 8, 3, w - 16, rust[3])
	for wx in [12, 21]:
		K.rect(im, wx, 7, 7, 5, Color("1a1412"))
		K.hline(im, wx, 7, 7, Color("2e2420"))
	# the radiator shell and one headlamp left
	K.rect(im, 4, 10, 5, 7, Color("3a3430"))
	K.px(im, 3, 9, Color("c8c0a8"))
	# wheels: bare rims, one sunk in the dirt
	for wx in [10, w - 10]:
		K.ellipse(im, wx, h - 6, 3.5, 3.0, Color("1e1a18"))
		K.ring(im, wx, h - 6, 3.0, 2.6, rust[2])
	# grass through the floor
	for k in 16:
		var gx := 4 + int(K.hash2(k, 1, sd) * (w - 8))
		var gh := 2 + int(K.hash2(k, 2, sd) * 4.0)
		K.vline(im, gx, h - 4 - gh, gh, Color("8a9a4a") if k % 2 == 0 else Color("b8a860"))
	K.outline(im, Color("1e1410"))
	return im


## A gas pump: a white cabinet with a red band and a hose.
func gas_pump() -> Image:
	var w := 12
	var h := 22
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, 5.0, 1.6, 0.3)
	K.rect(im, 2, 3, 8, 15, Color("e8e4d8"))
	K.vline(im, 2, 3, 15, Color("ffffff"))
	K.vline(im, 9, 3, 15, Color("a8a49a"))
	K.rect(im, 2, 8, 8, 3, Color("b8382a"))
	K.rect(im, 3, 4, 6, 3, Color("2a3038"))
	K.px(im, 4, 5, Color("f0c84a"))
	K.rect(im, 1, 18, 10, 2, Color("6a6a70"))
	K.vline(im, 10, 9, 6, Color("1e1e22"))
	K.px(im, 11, 15, Color("1e1e22"))
	K.outline(im, Color("1e1a18"))
	return im


## A flagpole with the flag out.
func flagpole() -> Image:
	var w := 18
	var h := 52
	var im := K.make(w, h)
	K.shadow(im, 3.0, h - 2.0, 4.0, 1.4, 0.3)
	K.vline(im, 2, 2, h - 4, Color("d8d4cc"))
	K.vline(im, 3, 2, h - 4, Color("8a867e"))
	K.px(im, 2, 1, Color("f0c84a"))
	for yy in 9:
		for xx in 13:
			var wave := int(sin(xx * 0.6) * 1.0)
			var col := Color("b8382a") if (yy / 1) % 2 == 0 else Color("f5eee0")
			if xx < 6 and yy < 5:
				col = Color("2a3a7a")
				if (xx + yy) % 2 == 0:
					col = Color("e8e8f0")
			K.px(im, 4 + xx, 3 + yy + wave, col)
	K.rect(im, 0, h - 4, 6, 2, granite[4])
	K.outline(im, Color("1e1a18"))
	return im


## The park sign by the road: routed letters on a heavy plank between two
## piers of river stone.
func park_sign() -> Image:
	var w := 112
	var h := 32
	var sd := 1890
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 2.0, 2.2, 0.3)
	for side in [0, 1]:
		stone_wall(im, 2 if side == 0 else w - 12, 6, 10, h - 8, sd + side, 0.5, 3, 2, true)
	K.rect(im, 9, 9, w - 18, 13, timber[0])
	board_wall(im, 10, 10, w - 20, 11, sd, 3)
	for xx in range(10, w - 10):
		K.px(im, xx, 10, timber[4])
	K.text_centered(im, 10, w - 20, 11, "YOSEMITE NATIONAL PARK", Color("f0e2bc"), timber[0])
	K.outline(im, Color("231a16"))
	return im


## A row of rural mailboxes on a rail, for the town.
func mailboxes() -> Image:
	var w := 30
	var h := 16
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, 13.0, 1.4, 0.3)
	K.hline(im, 1, 7, w - 2, timber[2])
	for px_ in [4, w - 5]:
		K.vline(im, px_, 7, h - 9, timber[1])
	for k in 4:
		var bx := 2 + k * 7
		var col: Color = [Color("8a8e92"), Color("2a2a2e"), Color("8a8e92"), Color("4a5a3a")][k]
		K.rect(im, bx, 2, 6, 5, col)
		K.hline(im, bx, 2, 6, col.lightened(0.3))
		if k % 2 == 0:
			K.px(im, bx + 5, 1, Color("c8382a"))
	K.outline(im, Color("1e1a18"))
	return im


## Arch Rock: two huge granite boulders that fell from the canyon wall and
## came to rest leaning on each other, with the road threaded under them.
## Seen from down the road: the opening is ARCH_GAP px wide at the bottom
## center, with the road going on beyond it.
func arch_rock() -> Image:
	var w := 172
	var h := 116
	var sd := 1926
	var im := K.make(w, h)
	var tone := FloraArt.ramp(FloraArt.ROCK_TONE)
	var cx := w / 2.0
	K.shadow(im, cx + 4.0, h - 3.0, w / 2.0 - 4.0, 4.0, 0.34)
	# a height field: two leaning boulders, the left one bigger
	var hts := PackedFloat32Array()
	hts.resize(w * h)
	for y in h:
		for x in w:
			var best := 0.0
			for b: Array in [[52.0, 64.0, 50.0, 54.0, 0.42], [121.0, 68.0, 47.0, 50.0, -0.45]]:
				var dx: float = (x + 0.5 - b[0]) / b[2]
				var dy: float = (y + 0.5 - b[1]) / b[3]
				dx += dy * float(b[4])
				var d := dx * dx + dy * dy
				d += (vnoise(x * 0.12, y * 0.12, sd) - 0.5) * 0.35
				if d < 1.0:
					best = maxf(best, sqrt(1.0 - d))
			hts[y * w + x] = best
	# the opening under the arch
	var gap := ARCH_GAP / 2.0
	for y in h:
		for x in w:
			# a pointed gap where the two boulders lean together
			var dx := (x + 0.5 - cx) / gap
			var up := float(h - 4 - y) / 64.0
			if up < 1.0 and absf(dx) < pow(1.0 - up, 0.7) and y < h - 3:
				hts[y * w + x] = -1.0
	for y in h:
		for x in w:
			var v := hts[y * w + x]
			if v == 0.0:
				continue
			if v < 0.0:
				# through the arch: the road going on, and the canyon beyond
				var up := float(h - 4 - y) / 64.0
				var col := Color("4a4a50") if up < 0.18 else (Color("5c7a46") if up < 0.45 else Color("8aa0b4"))
				if up < 0.18 and absf(x + 0.5 - cx) < 1.0 and (y % 4) < 2:
					col = Color("e8d070")
				K.px(im, x, y, col)
				continue
			var gx := hts[y * w + mini(x + 1, w - 1)] - hts[y * w + maxi(x - 1, 0)]
			var gy := hts[mini(y + 1, h - 1) * w + x] - hts[maxi(y - 1, 0) * w + x]
			var lam := 0.42 - gx * 2.2 - gy * 2.6 + v * 0.2
			lam += (K.hash2(x / 2, y / 2, sd) - 0.5) * 0.14
			var col := FloraArt.shade(tone, clampf(lam, 0.0, 1.0), x, y)
			# dark cracks where the blocks meet, and lichen
			if absf(vnoise(x * 0.09, y * 0.2, sd + 3) - 0.5) < 0.02:
				col = tone[1]
			elif K.hash2(x, y, sd + 7) < 0.012:
				col = Color("c8b45a")
			K.px(im, x, y, col)
	# the dark undersides inside the arch
	for y in range(h - 70, h - 3):
		for x in range(int(cx - gap - 3), int(cx + gap + 3)):
			if hts[y * w + x] > 0.0 and (hts[mini(y + 2, h - 1) * w + x] < 0.0 or hts[y * w + mini(x + 2, w - 1)] < 0.0 or hts[y * w + maxi(x - 2, 0)] < 0.0):
				K.px(im, x, y, tone[1])
	FloraArt.rim(im, 0.5)
	return im
