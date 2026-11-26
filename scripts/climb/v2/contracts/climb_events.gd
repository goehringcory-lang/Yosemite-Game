class_name ClimbEvents
extends RefCounted
## The v2 event bus: one per climb (not an autoload, so tests stay apart).
## Systems announce what happened here; views, sound, the HUD and counters
## listen. Rules (CONTRACTS.md):
##   - only the owner of a fact emits its event (rope emits clipped, gear
##     emits piece_placed...), through [method send];
##   - listeners never change the session: they draw, play and count;
##   - presentation (camera moves, sounds) is derived from these events by
##     look (thread 10), so there are no camera or sound events.
## Every event is also kept in [member trace] (name + args) for tests.

# --- the climb (director)
signal climb_started(route_id: String)
signal pitch_started(pitch: int)
signal pitch_finished(pitch: int)
signal phase_changed(from: StringName, to: StringName)
signal climb_finished(result: V2Result)
# --- body (thread 3)
signal aim_changed(hold_id: String)
signal move_previewed(move: V2Move)
signal move_committed(move: V2Move)
signal hand_swapped(hand: StringName)
signal hip_changed(hip: Vector2)
# --- effort (thread 4)
signal effort_changed(effort: V2Effort)
signal rested(kind: StringName)
signal food_eaten(food_id: String, gas: float)
# --- rope (thread 5)
signal rope_pulled(arms: int, needed: int)
signal clipped(piece_id: String, back_clipped: bool)
signal unclipped(piece_id: String)
# --- gear (thread 6)
signal piece_offered(item_id: String, reading: Dictionary)
signal piece_placed(piece_id: String)
signal piece_cancelled(item_id: String)
# --- falls and the partner (thread 7)
signal fall_started(fall: V2Fall)
signal piece_popped(piece_id: String)
signal fall_caught(fall: V2Fall)
signal piece_cleaned(piece_id: String, grade: String)
signal partner_said(line: String)
# --- cruxes and big-wall moments (thread 8)
signal crux_entered(zone_id: String)
signal crux_sent(zone_id: String, clean: bool)
signal special_started(kind: StringName)
signal special_finished(kind: StringName, ok: bool)
## One stroke of a special: a hammer tap and its tone, a swing's peak, a haul
## stroke, an inchworm shuffle. Look, sound and art react to these (no bars).
signal special_step(kind: StringName, data: Dictionary)

## Every event sent, in order: [name, args].
var trace: Array = []
## Turn off to stop keeping the trace (long climbs).
var keep_trace := true


## Emits [param event] with [param args] and keeps it in the trace.
func send(event: StringName, args: Array = []) -> void:
	if not has_signal(event):
		push_error("ClimbEvents: no event %s" % event)
		return
	if keep_trace:
		trace.append([event, args])
	callv("emit_signal", [event] + args)


## Just the names in the trace, optionally only those in [param only].
func names(only: Array = []) -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: Array in trace:
		if only.is_empty() or entry[0] in only:
			out.append(entry[0])
	return out


func count(event: StringName) -> int:
	var n := 0
	for entry: Array in trace:
		if entry[0] == event:
			n += 1
	return n
