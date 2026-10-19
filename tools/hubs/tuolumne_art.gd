extends "res://tools/hubs/valley_art.gd"
## Tuolumne Meadows pixel art in the Ahwahnee's style (the ramps, upper-left
## light and dark rim of valley_art.gd): the granite domes round the meadow
## (Lembert Dome with its glacier-plucked west face, Pothole Dome, Fairview
## Dome), the spires of Cathedral Peak, Parsons Memorial Lodge (1915) of
## local granite, the McCauley Cabin, the log enclosure round Soda Springs,
## the visitor center, the big canvas tents of the store and the lodge, and
## the footbridge over the Tuolumne. Written to assets/sprites/tuolumne/ at
## 16px scale; tools/hubs/rebuild_tuolumne.sh moves them onto the 32px grid.
## The lodgepoles and whitebark pines are in foothill_flora_art.gd.

const TM_OUT := "res://assets/sprites/tuolumne/"
## The domes and the peak: [width, height, how far the solid base reaches
## back from the sprite's foot, in px] (the builder lays CLIFF under them).
const MASSES := {
	"lembert_dome": Vector3i(400, 230, 96),
	"pothole_dome": Vector3i(230, 100, 52),
	"fairview_dome": Vector3i(250, 190, 80),
	"cathedral_peak": Vector3i(260, 300, 72),
}
const FOOTBRIDGE := Vector2i(36, 80)


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TM_OUT))
	var shake := ["2a2622", "3e3832", "564e44", "6e6456", "887c6a", "a49882"]
	var green := ["1c2a22", "2a4030", "3a5640", "4d6e50", "658a64", "84a67c"]
	_tm_write(dome(400, 230, 1911, 0.55, 1.6, 0.65), "lembert_dome")
	_tm_write(dome(230, 100, 1912, 0.95, 1.05, 0.9), "pothole_dome")
	_tm_write(dome(250, 190, 1913, 0.75, 1.15, 0.3), "fairview_dome")
	_tm_write(cathedral_peak(), "cathedral_peak")
	_pair("parsons_lodge", building("", {"size": Vector2i(60, 44), "wall": "stone", "seed": 1915, "roof": shake,
		"windows": [12, 48], "gable": 30, "chimney": 50, "dark": true, "scale": 1.35}))
	_pair("mccauley_cabin", building("", {"size": Vector2i(44, 36), "wall": "timber", "seed": 1902, "roof": shake,
		"windows": [10], "chimney": 34, "dark": true, "scale": 1.3}))
	_pair("visitor_center", building("", {"size": Vector2i(64, 42), "wall": "stone_timber", "label": "VISITOR CENTER", "seed": 1930,
		"roof": green, "windows": [10, 22, 42, 54], "gable": 32, "chimney": 54, "scale": VILLAGE_SCALE}))
	_pair("store_tent", canvas_hall(118, 64, "STORE  GRILL", 1924))
	_pair("lodge_tent", canvas_hall(96, 58, "TUOLUMNE LODGE", 1916))
	_tm_write(soda_springs(), "soda_springs")
	_tm_write(footbridge(), "footbridge")


func _pair(sprite_name: String, built: Array) -> void:
	_tm_write(built[0], sprite_name)
	_tm_write(built[1], sprite_name + "_glow")


func _tm_write(im: Image, sprite_name: String) -> void:
	im.save_png(ProjectSettings.globalize_path(TM_OUT + sprite_name + ".png"))


# ---------------------------------------------------------------- granite

const STAIN := Color("3a3a44")
const LICHEN := Color("c8b45a")


## Lights a granite height field (0 outside, up to 1 at the top) from the
## upper left in the flora's rock tones, with sheeting joints, black water
## streaks down the steep faces, lichen, and a few lodgepoles in the cracks.
func _granite(im: Image, hts: PackedFloat32Array, w: int, h: int, sd: int, sheets := true, trees := 10, relief := 1.0) -> void:
	var tone := FloraArt.ramp(FloraArt.ROCK_TONE)
	for y in h:
		for x in w:
			var v := hts[y * w + x]
			if v <= 0.0:
				continue
			var gx := hts[y * w + mini(x + 1, w - 1)] - hts[y * w + maxi(x - 1, 0)]
			var gy := hts[mini(y + 1, h - 1) * w + x] - hts[maxi(y - 1, 0) * w + x]
			var lam := 0.46 + (gx * 14.0 + gy * 7.0) * relief + v * 0.2
			lam += (K.hash2(x / 2, y / 2, sd) - 0.5) * 0.12
			var col := FloraArt.shade(tone, clampf(lam, 0.0, 1.0), x, y)
			# the joints where sheets of granite peel away, following the form
			if sheets and absf(fmod(v * 7.0 + vnoise(x * 0.05, y * 0.05, sd) * 0.6, 1.0) - 0.5) < 0.035:
				col = col.darkened(0.22)
			# water streaks down the steep, shaded faces
			if gx < -0.04 and vnoise(x * 0.5, y * 0.03, sd + 5) > 0.66:
				col = col.lerp(STAIN, 0.45)
			if K.hash2(x, y, sd + 7) < 0.01:
				col = LICHEN
			K.px(im, x, y, col)
	# a few small lodgepoles rooted in cracks on the lower slopes
	var green := FloraArt.ramp(["152a20", "1e3a28", "2a4c30", "3a6038", "4e7642"])
	for i in trees:
		var x := int(K.hash2(i, 1, sd) * w)
		var y := int(h * 0.55 + K.hash2(i, 2, sd) * h * 0.4)
		if y >= h or hts[y * w + x] <= 0.05 or hts[y * w + x] > 0.6:
			continue
		for k in 8:
			var half := int(k * 0.45)
			K.hline(im, x - half, y - 8 + k, half * 2 + 1, green[clampi(1 + (k % 3) - (1 if k > 5 else 0), 0, 4)])
		K.vline(im, x, y, 2, Color("4a3a2e"))


## A skirt of fallen blocks along the foot of a granite mass, so it meets
## the ground in rubble, not a ruled line.
func _skirt(im: Image, hts: PackedFloat32Array, w: int, h: int, sd: int) -> void:
	var tone := FloraArt.ramp(FloraArt.ROCK_TONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var left := w
	var right := 0
	for x in w:
		if hts[(h - 5) * w + x] > 0.0:
			left = mini(left, x)
			right = maxi(right, x)
	if right <= left:
		return
	for i in (right - left) / 3:
		var cx := rng.randf_range(left - 6, right + 6)
		var cy := h - 4 - rng.randf() * 7.0
		var r := rng.randf_range(1.5, 4.0)
		for y in range(int(cy - r), int(cy + r * 0.7) + 1):
			for x in range(int(cx - r), int(cx + r) + 1):
				if x < 0 or x >= w or y < 0 or y >= h:
					continue
				var dx := (x + 0.5 - cx) / r
				var dy := (y + 0.5 - cy) / (r * 0.75)
				if dx * dx + dy * dy > 1.0:
					continue
				var t := 0.6 - dx * 0.3 - dy * 0.35 + (K.hash2(x, y, sd) - 0.5) * 0.2
				K.px(im, x, y, FloraArt.shade(tone, clampf(t, 0.0, 1.0), x, y))


## A granite dome: the glaciers rounded its upstream (east) side and plucked
## its downstream (west, left) side into a steeper face. [param left] and
## [param right] are its half-widths as fractions of the sprite's, and
## [param plucked] how much steeper the left side is.
func dome(w: int, h: int, sd: int, left: float, right: float, plucked: float) -> Image:
	var im := K.make(w, h)
	K.shadow(im, w / 2.0 + 6.0, h - 3.0, w / 2.0 - 8.0, 4.0, 0.3)
	var hts := PackedFloat32Array()
	hts.resize(w * h)
	var cx := w * 0.45
	for y in h:
		for x in w:
			var rx := (cx * left) if x < cx else ((w - cx) * right * 0.62)
			var dx := (x + 0.5 - cx) / maxf(rx, 1.0)
			var up := float(h - 4 - y) / (h - 6.0)
			var top := 1.0 - dx * dx
			if x < cx:
				top = 1.0 - pow(absf(dx), 1.0 + plucked * 2.0)
			top += (vnoise(x * 0.06, 0.0, sd) - 0.5) * 0.04
			if up < 0.0 or up > top or y > h - 4 - int(vnoise(x * 0.07, 3.0, sd) * 9.0):
				continue
			hts[y * w + x] = sqrt(maxf(0.0, top - up)) * 0.9 + 0.1 * (1.0 - absf(dx))
	_granite(im, hts, w, h, sd, true, w / 18)
	_skirt(im, hts, w, h, sd + 1)
	FloraArt.rim(im, 0.5)
	return im


## Cathedral Peak: a cluster of granite spires, the highest a fin with a
## summit block on top, ledges across its faces and snow lingering in the
## shaded gullies into summer.
func cathedral_peak() -> Image:
	var w := 260
	var h := 300
	var sd := 1869
	var im := K.make(w, h)
	K.shadow(im, w / 2.0 + 6.0, h - 3.0, w / 2.0 - 10.0, 4.0, 0.3)
	var hts := PackedFloat32Array()
	hts.resize(w * h)
	# [x of the tip, y of the tip, half-width at the base]
	var spires := [[125.0, 4.0, 68.0], [80.0, 80.0, 66.0], [182.0, 62.0, 68.0], [130.0, 128.0, 126.0]]
	for y in h:
		for x in w:
			var best := 0.0
			for s: Array in spires:
				var t := (y - float(s[1])) / (h - 4.0 - float(s[1]))
				if t < 0.0 or t > 1.0:
					continue
				var half: float = float(s[2]) * pow(t, 0.8)
				var d := absf(x + 0.5 - float(s[0])) / maxf(half, 0.5)
				d += (vnoise(x * 0.1, y * 0.1, sd) - 0.5) * 0.45
				if d < 1.0 and y <= h - 4 - int(vnoise(x * 0.07, 3.0, sd) * 9.0):
					best = maxf(best, (1.0 - d) * (1.0 - t * 0.6))
			hts[y * w + x] = best
	_granite(im, hts, w, h, sd, false, 8, 0.4)
	# snow lingering in the shaded gullies
	for y in range(20, int(h * 0.6)):
		for x in w:
			var v := hts[y * w + x]
			if v <= 0.0:
				continue
			var gx := hts[y * w + mini(x + 1, w - 1)] - hts[y * w + maxi(x - 1, 0)]
			if gx < -0.02 and v < 0.25 and vnoise(x * 0.12, y * 0.12, sd + 9) > 0.62:
				K.px(im, x, y, Color("eef4f8") if (x + y) % 3 else Color("b4c4d0"))
	_skirt(im, hts, w, h, sd + 1)
	FloraArt.rim(im, 0.5)
	return im


# ---------------------------------------------------------------- buildings and props

## A long canvas tent on a wooden frame, like the Tuolumne Meadows store and
## grill and the lodge's dining tent: low board walls, a sagging cream canvas
## roof between its rafters, a stovepipe, and a sign. Returns [sprite, glow].
func canvas_hall(w: int, h: int, label: String, sd: int) -> Array:
	windows.clear()
	glass_snap = null
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 1.0, 2.6, 0.3)
	var canvas := _ramp(["7a7464", "9c9682", "bab39c", "d4ccb2", "e6dfc6", "f4eedc"])
	var wall_top := int(h * 0.56)
	board_wall(im, 1, wall_top, w - 2, h - wall_top - 3, sd, 3)
	# the roof: canvas between rafters, each bay sagging a little, a ridge pole
	for yy in range(3, wall_top):
		var t := float(yy - 3) / (wall_top - 3)
		var inset := int((1.0 - t) * 6.0)
		for xx in range(inset, w - inset):
			var bay := xx % 16
			var sag := sin(bay / 16.0 * PI) * 0.12
			var lv := 0.75 - t * 0.35 + sag - float(xx) / w * 0.12 + (K.hash2(xx / 3, yy / 2, sd) - 0.5) * 0.05
			var col := canvas[clampi(roundi(lv * 5.0), 0, 5)]
			if bay == 0:
				col = canvas[1]
			K.px(im, xx, yy, col)
	K.hline(im, 6, 3, w - 12, canvas[5])
	K.hline(im, 6, 4, w - 12, canvas[2])
	_vb_eave(im, 0, wall_top - 1, w)
	for wx in range(12, w - 10, 18):
		if absi(wx - w / 2) < 10:
			continue
		_vb_window(im, wx, wall_top + 4, 7, mini(8, h - wall_top - 10), K.hash2(wx, sd, 5) < 0.6, sd + wx)
	plank_door(im, w / 2, h - 3, mini(14, h - wall_top - 4), sd + 500, 10)
	chimney(im, int(w * 0.78), 0, 8, sd + 3)
	sign_board(im, w / 2, wall_top - 10, label)
	K.outline(im, Color("2a2420"))
	var glow := _glow_image(im, w, h)
	return [im, glow]


## Soda Springs: a roofless pen of logs round the rust-red ground where cold,
## fizzy water bubbles up.
func soda_springs() -> Image:
	var w := 56
	var h := 40
	var sd := 1885
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 3.0, w / 2.0 - 2.0, 2.4, 0.3)
	# the iron-stained ground and the spring pools
	for yy in range(10, h - 6):
		for xx in range(5, w - 5):
			var n := vnoise(xx * 0.2, yy * 0.2, sd)
			var col := Color("a8542a") if n > 0.55 else (Color("c87a3a") if n > 0.35 else Color("8a4424"))
			K.px(im, xx, yy, col)
	for pool: Array in [[20, 22, 5.0, 3.0], [36, 26, 4.0, 2.4]]:
		K.ellipse(im, pool[0], pool[1], pool[2], pool[3], Color("5a8a7a"))
		K.ellipse(im, pool[0] - 1, pool[1] - 1, pool[2] - 2.0, pool[3] - 1.4, Color("8ac0b0"))
		for b in 3:
			K.px(im, int(pool[0]) - 2 + b * 2, int(pool[1]), Color("e8f4f0"))
	# the log walls, three courses, notched at the corners (the front is low)
	for course in 3:
		var y0 := 8 + course * 2
		_log(im, 2, y0, w - 4, sd + course)
		K.vline(im, 3, y0, h - y0 - 6, timber[2])
		K.vline(im, w - 4, y0, h - y0 - 6, timber[1])
	_log(im, 2, h - 8, w - 4, sd + 9)
	K.outline(im, Color("231a16"))
	return im


func _log(im: Image, x: int, y: int, length: int, sd: int) -> void:
	for xx in length:
		K.px(im, x + xx, y, timber[4] if K.hash2(xx / 4, sd, 1) > 0.2 else timber[3])
		K.px(im, x + xx, y + 1, timber[1])
	K.px(im, x, y, timber[5])
	K.px(im, x + length - 1, y + 1, timber[0])


## The footbridge over the Tuolumne, seen from above: a plank deck running
## north and south between two log rails. Lies flat over the river.
func footbridge() -> Image:
	var w := FOOTBRIDGE.x
	var h := FOOTBRIDGE.y
	var im := K.make(w, h)
	for yy in h:
		var plank := yy / 3
		for xx in range(4, w - 4):
			var idx := 3 + int(K.hash2(plank, xx / 9, 7) * 2.0)
			if yy % 3 == 2:
				idx = 1
			K.px(im, xx, yy, timber[clampi(idx, 0, 5)])
	for side in [0, w - 4]:
		for yy in h:
			K.px(im, side, yy, timber[4])
			K.px(im, side + 1, yy, timber[3])
			K.px(im, side + 2, yy, timber[1])
			K.px(im, side + 3, yy, Color(0.1, 0.1, 0.15, 0.4))
		for yy in range(2, h, 12):
			K.rect(im, side, yy, 4, 3, timber[2])
			K.hline(im, side, yy, 4, timber[5])
	K.outline(im, Color("231a16"))
	return im
