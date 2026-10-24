extends "res://tools/hubs/ahwahnee_ground.gd"
## The ground of Tuolumne Meadows, painted as the high country really looks
## in midsummer at 8,600 feet, on top of the Ahwahnee ground painter:
##
## - The meadow is sedge, not lawn: a muted, deep green turf of fine blades,
##   swelling into hummocks, with tawny drifts where it dries first, sparse
##   flowers (shooting stars, lupine, buttercups, yampah) and the odd
##   Belding's ground squirrel burrow.
## - The wet meadow is darker and bluer, with small pools of snowmelt
##   standing in it.
## - The lodgepole forest floor is pale granite sand (grus), drifted with
##   rusty needle duff, cones and grey twigs, with sedge only in the hollows.
## - The Tuolumne is clear: over a bed of granite cobbles in the shallows,
##   teal in the runs and dark in the pools, with current lines on the
##   surface, and banks of sod cut by the river rather than beaches of sand.
##   Its bars are cobble and gravel.
## - The Tioga Road is asphalt with a double yellow line and white edges.
##
## Every color is one of the Valley Days palette's (tools/art32/palette.py),
## so the 32px pass keeps them as painted, and no texture is a one-pixel
## checker: the 32px pass's Scale2x turns those into little diamond glyphs.

# The palette's ramps, by name, dark to light.
const G0 := Color("2b2a30")
const G1 := Color("47464d")
const G2 := Color("6a6a70")
const G3 := Color("93918f")
const G4 := Color("bdb8ae")
const G5 := Color("e4ddcc")
const T1 := Color("86694b")
const T2 := Color("b0925f")
const T3 := Color("d6bd88")
const P1 := Color("1d3f2b")
const P2 := Color("2c5c37")
const P3 := Color("437f45")
const M0 := Color("5c8f3c")
const M1 := Color("84b04a")
const O1 := Color("ad7a22")
const O2 := Color("d8a63b")
const O3 := Color("f1cf6a")
const B0 := Color("2a1b14")
const B1 := Color("47301f")
const B2 := Color("6b4829")
const W0 := Color("142f47")
const W1 := Color("235679")
const W2 := Color("3a86a8")
const W3 := Color("63b3c6")
const W4 := Color("9fd8d9")
const W5 := Color("d6f1ee")
const LUPINE := Color("6f5aa6")
const SHOOTING_STAR := Color("d47a9b")
const WHITE_FLOWER := Color("f5eee0")


## A threshold test with its edge broken into 2x2 clusters, so a boundary
## between two tones is ragged rather than ruled or checkered.
func _over(v: float, thr: float, x: int, y: int, s: int, spread := 0.07) -> bool:
	return v > thr + (hash2(x >> 1, y >> 1, s) - 0.5) * spread


## Offset from a cell's anchor and the cell's hash, like _nat_jit, but the
## anchor may sit anywhere in its cell, so small cells don't fall into a
## visible lattice (a mark reaching past its cell is clipped there).
func _jit(x: int, y: int, cs: int, s: int) -> Vector3:
	var gx := x / cs
	var gy := y / cs
	var ax := gx * cs + int(hash2(gx, gy, s) * float(cs))
	var ay := gy * cs + int(hash2(gx, gy, s + 1) * float(cs))
	return Vector3(float(x - ax), float(y - ay), hash2(gx, gy, s + 2))


## Per tile, how much meadow is round it (blurred), so the forest floor
## turns grassy as it nears the meadow instead of stopping at a line.
var _mead_f := PackedFloat32Array()


func _color(k: int, x: int, y: int, i: int, tx: int, ty: int) -> Color:
	if _mead_f.size() != w * h:
		var f := PackedFloat32Array()
		f.resize(w * h)
		for t in w * h:
			f[t] = 1.0 if kind[t] == Terrain.MEADOW or kind[t] == Terrain.WET_MEADOW else 0.0
		_mead_f = _path_blur(_path_blur(_path_blur(f)))
	var a := float(_na[i]) / 255.0
	var b := float(_nb[i]) / 255.0
	var n := float(_nc[i]) / 255.0
	match k:
		Terrain.SUBALPINE:
			return _grus(x, y, a, b, n, false)
		Terrain.CAMP:
			return _grus(x, y, a, b, n, true)
		Terrain.MEADOW:
			return _sedge(x, y, a, b, n, false)
		Terrain.WET_MEADOW:
			return _sedge(x, y, a, b, n, true)
		Terrain.TRAIL:
			return _sand_trail(x, y, a, b, n)
		Terrain.SAND:
			return _cobble_bar(x, y, a, b, n)
		Terrain.ROAD:
			return _tioga(x, y, a, b, n)
		Terrain.PARKING:
			return _lot_asphalt(x, y, a, b, n)
		Terrain.RIVER, Terrain.LAKE:
			return _clear_water(k, x, y, i, a, b, n)
	return super._color(k, x, y, i, tx, ty)


# ---------------------------------------------------------------- the forest floor

## The lodgepole forest's floor: pale grey grus with warm patches, rusty
## needle duff drifted in the low field, cones, grey twigs and pebbles, and
## sedge only in the hollows. Trampled (a campsite, the trodden rise at
## Soda Springs) it is barer and packed, with no sedge.
func _grus(x: int, y: int, a: float, b: float, n: float, trampled: bool) -> Color:
	# the sand itself: grey and buff grains mixed in small clusters, a
	# little warmer where the large field runs high
	var warm := 0.12 + smooth(0.3, 0.7, a * 0.7 + n * 0.3) * 0.76
	var col := T3 if hash2(x >> 1, y >> 1, 500) < warm else G4
	# needle duff in soft drifts: scattered needles thickening into a mat
	var duff := b * 0.7 + a * 0.3
	var thr := 0.62 if trampled else 0.55
	var needle := _jit(x, y, 3, 511)
	var on_needle := needle.z < 0.85 and ((int(needle.x) == 0 and int(needle.y) == 0) or (int(needle.x) == 1 and int(needle.y) == (1 if needle.z < 0.4 else -1)))
	if _over(duff, thr + 0.14, x, y, 503, 0.1):
		col = T2 if not on_needle else (T1 if needle.z < 0.65 else B2)
	elif _over(duff, thr, x, y, 504, 0.12):
		if on_needle:
			col = T1 if needle.z < 0.45 else T2
		elif hash2(x >> 1, y >> 1, 508) < 0.5:
			col = T2
	elif _over(duff, thr - 0.1, x, y, 505, 0.12) and on_needle and needle.z < 0.35:
		col = T2
	elif trampled and _over(n, 0.66, x, y, 506) and hash2(x >> 1, y >> 1, 507) < 0.5:
		col = T2
	# near the meadow the sedge and grass reach in under the trees
	var mead := _path_sample(_mead_f, x, y) if not _mead_f.is_empty() else 0.0
	# sedge and grass in the hollows of the low field
	var grassy := 0.0 if trampled else maxf(smooth(0.3, 0.12, a), smooth(0.02, 0.35, mead))
	if grassy > 0.0:
		var t := _jit(x, y, 3, 521)
		if t.z < grassy * 0.8:
			var dx := int(t.x)
			var dy := int(t.y)
			var dry := hash2(x / 4, y / 4, 522) < 0.4
			if dx == 0 and dy == 0:
				col = P2
			elif dx == 0 and dy == -1:
				col = (O2 if dry else M0) if t.z < grassy * 0.35 else P3
			elif absi(dx) == 1 and dy == 0:
				col = P3 if not dry else O1
	# granite grit: a quartz glint with its shadow, now and then
	var g := _jit(x, y, 6, 531)
	if g.z < 0.22:
		if int(g.x) == 0 and int(g.y) == 0:
			col = G5
		elif int(g.x) == 1 and int(g.y) == 1:
			col = G3
	# cones: a little brown oval with a shadow
	var cn := _jit(x, y, 14, 541)
	if cn.z < (0.08 if trampled else 0.16):
		var dx := int(cn.x)
		var dy := int(cn.y)
		if dy == 0 and (dx == 0 or dx == 1):
			col = T1 if dx == 0 else B2
		elif dy == 1 and dx >= 0 and dx <= 2:
			col = B1
	# weathered grey twigs
	var tw := _jit(x, y, 13, 551)
	if tw.z < 0.14:
		var dx := int(tw.x)
		var dy := int(tw.y)
		var slope := -1 if tw.z < 0.07 else 1
		if dx >= -2 and dx <= 2 and dy == (dx * slope) / 2:
			col = G3 if dx < 1 else G2
	return col


## The trails here are sandy grus, worn paler than the forest floor, with
## a darker tread line and pebbles.
func _sand_trail(x: int, y: int, a: float, b: float, n: float) -> Color:
	var col := T3
	if not _over(b * 0.6 + n * 0.4, 0.34, x, y, 561):
		col = T2
	var p := _jit(x, y, 7, 571)
	if p.z < 0.2:
		if int(p.x) == 0 and int(p.y) == 0:
			col = G5
		elif int(p.x) == 0 and int(p.y) == 1:
			col = G3
	return col


# ---------------------------------------------------------------- the meadow

## Sedge turf: a fine texture of short upright blades (a lit tip over a
## dark base), over broad hummocks lit from the upper left. Drier rises
## go tawny; the wet meadow is darker, bluer, with snowmelt pools.
func _sedge(x: int, y: int, a: float, b: float, n: float, wet: bool) -> Color:
	var v := a * 0.55 + b * 0.45
	# two turf tones only: the sedge, and the deeper green of the swales
	var base := M0
	var dark := P3
	var tip := M1
	if wet:
		base = P3
		dark = P2
		tip = M0
		if not _over(v, 0.42, x, y, 601):
			base = P2
			dark = P1
	elif not _over(v, 0.34, x, y, 602, 0.1):
		base = P3
		dark = P2
	# drier rises, where the sedge cures tawny first; elsewhere a share of
	# the blades are tawny anyway, so the green reads olive, not lawn
	var dry_f := float(_nf[y * _pw + x]) / 255.0 * 0.7 + b * 0.3
	var dry := not wet and _over(dry_f, 0.64, x, y, 605, 0.08)
	var col := base
	# blades: two-pixel strokes, lit tip above a dark root, densely set
	var bl := _jit(x, y, 3, 611)
	if bl.z < 0.62:
		var dx := int(bl.x)
		var dy := int(bl.y)
		var tawny := hash2(x / 3, y / 3, 612) < (0.55 if dry else (0.0 if wet else 0.22))
		if dx == 0 and dy == 0:
			col = dark if not tawny else (O1 if dry else dark)
		elif dx == 0 and dy == -1:
			col = (T2 if dry and bl.z < 0.3 else O2) if tawny else (tip if bl.z < 0.4 else base)
	# a second, sparser layer of taller seed heads
	var hd := _jit(x, y, 7, 621)
	if hd.z < (0.3 if dry else 0.1) and int(hd.x) == 0 and int(hd.y) >= -2 and int(hd.y) <= 0:
		col = (O1 if dry else P2) if int(hd.y) == 0 else (O3 if dry and int(hd.y) == -2 else (O2 if dry else tip))
	if wet:
		# small pools of snowmelt standing in the sedge, sky in them
		if _over(n * 0.6 + (1.0 - a) * 0.4, 0.74, x, y, 631, 0.04):
			col = W2
			if not _over(n * 0.6 + (1.0 - a) * 0.4, 0.78, x, y, 632, 0.04):
				col = P1
			elif hash2(x >> 1, y, 633) < 0.18:
				col = W4
		return col
	# flowers, in drifts: shooting stars, lupine, buttercups, yampah
	var fl := _nat_flower(x, y, 11, 641, 0.05)
	if fl.x != 0:
		var petal: Color = [SHOOTING_STAR, LUPINE, O3, WHITE_FLOWER][fl.y]
		col = petal if fl.x == 1 else (B2 if fl.y == 0 else petal)
	# a Belding's ground squirrel burrow, with its fan of dug-out sand
	var bu := _jit(x, y, 37, 651)
	if bu.z < 0.12:
		var dx := int(bu.x)
		var dy := int(bu.y)
		if dy == 0 and (dx == 0 or dx == 1):
			col = B0
		elif dy == -1 and (dx == 0 or dx == 1):
			col = B1
		elif dy == 1 and dx >= -1 and dx <= 2:
			col = T2
		elif dy == 2 and dx >= 0 and dx <= 1:
			col = T1
	return col


# ---------------------------------------------------------------- the river

## A gravel and cobble bar on the inside of a bend: rounded granite cobbles
## lit from the upper left, with coarse sand between.
func _cobble_bar(x: int, y: int, a: float, b: float, n: float) -> Color:
	var v := _nat_vor(x, y, 4, 701)
	if v.y < 0.9:
		return T2 if hash2(x >> 1, y >> 1, 702) < 0.6 else T3
	var lvl := clampi(int(v.z * 3.0 + v.x * 1.2), 0, 3)
	return [G2, G3, G4, G5][lvl]


## Clear snowmelt: the cobble bed shows in the shallows, teal in the runs,
## deep blue in the channel; current lines run along the river (west, across the
## map) and a sun glint sparkles now and then. Dog Lake is the same water,
## stiller.
func _clear_water(k: int, x: int, y: int, i: int, a: float, b: float, n: float) -> Color:
	var d := _pdep[i]
	var t := clampf((d - 0.5) / 1.5, 0.0, 1.0)
	# the river runs deep under a cut bank and shoals over a bar: look up
	# and down for the nearest shore and what lies on it
	if k == Terrain.RIVER and t < 0.5:
		for r in range(1, 14):
			var up := _pk[maxi(0, y - r) * _pw + x]
			var down := _pk[mini(_ph - 1, y + r) * _pw + x]
			if not _is_water(up) or not _is_water(down):
				var shore := up if not _is_water(up) else down
				if shore != Terrain.SAND:
					t = minf(1.0, t + 0.22)
				break
	var col := W2
	if t < 0.22:
		# the bed: cobbles under a skin of water
		var v := _nat_vor(x, y, 4, 711)
		col = W3
		if v.y < 0.9:
			col = W2
		elif v.z > 0.62:
			col = W4
	elif t < 0.5:
		col = W2
		var v := _nat_vor(x, y, 5, 712)
		if v.y > 1.2 and v.z > 0.7 and hash2(x >> 1, y >> 1, 713) < 0.5:
			col = W3
	else:
		col = W1
	# current lines: long thin streaks running with the river
	var still := k == Terrain.LAKE
	var cell := 23 if not still else 31
	var sx := (x + int(hash2(0, y / 3, 721) * 40.0)) / cell
	var sy := y / 3
	if y % 3 == 0 and hash2(sx, sy, 722) < (0.22 if not still else 0.08):
		var lx := (x + int(hash2(0, y / 3, 721) * 40.0)) % cell
		var length := 6 + int(hash2(sx, sy, 723) * 10.0)
		if lx < length:
			col = W3 if col == W1 or col == W0 else W4
	# sun glints
	var gl := _jit(x, y, 17, 731)
	if gl.z < 0.1 and int(gl.y) == 0 and (int(gl.x) == 0 or int(gl.x) == 1) and t > 0.2:
		col = W5
	return col


## The river's edges: where meadow meets water the river has cut the sod,
## so a north bank shows a face of dark earth above the water, and a south
## bank's turf hangs over it, throwing a dark line of shadow on the water.
## A gravel bar slopes in, with no edge at all.
func _shore_and_edges(im: Image) -> void:
	var edits := {}
	for y in range(3, _ph - 3):
		for x in range(3, _pw - 3):
			var i := y * _pw + x
			if _pwet[i] == 1:
				# shadow under an overhanging south bank (land just below)
				var below := _pk[i + _pw]
				if _pwet[i + _pw] == 0 and below != Terrain.SAND and below != Terrain.BRIDGE:
					edits[i] = W0 if _pdep[i] > 0.9 else W1
				elif _pwet[i + 2 * _pw] == 0 and _pk[i + 2 * _pw] != Terrain.SAND and hash2(x >> 1, y, 741) < 0.6:
					edits[i] = W1 if im.get_pixel(x, y) != W0 else W0
				continue
			var k := _pk[i]
			if k == Terrain.SAND or k == Terrain.BRIDGE or _phard[i] == 1:
				continue
			# a north bank: water a pixel or two below shows the cut face
			if _pwet[i + _pw] == 1:
				edits[i] = B1
			elif _pwet[i + 2 * _pw] == 1:
				edits[i] = B2 if hash2(x >> 1, y, 742) < 0.75 else T1
			# a south bank's lip: lit turf (or sand) along the top of the water
			elif _pwet[i - _pw] == 1:
				edits[i] = M1 if k == Terrain.MEADOW else (M0 if k == Terrain.WET_MEADOW else T3)
			# the sides of the channel: a dark line of wet earth
			elif _pwet[i + 1] == 1 or _pwet[i - 1] == 1:
				edits[i] = B1
	for i: int in edits:
		im.set_pixel(i % _pw, i / _pw, edits[i])
	_tioga_lines(im)


# ---------------------------------------------------------------- the road

## Tioga Road's asphalt: dark grey, with grit in small clusters and paler
## worn wheel tracks.
func _tioga(x: int, y: int, a: float, b: float, n: float) -> Color:
	var col := G1
	if _over(a * 0.5 + n * 0.5, 0.66, x, y, 801):
		col = G2
	var g := _jit(x, y, 4, 802)
	if g.z < 0.25 and int(g.x) == 0 and int(g.y) == 0:
		col = G2 if col == G1 else G3
	elif g.z > 0.92 and int(g.x) == 0 and int(g.y) == 0:
		col = G0
	return col


## The lots: the road's asphalt (so the roads run into them without a
## seam), with oil stains where the cars stand.
func _lot_asphalt(x: int, y: int, a: float, b: float, n: float) -> Color:
	var col := _tioga(x, y, a, b, n)
	if _over(b * 0.5 + n * 0.5, 0.78, x, y, 812, 0.05):
		col = G0 if hash2(x >> 1, y >> 1, 813) < 0.3 else G1
	return col


## The double yellow center line and the white edge lines, worn and broken
## here and there, on every stretch of road running across the map.
func _tioga_lines(im: Image) -> void:
	for x in _pw:
		var y := 0
		while y < _ph:
			if _pk[y * _pw + x] != Terrain.ROAD:
				y += 1
				continue
			var top := y
			while y < _ph and _pk[y * _pw + x] == Terrain.ROAD:
				y += 1
			var bottom := y - 1
			var run := bottom - top + 1
			# only the long, level road: its runs are about two tiles tall
			if run < 22 or run > 44:
				continue
			# skip where the road turns (a short run across)
			var across := 0
			var cy := (top + bottom) / 2
			for dx in range(-24, 25):
				if x + dx >= 0 and x + dx < _pw and _pk[cy * _pw + x + dx] == Terrain.ROAD:
					across += 1
			if across < 49:
				continue
			var worn := hash2(x / 5, cy, 821) < 0.12
			if not worn:
				im.set_pixel(x, cy - 1, O2 if hash2(x >> 1, cy, 822) < 0.85 else O1)
				im.set_pixel(x, cy + 1, O2 if hash2(x >> 1, cy + 1, 822) < 0.85 else O1)
			if hash2(x / 4, top, 823) < 0.8:
				im.set_pixel(x, top + 2, G4 if hash2(x >> 1, top, 824) < 0.8 else G3)
			if hash2(x / 4, bottom, 825) < 0.8:
				im.set_pixel(x, bottom - 2, G4 if hash2(x >> 1, bottom, 826) < 0.8 else G3)
