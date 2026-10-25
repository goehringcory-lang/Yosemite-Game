class_name BinocularView
extends CanvasLayer
## Looking through one of Glacier Point's coin-operated viewers. The whole
## view from the railing is painted once as a panorama, three screens wide,
## by the climbing screen's sky and skyline painters (ClimbSky,
## ClimbLandscape) for the hour and the weather: Sentinel Rock and El Capitan
## down the Valley to the west, Yosemite Falls and the Royal Arches across
## it, Half Dome and Clouds Rest up Tenaya Canyon, the Merced's staircase of
## falls to the east under the snowy Sierra crest, and Curry Village 3,200
## feet straight down. You see it through two round lenses.
##
## Pan along the skyline, tilt down to the Valley floor, and switch between
## 8x and 16x. Hold a peak or a waterfall in the crosshairs and the viewer
## names it: brackets close round it, and the plaque below gives its height,
## how far off it is, its bearing, and a line about it. Everything you've
## named stays named (Park.spotted_peaks), and the tally at the right counts
## them.
##
##   var view := BinocularView.new()
##   view.setup("glacier_point", 65.0)   # facing Half Dome
##   add_child(view)
##   await view.finished

signal finished

const SCREEN := Vector2(480, 270)
const SHADER := preload("res://assets/shaders/binoculars.gdshader")
const P := preload("res://scripts/climb/art/climb_paint.gd")

## The two lenses, and the crosshair between them.
const LENS_LEFT := Vector2(182, 116)
const LENS_RIGHT := Vector2(298, 116)
const LENS_RADIUS := 100.0
const CENTER := Vector2(240, 116)
## Where the plaque under the lenses begins.
const PLAQUE_Y := 222.0
const ZOOMS := [1.0, 2.0]
const ZOOM_NAMES := ["8x", "16x"]
## Panorama pixels per second at 8x (half that, on screen, at 16x).
const PAN_SPEED := 120.0
const TILT_SPEED := 0.85
const TILT_MIN := -0.75
const TILT_MAX := 0.9
## Seconds a new landmark has to stay in the crosshairs to be named.
const LOCK := 0.6
## How far either side of the crosshair a landmark still counts as in it.
const REACH := 28.0
## The camera's height in the panorama, and how the layers (far, middle,
## near, the floor) sit level and rise as you tilt down: nearer things move
## more, so the drop feels like a drop.
const CAM_Y := 130.0
const LAYER_DROP := [0.0, 0.0, 0.0, 82.0]
const LAYER_TILT := [70.0, 95.0, 125.0, 200.0]
## The lip of Glacier Point itself, at the foot of the view when you look
## down: where it sits level, and how fast it rises.
const RIM_Y := 262.0
const RIM_TILT := 104.0
const RIM_H := 170
const SKY_TOP := -80.0
const SKY_TILT := 50.0
const SKY_H := 330
const IRIS := 0.35

const INK := Color("2a1b14")
const GOLD := Color("e8c068")
const PAPER := Color("efe4c8")
const DIM := Color("9a8f7a")
const FAINT := Color(0.937, 0.894, 0.784, 0.32)

## Each viewpoint and what's in it. The panorama runs from bearing "from" to
## "to" (past 360 for the far side of north), at "density" pixels per degree
## ([bearing, density] knots, eased between), so the compass runs smoothly
## and crowded stretches of skyline get more room. Every target stands at
## its true bearing from the railing. One with a landmark kind "k" is painted
## by ClimbLandscape (in layer "l", at scale "s"); "on" names the landmark a
## target is a part of; "floor" puts one on the Valley floor (at that height
## in the floor picture), "floor_river" on the river. "ax" is where across
## its landmark the anchor (the brackets) goes, its fall (or arches, or
## summit) as the real skyline from here has it if not given, and
## "ay" how far down from there. "stat" is the height (or the drop, for a
## fall), "mi" how far off, in miles. "text_fall" and "text_winter", when
## there, replace "text" in that season. "village" is where Curry Village
## stands in ClimbLandscape's floor picture, so it can be slid under its
## bearing.
const VIEWS := {
	"glacier_point": {
		"title": "Glacier Point", "elevation": "7,214 ft", "vantage": "glacier_point",
		"from": 242.0, "to": 506.0, "ground": "curry", "village": 335,
		"density": [[242, 7], [258, 8], [264, 15], [282, 15], [288, 3.5], [320, 3.5], [325, 10], [340, 10], [346, 4], [358, 4],
			[366, 11], [378, 13], [392, 12], [398, 8], [406, 10], [418, 14], [428, 14], [432, 11], [440, 15], [450, 12],
			[456, 13], [468, 12], [476, 10], [490, 8], [506, 8]],
		"backdrop": [{"k": "north_rim", "b": 302.0, "s": 1.1, "l": 1}, {"k": "sierra_crest", "b": 92.0, "s": 1.0, "l": 0}, {"k": "sierra_crest", "b": 113.0, "s": 0.8, "l": 0}],
		"targets": [
			{"id": "sentinel_rock", "name": "Sentinel Rock", "k": "sentinel_rock", "l": 2, "s": 0.95, "bearing": 266, "stat": "7,038 ft", "mi": 1.5,
				"text": "A granite obelisk on the Valley's south wall, 3,000 feet above the floor. In spring Sentinel Fall drops down the cliff beside it."},
			{"id": "el_capitan", "name": "El Capitan", "k": "el_capitan", "l": 1, "s": 0.72, "bearing": 274, "stat": "7,573 ft", "mi": 3.5,
				"text": "Three thousand feet of sheer granite down the Valley. Warren Harding's team topped out the Nose in 1958, after 47 days of work on the wall."},
			{"id": "eagle_peak", "name": "Eagle Peak", "k": "three_brothers", "l": 1, "s": 0.75, "bearing": 280, "stat": "7,779 ft", "mi": 2.6,
				"text": "The highest of the Three Brothers, three tilted blocks of granite stepped up the north wall, each broken off along the same set of joints."},
			{"id": "yosemite_falls", "name": "Yosemite Falls", "k": "yosemite_falls", "l": 1, "s": 0.8, "bearing": 325, "stat": "2,425 ft drop", "mi": 2.2, "ay": 0.25,
				"text": "Upper Fall, Middle Cascades and Lower Fall together drop 2,425 feet: one of the tallest waterfalls in North America. Loudest in May and June.",
				"text_fall": "Upper Fall, Middle Cascades and Lower Fall together drop 2,425 feet. By fall the creek runs low or dry; the first big storms bring it back."},
			{"id": "yosemite_point", "name": "Yosemite Point", "k": "north_rim", "l": 1, "s": 0.9, "bearing": 339, "stat": "6,936 ft", "mi": 2.2,
				"text": "The rim just east of the falls. Below it, Lost Arrow Spire stands out from the wall like a blade, 200 feet clear of the cliff at its tip."},
			{"id": "royal_arches", "name": "Royal Arches", "k": "royal_arches", "l": 2, "s": 1.0, "bearing": 4, "stat": "1,500 ft tall", "mi": 1.4, "ay": 0.3,
				"text": "Great arcs of granite that peeled off the wall in sheets, like the layers of an onion. The Ahwahnee hotel sits in the trees at their foot."},
			{"id": "north_dome", "name": "North Dome", "k": "north_dome", "l": 1, "s": 1.05, "bearing": 20, "stat": "7,542 ft", "mi": 2.1,
				"text": "A rounded crown above the Royal Arches, shaped as the granite shed its outer shells one by one. The view of Half Dome from its top is famous."},
			{"id": "basket_dome", "name": "Basket Dome", "k": "basket_dome", "l": 1, "s": 0.85, "bearing": 25, "stat": "7,612 ft", "mi": 2.6,
				"text": "A smaller dome on the north rim, above the mouth of Tenaya Canyon and Mirror Lake."},
			{"id": "mt_hoffmann", "name": "Mount Hoffmann", "k": "mt_hoffmann", "l": 0, "s": 1.3, "bearing": 27, "stat": "10,850 ft", "mi": 8.7,
				"text": "Near the geographic center of the park. From its summit, on a clear day, you can see most of Yosemite at once."},
			{"id": "washington_column", "name": "Washington Column", "k": "washington_column", "l": 2, "s": 0.9, "bearing": 34, "stat": "5,912 ft", "mi": 1.5,
				"text": "A tall pillar of granite beside the Royal Arches. Astroman, one of the great free climbs, goes straight up its east face."},
			{"id": "mt_watkins", "name": "Mount Watkins", "k": "mt_watkins", "l": 1, "s": 1.0, "bearing": 50, "stat": "8,500 ft", "mi": 4.1,
				"text": "Named for Carleton Watkins, whose photographs in the 1860s helped win the Valley its protection. Its south face drops into Tenaya Canyon."},
			{"id": "clouds_rest", "name": "Clouds Rest", "k": "clouds_rest", "l": 0, "s": 1.5, "bearing": 61, "stat": "9,926 ft", "mi": 5.3,
				"text": "Higher than Half Dome, standing behind it. Its northwest face falls nearly a mile into Tenaya Canyon, one of the biggest granite faces anywhere."},
			{"id": "half_dome", "name": "Half Dome", "k": "half_dome", "l": 1, "s": 1.35, "bearing": 65, "stat": "8,842 ft", "mi": 2.5,
				"text": "Its northwest face is nearly sheer for 2,000 feet. Royal Robbins's team climbed it in 1957: the first Grade VI climb in the country."},
			{"id": "mt_broderick", "name": "Mount Broderick", "k": "mt_broderick", "l": 2, "s": 1.0, "bearing": 74, "stat": "6,706 ft", "mi": 2.9,
				"text": "A rounded knob beside Liberty Cap, its granite smoothed and polished by the ice that once filled the canyon to its shoulders."},
			{"id": "liberty_cap", "name": "Liberty Cap", "k": "liberty_cap", "l": 1, "s": 1.3, "bearing": 76, "stat": "7,076 ft", "mi": 3.3,
				"text": "A smooth granite dome standing over Nevada Fall. The Mist Trail and the John Muir Trail both pass beneath it."},
			{"id": "mt_florence", "name": "Mount Florence", "k": "mt_florence", "l": 0, "s": 0.85, "bearing": 85, "stat": "12,561 ft", "mi": 13.3,
				"text": "Named for Florence Hutchings, the first child of settlers born in Yosemite Valley, in 1864. She grew up climbing all over it."},
			{"id": "mt_maclure", "name": "Mount Maclure", "k": "mt_maclure", "l": 0, "s": 0.8, "bearing": 87, "stat": "12,880 ft", "mi": 16.0,
				"text": "In 1872 John Muir set stakes in the glacier on its flank and watched them move: proof that living ice still worked in the Sierra."},
			{"id": "mt_lyell", "name": "Mount Lyell", "k": "mt_lyell", "l": 0, "s": 0.75, "bearing": 89, "stat": "13,114 ft", "mi": 16.5,
				"text": "The highest peak in the park. The Lyell Glacier on its north side feeds the Tuolumne River."},
			{"id": "vernal_fall", "name": "Vernal Fall", "k": "vernal_fall", "l": 2, "s": 1.0, "bearing": 97, "stat": "317 ft drop", "mi": 1.6, "ay": 0.1,
				"text": "The Merced drops 317 feet in a broad curtain. In spring its spray soaks everyone on the Mist Trail's granite stairs beside it."},
			{"id": "nevada_fall", "name": "Nevada Fall", "k": "nevada_fall", "l": 1, "s": 1.0, "bearing": 100, "stat": "594 ft drop", "mi": 2.3, "ay": 0.2,
				"text": "The Merced pours 594 feet over a granite lip and twists as it falls. The John Muir Trail crosses the river just above it."},
			{"id": "mt_clark", "name": "Mount Clark", "k": "mt_clark", "l": 0, "s": 0.75, "bearing": 106, "stat": "11,522 ft", "mi": 8.4,
				"text": "A sharp fin of the Clark Range, named for Galen Clark, the first Guardian of Yosemite."},
			{"id": "mt_starr_king", "name": "Mount Starr King", "k": "mt_starr_king", "l": 1, "s": 1.45, "bearing": 120, "stat": "9,092 ft", "mi": 4.7,
				"text": "A steep bald dome, named for Thomas Starr King, whose letters from Yosemite in 1860 helped draw the country's eye to it."},
			{"id": "illilouette_fall", "name": "Illilouette Fall", "k": "illilouette_fall", "l": 2, "s": 1.3, "bearing": 123, "stat": "370 ft drop", "mi": 0.8, "ay": 0.1,
				"text": "Illilouette Creek drops 370 feet into its own gorge, hidden from the Valley floor. This is one of the few places you can see it."},
			{"id": "curry_village", "name": "Curry Village", "floor": 306, "bearing": 7, "stat": "3,200 ft below", "mi": 0.5,
				"text": "Camp Curry, founded in 1899. On summer nights the Firefall poured off the cliff right where you're standing, to cheers from down there."},
			{"id": "merced_river", "name": "The Merced River", "floor_river": true, "bearing": 20, "stat": "3,200 ft below", "mi": 0.8,
				"text": "Down from its falls, the Merced winds slow through the Valley's meadows, and on west to the San Joaquin."},
		],
	},
}

var view_id := "glacier_point"
var spec: Dictionary = {}
## Where the viewer is pointed (panorama x at the crosshair), how far it's
## tilted down (-0.75 up .. 1 down), and the magnification (an index into
## ZOOMS, and the scale on its way there).
var pan_x := 0.0
var tilt := 0.0
var zoom_index := 0
var zoom := 1.0
## The landmark in the crosshairs (an index into targets), or -1.
var focus := -1

var _start_bearing := 65.0
var _targets: Array[Dictionary] = []
var _anchors: Array[Vector2] = []
var _scale := PackedFloat32Array()
## The panorama's width, in pixels.
var _width := 0
var _hour := 12.0
var _pal: Dictionary = {}
var _weather: Dictionary = {}
var _ready_to_draw := false
var _task := -1
var _painted: Dictionary = {}
var _sky: Texture2D
var _layers: Array[Texture2D] = []
var _rim: Texture2D
## The layer pictures, kept to tell when a nearer ridge hides a landmark.
var _images: Array[Image] = []
var _falls: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _canvas: Control
var _picture: Control
var _lens: ColorRect
var _overlay: Control
var _mat: ShaderMaterial
var _time := 0.0
var _open := 0.0
var _closing := false
var _focus_pull := 1.0
var _vel := Vector2.ZERO
var _lock := 0.0
var _flash := 0.0
var _new_mark := 0.0
var _plaque_in := 0.0
var _dragging := false

## The last panorama painted, kept so stepping up again is instant.
static var _cache_key := ""
static var _cache: Dictionary = {}


## [param view] is one of VIEWS; [param bearing] is where the viewer points
## when you step up to it.
func setup(view: String, bearing := 65.0) -> void:
	view_id = view
	_start_bearing = bearing


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiScale.layer(self)
	spec = VIEWS.get(view_id, VIEWS.glacier_point)
	_targets.clear()
	for t: Dictionary in spec.targets:
		_targets.append(t)
	_scale = make_scale(spec)
	_width = ceili(_scale[-1])
	pan_x = x_at(_start_bearing)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	UiScale.fit(_canvas)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_canvas)
	# back to front: the view, the lenses (which read the view), the readouts
	_picture = Control.new()
	_picture.name = "Picture"
	UiScale.fit(_picture)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.draw.connect(_draw_picture)
	_canvas.add_child(_picture)
	_lens = ColorRect.new()
	_lens.name = "Lenses"
	UiScale.fit(_lens)
	_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("left_center", LENS_LEFT)
	_mat.set_shader_parameter("right_center", LENS_RIGHT)
	_mat.set_shader_parameter("radius", LENS_RADIUS)
	_mat.set_shader_parameter("iris", 0.0)
	_mat.set_shader_parameter("blur", 1.0)
	_lens.material = _mat
	_canvas.add_child(_lens)
	_overlay = Control.new()
	_overlay.name = "Readouts"
	UiScale.fit(_overlay)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_canvas.add_child(_overlay)
	_hour = GameClock.minutes / 60.0
	_weather = Weather.today()
	_pal = ClimbSky.palette(_hour)
	Sound.play("ui_open", -4.0, 0.0)
	_start_painting()


func _exit_tree() -> void:
	# Don't leave a painter writing into a freed screen.
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


# ------------------------------------------------------------------ bearings

## The panorama's scale: its x at every quarter degree from the view's
## "from" bearing, summed from its density.
static func make_scale(view: Dictionary) -> PackedFloat32Array:
	var knots: Array = view.density
	var out := PackedFloat32Array()
	var x := 0.0
	var b: float = view.from
	while b <= float(view.to) + 0.001:
		out.append(x)
		x += _density(knots, b + 0.125) * 0.25
		b += 0.25
	return out


static func _density(knots: Array, b: float) -> float:
	if b <= knots[0][0]:
		return knots[0][1]
	for i in knots.size() - 1:
		var a: Array = knots[i]
		var n: Array = knots[i + 1]
		if b <= n[0]:
			return lerpf(a[1], n[1], smoothstep(a[0], n[0], b))
	return knots[-1][1]


## Bearings east of north run on past 360, so the panorama's run from west
## round to the southeast is one rising line.
static func unwrap(bearing: float) -> float:
	return bearing if bearing > 180.0 else bearing + 360.0


## The panorama x of [param bearing] on [param scale] (see make_scale).
static func scale_x(scale: PackedFloat32Array, view: Dictionary, bearing: float) -> float:
	var f := (unwrap(bearing) - float(view.from)) * 4.0
	var i := clampi(int(floorf(f)), 0, scale.size() - 2)
	return lerpf(scale[i], scale[i + 1], f - i)


## The panorama x where [param bearing] lies.
func x_at(bearing: float) -> float:
	return scale_x(_scale, spec, bearing)


## The bearing at panorama x [param x], 0..360.
func bearing_at(x: float) -> float:
	return fposmod(_unwrapped_bearing(x), 360.0)


func _unwrapped_bearing(x: float) -> float:
	var lo := 0
	var hi := _scale.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _scale[mid] <= x:
			lo = mid
		else:
			hi = mid
	var f := (x - _scale[lo]) / maxf(_scale[hi] - _scale[lo], 0.001)
	return float(spec.from) + (lo + f) / 4.0


## "NE", "ESE"... for [param bearing].
static func compass_point(bearing: float) -> String:
	var names := ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
	return names[int(roundf(fposmod(bearing, 360.0) / 22.5)) % 16]


# ------------------------------------------------------------------ painting

func _cache_id() -> String:
	return "%s:%.2f:%d:%s" % [view_id, snappedf(_hour, 0.25), GameClock.season, str(_weather)]


func _start_painting() -> void:
	if _cache_key == _cache_id() and not _cache.is_empty():
		_painted = _cache
		_finish_painting()
		return
	var pal := _pal.duplicate(true)
	var view: Dictionary = spec
	var hour := _hour
	var scale := _scale
	_task = WorkerThreadPool.add_task(func() -> void:
		_painted = BinocularView.paint(view, pal, hour, scale))


## Paints the panorama for [param view] under [param pal]: the sky, the three
## skyline layers and the floor, where each landmark's summit landed, and the
## falls to shimmer. Images only, so it can run on a worker thread.
static func paint(view: Dictionary, pal: Dictionary, hour: float, scale: PackedFloat32Array) -> Dictionary:
	var width := ceili(scale[-1])
	var specs: Array = []
	for b: Dictionary in view.get("backdrop", []):
		specs.append({"k": b.k, "x": roundi(scale_x(scale, view, b.b)), "s": b.get("s", 1.0), "l": b.get("l", 0)})
	var floor_x := 0
	for t: Dictionary in view.targets:
		if t.has("floor"):
			floor_x = roundi(scale_x(scale, view, t.bearing)) - int(view.get("village", 0))
		if not t.has("k"):
			continue
		# Stand the landmark so its summit (or its anchor) is at its bearing.
		var s: float = t.get("s", 1.0)
		var w := int(ClimbLandscape.LANDMARKS[t.k].w * s)
		var across: float = t.get("ax", ClimbLandscape.anchor_across(t.k, view.get("vantage", "")))
		var cx := scale_x(scale, view, t.bearing) - (across - 0.5) * w
		specs.append({"k": t.k, "x": roundi(cx), "s": s, "l": t.get("l", 1)})
	var land := ClimbLandscape.build({"view": specs, "ground": view.get("ground", "valley_forest"),
		"floor_x": floor_x, "vantage": view.get("vantage", "")}, pal, hash(view.title), width)
	var sky_x := func(b: float) -> float: return scale_x(scale, view, b)
	return {"land": land, "sky": paint_sky(pal, width, hour, sky_x), "rim": paint_rim(pal, width)}


## The granite lip you're standing on, seen as you lean over the railing:
## a ragged edge with manzanita clinging to it, and the face falling away
## below, lit at the top and going into shadow.
static func paint_rim(pal: Dictionary, width: int) -> Image:
	var im := Image.create_empty(width, RIM_H, false, Image.FORMAT_RGBA8)
	var c := ClimbLandscape._body(pal, 2)
	var ramp: Array[Color] = c.ramp
	var tops := PackedInt32Array()
	tops.resize(width)
	for x in width:
		tops[x] = 12 + int(P.smooth_noise(x / 31.0, 0.0, 41) * 16.0 + P.smooth_noise(x / 7.0, 3.0, 9) * 5.0)
	for x in width:
		var top := tops[x]
		var d := tops[maxi(x - 2, 0)] - tops[mini(x + 2, width - 1)]
		var t0 := 0.9 + (P.noise(x / 3, 0, 19) - 0.5) * 0.9 - clampf(d * 0.15, -0.6, 0.6)
		ClimbLandscape._band_col(im, x, top, RIM_H, t0, t0 + 3.2, ramp)
		im.set_pixel(x, top, ramp[0] if d >= 0 else ramp[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7214
	# joints and water streaks down the face
	for i in width / 18:
		var x := rng.randi_range(0, width - 1)
		var y := tops[x] + rng.randi_range(4, 30)
		var col: Color = ramp[4] if i % 3 else ramp[3]
		while y < RIM_H:
			ClimbLandscape._px(im, x, y, col)
			y += 1
			if rng.randf() < 0.12:
				x = clampi(x + rng.randi_range(-1, 1), 0, width - 1)
	# manzanita and a few small firs on the lip
	for i in width / 26:
		var x := rng.randi_range(4, width - 5)
		var y := tops[x] + 1
		if rng.randf() < 0.75:
			ClimbLandscape._ell(im, x, y, rng.randi_range(3, 6), 2, c.tree_dk)
			ClimbLandscape._ell(im, x - 1, y - 1, 2, 1, c.tree)
			ClimbLandscape._px(im, x - 2, y - 2, c.tree_lit)
		else:
			ClimbLandscape._conifer(im, x, y - 9, 9, c, true)
	return im


## The sky across the whole panorama: ClimbSky's banded colors, stars at
## night, and the sun or moon where it really stands at [param hour] (it
## rises in the east, at the right, and sets down the Valley to the west).
static func paint_sky(pal: Dictionary, width: int, hour: float, x_of: Callable) -> Image:
	var im := Image.create_empty(width, SKY_H, false, Image.FORMAT_RGBA8)
	var strip := Image.create_empty(4, SKY_H, false, Image.FORMAT_RGBA8)
	var bands := 14
	for y in SKY_H:
		var t := y / float(SKY_H - 1)
		for x in 4:
			var q: float = t * bands + (ClimbSky.BAYER[y % 4][x] / 16.0 - 0.5) * 0.9
			strip.set_pixel(x, y, ClimbSky._sky_at(pal, clampf(floorf(q) / bands, 0.0, 1.0)))
	for x in range(0, width, 4):
		im.blit_rect(strip, Rect2i(0, 0, 4, SKY_H), Vector2i(x, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7214
	if pal.night:
		for i in width / 9:
			var p := Vector2i(rng.randi_range(0, width - 1), rng.randi_range(0, 210))
			var a := rng.randf_range(0.35, 1.0)
			im.set_pixelv(p, Color(1, 1, 0.95, a))
			if a > 0.93 and p.x > 0 and p.y > 0:
				# a few bright ones get a little cross
				for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var q := (p + o).clamp(Vector2i.ZERO, Vector2i(width - 1, SKY_H - 1))
					im.set_pixelv(q, im.get_pixelv(q).lerp(Color(1, 1, 0.95), 0.45))
		var night_t := fposmod(hour - 20.5, 24.0) / 9.0
		var mx := int(x_of.call(100.0 + night_t * 170.0))
		var my := int(250 - sin(clampf(night_t, 0.0, 1.0) * PI) * 210)
		_disc(im, Vector2i(mx, my), 6, Color("d6f1ee"), Color("bdb8ae"))
	else:
		var day_t := clampf((hour - 5.5) / 15.0, 0.0, 1.0)
		var sx := int(x_of.call(75.0 + day_t * 210.0))
		var sy := int(262 - sin(day_t * PI) * 300)
		_glow(im, Vector2i(sx, sy), 30, pal.sun)
		_disc(im, Vector2i(sx, sy), 6, pal.sun, (pal.sun as Color).darkened(0.08))
	return im


static func _disc(im: Image, c: Vector2i, r: int, col: Color, shade: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var p := c + Vector2i(x, y)
			if x * x + y * y <= r * r and p.x >= 0 and p.y >= 0 and p.x < im.get_width() and p.y < im.get_height():
				im.set_pixelv(p, shade if x + y > r / 2 else col)


static func _glow(im: Image, c: Vector2i, r: int, col: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var p := c + Vector2i(x, y)
			var d := sqrt(x * x + y * y) / r
			if d < 1.0 and p.x >= 0 and p.y >= 0 and p.x < im.get_width() and p.y < im.get_height():
				if ClimbSky.BAYER[p.y % 4][p.x % 4] / 16.0 < (1.0 - d) * 0.77:
					im.set_pixelv(p, im.get_pixelv(p).lerp(col, 0.35))


## Turns the painted images into textures, and works out where each target
## sits in the panorama.
func _finish_painting() -> void:
	_cache_key = _cache_id()
	_cache = _painted
	var land: Dictionary = _painted.land
	_sky = ImageTexture.create_from_image(_painted.sky)
	_layers.clear()
	var images: Array[Image] = []
	for l: Dictionary in land.layers:
		images.append(l.image)
		_layers.append(ImageTexture.create_from_image(l.image))
	_images = images
	_falls = land.falls
	_rim = ImageTexture.create_from_image(_painted.rim)
	var peaks := {}
	for p: Dictionary in land.peaks:
		peaks[p.k] = p
	_anchors.clear()
	for t: Dictionary in _targets:
		_anchors.append(_anchor_for(t, peaks, images))
	# Clouds: more of them on a cloudy day, low and heavy in a storm.
	_clouds.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_cache_key)
	var cover: float = _weather.get("clouds", 0.3)
	var count := int(4 + cover * 16)
	for i in count:
		var img := ClimbSky.cloud(_pal, 300 + i)
		_clouds.append({"tex": ImageTexture.create_from_image(img), "x": rng.randf_range(0.0, float(_width)),
			"y": rng.randf_range(-40.0, 70.0 + cover * 50.0), "speed": rng.randf_range(1.0, 3.0)})
	_ready_to_draw = true
	Sound.play("climb_clip", -6.0, 0.02, 0.8)


## Where target [param t]'s brackets go, in panorama-layer picture
## coordinates (x, y in its layer's image), plus its layer in z.
func _anchor_for(t: Dictionary, peaks: Dictionary, images: Array[Image]) -> Vector2:
	var x := x_at(t.bearing)
	if t.has("floor"):
		return Vector2(x, t.floor)
	if t.has("floor_river"):
		# On the river, which the floor painter lays along this curve.
		var top := 130 + ClimbLandscape.PAD
		return Vector2(x, top + 74 + int(sin(int(x) * 0.03 + 1.0) * 9.0 + sin(int(x) * 0.011) * 14.0) + 1)
	var key: String = t.get("k", t.get("on", ""))
	var peak: Dictionary = peaks.get(key, {})
	var l := layer_of(_targets.find(t))
	var from_y: int = peak.get("y", 0) if t.has("k") else 0
	var top_y := _column_top(images[l], int(x), from_y)
	var base: float = ClimbLandscape.LAYER_BASE[l] + 10 + ClimbLandscape.PAD
	return Vector2(x, lerpf(top_y, base, t.get("ay", 0.0)))


## The first solid pixel down column [param x] of [param im], from
## [param from_y] up a little (so a summit's own rim is found).
static func _column_top(im: Image, x: int, from_y: int) -> int:
	x = clampi(x, 0, im.get_width() - 1)
	for y in range(maxi(from_y - 4, 0), im.get_height()):
		if im.get_pixel(x, y).a > 0.5:
			return y
	return from_y


## The layer target [param i] is painted in (3 for the floor).
func layer_of(i: int) -> int:
	var t := _targets[i]
	if t.has("floor") or t.has("floor_river"):
		return 3
	if t.has("on"):
		for o: Dictionary in _targets:
			if o.get("k", "") == t.on:
				return o.get("l", 1)
	return t.get("l", 1)


# ------------------------------------------------------------------ the view

## Where layer [param l]'s picture sits in the panorama at the current tilt.
func layer_y(l: int) -> float:
	return -ClimbLandscape.PAD + LAYER_DROP[l] - tilt * LAYER_TILT[l]


## Where the lip of the point sits in the panorama at the current tilt.
func rim_y() -> float:
	return RIM_Y - tilt * RIM_TILT


## True when target [param i] can be seen: in a lens, and not behind the
## Valley floor (for the peaks) or the lip you're leaning over.
func is_visible_target(i: int, margin := 6.0) -> bool:
	var s := anchor_on_screen(i)
	if not in_lens(s, margin):
		return false
	var a := _anchors[i]
	var pano_y := a.y + layer_y(layer_of(i))
	if pano_y > rim_y() + 14.0:
		return false
	# Behind a nearer ridge, or the floor?
	var x := int(a.x)
	for near in range(layer_of(i) + 1, _images.size()):
		var y := int(pano_y - layer_y(near)) + 1
		var im := _images[near]
		if x >= 0 and x < im.get_width() and y >= 0 and y < im.get_height() and im.get_pixel(x, y).a > 0.5:
			return false
	return true


## Panorama point -> screen point, at the current pan, tilt and zoom.
func to_screen(p: Vector2) -> Vector2:
	return CENTER + (p - Vector2(pan_x, CAM_Y)) * zoom


## Target [param i]'s anchor on screen.
func anchor_on_screen(i: int) -> Vector2:
	var a := _anchors[i]
	return to_screen(Vector2(a.x, a.y + layer_y(layer_of(i))))


## True when [param p] (screen) is inside a lens, [param margin] in from its rim.
func in_lens(p: Vector2, margin := 0.0) -> bool:
	var r := LENS_RADIUS - margin
	return p.distance_to(LENS_LEFT) < r or p.distance_to(LENS_RIGHT) < r


func _process(delta: float) -> void:
	_time += delta
	if not _ready_to_draw:
		if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
			_finish_painting()
		elif _closing and _task < 0:
			finished.emit()
			queue_free()
		_overlay.queue_redraw()
		return
	if _closing:
		_open = maxf(_open - delta / (IRIS * 0.7), 0.0)
		if _open <= 0.0:
			finished.emit()
			queue_free()
	else:
		_open = minf(_open + delta / IRIS, 1.0)
		_steer(delta)
	_focus_pull = maxf(_focus_pull - delta * 1.6, 0.0)
	zoom = move_toward(zoom, ZOOMS[zoom_index], delta * 5.0)
	var zoom_blur := absf(zoom - ZOOMS[zoom_index]) * 1.4
	var eased := 1.0 - pow(1.0 - _open, 3.0)
	_mat.set_shader_parameter("iris", eased)
	_mat.set_shader_parameter("blur", clampf(maxf(_focus_pull, zoom_blur) + absf(_vel.x) / 900.0, 0.0, 1.2))
	_clamp_view()
	_update_focus(delta)
	_flash = maxf(_flash - delta * 2.5, 0.0)
	_new_mark = maxf(_new_mark - delta, 0.0)
	_plaque_in = minf(_plaque_in + delta * 6.0, 1.0)
	_picture.queue_redraw()
	_overlay.queue_redraw()


## Pans and tilts with the stick or keys, with a little weight to it.
func _steer(delta: float) -> void:
	var want := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	if Input.is_action_pressed("run"):
		want.x *= 2.2
	var target := Vector2(want.x * PAN_SPEED / zoom, want.y * TILT_SPEED / zoom)
	_vel = _vel.lerp(target, clampf(delta * 9.0, 0.0, 1.0))
	if not _dragging:
		pan_x += _vel.x * delta
		tilt += _vel.y * delta


func _clamp_view() -> void:
	var half := (LENS_RIGHT.x + LENS_RADIUS - CENTER.x) / zoom
	pan_x = clampf(pan_x, half, float(_width) - half)
	tilt = clampf(tilt, TILT_MIN, TILT_MAX)


## Finds what's in the crosshairs and, held there, names it.
func _update_focus(delta: float) -> void:
	var best := -1
	var best_d := REACH
	for i in _targets.size():
		var s := anchor_on_screen(i)
		if not is_visible_target(i) or absf(s.y - CENTER.y) > 90.0:
			continue
		var d := absf(s.x - CENTER.x) + absf(s.y - CENTER.y) * 0.15
		if d < best_d:
			best_d = d
			best = i
	if best != focus:
		focus = best
		_lock = 0.0
		_plaque_in = 0.0
		if best >= 0:
			Sound.play("ui_move", -10.0, 0.02)
	if focus < 0 or is_spotted(focus):
		return
	# Hold steady: the lock only builds while you're not swinging past.
	if absf(_vel.x) < 40.0 / zoom:
		_lock += delta
	if _lock >= LOCK:
		spot(focus)


## True once target [param i] has been named.
func is_spotted(i: int) -> bool:
	return Park.spotted_peaks.has(_targets[i].id)


## Names target [param i]: it's added to the tally, with a flash and a chime.
func spot(i: int) -> void:
	if is_spotted(i):
		return
	Park.spotted_peaks[_targets[i].id] = true
	_flash = 1.0
	_new_mark = 2.5
	_plaque_in = 0.0
	Sound.play("pickup", -3.0, 0.0, 1.1)


## How many of this view's targets have been named.
func spotted_count() -> int:
	var n := 0
	for i in _targets.size():
		if is_spotted(i):
			n += 1
	return n


func close() -> void:
	if _closing:
		return
	_closing = true
	Sound.play("ui_close", -4.0, 0.0)


func _set_zoom(index: int) -> void:
	index = clampi(index, 0, ZOOMS.size() - 1)
	if index == zoom_index:
		return
	zoom_index = index
	Sound.play("climb_clip", -9.0, 0.03, 1.25 if index > 0 else 1.0)
	# Zooming in on something levels the view on it.
	if index > 0 and focus >= 0:
		var a := _anchors[focus]
		var l := layer_of(focus)
		var want: float = (a.y - ClimbLandscape.PAD + LAYER_DROP[l] - CAM_Y + 10.0) / LAYER_TILT[l]
		tilt = clampf(want, TILT_MIN, TILT_MAX) if l < 3 else tilt
		pan_x = lerpf(pan_x, a.x, 0.6)


func _input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif MenuInput.confirm(event):
		get_viewport().set_input_as_handled()
		if _ready_to_draw:
			_set_zoom(0 if zoom_index > 0 else 1)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom_index + 1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom_index - 1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var motion := (event as InputEventMouseMotion).relative / UiScale.FACTOR
		pan_x -= motion.x / zoom
		tilt += motion.y / (LAYER_TILT[1] * zoom)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("use_tool"):
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ drawing

## The panorama: sky, clouds, the skyline layers back to front with their
## falls shimmering, birds, the weather, then the floor.
func _draw_picture() -> void:
	var c := _picture
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color.BLACK)
	if not _ready_to_draw:
		return
	var origin := (CENTER - Vector2(pan_x, CAM_Y) * zoom).round()
	c.draw_set_transform(origin, 0.0, Vector2(zoom, zoom))
	c.draw_texture(_sky, Vector2(0, roundf(SKY_TOP - tilt * SKY_TILT)))
	var night: bool = _pal.night
	var tint := Color(1, 1, 1, 0.92) if not night else Color(0.45, 0.48, 0.6, 0.55)
	var sky_y := SKY_TOP - tilt * SKY_TILT
	for cl: Dictionary in _clouds:
		var x := fposmod(cl.x + _time * cl.speed, float(_width) + 80.0) - 40.0
		c.draw_texture(cl.tex, Vector2(x, cl.y + sky_y + 80.0).round(), tint)
	var storm: float = maxf(_weather.get("rain", 0.0), _weather.get("snow", 0.0))
	var haze := ClimbLandscape._haze(_pal)
	for l in _layers.size():
		var y := roundf(layer_y(l))
		c.draw_texture(_layers[l], Vector2(0, y))
		_draw_shimmer(c, l, y)
		if l == 1:
			_draw_birds(c)
		if storm > 0.0 and l < 2:
			# Cloud down on the peaks: the far ones all but gone.
			var a: float = storm * (0.7 if l == 0 else 0.35)
			c.draw_rect(Rect2(0, y, float(_width), _layers[l].get_height()), Color(haze, a))
	c.draw_texture(_rim, Vector2(0, roundf(rim_y())))
	c.draw_set_transform(Vector2.ZERO)
	if storm > 0.0:
		_draw_precipitation(c, storm)


## Waterfalls shimmer, as on the wall.
func _draw_shimmer(c: CanvasItem, l: int, off: float) -> void:
	for f: Dictionary in _falls:
		if f.layer != l:
			continue
		for y in range(int(f.y0) + 2, int(f.y1), 3):
			if fmod(_time * 7.0 + y * 0.21, 3.0) < 1.0:
				var pos := Vector2(f.x + 1 + int(sin(_time * 3.0 + y * 0.3) * 1.2), y + off)
				c.draw_rect(Rect2(pos, Vector2(1, 2)), Color(0.961, 0.933, 0.878, 0.8))


## A pair of ravens riding the updraft off the cliff, by day.
func _draw_birds(c: CanvasItem) -> void:
	if _pal.night:
		return
	for i in 2:
		var t := _time * (0.05 + i * 0.013) + i * 0.47
		var x := pan_x + sin(t * TAU * 0.37 + i) * 150.0 + sin(t * 1.7) * 30.0
		var y := CAM_Y + 30.0 + cos(t * TAU * 0.29 + i * 2.0) * 22.0 - tilt * 60.0
		var flap := int(_time * (5.0 + i)) % 4 == 0
		var col := Color(0.08, 0.07, 0.1, 0.9)
		var p := Vector2(roundf(x), roundf(y))
		var tip := 1.0 if flap else -1.0
		# a raven: body, wings swept up in a glide, down on the beat
		c.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), col)
		c.draw_rect(Rect2(p + Vector2(-3, tip), Vector2(2, 1)), col)
		c.draw_rect(Rect2(p + Vector2(2, tip), Vector2(2, 1)), col)
		c.draw_rect(Rect2(p + Vector2(0, 1), Vector2(1, 1)), col)


## Rain streaks or snowflakes across the glass.
func _draw_precipitation(c: CanvasItem, amount: float) -> void:
	var snow: bool = _weather.get("snow", 0.0) > 0.0
	var n := int(40 * amount)
	for i in n:
		var seed_x := float((i * 9301 + 49297) % 233280) / 233280.0
		var speed := (60.0 + (i % 5) * 18.0) if not snow else (14.0 + (i % 4) * 5.0)
		var x := fposmod(seed_x * 400.0 - _time * (12.0 if not snow else 6.0), 400.0) + 40.0
		var y := fposmod(float(i * 37 % 200) + _time * speed, 220.0) + 6.0
		if snow:
			x += sin(_time * 1.3 + i) * 3.0
			c.draw_rect(Rect2(roundf(x), roundf(y), 1, 1), Color(1, 1, 1, 0.75))
		else:
			c.draw_line(Vector2(x, y), Vector2(x - 2, y + 6), Color(0.85, 0.9, 1.0, 0.35))


## Everything read off the view: the crosshair, names on the skyline, the
## brackets round what's in the crosshairs, the compass, the dials at the
## sides and the plaque below.
func _draw_overlay() -> void:
	var c := _overlay
	var font := c.get_theme_default_font()
	if not _ready_to_draw:
		_center_text(c, font, "...", Vector2(240, 120), 10, DIM)
		return
	var shown := clampf((_open - 0.6) / 0.4, 0.0, 1.0)
	if shown <= 0.0:
		return
	c.modulate.a = shown
	_draw_crosshair(c)
	_draw_pins(c, font)
	if focus >= 0:
		_draw_brackets(c, font)
	_draw_compass(c, font)
	_draw_dials(c, font)
	_draw_plaque(c, font)


func _draw_crosshair(c: CanvasItem) -> void:
	var col := Color(PAPER, 0.55)
	var p := CENTER
	# four arms with a gap in the middle
	c.draw_rect(Rect2(p.x - 9, p.y, 6, 1), col)
	c.draw_rect(Rect2(p.x + 4, p.y, 6, 1), col)
	c.draw_rect(Rect2(p.x, p.y - 9, 1, 6), col)
	c.draw_rect(Rect2(p.x, p.y + 4, 1, 6), col)
	# A rangefinder scale along the horizontal.
	for k in range(-6, 7):
		if k == 0:
			continue
		var x := p.x + k * 14.0
		var tall := 3.0 if k % 2 == 0 else 1.0
		c.draw_rect(Rect2(x, p.y - floorf(tall / 2.0), 1, tall), FAINT)
	c.draw_rect(Rect2(p, Vector2(1, 1)), Color(GOLD, 0.8))


## A small mark and name on every landmark in sight; "?" for the ones the
## viewer hasn't named yet. Names that would overlap stack, or wait.
func _draw_pins(c: CanvasItem, font: Font) -> void:
	var taken: Array[Rect2] = []
	if focus >= 0:
		var fs := anchor_on_screen(focus)
		taken.append(Rect2(fs - Vector2(44, 36), Vector2(88, 44)))
	var order: Array[int] = []
	for i in _targets.size():
		order.append(i)
	# nearest first, so they get the low places
	order.sort_custom(func(a: int, b: int) -> bool: return layer_of(a) > layer_of(b))
	for i in order:
		if i == focus or not is_visible_target(i, 10.0):
			continue
		var s := anchor_on_screen(i).round()
		var known := is_spotted(i)
		var label: String = _targets[i].name if known else "?"
		var w := ceilf(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
		var placed := false
		for lift in [14.0, 26.0, 38.0]:
			var r := Rect2(roundf(s.x - w / 2.0) - 3, s.y - lift - 9, w + 6, 11)
			var clear := true
			for o: Rect2 in taken:
				if o.grow(1.0).intersects(r):
					clear = false
					break
			if clear and in_lens(r.position + Vector2(0, 5), 2.0) and in_lens(r.end - Vector2(0, 5), 2.0):
				taken.append(r)
				var col := PAPER if known else GOLD
				# a leader down to the mark, then the tag
				c.draw_rect(Rect2(s.x, r.end.y, 1, s.y - r.end.y - 1), Color(col, 0.5))
				c.draw_rect(Rect2(s - Vector2(1, 1), Vector2(3, 3)), Color(INK, 0.75))
				c.draw_rect(Rect2(s, Vector2(1, 1)), col)
				c.draw_rect(r, Color(INK, 0.62))
				c.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Color(col, 0.35))
				_label(c, font, label, Vector2(r.position.x + 3, r.end.y - 3), 8, Color(col, 0.95))
				placed = true
				break
		if not placed:
			c.draw_rect(Rect2(s, Vector2(1, 1)), Color(PAPER, 0.6))


## Corner brackets round the landmark in the crosshairs. They close in as
## the lock builds, flash when it takes, and carry its name above.
func _draw_brackets(c: CanvasItem, font: Font) -> void:
	var s := anchor_on_screen(focus).round()
	var known := is_spotted(focus)
	var t := 1.0 if known else clampf(_lock / LOCK, 0.0, 1.0)
	var grow := 1.0 + (1.0 - t) * 0.6 + _flash * 0.15
	var half := Vector2(17, 12) * grow
	var box := Rect2(s - half + Vector2(0, 4), half * 2.0)
	var col := GOLD.lerp(Color.WHITE, _flash) if known else Color(PAPER, 0.5 + 0.5 * t)
	var arm := 5.0
	for corner in 4:
		var px := box.position.x if corner % 2 == 0 else box.end.x - 1
		var py := box.position.y if corner < 2 else box.end.y - 1
		var dx := 1.0 if corner % 2 == 0 else -1.0
		var dy := 1.0 if corner < 2 else -1.0
		c.draw_rect(Rect2(minf(px, px + dx * (arm - 1)), py, arm, 1).abs(), col)
		c.draw_rect(Rect2(px, minf(py, py + dy * (arm - 1)), 1, arm).abs(), col)
	if _flash > 0.0:
		c.draw_rect(box.grow(2.0 + (1.0 - _flash) * 6.0), Color(1, 0.95, 0.8, _flash * 0.5), false, 1.0)
	var label: String = _targets[focus].name if known else "Identifying"
	if not known:
		label += ".".repeat(int(_time * 3.0) % 4)
	var w := ceilf(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x)
	if not known:
		w = ceilf(font.get_string_size("Identifying...", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x)
	var tag := Rect2(roundf(s.x - w / 2.0) - 4, box.position.y - 17, w + 8, 14)
	if tag.position.y < 24.0 or not in_lens(tag.position, 0.0):
		tag.position.y = box.end.y + 3
	c.draw_rect(tag, Color(INK, 0.75))
	c.draw_rect(Rect2(tag.position.x, tag.end.y - 1, tag.size.x, 1), Color(col, 0.8))
	_label(c, font, label, Vector2(tag.position.x + 4, tag.end.y - 4), 10, GOLD if known else PAPER)


## The compass tape across the top: a tick for every degree (when there's
## room), numbers every ten, the points of the compass, and a caret over
## where the viewer points.
func _draw_compass(c: CanvasItem, font: Font) -> void:
	var y := 16.0
	var half := 106.0
	c.draw_rect(Rect2(CENTER.x - half, y, half * 2.0, 1), Color(DIM, 0.5))
	var b0 := floorf(_unwrapped_bearing(pan_x - half / zoom))
	var b1 := ceilf(_unwrapped_bearing(pan_x + half / zoom))
	var deg := b0
	while deg <= b1:
		var x := roundf(CENTER.x + (x_at(fposmod(deg, 360.0)) - pan_x) * zoom)
		var room := absf(CENTER.x + (x_at(fposmod(deg + 1.0, 360.0)) - pan_x) * zoom - x)
		var d := int(fposmod(deg, 360.0))
		if absf(x - CENTER.x) <= half:
			var fade := 1.0 - pow(absf(x - CENTER.x) / half, 4.0)
			if d % 45 == 0:
				c.draw_rect(Rect2(x, y - 5, 1, 5), Color(PAPER, fade))
				_center_text(c, font, compass_point(d), Vector2(x + 0.5, y - 7), 8, Color(GOLD if d % 90 == 0 else PAPER, fade))
			elif d % 10 == 0:
				c.draw_rect(Rect2(x, y - 4, 1, 4), Color(PAPER, 0.75 * fade))
				if room * 10.0 > 34.0:
					_center_text(c, font, str(d), Vector2(x + 0.5, y - 7), 8, Color(DIM, fade))
			elif d % 5 == 0:
				c.draw_rect(Rect2(x, y - 3, 1, 3), Color(DIM, 0.8 * fade))
			elif room >= 5.0:
				c.draw_rect(Rect2(x, y - 1, 1, 1), Color(DIM, 0.6 * fade))
		deg += 1.0
	# the caret
	c.draw_colored_polygon(PackedVector2Array([Vector2(CENTER.x - 3, y + 2), Vector2(CENTER.x + 4, y + 2), Vector2(CENTER.x + 0.5, y + 5.5)]), GOLD)


## The dials in the black at the sides: magnification, bearing and tilt at
## the left, the tally and the seeing at the right, and the controls.
func _draw_dials(c: CanvasItem, font: Font) -> void:
	var lx := 10.0
	_label(c, font, "POWER", Vector2(lx, 40), 8, DIM)
	_label(c, font, ZOOM_NAMES[zoom_index], Vector2(lx, 56), 16, GOLD)
	var bearing := bearing_at(pan_x)
	_label(c, font, "BEARING", Vector2(lx, 74), 8, DIM)
	_label(c, font, "%03d°  %s" % [int(roundf(bearing)) % 360, compass_point(bearing)], Vector2(lx, 86), 10, PAPER)
	# tilt: a little level with a bubble
	_label(c, font, "TILT", Vector2(lx, 102), 8, DIM)
	var gx := lx + 2.0
	var gy := 108.0
	c.draw_rect(Rect2(gx, gy, 3, 44), Color(DIM, 0.4))
	var mark := gy + (tilt - TILT_MIN) / (TILT_MAX - TILT_MIN) * 41.0
	c.draw_rect(Rect2(gx - 2, roundf(mark), 7, 3), GOLD)
	c.draw_rect(Rect2(gx + 5, gy + (0.0 - TILT_MIN) / (TILT_MAX - TILT_MIN) * 41.0 + 1, 3, 1), Color(PAPER, 0.6))
	_label(c, font, "rim" if tilt < 0.45 else "floor", Vector2(gx + 11, roundf(mark) + 5), 8, Color(PAPER, 0.7))
	# controls
	var tree := get_tree()
	var hints := [
		[MenuInput.button(tree, "Arrows", "Stick"), "Look"],
		[MenuInput.button(tree, "E", "A"), "Zoom"],
		[MenuInput.button(tree, "Esc", "B"), "Leave"],
	]
	for k in hints.size():
		_label(c, font, hints[k][0], Vector2(lx, 172 + k * 11), 8, GOLD)
		_label(c, font, hints[k][1], Vector2(lx + 38, 172 + k * 11), 8, Color(PAPER, 0.8))
	# right: the tally, a dot for each landmark
	var rx := 408.0
	var total := _targets.size()
	var got := spotted_count()
	_label(c, font, "IDENTIFIED", Vector2(rx, 40), 8, DIM)
	_label(c, font, "%d / %d" % [got, total], Vector2(rx, 56), 16, GOLD)
	for i in total:
		var dot := Vector2(rx + (i % 6) * 9, 64 + (i / 6) * 9)
		c.draw_rect(Rect2(dot, Vector2(6, 6)), Color(DIM, 0.35))
		if is_spotted(i):
			var col := GOLD.lerp(Color.WHITE, _flash) if i == focus else GOLD
			c.draw_rect(Rect2(dot + Vector2(1, 1), Vector2(4, 4)), col)
	if got == total:
		_label(c, font, "Every one!", Vector2(rx, 122), 8, GOLD)
	_label(c, font, "SEEING", Vector2(rx, 150), 8, DIM)
	_label(c, font, seeing(), Vector2(rx, 162), 10, PAPER)
	_label(c, font, "%s  %s" % [spec.title, spec.elevation], Vector2(rx, 194), 8, Color(PAPER, 0.6))
	_label(c, font, _clock_text(), Vector2(rx, 205), 8, Color(PAPER, 0.6))


## How clear the air is: what the plaque calls the day's visibility.
func seeing() -> String:
	if _weather.get("snow", 0.0) > 0.0:
		return "Snowing"
	if _weather.get("rain", 0.0) > 0.0:
		return "Rain"
	if _pal.night:
		return "Starlight"
	if _weather.get("clouds", 0.0) > 0.45:
		return "Fair"
	if _hour < 7.5 or _hour > 18.5:
		return "Low light"
	return "Excellent"


func _clock_text() -> String:
	var h := int(_hour) % 24
	var m := int(fposmod(_hour * 60.0, 60.0))
	return "%d:%02d %s" % [12 if h % 12 == 0 else h % 12, m, "AM" if h < 12 else "PM"]


## The brass plaque under the lenses: the name, its numbers, and a line
## about it, or what to do when nothing's in the crosshairs.
func _draw_plaque(c: CanvasItem, font: Font) -> void:
	var y := PLAQUE_Y
	c.draw_rect(Rect2(22, y, 436, 1), Color(GOLD, 0.35))
	c.draw_rect(Rect2(22, y + 1, 436, 1), Color(INK, 0.6))
	var a := 1.0 - pow(1.0 - _plaque_in, 2.0)
	var slide := (1.0 - a) * 4.0
	var known := focus >= 0 and is_spotted(focus)
	if focus >= 0 and known:
		var t: Dictionary = _targets[focus]
		_label(c, font, t.name, Vector2(26 + slide, y + 15), 10, Color(GOLD, a))
		var name_w := font.get_string_size(t.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		if _new_mark > 0.0:
			var blink := 1.0 if _new_mark > 0.6 else _new_mark / 0.6
			var bx := 32 + name_w + slide
			c.draw_rect(Rect2(bx, y + 6, 22, 11), Color(GOLD, 0.9 * blink))
			_label(c, font, "NEW", Vector2(bx + 3, y + 15), 8, Color(INK, blink))
		var stats := "%s   %s mi   %s %d°" % [t.stat, _miles(t.mi), compass_point(t.bearing), int(t.bearing)]
		var sw := font.get_string_size(stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_label(c, font, stats, Vector2(454 - sw, y + 15), 8, Color(PAPER, 0.75 * a))
		c.draw_multiline_string(font, Vector2(26 + slide, y + 28), text_for(focus), HORIZONTAL_ALIGNMENT_LEFT, 428, 8, 2, Color(PAPER, a))
	elif focus >= 0:
		_label(c, font, "Hold steady...", Vector2(26, y + 15), 10, PAPER)
		var bar := Rect2(26, y + 24, 140, 3)
		c.draw_rect(bar, Color(DIM, 0.35))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_lock / LOCK, 0.0, 1.0), bar.size.y)), GOLD)
		_label(c, font, "Keep it in the crosshairs to name it.", Vector2(26, y + 40), 8, Color(PAPER, 0.7))
	else:
		_label(c, font, "%s  ·  %s" % [spec.title, spec.elevation], Vector2(26, y + 15), 10, Color(GOLD, 0.9))
		var hint := "Pan along the skyline, or tilt down to the Valley floor 3,200 feet below. Hold a peak or a waterfall in the crosshairs to name it."
		if _pal.night:
			hint = "The peaks are dark shapes against the stars tonight. Hold one in the crosshairs to name it, or come back by daylight."
		c.draw_multiline_string(font, Vector2(26, y + 28), hint, HORIZONTAL_ALIGNMENT_LEFT, 428, 8, 2, Color(PAPER, 0.8))


## What the plaque says about target [param i], for the season.
func text_for(i: int) -> String:
	var t: Dictionary = _targets[i]
	match GameClock.season:
		GameClock.Season.FALL:
			return t.get("text_fall", t.text)
		GameClock.Season.WINTER:
			return t.get("text_winter", t.text)
	return t.text


static func _miles(mi: float) -> String:
	return ("%.1f" % mi).trim_suffix(".0") if mi < 10.0 else str(int(roundf(mi)))


func _label(c: CanvasItem, font: Font, text: String, at: Vector2, size: int, col: Color) -> void:
	c.draw_string(font, at.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _center_text(c: CanvasItem, font: Font, text: String, at: Vector2, size: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(font, Vector2(roundf(at.x - w / 2.0), roundf(at.y)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
