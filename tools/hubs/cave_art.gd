extends RefCounted
## Pixel art for the Guardian's cave, the talus cave under the Royal Arches
## where the story ends: the room (one 480x272 picture, like the shop
## interiors), the looking-glass over its tin box, and the gap in the talus
## you go in by. Drawn in code with PixelKit, written to assets/sprites/cave/.

const K = preload("res://tools/hubs/pixel_kit.gd")
const DIR := "res://assets/sprites/cave/"
const W := 480
const H := 272
## Where the back wall meets the floor, and the walls' thickness at the sides.
const FLOOR_Y := 80
const SIDE := 16
const ROCK := Color("4a4c56")
const ROCK_DARK := Color("24252c")
const SAND := Color("6a6252")


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var images := {"cave_room": room(), "mirror": mirror(), "cave_mouth": mouth()}
	for image_name: String in images:
		(images[image_name] as Image).save_png(ProjectSettings.globalize_path(DIR + image_name + ".png"))


## A fallen granite boulder: rounded, lit from the upper left, dark underneath.
func _boulder(im: Image, cx: float, cy: float, rx: float, ry: float, seed_value: int) -> void:
	var base := ROCK.lightened((K.hash2(int(cx), int(cy), seed_value) - 0.5) * 0.24)
	K.ellipse(im, cx, cy + 1.5, rx + 1.0, ry + 1.0, ROCK_DARK.darkened(0.3)) # the gap behind it
	K.ellipse(im, cx, cy, rx, ry, base.darkened(0.28))
	K.ellipse(im, cx - rx * 0.06, cy - ry * 0.12, rx * 0.94, ry * 0.86, base)
	K.ellipse(im, cx - rx * 0.22, cy - ry * 0.34, rx * 0.6, ry * 0.46, base.lightened(0.16))
	K.ellipse(im, cx - rx * 0.32, cy - ry * 0.5, rx * 0.3, ry * 0.2, base.lightened(0.3))
	# a crack, and flecks of mica
	var crack := cx + (K.hash2(seed_value, 1, 3) - 0.5) * rx
	for i in int(ry * 1.2):
		K.px(im, int(crack + K.hash2(i, seed_value, 4) * 2.0), int(cy - ry * 0.5) + i, base.darkened(0.4))
	for i in 5:
		K.px(im, int(cx + (K.hash2(i, seed_value, 5) - 0.5) * rx * 1.4), int(cy + (K.hash2(i, seed_value, 6) - 0.6) * ry), base.lightened(0.35))


## A wall of piled boulders filling the rectangle, the nearer ones drawn last.
func _talus(im: Image, x0: int, y0: int, w: int, h: int, size: float, seed_value: int, skip := Rect2()) -> void:
	var stones: Array[Vector3] = []
	var count := int(w * h / (size * size * 1.1)) + 2
	for i in count:
		var cx := x0 + K.hash2(i, 1, seed_value) * w
		var cy := y0 + K.hash2(i, 2, seed_value) * h
		if skip.has_point(Vector2(cx, cy)):
			continue
		stones.append(Vector3(cx, cy, size * (0.7 + K.hash2(i, 3, seed_value) * 0.7)))
	stones.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	for i in stones.size():
		_boulder(im, stones[i].x, stones[i].y, stones[i].z, stones[i].z * 0.72, seed_value + i * 7)


## The cave: piled talus for walls, a sand floor, daylight coming in at the
## gap in front and down a chimney onto the back wall.
func room() -> Image:
	var im := K.make(W, H)
	im.fill(ROCK_DARK)
	# the floor: granite sand, darker toward the walls
	for y in range(FLOOR_Y - 8, H):
		for x in W:
			var n := K.hash2(x, y, 41)
			var edge := minf(minf(x - SIDE, W - SIDE - x), minf(y - FLOOR_Y, H - 16 - y)) / 48.0
			var tone := SAND.darkened(clampf(0.46 - edge * 0.34, 0.0, 0.55)).lightened((n - 0.5) * 0.1)
			if n > 0.965:
				tone = tone.lightened(0.25) # a fleck of quartz
			elif n < 0.03:
				tone = tone.darkened(0.3) # a pebble's shadow
			K.px(im, x, y, tone)
	# the back wall, the sides, and the front wall either side of the gap
	_talus(im, -8, 0, W + 16, FLOOR_Y - 14, 22.0, 11)
	_talus(im, -8, FLOOR_Y - 22, W + 16, 16, 15.0, 23)
	_talus(im, -4, FLOOR_Y, SIDE + 2, H - FLOOR_Y, 10.0, 31)
	_talus(im, W - SIDE + 2, FLOOR_Y, SIDE + 2, H - FLOOR_Y, 10.0, 37)
	_talus(im, 0, H - 13, W, 14, 10.0, 43, Rect2(214, H - 30, 52, 40))
	# the gap: daylight between two leaning blocks
	K.rect(im, 226, H - 16, 28, 16, Color("efe2b8"))
	K.rect(im, 226, H - 16, 28, 3, Color("cdbf94"))
	_boulder(im, 216, H - 9, 13, 10, 51)
	_boulder(im, 264, H - 9, 13, 10, 57)
	# daylight spilling in across the floor from the gap
	for y in range(H - 86, H - 16):
		var reach := (y - (H - 86)) / 70.0
		for dx in range(-44, 44):
			var fall := 1.0 - absf(dx) / (14.0 + reach * 28.0)
			if fall > 0.0:
				K.px(im, 240 + dx, y, Color(1.0, 0.93, 0.7, 0.2 * fall * reach))
	# and a thin shaft down a chimney in the roof, onto the back wall
	for y in range(0, FLOOR_Y + 44):
		var half := 6.0 + y * 0.14
		for dx in range(-int(half), int(half) + 1):
			K.px(im, 240 + dx, y, Color(1.0, 0.95, 0.78, 0.15 * (1.0 - absf(dx) / (half + 1.0))))
	K.ellipse(im, 240, FLOOR_Y + 42, 30, 10, Color(1.0, 0.95, 0.78, 0.13))
	return im


## The looking-glass: a small silvered mirror in a wooden frame, hung on the
## rock over an open tin box with the last sheet in it.
func mirror() -> Image:
	var im := K.make(34, 46)
	# the mirror
	K.rect(im, 9, 1, 16, 22, Color("6b4a2e"))
	K.rect(im, 10, 2, 14, 20, Color("8a6238"))
	K.rect(im, 12, 4, 10, 16, Color("9fb4c4"))
	K.rect(im, 12, 4, 10, 5, Color("c8d8e2"))
	for i in 8:
		K.px(im, 13 + i, 12 - i, Color("eef4f8")) # a glint across the glass
		K.px(im, 14 + i, 16 - i, Color("d8e4ec"))
	K.px(im, 20, 18, Color("7a8e9e")) # a spot where the silvering has gone
	K.px(im, 13, 19, Color("7a8e9e"))
	K.rect(im, 16, 0, 2, 2, Color("3a3a3a")) # the nail
	# the ledge of rock it stands over
	K.rect(im, 1, 34, 32, 12, ROCK.lightened(0.08))
	K.rect(im, 1, 34, 32, 2, ROCK.lightened(0.3))
	K.rect(im, 1, 43, 32, 3, ROCK.darkened(0.3))
	# the tin box, lid back, with the sheet lying in it
	K.rect(im, 6, 24, 22, 4, Color("7a8088")) # the lid, standing open
	K.rect(im, 6, 24, 22, 1, Color("a8b0b8"))
	K.rect(im, 5, 28, 24, 9, Color("5c646c"))
	K.rect(im, 5, 28, 24, 1, Color("98a0a8"))
	K.rect(im, 7, 29, 20, 6, Color("efe6cc")) # the last sheet
	K.rect(im, 18, 33, 8, 2, Color("d8cca8")) # its label
	K.px(im, 19, 33, Color("5a4a3a"))
	K.px(im, 21, 33, Color("5a4a3a"))
	K.px(im, 23, 33, Color("5a4a3a"))
	K.px(im, 5, 36, Color("a05a30")) # rust at the corners
	K.px(im, 28, 36, Color("a05a30"))
	K.outline(im)
	return im


## The way in: a black gap between two blocks leaning together at the foot of
## the cliff.
func mouth() -> Image:
	var im := K.make(40, 34)
	# the left block, leaning right, and the right block, leaning left
	for y in range(4, 34):
		var lean := (33 - y) / 4
		K.rect(im, 1 + lean / 2, y, 13 + lean / 2, 1, ROCK.lightened(0.16 - y * 0.006))
		K.rect(im, 26 - lean, y, 13 + lean / 2, 1, ROCK.lightened(0.02 - y * 0.006))
	# the capstone across the top
	K.rect(im, 8, 1, 25, 8, ROCK.lightened(0.2))
	K.rect(im, 8, 1, 25, 2, ROCK.lightened(0.4))
	K.rect(im, 8, 8, 25, 1, ROCK.darkened(0.35))
	# the gap
	for y in range(9, 34):
		var half := 3 + (y - 9) / 4
		K.rect(im, 20 - half, y, half * 2, 1, Color("0e0e14"))
	K.rect(im, 18, 30, 4, 4, Color("1c1c26")) # a little of the floor inside
	# lichen and a fern at the foot
	for at in [Vector2i(4, 14), Vector2i(31, 18), Vector2i(12, 4), Vector2i(34, 26)]:
		K.px(im, at.x, at.y, Color("a8b060"))
		K.px(im, at.x + 1, at.y, Color("8a9a50"))
	for i in 4:
		K.px(im, 3 + i, 32 - i, Color("5a9a48"))
		K.px(im, 7 - i / 2, 31 - i, Color("4a8a40"))
	K.outline(im)
	return im
