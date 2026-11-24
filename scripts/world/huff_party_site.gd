class_name HuffPartySite
extends Node2D
## The HUFF crew's off-trail forest party after 10 PM: two thumping PA speakers
## playing a positional forest-rave beat (huff_party.wav), a DJ crate and beer
## cooler, sweeping colored dance lights (PointLight2D pools + additive beams),
## drifting smoke, and four dancing HUFF employees who offer beer, weed and LSD.

const NPC_SCENE := preload("res://scenes/story/npc.tscn")
const COOLER_TEX := preload("res://assets/sprites/curry/cooler.png")

## How far away (world pixels) the muffled bass from the speakers can be heard
## through the pines and boulders.
const SPEAKER_REACH := 860.0
const SPEAKER_LEVEL := 0.85

## Dance light colors: magenta, electric cyan, neon lime/gold.
const LIGHT_COLORS: Array[Color] = [
	Color(1.0, 0.22, 0.72),
	Color(0.15, 0.92, 1.0),
	Color(0.76, 1.0, 0.25),
]

static var _speaker_tex: ImageTexture
static var _deck_tex: ImageTexture
static var _light_tex: GradientTexture2D

var _clock := 0.0
var _speakers: Array[Sprite2D] = []
var _lights: Array[PointLight2D] = []
var _beams: Node2D
var partiers: Array[HuffPartier] = []


func _init() -> void:
	name = "HuffPartySite"
	y_sort_enabled = true


## Builds the speakers, DJ crate, cooler, dance lights, positional audio and
## dancing HUFF crew around [param center_local] in [param region].
func setup(region: Region, center_local: Vector2) -> void:
	position = center_local
	_build_textures()
	var grid := WalkGrid.of(region)
	var center_world := region.to_global(center_local)

	# Positional bass beat from the speakers.
	var emitter := SoundEmitter.make("huff_party", SPEAKER_REACH, SPEAKER_LEVEL)
	emitter.position = Vector2(0, -16)
	add_child(emitter)

	# Two stacked PA speakers flanking the DJ crate.
	for sx: float in [-42.0, 42.0]:
		var body := StaticBody2D.new()
		body.name = "HuffSpeakerLeft" if sx < 0.0 else "HuffSpeakerRight"
		body.position = Vector2(sx, -18.0)
		body.collision_mask = 0
		var sp := Sprite2D.new()
		sp.name = "Sprite"
		sp.texture = _speaker_tex
		sp.offset = Vector2(0, -22)
		body.add_child(sp)
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(22, 12)
		col.shape = rect
		col.position = Vector2(0, -6)
		body.add_child(col)
		add_child(body)
		_speakers.append(sp)

	# DJ milk-crate deck between the speakers.
	var deck := StaticBody2D.new()
	deck.name = "HuffDJDeck"
	deck.position = Vector2(0.0, -20.0)
	deck.collision_mask = 0
	var deck_sp := Sprite2D.new()
	deck_sp.name = "Sprite"
	deck_sp.texture = _deck_tex
	deck_sp.offset = Vector2(0, -14)
	deck.add_child(deck_sp)
	var deck_col := CollisionShape2D.new()
	var deck_rect := RectangleShape2D.new()
	deck_rect.size = Vector2(30, 12)
	deck_col.shape = deck_rect
	deck_col.position = Vector2(0, -6)
	deck.add_child(deck_col)
	add_child(deck)

	# Cooler stocked with cold King Cobras.
	var cooler := StaticBody2D.new()
	cooler.name = "HuffPartyCooler"
	cooler.position = Vector2(22.0, -10.0)
	cooler.collision_mask = 0
	var cooler_sp := Sprite2D.new()
	cooler_sp.name = "Sprite"
	cooler_sp.texture = COOLER_TEX
	cooler_sp.offset = Vector2(0, -12)
	cooler.add_child(cooler_sp)
	var cooler_col := CollisionShape2D.new()
	var cooler_rect := RectangleShape2D.new()
	cooler_rect.size = Vector2(24, 10)
	cooler_col.shape = cooler_rect
	cooler_col.position = Vector2(0, -5)
	cooler.add_child(cooler_col)
	add_child(cooler)

	# Sweeping colored dance PointLight2Ds lighting up the forest and boulders.
	for i in LIGHT_COLORS.size():
		var light := PointLight2D.new()
		light.name = "DanceLight%d" % i
		light.texture = _light_tex
		light.texture_scale = 2.6
		light.color = LIGHT_COLORS[i]
		light.energy = 1.35
		light.height = 28.0
		light.shadow_enabled = false
		add_child(light)
		_lights.append(light)

	# Additive sweeping light beams & glowing disco pools over the clearing.
	_beams = _DanceBeams.new()
	_beams.name = "DanceBeams"
	add_child(_beams)

	# Soft rising smoke in the night air.
	var smoke := AmbientFx.new()
	smoke.name = "PartySmoke"
	smoke.effect = "smoke"
	smoke.area = Vector2(36, 12)
	smoke.position = Vector2(0, -24)
	smoke.z_index = 5
	add_child(smoke)

	# Four dancing HUFF employees positioned on verified open WalkGrid spots.
	var offsets: Array[Vector2] = [
		Vector2(-2.0, -2.0),   # Rico at the decks
		Vector2(-32.0, 22.0),  # Macy
		Vector2(34.0, 20.0),   # Devon near the cooler
		Vector2(0.0, 34.0),    # Tessa under the lights
	]
	for i in HuffParty.CREW_PATHS.size():
		var data := load(HuffParty.CREW_PATHS[i]) as CharacterData
		if data == null:
			continue
		var want_world := center_world + offsets[i]
		var open_world := grid.nearest_open(want_world, 5)
		var raw: Node = NPC_SCENE.instantiate()
		raw.set_script(HuffPartier)
		var npc := raw as HuffPartier
		npc.name = "HuffPartier_" + data.id
		npc.character = data
		npc.stands_still = true
		npc.dance_phase = float(i) * 0.65
		npc.party_center = Vector2.ZERO
		npc.position = open_world - center_world
		add_child(npc)
		partiers.append(npc)


func _process(delta: float) -> void:
	_clock += delta
	var beat := _clock * HuffParty.BEAT_HZ
	var thump := pow(maxf(0.0, sin(beat * PI)), 4.0)
	# Speakers pulse slightly outward on every kick drum.
	for i in _speakers.size():
		var sp := _speakers[i]
		if is_instance_valid(sp):
			var s := 1.0 + thump * 0.08
			sp.scale = Vector2(s, 1.0 - thump * 0.04)
	# Orbit and pulse the three colored dance lights across the clearing.
	for i in _lights.size():
		var light := _lights[i]
		if not is_instance_valid(light):
			continue
		var angle := _clock * (0.9 + float(i) * 0.35) + float(i) * (TAU / 3.0)
		var rx := 58.0 + 18.0 * sin(_clock * 0.7 + float(i))
		var ry := 34.0 + 12.0 * cos(_clock * 0.6 + float(i))
		light.position = Vector2(cos(angle) * rx, sin(angle) * ry - 6.0)
		var pulse := 0.85 + 0.65 * pow(maxf(0.0, sin((beat + float(i) * 0.33) * PI)), 2.0)
		light.energy = pulse * 1.45
	if is_instance_valid(_beams):
		_beams.set("clock", _clock)
		_beams.queue_redraw()


static func _build_textures() -> void:
	if _light_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.55, 0.82, 1.0])
		g.colors = PackedColorArray([
			Color(1, 1, 1, 1), Color(1, 1, 1, 0.72), Color(1, 1, 1, 0.32),
			Color(1, 1, 1, 0.08), Color(1, 1, 1, 0),
		])
		_light_tex = GradientTexture2D.new()
		_light_tex.gradient = g
		_light_tex.fill = GradientTexture2D.FILL_RADIAL
		_light_tex.fill_from = Vector2(0.5, 0.5)
		_light_tex.fill_to = Vector2(1.0, 0.5)
		_light_tex.width = 128
		_light_tex.height = 128
	if _speaker_tex == null:
		_speaker_tex = _make_speaker_texture()
	if _deck_tex == null:
		_deck_tex = _make_deck_texture()


## Crisp 28x44 pixel-art PA speaker cabinet with woofer, tweeter and LED strip.
static func _make_speaker_texture() -> ImageTexture:
	var w := 28
	var h := 44
	var im := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var edge := Color("14151c")
	var body := Color("262934")
	var hi := Color("3b4052")
	var grille := Color("1b1d26")
	var cone := Color("494e63")
	var dust := Color("171820")
	# Cabinet box (x: 2..25, y: 2..41)
	for y in range(2, 42):
		for x in range(2, 26):
			var border := x == 2 or x == 25 or y == 2 or y == 41
			im.set_pixel(x, y, edge if border else (hi if y == 3 or x == 3 else body))
	# Recessed speaker grille
	for y in range(5, 38):
		for x in range(5, 23):
			im.set_pixel(x, y, grille)
	# Upper tweeter horn (center 14, 12, radius 4.5)
	for y in range(7, 18):
		for x in range(9, 20):
			var d := Vector2(x - 14.0, y - 12.0).length()
			if d <= 4.6:
				im.set_pixel(x, y, dust if d <= 1.8 else cone)
	# Lower woofer cone (center 14, 28, radius 7.5)
	for y in range(20, 36):
		for x in range(6, 23):
			var d := Vector2(x - 14.0, y - 28.0).length()
			if d <= 7.4:
				im.set_pixel(x, y, dust if d <= 2.6 else (hi if d > 6.2 else cone))
	# Glowing power & VU meter LEDs along the bottom rim
	im.set_pixel(6, 39, Color("32ff7e"))
	im.set_pixel(7, 39, Color("32ff7e"))
	im.set_pixel(10, 39, Color("18dcff"))
	im.set_pixel(11, 39, Color("18dcff"))
	im.set_pixel(14, 39, Color("fffa65"))
	im.set_pixel(15, 39, Color("fffa65"))
	im.set_pixel(18, 39, Color("ff38b8"))
	im.set_pixel(19, 39, Color("ff38b8"))
	# Rubber feet
	for fx in [4, 5, 22, 23]:
		im.set_pixel(fx, 42, edge)
		im.set_pixel(fx, 43, edge)
	return ImageTexture.create_from_image(im)


## Crisp 34x28 pixel-art DJ crate & portable mixer deck with glowing cue pads.
static func _make_deck_texture() -> ImageTexture:
	var w := 34
	var h := 28
	var im := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var edge := Color("14151c")
	var crate := Color("3b3229")
	var slat := Color("594b3c")
	var deck := Color("242733")
	var platter := Color("14161e")
	var silver := Color("8b92a8")
	# Wooden milk crate base (y: 12..27)
	for y in range(12, 28):
		for x in range(3, 31):
			var border := x == 3 or x == 30 or y == 12 or y == 27
			var stripe := (y == 17 or y == 22) and x > 4 and x < 29
			im.set_pixel(x, y, edge if border else (slat if stripe else crate))
	# Mixer / controller on top (y: 4..13)
	for y in range(4, 14):
		for x in range(2, 32):
			var border := x == 2 or x == 31 or y == 4 or y == 13
			im.set_pixel(x, y, edge if border else deck)
	# Two jog wheels
	for cx in [9, 24]:
		for y in range(6, 12):
			for x in range(cx - 3, cx + 4):
				var d := Vector2(x - cx, y - 8.5).length()
				if d <= 3.1:
					im.set_pixel(x, y, silver if d > 2.2 else platter)
	# Glowing colored performance pads in the middle
	im.set_pixel(15, 7, Color("ff38b8"))
	im.set_pixel(16, 7, Color("ff38b8"))
	im.set_pixel(18, 7, Color("18dcff"))
	im.set_pixel(19, 7, Color("18dcff"))
	im.set_pixel(15, 10, Color("a8ff33"))
	im.set_pixel(16, 10, Color("a8ff33"))
	im.set_pixel(18, 10, Color("ffaa22"))
	im.set_pixel(19, 10, Color("ffaa22"))
	return ImageTexture.create_from_image(im)


## Additive sweeping dance-light beams, disco floor spots and beat rings over
## the clearing so the lights shine brightly even on Low graphics.
class _DanceBeams extends Node2D:
	var clock := 0.0

	func _init() -> void:
		z_index = 12
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _draw() -> void:
		var beat := clock * HuffParty.BEAT_HZ
		var thump := pow(maxf(0.0, sin(beat * PI)), 3.0)
		var origin := Vector2(0, -28)
		# Three sweeping translucent light cones from the deck/light stand.
		for i in HuffPartySite.LIGHT_COLORS.size():
			var base_col: Color = HuffPartySite.LIGHT_COLORS[i]
			var sweep := sin(clock * (1.2 + float(i) * 0.45) + float(i) * 2.1) * 0.95
			var dir_angle := PI * 0.5 + sweep + (float(i) - 1.0) * 0.45
			var length := 115.0 + 20.0 * sin(clock * 1.7 + float(i))
			var spread := 0.16 + thump * 0.05
			var p1 := origin + Vector2.from_angle(dir_angle - spread) * length
			var p2 := origin + Vector2.from_angle(dir_angle + spread) * length
			var cone_col := Color(base_col.r, base_col.g, base_col.b, 0.20 + thump * 0.12)
			draw_colored_polygon(PackedVector2Array([origin, p1, p2]), cone_col)
			# Bright floor spot where the beam lands.
			var spot := origin + Vector2.from_angle(dir_angle) * (length * 0.72)
			draw_circle(spot, 14.0 + thump * 5.0, Color(base_col.r, base_col.g, base_col.b, 0.24 + thump * 0.14))
			draw_circle(spot, 6.0, Color(base_col.r, base_col.g, base_col.b, 0.40))
		# Expanding sound-wave rings from both speakers on the beat.
		var wave_t := fposmod(beat, 1.0)
		var wave_r := 8.0 + wave_t * 28.0
		var wave_a := (1.0 - wave_t) * 0.32
		for sx: float in [-42.0, 42.0]:
			draw_arc(Vector2(sx, -24.0), wave_r, 0.0, TAU, 20, Color(0.75, 0.95, 1.0, wave_a), 1.5)
		# Glowing light-bar dots over the DJ crate.
		for i in HuffPartySite.LIGHT_COLORS.size():
			var c: Color = HuffPartySite.LIGHT_COLORS[i]
			var lx := (float(i) - 1.0) * 14.0
			draw_circle(Vector2(lx, -34.0), 4.0 + thump * 2.0, Color(c.r, c.g, c.b, 0.75))
