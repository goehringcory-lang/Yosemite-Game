class_name GraphicsWatch
extends Node
## Graphics on Auto: watches how smoothly the game runs and, on a computer too
## slow for High, switches to Low (see Settings.low) and says so. It looks at
## once for the plain signs of an old or weak computer (no Vulkan, so the game
## fell back to OpenGL, or no graphics card at all), and otherwise at the
## frame times: if the typical frame takes longer than SLOW_MS for STRIKES
## stretches of WINDOW seconds in a row, it's slow. The choice is saved, so
## the next start begins on Low (with its lighter renderer); picking Auto again
## in Settings looks afresh.
##
## Only in the real game (the World as the running scene, with a window and
## the player's own settings), never in tests or screenshot tools.

## A typical frame slower than this (40 frames a second) counts as slow.
const SLOW_MS := 25.0
## Seconds of play in each look.
const WINDOW := 4.0
## Looks in a row that must be slow.
const STRIKES := 2
## Seconds to wait after the game starts or the player changes area, while
## things load.
const SETTLE := 3.0

var _frames: PackedFloat32Array = []
var _elapsed := 0.0
var _strikes := 0
var _settle := SETTLE
var _last_usec := 0


func _ready() -> void:
	name = "GraphicsWatch"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var world := get_parent()
	if world.has_signal("region_changed"):
		world.region_changed.connect(_on_region_changed.unbind(1))
	_check_device.call_deferred()


## True when Auto is on and the World is the game being played.
func _watching() -> bool:
	return Settings.graphics == Settings.Graphics.AUTO and not Settings.auto_low \
			and Settings.path == Settings.DEFAULT_PATH \
			and DisplayServer.get_name() != "headless" \
			and get_tree().current_scene == get_parent()


## No Vulkan (the game fell back to OpenGL) or drawing on the processor: Low
## from the start.
func _check_device() -> void:
	if not _watching():
		return
	var fell_back := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var on_cpu := RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_CPU
	if fell_back or on_cpu:
		_go_low()


func _on_region_changed() -> void:
	_settle = SETTLE
	_frames.clear()
	_elapsed = 0.0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last_usec) / 1000.0
	_last_usec = now
	# Not watching now (High, Low, or already dropped): start afresh if Auto
	# is picked again.
	if not _watching():
		_frames.clear()
		_elapsed = 0.0
		_strikes = 0
		return
	# only time real play: not paused, not in another window, not loading
	if get_tree().paused or not get_window().has_focus() or ms > 1000.0:
		_frames.clear()
		_elapsed = 0.0
		return
	if _settle > 0.0:
		_settle -= ms / 1000.0
		return
	_frames.append(ms)
	_elapsed += ms / 1000.0
	if _elapsed < WINDOW:
		return
	var typical := median(_frames)
	_frames.clear()
	_elapsed = 0.0
	_strikes = _strikes + 1 if typical > SLOW_MS else 0
	if _strikes >= STRIKES:
		_go_low()


func _go_low() -> void:
	_strikes = 0
	Settings.auto_low = true
	Settings.save()
	Settings.apply_graphics(get_window())
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message("Graphics set to Low to keep the game smooth")


static func median(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]
