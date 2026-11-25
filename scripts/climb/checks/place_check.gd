class_name PlaceCheck
extends ClimbCheck
## Placing a cam or a nut in a crack, with one hand while the other hangs on.
##
## First pick the piece: your rack runs along the panel, smallest first, and
## the cursor starts on the best fit you have. Left and Right pick another.
## A piece two or more sizes off the crack won't go in, so it's greyed out;
## one size off goes in badly at best. A slung horn is always there at the
## end of the rack, for when nothing fits.
##
## Then seat it: hold Space (or E) to pull the trigger and the lobes draw in;
## let go and they open against the rock. Let go in the green and the cam
## sits mid-range, solid. Short of the green it's tipped out (it may rip in a
## fall); past it, it's over-cammed (it holds, but your second will fight to
## clean it). A nut has no trigger: hold to slot it, let go to seat it with a
## tug, and it never over-cams.
##
## The time is your grip: long on a jug, short on a crimp, shorter pumped.
## Run out while seating and you leave the piece however it is; run out
## while still picking, or press Esc, and you put nothing in ("cancel").

## The green for the right size, and for one size off (and where it sits).
const FIT_WINDOW := 0.34
const NUT_WINDOW := 0.26
const OFF_WINDOW := 0.16
const FIT_CENTER := 0.5
## One size too small (tips out) sits low on the bar; too big sits high.
const SMALL_CENTER := 0.3
const BIG_CENTER := 0.72
## The trigger comes in this many bar lengths a second.
const PULL_SPEED := 0.9
## The green never gets wider than this.
const MAX_WINDOW := 0.5

## The pieces you can choose from: rack entries with "left" (how many are
## still on your harness), plus ClimbRack.SLING at the end.
var pieces: Array[Dictionary] = []
## The crack's width (ClimbRack.WIDTHS).
var width := 4
## Which piece the cursor is on, and the one you seated ("" until then).
var cursor := 0
var chosen: Dictionary = {}
## "pick" until you start pulling, "seat" while you pull, "" when done.
var phase := "pick"
## How far the trigger is pulled in, 0 to 1.
var pull := 0.0
var pull_speed := PULL_SPEED
## Assist: Settings.room() widens the green.
var room := 1.0
## The key that opened the check may still be down: pulling starts only once
## it has been let go (or with a fresh press).
var _armed := false


## [param rack] is ClimbState's pieces with what's left of each this pitch;
## [param p_width] the crack; [param grip_seconds] the time your grip gives.
func _init(rack: Array, p_width: int, grip_seconds: float, pace := 1.0, p_room := 1.0) -> void:
	width = p_width
	time_total = grip_seconds
	time_left = grip_seconds
	pull_speed = PULL_SPEED * pace
	room = p_room
	for piece: Dictionary in rack:
		if int(piece.get("left", 0)) > 0:
			pieces.append(piece)
	pieces.append(ClimbRack.SLING.duplicate())
	cursor = best_index()


## The piece the cursor starts on: the best fit you carry, and of two the
## one you have more of (save the last of a size for higher up).
func best_index() -> int:
	var best := pieces.size() - 1
	var best_off := 99
	var best_left := -1
	for i in pieces.size() - 1:
		var off := ClimbRack.misfit(pieces[i], width)
		var left := int(pieces[i].get("left", 0))
		if off > 1:
			continue
		if off < best_off or (off == best_off and left > best_left):
			best = i
			best_off = off
			best_left = left
	return best


## True if [param i] would go in this crack (it's at most one size off).
func can_use(i: int) -> bool:
	return i >= 0 and i < pieces.size() and ClimbRack.misfit(pieces[i], width) <= 1


func selected() -> Dictionary:
	return pieces[cursor]


func is_sling() -> bool:
	return selected().get("kind", "") == "sling"


func is_nut() -> bool:
	return selected().get("kind", "") == "nut"


## The green for the selected piece: [center, width]. A sling has none.
func green() -> Vector2:
	var piece := selected()
	var off := ClimbRack.misfit(piece, width)
	if off == 0:
		return Vector2(FIT_CENTER, minf((NUT_WINDOW if is_nut() else FIT_WINDOW) * room, MAX_WINDOW))
	var side := ClimbRack.misfit_side(piece, width)
	return Vector2(BIG_CENTER if side > 0 else SMALL_CENTER, minf(OFF_WINDOW * room, MAX_WINDOW))


func step(delta: float, held: Dictionary) -> void:
	if is_done():
		return
	elapsed += delta
	time_left -= delta
	var pulling: bool = held.get("pull", false)
	if phase == "pick":
		if not pulling:
			_armed = true
		elif _armed:
			_start_pull()
	if phase == "seat":
		if pulling:
			pull = minf(pull + pull_speed * delta, 1.0)
		else:
			seat()
			return
	if time_left <= 0.0:
		# Your grip's gone: the piece stays however it is.
		if phase == "seat":
			seat()
		else:
			_finish("cancel", "grip")


func press(action: String) -> void:
	if is_done() or phase != "pick":
		return
	match action:
		"left":
			_move_cursor(-1)
		"right":
			_move_cursor(1)
		"tool", "interact":
			_start_pull()
		"cancel":
			_finish("cancel", "cancel")


func _move_cursor(dir: int) -> void:
	var i := cursor
	for n in pieces.size():
		i = posmod(i + dir, pieces.size())
		if can_use(i):
			cursor = i
			events.append({"type": "pick", "index": i})
			return


func _start_pull() -> void:
	if not can_use(cursor):
		cursor = best_index()
	chosen = selected()
	if is_sling():
		# Nothing to seat: loop the sling round and clip it.
		events.append({"type": "seated", "result": "slip"})
		_finish("slip", "sling")
		return
	phase = "seat"
	events.append({"type": "pull"})


## Lets go of the trigger: the lobes open where they are.
func seat() -> void:
	if is_done():
		return
	chosen = selected()
	var g := green()
	var how := judge(pull, g.x, g.y)
	var why := "seated"
	if how == "slip":
		if pull > g.x and not is_nut() and ClimbRack.misfit_side(chosen, width) >= 0:
			how = "over"
			why = "over"
		else:
			why = "tipped"
	elif ClimbRack.misfit(chosen, width) > 0:
		# One size off goes in, but never better than good.
		how = "good"
		why = "off_size"
	phase = ""
	events.append({"type": "seated", "result": how})
	_finish(how, why)
