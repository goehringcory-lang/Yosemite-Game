class_name ClimbGranite
extends RefCounted
## The big forms of a Yosemite wall, painted over ClimbRock's face before the
## holds go on: exfoliation sheets (the overlapping shells granite peels off
## in) with their lit lips and cast shadows, black water streaks bleeding
## down from ledges and crack tops with lichen on their margins, and soft
## shadow under anything that stands off the face.
##
## The light comes from the upper left, as everywhere on the climbing screen:
## an edge facing left and up catches it, an edge facing right throws a
## shadow to the right. Colors are worked in freely here; the finished wall
## is quantized to its granite ramp afterwards (ClimbHiRes.quantize).

const P := preload("res://scripts/climb/art/climb_paint.gd")


## Darkens the pixel at ([param x], [param y]) by [param amount] (0..1),
## leaving the sky (transparent) alone.
static func darken(im: Image, x: int, y: int, amount: float) -> void:
	if x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height():
		return
	var col := im.get_pixel(x, y)
	if col.a < 0.5:
		return
	im.set_pixel(x, y, col.darkened(amount))


static func lighten(im: Image, x: int, y: int, amount: float) -> void:
	if x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height():
		return
	var col := im.get_pixel(x, y)
	if col.a < 0.5:
		return
	im.set_pixel(x, y, col.lightened(amount))


static func tint(im: Image, x: int, y: int, to: Color, amount: float) -> void:
	if x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height():
		return
	var col := im.get_pixel(x, y)
	if col.a < 0.5:
		return
	im.set_pixel(x, y, col.lerp(to, amount))


# ---------------------------------------------------------------- sheets

## Near-vertical exfoliation sheets: [param count] long wandering edges where
## one shell of granite overlaps the next. A sheet standing proud on the left
## shows a lit lip and throws a tapering shadow onto the face to its right; one
## standing proud on the right shows its edge as a narrow lit wall. Each edge
## wanders, breaks off and starts again, and its shadow swells and thins, so
## it reads as an overlap and not a ruled line. [param right] is where the
## face ends against the sky (per row).
static func sheets(im: Image, c: Dictionary, rng: RandomNumberGenerator, edge: PackedInt32Array, count: int, curve := 0.0) -> void:
	var w := im.get_width()
	var h := im.get_height()
	for i in count:
		var x0 := rng.randf_range(14.0, w - 70.0)
		var y0 := rng.randi_range(-80, h - 120)
		var length := rng.randi_range(140, 520)
		var slant := rng.randf_range(-0.1, 0.1)
		var phase := rng.randf() * TAU
		var seed_value := rng.randi()
		var proud_left := rng.randf() < 0.7
		var depth := rng.randf_range(2.0, 5.0)
		var bow := curve * rng.randf_range(0.6, 1.4)
		for k in length:
			var y := y0 + k
			if y < 0 or y >= h:
				continue
			var t := float(k) / length
			# Pointed ends: the sheet thins to nothing at the top and bottom.
			var taper := minf(minf(t, 1.0 - t) * 6.0, 1.0)
			if taper <= 0.05:
				continue
			# A gap now and then: the edge dies into the face and comes back.
			if P.smooth_noise(k * 0.03, i * 3.1, seed_value) < 0.22:
				continue
			var x := int(x0 + slant * k + sin(k * 0.021 + phase) * 4.0 + P.smooth_noise(k * 0.08, 1.0, seed_value) * 3.0 + bow * sin(t * PI) * 40.0)
			var lim := edge[y] - 6 if y < edge.size() else w - 30
			if x < 2 or x >= lim:
				continue
			var sw := int(round(depth * taper * (0.55 + 0.9 * P.smooth_noise(k * 0.05, 7.0, seed_value))))
			if proud_left:
				# The shell on the left: its lip in the sun, then its shadow.
				lighten(im, x - 2, y, 0.08)
				lighten(im, x - 1, y, 0.2)
				darken(im, x, y, 0.42)
				for s in sw:
					var fall := 1.0 - float(s) / maxf(sw, 1)
					if s == sw - 1 and not P.dither(x + 1 + s, y, 0.5):
						continue
					darken(im, x + 1 + s, y, 0.12 + 0.2 * fall)
				# the shell itself a shade lighter than the face it overlaps
				for s in range(3, 14):
					if P.dither(x - s, y, 0.5 - s * 0.03):
						lighten(im, x - s, y, 0.04)
			else:
				# The shell on the right: its edge is a narrow wall facing
				# the light, with a dark seam where it meets the face.
				darken(im, x - 1, y, 0.3)
				for s in maxi(sw / 2, 1):
					lighten(im, x + s, y, 0.18 - s * 0.04)
				darken(im, x + maxi(sw / 2, 1), y, 0.06)


# ---------------------------------------------------------------- streaks

## Black water streaks (desert varnish), bleeding down from [param sources]
## (points on ledges, roof lips and crack tops) plus a few from nowhere: bundles
## of parallel stripes with feathered edges that fade out downward, a pale
## bleached streak beside some, and lichen growing on the wet margins near the
## top. [param amount] 0..1 scales how many and how dark.
static func streaks(im: Image, c: Dictionary, rng: RandomNumberGenerator, sources: Array, amount: float, edge: PackedInt32Array) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var starts := sources.duplicate()
	for i in int(w * h / 26000.0 * (0.5 + amount)):
		starts.append(Vector2i(rng.randi_range(10, w - 50), rng.randi_range(-40, h - 100)))
	var dark: Color = (c.streak as Color).lerp(c.seam, 0.3)
	for s: Vector2i in starts:
		if rng.randf() > 0.35 + amount * 0.65:
			continue
		var bundle := rng.randi_range(1, 3 if amount < 0.6 else 5)
		var length := rng.randi_range(60, int(140 + 260 * amount))
		var strength := rng.randf_range(0.22, 0.32 + 0.25 * amount)
		var seed_value := rng.randi()
		var x := float(s.x)
		for b in bundle:
			var sw := rng.randi_range(1, 4)
			var len_b := int(length * rng.randf_range(0.5, 1.0))
			var xb := x + rng.randi_range(0, 3)
			for k in len_b:
				var y := s.y + k
				if y < 0:
					continue
				if y >= h:
					break
				var t := float(k) / len_b
				# full strength just under the source, fading out downward
				var fade := minf(t * 6.0, 1.0) * (1.0 - t * t)
				var cx := int(xb + P.smooth_noise(0.5, y * 0.04, seed_value + b) * 3.0 - 1.5)
				var lim := edge[y] - 5 if y < edge.size() else w - 30
				for dx in range(-sw, sw + 1):
					var xx := cx + dx
					if xx < 0 or xx >= lim:
						continue
					var side := absf(dx) / maxf(sw, 1)
					var a := strength * fade * (1.0 - side * 0.5)
					# feathered edges: the outer pixels dither out
					if side >= 0.99 and not P.dither(xx, y, 0.45 * fade):
						continue
					tint(im, xx, y, dark, a)
				# lichen and moss on the wet margin near the top
				if t < 0.3 and P.noise(cx, y, seed_value) < 0.03 * amount + 0.01:
					var col: Color = [c.lichen_g, c.lichen_y, c.lichen_o, c.moss][rng.randi() % 4]
					var lx := cx + (sw + 1 if rng.randf() < 0.5 else -sw - 1)
					if lx > 0 and lx < lim:
						im.set_pixel(lx, y, col)
						if lx + 1 < lim:
							im.set_pixel(lx + 1, y, col.darkened(0.15))
						if y + 1 < h:
							im.set_pixel(lx, y + 1, col.darkened(0.2))
			x += sw * 2 + rng.randi_range(2, 6)
		# A bleached streak beside the dark ones: water that ran clean.
		if rng.randf() < 0.4:
			var bx := int(x) + 2
			for k in int(length * 0.7):
				var y := s.y + k
				if y < 0 or y >= h:
					continue
				var lim2 := edge[y] - 5 if y < edge.size() else w - 30
				for dx in 2:
					if bx + dx < lim2 and P.dither(bx + dx, y, 0.6 * (1.0 - float(k) / length)):
						lighten(im, bx + dx, y, 0.07)


# ---------------------------------------------------------------- shadow

## A soft shadow under a ledge or roof, [param x0]..[param x1] wide, from
## [param y] down, [param depth] pixels deep at its deepest and varying along
## the ledge, dithered out at its foot.
static func shadow_below(im: Image, x0: int, x1: int, y: int, depth: float, seed_value: int) -> void:
	for x in range(maxi(x0, 0), mini(x1, im.get_width())):
		var d := int(depth * (0.45 + 0.75 * P.smooth_noise(x * 0.05, 2.0, seed_value)))
		for k in d:
			var t := float(k) / maxf(d, 1)
			if t > 0.6 and not P.dither(x, y + k, (1.0 - t) * 2.0):
				continue
			darken(im, x, y + k, 0.34 * (1.0 - t * 0.7))


## Darkens a little around [param p] in a ring [param r] wide: the cavity
## where the rock turns in, under holds and inside cracks.
static func cavity(im: Image, p: Vector2i, r: int, amount: float) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := sqrt(dx * dx + dy * dy)
			if d <= r:
				darken(im, p.x + dx, p.y + dy, amount * (1.0 - d / (r + 1)))


# ---------------------------------------------------------------- planes

## Big facets of the wall, [param count] of them: tall bands of rock turned
## a little away from the sun (a shade darker, darkest against the corner
## they make) or toward it (a shade lighter), each with a sharp arête where it
## starts, so the face reads as planes of rock and not one flat sheet.
static func planes(im: Image, rng: RandomNumberGenerator, edge: PackedInt32Array, count: int) -> void:
	var w := im.get_width()
	var h := im.get_height()
	for i in count:
		var x0 := rng.randf_range(10.0, w - 110.0)
		var width := rng.randf_range(36.0, 90.0)
		var y0 := rng.randi_range(-60, h - 160)
		var length := rng.randi_range(160, 480)
		var away := rng.randf() < 0.65
		var amount := rng.randf_range(0.09, 0.16) if away else rng.randf_range(0.05, 0.09)
		var slant := rng.randf_range(-0.08, 0.08)
		var seed_value := rng.randi()
		for k in length:
			var y := y0 + k
			if y < 0 or y >= h:
				continue
			var t := float(k) / length
			var fade := minf(minf(t, 1.0 - t) * 5.0, 1.0)
			var left := int(x0 + slant * k + P.smooth_noise(k * 0.04, 2.0, seed_value) * 6.0)
			var right := int(left + width * (0.75 + 0.5 * P.smooth_noise(k * 0.02, 5.0, seed_value)))
			var lim := edge[y] - 6 if y < edge.size() else w - 30
			right = mini(right, lim)
			if right <= left + 4:
				continue
			for x in range(maxi(left, 0), right):
				var across := float(x - left) / (right - left)
				# darkest near the arête, easing off across the plane
				var a := amount * fade * (1.0 - across * 0.6)
				if across > 0.85 and not P.dither(x, y, (1.0 - across) * 6.0):
					continue
				if away:
					darken(im, x, y, a)
				else:
					lighten(im, x, y, a)
			# the arête: a lit edge where the plane turns away from the sun
			if away and fade > 0.3:
				lighten(im, left - 1, y, 0.16 * fade)
				darken(im, left, y, 0.1 * fade)


## Royal Arches' great curving shells: [param count] arcs of exfoliating
## granite, each a lit lip with a dark undercut and shadow under it, the rock
## within the curve a little recessed.
static func arches(im: Image, rng: RandomNumberGenerator, edge: PackedInt32Array, count: int) -> void:
	var w := im.get_width()
	var h := im.get_height()
	for i in count:
		var cx := rng.randf_range(40.0, w - 80.0)
		var cy := rng.randf_range(60.0, h + 40.0)
		var rx := rng.randf_range(70.0, 170.0)
		var ry := rng.randf_range(40.0, 110.0)
		var depth := rng.randf_range(3.0, 6.0)
		var a0 := rng.randf_range(0.0, 0.5)
		var a1 := PI - rng.randf_range(0.0, 0.5)
		var steps := int(rx * PI * 1.6)
		var last := Vector2i(-999, -999)
		for k in steps:
			var t := lerpf(a0, a1, float(k) / steps)
			var x := int(cx + rx * cos(t))
			var y := int(cy - ry * sin(t))
			if Vector2i(x, y) == last:
				continue
			last = Vector2i(x, y)
			if y < 0 or y >= h or x < 2 or x >= (edge[y] - 6 if y < edge.size() else w - 30):
				continue
			var taper := minf(minf(t - a0, a1 - t) * 3.0, 1.0)
			# the shell's lit lip, two pixels thick, then the undercut and a
			# wide soft shadow on the rock below
			lighten(im, x, y - 2, 0.08 * taper)
			lighten(im, x, y - 1, 0.18 * taper)
			lighten(im, x, y, 0.2 * taper)
			darken(im, x, y + 1, 0.3 * taper)
			for s in int(depth * 2.0 * taper):
				var f := float(s) / (depth * 2.0)
				if f > 0.6 and not P.dither(x, y + 2 + s, (1.0 - f) * 2.5):
					continue
				darken(im, x, y + 2 + s, 0.2 * (1.0 - f) * taper)
		# the recess under the arch
		for yy in range(int(cy - ry * 0.9), int(cy)):
			if yy < 0 or yy >= h:
				continue
			var span := rx * sqrt(maxf(1.0 - pow((cy - yy) / ry, 2.0), 0.0)) * 0.9
			for xx in range(int(cx - span), int(cx + span)):
				if xx > 1 and xx < (edge[yy] - 6 if yy < edge.size() else w - 30) and P.dither(xx, yy, 0.5):
					darken(im, xx, yy, 0.05)


## Glacier polish: smooth, pale patches with ragged edges where the ice
## ground the granite glassy. [param amount] 0..1 is how much of the face;
## polished pixels carry [param alpha] so the fine grain leaves them smooth.
static func polish(im: Image, rng: RandomNumberGenerator, edge: PackedInt32Array, amount: float, alpha: int) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.55
	var field := noise.get_image(w, h, false, false, true).get_data()
	var cut := int(255 * (1.0 - amount * 0.45))
	var data := im.get_data().to_int32_array()
	for y in h:
		var lim := edge[y] - 6 if y < edge.size() else w - 30
		var row := y * w
		for x in mini(lim, w):
			var v := field[row + x]
			if v < cut:
				continue
			var p := data[row + x]
			if ((p >> 24) & 0xff) != 0xff:
				continue
			var col := Color8(p & 0xff, (p >> 8) & 0xff, (p >> 16) & 0xff).lightened(0.04 + 0.05 * float(v - cut) / maxf(255 - cut, 1))
			data[row + x] = col.r8 | (col.g8 << 8) | (col.b8 << 16) | (alpha << 24)
	im.set_data(w, h, false, Image.FORMAT_RGBA8, data.to_byte_array())
