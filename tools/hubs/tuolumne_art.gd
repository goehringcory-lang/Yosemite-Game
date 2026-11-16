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
const ROAD_BRIDGE := Vector2i(46, 80)


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TM_OUT))
	var shake := ["2a2622", "3e3832", "564e44", "6e6456", "887c6a", "a49882"]
	var green := ["1c2a22", "2a4030", "3a5640", "4d6e50", "658a64", "84a67c"]
	_tm_write(lembert_dome(), "lembert_dome")
	_tm_write(dome(230, 100, 1912, 0.95, 1.05, 0.9), "pothole_dome")
	_tm_write(dome(250, 190, 1913, 0.75, 1.15, 0.3), "fairview_dome")
	_tm_write(cathedral_peak(), "cathedral_peak")
	_pair("parsons_lodge", building("", {"size": Vector2i(60, 44), "wall": "stone", "seed": 1915, "roof": shake,
		"windows": [12, 48], "gable": 30, "chimney": 50, "dark": true, "scale": 1.35}))
	_pair("mccauley_cabin", building("", {"size": Vector2i(44, 36), "wall": "timber", "seed": 1902, "roof": shake,
		"windows": [10], "chimney": 34, "dark": true, "scale": 1.3}))
	_pair("visitor_center", building("", {"size": Vector2i(64, 42), "wall": "stone_timber", "label": "VISITOR CENTER", "seed": 1930,
		"roof": green, "windows": [10, 22, 42, 54], "gable": 32, "chimney": 54, "scale": VILLAGE_SCALE}))
	save_dressing()
	_tm_write(soda_springs(), "soda_springs")
	_tm_write(footbridge(), "footbridge")
	_tm_write(road_bridge(), "road_bridge")


## The store and lodge halls and the props round them. Also drawn on their
## own by tools/hubs/rebuild_tuolumne_dressing.sh.
func save_dressing() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TM_OUT))
	_pair("store_tent", canvas_hall(118, 64, "STORE  GRILL", 1924))
	_pair("lodge_tent", canvas_hall(96, 58, "TUOLUMNE LODGE", 1916))
	_tm_write(entrance_sign(), "entrance_sign")
	_tm_write(junction_sign(), "junction_sign")
	_tm_write(ice_chest(), "ice_chest")
	_tm_write(porch_bench(), "porch_bench")
	_tm_write(firewood_rack(), "firewood_rack")
	_tm_write(gas_pump(), "gas_pump")
	_tm_write(woodpile(), "woodpile")
	_tm_write(lamp_post(), "lamp_post")


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
			if sheets and absf(fmod(v * 5.0 + vnoise(x * 0.03, y * 0.03, sd) * 0.3, 1.0) - 0.5) < 0.03:
				col = col.darkened(0.22)
			# water streaks down the steep, shaded faces
			if gx < -0.04 and vnoise(x * 0.5, y * 0.03, sd + 5) > 0.66:
				col = col.lerp(STAIN, 0.45)
			if K.hash2(x, y, sd + 7) < 0.003:
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
func dome(w: int, h: int, sd: int, left: float, right: float, plucked: float, peak := 0.45, east := 2.0) -> Image:
	var im := K.make(w, h)
	K.shadow(im, w / 2.0 + 6.0, h - 3.0, w / 2.0 - 8.0, 4.0, 0.3)
	var hts := PackedFloat32Array()
	hts.resize(w * h)
	var cx := w * peak
	for y in h:
		for x in w:
			var rx := (cx * left) if x < cx else ((w - cx) * right * 0.62)
			var dx := (x + 0.5 - cx) / maxf(rx, 1.0)
			var up := float(h - 4 - y) / (h - 6.0)
			var top := 1.0 - pow(absf(dx), east)
			if x < cx:
				top = 1.0 - pow(absf(dx), 1.0 + plucked * 2.0)
			top += (vnoise(x * 0.06, 0.0, sd) - 0.5) * 0.04
			if up < 0.0 or up > top or y > h - 4 - int(vnoise(x * 0.07, 3.0, sd) * 9.0):
				continue
			hts[y * w + x] = sqrt(maxf(0.0, top - up)) * 0.9 + 0.1 * (1.0 - absf(dx))
	_granite(im, hts, w, h, sd, true, w / 18)
	# a little rubble along the foot, more under the plucked face
	var owner := PackedInt32Array()
	owner.resize(w * h)
	for i in w * h:
		owner[i] = 0 if hts[i] > 0.0 else -1
	_talus(im, owner, w, h, 12, sd + 1, 0.35, cx)
	FloraArt.rim(im, 0.5)
	return im


## Cathedral Peak as it stands over the meadows from the north: a great
## steep pyramid of jointed granite, faceted by the frost into flat faces
## (lit on the west, shaded on the east), with the slender summit spire on
## top, Eichorn Pinnacle standing off its west shoulder, lesser towers on
## the east ridge, vertical cracks and ledges across the faces, and snow
## lingering in the shaded gullies into summer.
func cathedral_peak() -> Image:
	var w := 260
	var h := 300
	var sd := 1869
	var im := K.make(w, h)
	K.shadow(im, w / 2.0 + 6.0, h - 3.0, w / 2.0 - 10.0, 4.0, 0.3)
	var tone := FloraArt.ramp(FloraArt.ROCK_TONE)
	var foot := float(h - 6)
	# [apex x, apex y, half-width at the foot, west ridge, east ridge, width
	# at the top, flare], back to front: each a tower of three faces split
	# by two ridges running down from the top (fractions of the half-width
	# at the foot). A blocky top and a high flare make a column; a pointed
	# top and a low flare, a pyramid.
	var towers := [
		[186.0, 96.0, 74.0, 0.3, 0.45, 0.06, 1.0],   # the east ridge's towers
		[208.0, 128.0, 52.0, 0.35, 0.4, 0.1, 1.1],
		[86.0, 64.0, 24.0, 0.2, 0.3, 0.26, 2.4],     # Eichorn Pinnacle
		[128.0, 4.0, 32.0, 0.25, 0.32, 0.3, 2.2],    # the summit block
		[124.0, 66.0, 124.0, 0.3, 0.42, 0.04, 0.95], # the main pyramid
		[58.0, 150.0, 60.0, 0.4, 0.4, 0.08, 1.0],    # the west buttress
	]
	# which tower owns each pixel, and how it is lit (0 dark .. 1 lit)
	var lit := PackedFloat32Array()
	lit.resize(w * h)
	lit.fill(-1.0)
	var owner := PackedInt32Array()
	owner.resize(w * h)
	owner.fill(-1)
	var fy := PackedFloat32Array()
	fy.resize(w * h)
	for ti in towers.size():
		var tw: Array = towers[ti]
		var ax: float = tw[0]
		var ay: float = tw[1]
		var hw: float = tw[2]
		for y in range(int(ay), h):
			var f := (y - ay) / (foot - ay)
			if f > 1.0:
				break
			# a steep, slightly concave profile: the faces flare at the foot
			var half := hw * (float(tw[5]) + (1.0 - float(tw[5])) * pow(f, float(tw[6])))
			# the top comes to a blunt, broken point, not a flat cap
			var cap := 0.07 * (1.0 + float(tw[5]) * 3.0)
			half *= sqrt(clampf(f / cap, 0.04, 1.0))
			var jag := (vnoise(float(y) * 0.18, float(ti) * 7.0, sd) - 0.5) * 6.0 * f
			var west := ax - half + jag
			var east := ax + half + (vnoise(float(y) * 0.18, float(ti) * 7.0 + 3.0, sd) - 0.5) * 6.0 * f
			if y > int(foot) - 4:
				continue
			var rl := ax - half * float(tw[3]) + (vnoise(float(y) * 0.05, float(ti), sd + 3) - 0.5) * 4.0
			var rr := ax + half * float(tw[4]) + (vnoise(float(y) * 0.05, float(ti) + 9.0, sd + 4) - 0.5) * 4.0
			for x in range(maxi(0, int(west)), mini(w, int(east) + 1)):
				var v := 0.0
				if x < rl:
					v = 0.8 + (rl - x) / maxf(1.0, rl - west) * 0.12
				elif x <= rr:
					v = 0.52 - (x - rl) / maxf(1.0, rr - rl) * 0.08
				else:
					v = 0.26 - (x - rr) / maxf(1.0, east - rr) * 0.08
				# nearer the foot the faces are broken into blocks and ledges
				v -= f * 0.06
				lit[y * w + x] = v
				owner[y * w + x] = ti
				fy[y * w + x] = f
	# the foot is ragged: the rock gives way to its talus at an uneven line
	for x in w:
		var ragged := int(foot) - 4 - int(vnoise(x * 0.09, 5.0, sd) * 22.0 + K.hash2(x / 3, 1, sd) * 4.0)
		for y in range(ragged, h):
			lit[y * w + x] = -1.0
	for y in h:
		for x in w:
			var i := y * w + x
			var v := lit[i]
			if v < 0.0:
				continue
			var f := fy[i]
			# vertical joints: long cracks at uneven spacing that wander a
			# little and break off, as the granite splits into columns
			var cx_ := float(x) + (vnoise(float(y) * 0.06, float(o_seed(x)), sd + 1) - 0.5) * 3.0
			var joint := vnoise(cx_ * 0.45, float(y) * 0.012, sd + 12)
			if absf(joint - 0.5) < 0.035 and vnoise(cx_ * 0.2, float(y) * 0.05, sd + 13) > 0.38:
				v -= 0.2
			# ledges: short, irregular shelves lit on top, shaded below
			var lrow := y + int(K.hash2(x / 9, 0, sd + 2) * 13.0)
			var ledge := K.hash2(x / 9, lrow / 13, sd + 2)
			if lrow % 13 == 0 and ledge > 0.78:
				v += 0.18
			elif lrow % 13 == 1 and ledge > 0.78:
				v -= 0.2
			# block texture, in small clusters
			v += (vnoise(x * 0.3, y * 0.3, sd + 6) - 0.5) * 0.12
			# a different tower in front of this one: a dark seam along its edge
			var o := owner[i]
			if x > 0 and owner[i - 1] != o and owner[i - 1] >= 0:
				v -= 0.25
			var col := FloraArt.shade(tone, clampf(v, 0.0, 1.0), x, y)
			# black water streaks and orange oxide down the shaded faces
			if v < 0.35 and vnoise(x * 0.4, y * 0.02, sd + 5) > 0.68:
				col = col.lerp(STAIN, 0.4)
			elif v > 0.6 and vnoise(x * 0.3, y * 0.05, sd + 8) > 0.74:
				col = col.lerp(Color("b07a42"), 0.25)
			# snow lying on the ledges in the shaded gullies, high up
			if f < 0.45 and v < 0.42 and v > 0.18 and vnoise(x * 0.09, y * 0.2, sd + 9) > 0.7:
				col = Color("eef4f8") if (y % 9 > 2 or v > 0.3) else Color("b4c4d0")
			if K.hash2(x, y, sd + 7) < 0.0015:
				col = LICHEN
			K.px(im, x, y, col)
	# a few whitebarks and lodgepoles on the lower ledges
	var green := FloraArt.ramp(["152a20", "1e3a28", "2a4c30", "3a6038", "4e7642"])
	for i in 18:
		var x := int(20 + K.hash2(i, 1, sd) * (w - 40))
		var y := int(h * 0.72 + K.hash2(i, 2, sd) * h * 0.22)
		if y >= h or lit[y * w + x] < 0.0:
			continue
		var tall := 5 + int(K.hash2(i, 3, sd) * 5.0)
		for k in tall:
			var half := int(k * 0.45)
			K.hline(im, x - half, y - tall + k, half * 2 + 1, green[clampi(1 + (k % 3) - (1 if k > tall - 3 else 0), 0, 4)])
		K.vline(im, x, y, 2, Color("4a3a2e"))
	_talus(im, owner, w, h, 34, sd + 1)
	FloraArt.rim(im, 0.5)
	return im


## A cone of fallen blocks at the foot of a peak: big blocks scattered thin
## near the rock, smaller ones spilling out over the ground below, each lit
## from the upper left, the band [param depth] px deep. Only under columns
## where [param owner] has rock.
func _talus(im: Image, owner: PackedInt32Array, w: int, h: int, depth: int, sd: int, density := 1.1, steep_until := -1.0) -> void:
	var tone := FloraArt.ramp(FloraArt.ROCK_TONE)
	var cols := []
	for x in w:
		for y in range(0, h - depth):
			if owner[y * w + x] >= 0:
				cols.append(x)
				break
	if cols.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var blocks: Array[Vector3] = []
	for i in int(cols.size() * density):
		var x: float = float(cols[rng.randi() % cols.size()]) + rng.randf_range(-3.0, 3.0)
		# more rubble under a steep face (left of [param steep_until])
		if x > steep_until and steep_until > 0.0 and rng.randf() < 0.5:
			continue
		var t := pow(rng.randf(), 0.8)
		var y := float(h - 4 - depth) + t * depth
		var r := lerpf(4.5, 1.5, t) * rng.randf_range(0.6, 1.2)
		blocks.append(Vector3(x, y, r))
	blocks.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	for bi in blocks.size():
		var bk := blocks[bi]
		for y in range(int(bk.y - bk.z), int(bk.y + bk.z * 0.7) + 1):
			for x in range(int(bk.x - bk.z), int(bk.x + bk.z) + 1):
				if x < 0 or x >= w or y < 0 or y >= h - 3:
					continue
				var dx := (x + 0.5 - bk.x) / bk.z
				var dy := (y + 0.5 - bk.y) / (bk.z * 0.75)
				# angular blocks: a diamond-rounded outline, not a circle
				if absf(dx) * 0.6 + dx * dx * 0.4 + absf(dy) * 0.6 + dy * dy * 0.4 > 1.0:
					continue
				var tt := 0.3 + K.hash2(bi, 7, sd) * 0.2 - dx * 0.26 - dy * 0.3 + (K.hash2(x / 2, y / 2, sd + bi) - 0.5) * 0.1
				K.px(im, x, y, FloraArt.shade(tone, clampf(tt, 0.0, 1.0), x, y))


static func o_seed(x: int) -> int:
	return x / 6


## Lembert Dome from the meadow, a roche moutonnée: the glacier rode over
## it from the east, smoothing the long, gentle slope on the right into
## polished slabs, and plucked the downstream west end into the steep face
## on the left, under the summit.
func lembert_dome() -> Image:
	var w := 400
	var h := 230
	var sd := 1911
	var im := dome(w, h, sd, 0.86, 1.62, 1.1, 0.3, 1.35)
	# glacial polish: patches on the gentle slope that catch the sun
	for i in 10:
		var px_ := int(w * 0.38 + K.hash2(i, 1, sd) * w * 0.5)
		var py_ := int(h * 0.4 + K.hash2(i, 2, sd) * h * 0.45)
		for yy in range(py_ - 3, py_ + 4):
			for xx in range(px_ - 10, px_ + 11):
				if xx < 0 or yy < 0 or xx >= w or yy >= h or im.get_pixel(xx, yy).a < 0.5:
					continue
				var d := pow((xx - px_) / 10.0, 2.0) + pow((yy - py_) / 3.5, 2.0)
				if d < 1.0 and K.hash2(xx / 2, yy, sd + i) > d * 0.9:
					K.px(im, xx, yy, im.get_pixel(xx, yy).lightened(0.1))
	return im


# ---------------------------------------------------------------- buildings and props

## A long canvas tent on a wooden frame, like the Tuolumne Meadows store and
## grill and the lodge's dining tent: low board walls under a canvas valance,
## a weathered cream canvas roof sagging between its rafters (each bay lit on
## the side that faces the upper-left light), sewn seams, rain stains, a
## ridge pole, a tin stovepipe, a plank deck along the front and a sign.
## Returns [sprite, glow].
func canvas_hall(w: int, h: int, label: String, sd: int) -> Array:
	windows.clear()
	glass_snap = null
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 1.0, 2.6, 0.3)
	var canvas := _ramp(["5e584a", "7e7764", "a09880", "c0b79c", "d8d0b4", "ebe4cc", "f8f4e4"])
	var stain := Color("6e5e44")
	var wall_top := int(h * 0.56)
	board_wall(im, 1, wall_top, w - 2, h - wall_top - 3, sd, 3)
	# the roof: canvas between rafters, each bay sagging, a ridge pole
	var bay_w := 12
	var top := 3
	for yy in range(top, wall_top):
		var t := float(yy - top) / (wall_top - top)
		var inset := int((1.0 - t) * 6.0)
		for xx in range(inset, w - inset):
			var u := float(xx % bay_w) / bay_w
			# the sag deepens toward the eave, where the canvas hangs freest
			var sag := 0.16 + t * 0.16
			var lv := 0.74 - t * 0.3 - cos(u * PI) * sag - float(xx) / w * 0.1
			lv += (K.hash2(xx / 3, yy / 2, sd) - 0.5) * 0.06
			# sewn seams across the canvas
			if (yy - top) % 7 == 6:
				lv -= 0.08
			var col := FloraArt.shade(canvas, clampf(lv, 0.0, 1.0), xx, yy)
			if xx % bay_w == 0:
				# the rafter under the canvas: a lit crest with shade beside it
				col = canvas[mini(6, roundi(lv * 6.0) + 1)]
			elif xx % bay_w == 1:
				col = canvas[clampi(roundi(lv * 6.0) - 1, 0, 6)]
			# rain stains run down the bottoms of the bays toward the eave
			var streak := K.hash2(xx, sd, 41)
			if t > 0.45 and streak < 0.18 and u > 0.25 and u < 0.75 and K.hash2(xx, yy / 3, sd + 9) < (t - 0.4) * 1.4:
				col = col.lerp(stain, 0.22)
			K.px(im, xx, yy, col)
	# the ridge pole
	K.hline(im, 6, top, w - 12, canvas[6])
	K.hline(im, 6, top + 1, w - 12, canvas[3])
	K.hline(im, 6, top + 2, w - 12, canvas[2])
	# the valance: canvas hanging over the wall top in shallow scallops
	var val := wall_top - 1
	for xx in range(0, w):
		var u := float(xx % bay_w) / bay_w
		var drop := 2 + roundi(sin(u * PI) * 1.6)
		for d in drop:
			var idx := 5 if d == 0 else (4 if d < drop - 1 else 2)
			K.px(im, xx, val + d, canvas[idx])
		# a dark green hem along the bottom of the valance
		K.px(im, xx, val + drop, Color("3a5a40"))
		K.px(im, xx, val + drop + 1, Color("24382a"))
	shade(im, 1, val + 4, w - 2, 6, Color("1e1834"), 1.0, 0.0, 0.45)
	for wx in range(12, w - 10, 18):
		if absi(wx - w / 2) < 10:
			continue
		_vb_window(im, wx, wall_top + 5, 7, mini(8, h - wall_top - 11), K.hash2(wx, sd, 5) < 0.6, sd + wx)
	# a plank deck along the front, with a step up to the door
	var deck_y := h - 5
	for xx in range(2, w - 2):
		K.px(im, xx, deck_y, timber[4] if (xx % 9) else timber[3])
		K.px(im, xx, deck_y + 1, timber[2])
		K.px(im, xx, deck_y + 2, timber[0])
	plank_door(im, w / 2, deck_y, mini(14, h - wall_top - 6), sd + 500, 10)
	K.rect(im, w / 2 - 6, deck_y + 1, 12, 2, timber[3])
	K.hline(im, w / 2 - 6, deck_y + 1, 12, timber[5])
	# a lamp each side of the door
	K.lantern(im, w / 2 - 9, wall_top + 5)
	K.lantern(im, w / 2 + 9, wall_top + 5)
	_stovepipe(im, int(w * 0.78), 0, 12)
	sign_board(im, w / 2, wall_top - 11, label)
	K.outline(im, Color("2a2420"))
	var glow := _glow_image(im, w, h)
	return [im, glow]


## A tin stovepipe through the canvas: a thin pipe lit on its left, a
## coolie-hat cap on top and a scorched collar where it leaves the roof.
func _stovepipe(im: Image, x: int, top: int, h: int) -> void:
	for yy in range(top + 2, top + h):
		K.px(im, x - 1, yy, iron[3])
		K.px(im, x, yy, iron[2])
		K.px(im, x + 1, yy, iron[1])
	K.hline(im, x - 3, top, 7, iron[2])
	K.hline(im, x - 2, top, 5, iron[3])
	K.hline(im, x - 2, top + 1, 5, iron[0])
	K.rect(im, x - 2, top + h - 1, 5, 2, Color("5a4a3a"))
	K.hline(im, x - 2, top + h - 1, 5, Color("8a7a62"))


# ---------------------------------------------------------------- props

## A routed park sign in brown-stained wood, cream letters cut in, on two
## peeled-log posts set in a mortared granite footing: the welcome at the
## meadow's west end.
func entrance_sign() -> Image:
	var w := 74
	var h := 32
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 2.0, 2.0, 0.3)
	# the footing
	stone_wall(im, 4, h - 9, w - 8, 6, 1961, 0.5, 3, 2, false)
	K.hline(im, 4, h - 9, w - 8, granite[5])
	# the posts
	for px_ in [9, w - 12]:
		post(im, px_, 4, h - 13, 1962 + px_, 3)
		K.hline(im, px_, 3, 3, timber[4])
	# the board
	var bx := 3
	var by := 6
	var bw := w - 6
	var bh := 13
	for yy in bh:
		for xx in bw:
			var t := 0.42 + (K.hash2(xx / 4, yy, 1963) - 0.5) * 0.12 - float(xx) / bw * 0.1 + (0.5 - float(yy) / bh) * 0.12
			K.px(im, bx + xx, by + yy, timber[clampi(roundi(t * 5.0), 0, 5)])
	K.hline(im, bx, by, bw, timber[4])
	K.hline(im, bx, by + bh - 1, bw, timber[0])
	K.vline(im, bx, by, bh, timber[3])
	K.vline(im, bx + bw - 1, by, bh, timber[0])
	var cream := Color("ecdcb2")
	var cut := Color("2c1b12")
	K.text_centered(im, bx, bw, by + 2, "TUOLUMNE MEADOWS", cream, cut)
	K.text_centered(im, bx, bw, by + 8, "ELEV 8600 FT", Color("d0bc8c"), cut)
	K.outline(im, Color("231a16"))
	return im


## A trail junction post: a squared post with routed boards pointing the
## ways, the John Muir and Pacific Crest trails sharing Lyell Canyon south.
func junction_sign() -> Image:
	var w := 92
	var h := 36
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, 6.0, 1.6, 0.3)
	post(im, w / 2 - 1, 4, h - 6, 1964, 3)
	K.hline(im, w / 2 - 1, 3, 3, timber[4])
	var boards := [["JMT  PCT", 6, -1], ["LYELL CYN", 13, -1], ["DOG LAKE", 20, 1]]
	for b: Array in boards:
		var label: String = b[0]
		var y: int = b[1]
		var dir: int = b[2]
		var bw := K.text_width(label) + 6
		var x := w / 2 - bw + 3 if dir < 0 else w / 2 - 2
		K.rect(im, x, y, bw, 7, timber[2])
		K.hline(im, x, y, bw, timber[4])
		K.hline(im, x, y + 6, bw, timber[0])
		# the pointed end
		var tip := x - 1 if dir < 0 else x + bw
		K.vline(im, tip, y + 1, 5, timber[2])
		K.vline(im, tip + dir, y + 2, 3, timber[2])
		K.px(im, tip + dir * 2, y + 3, timber[1])
		K.text(im, x + 3, y + 1, label, Color("ecdcb2"), timber[0])
	K.outline(im, Color("231a16"))
	return im


## The store's ice chest out front: a white chest freezer with ICE on its
## lid-front in blue, a steel lid and a padlock hasp.
func ice_chest() -> Image:
	var im := K.make(28, 20)
	K.shadow(im, 14, 18.5, 13, 1.6, 0.3)
	var white := _ramp(["7e8a94", "a6b0b8", "c8d0d4", "e2e8ea", "f4f8f8"])
	for yy in 14:
		for xx in 26:
			var t := 0.75 - float(xx) / 26.0 * 0.3 + (0.5 - float(yy) / 14.0) * 0.1
			K.px(im, 1 + xx, 3 + yy, white[clampi(roundi(t * 4.0), 0, 4)])
	# the lid
	K.rect(im, 1, 2, 26, 4, white[3])
	K.hline(im, 1, 2, 26, white[4])
	K.hline(im, 1, 5, 26, white[0])
	K.rect(im, 12, 6, 4, 2, iron[2])
	# ICE in blue with a frosty shadow
	K.text_centered(im, 1, 26, 9, "ICE", Color("2a5aa8"), Color("8ab0d8"))
	# the base and a drip of meltwater
	K.hline(im, 1, 16, 26, white[0])
	K.px(im, 22, 17, Color("8ab0d8"))
	K.outline(im, Color("2a2a30"))
	return im


## A plank porch bench, worn pale where people sit.
func porch_bench() -> Image:
	var im := K.make(30, 16)
	K.shadow(im, 15, 14.5, 14, 1.4, 0.3)
	# the back: two rails on short posts
	for yy in [1, 4]:
		K.hline(im, 2, yy, 26, timber[4])
		K.hline(im, 2, yy + 1, 26, timber[2])
	for lx in [3, 26]:
		K.vline(im, lx, 1, 13, timber[1])
	# the seat, worn pale in the middle
	K.hline(im, 1, 8, 28, timber[5])
	K.hline(im, 1, 9, 28, timber[4])
	K.hline(im, 6, 8, 18, Color("c89a66"))
	K.hline(im, 1, 10, 28, timber[1])
	for lx in [3, 26]:
		K.vline(im, lx, 11, 3, timber[0])
	K.outline(im, Color("231a16"))
	return im


## A rack of firewood bundles for the campers: split lodgepole tied in
## twine, stacked under a small FIREWOOD board.
func firewood_rack() -> Image:
	var im := K.make(38, 26)
	K.shadow(im, 19, 24.5, 18, 1.6, 0.3)
	# the frame
	post(im, 1, 4, 20, 1971, 2)
	post(im, 35, 4, 20, 1972, 2)
	K.rect(im, 1, 22, 36, 2, timber[1])
	# bundles: rows of split ends
	for row in 3:
		for b in 4:
			var bx := 4 + b * 8
			var by := 10 + row * 4
			for k in 6:
				var ex := bx + (k % 3) * 2
				var ey := by + (k / 3) * 2
				K.px(im, ex, ey, Color("c8a272") if K.hash2(ex, ey, 7) > 0.3 else Color("a8845a"))
				K.px(im, ex + 1, ey, Color("8a6440"))
				K.px(im, ex, ey + 1, Color("6a4a2e"))
			K.vline(im, bx + 3, by, 4, Color("d8c890"))
	# the board
	K.rect(im, 1, 2, 36, 7, timber[2])
	K.hline(im, 1, 2, 36, timber[4])
	K.hline(im, 1, 8, 36, timber[0])
	K.text_centered(im, 1, 36, 3, "FIREWOOD", Color("ecdcb2"), timber[0])
	K.outline(im, Color("231a16"))
	return im


## An old gas pump like the one that stood by the store: a round-shouldered
## red pump with a white globe, a dial face and the hose on its hook.
func gas_pump() -> Image:
	var im := K.make(16, 34)
	K.shadow(im, 8, 32.5, 7, 1.4, 0.3)
	var red := _ramp(["4a1414", "6e1e1c", "962a24", "b83a2e", "d65a44"])
	for yy in range(8, 30):
		for xx in range(2, 13):
			var t := 0.7 - float(xx - 2) / 11.0 * 0.5
			K.px(im, xx, yy, red[clampi(roundi(t * 4.0), 0, 4)])
	# the globe
	K.ellipse(im, 7.5, 4.5, 3.6, 3.6, Color("e8e4d8"))
	K.px(im, 6, 3, Color("ffffff"))
	K.hline(im, 5, 5, 6, red[3])
	K.rect(im, 6, 7, 4, 2, iron[2])
	# the dial face
	K.rect(im, 4, 11, 7, 6, Color("efe6c8"))
	K.hline(im, 4, 11, 7, Color("fff8e0"))
	K.hline(im, 5, 13, 5, iron[1])
	K.hline(im, 5, 15, 3, iron[1])
	# the hose
	K.vline(im, 13, 14, 10, iron[0])
	K.px(im, 14, 14, iron[1])
	K.px(im, 14, 15, iron[2])
	K.rect(im, 1, 29, 13, 2, granite[3])
	K.hline(im, 1, 29, 13, granite[5])
	K.outline(im, Color("231a16"))
	return im


## The lodge's woodpile for the tent-cabin stoves: lodgepole rounds stacked
## end-out between two stakes, a chopping block with the axe left in it.
func woodpile() -> Image:
	var im := K.make(40, 22)
	K.shadow(im, 20, 20.5, 19, 1.8, 0.3)
	for row in 3:
		var n := 6 - row
		for k in n:
			var cx := 5.0 + k * 5.2 + row * 2.6
			var cy := 17.0 - row * 4.6
			K.ellipse(im, cx, cy, 2.6, 2.4, Color("6a4a2e"))
			K.ellipse(im, cx - 0.4, cy - 0.3, 1.8, 1.6, Color("c8a272"))
			K.px(im, int(cx), int(cy), Color("a07c52"))
	K.vline(im, 1, 6, 14, timber[1])
	K.vline(im, 32, 6, 14, timber[1])
	# chopping block and axe
	K.rect(im, 34, 14, 5, 5, Color("7a5434"))
	K.hline(im, 34, 14, 5, Color("c8a272"))
	K.vline(im, 36, 7, 7, Color("b08a5a"))
	K.rect(im, 35, 12, 3, 2, iron[2])
	K.px(im, 35, 12, iron[3])
	K.outline(im, Color("231a16"))
	return im


## A lantern on a peeled-log post, lighting the lodge path after dark.
func lamp_post() -> Image:
	var im := K.make(14, 36)
	K.shadow(im, 5, 34.5, 4, 1.2, 0.3)
	post(im, 3, 3, 31, 1981, 3)
	K.hline(im, 4, 4, 8, iron[2])
	K.hline(im, 4, 5, 8, iron[0])
	K.vline(im, 10, 6, 2, iron[1])
	K.lantern(im, 10, 8)
	K.outline(im, Color("231a16"))
	return im


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


## The road bridge on the spur to the Lembert Dome lot, seen from above: an
## asphalt deck between two parapets of dressed granite blocks capped in
## concrete, like the Tioga Road's old stone bridges, throwing a shadow on
## the water to the east. Lies flat over the river, stretched to its banks.
func road_bridge() -> Image:
	var w := ROAD_BRIDGE.x
	var h := ROAD_BRIDGE.y
	var im := K.make(w, h)
	var stone := FloraArt.ramp(["30343f", "484d5a", "6a6a70", "93918f", "bdb8ae", "e4ddcc"])
	# the shadow on the water east of the bridge
	for yy in h:
		for xx in range(w - 5, w):
			K.px(im, xx, yy, Color(0.04, 0.08, 0.14, 0.45 - (xx - (w - 5)) * 0.07))
	# the deck: worn asphalt with grit
	for yy in h:
		for xx in range(6, w - 11):
			var col := Color("47464d") if K.hash2(xx / 2, yy / 2, 31) > 0.12 else Color("6a6a70")
			if K.hash2(xx, yy, 32) < 0.03:
				col = Color("2b2a30")
			K.px(im, xx, yy, col)
	# the parapets: a course of granite blocks with a concrete cap
	for side: int in [0, w - 11]:
		for yy in h:
			var block := (yy + (2 if side > 0 else 0)) / 5
			var lit := K.hash2(block, side, 33)
			for xx in range(side, side + 6):
				var u := xx - side
				var col := stone[3] if lit < 0.5 else stone[4]
				if (yy + (2 if side > 0 else 0)) % 5 == 0:
					col = stone[1]
				if u == 0:
					col = stone[5] if side == 0 else stone[4]
				elif u == 5:
					col = stone[1]
				elif u >= 2 and u <= 3:
					# the concrete cap along the top of the wall
					col = stone[5] if u == 2 else stone[4]
				K.px(im, xx, yy, col)
		# the parapet's shadow on the deck
		if side == 0:
			K.vline(im, 6, 0, h, Color("2b2a30"))
	# a white edge line on the deck
	for yy in h:
		if (yy / 6) % 4 != 3:
			K.px(im, 8, yy, Color("bdb8ae"))
			K.px(im, w - 14, yy, Color("bdb8ae"))
	return im

