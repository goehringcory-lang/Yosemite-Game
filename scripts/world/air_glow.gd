class_name AirGlow
extends WorldEnvironment
## Real glow after dark, on High graphics (the Forward+ renderer): the bright
## cores of lamps, fires and lit windows spill soft light into the night air
## round them. It takes over from the halo sprites NightLight draws on Low,
## where the renderer has no glow. Only the world glows: the HUD and menus
## sit on canvas layers above it. It fades in with the night (as DayNight's
## tint darkens), so nothing pale blooms by day; indoors it follows the
## room's lamps (RoomLight).

## How strong the glow is at full night.
const STRENGTH := 1.2
## Only pixels brighter than this glow. At night, under the tint, only the
## lights themselves and the ground right under them get that bright.
const THRESHOLD := 0.72

var _tint: CanvasModulate
## The glow, set as [member environment] only while something glows: any
## environment at all, even with its glow off, sends the whole 2D picture
## through the 3D pipeline (a depth pass and tonemap over the full screen
## every frame), which by day is all cost and nothing to see.
var _env: Environment


## True when the game draws real glow (and NightLight skips its halos).
static func active() -> bool:
	return LitSprites.active()


func _ready() -> void:
	name = "AirGlow"
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = THRESHOLD
	env.glow_hdr_scale = 2.0
	env.glow_bloom = 0.0
	# wide, soft levels for light in the air, one tight one for the core
	for i in 7:
		env.set_glow_level(i, [0.0, 0.0, 0.6, 1.0, 1.0, 0.6, 0.0][i])
	_env = env
	# On for the first frame, so the glow's shaders are built while the game
	# loads, not with a hitch the first time night falls.
	env.glow_enabled = true
	env.glow_intensity = 0.0
	environment = env


func _process(_delta: float) -> void:
	if _tint == null:
		_tint = get_parent().get_node_or_null("DayNight") as CanvasModulate
	var dark := 0.0
	if active() and _tint != null and _tint.visible:
		var lum := (_tint.color.r + _tint.color.g + _tint.color.b) / 3.0
		dark = clampf((0.9 - lum) / 0.45, 0.0, 1.0)
	elif active():
		# a room at night: firelight and lamps glow, more gently
		dark = RoomLight.level * 0.6
	var glowing := dark > 0.01
	_env.glow_enabled = glowing
	_env.glow_intensity = STRENGTH * dark
	var want: Environment = _env if glowing else null
	if environment != want:
		environment = want
