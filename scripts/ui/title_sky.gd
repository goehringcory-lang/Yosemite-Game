class_name TitleSky
extends Control
## The life in the title screen's sky: a few small pixel clouds drifting east
## over the painting, and now and then a pair of ravens gliding across,
## flapping a few beats and then sailing. Drawn at the title's 480x270, every
## shape snapped to whole pixels so it sits with the painted art.

const SCREEN := Vector2(480, 270)
const CLOUD_LIGHT := Color(0.976, 0.965, 0.937, 0.92)
const CLOUD_SHADE := Color(0.82, 0.855, 0.89, 0.92)
const RAVEN := Color(0.106, 0.098, 0.122)
## Each cloud: [x at start, y, width, pixels a second].
const CLOUDS := [
	[40.0, 18.0, 34, 2.2],
	[250.0, 44.0, 22, 3.1],
	[400.0, 8.0, 28, 1.6],
	[150.0, 64.0, 18, 3.6],
]
## A raven seen from below: gliding, wings up, wings down. "#" is a feather.
const RAVEN_FRAMES := [
	[
		"##.......##",
		"..##...##..",
		"....###....",
		".....#.....",
	],
	[
		"#.........#",
		".#.......#.",
		"..##...##..",
		"....###....",
		".....#.....",
	],
	[
		"....###....",
		"..##.#.##..",
		".#.......#.",
		"#.........#",
	],
]
## Seconds before the first ravens, and between one pair and the next.
const FIRST_RAVENS := 2.5
const RAVEN_GAP := 16.0
const RAVEN_SPEED := 26.0

var _time := 0.0
## Each cloud's shape as rows of [x offset, width] spans, built once.
var _shapes: Array = []
var _next_ravens := FIRST_RAVENS
## The pair in the sky now: start time, height, and which way they fly (1 east).
var _ravens := {}


func _ready() -> void:
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cloud: Array in CLOUDS:
		_shapes.append(_cloud_shape(cloud[2], int(cloud[0] * 7.0) + 3))


func _process(delta: float) -> void:
	_time += delta
	if _ravens.is_empty() and _time >= _next_ravens:
		var east := randf() < 0.5
		_ravens = {"start": _time, "y": randf_range(26.0, 70.0), "dir": 1.0 if east else -1.0}
	elif not _ravens.is_empty() and _time - _ravens.start > (SCREEN.x + 80.0) / RAVEN_SPEED:
		_ravens = {}
		_next_ravens = _time + RAVEN_GAP
	queue_redraw()


## True while ravens are crossing (tests and screenshots look for them).
func ravens_flying() -> bool:
	return not _ravens.is_empty()


## Sends a pair across now.
func send_ravens(y := 40.0, east := true) -> void:
	_ravens = {"start": _time, "y": y, "dir": 1.0 if east else -1.0}


## A puffy cloud [param width] pixels wide: a flat base under three or four
## round tops, as spans of whole pixels per row.
static func _cloud_shape(width: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bumps: Array[Vector3] = [] # x, y of the centre, radius
	var count := 3 + width / 16
	for i in count:
		var x := (i + 0.5) * width / float(count) + rng.randf_range(-2.0, 2.0)
		var r := rng.randf_range(0.18, 0.3) * width
		if i == count / 2:
			r *= 1.3
		bumps.append(Vector3(x, 0.0, r))
	var height := 0
	for b in bumps:
		height = maxi(height, int(ceil(b.z)))
	var rows: Array = []
	for y in range(-height, 3):
		var lo := 1e9
		var hi := -1e9
		for b in bumps:
			var dy := float(y) + 0.5
			if dy >= 0.0:
				dy = 0.0 # the flat base under every bump
			var half := b.z * b.z - dy * dy
			if half <= 0.0:
				continue
			var w := sqrt(half)
			lo = minf(lo, b.x - w)
			hi = maxf(hi, b.x + w)
		if hi > lo:
			rows.append([y, roundi(lo), roundi(hi) - roundi(lo)])
	return rows


func _draw() -> void:
	for i in CLOUDS.size():
		var cloud: Array = CLOUDS[i]
		var span: float = SCREEN.x + cloud[2] + 20.0
		var x := roundf(fposmod(cloud[0] + _time * cloud[3], span) - cloud[2] - 10.0)
		var y: float = cloud[1]
		var rows: Array = _shapes[i]
		for row: Array in rows:
			# the bottom two rows are shaded, like the painted clouds
			var shade: Color = CLOUD_SHADE if row[0] >= 1 else CLOUD_LIGHT
			draw_rect(Rect2(x + row[1], y + row[0], row[2], 1), shade)
	if not _ravens.is_empty():
		var t: float = _time - _ravens.start
		var dir: float = _ravens.dir
		var lead_x := -40.0 + t * RAVEN_SPEED if dir > 0.0 else SCREEN.x + 40.0 - t * RAVEN_SPEED
		for bird in 2:
			var bx := lead_x - dir * bird * 14.0
			var by: float = _ravens.y + bird * 6.0 + sin(t * 0.9 + bird) * 3.0
			# a few wingbeats every three seconds, then a long glide
			var beat := fmod(t + bird * 0.4, 3.0)
			var frame := 0
			if beat < 1.0:
				frame = 1 + int(beat * 8.0) % 2
			_draw_raven(Vector2(roundf(bx), roundf(by)), frame)


func _draw_raven(at: Vector2, frame: int) -> void:
	var rows: Array = RAVEN_FRAMES[frame]
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			if line[x] == "#":
				draw_rect(Rect2(at + Vector2(x - 5, y - 2), Vector2.ONE), RAVEN)
