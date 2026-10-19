extends "res://tools/hubs/ahwahnee_land_art.gd"
## The north wall of the Valley above Yosemite Village and Camp 4, in the
## Ahwahnee's landscape style (the same height-field lighting, ordered dithering,
## stained granite, ledge conifers and talus skirt as the Royal Arches wall),
## with Lower Yosemite Fall pouring down a gully in it. Drawn for the exact
## cliff outline the village builder lays out, so the picture and the solid
## tiles line up. Written to assets/sprites/buildings/.
##
## <prefix>_wall.png   (W x tallest cliff + SKIRT): the wall seen from the front,
##   top edge at the top of the map. Transparent below the skirt so the ground
##   shows through between the talus boulders.
## <prefix>_fall_0.png .. _fall_5.png (FALL_W x fall height), loop at ~8 fps,
##   drawn at the gully's top. <prefix>_mist_0..3 go at its foot.

const OUT := "res://assets/sprites/buildings/"
const SKIRT := 44
const FALL_W := 48
const FALL_H := 128

## Added to every noise seed, so another wall (El Capitan, Sentinel Rock)
## isn't the Village's wall again. 0 draws the Village's.
var seed_offset := 0


## Writes the wall and the fall frames into [param dir] as "<prefix>_wall.png"
## and so on. [param prof] is, for every pixel column of the map, the y where
## the solid cliff ends; [param fall_cx] is the pixel x of the fall's center
## and [param fall_h] its height in pixels.
func save_village(prof: PackedInt32Array, fall_cx: int, dir := OUT, prefix := "village", fall_h := FALL_H) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	village_wall(prof, fall_cx).save_png(ProjectSettings.globalize_path("%s%s_wall.png" % [dir, prefix]))
	for i in CASCADE_FRAMES:
		fall_frame(i, fall_h).save_png(ProjectSettings.globalize_path("%s%s_fall_%d.png" % [dir, prefix, i]))
	for i in MIST_FRAMES:
		mist_frame(i).save_png(ProjectSettings.globalize_path("%s%s_mist_%d.png" % [dir, prefix, i]))


static func gully_x(y: float, fall_cx: float) -> float:
	return fall_cx + 2.5 * sin(y * 0.07 + 0.4) + 1.5 * sin(y * 0.19)


func village_wall(prof: PackedInt32Array, fall_cx: int) -> Image:
	var W := prof.size()
	var tallest := 0
	for p in prof:
		tallest = maxi(tallest, p)
	var Hh := tallest + SKIRT
	var n_base := _noise(31 + seed_offset, 2)
	var n_fine := _noise(32 + seed_offset)
	var n_join := _noise(33 + seed_offset, 3)
	var n_streak := _noise(34 + seed_offset, 2)
	var n_wet := _noise(35 + seed_offset, 2)
	var n_lichen := _noise(36 + seed_offset, 3)
	var n_crack := _noise(37 + seed_offset, 3)
	var n_warp := _noise(38 + seed_offset, 2)
	var n_shade := _noise(39 + seed_offset, 2)
	var n_rim := _noise(40 + seed_offset, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1851 + seed_offset

	var hgt := PackedFloat32Array()
	hgt.resize(W * Hh)
	var wetv := PackedFloat32Array()
	wetv.resize(W * Hh)
	var shade_add := PackedFloat32Array()
	shade_add.resize(W * Hh)
	for y in Hh:
		for x in W:
			var wx := x + n_warp.get_noise_2d(x * 0.008, y * 0.008) * 7.0
			var wy := y + n_warp.get_noise_2d(x * 0.008 + 50.0, y * 0.008 + 50.0) * 7.0
			var h := n_base.get_noise_2d(wx * 0.007, wy * 0.011) * 6.0
			h += n_join.get_noise_2d(wx * 0.035, wy * 0.004) * 1.1
			h += n_fine.get_noise_2d(x * 0.35, y * 0.35) * 0.3
			# a few broad stepped recesses, like the real wall's weathered joints
			h += sin(wx * 0.011 + n_base.get_noise_2d(wx * 0.004, 7.0) * 3.0) * 2.4
			var dc := absf(x - gully_x(y, fall_cx))
			h -= 13.0 * (1.0 - smoothstep(5.0, 19.0, dc))
			wetv[y * W + x] = exp(-pow(dc / 34.0, 2.0))
			hgt[y * W + x] = h

	var ledges: Array = []
	for i in W / 56:
		ledges.append([rng.randi_range(8, W - 90), rng.randi_range(22, 70), rng.randi_range(18, maxi(40, tallest - 24))])
	var lip := [0.6, 1.8, 2.4, 2.6, 0.8, 0.0]
	for l: Array in ledges:
		var lx: int = l[0]
		var ll: int = l[1]
		var ly: int = l[2]
		for x in range(lx, mini(lx + ll, W)):
			var t := float(x - lx) / ll
			var taper := pow(sin(t * PI), 0.5)
			var jit := int(n_fine.get_noise_2d(x * 0.05 + ly, ly * 0.3) * 4.5)
			for dy in range(-3, 3):
				var y := ly + dy + jit
				if y >= 0 and y < Hh:
					hgt[y * W + x] += taper * lip[dy + 3]
			for dy in range(2, 10):
				var y2 := ly + dy + jit
				if y2 >= 0 and y2 < Hh:
					shade_add[y2 * W + x] -= 0.09 * taper * (1.0 - float(dy - 2) / 8.0)

	var im := Image.create_empty(W, Hh, false, Image.FORMAT_RGBA8)
	var ramp := _cols(GRANITE)
	var orange := _cols(["6a4a2a", "8f6a34", "b98a44", "d8ad5c", "e8c878"])
	var gray_green := _cols(["5a6456", "7a8672", "9aa48c", "b6bda4"])
	var blue_black := Color("242838")
	var lx_l := -0.62
	var ly_l := -0.55
	var lz_l := 0.56
	for y in Hh:
		for x in W:
			var i := y * W + x
			var xm := maxi(x - 1, 0)
			var xp := mini(x + 1, W - 1)
			var ym := maxi(y - 1, 0)
			var yp := mini(y + 1, Hh - 1)
			var hx := (hgt[y * W + xp] - hgt[y * W + xm]) * 0.5
			var hy := (hgt[yp * W + x] - hgt[ym * W + x]) * 0.5
			var inv := 1.0 / sqrt(hx * hx + hy * hy + 1.0)
			var d := (-hx * lx_l - hy * ly_l + lz_l) * inv
			var s := 0.26 + 0.78 * _sat(d)
			var x4a := maxi(x - 5, 0)
			var x4b := mini(x + 5, W - 1)
			var y4a := maxi(y - 5, 0)
			var y4b := mini(y + 5, Hh - 1)
			var cav := (hgt[y * W + x4a] + hgt[y * W + x4b] + hgt[y4a * W + x] + hgt[y4b * W + x]) * 0.25 - hgt[i]
			s -= _sat(cav * 0.03) * 0.4
			s += shade_add[i]
			s += (K.hash2(x / 3, y / 3, 31) - 0.5) * 0.05
			var sh := n_shade.get_noise_2d(x * 0.0045, y * 0.006)
			s -= maxf(0.0, sh - 0.02) * 0.65
			s *= 0.9 + 0.1 * (1.0 - float(y) / Hh)
			s -= 0.2 * (1.0 - smoothstep(4.0, 30.0, y))
			s -= 0.3 * smoothstep(float(prof[x]) - 30.0, float(prof[x]) + 2.0, y)
			var wx := x + n_warp.get_noise_2d(x * 0.02, y * 0.02) * 8.0
			var streak := n_streak.get_noise_2d(wx * 0.16, y * 0.0045)
			var wetmask := 0.25 + 0.75 * smoothstep(-0.25, 0.45, n_wet.get_noise_2d(x * 0.007, y * 0.009))
			var stain := smoothstep(0.34, 0.5, streak) * wetmask
			stain = maxf(stain, wetv[i] * 0.85)
			s -= stain * 0.27
			var cv := absf(n_crack.get_noise_2d(wx * 0.02, y * 0.005))
			var ch := absf(n_crack.get_noise_2d(x * 0.004 + 30.0, y * 0.022))
			if cv < 0.0045 or ch < 0.0016:
				s -= 0.22
			var col := _ramp(ramp, s, x, y, 0.3)
			# hue shift: lit faces warm toward cream, shade cools toward blue-violet
			if s > 0.7 and stain < 0.2:
				col = col.lerp(Color("eadfc4"), minf(0.35, (s - 0.7) * 0.9))
			elif s < 0.38:
				col = col.lerp(Color("2a2f4c"), minf(0.4, (0.38 - s) * 0.9))
			if stain > 0.25:
				col = col.lerp(blue_black, minf(0.45, (stain - 0.25) * 0.8))
			var lich := n_lichen.get_noise_2d(x * 0.05, y * 0.05)
			if lich > 0.4 and s > 0.5 and stain < 0.3 and d > 0.5:
				col = _ramp(orange, s * 0.85 + (K.hash2(x / 2, y / 2, 5) - 0.5) * 0.3, x, y, 0.3) if lich > 0.5 else col.lerp(Color("c9a05a"), 0.3)
			elif lich < -0.42 and s > 0.4 and stain < 0.3:
				col = _ramp(gray_green, s + (K.hash2(x / 2, y / 2, 6) - 0.5) * 0.3, x, y, 0.3)
			im.set_pixel(x, y, col)

	# conifers and shrubs on the ledges
	for l: Array in ledges:
		var lx: int = l[0]
		var ll: int = l[1]
		var ly: int = l[2]
		if ly < 22:
			continue
		var count := ll / 26
		for k in count:
			var vx := lx + int((k + 0.5 + (rng.randf() - 0.5) * 0.6) / count * ll)
			if absf(vx - gully_x(ly, fall_cx)) < 18.0:
				continue
			var base_y := ly - 1
			var roll := rng.randf()
			var sd := rng.randi()
			if roll < 0.4:
				_conifer(im, vx, base_y, rng.randi_range(9, 17), rng.randf_range(3.0, 4.6), sd)
			elif roll < 0.6:
				_conifer(im, vx, base_y, rng.randi_range(12, 19), rng.randf_range(2.0, 2.8), sd, true)
			elif roll < 0.85:
				_shrub(im, vx, base_y, rng.randf_range(3.0, 5.0), sd, rng.randf() < 0.5)
			else:
				_fern(im, vx, base_y, rng.randi_range(4, 6), sd)

	# the forest rim on the plateau, with a notch where the creek spills
	var rim := PackedInt32Array()
	rim.resize(W)
	var greens := _cols(GREENS)
	for x in W:
		rim[x] = 6 + int((n_rim.get_noise_1d(x * 0.05 + 200.0) + 1.0) * 5.0)
		for y in rim[x]:
			var col := _ramp(greens, 0.15 + K.hash2(x, y, 44) * 0.25, x, y, 0.5)
			if absf(x - fall_cx) > 6.0:
				im.set_pixel(x, y, col)
	var x_t := 0
	while x_t < W:
		var hh := rng.randi_range(18, 34)
		var hw := rng.randf_range(4.0, 7.0)
		if absf(x_t - fall_cx) > 16.0:
			_conifer(im, x_t, rim[clampi(x_t, 0, W - 1)] + rng.randi_range(0, 4), hh, hw, rng.randi(), rng.randf() < 0.3)
		x_t += rng.randi_range(5, 11)
	for y in range(0, 10):
		for x in range(fall_cx - 6, fall_cx + 7):
			var t := 1.0 - absf(x - fall_cx) / 7.0
			if y < 4:
				K.px(im, x, y, Color("2b2f40"))
			elif K.hash2(x, y, 3) < t:
				K.px(im, x, y, Color("34394e"))

	_village_skirt(im, prof, rng, fall_cx)
	return im


## Cuts the rock at the cliff outline and scatters talus, boulders, conifers
## and ferns below it, thinning toward the bottom.
func _village_skirt(im: Image, prof: PackedInt32Array, rng: RandomNumberGenerator, fall_cx: int) -> void:
	var W := prof.size()
	var Hh := im.get_height()
	var gravel := _cols(["3a3a40", "56524e", "746d64", "8f867a", "aca08e", "c6b9a2"])
	for x in W:
		for y in range(prof[x], Hh):
			im.set_pixel(x, y, Color(0, 0, 0, 0))
		for y in range(maxi(prof[x] - 4, 0), Hh):
			var below := float(y - prof[x])
			var dens := 1.0 - smoothstep(-2.0, float(SKIRT) - 4.0, below) * 0.94
			var cell := K.hash2(x / 2, y / 2, 91) * 0.7 + K.hash2(x, y, 92) * 0.3
			if cell < dens:
				var light := 0.5 + (K.hash2(x, y, 93) - 0.5) * 0.9 - (below / 90.0)
				im.set_pixel(x, y, _ramp(gravel, light, x, y, 0.5))
	var boulders: Array = []
	for i in W / 11:
		var bx := rng.randi_range(0, W - 1)
		boulders.append([bx, prof[bx] + rng.randi_range(-2, SKIRT - 8), 3.0 + pow(rng.randf(), 2.4) * 11.0])
	boulders.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	var trees: Array = []
	for i in W / 34:
		var tx := rng.randi_range(4, W - 4)
		if absf(tx - fall_cx) < 40.0:
			continue
		trees.append([tx, mini(prof[tx] + rng.randi_range(6, SKIRT - 8), Hh - 2), rng.randi_range(24, 48), rng.randf_range(5.0, 8.0), rng.randf() < 0.3])
	trees.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	for b: Array in boulders:
		if b[1] < prof[b[0]] + 14:
			_boulder(im, b[0], b[1], b[2], b[2] * 0.72, rng.randi())
	for t: Array in trees:
		K.shadow(im, t[0] + 2, t[1] + 1, t[3] * 0.8, 2.5, 0.3)
		_conifer(im, t[0], t[1], t[2], t[3], rng.randi(), t[4])
	for b: Array in boulders:
		if b[1] >= prof[b[0]] + 14:
			_boulder(im, b[0], b[1], b[2], b[2] * 0.72, rng.randi())
	for i in W / 16:
		var fx := rng.randi_range(0, W - 1)
		if absf(fx - fall_cx) < 36.0:
			continue
		var fy := mini(prof[fx] + rng.randi_range(4, SKIRT - 6), Hh - 1)
		if rng.randf() < 0.55:
			_fern(im, fx, fy, rng.randi_range(4, 7), rng.randi())
		else:
			_shrub(im, fx, fy, rng.randf_range(3.0, 6.0), rng.randi(), rng.randf() < 0.4)


## One frame of Lower Yosemite Fall: a ribbon of white water down the gully,
## widening at each ledge. The pattern repeats every 48 px of flow; one frame
## moves it 8 px.
func fall_frame(frame: int, fall_h := FALL_H) -> Image:
	var W := FALL_W
	var Hh := fall_h
	var im := K.make(W, Hh)
	var shift := frame * 8.0
	var tones := _cols(["4f80a6", "6ea0c4", "9ccce4", "cfeaf6", "f2fbff", "ffffff"])
	var ledge_ys := [int(Hh * 0.23), int(Hh * 0.52), int(Hh * 0.78)]
	for y in Hh:
		var Y := float(y)
		var cx := gully_x(Y, W / 2.0) - 0.0
		var w := 6.0 + 3.5 * smoothstep(0.0, 60.0, Y) + 0.6 * sin(Y * 0.19)
		var lip_glow := 0.0
		for ly: int in ledge_ys:
			var t := Y - ly
			if t >= 0.0 and t < 22.0:
				w += 3.6 * smoothstep(0.0, 8.0, t) * (1.0 - smoothstep(8.0, 22.0, t))
			if absf(t) < 3.0:
				lip_glow = 1.0 - absf(t) / 3.0
				w += 0.9
		if Y > Hh - 14.0:
			w += (Y - (Hh - 14.0)) * 0.35
		var flow_y := Y - shift
		for x in W:
			var d := absf(x - cx)
			var ex := (K.hash2(x, posmod(int(flow_y), 48), 12) - 0.5) * 1.6
			var cover := w + ex - d
			if cover > 0.0:
				var cell := int(floor(x * 0.55))
				var v := _vnoise(cell, flow_y, 6.0, 8, 21) * 0.5 + _vnoise(cell + 40, flow_y, 12.0, 4, 22) * 0.3 + _vnoise(int(x * 0.9) + 90, flow_y, 3.0, 16, 23) * 0.2
				var prof_c := 1.0 - pow(d / maxf(w, 1.0), 2.0) * 0.7
				# a fast, thin layer of white streaks riding the flow
				var fast := _vnoise(int(x * 0.7) + 140, flow_y * 1.6, 2.5, 24, 24)
				if fast > 0.6:
					v += 1.1 * (fast - 0.6)
				v = v * 0.95 + prof_c * 0.24 + lip_glow * 0.3 - 0.08
				# the bright core of the sheet, brightest down the middle
				var core := 1.0 - clampf(d / maxf(w, 1.0), 0.0, 1.0)
				v += 0.16 * core * core
				v -= 0.22 * ((x - cx) / maxf(w, 1.0))
				if d > w - 1.2:
					v -= 0.22
				if Y > Hh - 18.0:
					v += (Y - (Hh - 18.0)) * 0.03
				var col := _ramp(tones, v, x, y, 0.5)
				if cover < 1.0:
					col.a = 0.55
				im.set_pixel(x, y, col)
			elif cover > -3.2:
				var fall := posmod(int(flow_y), 48)
				if K.hash2(x, fall, 33) < 0.11 * (1.0 + lip_glow) and K.hash2(x + 7, fall + 3, 34) < 0.7:
					im.set_pixel(x, y, Color(0.86, 0.95, 1.0, 0.55 if cover > -1.6 else 0.35))
			# foam splashing around the plunge, in clumps that move with the frame
			if Y > Hh - 18.0 and cover > -5.0 and cover <= 1.0:
				var fc := K.hash2(int(x / 2), int(Y / 2) + frame * 3, 36)
				if fc < 0.5 * (1.0 - absf(cover) / 5.0):
					im.set_pixel(x, y, Color("f2fbff") if fc < 0.2 else Color("cfeaf6"))
	return im
