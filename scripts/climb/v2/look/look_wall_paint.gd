class_name LookWallPaint
extends RefCounted
## Paints one v2 pitch (a V2Wall) into the pictures the wall shader lights
## (look_wall.gdshader). Painted once per pitch, never per frame; the light,
## the weather and the headlamp are all the shader's.
##
## Three pictures, all over the same patch of rock (the climbable face plus
## LookTuning's margins, so the rock carries on past the line and ends at an
## arete on the right with the valley beyond):
##   height  L8, full density (PX_PER_M): the rock's relief. Big granite
##           forms from stretched noise, joints, cracks as deep as they are
##           wide, and each hold as a real feature: an edge is a lip with a
##           sharp drop on the side you pull from, a jug a deep scoop behind a
##           lip, a sloper a soft bulge, a pocket a hole, a pinch a rib, a horn
##           a knob. The shader lights the slopes, so holds read by their
##           shadows the way real ones do, never by colour.
##   sheets  L8, full width, half the rows: exfoliation plates the shader
##           adds to the height (cell noise; kept apart so it stays crisp).
##   tone    RG8, quarter density: R = how pale the stone is (stains, dikes),
##           G = rock (255) or sky past the arete (0).
##   marks   RGBA8, half density: R = black water streaks, G = lichen,
##           B = chalk on the holds people use, A = wet rock.
## Nothing here draws from the session's random streams: each pitch seeds
## its own generator, so the same wall always paints the same.

const T := preload("res://scripts/climb/v2/look/look_tuning.gd")
const PPM := ClimbV2.PX_PER_M


## Paints [param wall]. Returns {"height", "sheets", "tone", "marks": Image, "rect":
## Rect2 (the wall metres covered, y up: position = lower left), "arete": x of
## the arete in metres}.
static func paint(wall: V2Wall, seed_value := 0) -> Dictionary:
	var rect := area(wall)
	var w := int(ceil(rect.size.x * PPM))
	var h := int(ceil(rect.size.y * PPM))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, wall.route_id, wall.pitch, "look"])
	var height := _relief(w, h, wall, rng)
	var marks := Image.create_empty(maxi(1, w / 2), maxi(1, h / 2), false, Image.FORMAT_RGBA8)
	var arete := wall.size.x + T.MARGIN_RIGHT
	_joints(height, rect, wall, rng)
	for c in wall.cracks:
		_crack(height, marks, rect, c)
	for z in wall.zones:
		_zone(height, marks, rect, z, rng)
	# A belay ledge to stand on at the foot of every pitch after the first.
	if wall.pitch > 0 and str(wall.info.get("belay", "ledge")) != "hanging":
		_ledge(height, rect, wall.start.x - 1.6, wall.start.x + 1.6, wall.start.y - 0.05, 0.3)
	_streaks(marks, rect, wall, rng)
	_lichen(marks, rect, wall, rng)
	for hold in wall.holds:
		_hold(height, marks, rect, hold)
	var tone := _tone(w, h, rect, wall, arete, rng)
	var sheets := _sheets(w, h, wall, rng)
	return {"height": height, "sheets": sheets, "tone": tone, "marks": marks, "rect": rect, "arete": arete}


## The patch of wall metres a pitch's pictures cover (lower left + size).
static func area(wall: V2Wall) -> Rect2:
	var x0 := -T.MARGIN_LEFT
	var y0 := wall.start.y - T.MARGIN_BELOW
	var x1 := wall.size.x + T.MARGIN_RIGHT + 0.8
	var y1 := maxf(wall.size.y, wall.top.y) + T.MARGIN_ABOVE
	return Rect2(x0, y0, x1 - x0, y1 - y0)


## A wall spot as a pixel in a picture of [param rect] at [param density]
## pixels a metre (y down in the picture).
static func to_px(p: Vector2, rect: Rect2, density := PPM) -> Vector2:
	return Vector2(p.x - rect.position.x, rect.end.y - p.y) * density


# ------------------------------------------------------------------ relief

## Granite: broad forms stretched up and down the face (it weathers in
## vertical flutes and sheets), on a smoother base for slabs.
static func _relief(w: int, h: int, wall: V2Wall, rng: RandomNumberGenerator) -> Image:
	var smooth := wall.style in [&"slab", &"dike", &"snow", &"ice"]
	var forms := FastNoiseLite.new()
	forms.seed = rng.randi()
	forms.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	forms.fractal_type = FastNoiseLite.FRACTAL_FBM
	forms.fractal_octaves = 4
	forms.fractal_gain = 0.5
	forms.frequency = 0.02
	# Half as many columns and a quarter as many rows, then stretched: the
	# forms run up the face, and the noise costs an eighth.
	var im := forms.get_image(maxi(2, w / 2), maxi(2, h / 4), false, false, true)
	im.convert(Image.FORMAT_L8)
	im.resize(w, h, Image.INTERPOLATE_CUBIC)
	var data := im.get_data()
	var k := 0.4 if smooth else 0.55
	for i in data.size():
		data[i] = 80 + int(data[i] * k)
	return Image.create_from_data(w, h, false, Image.FORMAT_L8, data)


## Sheets and facets: flat plates with steps between them, the way granite
## exfoliates (the steps catch the light or throw a shadow). Full width,
## half the rows (stretched up the face); the shader adds it to the height.
static func _sheets(w: int, h: int, wall: V2Wall, rng: RandomNumberGenerator) -> Image:
	var smooth := wall.style in [&"slab", &"dike", &"snow", &"ice"]
	var cells := FastNoiseLite.new()
	cells.seed = rng.randi()
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	cells.frequency = 0.011 if smooth else 0.015
	cells.fractal_type = FastNoiseLite.FRACTAL_NONE
	cells.domain_warp_enabled = true
	cells.domain_warp_amplitude = 22.0
	cells.domain_warp_frequency = 0.012
	var im := cells.get_image(w, maxi(2, h / 2), false, false, true)
	im.convert(Image.FORMAT_L8)
	return im


## Adds [param amount] (0..1 of full height, may be negative) at pixel
## [param x], [param y].
static func _bump(im: Image, x: int, y: int, amount: float) -> void:
	if x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height():
		return
	var v := im.get_pixel(x, y).r + amount
	im.set_pixel(x, y, Color(clampf(v, 0.0, 1.0), 0, 0))


## Joints: long thin grooves wandering up the margins and across the face,
## the seams granite breaks along.
static func _joints(im: Image, rect: Rect2, wall: V2Wall, rng: RandomNumberGenerator) -> void:
	var count := 2 + int(rect.size.y / 14.0)
	for j in count:
		var x := rng.randf_range(rect.position.x + 0.5, rect.end.x - 1.5)
		var y := rng.randf_range(rect.position.y, rect.end.y - 4.0)
		var length := rng.randf_range(3.0, 12.0)
		var lean := rng.randf_range(-0.25, 0.25)
		# A third of them run across, the way sheets peel.
		var across := rng.randf() < 0.3
		var p := Vector2(x, y)
		var walked := 0.0
		while walked < length:
			var dir := Vector2(1.0, lean).normalized() if across else Vector2(lean, 1.0).normalized()
			lean = clampf(lean + rng.randf_range(-0.08, 0.08), -0.4, 0.4)
			var q := to_px(p, rect)
			_bump(im, int(q.x), int(q.y), -0.14)
			_bump(im, int(q.x) + 1, int(q.y), -0.05)
			p += dir / PPM
			walked += 1.0 / PPM


## A crack: a dark core as wide as the crack is (Camalot scale -> pixels),
## lips either side, narrower just under each constriction, soft and wide
## where it flares. Damp below, so a faint dark streak runs down from it.
static func _crack(im: Image, marks: Image, rect: Rect2, c: V2Crack) -> void:
	if c.points.size() < 2:
		return
	var pinch := {}
	for i in c.constrictions:
		pinch[i] = true
	for i in c.points.size() - 1:
		var a := c.points[i]
		var b := c.points[i + 1]
		var seg := a.distance_to(b)
		var steps := maxi(1, int(seg * PPM))
		for s in steps + 1:
			var f := float(s) / steps
			var p := a.lerp(b, f)
			var width := lerpf(c.widths[i], c.widths[mini(i + 1, c.widths.size() - 1)], f)
			# The crack narrows just under a constriction (where a nut seats).
			if pinch.has(i + 1) and f > 0.7:
				width *= lerpf(1.0, 0.55, (f - 0.7) / 0.3)
			var half := (T.CRACK_PX_MIN + maxf(width, 0.0) * T.CRACK_PX_PER) * 0.5
			var flare_px := c.flare * 3.0
			var q := to_px(p, rect)
			# Real cracks wander a pixel or so either way.
			q.x += sin(q.y * 0.11 + i) * 0.8 + sin(q.y * 0.37) * 0.5
			var reach := int(ceil(half + flare_px + 2.0))
			for dx in range(-reach, reach + 1):
				var x := int(q.x) + dx
				var y := int(q.y)
				var d := absf(float(dx))
				if d <= half:
					# The deep inside: darker the wider it is.
					_set_low(im, x, y, 0.08 + 0.1 * (1.0 - clampf(width / 7.0, 0.0, 1.0)))
				elif d <= half + flare_px:
					_bump(im, x, y, -0.18 * (1.0 - (d - half) / maxf(flare_px, 0.01)))
				elif d <= half + flare_px + 2.0:
					# Lips: proud on the sunny left, dipping off on the right.
					_bump(im, x, y, 0.07 if dx < 0 else 0.03)
			var mq := to_px(p, rect, PPM * 0.5)
			_mark(marks, int(mq.x), int(mq.y) + 1, 0, 0.18)


static func _set_low(im: Image, x: int, y: int, v: float) -> void:
	if x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height():
		return
	im.set_pixel(x, y, Color(minf(im.get_pixel(x, y).r, v), 0, 0))


## Adds [param amount] to channel [param ch] (0 R .. 3 A) of a marks pixel.
static func _mark(im: Image, x: int, y: int, ch: int, amount: float) -> void:
	if x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height():
		return
	var c := im.get_pixel(x, y)
	c[ch] = clampf(c[ch] + amount, 0.0, 1.0)
	im.set_pixel(x, y, c)


## Zones the rock shows: ledges stand out with a flat top, wet streaks seep
## down from their top edge.
static func _zone(im: Image, marks: Image, rect: Rect2, z: V2Zone, rng: RandomNumberGenerator) -> void:
	match z.kind:
		&"ledge", &"bivy":
			var y := z.rect.end.y
			_ledge(im, rect, z.rect.position.x, z.rect.end.x, y, 0.26)
		&"wet":
			var x := z.rect.position.x
			while x < z.rect.end.x:
				var reach := z.rect.size.y * rng.randf_range(0.6, 1.4)
				var wide := rng.randf_range(0.08, 0.3)
				var y := z.rect.end.y
				while y > z.rect.end.y - reach:
					var f := (z.rect.end.y - y) / reach
					for dx in range(-int(wide * PPM * 0.5), int(wide * PPM * 0.5) + 1):
						var q := to_px(Vector2(x, y), rect, PPM * 0.5)
						_mark(marks, int(q.x) + dx, int(q.y), 3, 0.5 * (1.0 - f))
						_mark(marks, int(q.x) + dx, int(q.y), 0, 0.12 * (1.0 - f))
					y -= 1.0 / (PPM * 0.5)
				x += rng.randf_range(0.15, 0.5)


## A ledge: a shelf with a flat top and a dark drop under its lip.
static func _ledge(im: Image, rect: Rect2, x0: float, x1: float, y: float, amount: float) -> void:
	var a := to_px(Vector2(x0, y), rect)
	var b := to_px(Vector2(x1, y), rect)
	for x in range(int(a.x), int(b.x) + 1):
		var edge := minf(x - a.x, b.x - x)
		var fade := clampf(edge / 6.0, 0.0, 1.0)
		for dy in range(-6, 3):
			# The top runs back flat; under the lip it drops away.
			var v := amount * fade * (1.0 if dy <= 0 else (1.0 - dy / 3.0))
			_bump(im, x, int(a.y) + dy, v - (0.12 * fade if dy == 2 else 0.0))


## Yosemite's black water streaks: dark stripes down from the top where
## winter melt runs, some long, some short.
static func _streaks(marks: Image, rect: Rect2, wall: V2Wall, rng: RandomNumberGenerator) -> void:
	var count := rng.randi_range(2, 4)
	for s in count:
		var x := rng.randf_range(rect.position.x + 0.5, rect.end.x - 1.5)
		var wide := rng.randf_range(0.4, 1.2)
		var reach := rect.size.y * rng.randf_range(0.3, 0.8)
		var y := rect.end.y
		var drift := 0.0
		while y > rect.end.y - reach:
			var f := (rect.end.y - y) / reach
			drift += rng.randf_range(-0.01, 0.01)
			var q := to_px(Vector2(x + drift, y), rect, PPM * 0.5)
			var half := int(wide * PPM * 0.25 * (1.0 - f * 0.5))
			for dx in range(-half, half + 1):
				var edge := 1.0 - absf(float(dx)) / maxf(half, 1)
				_mark(marks, int(q.x) + dx, int(q.y), 0, 0.5 * edge * (1.0 - f) * rng.randf_range(0.7, 1.0))
			y -= 1.0 / (PPM * 0.5)


## Lichen: a few patches, thickest off the line where nobody's hands go.
static func _lichen(marks: Image, rect: Rect2, wall: V2Wall, rng: RandomNumberGenerator) -> void:
	var count := int(rect.size.y * 1.2)
	for i in count:
		var x := rng.randf_range(rect.position.x, rect.end.x - 1.0)
		# Off the climbable face mostly.
		if x > 0.3 and x < wall.size.x - 0.3 and rng.randf() < 0.75:
			continue
		var y := rng.randf_range(rect.position.y, rect.end.y)
		var r := rng.randf_range(0.08, 0.3) * PPM * 0.5
		var c := to_px(Vector2(x, y), rect, PPM * 0.5)
		for dy in range(-int(r), int(r) + 1):
			for dx in range(-int(r), int(r) + 1):
				var d := Vector2(dx, dy * 1.4).length() / r
				if d < 1.0 and rng.randf() < 1.0 - d * 0.6:
					_mark(marks, int(c.x) + dx, int(c.y) + dy, 1, 0.7)


# ------------------------------------------------------------------ holds

## A hold, as rock. Its lip runs across its pull, its sharp drop and shadow
## are on the side you pull from, its size sets how big and deep it is.
## Hand holds people use carry chalk.
static func _hold(im: Image, marks: Image, rect: Rect2, hold: V2Hold) -> void:
	if hold.kind == &"jam":
		return
	var c := to_px(hold.pos, rect)
	# "Up" for the hold: away from the pull, in picture pixels (y down).
	var pull := hold.pull.normalized() if hold.pull.length() > 0.01 else Vector2(0, -1)
	var up := Vector2(-pull.x, pull.y)
	var along := Vector2(up.y, -up.x)
	var s := clampf(hold.size, 0.0, 1.0)
	var foot_only := not hold.hand
	var kind := hold.kind
	if foot_only:
		kind = &"chip"
	var spec := _shape(kind, s)
	var r := int(ceil(maxf(spec.half_len, spec.depth) + 3.0))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := Vector2(dx, dy)
			var u := p.dot(along)
			var v := p.dot(up) # + toward the hold's top face
			var amount := _profile(spec, u, v)
			if amount != 0.0:
				_bump(im, int(c.x) + dx, int(c.y) + dy, amount)
	# Chalk on the top of hand holds: heavy on chalked ones, a little on the rest.
	if hold.hand and not hold.has_tag("hidden"):
		var chalk := 0.75 if hold.has_tag("chalked") else 0.35
		if hold.has_tag("anchor"):
			chalk = 0.0
		var mc := to_px(hold.pos, rect, PPM * 0.5) + up * 1.5
		var cr := maxf(2.0, spec.half_len * 0.5 * 0.8)
		for dy in range(-int(cr) - 1, int(cr) + 2):
			for dx in range(-int(cr) - 1, int(cr) + 2):
				var p := Vector2(dx, dy)
				var d := Vector2(p.dot(along) / cr, p.dot(up) / maxf(cr * 0.5, 1.0)).length()
				if d < 1.0:
					_mark(marks, int(mc.x) + dx, int(mc.y) + dy, 2, chalk * (1.0 - d * d))


## Shape numbers per kind: half the lip's length, how proud it stands, how
## far the top runs back, a scoop behind the lip, round or long.
static func _shape(kind: StringName, s: float) -> Dictionary:
	match kind:
		&"jug":
			return {"half_len": 7.0 + s * 6.0, "height": 0.34 + s * 0.1, "depth": 4.0, "scoop": 0.22, "round": false}
		&"edge":
			return {"half_len": 6.0 + s * 6.0, "height": 0.2 + s * 0.08, "depth": 2.5, "scoop": 0.0, "round": false}
		&"crimp":
			return {"half_len": 3.5 + s * 3.0, "height": 0.14 + s * 0.06, "depth": 1.5, "scoop": 0.0, "round": false}
		&"sloper":
			return {"half_len": 7.0 + s * 5.0, "height": 0.16 + s * 0.06, "depth": 7.0, "scoop": 0.0, "round": true}
		&"pinch":
			return {"half_len": 2.5, "height": 0.24, "depth": 6.0 + s * 4.0, "scoop": 0.0, "round": false, "rib": true}
		&"pocket":
			return {"half_len": 3.0 + s * 3.0, "height": -0.4, "depth": 3.0 + s * 2.0, "scoop": 0.0, "round": true, "hole": true}
		&"horn":
			return {"half_len": 4.0 + s * 3.0, "height": 0.42, "depth": 5.0 + s * 3.0, "scoop": 0.0, "round": true}
		&"stance":
			return {"half_len": 16.0 + s * 18.0, "height": 0.3, "depth": 5.0, "scoop": 0.0, "round": false}
		&"chip":
			return {"half_len": 2.5 + s * 3.0, "height": 0.12, "depth": 1.5, "scoop": 0.0, "round": false}
		_: # undercling, sidepull, gaston: edges facing their own way
			return {"half_len": 5.0 + s * 5.0, "height": 0.2 + s * 0.08, "depth": 2.5, "scoop": 0.0, "round": false}


## Height added at (u along the lip, v toward its top) for a hold [param spec].
static func _profile(spec: Dictionary, u: float, v: float) -> float:
	var half: float = spec.half_len
	var depth: float = spec.depth
	var height: float = spec.height
	if spec.get("hole", false):
		var d := Vector2(u, v).length() / half
		if d < 1.0:
			return height * (1.0 - d * d)
		return 0.08 * (1.0 - (d - 1.0) / 0.4) if d < 1.4 and v > 0.0 else 0.0
	if spec.get("round", false):
		var d := Vector2(u / half, v / depth).length()
		if d >= 1.0:
			return 0.0
		var dome := height * (1.0 - d * d)
		# Horns and slopers drop more sharply on the pull side.
		return dome * (1.0 if v >= 0.0 else 1.0 - absf(v) / depth * 0.4)
	if spec.get("rib", false):
		# A rib running along the pull: symmetric across, tapering at the ends.
		var across := absf(u) / half
		if across >= 1.0 or absf(v) > depth:
			return 0.0
		return height * (1.0 - across * across) * (1.0 - pow(absf(v) / depth, 2.0))
	# A lip: rounded ends, a short steep drop on the pull side (v < 0) where
	# the shadow falls, the top running back over [depth], a scoop behind it.
	var end := clampf((half - absf(u)) / 2.0, 0.0, 1.0)
	if end <= 0.0:
		return 0.0
	var out := 0.0
	if v < 0.0:
		out = height * clampf(1.0 + v / 1.5, 0.0, 1.0)
	elif v <= depth:
		out = height * (1.0 - v / depth * 0.6)
	elif v <= depth + 2.0:
		out = height * 0.4 * (1.0 - (v - depth) / 2.0)
	var scoop: float = spec.scoop
	if scoop > 0.0 and v > 1.0 and v < depth + 2.0:
		out -= scoop * sin(PI * (v - 1.0) / (depth + 1.0))
	return out * end


# ------------------------------------------------------------------ tone

## How pale the stone is (R) and where it is rock at all (G): a slow
## mottling, pale dikes on dike pitches, and a ragged arete on the right.
static func _tone(w: int, h: int, rect: Rect2, wall: V2Wall, arete: float, rng: RandomNumberGenerator) -> Image:
	var tw := maxi(2, w / 4)
	var th := maxi(2, h / 4)
	var n := FastNoiseLite.new()
	n.seed = rng.randi()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.03
	n.fractal_octaves = 3
	var mottle := n.get_image(tw, th, false, false, true).get_data()
	var edge := FastNoiseLite.new()
	edge.seed = rng.randi()
	edge.frequency = 0.08
	edge.fractal_octaves = 3
	var dikes: Array = []
	if wall.style == &"dike":
		for i in 3:
			dikes.append([rng.randf_range(-0.6, 0.6), rng.randf_range(0.0, rect.size.y), rng.randf_range(0.15, 0.4)])
	var data := PackedByteArray()
	data.resize(tw * th * 2)
	var mpp := 4.0 / PPM
	for y in th:
		var wy := rect.end.y - y * mpp
		var jag := edge.get_noise_1d(wy * 6.0) * 0.35 + edge.get_noise_1d(wy * 1.3 + 50.0) * 0.5
		var edge_x := arete + jag
		for x in tw:
			var wx := rect.position.x + x * mpp
			var i := (y * tw + x) * 2
			var pale := 0.45 + (mottle[y * tw + x] / 255.0 - 0.5) * 0.16
			for d: Array in dikes:
				var line: float = wy - d[1] - wx * d[0]
				if absf(line) < d[2]:
					pale += 0.16 * (1.0 - absf(line) / d[2])
			data[i] = clampi(int(pale * 255.0), 0, 255)
			data[i + 1] = 255 if wx < edge_x else 0
	return Image.create_from_data(tw, th, false, Image.FORMAT_RG8, data)
