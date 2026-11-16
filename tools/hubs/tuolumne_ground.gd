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
const T0 := Color("5e4a38")
const T1 := Color("86694b")
const T2 := Color("b0925f")
const T3 := Color("d6bd88")
const P0 := Color("12291d")
const P1 := Color("1d3f2b")
const P2 := Color("2c5c37")
const P3 := Color("437f45")
const M0 := Color("5c8f3c")
const M1 := Color("84b04a")
const M2 := Color("aecb62")
const M3 := Color("d3e48a")
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
const PAINT_RED := Color("b3362b")
const A1 := Color("d9772a")
const NIGHT_BLUE := Color("2d3050")


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
## Per tile, how near the water is (blurred), so the sedge stays green along
## the river and the lake rather than curing.
var _water_f := PackedFloat32Array()


## The painted ground, then the edges of the granite slabs and the trails.
func paint(grid: PackedInt32Array, width: int, height: int, seed_v: int) -> Image:
	var im := super.paint(grid, width, height, seed_v)
	_ground_edges(im)
	return im


func _color(k: int, x: int, y: int, i: int, tx: int, ty: int) -> Color:
	if _mead_f.size() != w * h:
		var f := PackedFloat32Array()
		f.resize(w * h)
		for t in w * h:
			f[t] = 1.0 if kind[t] == Terrain.MEADOW or kind[t] == Terrain.WET_MEADOW else 0.0
		_mead_f = _path_blur(_path_blur(_path_blur(f)))
		var wf := PackedFloat32Array()
		wf.resize(w * h)
		for t in w * h:
			wf[t] = 1.0 if kind[t] in [Terrain.RIVER, Terrain.LAKE, Terrain.SAND, Terrain.WET_MEADOW] else 0.0
		_water_f = _path_blur(_path_blur(wf))
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
		Terrain.GRANITE:
			return _polished(x, y, i, a, b, n)
	return super._color(k, x, y, i, tx, ty)


# ---------------------------------------------------------------- shared motifs

## Like _jit, but the anchor keeps [param m] pixels inside its cell, so a
## mark reaching m pixels round it is never clipped.
func _jitm(x: int, y: int, cs: int, s: int, m: int) -> Vector3:
	var gx := x / cs
	var gy := y / cs
	var ax := gx * cs + m + int(hash2(gx, gy, s) * float(cs - 2 * m))
	var ay := gy * cs + m + int(hash2(gx, gy, s + 1) * float(cs - 2 * m))
	return Vector3(float(x - ax), float(y - ay), hash2(gx, gy, s + 2))


## A clump of sedge or grass, three pixels wide and up to three tall, lit
## from the upper left: 0 none, 1 shadow at its foot, 2 blade, 3 lit blade,
## 4 lit tip. [param prob] is the share of cells with a clump.
func _clump(x: int, y: int, cs: int, s: int, prob: float) -> int:
	var c1 := _clump_in(x, y, cs + 1, s, prob)
	if c1 != 0:
		return c1
	return _clump_in(x + 3, y + 2, cs + 3, s + 7, prob * 0.8)


func _clump_in(x: int, y: int, cs: int, s: int, prob: float) -> int:
	var d := _jitm(x, y, cs, s, 1)
	if d.z > prob:
		return 0
	var dx := int(d.x)
	var dy := int(d.y)
	var tall := d.z < prob * 0.45
	if dy == 0 and (dx == 0 or dx == 1):
		return 1
	if dy == -1:
		if dx == -1:
			return 3
		if dx == 0:
			return 2
		if dx == 1:
			return 2 if d.z < prob * 0.7 else 0
	if dy == -2:
		if dx == -1 and tall:
			return 4
		if dx == 1 and d.z < prob * 0.3:
			return 3
	return 0


## Relief of the large field at a pixel: +1 on a slope facing the light (up
## and to the left), -1 on one turned away, 0 on the flat.
func _facing(x: int, y: int, field: PackedByteArray, reach: int, step: float) -> int:
	var ul := field[clampi(y - reach, 0, _ph - 1) * _pw + clampi(x - reach, 0, _pw - 1)]
	var dr := field[clampi(y + reach, 0, _ph - 1) * _pw + clampi(x + reach, 0, _pw - 1)]
	var d := (float(ul) - float(dr)) / 255.0
	if d > step:
		return 1
	if d < -step:
		return -1
	return 0


## A low granite outcrop or glacial erratic, lying flush in the ground:
## Vector2i(state, tone). State 0 none, 1 the rock (tone 0 dark to 3
## lit), 2 the shadow it throws down and to the right. Each sits well
## inside its cell, so it never spills into the next, and only where all
## of the ground under it is of [param kinds].
func _outcrop(x: int, y: int, cs: int, s: int, prob: float, kinds: Array) -> Vector2i:
	var gx := x / cs
	var gy := y / cs
	if hash2(gx, gy, s + 2) > prob:
		return Vector2i.ZERO
	var m := 14
	var ax := gx * cs + m + int(hash2(gx, gy, s) * float(cs - 2 * m))
	var ay := gy * cs + m + int(hash2(gx, gy, s + 1) * float(cs - 2 * m))
	var rx := 3.0 + hash2(gx, gy, s + 3) * 6.0
	var ry := rx * (0.5 + hash2(gx, gy, s + 4) * 0.2)
	var fx := float(x - ax) / rx
	var fy := float(y - ay) / ry
	# ragged, not a perfect oval: the rim wobbles on the small field
	var e := fx * fx + fy * fy + (hash2(x >> 1, y >> 1, s + 5) - 0.5) * 0.25
	if e > 1.9:
		return Vector2i.ZERO
	# all the tiles it covers must be the right ground
	for c2: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var tx := clampi((ax + c2.x * int(rx + 3.0)) / T, 0, w - 1)
		var ty := clampi((ay + c2.y * int(ry + 3.0)) / T, 0, h - 1)
		if kind[ty * w + tx] not in kinds:
			return Vector2i.ZERO
	if e <= 1.0:
		# lit toward the upper left, its lower rim dark
		var lit := -(fx + fy * 1.4)
		var tone := 2
		if e > 0.72 and fy > 0.1:
			tone = 0
		elif lit > 0.85 and e > 0.3:
			tone = 3
		elif lit < -0.6:
			tone = 1
		# a crack across some of them
		if hash2(gx, gy, s + 6) < 0.4 and absi((x - ax) - (y - ay) / 2 - int(hash2(gx, gy, s + 7) * 4.0) + 2) == 0 and e < 0.8:
			tone = 0
		return Vector2i(1, tone)
	# its shadow, down and to the right
	var sx := float(x - ax - 1) / rx
	var sy := float(y - ay - 1) / ry
	if sx * sx + sy * sy <= 1.05 and fy > -0.2:
		return Vector2i(2, 0)
	return Vector2i.ZERO


## A wildflower in bloom: Vector2i(state, kind). State 0 none, 1 petal,
## 2 second petal colour, 3 stem. Kinds: 0 lupine (a spike), 1 shooting
## star, 2 buttercup, 3 yampah, 4 paintbrush. Flowers come in drifts of
## one kind, thickest where the flower field runs high.
func _bloom(x: int, y: int, cs: int, s: int, base: float, kinds: Array) -> Vector2i:
	var gx := x / cs
	var gy := y / cs
	var fld := float(_nf[clampi(gy * cs + cs / 2, 0, _ph - 1) * _pw + clampi(gx * cs + cs / 2, 0, _pw - 1)]) / 255.0
	var prob := base * (0.2 + 3.0 * smooth(0.45, 0.8, fld))
	var d := _jitm(x, y, cs, s, 2)
	if d.z > prob:
		return Vector2i.ZERO
	# one kind to a drift, now and then another mixed in
	var pick := int(hash2(x / 48, y / 40, s + 3) * float(kinds.size()))
	if hash2(gx, gy, s + 4) < 0.2:
		pick = int(hash2(gx, gy, s + 5) * float(kinds.size()))
	var sp: int = kinds[clampi(pick, 0, kinds.size() - 1)]
	var dx := int(d.x)
	var dy := int(d.y)
	match sp:
		0:
			if dx == 0 and (dy == -2 or dy == -1):
				return Vector2i(1 if dy == -2 else 2, 0)
			if dx == 0 and dy == 0:
				return Vector2i(3, 0)
		_:
			if dy == -1 and (dx == 0 or dx == 1):
				return Vector2i(1 if dx == 0 else 2, sp)
			if dy == 0 and dx == 0:
				return Vector2i(3, sp)
	return Vector2i.ZERO


func _bloom_color(st: Vector2i, stem: Color) -> Color:
	if st.x == 3:
		return stem
	match st.y:
		0:
			return LUPINE if st.x == 1 else NIGHT_BLUE
		1:
			return SHOOTING_STAR if st.x == 1 else B2
		2:
			return O3 if st.x == 1 else O2
		3:
			return WHITE_FLOWER if st.x == 1 else G5
	return PAINT_RED if st.x == 1 else A1


# ---------------------------------------------------------------- the forest floor

## The lodgepole forest's floor: pale granite sand (grus) lying in broad
## patches of grey and buff, rusty needle duff drifted in the low field,
## cones, grey twigs, grit, sedge clumps in the hollows and low granite
## outcrops flush with the sand. Trampled (a campsite, the trodden rise at
## Soda Springs) it is barer and packed, with no sedge.
func _grus(x: int, y: int, a: float, b: float, n: float, trampled: bool) -> Color:
	# the sand: broad patches, warm buff where the large field runs high,
	# pale grey grus elsewhere, with a few grains of the other mixed in
	var warm := _over(a * 0.8 + n * 0.2, 0.52, x, y, 500, 0.05)
	var col := T3 if warm else G4
	if hash2(x >> 1, y >> 1, 501) < 0.04:
		col = G4 if warm else T3
	# needle duff in soft drifts: scattered needles thickening into a mat
	var duff := b * 0.7 + a * 0.3
	var thr := 0.66 if trampled else 0.58
	var needle := _jit(x, y, 3, 511)
	var on_needle := needle.z < 0.85 and ((int(needle.x) == 0 and int(needle.y) == 0) or (int(needle.x) == 1 and int(needle.y) == (1 if needle.z < 0.4 else -1)))
	if _over(duff, thr + 0.1, x, y, 503, 0.06):
		col = T2 if not on_needle else (T1 if needle.z < 0.65 else B2)
	elif _over(duff, thr, x, y, 504, 0.06):
		if on_needle and needle.z < 0.5:
			col = T1 if needle.z < 0.3 else T2
	elif _over(duff, thr - 0.14, x, y, 505, 0.1) and on_needle and needle.z < 0.22:
		col = T2
	# near the meadow the sedge and grass reach in under the trees
	var mead := _path_sample(_mead_f, x, y) if not _mead_f.is_empty() else 0.0
	var grassy := 0.0 if trampled else maxf(smooth(0.3, 0.12, a), smooth(0.02, 0.35, mead))
	if grassy > 0.0:
		var dry := hash2(x / 6, y / 6, 522) < 0.35
		var cl := _clump(x, y, 4, 521, grassy * 0.7)
		if cl == 1:
			col = P2 if not dry else T1
		elif cl == 2:
			col = (P3 if not dry else O1)
		elif cl == 3:
			col = (M0 if not dry else O2)
		elif cl == 4:
			col = (M1 if not dry else O3)
	# a low outcrop of granite, polished by the glaciers, flush with the sand
	var oc := _outcrop(x, y, 64, 561, 0.16 if trampled else 0.24, [Terrain.SUBALPINE, Terrain.CAMP])
	if oc.x == 1:
		return [G2, G3, G4, G5][oc.y]
	elif oc.x == 2:
		col = T1 if col == T2 or col == T3 else G2
	# granite grit: a quartz glint with its shadow, now and then
	var g := _jit(x, y, 6, 531)
	if g.z < 0.18:
		if int(g.x) == 0 and int(g.y) == 0:
			col = G5
		elif int(g.x) == 1 and int(g.y) == 1:
			col = G2
	# pebbles: a lit top-left, a dark foot
	var pb := _jit(x, y, 11, 535)
	if pb.z < 0.16:
		var dx := int(pb.x)
		var dy := int(pb.y)
		if dy == 0 and (dx == 0 or dx == 1):
			col = G4 if dx == 0 else G3
		elif dy == 1 and (dx == 0 or dx == 1):
			col = G2 if dx == 0 else G1
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
	if tw.z < 0.12:
		var dx := int(tw.x)
		var dy := int(tw.y)
		var slope := -1 if tw.z < 0.06 else 1
		if dx >= -2 and dx <= 2 and dy == (dx * slope) / 2:
			col = G3 if dx < 1 else G2
	return col


## The trails here are sandy grus, worn paler than the forest floor: a
## paler tread down the middle where most feet go, scuffs and pebbles, and
## (in _trail_edges) a sunken lip with the grass leaning over it.
func _sand_trail(x: int, y: int, a: float, b: float, n: float) -> Color:
	var col := T3
	if not _over(b * 0.6 + n * 0.4, 0.3, x, y, 561):
		col = T2
	# footprints and scuffs: short dark dashes across the tread
	var sc := _jit(x, y, 5, 566)
	if sc.z < 0.18 and int(sc.y) == 0 and (int(sc.x) == 0 or int(sc.x) == 1):
		col = T2 if col == T3 else T1
	var p := _jit(x, y, 7, 571)
	if p.z < 0.2:
		if int(p.x) == 0 and int(p.y) == 0:
			col = G5
		elif int(p.x) == 0 and int(p.y) == 1:
			col = G3
	return col


# ---------------------------------------------------------------- the meadow

## Sedge turf in clumps, lit from the upper left, over broad hummocks that
## catch the light on one side and fall into shade on the other. The greens
## run from the deep swales through sedge green to olive and, on the drier
## rises, to cured straw; the wet meadow is darker, with snowmelt pools.
## Wildflowers grow in drifts of one kind, and glacial erratics and low
## slabs of polished granite lie flush in the grass.
func _sedge(x: int, y: int, a: float, b: float, n: float, wet: bool) -> Color:
	var v := a * 0.55 + b * 0.45
	# the turf's tones: base, the clump's foot, its blade, its lit blade, its tip
	var base := M0
	var foot := P3
	var blade := M0
	var lit := M1
	var tip := M2
	var swale := false
	if wet:
		base = P3
		foot = P2
		blade = P3
		lit = M0
		tip = M1
		if not _over(v, 0.42, x, y, 601):
			base = P2
			foot = P1
			blade = P2
			lit = P3
			tip = M0
	elif not _over(v, 0.36, x, y, 602, 0.1):
		swale = true
		base = P3
		foot = P2
		blade = P3
		lit = M0
		tip = M1
	# how cured the sedge is: drier on the rises, never by the water
	var near_water := _path_sample(_water_f, x, y) if not _water_f.is_empty() else 0.0
	var cure := (a * 0.5 + float(_nf[y * _pw + x]) / 255.0 * 0.3 + b * 0.2) - near_water * 0.5
	var olive := not wet and not swale and _over(cure, 0.46, x, y, 605, 0.08)
	var straw := false
	if straw:
		base = T2
		foot = T1
		blade = T2
		lit = O2
		tip = T3
	var col := base
	# the hummocks: the side facing the sun a step lighter, the far side darker
	var face := _facing(x, y, _na, 4, 0.025) if not wet else 0
	if face < 0 and hash2(x >> 1, y >> 1, 607) < 0.45:
		col = foot
	# clumps, densely set; on the olive ground about half are tawny
	var cl := _clump(x, y, 4, 611, 0.7 if not wet else 0.55)
	if cl != 0:
		var tawny := olive and hash2(x / 4, y / 4, 612) < 0.5
		var green := straw and hash2(x / 4, y / 4, 613) < 0.25
		var f := foot
		var bl := blade
		var li := lit
		var tp := tip
		if tawny:
			f = P3
			bl = T2
			li = T3
			tp = O3
		elif green:
			f = P3
			bl = M0
			li = M1
			tp = M1
		if face > 0 and cl >= 2:
			cl = mini(cl + 1, 4)
		col = [col, f, bl, li, tp][cl]
	if wet:
		# small pools of snowmelt standing in the sedge, sky in them
		if _over(n * 0.6 + (1.0 - a) * 0.4, 0.74, x, y, 631, 0.04):
			col = W2
			if not _over(n * 0.6 + (1.0 - a) * 0.4, 0.78, x, y, 632, 0.04):
				col = P1
			elif hash2(x >> 1, y, 633) < 0.18:
				col = W4
			return col
		var wb := _bloom(x, y, 7, 645, 0.05, [1, 3])
		if wb.x != 0:
			col = _bloom_color(wb, P2)
		return col
	# flowers, in drifts: lupine, shooting stars, buttercups, yampah, paintbrush
	var fl := _bloom(x, y, 6, 641, 0.1, [0, 1, 2, 3, 4] if not straw else [0, 4])
	if fl.x != 0:
		col = _bloom_color(fl, foot)
	# a glacial erratic or a low slab of granite in the grass
	var oc := _outcrop(x, y, 72, 661, 0.28, [Terrain.MEADOW])
	if oc.x == 1:
		return [G2, G3, G4, G5][oc.y]
	elif oc.x == 2:
		col = P2 if not straw else T1
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


# ---------------------------------------------------------------- the granite

## Granite polished by the glaciers that filled these meadows: pale, smooth
## slabs peeling in sheets (each sheet's edge a dark line under a lit lip),
## with streaks of glacial polish catching the sun, cracks with sedge in
## them, lichen, and erratic boulders left lying on top.
func _polished(x: int, y: int, i: int, a: float, b: float, n: float) -> Color:
	var col := G4
	if not _over(a * 0.8 + b * 0.2, 0.36, x, y, 901, 0.04):
		col = G3
	# sheet edges: where the medium field crosses a step
	var sheet := fmod(b * 2.5 + a * 1.0, 1.0)
	var above := fmod(float(_nb[maxi(0, i - _pw)]) / 255.0 * 2.5 + float(_na[maxi(0, i - _pw)]) / 255.0 * 1.0, 1.0)
	if sheet < 0.03:
		col = G2
	elif above < 0.03:
		col = G5
	# glacial polish: short streaks of sheen, running with the old ice (west)
	var pcx := (x + int(hash2(0, y / 2, 905) * 30.0)) / 9
	if col != G2 and hash2(pcx, y / 2, 906) < 0.05 and (x + int(hash2(0, y / 2, 905) * 30.0)) % 9 < 5:
		col = G5
	# cracks, some with a line of sedge in them
	var cr := _jitm(x, y, 23, 911, 5)
	if cr.z < 0.1:
		var dx := int(cr.x)
		var dy := int(cr.y)
		if dx >= -4 and dx <= 4 and dy == dx / 3:
			col = G2
			if cr.z < 0.05 and dx % 2 == 0:
				col = P3
		elif dx >= -3 and dx <= 3 and dy == dx / 3 - 1 and cr.z < 0.05 and dx % 2 == 0:
			col = M0
	# lichen: chartreuse and rust
	var li := _jit(x, y, 9, 921)
	if li.z < 0.05 and int(li.y) == 0 and (int(li.x) == 0 or int(li.x) == 1):
		col = M2 if li.z < 0.06 else O1
	# erratic boulders lying on the slab, each with its shadow
	var bo := _jitm(x, y, 26, 931, 7)
	if bo.z < 0.14:
		var r := 2.0 + bo.z * 9.0
		var fx := bo.x / r
		var fy := bo.y / (r * 0.75)
		var e := fx * fx + fy * fy
		if e <= 1.0:
			var lt := -(fx + fy)
			col = G5 if lt > 0.6 else (G4 if lt > -0.3 else (G3 if e < 0.7 or fy < 0.2 else G2))
		else:
			var sx := (bo.x - 1.0) / r
			var sy := (bo.y - 1.0) / (r * 0.75)
			if sx * sx + sy * sy <= 1.0 and fy > 0.0:
				col = G2
	return col


## Where a granite slab meets the sand or the grass, the slab's thickness
## shows as a dark rim along its lower edge with a shadow thrown below it,
## and its upper edge catches the light. Grass leans over the edges of the
## trails, and a trail's upper edge, sunk a little, is in shade.
func _ground_edges(im: Image) -> void:
	var edits := {}
	for y in range(3, _ph - 3):
		for x in range(3, _pw - 3):
			var i := y * _pw + x
			var k := _pk[i]
			if k == Terrain.GRANITE:
				var below := _pk[i + _pw]
				var up := _pk[i - _pw]
				if below != Terrain.GRANITE and below != Terrain.CLIFF and not _is_water(below):
					edits[i] = G1
				elif _pk[i + 2 * _pw] != Terrain.GRANITE and _pk[i + 2 * _pw] != Terrain.CLIFF and not _is_water(_pk[i + 2 * _pw]):
					edits[i] = G2
				elif up != Terrain.GRANITE and up != Terrain.CLIFF and not _is_water(up):
					edits[i] = G5
				continue
			if k in [Terrain.SUBALPINE, Terrain.MEADOW, Terrain.WET_MEADOW, Terrain.CAMP, Terrain.TRAIL]:
				# the shadow of a slab's edge, just below it
				if _pk[i - _pw] == Terrain.GRANITE or (_pk[i - 2 * _pw] == Terrain.GRANITE and hash2(x >> 1, y, 941) < 0.6):
					edits[i] = _shade(im.get_pixel(x, y))
					continue
			if k == Terrain.TRAIL:
				var up := _pk[i - _pw]
				var up2 := _pk[i - 2 * _pw]
				var grass_up := up == Terrain.MEADOW or up == Terrain.WET_MEADOW or up == Terrain.SUBALPINE
				if grass_up:
					# blades from the bank above lean out over the tread
					if hash2(x, y, 951) < 0.45:
						edits[i] = P3 if up != Terrain.SUBALPINE else T2
					else:
						edits[i] = T1
				elif up2 == Terrain.MEADOW or up2 == Terrain.WET_MEADOW or up2 == Terrain.SUBALPINE:
					edits[i] = T2 if hash2(x, y, 952) < 0.7 else (M0 if up2 != Terrain.SUBALPINE and hash2(x, y, 953) < 0.5 else T2)
				elif _pk[i + _pw] != Terrain.TRAIL and _pk[i + _pw] != Terrain.BRIDGE and hash2(x >> 1, y, 954) < 0.5:
					# the lower lip, a little lit
					edits[i] = T3
				else:
					# grass leaning in from the sides
					var side := _pk[i - 1] if _pk[i - 1] != Terrain.TRAIL else _pk[i + 1]
					if (side == Terrain.MEADOW or side == Terrain.WET_MEADOW) and hash2(x, y >> 1, 955) < 0.5:
						edits[i] = M0 if hash2(x, y, 956) < 0.5 else P3
	for i: int in edits:
		im.set_pixel(i % _pw, i / _pw, edits[i])


## One step down the ground's own ramp, as a shadow falls on it.
func _shade(c0: Color) -> Color:
	for ramp: Array in [[G0, G1, G2, G3, G4, G5], [T0, T1, T2, T3], [P0, P1, P2, P3, M0, M1, M2, M3], [B0, B1, B2], [O1, O2, O3]]:
		for j in range(1, ramp.size()):
			if c0.is_equal_approx(ramp[j]):
				return ramp[j - 1]
	return c0.darkened(0.2)


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
