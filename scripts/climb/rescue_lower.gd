class_name RescueLower
extends CanvasLayer
## Lowering someone off a climb on a rescue (Rescues): you're at the anchor
## and they hang on the rope below you, clipped in, all the way to the
## ground. Hold use to let the rope run through the brake and they go down,
## faster the longer you hold; let go to brake. The face has flakes and roofs
## on it (SNAGS): ease them past one slowly, or they bump into it and you
## have to stop and let them push off. Run the rope too fast for too long and
## the brake gets hot (HEAT) and locks until it cools.
##
## Nobody falls: a lower always reaches the ground, and how smooth it was
## ([member bumps]) is what you're told after. Cancel hands the rope to the
## team, who finish it.
##
## It's drawn like the climbing screen it follows (ClimbMinigame): the
## route's own granite painted for the hour with the valley beyond, you
## braced at the anchor feeding rope through the brake, and them sitting in
## their harness on the rope, the view following them down past the flakes
## to the ground. The speed and brake gauges stand at the right, as the
## climbing screen's stamina does.
##
## The rules are in [method step], so tests can lower without the keyboard.

signal finished

## How far down they are (0 at the anchor, 1 on the ground) a second, at
## most, and how quickly the speed builds while you hold and drops when you
## let go.
const MAX_SPEED := 0.16
const ACCEL := 0.22
const BRAKE := 0.5
## Over a snag, faster than this is a bump.
const SAFE_SPEED := 0.06
## Seconds stopped after a bump, while they push off the rock.
const BUMP_STOP := 0.9
## Above HOT_SPEED the brake heats up this much a second; below it, it cools.
## Full heat locks the rope for LOCK_TIME.
const HOT_SPEED := 0.12
const HEAT_RATE := 0.45
const COOL_RATE := 0.35
const LOCK_TIME := 1.4
## The face's snags, as [top, bottom] down the rope (0 to 1).
const SNAGS := [[0.22, 0.3], [0.48, 0.56], [0.74, 0.82]]
const L := preload("res://scripts/climb/art/climb_layout.gd")
const P := preload("res://scripts/climb/art/climb_paint.gd")
const SCREEN := Vector2(480, 270)
## The rope hangs down this line of the wall (screen x), and the view keeps
## them this far down the screen as they go.
const ROPE_X := 172.0
const FOLLOW_Y := 120.0
## The gauges: speed and brake heat, upright at the right.
const SPEED_BAR := Rect2(424, 92, 12, 116)
const HEAT_BAR := Rect2(458, 92, 12, 116)
const ROPE := Color("b3362b")
const ROPE_LIT := Color("d9772a")
const OUTLINE := Color("15141c")
const STEEL := Color("bdb8ae")
## How far a snag stands out from the face (picture px), and how wide it is.
const SNAG_W := 70
const SNAG_LIP := 9

## How far down they are, and how fast they're going.
var depth := 0.0
var speed := 0.0
var heat := 0.0
## Bumps into the rock so far.
var bumps := 0
var done := false
## True if you handed the rope to the team.
var handed_off := false
var route_name := ""

var _stopped := 0.0
var _locked := 0.0
## Snags already passed or bumped, so each one counts once.
var _cleared: Array[int] = []
var _flash := ""
var _flash_age := 9.0
var _canvas: Control
## The painted scene (see _paint): sky, the valley's layers, clouds, the
## wall, and where the anchor ledge and the ground are in the wall picture.
var _pal := {}
var _sky_tex: Texture2D
var _layers: Array[Dictionary] = []
var _clouds: Array[Texture2D] = []
var _wall_tex: Texture2D
var _anchor_y := 0.0
var _ground_y := 0.0
## Them, sitting in their harness, and you at the anchor (your rack).
var _them: Texture2D
var _kit := {}
var _time := 0.0
var _feed := 0.0


func _ready() -> void:
	layer = 18
	UiScale.layer(self)
	_canvas = Control.new()
	UiScale.fit(_canvas)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw)
	add_child(_canvas)
	# Painted in code like the climbing screen, and kept on the palette the
	# same way.
	var snap := ColorRect.new()
	UiScale.fit(snap)
	snap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	snap.material = ShaderMaterial.new()
	snap.material.shader = load("res://assets/shaders/palette_snap.gdshader")
	add_child(snap)


## Starts lowering from the top of [param route] (the scene is painted for
## it; with none, the rock is plain), with [param who] on the rope: their
## sprite sheet (CharacterSheet), for the colors they're wearing.
func start(route: RouteData = null, who: Texture2D = null) -> void:
	route_name = route.display_name if route else ""
	if route:
		_paint(route, who)
	depth = 0.0
	speed = 0.0
	heat = 0.0
	bumps = 0
	done = false
	handed_off = false
	_cleared = []
	Sound.play("climb_clip", -4.0, 0.1)


## Moves the lower on by [param delta] seconds, with use held or not.
func step(delta: float, holding: bool) -> void:
	if done:
		return
	_flash_age += delta
	_stopped = maxf(_stopped - delta, 0.0)
	_locked = maxf(_locked - delta, 0.0)
	var running := holding and _stopped <= 0.0 and _locked <= 0.0
	if running:
		speed = minf(speed + ACCEL * delta, MAX_SPEED)
	else:
		speed = maxf(speed - BRAKE * delta, 0.0)
	heat = clampf(heat + (HEAT_RATE if speed > HOT_SPEED else -COOL_RATE) * delta, 0.0, 1.0)
	if heat >= 1.0 and _locked <= 0.0:
		_locked = LOCK_TIME
		speed = 0.0
		_say("Brake's hot!")
		Sound.play("ui_back", -4.0, 0.05)
	depth = minf(depth + speed * delta, 1.0)
	var snag := snag_at(depth)
	if snag >= 0 and not snag in _cleared:
		if speed > SAFE_SPEED:
			_cleared.append(snag)
			bumps += 1
			speed = 0.0
			_stopped = BUMP_STOP
			_say("Bump!")
			Sound.play("climb_move", -2.0, 0.1)
		elif depth >= SNAGS[snag][1] - 0.02:
			_cleared.append(snag)
			_say("Clean")
			Sound.play("item_get", -8.0, 0.08)
	if depth >= 1.0:
		_end()
	if _canvas:
		_canvas.queue_redraw()


## The snag at [param at] (an index into SNAGS), or -1.
static func snag_at(at: float) -> int:
	for i in SNAGS.size():
		if at >= SNAGS[i][0] and at <= SNAGS[i][1]:
			return i
	return -1


## Hands the rope to the team, who finish the lower.
func hand_off() -> void:
	if done:
		return
	handed_off = true
	_end()


## What's said after: how it went.
func outcome_text() -> String:
	if handed_off:
		return "The team took the rope and finished the lower. Everyone's down safe."
	match bumps:
		0:
			return "A perfect lower: not one bump. Down safe on the ground."
		1:
			return "Down safe, with one bump on the way."
	return "Down safe, a little bruised from %d bumps on the way." % bumps


func _end() -> void:
	done = true
	finished.emit()


func _say(text: String) -> void:
	_flash = text
	_flash_age = 0.0


func _process(delta: float) -> void:
	_time += delta
	# your brake hand pays the rope out while it runs
	_feed += delta * speed * 40.0
	step(delta, Input.is_action_pressed("interact") or Input.is_action_pressed("use_tool"))


func _input(event: InputEvent) -> void:
	if done:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hand_off()
	elif event.is_action("interact") or event.is_action("use_tool"):
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- the scene

## Paints the scene for [param route] at this hour: the sky and the valley
## from the climbing screen's painters, and the route's first pitch of rock
## (its foot is the ground they're lowered to), with the flakes they have to
## get past as bulges across the rope's line.
func _paint(route: RouteData, who: Texture2D) -> void:
	var profile := ClimbProfiles.get_profile(route.id)
	_pal = ClimbSky.palette(GameClock.minutes / 60.0)
	var seed_value := hash(route.id)
	_sky_tex = ImageTexture.create_from_image(ClimbSky.sky(_pal))
	var land := ClimbLandscape.build(profile, _pal, seed_value)
	_layers.clear()
	for layer: Dictionary in land.layers:
		_layers.append({"tex": ClimbHiRes.texture(layer.image), "sink": layer.sink, "pad": layer.pad})
	_clouds.clear()
	for i in 3:
		_clouds.append(ClimbHiRes.texture(ClimbSky.cloud(_pal, seed_value + i)))
	var state := ClimbState.new(route, 0, absi(seed_value))
	var rock: String = profile.get("rock", "apron")
	var wall := ClimbRock.paint(state, rock, _pal, seed_value + 31)
	var im: Image = wall.image
	ClimbScenes.paint_base(im, profile.get("ground", ""), state, _pal, wall.edge, seed_value)
	_anchor_y = L.wall_px(state.top_row, state.top_row, 0).y + 7.0
	_ground_y = L.wall_px(state.top_row, 0, 0).y + 7.0
	var colors := ClimbRock.colors(rock, _pal)
	for i in SNAGS.size():
		_paint_snag(im, colors, int(_rope_y(SNAGS[i][0])), int(_rope_y(SNAGS[i][1]) - _rope_y(SNAGS[i][0])), seed_value + i)
	_wall_tex = ClimbHiRes.wall_texture(im, rock, 0.0, seed_value + 31)
	_them = ClimbSprites.belayer(_look_of(who), "sit")
	_kit = Gear.owned.duplicate()


## A bulge of rock across the rope's line, [param tall] picture px high from
## [param top]: lit along its top, its underside in shadow, a dark seam
## where it leaves the face and a shadow cast on the wall under it.
func _paint_snag(im: Image, c: Dictionary, top: int, tall: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var left := int(ROPE_X) - SNAG_W / 2 + rng.randi_range(-6, 6)
	for x in SNAG_W:
		# a rounded outline: thin at the ends, standing out most in the middle
		var t := float(x) / (SNAG_W - 1)
		var stand := int(roundf(sin(t * PI) * SNAG_LIP)) + rng.randi_range(0, 1)
		var y0 := top + SNAG_LIP - stand
		var y1 := top + tall
		# a dark seam where it parts from the face above, a lit crest, then
		# its body turning from the light into shade underneath
		P.px(im, left + x, y0 - 1, c.seam)
		P.px(im, left + x, y0, ClimbRock.tone(c, 3.6 - t * 0.6))
		var body := maxi(y1 - y0 - 1, 1)
		for k in body:
			var f := float(k) / body
			P.px(im, left + x, y0 + 1 + k, ClimbRock.tone(c, lerpf(2.8, 0.9, f) - t * 0.5))
		P.px(im, left + x, y1, c.deep)
		# the shadow it throws on the face below, longer under the middle
		var drop := stand + 3
		for k in drop:
			var under := im.get_pixel(left + x, y1 + 1 + k)
			if under.a > 0.5:
				im.set_pixel(left + x, y1 + 1 + k, under.darkened(0.45 * (1.0 - float(k) / drop)))
	# cracks where it's come away a little from the wall
	for i in 2:
		var cx := left + rng.randi_range(8, SNAG_W - 8)
		P.rect(im, cx, top + SNAG_LIP, 1, tall - SNAG_LIP - 3, c.seam)


## A look for the climbing screen's figure painter from someone's sprite
## sheet: the skin, shirt and trousers they're wearing, read off their
## standing frame.
static func _look_of(sheet: Texture2D) -> Dictionary:
	var look := {"id": "", "skin": "e0ac7e", "hair": "5a3a22", "hat": "", "top": "d9772a", "bottom": "4a4a58"}
	if sheet == null:
		return look
	var im := sheet.get_image()
	if im == null or im.get_width() < 32 or im.get_height() < 48:
		return look
	if im.is_compressed():
		im.decompress()
	look["skin"] = im.get_pixel(14, 18).to_html(false)
	look["top"] = im.get_pixel(14, 28).to_html(false)
	look["bottom"] = im.get_pixel(13, 38).to_html(false)
	look["hair"] = im.get_pixel(16, 5).to_html(false)
	return look


## Picture y of the rope [param at] (0 at the anchor, 1 on the ground).
func _rope_y(at: float) -> float:
	return lerpf(_anchor_y + 10.0, _ground_y - 22.0, at)


## Screen y of the wall picture's top: the view follows them down.
func _view_top() -> float:
	var h := float(_wall_tex.get_height()) if _wall_tex else SCREEN.y
	return -clampf(_rope_y(depth) - FOLLOW_Y, 0.0, maxf(h - SCREEN.y, 0.0))


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var ci := _canvas
	if _wall_tex == null:
		_draw_plain()
	else:
		ci.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("1d3f2b"))
		var top := _view_top()
		var height := clampf(-top / maxf(float(_wall_tex.get_height()) - SCREEN.y, 1.0), 0.0, 1.0)
		ci.draw_texture(_sky_tex, Vector2.ZERO)
		for i in _clouds.size():
			var x := fposmod(160.0 + i * 151.0 + _time * (3.0 + i * 1.7), SCREEN.x + 140.0) - 70.0
			ci.draw_texture(_clouds[i], Vector2(x, 24.0 + i * 29.0 + height * 10.0).round(), Color(1, 1, 1, 0.35 if _pal.get("night", false) else 0.95))
		for layer: Dictionary in _layers:
			ci.draw_texture(layer.tex, Vector2(0, roundf((1.0 - height) * layer.sink) - layer.pad))
		ci.draw_texture(_wall_tex, Vector2(0, roundf(top)))
		# the forest floor under the foot of the picture
		var bottom := roundf(top) + _wall_tex.get_height()
		if bottom < SCREEN.y:
			ci.draw_rect(Rect2(0, bottom, SCREEN.x, SCREEN.y - bottom), Color("1d3f2b"))
		_draw_snag_warnings(top)
		_draw_anchor(top)
		_draw_them(top)
		_draw_rope(top)
	_draw_hud()


## With no route to paint (tests), plain granite and the ground.
func _draw_plain() -> void:
	var ci := _canvas
	ci.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("7c7884"))
	ci.draw_rect(Rect2(0, SCREEN.y - 12, SCREEN.x, 12), Color("437f45"))
	var y := lerpf(30.0, SCREEN.y - 30.0, depth)
	ci.draw_line(Vector2(ROPE_X, 20), Vector2(ROPE_X, y), ROPE, 1.0)
	ci.draw_rect(Rect2(ROPE_X - 3, y, 6, 8), ClimbUI.WARN)


## The flake coming up under them glows a warning while it's still to pass.
func _draw_snag_warnings(top: float) -> void:
	for i in SNAGS.size():
		if i in _cleared or absf(depth - SNAGS[i][0]) > 0.1:
			continue
		var y0 := top + _rope_y(SNAGS[i][0])
		var y1 := top + _rope_y(SNAGS[i][1])
		var pulse := 0.35 + 0.25 * sin(_time * 8.0)
		_canvas.draw_rect(Rect2(ROPE_X - SNAG_W / 2.0 - 3, y0 - 1, SNAG_W + 6, y1 - y0 + 2), Color(ClimbUI.WARN, pulse), false, 1.0)


## You at the anchor on the ledge: bolts with the rescue rope through a
## brake, your guide hand up on the rope and your brake hand paying it out.
func _draw_anchor(top: float) -> void:
	var ledge := top + _anchor_y
	if ledge < -60.0:
		return
	var bolt := Vector2(ROPE_X, ledge - 30.0)
	for dx: float in [-6.0, 6.0]:
		_canvas.draw_rect(Rect2(bolt + Vector2(dx - 2, -2), Vector2(5, 5)), OUTLINE)
		_canvas.draw_rect(Rect2(bolt + Vector2(dx - 1, -1), Vector2(3, 3)), STEEL)
	_canvas.draw_line(bolt + Vector2(-6, 1), bolt + Vector2(0, 7), STEEL, 1.0)
	_canvas.draw_line(bolt + Vector2(6, 1), bolt + Vector2(0, 7), STEEL, 1.0)
	var feed := sin(_feed) * 2.0 if speed > 0.0 else 0.0
	var pose := {"hr": Vector2(10, 4 + feed), "hl": Vector2(-3, -12), "fr": Vector2(6, 22), "fl": Vector2(-5, 22), "lean": 0}
	var you := ClimbSprites.climber(pose, _kit)
	var o := ClimbSprites.ORIGIN
	_canvas.draw_texture(you, (Vector2(ROPE_X + 26.0, ledge - 26.0) - o).round())
	# the rope from your brake hand up through the anchor
	_sag(Vector2(ROPE_X + 36.0, ledge - 22.0 + feed), bolt + Vector2(0, 7), 0.05)


## The rope from the anchor down to their harness (in front of them, to
## where they're tied in).
func _draw_rope(top: float) -> void:
	var from := Vector2(ROPE_X, top + _anchor_y - 23.0)
	_sag(from, _harness(top), 0.0)


## Them, sitting in their harness on the rope, swinging a little while the
## rope runs and pushing off the rock with a bump.
func _draw_them(top: float) -> void:
	var tex := _them
	var at := _harness(top)
	if tex:
		_canvas.draw_texture(tex, (at - Vector2(ClimbSprites.BSIZE.x / 2.0, ClimbSprites.BSIZE.y - 12.0)).round())
	else:
		_canvas.draw_rect(Rect2(at.x - 3, at.y, 6, 8), ClimbUI.WARN)
	if _flash_age < 1.0 and _flash != "":
		var col: Color = ClimbUI.GOOD if _flash == "Clean" else ClimbUI.WARN
		ClimbUI.outlined(_canvas, Vector2(at.x + 34.0, at.y - 16.0 - _flash_age * 10.0), _flash, col, 12, -1.0, HORIZONTAL_ALIGNMENT_LEFT)


## Where the rope meets their harness on screen.
func _harness(top: float) -> Vector2:
	var swing := sin(_time * 4.2) * 2.5 * minf(speed / MAX_SPEED, 1.0)
	if _stopped > 0.0:
		swing = sin(_stopped * 14.0) * 3.0
	return Vector2(ROPE_X + swing, top + _rope_y(depth)).round()


## One span of rope, as the climbing screen draws it: a dark edge, the red
## sheath and a lit thread, hanging in a slight curve.
func _sag(a: Vector2, b: Vector2, amount: float) -> void:
	var length := a.distance_to(b)
	var mid := (a + b) / 2.0 + Vector2(length * amount * 0.5, length * amount * 0.6)
	var pts := PackedVector2Array()
	var n := clampi(int(length / 3.0), 4, 64)
	for i in n + 1:
		var t := i / float(n)
		pts.append((a.lerp(mid, t).lerp(mid.lerp(b, t), t) * 2.0).round() / 2.0)
	_canvas.draw_polyline(pts, OUTLINE, 2.0)
	_canvas.draw_polyline(pts, ROPE, 1.5)
	var lit := PackedVector2Array()
	for p in pts:
		lit.append(p + Vector2(-0.25, -0.5))
	_canvas.draw_polyline(lit, ROPE_LIT, 0.5)


## The plate at the top left (who, where, how far to go), the gauges at the
## right, and the keys at the foot, in the climbing screen's wood and paper.
func _draw_hud() -> void:
	var ci := _canvas
	var plate := Rect2(6, 6, 170, 34)
	ClimbUI.panel(ci, plate)
	ClimbUI.ink(ci, Vector2(14, 20), "Lowering on %s" % route_name if route_name != "" else "Lowering", ClimbUI.INK, 10, 156)
	var left := "Bumps: %d" % bumps if bumps > 0 else "No bumps yet"
	ClimbUI.ink(ci, Vector2(14, 32), "%d%% of the way down  ·  %s" % [roundi(depth * 100.0), left], ClimbUI.INK_SOFT, 10, 156)
	_gauge(SPEED_BAR, speed / MAX_SPEED, ClimbUI.GOOD if speed <= SAFE_SPEED else (ClimbUI.GOLD if speed <= HOT_SPEED else ClimbUI.WARN), "speed", SAFE_SPEED / MAX_SPEED)
	_gauge(HEAT_BAR, heat, Color("b3362b") if _locked > 0.0 else ClimbUI.WARN, "brake", -1.0)
	var hint := "Hold [%s] Let the rope run  ·  Let go to brake  ·  [%s] Hand it to the team" % [_use_button(), ClimbUI.button(ci, "Esc", "B")]
	var w := ClimbUI.keys_width(hint, 10) + 16
	var r := Rect2(roundf((SCREEN.x - w) / 2.0), SCREEN.y - 26, w, 18)
	ClimbUI.panel(ci, r)
	ClimbUI.keys(ci, Vector2(r.position.x + 8, r.position.y + 13), hint, ClimbUI.INK, 10)


## An upright gauge in a wood frame, filled [param frac] from the bottom,
## labeled under, with a cream tick at [param mark] (negative: none).
func _gauge(r: Rect2, frac: float, fill: Color, label: String, mark: float) -> void:
	var ci := _canvas
	ClimbUI.panel(ci, r.grow(3))
	ci.draw_rect(r, Color("2a1b14"))
	var h := roundf(r.size.y * clampf(frac, 0.0, 1.0))
	ci.draw_rect(Rect2(r.position.x, r.end.y - h, r.size.x, h), fill)
	ci.draw_rect(Rect2(r.position.x, r.end.y - h, r.size.x, minf(h, 2.0)), fill.lightened(0.3))
	if mark >= 0.0:
		var y := roundf(r.end.y - r.size.y * mark)
		ci.draw_rect(Rect2(r.position.x - 3, y, r.size.x + 6, 1), ClimbUI.CREAM)
	ClimbUI.outlined(ci, Vector2(r.position.x + r.size.x / 2.0, r.end.y + 14), label, ClimbUI.CREAM, 9, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


func _use_button() -> String:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	return hud.interact_button() if hud and hud.has_method("interact_button") else "E"
