extends RefCounted
## Pixel art for the Lamon Homestead camp: your tent, the campfire, and the
## Ahwahneechee food stations Tabuce teaches you to use (the chuckah acorn
## granary, the bedrock mortar, and the leaching basin). Drawn in code with
## PixelKit in the same warm palette, dark brown outline and 3/4 view as the
## Curry Village art. Written to assets/sprites/lamon/. Replace any PNG with
## hand-drawn art of the same size at any time.
##
##   godot --headless --path . -s res://tools/hubs/preview_lamon_art.gd

const K = preload("res://tools/hubs/pixel_kit.gd")
const DIR := "res://assets/sprites/lamon/"

const GRANITE := "a9a49a"
const SOIL := "7a5a3c"
const WILLOW := "b89a5c"
const POLE := "6e4a2e"
const CANVAS := "c9b48a"
const ACORN := "a0703c"
const ACORN_MEAL := "d8b878"
const CEDAR := "4f6e3a"
## Frames in the campfire sheet (matches the overlay's frames = 4).
const FIRE_FRAMES := 4


static func c(hex: String) -> Color:
	return Color(hex)


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var sheets := {
		"camp_tent": camp_tent(), "campfire": campfire(),
		"chuckah_empty": chuckah_empty(), "chuckah_built": chuckah_built(),
		"mortar_slab": mortar_slab(), "leaching_basin": leaching_basin(),
	}
	for sprite_name: String in sheets:
		(sheets[sprite_name] as Image).save_png(ProjectSettings.globalize_path(DIR + sprite_name + ".png"))


# ---------------------------------------------------------------- camp

## Your canvas ridge tent: a sun-faded A-frame with the front flaps tied back,
## a bedroll inside, guy lines and stakes. 52x44, standing on its bottom row.
func camp_tent() -> Image:
	var im := K.make(52, 44)
	K.shadow(im, 26.0, 41.0, 23.0, 2.6)
	var canvas := c(CANVAS)
	var shade := canvas.darkened(0.2)
	var lit := canvas.lightened(0.14)
	var apex := Vector2i(26, 6)
	var base_y := 40
	# The two roof slopes, seen from the front: lit on the left, shaded on the right.
	for y in range(apex.y, base_y + 1):
		var t := float(y - apex.y) / float(base_y - apex.y)
		var half := int(round(2.0 + t * 20.0))
		for x in range(26 - half, 26 + half + 1):
			var col := lit if x < 26 else shade
			# seams running down each slope
			if (x - 26) != 0 and absi(x - 26) % 6 == 0:
				col = col.darkened(0.1)
			if K.hash2(x, y, 41) > 0.93:
				col = col.darkened(0.06)
			K.px(im, x, y, col)
	# The open doorway and the dark inside.
	for y in range(18, base_y + 1):
		var t := float(y - 18) / float(base_y - 18)
		var half := int(round(1.0 + t * 8.0))
		K.hline(im, 26 - half, y, half * 2 + 1, c("3a2a20"))
	# A rolled bedroll inside and a lantern glow on the floor.
	K.rect(im, 21, 35, 10, 4, c("8a3a3a"))
	K.hline(im, 21, 35, 10, c("a85050"))
	K.vline(im, 24, 35, 4, c("6a2a2a"))
	K.vline(im, 28, 35, 4, c("6a2a2a"))
	# Front flaps tied back on either side of the door.
	for side in [-1, 1]:
		for y in range(20, base_y + 1):
			var t := float(y - 20) / float(base_y - 20)
			var x0: int = 26 + side * int(round(2.0 + t * 8.0))
			for k in 3:
				K.px(im, x0 + side * k, y, (lit if side < 0 else shade).darkened(0.08 * k))
		K.hline(im, 26 + side * 7 - (2 if side > 0 else 0), 29, 3, c("6e4a2e"))
	# Ridge pole and front upright.
	K.rect(im, 25, 3, 2, 4, c(POLE))
	K.px(im, 25, 2, c(POLE).lightened(0.2))
	K.hline(im, apex.x - 1, apex.y, 3, lit.lightened(0.1))
	# Hem along the ground and a dirt sill at the door.
	K.hline(im, 4, base_y, 44, canvas.darkened(0.35))
	K.hline(im, 18, base_y, 17, c(SOIL))
	K.outline(im)
	# Guy lines and stakes, outside the outline pass so they stay thin.
	var line := c("e8dcc0")
	for side in [-1, 1]:
		var from := Vector2(26 + side * 13, 24)
		var to := Vector2(26 + side * 24, 40)
		for i in 13:
			var p := from.lerp(to, i / 12.0)
			K.px(im, int(round(p.x)), int(round(p.y)), line)
		K.rect(im, int(to.x) - (1 if side > 0 else 0), 39, 2, 3, c(POLE))
	return im


## A ring of river stones around crossed logs and a fire. Four frames side by
## side, 32x28 each; the flames lick and shift between them.
func campfire() -> Image:
	var fw := 32
	var fh := 28
	var sheet := K.make(fw * FIRE_FRAMES, fh)
	for f in FIRE_FRAMES:
		var im := _campfire_frame(f, fw, fh)
		sheet.blit_rect(im, Rect2i(0, 0, fw, fh), Vector2i(f * fw, 0))
	return sheet


func _campfire_frame(f: int, w: int, h: int) -> Image:
	var im := K.make(w, h)
	var cx := w / 2.0
	var gy := float(h - 6)
	K.shadow(im, cx, gy + 2.0, 14.0, 3.5, 0.28)
	# Ash bed.
	K.ellipse(im, cx, gy, 10.0, 3.6, c("3a3230"))
	K.ellipse(im, cx, gy - 0.5, 7.0, 2.4, c("5a4a44"))
	# Back half of the stone ring (drawn before the fire).
	var stones: Array = []
	for i in 10:
		var a := TAU * i / 10.0 + 0.3
		stones.append(Vector3(cx + cos(a) * 11.5, gy + sin(a) * 4.2, sin(a)))
	for s: Vector3 in stones:
		if s.z < 0.0:
			_stone(im, s.x, s.y, i_hash(s), 2.6, 2.0)
	# Crossed logs.
	_log(im, Vector2(cx - 7, gy + 1), Vector2(cx + 5, gy - 3))
	_log(im, Vector2(cx + 7, gy + 1), Vector2(cx - 5, gy - 3))
	# Embers.
	for i in 6:
		var ex := int(cx - 5 + K.hash2(i, f, 3) * 10.0)
		var ey := int(gy - 1 + K.hash2(i, f, 4) * 2.0)
		K.px(im, ex, ey, c("ff9a30") if (i + f) % 2 else c("ffd060"))
	# Flames: three tongues whose heights and sway change frame to frame.
	var sway: int = [0, 1, 0, -1][f]
	var heights: Array = [[12, 16, 10], [14, 13, 12], [11, 17, 9], [13, 14, 13]][f]
	var xs := [cx - 4.0, cx, cx + 4.0]
	for i in 3:
		_flame(im, xs[i] + sway * (1 if i != 1 else 0), gy - 2.0, 3.2 - absf(i - 1) * 0.5, heights[i], f + i)
	# Front half of the ring, over the logs.
	for s: Vector3 in stones:
		if s.z >= 0.0:
			_stone(im, s.x, s.y, i_hash(s), 2.8, 2.1)
	K.outline(im)
	# Sparks above the outline pass.
	for i in 2:
		var sx := int(cx - 3 + K.hash2(i, f, 9) * 6.0)
		var sy := int(gy - 18 - K.hash2(i, f, 10) * 4.0)
		K.px(im, sx, sy, c("ffd060"))
	return im


func i_hash(v: Vector3) -> int:
	return int(v.x * 7.0 + v.y * 13.0)


func _speckled_ellipse(im: Image, cx: float, cy: float, rx: float, ry: float, base: Color, seed_value: int) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy > 1.0:
				continue
			var col := base
			var n := K.hash2(x, y, seed_value)
			if n > 0.9:
				col = col.lightened(0.14)
			elif n < 0.1:
				col = col.darkened(0.14)
			elif n > 0.84:
				col = col.lerp(c("e0d8c8"), 0.5)
			K.px(im, x, y, col)


func _stone(im: Image, x: float, y: float, seed_value: int, rx: float, ry: float) -> void:
	var base := c(GRANITE).darkened(K.hash2(seed_value, 1, 5) * 0.25)
	K.ellipse(im, x, y, rx, ry, base)
	K.px(im, int(x - 1), int(y - 1), base.lightened(0.25))
	K.hline(im, int(x - rx + 1), int(y + ry - 0.5), int(rx * 2 - 1), base.darkened(0.3))


func _log(im: Image, a: Vector2, b: Vector2) -> void:
	var steps := int(a.distance_to(b)) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		K.rect(im, int(p.x) - 1, int(p.y) - 1, 3, 3, c("6e4a2e"))
		K.px(im, int(p.x), int(p.y) - 1, c("9a6c44"))
	K.ellipse(im, a.x, a.y, 1.6, 1.6, c("d0a870"))
	K.px(im, int(a.x), int(a.y), c("a07040"))


func _flame(im: Image, x: float, base_y: float, half_w: float, height: int, seed_value: int) -> void:
	for dy in height:
		var t := float(dy) / height
		var w := half_w * (1.0 - t * t) + (0.6 if K.hash2(dy, seed_value, 2) > 0.7 else 0.0)
		var lean := sin(t * 3.0 + seed_value) * 0.8 * t
		var col := c("ffe080")
		if t > 0.75:
			col = c("e0502a")
		elif t > 0.45:
			col = c("ff8a2a")
		elif t > 0.2:
			col = c("ffb840")
		var y := int(base_y) - dy
		for fx in range(int(round(x + lean - w)), int(round(x + lean + w)) + 1):
			K.px(im, fx, y, col)
	# White-hot core at the base.
	K.hline(im, int(x) - 1, int(base_y), 3, c("fff4c0"))
	K.px(im, int(x), int(base_y) - 1, c("fff4c0"))


# ---------------------------------------------------------------- acorns

## The chuckah's spot before it's built: four peeled poles set in the ground,
## bundles of willow and a heap of acorns waiting beside them. 40x30.
func chuckah_empty() -> Image:
	var im := K.make(40, 30)
	K.shadow(im, 20.0, 27.0, 17.0, 2.4)
	# Cleared, tamped ground.
	K.ellipse(im, 20.0, 25.0, 11.0, 3.2, c(SOIL).lightened(0.12))
	# Four poles, the back two shorter and darker.
	for p in [[13, 11, 13, true], [27, 11, 13, true], [11, 7, 19, false], [29, 7, 19, false]]:
		var col := c(POLE) if p[3] else c(POLE).lightened(0.18)
		K.rect(im, p[0], p[1], 2, p[2], col)
		K.px(im, p[0], p[1], col.lightened(0.25))
	# A stick hoop tied across the front poles, the start of the frame.
	K.hline(im, 12, 15, 18, c(WILLOW).darkened(0.15))
	# Willow bundles lying on the ground.
	for b in [[2, 22], [4, 25]]:
		K.rect(im, b[0], b[1], 10, 3, c(WILLOW))
		K.hline(im, b[0], b[1], 10, c(WILLOW).lightened(0.2))
		K.vline(im, b[0] + 4, b[1], 3, c("6e4a2e"))
	# A heap of acorns.
	_acorn_pile(im, 33.0, 25.0, 4)
	K.outline(im)
	return im


## The finished chuckah: a tall basket granary of woven willow and brush on
## a pole frame, raised off the ground and capped with a thatch of boughs.
## 40x58.
func chuckah_built() -> Image:
	var im := K.make(40, 58)
	K.shadow(im, 20.0, 55.0, 16.0, 2.4)
	K.ellipse(im, 20.0, 53.0, 10.0, 2.8, c(SOIL).lightened(0.12))
	# Legs under the basket.
	for x in [12, 26]:
		K.rect(im, x, 40, 2, 14, c(POLE))
	K.rect(im, 19, 42, 2, 12, c(POLE).darkened(0.2))
	# The basket body: a tall barrel of woven courses, widest in the middle.
	var top := 12
	var bottom := 44
	for y in range(top, bottom):
		var t := float(y - top) / float(bottom - top)
		var half := int(round(9.0 + sin(t * PI) * 3.0))
		var course := (y - top) / 2
		for x in range(20 - half, 20 + half):
			var rel := float(x - (20 - half)) / float(half * 2)
			var col := c(WILLOW)
			# weave: alternating stitches in each course
			if ((x + course * 2) / 2) % 2 == 0:
				col = col.darkened(0.12)
			if (y - top) % 2 == 1:
				col = col.darkened(0.05)
			# round it: lit left, shaded right
			col = col.lightened(0.14 * (1.0 - rel * 2.2)) if rel < 0.4 else col.darkened(0.28 * (rel - 0.4) / 0.6)
			K.px(im, x, y, col)
	# Binding hoops of split stick.
	for y in [16, 28, 40]:
		var t := float(y - top) / float(bottom - top)
		var half := int(round(9.0 + sin(t * PI) * 3.0))
		K.hline(im, 20 - half, y, half * 2, c(POLE).lightened(0.1))
	# Upright poles showing outside the basket.
	for x in [9, 30]:
		K.rect(im, x, 10, 1, 36, c(POLE))
	# Cap of fir and cedar boughs, tied down.
	for y in range(2, 14):
		var t := float(y - 2) / 12.0
		var half := int(round(2.0 + t * 12.0))
		for x in range(20 - half, 20 + half + 1):
			var n := K.hash2(x, y, 23)
			var col := c(CEDAR)
			if n > 0.7:
				col = col.lightened(0.18)
			elif n < 0.25:
				col = col.darkened(0.2)
			if x > 20 + half / 2:
				col = col.darkened(0.12)
			K.px(im, x, y, col)
	K.rect(im, 19, 0, 2, 3, c(POLE))
	K.hline(im, 10, 12, 20, c(POLE))
	# A few acorns spilled at the foot.
	_acorn_pile(im, 31.0, 52.0, 2)
	K.outline(im)
	return im


func _acorn_pile(im: Image, cx: float, cy: float, rows: int) -> void:
	for row in rows:
		var count := rows - row + 1
		for i in count:
			var x := cx - count * 1.5 + i * 3.0 + 1.0
			var y := cy - row * 2.0
			K.ellipse(im, x, y, 1.6, 1.4, c(ACORN).darkened(0.1 * ((i + row) % 2)))
			K.px(im, int(x), int(y - 1.5), c("6a4a2a"))


## Bedrock mortar: a low granite outcrop worn with deep grinding holes, a
## stone pestle resting in one and fresh acorn meal in another. 64x24.
func mortar_slab() -> Image:
	var im := K.make(64, 24)
	K.shadow(im, 32.0, 20.5, 30.0, 3.0)
	var granite := c(GRANITE)
	# The rock: a rounded, low outcrop. A darker band for its sloping front,
	# then the lit, weathered top face over it.
	_speckled_ellipse(im, 32.0, 14.5, 30.0, 6.5, granite.darkened(0.26), 18)
	_speckled_ellipse(im, 32.0, 11.0, 29.0, 7.0, granite, 17)
	# Lumps that break up the outline.
	_speckled_ellipse(im, 9.0, 12.0, 6.0, 5.0, granite.darkened(0.06), 19)
	_speckled_ellipse(im, 55.0, 11.5, 6.5, 5.5, granite.darkened(0.04), 20)
	# Sun on the near edge of the top, shade on the far right.
	for x in range(8, 54):
		var top_y := 11.0 - 7.0 * sqrt(maxf(0.0, 1.0 - pow((x - 32.0) / 29.0, 2.0)))
		K.px(im, x, int(ceil(top_y)), granite.lightened(0.22))
	# Exfoliation cracks.
	for i in 6:
		K.px(im, 18 + i, 16 + i / 3, granite.darkened(0.45))
		K.px(im, 47 - i, 17 - i / 4, granite.darkened(0.45))
	# Mortar cups worn into the top.
	for cup in [[14.0, 9.0], [27.0, 11.0], [40.0, 8.5], [51.0, 11.0]]:
		K.ellipse(im, cup[0], cup[1], 3.6, 2.0, granite.darkened(0.45))
		K.ellipse(im, cup[0] + 0.5, cup[1] + 0.4, 2.4, 1.2, granite.darkened(0.6))
		K.hline(im, int(cup[0]) - 2, int(cup[1]) + 2, 5, granite.lightened(0.2))
	# Acorn meal in the second cup.
	K.ellipse(im, 27.5, 11.3, 2.4, 1.1, c(ACORN_MEAL))
	K.px(im, 26, 11, c(ACORN_MEAL).lightened(0.2))
	# A long river-cobble pestle leaning in the third cup.
	for i in 10:
		var pcol := c("6e6a62") if i < 3 else c("8e887c")
		K.rect(im, 39 + i / 2, 9 - i, 3, 1, pcol)
		K.px(im, 39 + i / 2, 9 - i, pcol.lightened(0.3))
	K.rect(im, 43, 0, 3, 1, c("a8a296"))
	# A few cracked acorns on the rock.
	for a in [[20, 12], [33, 13], [46, 12]]:
		K.px(im, a[0], a[1], c(ACORN))
		K.px(im, a[0] + 1, a[1], c(ACORN_MEAL))
	K.outline(im)
	return im


## Leaching basin: a shallow scoop of clean sand by the river, rimmed with
## stones, holding a layer of wet acorn meal under a spread of cedar boughs
## that break the water poured over it. 44x22.
func leaching_basin() -> Image:
	var im := K.make(44, 22)
	K.shadow(im, 22.0, 18.5, 20.0, 2.6)
	# Sand bank.
	K.ellipse(im, 22.0, 13.0, 19.0, 6.0, c("d8c898"))
	K.ellipse(im, 22.0, 12.5, 15.0, 4.4, c("c8b480"))
	# Wet meal in the hollow, darker where it's soaked.
	K.ellipse(im, 22.0, 12.0, 11.0, 3.2, c(ACORN_MEAL).darkened(0.12))
	K.ellipse(im, 20.5, 11.6, 7.0, 2.0, c(ACORN_MEAL).darkened(0.24))
	# A sheen of standing water.
	K.hline(im, 17, 11, 6, c("9cc8d8"))
	K.hline(im, 19, 12, 3, c("c8e4ee"))
	# Cedar boughs laid across one side.
	for b in [[26, 9, 9], [28, 12, 7]]:
		for i in b[2]:
			K.px(im, b[0] + i, b[1] - (i / 3), c(CEDAR).darkened(0.1))
			if i % 2 == 0:
				K.px(im, b[0] + i, b[1] - (i / 3) - 1, c(CEDAR).lightened(0.15))
				K.px(im, b[0] + i, b[1] - (i / 3) + 1, c(CEDAR))
	# Rim stones.
	for i in 9:
		var a := TAU * i / 9.0 + 0.2
		var x := 22.0 + cos(a) * 18.0
		var y := 13.0 + sin(a) * 5.5
		_stone(im, x, y, i * 5 + 3, 2.2, 1.6)
	# A water basket set beside it.
	K.ellipse(im, 5.0, 8.0, 3.4, 3.6, c(WILLOW))
	K.hline(im, 2, 6, 7, c(WILLOW).darkened(0.2))
	K.hline(im, 2, 9, 7, c(WILLOW).darkened(0.2))
	K.ellipse(im, 5.0, 5.2, 2.6, 0.9, c("6aa0b8"))
	K.outline(im)
	return im
