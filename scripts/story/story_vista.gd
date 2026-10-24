class_name StoryVista
extends CanvasLayer
## A sighting, seen the way the person who saw it saw it: a few seconds of
## the valley from their side, painted by the climbing screen's sky and
## skyline painters (ClimbSky, ClimbLandscape), with the speck that was you
## somewhere on the granite, and their words under it. StoryMoments plays one
## the first time each sighting comes true (GuardianSearch.SIGHTINGS).
##
##   var vista := StoryVista.new()
##   vista.setup(StoryMoments.MOMENTS["partner_apron"], {"who": "James Lamon", "text": "..."})
##   add_child(vista)
##   await vista.finished
##
## Letterboxed like a film. The view rises slowly (the skyline's layers slide
## at their own speeds, as they do on the wall), the speck catches the light,
## and the witness's portrait and words type out on the band below. Confirm
## shows all the words, then closes; cancel closes at once.

signal finished

const SCREEN := Vector2(480, 270)
const TOP_BAR := 24.0
const BOTTOM_BAR := 66.0
const FADE := 0.6
## How long the view takes to rise, and how long it holds after the words.
const RISE := 9.0
const LINGER := 2.5
const INK := Color("2a1b14")
const GOLD := Color("e8c068")
const PAPER := Color("efe4c8")
const GRAYSCALE := preload("res://assets/shaders/photograph.gdshader")

var spec: Dictionary = {}
var sighting: Dictionary = {}
var _canvas: Control
var _picture: Control
var _veil: ColorRect
var _title: Label
var _who: Label
var _text: Label
var _portrait: TextureRect
var _sky: Texture2D
var _layers: Array[Dictionary] = []
var _time := 0.0
var _fade := 1.0
var _shown := 0.0
var _closing := false
var _figure := Vector2(-100, -100)
var _figure_layer := 1
var _ready_to_draw := false


## [param moment] is one of StoryMoments.MOMENTS; [param words] is
## {"who": display name, "text": what they said}.
func setup(moment: Dictionary, words: Dictionary) -> void:
	spec = moment
	sighting = words


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiScale.layer(self)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	UiScale.fit(_canvas)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_canvas)
	# back to front: the picture, the letterbox, the words, the fade
	_picture = Control.new()
	_picture.name = "Picture"
	UiScale.fit(_picture)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.draw.connect(_draw_picture)
	if spec.get("photograph", false):
		var mat := ShaderMaterial.new()
		mat.shader = GRAYSCALE
		_picture.material = mat
	_canvas.add_child(_picture)
	var bars := Control.new()
	bars.name = "Bars"
	UiScale.fit(bars)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.draw.connect(func() -> void:
		bars.draw_rect(Rect2(0, 0, SCREEN.x, TOP_BAR), Color.BLACK)
		bars.draw_rect(Rect2(0, SCREEN.y - BOTTOM_BAR, SCREEN.x, BOTTOM_BAR), Color.BLACK)
		bars.draw_rect(Rect2(0, SCREEN.y - BOTTOM_BAR, SCREEN.x, 1), GOLD.darkened(0.5)))
	_canvas.add_child(bars)
	_build_words()
	_veil = ColorRect.new()
	_veil.name = "Fade"
	UiScale.fit(_veil)
	_veil.color = Color.BLACK
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_veil)
	_paint()
	Sound.play("story_sting", -2.0, 0.0)


## The title on the band above, the witness's face, name and words below.
func _build_words() -> void:
	_title = Label.new()
	_title.name = "Title"
	_title.text = spec.get("title", "")
	_title.position = Vector2(0, 5)
	_title.size = Vector2(SCREEN.x, 14)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", GOLD)
	_canvas.add_child(_title)
	var band_top := SCREEN.y - BOTTOM_BAR
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.texture = Portraits.for_speaker(sighting.get("who", ""), spec.get("mood", "surprised"))
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.position = Vector2(14, band_top + 8)
	_portrait.size = Vector2(50, 50)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.add_child(_portrait)
	var left := 74.0 if _portrait.texture else 16.0
	var width := SCREEN.x - left - 14
	_who = Label.new()
	_who.name = "Who"
	_who.text = "%s, %s" % [sighting.get("who", ""), spec.get("from", "")] if spec.get("from", "") != "" else sighting.get("who", "")
	_who.add_theme_color_override("font_color", GOLD)
	_who.clip_text = true
	_canvas.add_child(_who)
	_who.position = Vector2(left, band_top + 6)
	_who.size = Vector2(width, 12)
	_text = Label.new()
	_text.name = "Words"
	_text.text = sighting.get("text", "")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("font_color", PAPER)
	_text.visible_characters = 0
	_canvas.add_child(_text)
	# a wrapping label is sized once it's in the tree, or it grows to fit
	_text.position = Vector2(left, band_top + 20)
	_text.size = Vector2(width, BOTTOM_BAR - 24)


## Paints the sky and the skyline for the moment's hour, and finds where the
## speck stands: [code]figure[/code] is {"x", "down"}, a column of the
## landmark layer and how far down its face (0 the skyline, 1 its foot).
func _paint() -> void:
	var pal := ClimbSky.palette(float(spec.get("hour", 12.0)))
	_sky = ImageTexture.create_from_image(ClimbSky.sky(pal))
	var land := ClimbLandscape.build({"view": spec.get("view", []), "ground": spec.get("ground", "valley_forest"),
		"alpine": spec.get("alpine", false)}, pal, hash(spec.get("title", "")))
	_layers.clear()
	for l: Dictionary in land.layers:
		_layers.append({"tex": ImageTexture.create_from_image(l.image), "sink": l.sink, "pad": l.pad, "image": l.image})
	var fig: Dictionary = spec.get("figure", {})
	if not fig.is_empty():
		_figure_layer = int(fig.get("l", 1))
		var im: Image = _layers[_figure_layer].image
		var x := clampi(int(fig.x), 0, im.get_width() - 1)
		var base: int = ClimbLandscape.LAYER_BASE[_figure_layer] + 10 + ClimbLandscape.PAD
		var top: int = base
		for y in range(0, base):
			if im.get_pixel(x, y).a > 0.5:
				top = y
				break
		_figure = Vector2(x, lerpf(top, base, float(fig.get("down", 0.3))))
	for l: Dictionary in _layers:
		l.erase("image")
	_ready_to_draw = true


## How far the view has risen (0 to 1, eased), as the wall's height does.
func rise() -> float:
	var from: float = spec.get("rise_from", 0.45)
	var to: float = spec.get("rise_to", 0.7)
	var t := clampf(_time / RISE, 0.0, 1.0)
	return lerpf(from, to, t * t * (3.0 - 2.0 * t))


func _process(delta: float) -> void:
	_time += delta
	if _closing:
		_fade = minf(_fade + delta / FADE, 1.0)
		if _fade >= 1.0:
			finished.emit()
			queue_free()
	else:
		_fade = maxf(_fade - delta / FADE, 0.0)
		if _fade <= 0.0:
			var cps := Settings.chars_per_second()
			_shown = _shown + delta * cps if cps > 0.0 else float(_text.text.length())
			_text.visible_characters = mini(int(_shown), _text.text.length())
		if _text.visible_characters >= _text.text.length() and _time > RISE + LINGER * 2.0:
			close()
	_veil.color.a = _fade
	_picture.queue_redraw()


## Starts the fade back to the world.
func close() -> void:
	_closing = true


## True once every word is showing.
func is_revealed() -> bool:
	return _text.visible_characters >= _text.text.length()


func _input(event: InputEvent) -> void:
	if _closing:
		return
	if MenuInput.confirm(event):
		get_viewport().set_input_as_handled()
		if not is_revealed():
			_shown = float(_text.text.length())
			_text.visible_characters = -1
		else:
			close()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## The view: sky, skyline layers (rising), the speck, and what the witness
## stood among in front. (On its own Control, so a photograph can be grey.)
func _draw_picture() -> void:
	var c := _picture
	if not _ready_to_draw:
		c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color.BLACK)
		return
	c.draw_texture(_sky, Vector2.ZERO)
	var h := rise()
	for i in _layers.size():
		var l: Dictionary = _layers[i]
		c.draw_texture(l.tex, Vector2(0, roundf(h * l.sink) - l.pad))
		if i == _figure_layer and _figure.x >= 0.0 and spec.get("figure_kind", "climber") != "wreck":
			_draw_figure(c, _figure + Vector2(0, roundf(h * l.sink) - l.pad))
	if spec.get("figure_kind", "") == "wreck":
		# the wreck lies in the near grass, in front of everything
		_draw_wreck(c, Vector2(spec.get("wreck_x", 300.0), SCREEN.y - BOTTOM_BAR - 14.0))
	_draw_foreground(c)


## You, very small: a climber two pixels wide, catching the light, with a
## slow ring of light round them so the eye finds them. At night, a headlamp.
func _draw_figure(c: CanvasItem, at: Vector2) -> void:
	var kind: String = spec.get("figure_kind", "climber")
	var p := at.round()
	if kind == "headlamp":
		for k in 3:
			var on := fmod(_time * (1.3 + k * 0.4) + k, 2.0) < 1.6
			var lamp := p + Vector2(k * 7 - 7, k * 11 - 8)
			if on:
				c.draw_rect(Rect2(lamp - Vector2(2, 2), Vector2(5, 5)), Color(1.0, 0.85, 0.5, 0.25))
				c.draw_rect(Rect2(lamp, Vector2(1, 1)), Color("fff2c0"))
		return
	if kind == "wreck":
		_draw_wreck(c, p)
		return
	if kind == "stakes":
		# Muir's stakes in a line across the ice, and the climber beside them
		for k in 5:
			var s := p + Vector2(-26 + k * 11, 4 + k)
			c.draw_rect(Rect2(s, Vector2(1, 4)), Color("3a2a22"))
	var pulse := 0.5 + 0.5 * sin(_time * 2.4)
	# a soft ring of light, so the eye finds the speck
	c.draw_arc(p + Vector2(1, -4), 9.0 + pulse * 3.0, 0.0, TAU, 24, Color(1.0, 0.95, 0.8, 0.35 + 0.35 * pulse), 1.0)
	c.draw_arc(p + Vector2(1, -4), 5.0, 0.0, TAU, 16, Color(1.0, 0.95, 0.8, 0.15), 3.0)
	# the climber: three pixels wide, lit on the sun side
	c.draw_rect(Rect2(p + Vector2(-1, -8), Vector2(4, 8)), Color("1e1614"))
	c.draw_rect(Rect2(p + Vector2(0, -7), Vector2(2, 3)), Color("6a8a4a"))
	c.draw_rect(Rect2(p + Vector2(0, -4), Vector2(2, 3)), Color("3a4466"))
	c.draw_rect(Rect2(p + Vector2(0, -9), Vector2(2, 2)), Color("f0c088"))
	c.draw_rect(Rect2(p + Vector2(-2, -8), Vector2(1, 2)), Color("f0c088"))


## The old car at El Portal, one axle gone: rust on the gold grass.
func _draw_wreck(c: CanvasItem, p: Vector2) -> void:
	var rust := Color("8a4a2a")
	c.draw_rect(Rect2(p + Vector2(-14, -8), Vector2(28, 6)), rust)
	c.draw_rect(Rect2(p + Vector2(-8, -12), Vector2(14, 4)), rust.darkened(0.2))
	c.draw_rect(Rect2(p + Vector2(-6, -11), Vector2(4, 2)), Color("3a3a40"))
	c.draw_rect(Rect2(p + Vector2(0, -11), Vector2(4, 2)), Color("3a3a40"))
	# one wheel still on; the back sits in the grass where the axle was
	c.draw_circle(p + Vector2(-9, -2), 3.0, Color("2a2a2e"))
	c.draw_rect(Rect2(p + Vector2(6, -3), Vector2(8, 2)), rust.darkened(0.4))
	var pulse := 0.5 + 0.5 * sin(_time * 2.4)
	c.draw_arc(p + Vector2(10, -2), 5.0 + pulse * 2.0, 0.0, TAU, 20, Color(1.0, 0.95, 0.8, 0.2 + 0.25 * pulse), 1.0)


## What the witness was standing among: Lamon's apple trees, Camp Curry's
## tent cabins, a print's white border...
func _draw_foreground(c: CanvasItem) -> void:
	var bottom := SCREEN.y - BOTTOM_BAR
	var dark := Color("14100e")
	match spec.get("foreground", ""):
		"orchard":
			# Lamon's apple trees against the dawn: crooked trunks, low
			# spreading crowns of clumps, a rim of dawn light, blossom
			var leaf := Color("1a1c16")
			var rim := Color("4a3a52")
			for k in 3:
				var x := 40.0 + k * 170.0 + (k % 2) * 30.0
				c.draw_rect(Rect2(x - 2, bottom - 26, 5, 26), dark)
				c.draw_rect(Rect2(x + 2, bottom - 30, 8, 3), dark)
				c.draw_rect(Rect2(x - 9, bottom - 28, 8, 3), dark)
				var clumps := [Vector3(0, -40, 15), Vector3(-17, -33, 12), Vector3(17, -35, 13), Vector3(-8, -50, 11), Vector3(10, -49, 11), Vector3(-27, -27, 8), Vector3(26, -28, 8)]
				for cl: Vector3 in clumps:
					c.draw_circle(Vector2(x + cl.x - 1, bottom + cl.y - 1), cl.z, rim)
				for cl: Vector3 in clumps:
					c.draw_circle(Vector2(x + cl.x, bottom + cl.y), cl.z, leaf)
				for b in 6:
					c.draw_rect(Rect2(x - 22 + b * 9, bottom - 54 + (b * 7) % 24, 2, 2), Color("e8b8c4"))
		"tents":
			for k in 4:
				var x := 20.0 + k * 128.0
				var w := 70.0
				var roof := PackedVector2Array([Vector2(x, bottom), Vector2(x + w / 2.0, bottom - 22), Vector2(x + w, bottom)])
				c.draw_colored_polygon(roof, dark)
				c.draw_rect(Rect2(x + w / 2.0 - 4, bottom - 10, 8, 10), Color(1.0, 0.8, 0.4, 0.5) if k % 2 == 0 else dark)
		"pines":
			# conifers in tiers, drooping at the tips, a trunk at the foot
			for k in 7:
				var x := 10.0 + k * 74.0
				var hgt := 46.0 + (k % 3) * 12.0
				c.draw_rect(Rect2(x - 2, bottom - 8, 4, 8), dark)
				for tier in 4:
					var t := float(tier) / 4.0
					var y0 := bottom - 6 - hgt * t
					var half := 15.0 * (1.0 - t * 0.7)
					c.draw_colored_polygon(PackedVector2Array([Vector2(x - half, y0), Vector2(x, y0 - hgt * 0.38),
						Vector2(x + half, y0), Vector2(x + half * 0.6, y0 + 2), Vector2(x - half * 0.6, y0 + 2)]), dark)
	if spec.get("photograph", false):
		# the white border of the print
		var edge := 10.0
		var mat := Color("e8e4d8")
		c.draw_rect(Rect2(0, TOP_BAR, SCREEN.x, edge), mat)
		c.draw_rect(Rect2(0, bottom - edge, SCREEN.x, edge), mat)
		c.draw_rect(Rect2(0, TOP_BAR, edge, bottom - TOP_BAR), mat)
		c.draw_rect(Rect2(SCREEN.x - edge, TOP_BAR, edge, bottom - TOP_BAR), mat)
