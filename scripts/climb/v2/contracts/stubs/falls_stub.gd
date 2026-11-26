class_name FallsStub
extends FallSystem
## Stand-in falls and partner until thread 7's land (and kept for tests):
## you only fall when pumped out (or when you let go); pieces under 0.3
## quality pop, two at most; story routes never hit the ground. The partner
## cleans and grades each piece at the belay. Supplies "fall" and "belay".

const POP_BELOW := 0.3
const MAX_POPS := 2


func id() -> StringName:
	return &"falls"


func risk(move: V2Move) -> void:
	move.risk = 1.0 if session.sys.effort.pumped_out() and not move.has_tag("rest") else 0.0


func resolve(fall: V2Fall) -> V2Fall:
	var caught := ""
	for piece_id in fall.chain:
		var p := session.piece(piece_id)
		if p == null:
			continue
		if p.quality < POP_BELOW and fall.popped.size() < MAX_POPS:
			p.popped = true
			fall.popped.append(piece_id)
			continue
		caught = piece_id
		p.loaded += 1
		break
	fall.caught_by = caught
	fall.drop_m = session.sys.rope.drop_to(fall.from_pos, caught)
	var low := fall.from_pos.y - fall.drop_m
	var floor_y := session.wall.start.y + 0.6
	if low < floor_y:
		if session.mods.story:
			low = floor_y
		else:
			fall.lands_on = &"ground"
	fall.settle_pos = Vector2(fall.from_pos.x, low + 0.3)
	fall.cost = session.sys.effort.price_action(&"fall", {"drop_m": fall.drop_m})
	fall.partner_line = "Got you!" if caught != "" else "Caught you off the belay!"
	return fall


func clean_pitch() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids := session.pieces.keys()
	ids.sort()
	for piece_id: String in ids:
		var p: V2Piece = session.pieces[piece_id]
		var grade := "bomber" if p.quality >= 0.8 else ("walked a bit" if p.quality >= 0.5 else "that one was a prayer")
		# A piece that popped slid down the rope: it comes back too.
		session.rack.give_back(p.gear_id)
		if p.popped:
			grade = "it popped"
		session.bus.send(&"piece_cleaned", [piece_id, grade])
		out.append({"piece_id": piece_id, "gear_id": p.gear_id, "grade": grade, "line": "Your %s: %s." % [p.gear_id, grade]})
	return out


func phases() -> Dictionary:
	return {&"fall": FallPhase.new(), &"belay": BelayPhase.new()}


## The fall phase: the fall plays (events), then commit gets back on.
class FallPhase extends ClimbPhase:
	var fall: V2Fall

	func enter(p_director: ClimbDirector, args := {}) -> void:
		director = p_director
		name = &"fall"
		fall = args.get("fall")
		var bus := director.session.bus
		bus.send(&"fall_started", [fall])
		for piece_id in fall.popped:
			bus.send(&"piece_popped", [piece_id])
		bus.send(&"fall_caught", [fall])
		if fall.partner_line != "":
			bus.send(&"partner_said", [fall.partner_line])

	func handle(verb: StringName, pressed: bool) -> bool:
		if pressed and verb == &"commit":
			director.go(&"climb")
			return true
		return false

	func hint() -> String:
		return "Space to get back on the rock"


## The belay: the partner follows and cleans; commit starts the next pitch.
class BelayPhase extends ClimbPhase:
	var report: Array[Dictionary] = []

	func enter(p_director: ClimbDirector, _args := {}) -> void:
		director = p_director
		name = &"belay"
		director.rest(&"belay")
		report = director.session.sys.falls.clean_pitch()
		for r in report:
			director.session.bus.send(&"partner_said", [r.line])

	func handle(verb: StringName, pressed: bool) -> bool:
		if pressed and verb == &"commit":
			director.next_pitch()
			return true
		return false

	func hint() -> String:
		return "At the belay. E eats, Space climbs on"
