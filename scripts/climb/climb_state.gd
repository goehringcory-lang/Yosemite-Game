class_name ClimbState
extends RefCounted
## The rules of the climbing minigame, with no drawing or input, so tests can
## play a climb directly.
##
## A pitch is a grid of holds [member COLUMNS] wide. Row 0 is the belay ledge
## at the bottom, and the last row is the ledge at the top. Each move goes up
## one row: straight up, up-left, or up-right, onto a hold. Moves cost stamina.
## Some holds are cracks, where you can place a cam. On bolted pitches there
## are bolts beside the line instead, and old pitons on some cam routes, and
## you clip each with a quickdraw. If stamina runs out you fall to your last
## piece (or the belay). A short fall only costs time; a long one ends the
## climb, and you lower off safely.
##
## The kit helps too: climbing shoes make every move a little cheaper, a chalk
## bag lets you chalk up once a pitch for a couple of easier moves, a belay
## device makes your partner's catches soft and the belay restful, aiders let
## you pull through a hard move on a wall, ascenders let you jug fixed ropes,
## and on snow an ice axe stops a slide.
##
## Each pitch comes from ClimbProfiles: its style (slab, crack, chimney, roof,
## dike, knobs, snow, ice), where its crux points and rests and fixed pieces
## are. A crux asks for a short skill check when the screen sets [member
## interactive]; otherwise (tests, bots) it resolves as an average move. Miss
## the check and you're pumped: you eat something from the pack before you can
## try the move again, and with nothing to eat you come off. Harder pitches
## have more crux points and a faster meter.
##
## Holds have a grip: a jug, an edge or a crimp. Crimps (and cruxes) pump your
## forearms, and every couple of points of [member pump] adds to what each
## move costs and narrows the crux meter. A jug lets your arms recover a
## little, shaking out on one (or reaching a stance) recovers a lot, and
## placing gear is cheap from a jug and strenuous from a crimp. So the line
## matters: string the crimps together and you'll be paying double by the
## crux; break them up with jugs and place your gear from good holds.

enum Status { CLIMBING, TOPPED_OUT, RETREATED }

const COLUMNS := 5
const MAX_STAMINA := 100
## Stamina regained resting at each belay ledge.
const BELAY_REST := 10
## ...and a belay device makes the hanging belay much more restful.
const DEVICE_REST := 6
## Stamina you have back after hanging on the rope following a fall.
const AFTER_FALL_STAMINA := 30
## ...or after a soft catch from a belay device.
const DEVICE_CATCH := 10
## Falling from this many moves above your protection (or more) ends the climb.
const DANGEROUS_RUNOUT := 4
## After this many falls on one pitch, your arms are done and you lower off.
const MAX_FALLS_PER_PITCH := 3
## A night on the wall needs a meal worth at least this much energy.
const BIVY_MEAL_ENERGY := 30
## Stamina a night in a portaledge gives (a ledge gives a full night too).
const COLD_NIGHT_STAMINA := 70
## A night on the wall ends at 6:30 the next morning, whenever it began.
const WAKE_MINUTES := 6 * 60 + 30
## In-game minutes each action takes.
const MINUTES_PER_MOVE := 6
const MINUTES_PER_CAM := 2
const MINUTES_PER_FALL := 20
const MINUTES_TO_EAT := 5
const MINUTES_PER_CLIP := 2
const MINUTES_TO_CHALK := 2
const MINUTES_PER_AID := 12
const MINUTES_PER_JUG := 8
const MINUTES_PER_HAUL := 10
## On bolted routes: the first bolt is this many moves up, then one every
## BOLT_SPACING moves below the top ledge.
const BOLT_FIRST := 2
const BOLT_SPACING := 2
## Climbing shoes take this much off every move.
const SHOE_BONUS := 1
## Chalking up takes this much off each of the next CHALK_MOVES moves.
const CHALK_BONUS := 3
const CHALK_MOVES := 2
## A good stance (a rest hold) gives this much stamina back.
const REST_STANCE := 6
## Pump: what moving onto each grip does to your forearms (see [member pump]).
const PUMP_MAX := 6
const PUMP_JUG := -1
const PUMP_EDGE := 1
const PUMP_CRIMP := 3
## Pitches this grade or under are gentle on the arms (see [method pump_change]).
const EASY_GRADE := 2
## A crux hold pumps you this much on top of its grip.
const PUMP_CRUX := 1
## The screen warns you when pump reaches this.
const PUMP_WARN := 3
## Every this many points of pump add 1 to each move.
const PUMP_PER_COST := 1
## Each point of pump takes this much off the crux meter's green.
const PUMP_WINDOW := 0.02
## Shaking out on a jug or a stance takes this much pump off, once a hold.
const SHAKE_PUMP := 5
const MINUTES_TO_SHAKE := 3
## Stamina it takes to place a cam or clip a draw, by the hold you're on.
const PROTECT_COST := {"jug": 1, "edge": 2, "crimp": 5}
## How often each grip comes up, by pitch style: [jug, edge] (the rest are
## crimps). The guaranteed line is drawn from the same mix.
const GRIPS := {
	"slab": [0.15, 0.5],
	"crack": [0.25, 0.45],
	"flake": [0.3, 0.45],
	"chimney": [0.3, 0.55],
	"roof": [0.15, 0.4],
	"knobs": [0.45, 0.35],
	"dike": [0.25, 0.45],
}
## Each step up the grades adds this much to what a hold costs.
const COST_PER_GRADE := 1.0
## A crux point that isn't the pitch's named crux adds this much to its holds.
const CRUX_POINT_COST := 2
## Missing a crux costs this much stamina, plus PUMP_PER_GRADE a grade.
const PUMP_BASE := 3
const PUMP_PER_GRADE := 2
## The crux meter's marker crosses the bar this many times a second, plus a
## little for the pitch's grade and for the hardest grade on the route.
const CRUX_SPEED := 0.85
const CRUX_SPEED_PER_GRADE := 0.12
const CRUX_SPEED_PER_ROUTE_GRADE := 0.06
## ...but never so fast that it crosses the green in less than this.
const CRUX_MIN_GREEN_SECONDS := 0.1
## Each miss on a crux makes the next try a little easier: a wider green and
## a slower marker, up to CRUX_MERCY_TRIES misses.
const CRUX_MERCY_WINDOW := 0.03
const CRUX_MERCY_SLOWDOWN := 0.9
const CRUX_MERCY_TRIES := 4
## Seconds for a rhythm or a mash crux on the easiest pitch, less a grade.
const CRUX_RHYTHM_SECONDS := 5.6
const CRUX_MASH_SECONDS := 4.6
const CRUX_SECONDS_PER_GRADE := 0.2
## Aiding a hard move, and jugging a fixed rope, cost this much stamina.
const AID_STAMINA := 3
const JUG_STAMINA := 3
## Climbing a chimney: alternate sides, or lose the rhythm.
const CHIMNEY_BONUS := 1
const CHIMNEY_PENALTY := 2
## Weather and snow: wet rock and slush make every move cost more.
const STORM_PENALTY := 1
const STORM_HOUR := 14.5
const SLUSH_HOUR := 12.0
## The route card tells you to start high-country routes before this hour.
const ALPINE_START_BEFORE := 10
## For the route card's late-start warning: extra minutes a pitch takes beyond
## its moves (the belay, a clip or two, and a fall now and then), and more
## for each grade (shaking out, and the falls a hard pitch brings).
const ESTIMATE_PER_PITCH := 20
const ESTIMATE_PER_GRADE := 6
## A Keen meal (see Cooking) widens the crux meter's green this much.
const KEEN_WINDOW := 0.06
## Boulder problems: tries in a session before your fingertips are done.
const BOULDER_TRIES := 5
## Each fall onto the pad leaves you this much short of full stamina for the
## next try, and more for one off the top moves (a high, hard landing).
const BOULDER_FATIGUE := 8
const BOULDER_HIGH_FALL := 6
## Minutes on the pad between tries: brush the holds, chalk, breathe.
const MINUTES_BETWEEN_TRIES := 6

var route: RouteData
var status := Status.CLIMBING
var pitch := 0
var row := 0
var col := COLUMNS / 2
var stamina := MAX_STAMINA
## How pumped your forearms are, 0 to [constant PUMP_MAX]. Cleared at a belay,
## a stance and after a fall; shaking out on a jug takes most of it off.
var pump := 0
var cams_per_pitch := 0
var cams_left := 0
var quickdraws_per_pitch := 0
var quickdraws_left := 0
## Row of the highest piece placed this pitch (the belay ledge counts as row 0).
var protection_row := 0
## Cells with a placed cam this pitch, for drawing.
var placed_cams: Array[Vector2i] = []
## Bolts clipped this pitch (their cells).
var clipped_bolts: Array[Vector2i] = []
## Every piece the rope runs through this pitch, lowest first:
## {"cell": Vector2i, "kind": "cam" or "draw", "hw": "cam", "bolt" or "pin"}.
var protection: Array[Dictionary] = []
## Row -> column of the bolt (or old piton) on that row.
var bolts: Dictionary = {}
## Row -> "bolt" or "pin", for the fixed pieces in [member bolts].
var bolt_kinds: Dictionary = {}
## What meals cooked in the pot are doing for you: effect ("steady", "keen",
## "warming", "nimble") -> moves left. See Cooking.EFFECTS.
var boosts: Dictionary = {}
var has_shoes := false
var has_chalk := false
var has_device := false
var has_aiders := false
var has_ascenders := false
var has_haul_bag := false
var has_portaledge := false
var has_axe := false
var has_crampons := false
## Moves left that get the chalk bonus.
var chalk_moves := 0
var chalked_this_pitch := false
var falls := 0
var falls_this_pitch := 0
var nights_spent := 0
var minutes := 0
## Hard moves pulled through on aiders, and fixed-rope moves jugged.
var aid_moves := 0
var jug_moves := 0
## Crux moves done well, and missed.
var perfect_cruxes := 0
var slipped_cruxes := 0
## What just happened, for the UI.
var message := ""
## Row -> {column -> hold} for the current pitch. A hold has "cost" and
## "crack", and sometimes "crux", "rest", "fixed", "hard", "dike", "kind".
var holds: Dictionary = {}
## The current pitch's spec (see ClimbProfiles).
var spec: Dictionary = {}
## The screen sets this to get a skill check at the crux; without it a crux
## resolves as an average move.
var interactive := false
## A crux waiting on the player: {"kind", "name", "window", "row", "cell",
## "index", "count", "tries", "pumped"}. "pumped" is set after a miss, until
## you eat.
var pending: Dictionary = {}
## The in-game hour the climb started, for weather and snow.
var start_minutes := 8 * 60
## Things that happened since the screen last looked: {"type": String, ...}.
var events: Array[Dictionary] = []
var top_row := 8
var last_dx := 0

var _rng := RandomNumberGenerator.new()
var _rested_rows := {}
var _shaken_rows := {}
## 1 once [method route_has_fixed_pieces] has found some, 0 if none, -1 unasked.
var _has_fixed := -1


## [param seed] makes the wall the same every time (tests use this).
## [param kit] is the rest of the player's gear (gear id -> count, like
## Gear.owned): quickdraws, climbing shoes, and a chalk bag, and the big-wall
## and glacier gear.
func _init(p_route: RouteData, cams: int, seed := -1, kit := {}) -> void:
	route = p_route
	cams_per_pitch = 99 if route.top_rope else (0 if route.boulder else cams)
	quickdraws_per_pitch = 99 if route.top_rope else (0 if route.boulder else int(kit.get("quickdraw", 0)))
	has_shoes = int(kit.get("climbing_shoes", 0)) > 0
	has_chalk = int(kit.get("chalk_bag", 0)) > 0
	has_device = int(kit.get("belay_device", 0)) > 0
	has_aiders = int(kit.get("aiders", 0)) > 0
	has_ascenders = int(kit.get("ascenders", 0)) > 0
	has_haul_bag = int(kit.get("haul_bag", 0)) > 0
	has_portaledge = int(kit.get("portaledge", 0)) > 0
	has_axe = int(kit.get("ice_axe", 0)) > 0
	has_crampons = int(kit.get("crampons", 0)) > 0
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	_start_pitch()


func runout() -> int:
	return row - protection_row


func hold_at(r: int, c: int) -> Dictionary:
	return holds.get(r, {}).get(c, {})


func is_at_belay() -> bool:
	return row == 0


## Bolted pitch: bolts sit on the line.
func is_bolted() -> bool:
	return spec.get("bolts", "") == "line"


## Any pitch with fixed pieces to clip (bolts or old pitons).
func has_fixed_pieces() -> bool:
	return not bolts.is_empty()


func style() -> String:
	return spec.get("style", "crack")


func is_snow() -> bool:
	return style() == "snow" or style() == "ice"


## When storms build, as the route card says it: "2:30 PM".
static func storm_time_text() -> String:
	var h := int(STORM_HOUR)
	var m := roundi((STORM_HOUR - h) * 60.0)
	var clock := "%d" % (h % 12 if h % 12 != 0 else 12)
	if m > 0:
		clock += ":%02d" % m
	return "%s %s" % [clock, "AM" if h < 12 else "PM"]


## The in-game hour right now.
func hour() -> float:
	return fposmod((start_minutes + minutes) / 60.0, 24.0)


## True when it's raining on the high country, or the snow has gone slushy.
func is_stormy() -> bool:
	var weather: String = ClimbProfiles.get_profile(route.id).get("weather", "valley")
	return weather == "alpine" and hour() >= STORM_HOUR and hour() < 20.0


func pitch_name() -> String:
	return spec.get("name", "Pitch %d" % (pitch + 1))


## The pitch's named crux (0 if it has none). See [method crux_rows].
func crux_row() -> int:
	return int(spec.get("crux", 0))


## Every row of this pitch with a crux point, lowest first.
func crux_rows() -> Array:
	return spec.get("cruxes", [])


## True after missing a crux: you have to eat before you can try it again.
func is_pumped() -> bool:
	return pending.get("pumped", false)


## What moving onto the hold at ([param r], [param c]) costs right now, after
## climbing shoes, chalk, chimney rhythm and the weather. Ledges are free;
## other holds cost at least 1.
func move_cost(r: int, c: int) -> int:
	var hold := hold_at(r, c)
	if hold.is_empty():
		return 0
	var cost := int(hold.cost)
	if cost <= 0:
		return 0
	if has_shoes and not is_snow():
		cost -= SHOE_BONUS
	if chalk_moves > 0 and not is_snow():
		cost -= CHALK_BONUS
	if style() == "chimney":
		var dx := c - col
		if dx != 0 and dx == -last_dx:
			cost -= CHIMNEY_BONUS
		elif dx == last_dx and dx != 0:
			cost += CHIMNEY_PENALTY
	var warm := boosts.has("warming")
	if is_stormy() and not warm:
		cost += STORM_PENALTY
	cost += pump_cost()
	# Slush and storms don't stack: a storm already makes the snow wet.
	if is_snow() and not is_stormy() and hour() >= SLUSH_HOUR and hour() < 20.0 and not warm:
		cost += 1
	if boosts.has("nimble"):
		cost -= 1
	if style() == "slab":
		cost -= int(Perks.bonus("slackliners_feet"))
	return maxi(cost, 1)


## What pump adds to every move right now.
func pump_cost() -> int:
	return pump / PUMP_PER_COST


## The grip of the hold at ([param r], [param c]): "jug", "edge", "crimp",
## or "step" (snow, and the ledges).
func grip_at(r: int, c: int) -> String:
	return hold_at(r, c).get("grip", "step")


## The grip you're hanging on now.
func grip() -> String:
	return grip_at(row, col)


## What moving onto [param hold] does to your pump. Edges on an easy pitch
## (grade 2 or under) don't pump you.
func pump_change(hold: Dictionary) -> int:
	var change := 0
	match hold.get("grip", "step"):
		"jug":
			change = PUMP_JUG
		"edge":
			change = PUMP_EDGE if int(spec.get("diff", 2)) > EASY_GRADE else 0
		"crimp":
			change = PUMP_CRIMP
	if hold.get("crux", false):
		change += PUMP_CRUX
	if boosts.has("steady") and change > 0:
		change -= 1
	return change


## Stamina it takes to place a piece from where you hang.
func protect_cost() -> int:
	if hold_at(row, col).get("rest", false):
		return 1
	return int(PROTECT_COST.get(grip(), 2))


## True on a jug or a stance you haven't shaken out on yet, with pump to lose.
func can_shake() -> bool:
	if status != Status.CLIMBING or not pending.is_empty() or is_at_belay() or pump <= 0:
		return false
	var hold := hold_at(row, col)
	return (hold.get("grip", "") == "jug" or hold.get("rest", false)) and not _shaken_rows.has(row)


## Hangs off a straight arm and shakes the other one out: most of the pump
## goes, once a hold.
func shake_out() -> bool:
	if not can_shake():
		if status != Status.CLIMBING or not pending.is_empty():
			return false
		if pump <= 0:
			message = "Your arms feel fine."
		elif _shaken_rows.has(row):
			message = "You've shaken out here already. Move on before it saps you."
		else:
			message = "You can't let go here. Shake out on a jug."
		return false
	_shaken_rows[row] = true
	var before := pump
	pump = maxi(pump - SHAKE_PUMP, 0)
	minutes += MINUTES_TO_SHAKE
	message = "You shake out on the jug. The pump drains away (%d to %d)." % [before, pump]
	events.append({"type": "shake"})
	return true


## Fixed pieces per pitch: how many quickdraws it takes to clip them all.
func bolts_per_pitch() -> int:
	return bolts.size()


## Moves up one row. [param dx] is -1 (up-left), 0 (straight up), or 1 (up-right).
func move(dx: int) -> bool:
	if status != Status.CLIMBING or not pending.is_empty():
		return false
	var target := hold_at(row + 1, col + dx)
	if target.is_empty():
		message = "No hold there."
		return false
	var cost := move_cost(row + 1, col + dx)
	_step(dx, cost, MINUTES_PER_MOVE - int(Perks.bonus("light_rack")))
	return true


## Moves up with the aiders: hard holds on a wall pitch only. Costs a cam
## (placed at the new hold), a little stamina, and a lot of time.
func can_aid(dx: int) -> bool:
	if status != Status.CLIMBING or not pending.is_empty() or not has_aiders or route.top_rope:
		return false
	var target := hold_at(row + 1, col + dx)
	return not target.is_empty() and spec.get("hard_aid", false) and (target.get("hard", false) or target.get("crux", false)) \
		and cams_left > 0 and row + 1 < top_row


func aid_step(dx: int) -> bool:
	if not can_aid(dx):
		message = "Aiders work on the hard moves of a wall, with a cam to stand on." if has_aiders else "You need aiders for that."
		return false
	cams_left -= 1
	# The cam goes in at the new hold, so it catches you if the move fails.
	var cell := Vector2i(col + dx, row + 1)
	protection_row = row + 1
	placed_cams.append(cell)
	protection.append({"cell": cell, "kind": "cam", "hw": "cam", "aid": true})
	_step(dx, AID_STAMINA, MINUTES_PER_AID, true)
	pump = maxi(pump - 1, 0)
	aid_moves += 1
	if status == Status.CLIMBING:
		message = "You place a cam and stand in your aiders. Pulled through (+1 aid move)."
	events.append({"type": "aid"})
	return true


## Jugs up a fixed rope with the ascenders: safe, steady, and slow.
func can_jug(dx: int) -> bool:
	if status != Status.CLIMBING or not pending.is_empty() or not has_ascenders:
		return false
	var target := hold_at(row + 1, col + dx)
	return not target.is_empty() and target.get("fixed", false)


func jug(dx: int) -> bool:
	if not can_jug(dx):
		message = "There's no fixed rope there to jug." if has_ascenders else "You need ascenders to jug a fixed rope."
		return false
	# You can't fall off a fixed rope, so jugging never takes the last stamina.
	_step(dx, maxi(mini(JUG_STAMINA, stamina - 1), 0), MINUTES_PER_JUG, true)
	pump = maxi(pump - 1, 0)
	jug_moves += 1
	events.append({"type": "jug"})
	return true


## A move's worth of every meal's effect wears off.
func _wear_off_boosts() -> void:
	for effect: String in boosts.keys():
		boosts[effect] = int(boosts[effect]) - 1
		if boosts[effect] <= 0:
			boosts.erase(effect)


## Starts the effect of meal [param item_id], if it has one, and returns a
## line about it for the message ("" if none). A Hearty meal fills you up.
func _take_effect(item_id: String) -> String:
	if not Cooking.is_meal(item_id):
		return ""
	var meal: Dictionary = Cooking.meal_effect(item_id)
	if meal.effect == "":
		return ""
	if meal.effect == "hearty":
		stamina = MAX_STAMINA
		pump = 0
		return "Hearty: you're full of energy."
	boosts[meal.effect] = maxi(int(boosts.get(meal.effect, 0)), int(meal.moves))
	return "%s for %d moves." % [Cooking.EFFECTS[meal.effect].name, boosts[meal.effect]]


## Shared by moves, aid steps and jugs.
func _step(dx: int, cost: int, mins: int, safe := false) -> void:
	var hold := hold_at(row + 1, col + dx)
	row += 1
	col += dx
	last_dx = dx
	stamina -= cost
	minutes += mins
	chalk_moves = maxi(chalk_moves - 1, 0)
	var pump_before := pump
	if not safe:
		pump = clampi(pump + pump_change(hold), 0, PUMP_MAX)
	_wear_off_boosts()
	message = ""
	if pump >= PUMP_WARN and pump_before < PUMP_WARN:
		message = "Your forearms are pumping (+%d a move). Shake out on a jug." % pump_cost()
		events.append({"type": "pumped"})
	if hold.get("rest", false) and row < top_row and not _rested_rows.has(row):
		_rested_rows[row] = true
		stamina = mini(stamina + REST_STANCE, MAX_STAMINA)
		pump = 0
		message = "A good stance. You shake out (+%d)." % REST_STANCE
		events.append({"type": "rest"})
	if hold.get("crux", false) and row < top_row and not safe:
		var crux := ClimbProfiles.crux_at(spec, row)
		pending = {
			"kind": crux.kind,
			"name": crux.name,
			"row": row,
			"cell": Vector2i(col, row),
			"index": crux_rows().find(row) + 1,
			"count": crux_rows().size(),
			"tries": 0,
			"pumped": false,
			"narrow": -float(crux.get("narrow", 0.0)),
			"need": int(crux.get("need", 0)),
		}
		pending["window"] = crux_window()
		if not interactive:
			resolve_crux("good")
		return
	_settle()


## After a move: fall, finish the pitch, or carry on.
func _settle() -> void:
	if stamina <= 0:
		_fall()
	elif row == top_row:
		_finish_pitch()


## How wide the green zone of the crux meter is, 0..1 of the bar. The
## better your kit and your hands, the more forgiving the move, and every
## miss on a crux widens it a little for the next try. Pumped forearms
## narrow it.
func crux_window() -> float:
	var window := 0.30 - 0.025 * int(spec.get("diff", 2))
	if has_shoes:
		window += 0.05
	if chalk_moves > 0:
		window += 0.07
	if route.top_rope:
		window += 0.12
	window += Perks.bonus("steady_breath")
	if boosts.has("keen"):
		window += KEEN_WINDOW
	window += CRUX_MERCY_WINDOW * _crux_mercy()
	window -= PUMP_WINDOW * pump
	window += float(pending.get("narrow", 0.0))
	return clampf(window, 0.1, 0.5)


## How fast the crux meter's marker moves, in bar lengths a second: faster on
## a harder pitch and on a harder route, slower after a miss, and never too
## fast to catch the green.
func crux_speed() -> float:
	var speed := CRUX_SPEED + CRUX_SPEED_PER_GRADE * int(spec.get("diff", 2)) \
		+ CRUX_SPEED_PER_ROUTE_GRADE * int(route.pitches.max())
	speed *= pow(CRUX_MERCY_SLOWDOWN, _crux_mercy())
	return minf(speed, crux_window() / CRUX_MIN_GREEN_SECONDS)


## Seconds a "rhythm" or "mash" crux gives you: less on a harder pitch, more
## after a miss.
func crux_seconds(kind: String) -> float:
	var seconds := CRUX_RHYTHM_SECONDS if kind == "rhythm" else CRUX_MASH_SECONDS
	seconds -= CRUX_SECONDS_PER_GRADE * int(spec.get("diff", 2))
	if kind == "rhythm" and has_shoes:
		seconds += 2.0
	return seconds + 0.5 * _crux_mercy()


func _crux_mercy() -> int:
	return mini(int(pending.get("tries", 0)), CRUX_MERCY_TRIES)


## Finishes a try at a crux with "perfect", "good" or "slip". A slip (missing
## the green) leaves you pumped on the move: eat, then try again. With nothing
## to eat, or nothing left in your arms, you come off.
func resolve_crux(result: String) -> void:
	if pending.is_empty() or is_pumped():
		return
	var name: String = pending.name
	var diff := int(spec.get("diff", 2))
	events.append({"type": "crux", "result": result, "name": name})
	if result == "slip":
		var cost := PUMP_BASE + PUMP_PER_GRADE * diff
		stamina -= cost
		slipped_cruxes += 1
		if route.boulder:
			# No hanging on to eat a snack: miss the move and you're off.
			pending = {}
			_fall()
			if status == Status.CLIMBING:
				message = "You miss %s and come off. " % name.to_lower() + message
			return
		if stamina > 0 and _has_spare_food():
			pending.tries = int(pending.get("tries", 0)) + 1
			pending.pumped = true
			message = "You miss %s and you're spent (-%d). Eat something, then try again." % [name.to_lower(), cost]
			return
		pending = {}
		if stamina > 0:
			_fall()
			if status == Status.CLIMBING:
				message = "Spent on %s with nothing to eat, you come off. " % name.to_lower() + message
		else:
			_settle()
		return
	pending = {}
	if result == "perfect":
		stamina = mini(stamina + 3 + diff, MAX_STAMINA)
		pump = maxi(pump - 2, 0)
		perfect_cruxes += 1
		message = "Sent! Perfect through %s (+%d)." % [name.to_lower(), 3 + diff]
	else:
		message = "You make %s." % name.to_lower()
	_settle()


func can_place_cam() -> bool:
	return not route.boulder and status == Status.CLIMBING and pending.is_empty() and not route.top_rope and cams_left > 0 \
		and hold_at(row, col).get("crack", false) and protection_row < row


func place_cam() -> bool:
	if not can_place_cam():
		message = "You need a crack to place a cam." if cams_left > 0 else "You're out of cams for this pitch."
		return false
	cams_left -= 1
	protection_row = row
	placed_cams.append(Vector2i(col, row))
	protection.append({"cell": Vector2i(col, row), "kind": "cam", "hw": "cam"})
	_protect_effort()
	minutes += MINUTES_PER_CAM
	message = _protect_message("Cam placed.")
	events.append({"type": "cam"})
	return true


## True if there's a bolt on this row within arm's reach (your column or the
## next one over) that you haven't clipped, and a quickdraw to clip it with.
func can_clip() -> bool:
	return status == Status.CLIMBING and pending.is_empty() and not route.top_rope and quickdraws_left > 0 \
		and bolts.has(row) and absi(int(bolts[row]) - col) <= 1 and protection_row < row


func clip_bolt() -> bool:
	if not can_clip():
		if not bolts.has(row):
			message = "No bolt here. They're every couple of moves: watch for the glint."
		elif absi(int(bolts[row]) - col) > 1:
			message = "The bolt's out of reach. Stay closer to the line."
		elif quickdraws_left <= 0:
			message = "You're out of quickdraws for this pitch."
		else:
			message = "You've already clipped that bolt."
		return false
	var bolt := Vector2i(int(bolts[row]), row)
	var hw: String = bolt_kinds.get(row, "bolt")
	quickdraws_left -= 1
	protection_row = row
	clipped_bolts.append(bolt)
	protection.append({"cell": bolt, "kind": "draw", "hw": hw})
	_protect_effort()
	minutes += MINUTES_PER_CLIP
	message = _protect_message("Clipped the old piton." if hw == "pin" else "Clipped. The rope runs through the quickdraw.")
	events.append({"type": "clip", "hw": hw})
	return true


## Placing a piece: cheap from a jug, strenuous off a crimp. It never takes
## the last of your stamina: you'd rather hang on than finish the placement.
func _protect_effort() -> void:
	var effort := protect_cost()
	stamina = maxi(stamina - effort, 1) if stamina > 0 else stamina
	if grip() == "crimp" and not hold_at(row, col).get("rest", false):
		pump = mini(pump + 1, PUMP_MAX)


func _protect_message(done: String) -> String:
	if grip() == "crimp" and not hold_at(row, col).get("rest", false):
		return done + " Fiddly off a crimp (-%d)." % protect_cost()
	return done


## The protect button: clips a bolt within reach, or places a cam in a crack.
func protect() -> bool:
	if route.boulder:
		message = "No rope on a boulder. The pad and your spotter are your protection."
		return false
	return clip_bolt() if is_bolted() or can_clip() else place_cam()


## True if chalking up would help: on rock, once a pitch, anywhere but a
## ledge. (Chalk does nothing on snow and ice.)
func can_chalk() -> bool:
	return status == Status.CLIMBING and pending.is_empty() and has_chalk and not chalked_this_pitch \
		and (not is_at_belay() or route.boulder) and not is_snow()


## Dips your hands in the chalk bag: the next CHALK_MOVES moves cost less.
## Once a pitch, anywhere but a ledge.
func chalk_up() -> bool:
	if status != Status.CLIMBING or not pending.is_empty():
		return false
	if not has_chalk:
		message = "You don't have a chalk bag."
		return false
	if is_snow():
		message = "Chalk does nothing on snow and ice."
		return false
	if chalked_this_pitch:
		message = "You've already chalked up on this pitch. Save it for the next one."
		return false
	chalked_this_pitch = true
	chalk_moves = CHALK_MOVES
	minutes += MINUTES_TO_CHALK
	message = "You chalk up. Dry hands: the next %d moves are easier." % CHALK_MOVES
	events.append({"type": "chalk"})
	return true


## Food in the pack that is worth a night on the wall ([constant
## BIVY_MEAL_ENERGY] or more), one for each unit.
func meals_in_pack() -> int:
	var meals := 0
	for id in FoodDB.edible_in_inventory():
		if FoodDB.energy(id) >= BIVY_MEAL_ENERGY:
			meals += Inventory.count(id)
	return meals


## True if the pack holds [param recommended_energy] of food and a real meal
## for every night on the wall. The route card turns green on this.
func food_ready(recommended_energy: int) -> bool:
	return FoodDB.carried_energy() >= recommended_energy and meals_in_pack() >= route.nights


## Nights still to spend on the wall.
func nights_remaining() -> int:
	return maxi(route.nights - nights_spent, 0)


## True if [param item_id] is a night's meal the climb still needs.
func is_reserved_meal(item_id: String) -> bool:
	return FoodDB.energy(item_id) >= BIVY_MEAL_ENERGY and meals_in_pack() <= nights_remaining()


## What to eat at a belay: smaller foods first, saving the real meals for the
## nights, then a cooked meal whose effect you don't have going, and whatever
## spoils soonest among them. Empty if the pack has no food. If only reserved
## meals are left, it's one of those (and [method eat] will say to save it).
func next_food() -> String:
	var foods := FoodDB.edible_in_inventory()
	if foods.is_empty():
		return ""
	foods.sort_custom(func(a: String, b: String) -> bool:
		var meal_a := FoodDB.energy(a) >= BIVY_MEAL_ENERGY
		var meal_b := FoodDB.energy(b) >= BIVY_MEAL_ENERGY
		if meal_a != meal_b:
			return meal_b
		var lift_a := _would_boost(a)
		var lift_b := _would_boost(b)
		if lift_a != lift_b:
			return lift_a
		return _freshness(a) < _freshness(b))
	return foods[0]


## True if [param item_id] is a cooked meal whose effect isn't already going.
func _would_boost(item_id: String) -> bool:
	if not Cooking.is_meal(item_id):
		return false
	var effect: String = Cooking.meal_effect(item_id).effect
	return effect != "" and not boosts.has(effect)


## Days left before [param item_id] spoils, with food that never spoils last.
func _freshness(item_id: String) -> int:
	var days := Larder.days_left(item_id)
	return days if days > 0 else 9999


## True at a belay when there's something to eat and room to eat it, without
## touching a night's meal. Pumped on a crux, you eat right where you hang.
func can_eat() -> bool:
	if status != Status.CLIMBING:
		return false
	if is_pumped():
		return _has_spare_food()
	if not pending.is_empty() or not is_at_belay() or stamina >= MAX_STAMINA:
		return false
	return _has_spare_food()


## True if the pack has food that isn't a meal a night on the wall needs.
func _has_spare_food() -> bool:
	var id := next_food()
	return id != "" and not is_reserved_meal(id)


## Eats one of [param item_id] from the Inventory. Only at belay ledges, and
## not at full stamina, or wherever a missed crux has left you pumped. The
## meals the nights on the wall need are kept.
func eat(item_id: String) -> bool:
	var pumped := is_pumped()
	if not is_at_belay() and not pumped:
		message = "You can only eat at a belay ledge."
		return false
	if stamina >= MAX_STAMINA and not pumped:
		message = "You're not hungry."
		return false
	var energy := FoodDB.energy(item_id)
	if energy <= 0 or Inventory.count(item_id) <= 0:
		return false
	energy += int(Perks.bonus("trail_cook"))
	if is_reserved_meal(item_id):
		message = "Save this for the night on the wall."
		return false
	Inventory.remove(item_id)
	stamina = mini(stamina + energy, MAX_STAMINA)
	minutes += MINUTES_TO_EAT
	var item := ItemDB.get_item(item_id)
	message = "Ate %s (+%d)." % [item.display_name if item else item_id, energy]
	var effect := _take_effect(item_id)
	if effect != "":
		message += " " + effect
	if pumped:
		pending.pumped = false
		pending.window = crux_window()
		message += " Shake out and try %s again." % String(pending.name).to_lower()
	events.append({"type": "eat"})
	return true


## Gives up and lowers off (or rappels, with a belay device). Your gear comes
## with you.
func retreat(reason := "") -> void:
	status = Status.RETREATED
	pending = {}
	minutes += 15 + 10 * pitch
	if reason == "" and route.boulder:
		reason = "You pick up the pad and call it a session."
	if reason == "":
		reason = "You rappel down and head back." if has_device and pitch > 0 else "You lower off and head back down."
	message = reason
	events.append({"type": "retreat"})


## How the climb went: "Onsight" (no falls, no aid), "Hard-won" (falls but
## free), or "Aided" (pulled on gear).
func style_rating() -> String:
	if route.boulder:
		return "Flash" if falls == 0 else "Sent on try %d" % (falls + 1)
	if aid_moves > 0:
		return "Aided"
	if falls == 0:
		return "Onsight"
	return "Hard-won"


## True if the whole route went without pulling on gear.
func is_free() -> bool:
	return aid_moves == 0


func _fall() -> void:
	if route.boulder:
		_fall_on_pad()
		return
	falls += 1
	falls_this_pitch += 1
	minutes += MINUTES_PER_FALL
	pump = 0
	events.append({"type": "fall"})
	if falls_this_pitch >= MAX_FALLS_PER_PITCH:
		retreat("That's %d falls on this pitch. Your arms are done, so you lower off and head down." % falls_this_pitch)
		return
	var catch_stamina := AFTER_FALL_STAMINA + (DEVICE_CATCH if has_device else 0)
	if route.top_rope:
		stamina = catch_stamina
		message = "You slip, and the rope catches you right away. Rest, then keep going."
		return
	if is_snow():
		# You slide, then dig in your ice axe and stop.
		var slide := 2 if style() == "snow" else 3
		row = maxi(row - slide, 0)
		col = COLUMNS / 2 if row == 0 else _nearest_hold_column(row, col)
		stamina = catch_stamina
		chalk_moves = 0
		message = "You slide, then self-arrest with your ice axe. Catch your breath." if has_axe else "You slide a long way before you stop."
		return
	var distance := runout()
	if distance >= DANGEROUS_RUNOUT:
		retreat("You fell %d moves past your last protection. Shaken, you lower off and walk back down." % (distance * 2))
		return
	# A leader falls twice as far as they were above their protection.
	row = maxi(protection_row - distance, 0)
	# Back on the ledge you're lowered to the belay; otherwise you grab the nearest hold.
	col = COLUMNS / 2 if row == 0 else _nearest_hold_column(row, col)
	stamina = catch_stamina
	chalk_moves = 0
	var catcher := "belay"
	if protection_row > 0 and not protection.is_empty():
		var last: Dictionary = protection.back()
		catcher = "quickdraw" if last.kind == "draw" else "cam"
	message = "You fall, and your %s catches you. Shake it out and try again." % catcher


## Tries left on a boulder problem, counting the one you're on.
func tries_left() -> int:
	return maxi(BOULDER_TRIES - falls, 0)


## Off a boulder problem: you land on the pad, your spotter steadies you, and
## the next try starts from the ground with a little less in your arms. Run out
## of tries and the session is over.
func _fall_on_pad() -> void:
	var high := row >= top_row - 2
	falls += 1
	falls_this_pitch += 1
	minutes += MINUTES_BETWEEN_TRIES
	events.append({"type": "fall", "pad": true, "high": high})
	if falls >= BOULDER_TRIES:
		retreat("That's %d tries. Your fingertips are raw and your arms are done. Come back another day." % falls)
		return
	var fresh := MAX_STAMINA - BOULDER_FATIGUE * falls - (BOULDER_HIGH_FALL if high else 0)
	row = 0
	col = COLUMNS / 2
	last_dx = 0
	pump = 0
	chalk_moves = 0
	chalked_this_pitch = false
	pending = {}
	_rested_rows = {}
	_shaken_rows = {}
	stamina = fresh
	var left := tries_left()
	if high:
		message = "You come off the top and land hard on the pad. The spotter keeps you off the rocks. %d %s left." % [left, "try" if left == 1 else "tries"]
	else:
		message = "You drop onto the pad. Brush the holds, chalk up, go again. %d %s left." % [left, "try" if left == 1 else "tries"]


func _finish_pitch() -> void:
	pitch += 1
	events.append({"type": "pitch_done", "pitch": pitch})
	if pitch >= route.pitches.size():
		status = Status.TOPPED_OUT
		message = "You top out!"
		events.append({"type": "topout"})
		return
	var finished_spec := spec
	var haul_note := ""
	if route.nights > 0 and has_haul_bag:
		minutes += MINUTES_PER_HAUL
		haul_note = " You haul the bag (+%d min)." % MINUTES_PER_HAUL
	if _night_after(finished_spec):
		if not _bivy(finished_spec.get("bivy", "ledge")):
			return
	stamina = mini(stamina + BELAY_REST + (DEVICE_REST if has_device else 0) + int(Perks.bonus("leonards_belay")), MAX_STAMINA)
	_start_pitch()
	message = ("Belay ledge. Pitch %d of %d." % [pitch + 1, route.pitches.size()] + haul_note) if message == "" else message + haul_note


func _night_after(finished_spec: Dictionary) -> bool:
	if route.nights <= 0 or nights_spent >= route.nights:
		return false
	# Routes mark where the nights fall ("bivy" in the profile); otherwise an
	# equal share of pitches.
	var marked := false
	for i in route.pitches.size():
		if ClimbProfiles.pitch_spec(route, i).has("bivy"):
			marked = true
	if marked:
		return finished_spec.has("bivy")
	var pitches_per_day := ceili(route.pitches.size() / float(route.nights + 1))
	return pitch % pitches_per_day == 0


## Spends a night on the wall, eating the smallest real meal in the pack, and
## wakes at [constant WAKE_MINUTES] the next morning. Returns false if there's
## no real meal to eat.
func _bivy(place: String) -> bool:
	var cold := not has_portaledge and place != "ledge"
	var meal_id := ""
	for id in FoodDB.edible_in_inventory():
		var energy := FoodDB.energy(id)
		if energy < BIVY_MEAL_ENERGY:
			continue
		# On a cold night, a Warming meal beats a smaller one.
		var warm := cold and _warms(id)
		var best_warm := cold and meal_id != "" and _warms(meal_id)
		if meal_id == "" or (warm and not best_warm) or (warm == best_warm and energy < FoodDB.energy(meal_id)):
			meal_id = id
	if meal_id == "":
		retreat("Night is falling and you have no real meal for the wall. You rappel down hungry.")
		return false
	var warmed := _warms(meal_id) or boosts.has("warming")
	Inventory.remove(meal_id)
	nights_spent += 1
	stamina = MAX_STAMINA if (not cold or warmed) else COLD_NIGHT_STAMINA
	_take_effect(meal_id)
	minutes += minutes_until_morning()
	var item := ItemDB.get_item(meal_id)
	var meal := item.display_name if item else meal_id
	message = "You spend the night on the wall and eat %s. You wake up rested." % meal
	events.append({"type": "bivy", "night": nights_spent, "place": place, "meal": meal})
	return true


## True if [param item_id] is a meal that keeps you warm (see Cooking).
func _warms(item_id: String) -> bool:
	return Cooking.is_meal(item_id) and Cooking.meal_effect(item_id).effect == "warming"


## Game minutes from now until 6:30 the next morning (or this morning, if it's
## still the small hours).
func minutes_until_morning() -> int:
	var now := posmod(start_minutes + minutes, 24 * 60)
	return WAKE_MINUTES - now if now < WAKE_MINUTES else 24 * 60 + WAKE_MINUTES - now


## About how long a route takes in game minutes, without any nights on the
## wall: every move, plus the belay, the shake-outs and the odd fall on each
## pitch.
static func estimate_minutes(r: RouteData) -> int:
	var total := 0
	for i in r.pitches.size():
		var pitch_spec := ClimbProfiles.pitch_spec(r, i)
		total += int(pitch_spec.rows) * MINUTES_PER_MOVE + ESTIMATE_PER_PITCH + ESTIMATE_PER_GRADE * int(pitch_spec.diff)
	return total


## True if a one-day route started at [param clock_minutes] (GameClock.minutes)
## would still be going at the 2 AM curfew.
static func starts_too_late(r: RouteData, clock_minutes: int) -> bool:
	return r.nights == 0 and clock_minutes + estimate_minutes(r) > GameClock.PASS_OUT_HOUR * 60


## True if the route has bolts or old pitons to clip on some pitch.
func route_has_fixed_pieces() -> bool:
	if _has_fixed < 0:
		_has_fixed = 1 if route.protection == "bolts" else 0
		for i in route.pitches.size():
			var pitch_spec := ClimbProfiles.pitch_spec(route, i)
			if pitch_spec.get("bolts", "") == "line" or not pitch_spec.get("pins", []).is_empty():
				_has_fixed = 1
	return _has_fixed == 1


func _start_pitch() -> void:
	row = 0
	col = COLUMNS / 2
	last_dx = 0
	cams_left = cams_per_pitch
	quickdraws_left = quickdraws_per_pitch
	protection_row = 0
	falls_this_pitch = 0
	placed_cams.clear()
	clipped_bolts.clear()
	protection.clear()
	chalk_moves = 0
	chalked_this_pitch = false
	pending = {}
	_rested_rows = {}
	_shaken_rows = {}
	pump = 0
	spec = ClimbProfiles.pitch_spec(route, pitch)
	top_row = int(spec.rows)
	_generate_holds()
	events.append({"type": "pitch_start", "pitch": pitch, "name": spec.name})


## Columns that have holds on this pitch.
func allowed_cols() -> Array:
	var cols: Array = spec.get("cols", [])
	if cols.is_empty():
		cols = range(COLUMNS)
	return cols


func _crack_chance() -> float:
	if spec.has("cracks"):
		return float(spec.cracks)
	return 0.0 if is_bolted() else 0.3


func _generate_holds() -> void:
	holds = {}
	bolts = {}
	bolt_kinds = {}
	var difficulty := int(spec.diff)
	var cols := allowed_cols()
	var path := {}
	var ledge := {}
	for c in COLUMNS:
		ledge[c] = {"cost": 0, "crack": false}
	holds[0] = ledge
	holds[top_row] = ledge.duplicate(true)
	if spec.has("problem"):
		_authored_holds(difficulty)
		return
	var path_col := clampi(COLUMNS / 2, cols.min(), cols.max())
	var st := style()
	for r in range(1, top_row):
		var rowd := {}
		if st == "dike":
			# The dike snakes across the face; the line follows it.
			var sign := -1.0 if pitch % 2 == 1 else 1.0
			var target := 2.0 + sign * 1.7 * sin(r * 0.55) * minf(r / 2.0, 1.0)
			# ...one column at a time, so it stays within reach.
			path_col = clampi(clampi(roundi(target), path_col - 1, path_col + 1), cols.min(), cols.max())
		else:
			# A guaranteed line: each row has a hold within reach of the one below.
			path_col = clampi(path_col + _rng.randi_range(-1, 1), cols.min(), cols.max())
		path[r] = path_col
		rowd[path_col] = _make_hold(difficulty, true)
		if st == "chimney":
			# Both walls close in: every column has something to push on.
			for c: int in cols:
				if not rowd.has(c):
					rowd[c] = _make_hold(difficulty, false)
		elif st == "ice" and r % 3 == 0:
			pass # a crevasse bridge: only the line crosses
		else:
			for i in _rng.randi_range(1, 2):
				var c: int = cols[_rng.randi_range(0, cols.size() - 1)]
				if not rowd.has(c):
					rowd[c] = _make_hold(difficulty, false)
		holds[r] = rowd
	_remove_dead_ends(difficulty, cols)
	_apply_features(path, difficulty)
	if is_bolted():
		# Bolts sit on the line, so the easy way up passes every one of them.
		var gap := int(spec.get("bolt_gap", BOLT_SPACING))
		for r in range(BOLT_FIRST if gap == BOLT_SPACING else gap, top_row, gap):
			bolts[r] = path[r]
			bolt_kinds[r] = "bolt"
	for r: int in spec.get("pins", []):
		if r > 0 and r < top_row and path.has(r):
			bolts[r] = path[r]
			bolt_kinds[r] = spec.get("pin_kind", "pin")
	# Bolts and pitons were placed where you can let go and clip: the hold
	# beside each one is never a crimp.
	for r: int in bolts:
		var hold: Dictionary = holds[r][path[r]]
		if hold.get("grip", "step") == "crimp" and not hold.get("crux", false):
			hold.grip = "edge"
			hold.cost = _grip_cost(difficulty, "edge")
			hold.erase("hard")
	if _crack_chance() > 0.0 and not is_snow():
		_ensure_cracks(path)


## A boulder problem's holds are the real ones, the same every time: the
## spec's "problem" lists each row's holds, lowest first, as column ->
## {"grip", "cost", and maybe "name"}. Crux points and stances are marked on
## top as usual.
func _authored_holds(difficulty: int) -> void:
	var rows: Array = spec.problem
	for i in rows.size():
		var rowd := {}
		for c: int in rows[i]:
			var h: Dictionary = rows[i][c]
			var hold := {"cost": int(h.cost), "crack": false, "grip": h.get("grip", "edge")}
			if h.has("name"):
				hold["name"] = h.name
			if hold.grip == "crimp":
				hold["hard"] = true
			rowd[c] = hold
		holds[i + 1] = rowd
	_apply_features({}, difficulty)


## Gives every hold at least one hold within reach above it, so the player
## can never climb into a dead end.
func _remove_dead_ends(difficulty: int, cols: Array) -> void:
	for r in range(1, top_row - 1):
		for c: int in holds[r].keys():
			var reachable := false
			for dx in [-1, 0, 1]:
				reachable = reachable or holds[r + 1].has(c + dx)
			if not reachable:
				var nc := clampi(c + _rng.randi_range(-1, 1), cols.min(), cols.max())
				holds[r + 1][nc] = _make_hold(difficulty, false)


## A grip for a new hold on this pitch's style (see [constant GRIPS]).
func _roll_grip(on_line: bool) -> String:
	if style() == "dike" and not on_line:
		return "crimp"
	var mix: Array = GRIPS.get(style(), GRIPS.crack)
	var roll := _rng.randf()
	if roll < float(mix[0]):
		return "jug"
	return "edge" if roll < float(mix[0]) + float(mix[1]) else "crimp"


## What a hold of [param grip] costs on a pitch of [param difficulty].
func _grip_cost(difficulty: int, grip_name: String) -> int:
	var base := 2 + roundi(difficulty * COST_PER_GRADE)
	match grip_name:
		"jug":
			return maxi(base - 2, 2) + _rng.randi_range(0, 1)
		"crimp":
			return base + 1 + _rng.randi_range(0, 1)
	return base - 1 + _rng.randi_range(0, 1)


func _make_hold(difficulty: int, on_line: bool) -> Dictionary:
	var grip_name := _roll_grip(on_line)
	var cost := _grip_cost(difficulty, grip_name)
	var crack := _rng.randf() < _crack_chance()
	var hold := {"cost": cost, "crack": crack, "grip": grip_name}
	match style():
		"knobs":
			hold.cost = maxi(cost - 1, 2)
		"snow":
			hold.cost = 1 + difficulty + _rng.randi_range(0, 2)
			hold.crack = false
			hold["kind"] = "snow"
			hold.grip = "step"
		"ice":
			# Swinging tools is hard on the arms: every hold is an edge.
			hold.cost = 2 + difficulty + _rng.randi_range(0, 3)
			hold.crack = false
			hold["kind"] = "ice"
			hold.grip = "edge"
		"chimney":
			hold.cost = maxi(cost - 1, 3)
		"dike":
			# On the dike it's easy; off it, it's blank slab.
			hold.cost = maxi(cost - 2, 2) if on_line else cost + 2
			hold["dike"] = on_line
			hold.crack = hold.crack and not on_line
		"roof":
			hold.cost = cost
	if hold.grip == "crimp":
		hold["hard"] = true
	return hold


## Marks the crux, stances and fixed ropes the pitch's spec asks for.
func _apply_features(path: Dictionary, difficulty: int) -> void:
	# The pitch's named crux is its hardest move; the other crux points test
	# your timing more than your arms.
	for crux: int in crux_rows():
		var extra := 3 + difficulty if crux == crux_row() else CRUX_POINT_COST
		extra = int(ClimbProfiles.crux_at(spec, crux).get("extra", extra))
		for c: int in holds[crux]:
			var hold: Dictionary = holds[crux][c]
			hold.cost = int(hold.cost) + extra
			hold["crux"] = true
			hold["hard"] = true
			if hold.get("grip", "step") == "jug":
				hold.grip = "edge"
	for r: int in spec.get("rest", []):
		if r > 0 and r < top_row:
			for c: int in holds[r]:
				holds[r][c].cost = 2
				holds[r][c]["rest"] = true
				holds[r][c].erase("hard")
				if holds[r][c].get("grip", "step") != "step":
					holds[r][c].grip = "jug"
	for r: int in spec.get("fixed", []):
		if r > 0 and r < top_row and path.has(r):
			holds[r][path[r]]["fixed"] = true


## Makes sure a careful climber can protect every stretch of DANGEROUS_RUNOUT
## moves, so no pitch is impossible to climb safely: the guaranteed line has a
## crack (or a fixed piece) at least every DANGEROUS_RUNOUT - 1 moves.
func _ensure_cracks(path: Dictionary) -> void:
	var since := 0
	for r in range(1, top_row):
		since += 1
		var c: int = path[r]
		var protectable: bool = holds[r][c].crack or (bolts.has(r) and absi(int(bolts[r]) - c) <= 1)
		if not protectable and since >= DANGEROUS_RUNOUT - 1:
			holds[r][c].crack = true
			protectable = true
		if protectable:
			since = 0


func _nearest_hold_column(r: int, from_col: int) -> int:
	var best := from_col
	var best_distance := COLUMNS + 1
	for c: int in holds.get(r, {}):
		if absi(c - from_col) < best_distance:
			best = c
			best_distance = absi(c - from_col)
	return best


## Takes the events the screen hasn't seen yet.
func take_events() -> Array[Dictionary]:
	var out := events.duplicate()
	events.clear()
	return out
