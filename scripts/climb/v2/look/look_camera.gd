class_name LookCamera
extends RefCounted
## The living camera (thread 10): where the view looks, how close, and the
## small kicks a catch or a move gives it, all worked out from the session
## and the bus. Plain maths, no nodes, so tests drive it with fake frames.
##
## Calm by design, since the wall waits for you: one eased target per phase,
## a dead zone so hip shifts don't nudge the frame, a lead toward the aimed
## hold, a pan down the pitch while you read it, a pull back at the top. Only
## a caught fall shakes, and only up and down. [member reduce_motion] drops
## the shake, the lead and the settle and halves the rates.
##
## Units: [member focus] is in wall metres (y up); [member offset] in screen
## pixels; [member zoom] multiplies PX_PER_M.

const T := preload("res://scripts/climb/v2/look/look_tuning.gd")

var focus := Vector2(3, 2)
var zoom := T.ZOOM_CLOSE
## Pixels added after the focus (shake and settle).
var offset := Vector2.ZERO
## Where across the screen the focus sits (0..1), eased between phases.
var frame_x := T.FRAME_X
var reduce_motion := false
var screen_size := Vector2(960, 540)

var _target := Vector2(3, 2)
var _lead := Vector2.ZERO
var _rest := Vector2(3, 2)
var _zoom_target := T.ZOOM_CLOSE
var _shake := 0.0
var _shake_age := 99.0
var _settle_age := 99.0
var _read_age := 0.0
var _phase: StringName = &""
var _time := 0.0


## A new pitch: jump to it (no ease from the last pitch's wall).
func snap_to(wall: V2Wall, hip: Vector2) -> void:
	_rest = hip + Vector2(0, T.CLIMB_LIFT)
	_read_age = 0.0
	_lead = Vector2.ZERO
	if wall:
		focus = read_focus(wall, 0.0)
		zoom = T.ZOOM_WIDE
	else:
		focus = _rest
	_target = focus
	_zoom_target = zoom


func phase_changed(to: StringName) -> void:
	if to == &"read":
		_read_age = 0.0
	_phase = to


## A move went in: the view settles down a touch.
func move_committed() -> void:
	if not reduce_motion:
		_settle_age = 0.0


## The rope caught a fall of [param drop_m] metres.
func fall_caught(drop_m: float) -> void:
	if reduce_motion:
		return
	_shake = minf(T.SHAKE_MAX, T.SHAKE_BASE + T.SHAKE_PER_M * maxf(drop_m, 0.0))
	_shake_age = 0.0


## Where reading the pitch looks at [param age] seconds in: a hold at the
## top anchor, then a pan down to the start at READ_PAN_SPEED.
static func read_focus(wall: V2Wall, age: float) -> Vector2:
	var half_h := 540.0 * 0.5 / (ClimbV2.PX_PER_M * T.ZOOM_WIDE)
	var top := wall.top.y + T.MARGIN_ABOVE - half_h
	var bottom := wall.start.y - T.MARGIN_BELOW + half_h
	top = maxf(top, bottom)
	var y := maxf(bottom, top - maxf(age - T.READ_HOLD, 0.0) * T.READ_PAN_SPEED)
	return Vector2(wall.size.x * 0.5, y)


## One frame. [param aim] is the aimed hold's spot (or null), [param zone]
## the rect a special frames (or an empty Rect2).
func step(delta: float, session: ClimbSession, aim: Variant = null, zone := Rect2()) -> void:
	_time += delta
	var wall := session.wall
	var hip := session.pose.hip
	var rate := T.RATE_CLIMB
	var want_frame := T.FRAME_X
	# The dead zone: the resting point only moves once the hips leave it.
	var d := hip + Vector2(0, T.CLIMB_LIFT) - _rest
	if absf(d.x) > T.DEAD_ZONE.x:
		_rest.x += d.x - signf(d.x) * T.DEAD_ZONE.x
	if absf(d.y) > T.DEAD_ZONE.y:
		_rest.y += d.y - signf(d.y) * T.DEAD_ZONE.y
	var lead := Vector2.ZERO
	if aim is Vector2 and not reduce_motion:
		lead = ((aim as Vector2) - hip) * T.LEAD_SHARE
		lead = lead.limit_length(T.LEAD_MAX)
	_lead = _lead.lerp(lead, _ease(T.RATE_LEAD, delta))
	match _phase:
		&"read":
			_read_age += delta
			_target = read_focus(wall, _read_age) if wall else _rest
			_zoom_target = T.ZOOM_WIDE
			want_frame = 0.5
			rate = Vector2(3.0, 3.0)
		&"clip", &"place":
			_target = _rest + _lead * 0.5
			_zoom_target = T.ZOOM_CLOSE
			rate = T.RATE_WORK
		&"fall":
			_rest = hip + Vector2(0, T.CLIMB_LIFT)
			_target = hip - Vector2(0, T.FALL_BIAS)
			_zoom_target = T.ZOOM_CLOSE
			rate = T.RATE_FALL
		&"belay":
			var anchor := wall.top if wall else hip
			_target = (hip + Vector2(0, T.CLIMB_LIFT)).lerp(anchor, 0.3)
			_zoom_target = T.ZOOM_CLOSE
			rate = T.RATE_BELAY
		&"special":
			_target = zone.get_center() if zone.has_area() else _rest + _lead
			_zoom_target = T.ZOOM_CLOSE
			rate = T.RATE_WORK
		&"result":
			_target = Vector2(wall.size.x * 0.5, wall.top.y - 3.0) if wall else hip
			_zoom_target = T.ZOOM_WIDE
			want_frame = 0.5
			rate = T.RATE_RESULT
		_:
			_target = _rest + _lead
			_zoom_target = T.ZOOM_CLOSE
	if reduce_motion:
		rate *= 0.5
	zoom = lerpf(zoom, _zoom_target, _ease(T.RATE_ZOOM * (0.5 if reduce_motion else 1.0), delta))
	if absf(zoom - _zoom_target) < 0.002:
		zoom = _zoom_target
	frame_x = lerpf(frame_x, want_frame, _ease(T.RATE_ZOOM, delta))
	focus.x = lerpf(focus.x, _target.x, _ease(rate.x, delta))
	focus.y = lerpf(focus.y, _target.y, _ease(rate.y, delta))
	if wall:
		focus = clamp_focus(focus, wall)
	offset = Vector2.ZERO
	_shake_age += delta
	if _shake_age < T.SHAKE_TIME * 3.0:
		var fade := exp(-_shake_age / T.SHAKE_TIME * 2.0)
		offset.y += sin(_shake_age * 55.0) * _shake * fade
	_settle_age += delta
	if _settle_age < T.SETTLE_TIME:
		offset.y += sin(_settle_age / T.SETTLE_TIME * PI) * T.SETTLE_PX


## Keeps the view on painted rock: no sky past the rock on the left, at most
## a slice under the start and over the top, and the valley on the right.
func clamp_focus(f: Vector2, wall: V2Wall) -> Vector2:
	var ppm := ClimbV2.PX_PER_M * zoom
	var left_m := screen_size.x * frame_x / ppm
	var half_h := screen_size.y * 0.5 / ppm
	var lo_x := -T.MARGIN_LEFT + left_m
	f.x = maxf(f.x, lo_x)
	var lo_y := wall.start.y - T.MARGIN_BELOW + half_h
	var hi_y := wall.size.y + T.MARGIN_ABOVE - half_h
	f.y = lo_y if hi_y < lo_y else clampf(f.y, lo_y, hi_y)
	return f


## The world node's transform for this view: scale and position, rounded to
## whole screen pixels so the pixel art doesn't shimmer.
func world_transform() -> Transform2D:
	var at := Vector2(screen_size.x * frame_x, screen_size.y * 0.5)
	var pos := at - ClimberView.px(focus) * zoom + offset
	return Transform2D(0.0, Vector2(zoom, zoom), 0.0, pos.round())


## The wall spot under screen point [param p].
func to_wall(p: Vector2) -> Vector2:
	var t := world_transform()
	var local := t.affine_inverse() * p
	return Vector2(local.x, -local.y) / ClimbV2.PX_PER_M


static func _ease(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)
