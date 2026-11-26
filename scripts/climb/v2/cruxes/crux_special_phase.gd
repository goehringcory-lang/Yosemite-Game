class_name CruxSpecialPhase
extends ClimbPhase
## The "special" phase (thread 8): runs one CruxSpecial (King Swing, nailing,
## chimney, offwidth, hauling). The arrows step through its choices, the
## ghost (overlay) and the hint show what the chosen one would do, commit
## does it. Rest, eat and a double cancel (retreat) work here too. Every
## change goes through the director's intents (spend, rest, eat, hang_at,
## count_aid, go) or the crux system's own notes.

var special: CruxSpecial
var sel := 0
var belay := false
var _retreat_armed := false
var _say := ""


func enter(p_director: ClimbDirector, args := {}) -> void:
	director = p_director
	name = &"special"
	belay = bool(args.get("belay", false))
	_retreat_armed = false
	var sys := _sys()
	var kind: StringName = StringName(str(args.get("kind", "")))
	var n: Dictionary = director.session.notes.get(&"cruxes", {})
	var saved: Dictionary = n.get("special", {})
	var spot: Dictionary
	if not saved.is_empty() and StringName(str(saved.kind)) == kind:
		spot = saved.spot
		special = sys.make_special(kind, spot, saved.state)
		sel = int(saved.get("sel", 0))
		_say = str(saved.get("say", ""))
	else:
		var at: Vector2 = V2Data.vec(n.get("last_hold", V2Data.arr(director.session.pose.hip)))
		spot = sys.special_spot_at(at) if kind != &"haul" else {"id": "haul_%d" % director.session.pitch, "kind": "haul", "name": "Haul the bag", "rect": [0, 0, 0, 0]}
		if spot.is_empty():
			spot = {"id": "special_%s" % kind, "kind": String(kind), "name": String(kind).capitalize(), "rect": V2Data.rect_arr(Rect2(at - Vector2(1, 1), Vector2(2, 3)))}
		special = sys.make_special(kind, spot)
		sel = 0
		_say = ""
	if special == null:
		# Nothing knows this kind: carry on climbing.
		director.go(&"belay" if belay else &"climb")
		return
	if saved.is_empty() or StringName(str(saved.kind)) != kind:
		if kind != &"haul":
			director.session.bus.send(&"crux_entered", [str(spot.id)])
		director.session.bus.send(&"special_started", [kind])
	_save()


func _sys() -> CruxesV2:
	return director.session.sys.cruxes as CruxesV2


func options() -> Array:
	return special.options() if special else []


func chosen() -> Dictionary:
	var opts := options()
	if opts.is_empty():
		return {}
	sel = clampi(sel, 0, opts.size() - 1)
	return opts[sel]


func handle(verb: StringName, pressed: bool) -> bool:
	if special == null or not pressed:
		return false
	if verb != &"cancel":
		_retreat_armed = false
	match verb:
		&"aim_left", &"aim_down":
			_cycle(-1)
			return true
		&"aim_right", &"aim_up":
			_cycle(1)
			return true
		&"commit":
			do_option(chosen())
			return true
		&"rest":
			var kind := &"belay" if belay else (&"hang" if special.kind in [&"swing", &"nail"] else &"stance")
			return director.rest(kind)
		&"eat":
			return director.eat()
		&"cancel":
			if _retreat_armed:
				director.retreat()
			else:
				_retreat_armed = true
			return true
	return false


func _cycle(d: int) -> void:
	var n := options().size()
	if n == 0:
		return
	sel = posmod(sel + d, n)
	_save()


## Does [param option] (one of options()). Tests and bots call this too.
func do_option(option: Dictionary) -> void:
	if option.is_empty() or special == null:
		return
	var s := director.session
	var fx := special.apply(option)
	var c: Array = fx.get("cost", [])
	if not c.is_empty():
		director.spend(_price(c))
	if fx.has("rest"):
		director.rest(fx.rest)
	if fx.has("hang"):
		_hang(fx.hang, fx.get("tags", PackedStringArray()))
	if int(fx.get("aid", 0)) > 0:
		if director.has_method("count_aid"):
			director.call("count_aid", int(fx.aid))
		else:
			s.result.aid_moves += int(fx.aid)
	if s.bus.has_signal("special_step"):
		s.bus.send(&"special_step", [special.kind, fx.get("step", {})])
	_say = str(fx.get("say", ""))
	sel = 0
	if bool(fx.get("done", false)):
		var ok := bool(fx.get("ok", true))
		var kind := special.kind
		_sys().finish_special(special, ok)
		var n := s.note(&"cruxes")
		n["said"] = _say
		special = null
		s.bus.send(&"special_finished", [kind, ok])
		director.go(&"belay" if belay else &"climb")
		return
	_save()


## Prices a special's own cost through effort when a real effort system is
## in (it may weigh pump and gas its own way), else with the modifiers.
func _price(c: Array) -> V2Cost:
	var s := director.session
	var effort := s.sys.effort
	var script := effort.get_script() as Script
	if script and not script.resource_path.contains("/stubs/"):
		var priced := effort.price_action(&"special", {"kind": special.kind, "pump": c[0], "gas": c[1], "minutes": c[2]})
		if priced and (priced.pump != 0.0 or priced.gas != 0.0 or priced.minutes != 0):
			return priced
	return V2Cost.make(float(c[0]) * s.mods.pump_mult, float(c[1]) * s.mods.gas_mult, int(c[2]))


func _hang(pos: Vector2, tags: PackedStringArray) -> void:
	if director.has_method("hang_at"):
		director.call("hang_at", pos, tags)
	else:
		# Before contract v2: the same thing hang_at does.
		director.session.sys.body.settle(pos)
		for t in tags:
			if not director.session.pose.tags.has(t):
				director.session.pose.tags.append(t)


func _save() -> void:
	if special:
		_sys().save_special(special, sel, _say)


func hint() -> String:
	if special == null:
		return ""
	var o := chosen()
	var p := special.preview(o)
	var line := "%s: %s" % [special.title(), str(o.get("label", ""))]
	if str(p.get("say", "")) != "":
		line += " (%s)" % p.say
	var n := options().size()
	return line + ("   Arrows: %d choices. Space: do it. V rests, E eats." % n if n > 1 else "   Space: do it. V rests, E eats.")


## The last thing you felt or heard (for the overlay's caption).
func said() -> String:
	return _say
