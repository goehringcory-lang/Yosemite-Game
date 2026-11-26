class_name VistaView
extends BinocularView
## Taking in the view from a vista (Vistas, VistaSpot): the whole panorama,
## painted by the binocular viewers' skyline painters (BinocularView,
## ClimbLandscape) for the hour and the weather, opening like an iris across
## the full screen and sweeping slowly from one end to the other. As each
## landmark passes the middle it's named: its tag inks in with a chime, and
## the plaque below says a line about it. The vista's own line sits at the
## top. When the sweep is done you can look about with the stick, and
## Interact finishes; Interact during the sweep skips to the end (naming the
## lot).
##
##   var view := VistaView.new()
##   view.setup_vista(Vistas.get_vista("tunnel_view"))
##   add_child(view)
##   await view.swept       # the sweep is done (or was skipped)
##   view.point_at("half_dome")  # the peak-finder's arrow
##   view.close()
##   await view.finished

signal swept

## Seconds for the sweep across the whole panorama (a little less for a
## narrow one).
const SWEEP := 9.0
## How near the middle (UI px) a landmark comes to be named on the sweep.
const NAME_REACH := 18.0
const LENS_FULL := 340.0
const BAND := Color(0.08, 0.06, 0.05, 0.7)

var vista: Dictionary = {}
## True once the sweep is done.
var done_sweeping := false
## Hold the view open for the peak-finder (Interact won't close it).
var holding := false

var _sweep := 0.0
var _sweep_time := SWEEP
var _from_x := 0.0
var _to_x := 0.0
var _pointing := -1


## The vista to show (an entry of Vistas.all()).
func setup_vista(entry: Dictionary) -> void:
	vista = entry
	var key := str(entry.get("view", ""))
	if entry.has("panorama"):
		spec = (entry.panorama as Dictionary).duplicate(true)
		view_id = "vista:" + str(entry.id)
	else:
		spec = (BinocularView.VIEWS.get(key, BinocularView.VIEWS.glacier_point) as Dictionary).duplicate(true)
		view_id = key
	if not spec.has("elevation"):
		spec["elevation"] = ""
	# what the plaque says while nothing's passing the middle
	spec["hint"] = "The view sweeps across what you can see from here, and names each landmark as it passes."
	_start_bearing = float(spec.get("from", 0.0))


func _ready() -> void:
	super._ready()
	layer = 26
	# one wide lens: the whole screen, opening from the middle
	_mat.set_shader_parameter("left_center", CENTER)
	_mat.set_shader_parameter("right_center", CENTER)
	_mat.set_shader_parameter("radius", LENS_FULL)
	var half := CENTER.x / zoom
	_from_x = half
	_to_x = maxf(float(_width) - half, half)
	pan_x = _from_x
	tilt = 0.12
	_sweep_time = clampf(SWEEP * (_to_x - _from_x) / 900.0, 4.0, SWEEP)


## Anywhere on screen counts as "in the lens" here.
func in_lens(p: Vector2, margin := 0.0) -> bool:
	return Rect2(Vector2.ZERO, SCREEN).grow(-margin).has_point(p)


func _steer(delta: float) -> void:
	if not done_sweeping:
		_sweep += delta
		var t := clampf(_sweep / _sweep_time, 0.0, 1.0)
		var eased := t * t * (3.0 - 2.0 * t)
		pan_x = lerpf(_from_x, _to_x, eased)
		_vel = Vector2((_to_x - _from_x) / _sweep_time, 0.0)
		if t >= 1.0:
			_finish_sweep()
		return
	if _pointing >= 0:
		# the arrow's target, eased into the middle
		pan_x = lerpf(pan_x, _anchors[_pointing].x, clampf(delta * 3.0, 0.0, 1.0))
		_vel = Vector2.ZERO
		return
	super._steer(delta)


## While sweeping, name each landmark as it passes the middle.
func _update_focus(delta: float) -> void:
	if done_sweeping:
		super._update_focus(delta)
		return
	var best := -1
	var best_d := NAME_REACH
	for i in _targets.size():
		var s := anchor_on_screen(i)
		var d := absf(s.x - CENTER.x)
		if d < best_d and is_visible_target(i, 2.0):
			best_d = d
			best = i
	if best >= 0 and best != focus:
		focus = best
		_plaque_in = 0.0
		if not is_spotted(best):
			spot(best)
		else:
			Sound.play("ui_move", -10.0, 0.02)


func _finish_sweep() -> void:
	if done_sweeping:
		return
	done_sweeping = true
	for i in _targets.size():
		Park.spotted_peaks[_targets[i].id] = true
	swept.emit()


func close() -> void:
	super.close()
	# (closed before the sweep got going: whoever waits on it goes on)
	if not done_sweeping:
		done_sweeping = true
		swept.emit()


## Swings to the panorama target [param target_id] and hangs an arrow over
## it (the peak-finder). "" takes the arrow away.
func point_at(target_id: String) -> void:
	_pointing = -1
	for i in _targets.size():
		if _targets[i].id == target_id:
			_pointing = i
	if _pointing >= 0:
		focus = -1


## The panorama target the arrow is on, or -1.
func pointing() -> int:
	return _pointing


func _input(event: InputEvent) -> void:
	if _closing:
		return
	if holding:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if not done_sweeping and _ready_to_draw:
			_finish_sweep()
		close()
	elif MenuInput.confirm(event) or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		get_viewport().set_input_as_handled()
		if not _ready_to_draw:
			return
		if not done_sweeping:
			_finish_sweep()
			pan_x = _to_x
		else:
			close()


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
	# the vista's name and line at the top
	c.draw_rect(Rect2(0, 0, SCREEN.x, 38), BAND)
	_center_text(c, font, str(vista.get("title", spec.title)).to_upper(), Vector2(240, 12), 10, GOLD)
	var line := str(vista.get("line", ""))
	var lw := 440.0
	var a := clampf(_sweep / 1.5, 0.0, 1.0) if not done_sweeping else 1.0
	c.draw_multiline_string(font, Vector2(20, 23), line, HORIZONTAL_ALIGNMENT_CENTER, lw, 8, 2, Color(PAPER, 0.9 * a))
	_draw_pins(c, font)
	if _pointing >= 0:
		_draw_arrow(c)
	# the plaque, on a band of its own over the view
	c.draw_rect(Rect2(0, PLAQUE_Y - 2, SCREEN.x, SCREEN.y - PLAQUE_Y + 2), BAND)
	if _pointing < 0:
		_draw_plaque(c, font)
	var hint := ""
	if _pointing >= 0:
		hint = ""
	elif done_sweeping:
		hint = "Look about, or %s to go on" % _button_name()
	elif _sweep > 1.0:
		hint = "%s: skip" % _button_name()
	if hint != "":
		var w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_label(c, font, hint, Vector2(SCREEN.x - w - 8, SCREEN.y - 5), 8, Color(PAPER, 0.6))


## The peak-finder's arrow, bobbing over the landmark it asks about.
func _draw_arrow(c: CanvasItem) -> void:
	var s := anchor_on_screen(_pointing).round()
	var bob := roundf(sin(_time * 4.0) * 2.0)
	var tip := s + Vector2(0, -8 + bob)
	for row in 6:
		c.draw_rect(Rect2(tip.x - row, tip.y - row - 1, row * 2 + 1, 1), Color(GOLD, 0.95))
	c.draw_rect(Rect2(tip.x - 1, tip.y - 14, 3, 8), Color(GOLD, 0.95))
	c.draw_rect(Rect2(tip.x - 7, tip.y - 7, 15, 1), Color(INK, 0.4))


func _button_name() -> String:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("interact_button"):
		return str(hud.interact_button())
	return "E"
