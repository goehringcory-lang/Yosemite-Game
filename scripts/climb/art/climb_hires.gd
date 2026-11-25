class_name ClimbHiRes
extends RefCounted
## The climbing screen's 32px finish. The screen is laid out on the 480 x 270
## menu grid (see UiScale) and its painters work on that grid, so on their
## own they show the old 16px-era blocks, two screen pixels to each painted
## one. Every picture they paint comes through here on its way to the screen:
##
## - **Scale2x** doubles it the way tools/art32 doubled the rest of the game's
##   art: stair-stepped edges (skylines, cloud rims, flakes, the climber's
##   limbs) come out one screen pixel smoother, flat areas stay flat.
## - **Granite grain** (the wall only) paints each formation's stone back in
##   at full resolution: biotite flecks and feldspar specks, El Capitan's salt
##   and pepper, the big crystals that weather out as Cathedral Peak's knobs,
##   the glassy sheen of polished slab, glints in the ice.
## - **Wet rock** darkens the face and runs water streaks down it on a wet
##   day (see WallWeather), with a wet sheen catching the light.
##
## The textures report their old size ([method ImageTexture.set_size_override]),
## so every painter, layout constant and draw call stays on the 480 x 270
## grid while each texel lands on one screen pixel.

## Pictures this big or bigger are scaled in bands on the worker threads.
const PARALLEL_PIXELS := 20000
const BANDS := 8

## Grain per formation, as chances (0..255 of a byte) per screen pixel:
## [dark flecks, light specks, crystals, glints].
const GRAIN := {
	"apron": [10, 12, 0, 1],
	"polished": [5, 6, 0, 3],
	"golden": [14, 16, 2, 1],
	"orange": [14, 14, 2, 1],
	"dark": [18, 8, 1, 1],
	"pale": [9, 18, 2, 1],
	"roof": [14, 8, 1, 1],
	"elcap": [22, 22, 3, 1],
	"arches": [12, 12, 1, 1],
	"dome": [8, 10, 0, 1],
	"knobby": [14, 12, 9, 1],
	"columbia": [16, 10, 1, 2],
	"ice": [0, 6, 0, 5],
}
## How much the grain lightens and darkens a pixel.
const FLECK_DARK := 0.11
const SPECK_LIGHT := 0.08
const GLINT_LIGHT := 0.32
## Wet rock: darker overall, darker still in the streaks, and glossy.
const WET_DARK := 0.2
const STREAK_DARK := 0.3
const WET_TINT := Color(0.18, 0.22, 0.32)
const WET_GLINTS := 4


## A texture of [param im] at twice the density, reporting [param im]'s size.
static func texture(im: Image) -> ImageTexture:
	var tex := ImageTexture.create_from_image(scale2x(im))
	tex.set_size_override(im.get_size())
	return tex


## The wall picture as a texture: doubled, with its granite's grain and, when
## [param wet] > 0 (0..1), wet. [param seed_value] keeps the grain the same for
## the same pitch.
## With a [param ramp] (ClimbRock.colors(...).ramp), the stone is quantized
## to it first and the grain steps along it, so the whole face stays on the
## granite's own tones.
static func wall_texture(im: Image, rock_key: String, wet: float, seed_value: int, ramp := PackedColorArray()) -> ImageTexture:
	var src := _rgba(im)
	if wet > 0.0:
		src = _wet(src, wet, seed_value)
	if not ramp.is_empty():
		src = quantize(src, ramp)
	var detail := {"grain": GRAIN.get(rock_key, GRAIN.apron), "seed": seed_value, "glints": WET_GLINTS if wet > 0.0 else 0}
	if not ramp.is_empty():
		var ints := PackedInt32Array()
		var index := {}
		for i in ramp.size():
			var v := _int(ramp[i])
			ints.append(v)
			index[v] = i
		detail["ramp"] = ints
		detail["ramp_index"] = index
	var tex := ImageTexture.create_from_image(scale2x(src, detail))
	tex.set_size_override(im.get_size())
	return tex


## [param im] at twice the size by Scale2x, with the wall's grain when
## [param detail] has some ({"grain": [...], "seed": int, "glints": int}).
static func scale2x(im: Image, detail := {}, allow_parallel := true) -> Image:
	var src := _rgba(im)
	var w := src.get_width()
	var h := src.get_height()
	var data := src.get_data().to_int32_array()
	if detail.get("grain", []).is_empty():
		return _scale_plain(src, data, w, h, allow_parallel)
	var out := _bands(h, allow_parallel and w * h >= PARALLEL_PIXELS, func(y0: int, y1: int) -> PackedInt32Array:
		return _scale_rows(data, w, h, y0, y1, detail))
	return Image.create_from_data(w * 2, h * 2, false, Image.FORMAT_RGBA8, out.to_byte_array())


## Scale2x with no grain, the same picture as _scale_rows makes, much faster:
## the engine doubles every pixel (nearest), and only the pixels Scale2x
## would round off are looked at in script. A pixel whose neighbours above
## and below match, or left and right, stays a plain 2x2 block, so a row
## whose rows above and below are the same (most of a sky, a cloud or a far
## ridge) is done already.
static func _scale_plain(src: Image, data: PackedInt32Array, w: int, h: int, allow_parallel := true) -> Image:
	var doubled := src.duplicate() as Image
	doubled.resize(w * 2, h * 2, Image.INTERPOLATE_NEAREST)
	var base := doubled.get_data().to_int32_array()
	var w2 := w * 2
	var out := _bands(h, allow_parallel and w * h >= PARALLEL_PIXELS, func(y0: int, y1: int) -> PackedInt32Array:
		var rows := base.slice(y0 * 2 * w2, y1 * 2 * w2)
		var wm1 := w - 1
		for y in range(y0, y1):
			var row := y * w
			var up := row - w if y > 0 else row
			var dn := row + w if y < h - 1 else row
			if data.slice(up, up + w) == data.slice(dn, dn + w):
				continue
			var o0 := (y - y0) * 2 * w2
			var o1 := o0 + w2
			for x in w:
				var a := data[up + x]
				var d := data[dn + x]
				if a == d:
					continue
				var rx := row + x
				var p := data[rx]
				var c := data[rx - 1] if x > 0 else p
				var b := data[rx + 1] if x < wm1 else p
				if c == b:
					continue
				var ox0 := o0 + (x << 1)
				var ox1 := o1 + (x << 1)
				if c == a:
					rows[ox0] = a
				if a == b:
					rows[ox0 + 1] = b
				if d == c:
					rows[ox1] = c
				if b == d:
					rows[ox1 + 1] = d
		return rows)
	return Image.create_from_data(w2, h * 2, false, Image.FORMAT_RGBA8, out.to_byte_array())


static func _rgba(im: Image) -> Image:
	if im.get_format() == Image.FORMAT_RGBA8:
		return im
	var copy := im.duplicate() as Image
	copy.convert(Image.FORMAT_RGBA8)
	return copy


## Runs [param work] (rows y0..y1 -> their pixels) over [param h] rows, in
## bands on the worker threads when [param parallel], and joins the bands.
static func _bands(h: int, parallel: bool, work: Callable) -> PackedInt32Array:
	if not parallel or h < BANDS * 2:
		return work.call(0, h)
	var rows := ceili(h / float(BANDS))
	var parts := []
	parts.resize(BANDS)
	var task := WorkerThreadPool.add_group_task(func(b: int) -> void:
		parts[b] = work.call(mini(b * rows, h), mini((b + 1) * rows, h)), BANDS)
	WorkerThreadPool.wait_for_group_task_completion(task)
	var out := PackedInt32Array()
	for part: PackedInt32Array in parts:
		out.append_array(part)
	return out


## Scale2x (EPX) on rows y0..y1 of [param data] (w x h RGBA8 pixels as ints),
## with the grain pass on flat pixels. Returns the doubled rows.
static func _scale_rows(data: PackedInt32Array, w: int, h: int, y0: int, y1: int, detail: Dictionary) -> PackedInt32Array:
	var w2 := w * 2
	var out := PackedInt32Array()
	out.resize(maxi(y1 - y0, 0) * 2 * w2)
	var grain: Array = detail.get("grain", [])
	var grained := not grain.is_empty()
	var dark_t := 0
	var light_t := 0
	var crystal_t := 0
	var glint_t := 0
	if grained:
		dark_t = int(grain[0])
		light_t = dark_t + int(grain[1])
		crystal_t = int(grain[2])
		glint_t = int(grain[3]) + int(detail.get("glints", 0))
	var seed_mix: int = int(detail.get("seed", 0)) * 83492791
	var ramp: PackedInt32Array = detail.get("ramp", PackedInt32Array())
	var ramp_index: Dictionary = detail.get("ramp_index", {})
	# Each color's darker and lighter neighbors, worked out once.
	var darker := {}
	var lighter := {}
	var glint := {}
	var wm1 := w - 1
	for y in range(y0, y1):
		var row := y * w
		var up := row - w if y > 0 else row
		var dn := row + w if y < h - 1 else row
		var ox0 := (y - y0) * 2 * w2
		var ox1 := ox0 + w2
		var y_mix := (y * 19349663) ^ seed_mix
		var prev_p := data[row]
		for x in w:
			var rx := row + x
			var p := data[rx]
			var a := data[up + x]
			var d := data[dn + x]
			var c := prev_p
			prev_p = p
			var b := data[rx + 1] if x < wm1 else p
			var e0 := p
			var e1 := p
			var e2 := p
			var e3 := p
			if p == a and p == d and p == c and p == b:
				if grained and (p & 0xff000000) == 0xff000000:
					# A flat pixel of stone: one hash, a byte for each screen pixel.
					var hv := (x * 73856093) ^ y_mix
					hv = ((hv ^ (hv >> 15)) * 2246822519) & 0xffffffffffff
					hv = hv ^ (hv >> 13)
					if not darker.has(p):
						var at: int = ramp_index.get(p, -1)
						if at >= 0:
							# On the granite ramp: a fleck is a tone darker, a
							# speck a tone lighter, a glint three lighter.
							darker[p] = ramp[maxi(at - 1, 0)]
							lighter[p] = ramp[mini(at + 1, ramp.size() - 1)]
							glint[p] = ramp[mini(at + 3, ramp.size() - 1)]
						else:
							var col := _color(p)
							darker[p] = _int(col.darkened(FLECK_DARK))
							lighter[p] = _int(col.lightened(SPECK_LIGHT))
							glint[p] = _int(col.lightened(GLINT_LIGHT))
					var dk: int = darker[p]
					var lt: int = lighter[p]
					if crystal_t > 0 and ((hv >> 32) & 255) < crystal_t:
						# A crystal weathering out: lit on top, its shadow below right.
						e0 = lt
						e1 = lt
						e2 = lt
						e3 = dk
					else:
						var n0 := hv & 255
						var n1 := (hv >> 8) & 255
						var n2 := (hv >> 16) & 255
						var n3 := (hv >> 24) & 255
						if n0 < dark_t:
							e0 = dk
						elif n0 < light_t:
							e0 = lt
						if n1 < dark_t:
							e1 = dk
						elif n1 < light_t:
							e1 = lt
						if n2 < dark_t:
							e2 = dk
						elif n2 < light_t:
							e2 = lt
						if n3 < dark_t:
							e3 = dk
						elif n3 < light_t:
							e3 = lt
						if glint_t > 0 and ((hv >> 40) & 255) < glint_t:
							e1 = glint[p]
			elif a != d and c != b:
				if c == a:
					e0 = a
				if a == b:
					e1 = b
				if d == c:
					e2 = c
				if b == d:
					e3 = d
			out[ox0] = e0
			out[ox0 + 1] = e1
			out[ox1] = e2
			out[ox1 + 1] = e3
			ox0 += 2
			ox1 += 2
	return out


## How far (in Lab, lightness counted fully and colour by half) a pixel may
## be from the nearest ramp tone and still count as stone. Further off are
## lichen, chalk, plants and gear, which keep their colors.
const RAMP_REACH := 16.0
## Each band's 4x4 ordered dither thresholds, 0..1.
const DITHER := [0.03125, 0.53125, 0.15625, 0.65625, 0.78125, 0.28125, 0.90625, 0.40625, 0.21875, 0.71875, 0.09375, 0.59375, 0.96875, 0.46875, 0.84375, 0.34375]


## [param im] with every stone pixel moved onto the [param ramp]: the two
## ramp tones either side of its lightness, mixed by an ordered dither laid
## in the wall's own pixels (so it scrolls with the wall and never swims).
static func quantize(im: Image, ramp: PackedColorArray) -> Image:
	var src := _rgba(im)
	var w := src.get_width()
	var h := src.get_height()
	var data := src.get_data().to_int32_array()
	var labs: Array[Vector3] = []
	var ints := PackedInt32Array()
	for col in ramp:
		labs.append(_lab(col))
		ints.append(_int(col))
	var n := ramp.size()
	var reach2 := RAMP_REACH * RAMP_REACH
	var out := _bands(h, w * h >= PARALLEL_PIXELS, func(y0: int, y1: int) -> PackedInt32Array:
		var rows := data.slice(y0 * w, y1 * w)
		# color -> lo | hi << 8 | mix (0..16) << 16, or -1 to leave it be
		var seen := {}
		for y in range(y0, y1):
			var i := (y - y0) * w
			var dy := (y & 3) << 2
			for x in w:
				var p := rows[i + x]
				if ((p >> 24) & 0xff) < 200:
					continue
				var key := p & 0xffffff
				var pick: int = seen.get(key, -2)
				if pick == -2:
					var lab := _lab(_color(p))
					var best := 0
					var best_d := 1e20
					for k in n:
						var d := lab - labs[k]
						var dist := d.x * d.x + 0.5 * (d.y * d.y + d.z * d.z)
						if dist < best_d:
							best_d = dist
							best = k
					if best_d > reach2:
						pick = -1
					else:
						var other := best
						if lab.x > labs[best].x and best < n - 1:
							other = best + 1
						elif lab.x < labs[best].x and best > 0:
							other = best - 1
						var f := 0.0
						if other != best:
							f = clampf((lab.x - labs[best].x) / (labs[other].x - labs[best].x), 0.0, 1.0)
							# Dither only the middle of the step, so most of the
							# face is solid tones and the checkerboard stays rare.
							f = clampf((f - 0.3) / 0.4, 0.0, 1.0)
						pick = best | (other << 8) | (roundi(f * 16.0) << 16)
					seen[key] = pick
				if pick < 0:
					continue
				var f16 := (pick >> 16) & 0xff
				var idx := pick & 0xff
				if f16 > 0 and DITHER[dy | (x & 3)] * 16.0 < f16:
					idx = (pick >> 8) & 0xff
				rows[i + x] = (ints[idx] & 0xffffff) | (p & 0xff000000)
		return rows)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out.to_byte_array())


## CIE Lab of [param c] (sRGB, D65), as the palette tools reckon it.
static func _lab(c: Color) -> Vector3:
	var lin := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var r: float = lin.call(c.r)
	var g: float = lin.call(c.g)
	var b: float = lin.call(c.b)
	var x := (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
	var y := 0.2126 * r + 0.7152 * g + 0.0722 * b
	var z := (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
	var f := func(t: float) -> float:
		return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	var fx: float = f.call(x)
	var fy: float = f.call(y)
	var fz: float = f.call(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


## Wet rock: every painted pixel darker and cooler, and darker still where
## water streaks run down the face. Streaks follow columns (water runs down
## from cracks and ledges) and fade in and out along their length.
static func _wet(im: Image, wet: float, seed_value: int) -> Image:
	var w := im.get_width()
	var h := im.get_height()
	var data := im.get_data().to_int32_array()
	var streak_x := PackedFloat32Array()
	streak_x.resize(w)
	for x in w:
		streak_x[x] = ClimbPaint.smooth_noise(x * 0.21, 0.5, seed_value + 11)
	var streak_y := PackedFloat32Array()
	streak_y.resize(h)
	for y in h:
		streak_y[y] = ClimbPaint.smooth_noise(0.5, y * 0.035, seed_value + 23)
	var dark := WET_DARK * clampf(wet, 0.0, 1.0)
	var out := _bands(h, w * h >= PARALLEL_PIXELS, func(y0: int, y1: int) -> PackedInt32Array:
		var rows := data.slice(y0 * w, y1 * w)
		var damp := {}
		var streaked := {}
		for y in range(y0, y1):
			var i := (y - y0) * w
			for x in w:
				var p := rows[i + x]
				if (p & 0xff000000) == 0:
					continue
				if streak_x[x] * (0.6 + 0.4 * streak_y[y]) > 0.58:
					if not streaked.has(p):
						streaked[p] = _int(_color(p).darkened(STREAK_DARK).lerp(WET_TINT, 0.12))
					rows[i + x] = streaked[p]
				elif dark > 0.0:
					if not damp.has(p):
						damp[p] = _int(_color(p).darkened(dark).lerp(WET_TINT, 0.08 * wet))
					rows[i + x] = damp[p]
		return rows)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out.to_byte_array())


static func _color(v: int) -> Color:
	return Color8(v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255)


static func _int(col: Color) -> int:
	return col.r8 | (col.g8 << 8) | (col.b8 << 16) | (col.a8 << 24)
