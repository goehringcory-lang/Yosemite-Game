class_name ClimbNight
extends RefCounted
## The night on the wall: stars over the Valley, a few campfires far below, and
## you and your partner on a ledge or a portaledge, eating by headlamp around a
## little stove. Warm lamplight, a flickering flame, drifting steam.

const P := preload("res://scripts/climb/art/climb_paint.gd")
const UI := preload("res://scripts/climb/art/climb_ui.gd")
const SCREEN := Vector2(480, 270)
const WALL_W := 330

const PLAYER_LOOK := {"id": "player", "skin": "f0c088", "hair": "6a4428", "hat": "8a5a2a", "hat_kind": "fedora", "top": "6a8a4a", "bottom": "3a4466"}

const GLOW_RADIUS := 150

static var _wall_tex: ImageTexture
static var _sky_tex: ImageTexture
static var _glow_tex: ImageTexture


static func draw(ci: CanvasItem, info: Dictionary, state: ClimbState, route: RouteData, profile: Dictionary, age: float, time: float, kit: Dictionary) -> void:
	_sky(ci, time)
	_valley(ci, time)
	_wall(ci)
	var hanging: bool = info.get("place", "ledge") == "hanging"
	var cx := 170.0
	var cy := 168.0
	_glow(ci, Vector2(cx, cy - 14), time)
	if hanging:
		_portaledge(ci, cx, cy, time)
	else:
		_ledge(ci, cx, cy)
	# The haul bag hangs below.
	if state.has_haul_bag:
		var sway := sin(time * 0.9) * 1.5
		ci.draw_line(Vector2(cx - 70, cy + 22), Vector2(cx - 70 + sway, cy + 56), Color("47301f"), 3.0)
		ci.draw_line(Vector2(cx - 70, cy + 22), Vector2(cx - 70 + sway, cy + 56), Color("b3362b"), 1.0)
		ci.draw_texture(UI.icon_texture("haul_bag"), Vector2(cx - 76 + sway, cy + 56))
	# Two people, eating by headlamp, facing each other across the stove.
	var partner := ClimbProfiles.belayer_look(route)
	var me := ClimbSprites.belayer(PLAYER_LOOK, "sit", 0)
	var they := ClimbSprites.belayer(partner, "sit", int(time * 1.2) % 2)
	var y0 := cy - 41.0
	var x_me := cx - 58.0
	var x_they := cx + 10.0
	ci.draw_set_transform(Vector2(x_me + 48.0, y0), 0.0, Vector2(-1.0, 1.0))
	ci.draw_texture(me, Vector2.ZERO)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_texture(they, Vector2(x_they, y0))
	_headlamps(ci, Vector2(x_me + 24.0, y0 + 23.0), Vector2(x_they + 23.0, y0 + 23.0), Vector2(cx, cy - 2), time)
	_stove(ci, cx, cy, time)
	_meal(ci, cx, cy, time)
	_card(ci, info, age, hanging)
	var fade := clampf(1.0 - age * 2.0, 0.0, 1.0)
	if fade > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, fade))


# ---------------------------------------------------------------- sky

static func _sky(ci: CanvasItem, time: float) -> void:
	if _sky_tex == null:
		var im := P.make(480, 270)
		var top := Color("15141c")
		var mid := Color("2d3050")
		var low := Color("2d3050")
		var rim := Color("2d3050")
		for y in 270:
			var t := y / 190.0
			var c := top.lerp(mid, clampf(t * 1.4, 0.0, 1.0)) if t < 0.7 else mid.lerp(low, clampf((t - 0.7) / 0.3, 0.0, 1.0))
			if t > 1.0:
				c = low.lerp(rim, clampf((t - 1.0) * 2.0, 0.0, 1.0))
			for x in 480:
				# Ordered dither between neighbouring colour bands.
				var n: float = (float(P.BAYER[y & 3][x & 3]) + 0.5) / 16.0
				var q := c
				if n < 0.5:
					q = c.darkened(0.04)
				im.set_pixel(x, y, q)
		NightSky.paint(im, 1.0, 230, 91)
		_sky_tex = ImageTexture.create_from_image(im)
	ci.draw_texture(_sky_tex, Vector2.ZERO)
	# Twinkling stars and the odd shooting star over the painted Milky Way.
	NightSky.draw(ci, time, 1.0, 200, 91)
	# The moon, with a soft halo and a few craters.
	var mc := Vector2(398, 44)
	for i in 4:
		ci.draw_circle(mc, 30.0 - i * 5.0, Color(0.839, 0.945, 0.933, 0.035))
	ci.draw_circle(mc, 11, Color("2b2a30"))
	ci.draw_circle(mc, 10, Color("f5eee0"))
	ci.draw_circle(mc + Vector2(-2, -2), 7, Color("f5eee0"))
	ci.draw_circle(mc + Vector2(4, 3), 3, Color("e4ddcc"))
	ci.draw_circle(mc + Vector2(-4, 3), 2, Color("e4ddcc"))
	ci.draw_circle(mc + Vector2(2, -5), 2, Color("e4ddcc"))


static func _valley(ci: CanvasItem, time: float) -> void:
	# Far ridgelines and the valley floor: moonlit rims, layered fog.
	for l in 4:
		var base := 146 + l * 16
		var col := Color("2d3050").lerp(Color("15141c"), l / 3.0)
		var rim := Color("6f5aa6").lerp(Color("2d3050"), l / 3.0)
		for x in range(int(WALL_W) - 10, int(SCREEN.x)):
			var top := base - 22 + int(sin(x * (0.013 + l * 0.01) + l) * 12.0 + sin(x * 0.04 + l * 2.0) * 4.0 + P.noise(x / 3, l, 5) * 3.0)
			ci.draw_rect(Rect2(x, top, 1, SCREEN.y - top), col)
			ci.draw_rect(Rect2(x, top, 1, 1), rim)
		# A band of mist in the valley after each ridge.
		var my := base + 6
		for k in 3:
			ci.draw_rect(Rect2(WALL_W - 10, my + k * 3, SCREEN.x, 3), Color(0.55, 0.62, 0.85, 0.05 - k * 0.012))
	# Treeline specks on the nearest ridge.
	for i in 90:
		var tx := 330.0 + P.noise(i, 11, 7) * 150.0
		var ty := 200.0 + P.noise(i, 12, 7) * 55.0
		ci.draw_rect(Rect2(floorf(tx), floorf(ty), 1, 2), Color("15141c"))
	# Campfires, lamps and a ribbon of headlights on the Valley road.
	for i in 16:
		var fx := floorf(340.0 + P.noise(i, 5, 9) * 135.0)
		var fy := floorf(206.0 + P.noise(i, 6, 9) * 48.0)
		var flick := 0.6 + 0.4 * sin(time * 5.0 + i * 3.0 + sin(time * 2.1 + i))
		ci.draw_circle(Vector2(fx + 1, fy + 1), 4.0, Color(1.0, 0.6, 0.2, 0.05 * flick))
		ci.draw_rect(Rect2(fx, fy, 2, 2), Color(1.0, 0.7, 0.3, 0.55 + 0.45 * flick))
		ci.draw_rect(Rect2(fx, fy, 1, 1), Color(1.0, 0.95, 0.7, 0.6 + 0.4 * flick))
	for i in 6:
		var rx := fposmod(time * (4.0 + i) + i * 77.0, 150.0)
		ci.draw_rect(Rect2(345.0 + rx, 236 + (i % 2) * 2, 1, 1), Color(0.961, 0.933, 0.878, 0.8) if i % 2 == 0 else Color(0.702, 0.212, 0.169, 0.7))


# ---------------------------------------------------------------- wall

static func _wall(ci: CanvasItem) -> void:
	if _wall_tex == null:
		var im := P.make(WALL_W, 270)
		var base := Color("15141c")
		for y in 270:
			for x in WALL_W:
				var n := P.smooth_noise(x * 0.07, y * 0.015, 2) * 0.6 + P.smooth_noise(x * 0.3, y * 0.06, 6) * 0.4
				var c := base.lerp(Color("2d3050"), n)
				# Left of the wall is lit a bit warmer from the camp, right edge by the moon.
				c = c.lerp(Color("47464d"), clampf((x - 280.0) / 50.0, 0.0, 1.0) * 0.5)
				im.set_pixel(x, y, c)
		# Vertical cracks and dark streaks.
		for i in 9:
			var sx := int(P.noise(i, 8, 3) * (WALL_W - 12))
			var len := 40 + int(P.noise(i, 9, 3) * 160)
			var sy := int(P.noise(i, 10, 3) * 200)
			var x := sx
			for y in range(sy, mini(sy + len, 270)):
				if P.noise(y, i, 13) > 0.7:
					x += 1 if P.noise(y, i, 14) > 0.5 else -1
				x = clampi(x, 0, WALL_W - 1)
				im.set_pixel(x, y, Color("15141c"))
				if x + 1 < WALL_W:
					im.set_pixel(x + 1, y, Color("2d3050"))
		# Edge of the wall, catching the moon.
		for y in 270:
			for k in 4:
				im.set_pixel(WALL_W - 4 + k, y, [Color("2d3050"), Color("2d3050"), Color("6a6a70"), Color("93918f")][k])
		_wall_tex = ImageTexture.create_from_image(im)
	ci.draw_texture(_wall_tex, Vector2.ZERO)


static func _glow(ci: CanvasItem, at: Vector2, time: float) -> void:
	# The lamplight falls off smoothly into the dark: a few levels of warmth
	# dithered together (see _glow_image), not rings, and it flickers.
	if _glow_tex == null:
		_glow_tex = ImageTexture.create_from_image(_glow_image())
	var flicker := 0.9 + 0.07 * sin(time * 7.0) + 0.04 * sin(time * 13.0)
	ci.draw_texture(_glow_tex, (at - Vector2(GLOW_RADIUS, GLOW_RADIUS)).round(), Color(1, 1, 1, clampf(flicker, 0.0, 1.0)))


## A warm radial glow: six levels of light with an ordered dither between
## them, so it fades out pixel by pixel instead of in stepped rings.
static func _glow_image() -> Image:
	var size := GLOW_RADIUS * 2 + 1
	var im := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var levels := 6.0
	for y in size:
		for x in size:
			var d := Vector2(x - GLOW_RADIUS, y - GLOW_RADIUS).length() / GLOW_RADIUS
			if d >= 1.0:
				continue
			var strength := pow(1.0 - d, 1.5) * levels
			var bayer: float = P.BAYER[y & 3][x & 3] / 16.0
			var level := floorf(strength + bayer)
			if level > 0.0:
				im.set_pixel(x, y, Color(1.0, 0.62, 0.28, minf(level, levels) * 0.06))
	return im


static func _ledge(ci: CanvasItem, cx: float, cy: float) -> void:
	var lx := cx - 108.0
	var lw := 236.0
	# The shelf: a block of granite with a lit top and a shadowed face.
	ci.draw_rect(Rect2(lx, cy + 8, lw, 12), Color("47464d"))
	ci.draw_rect(Rect2(lx, cy + 8, lw, 2), Color("93918f"))
	ci.draw_rect(Rect2(lx, cy + 10, lw, 1), Color("6a6a70"))
	ci.draw_rect(Rect2(lx, cy + 17, lw, 3), Color("2d3050"))
	ci.draw_rect(Rect2(lx, cy + 20, lw - 8, 5), Color("15141c"))
	for i in 10:
		var x := lx + P.noise(i, 20, 2) * lw
		ci.draw_rect(Rect2(x, cy + 11 + P.noise(i, 21, 2) * 5.0, 3, 1), Color("2d3050"))
	# Sleeping bags rolled out behind, rack and rope coil hung on an anchor.
	ci.draw_rect(Rect2(cx - 100, cy - 4, 30, 12), Color("235679"))
	ci.draw_rect(Rect2(cx - 100, cy - 4, 30, 2), Color("3a86a8"))
	ci.draw_rect(Rect2(cx - 100, cy + 6, 30, 2), Color("142f47"))
	ci.draw_rect(Rect2(cx + 70, cy - 4, 32, 12), Color("6b4829"))
	ci.draw_rect(Rect2(cx + 70, cy - 4, 32, 2), Color("92693d"))
	ci.draw_rect(Rect2(cx + 70, cy + 6, 32, 2), Color("47301f"))
	# Anchor bolts and a small gear rack on the wall above.
	for k in [-50.0, 60.0]:
		ci.draw_rect(Rect2(cx + k, cy - 70, 3, 3), Color("bdb8ae"))
	for i in 5:
		ci.draw_texture(ClimbSprites.hardware("cam", i), Vector2(cx + 96 + i * 6, cy - 70 + (i % 2) * 2), Color(0.961, 0.933, 0.878, 0.9))


static func _portaledge(ci: CanvasItem, cx: float, cy: float, time: float) -> void:
	var anchor_y := 58.0
	var sway := sin(time * 0.8) * 0.8
	# Straps up to the anchor bolts, each ending at a carabiner.
	for k in [-72.0, 72.0]:
		var top := Vector2(cx + k * 0.8, anchor_y)
		var bot := Vector2(cx + k + sway, cy + 8)
		ci.draw_line(top, bot, Color("2a1b14"), 3.0)
		ci.draw_line(top, bot, Color("b3362b"), 1.0)
		ci.draw_rect(Rect2(top.x - 2, top.y - 3, 5, 6), Color("2a1b14"))
		ci.draw_rect(Rect2(top.x - 1, top.y - 2, 3, 4), Color("bdb8ae"))
		ci.draw_rect(Rect2(top.x - 1, top.y - 2, 3, 1), Color("f5eee0"))
	# The bed: orange nylon, a lit top edge, a dark underside and aluminium tubes.
	var bx := cx - 82.0 + sway
	ci.draw_rect(Rect2(bx, cy + 9, 164, 6), Color("15141c"))
	ci.draw_rect(Rect2(bx - 2, cy + 6, 168, 3), Color("bdb8ae"))
	ci.draw_rect(Rect2(bx - 2, cy + 6, 168, 1), Color("f5eee0"))
	ci.draw_rect(Rect2(bx, cy + 9, 164, 6), Color("d9772a"))
	ci.draw_rect(Rect2(bx, cy + 9, 164, 1), Color("f7a64a"))
	ci.draw_rect(Rect2(bx, cy + 14, 164, 1), Color("a84a1c"))
	for k in range(0, 160, 10):
		ci.draw_rect(Rect2(bx + 4 + k, cy + 10, 1, 4), Color("d9772a"))
	# Struts and the haul line underneath.
	for k in range(-70, 76, 20):
		ci.draw_rect(Rect2(cx + k + sway, cy + 15, 2, 6), Color("6a6a70"))
	ci.draw_rect(Rect2(bx + 6, cy + 20, 152, 1), Color("47464d"))


static func _headlamps(ci: CanvasItem, a: Vector2, b: Vector2, target: Vector2, time: float) -> void:
	# A cone of light from each forehead down to the food, and a bright dot.
	for pair in [[a, 1.0], [b, -1.0]]:
		var from: Vector2 = pair[0]
		var dir: float = pair[1]
		var to := target + Vector2(-dir * 2.0, 4.0)
		var flick := 0.08 + 0.01 * sin(time * 3.0 + dir)
		ci.draw_colored_polygon(PackedVector2Array([from, to + Vector2(-9, 2), to + Vector2(9, 6)]), Color(1.0, 0.95, 0.75, flick))
		ci.draw_colored_polygon(PackedVector2Array([from, to + Vector2(-5, 3), to + Vector2(5, 5)]), Color(1.0, 0.95, 0.75, flick))
		ci.draw_rect(Rect2(from.x + dir * -1.0 - 1, from.y - 6, 3, 2), Color("f5eee0"))
		ci.draw_rect(Rect2(from.x + dir * -1.0, from.y - 6, 1, 1), Color.WHITE)


static func _stove(ci: CanvasItem, cx: float, cy: float, time: float) -> void:
	# A little canister stove with a blue ring of flame under a dented pot.
	var flick := int(time * 12.0) % 3
	ci.draw_rect(Rect2(cx - 8, cy + 4, 16, 4), Color("2b2a30"))
	ci.draw_rect(Rect2(cx - 8, cy + 4, 16, 1), Color("6a6a70"))
	ci.draw_rect(Rect2(cx - 6, cy + 1, 12, 3), Color("47464d"))
	ci.draw_rect(Rect2(cx - 6, cy + 1, 12, 1), Color("93918f"))
	# Blue base flame with an orange tip, three frames.
	for i in 5:
		var fx := cx - 5 + i * 2.5
		var h := 2 + ((i + flick) % 3)
		ci.draw_rect(Rect2(fx, cy - h + 1, 2, h), Color("3a86a8"))
		ci.draw_rect(Rect2(fx, cy - h + 1, 2, 1), Color("f1cf6a"))
	ci.draw_circle(Vector2(cx, cy - 2), 14.0, Color(0.435, 0.353, 0.651, 0.04))
	# Pot: steel with a rolled rim, a bale handle and a lid.
	ci.draw_rect(Rect2(cx - 8, cy - 13, 16, 12), Color("93918f"))
	ci.draw_rect(Rect2(cx - 8, cy - 13, 3, 12), Color("bdb8ae"))
	ci.draw_rect(Rect2(cx + 4, cy - 13, 4, 12), Color("6a6a70"))
	ci.draw_rect(Rect2(cx - 9, cy - 14, 18, 2), Color("d6f1ee"))
	ci.draw_rect(Rect2(cx - 9, cy - 12, 18, 1), Color("47464d"))
	ci.draw_rect(Rect2(cx - 8, cy - 2, 16, 1), Color("47464d"))
	ci.draw_rect(Rect2(cx - 3, cy - 10, 5, 3), Color("2b2a30"))
	ci.draw_arc(Vector2(cx, cy - 14), 8.0, PI, TAU, 10, Color("2b2a30"), 1.0)


static func _meal(ci: CanvasItem, cx: float, cy: float, time: float) -> void:
	# Steam, curling up out of the pot.
	for i in 7:
		var life := fposmod(time * 12.0 + i * 5.0, 36.0)
		var sy := cy - 16.0 - life
		var sx := cx - 2.0 + sin(time * 1.8 + i * 1.7 + life * 0.15) * (2.0 + life * 0.08)
		var a := 0.55 * (1.0 - life / 36.0)
		var sz := 2 if life < 18.0 else 3
		ci.draw_rect(Rect2(floorf(sx), floorf(sy), sz, sz), Color(1, 1, 1, a))
	# Bowls on the ledge and a spoon, a mug for each.
	for k in [-26.0, 20.0]:
		ci.draw_rect(Rect2(cx + k, cy + 5, 7, 3), Color("e4ddcc"))
		ci.draw_rect(Rect2(cx + k, cy + 5, 7, 1), Color.WHITE)
		ci.draw_rect(Rect2(cx + k + 1, cy + 4, 5, 1), Color("a84a1c"))
		ci.draw_rect(Rect2(cx + k + 6, cy + 3, 1, 4), Color("6a6a70"))
	ci.draw_rect(Rect2(cx + 30, cy + 3, 4, 5), Color("6f5aa6"))
	ci.draw_rect(Rect2(cx + 30, cy + 3, 4, 1), Color("63b3c6"))


# ---------------------------------------------------------------- card

static func _card(ci: CanvasItem, info: Dictionary, age: float, hanging: bool) -> void:
	var r := Rect2(300, 24, 170, 100)
	UI.panel(ci, r)
	UI.ink(ci, Vector2(r.position.x + 85, r.position.y + 20), "Night %d on the wall" % info.get("night", 1), UI.INK, 16, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	UI.ink(ci, Vector2(r.position.x + 85, r.position.y + 34), "%s" % ("A portaledge on the wall." if hanging else "A ledge to sleep on."), UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	var meal: String = info.get("meal", "a meal")
	var lines := UI.wrap_lines("You and your partner share %s by headlamp. The Valley's campfires glow far below." % meal, 150.0, 10)
	for i in lines.size():
		UI.ink(ci, Vector2(r.position.x + 10, r.position.y + 50 + i * 11), lines[i], UI.INK, 10)
	if age > 0.8:
		UI.keys(ci, Vector2(r.position.x + 85, r.end.y - 8), "[E] Sleep until dawn", UI.WARN_DARK, 10, HORIZONTAL_ALIGNMENT_CENTER)
