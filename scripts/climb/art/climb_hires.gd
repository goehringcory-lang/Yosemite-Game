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
static func wall_texture(im: Image, rock_key: String, wet: float, seed_value: int) -> ImageTexture:
	var src := _rgba(im)
	if wet > 0.0:
		src = _wet(src, wet, seed_value)
	var detail := {"grain": GRAIN.get(rock_key, GRAIN.apron), "seed": seed_value, "glints": WET_GLINTS if wet > 0.0 else 0}
	var tex := ImageTexture.create_from_image(scale2x(src, detail))
	tex.set_size_override(im.get_size())
	return tex


## [param im] at twice the size by Scale2x, with the wall's grain when
## [param detail] has some ({"grain": [...], "seed": int, "glints": int}).
static func scale2x(im: Image, detail := {}) -> Image:
	var src := _rgba(im)
	var w := src.get_width()
	var h := src.get_height()
	var data := src.get_data().to_int32_array()
	var out := _bands(h, w * h >= PARALLEL_PIXELS, func(y0: int, y1: int) -> PackedInt32Array:
		return _scale_rows(data, w, h, y0, y1, detail))
	return Image.create_from_data(w * 2, h * 2, false, Image.FORMAT_RGBA8, out.to_byte_array())


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
	var seed_value: int = detail.get("seed", 0)
	# Each color's darker and lighter neighbors, worked out once.
	var darker := {}
	var lighter := {}
	var glint := {}
	for y in range(y0, y1):
		var row := y * w
		var up := row - w if y > 0 else row
		var dn := row + w if y < h - 1 else row
		var o0 := (y - y0) * 2 * w2
		var o1 := o0 + w2
		for x in w:
			var p := data[row + x]
			var a := data[up + x]
			var d := data[dn + x]
			var c := data[row + x - 1] if x > 0 else p
			var b := data[row + x + 1] if x < w - 1 else p
			var e0 := p
			var e1 := p
			var e2 := p
			var e3 := p
			if c == a and c != d and a != b:
				e0 = a
			if a == b and a != c and b != d:
				e1 = b
			if d == c and d != b and c != a:
				e2 = c
			if b == d and b != a and d != c:
				e3 = d
			if grained and p == a and p == b and p == c and p == d and (p & 0xff000000) != 0:
				# A flat pixel of stone: one hash, a byte for each screen pixel.
				var hv := (x * 73856093) ^ (y * 19349663) ^ (seed_value * 83492791)
				hv = ((hv ^ (hv >> 15)) * 2246822519) & 0xffffffffffff
				hv = hv ^ (hv >> 13)
				if not darker.has(p):
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
					e0 = dk if n0 < dark_t else (lt if n0 < light_t else e0)
					e1 = dk if n1 < dark_t else (lt if n1 < light_t else e1)
					e2 = dk if n2 < dark_t else (lt if n2 < light_t else e2)
					e3 = dk if n3 < dark_t else (lt if n3 < light_t else e3)
					if glint_t > 0 and ((hv >> 40) & 255) < glint_t:
						e1 = glint[p]
			out[o0 + 2 * x] = e0
			out[o0 + 2 * x + 1] = e1
			out[o1 + 2 * x] = e2
			out[o1 + 2 * x + 1] = e3
	return out


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
