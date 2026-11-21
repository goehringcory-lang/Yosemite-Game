extends Node
## Supply and demand at the Valley's traders (autoload "Market").
##
## Each buyer has an appetite for each sort of thing (TradeValues.sort_of):
## every unit you trade them adds one to their glut of that sort, and each
## step of glut takes GLUT_STEP off what they'll give for the next one (down
## to APPETITE_FLOOR, a twentieth a unit). Gluts ease by GLUT_RECOVERY
## steps every morning, so
## the same basket of greens is worth full price again in a few days, and
## spreading your trade across the Valley pays better than dumping it all
## on one counter. King Cobra has its own, steeper curve (COBRA_STEP,
## COBRA_RECOVERY): a climber's first can of the day is a treat, the fourth
## is just more beer.
##
## When what you hand over comes to more than the price, the rest goes on
## your tab with that trader (up to TAB_CAP) and pays toward the next trade.

signal changed

const GLUT_STEP := 0.05
const GLUT_RECOVERY := 6.0
const APPETITE_FLOOR := 0.4
const COBRA_STEP := 0.25
const COBRA_RECOVERY := 1.0
## Most a trader keeps on your tab; change beyond it is a tip.
const TAB_CAP := 25
## A glut this deep (appetite at or below 0.6) and the trader says so.
const FULL_UP := 0.6

## Buyer key -> {sort -> glut steps}.
var glut: Dictionary = {}
## Buyer key -> energy units of credit.
var tabs: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	GameClock.day_started.connect(_on_day_started.unbind(3))


func start_new_game() -> void:
	glut = {}
	tabs = {}
	changed.emit()


## The key a buyer's gluts and tab are kept under: the shop file's name
## ("curry_store"), or "anyone" for a trade without a shop.
static func key_of(data: ShopData) -> String:
	if data == null or data.resource_path == "":
		return "anyone"
	return data.resource_path.get_file().get_basename()


## How much of the usual value [param key] gives for one more of
## [param sort], with [param extra] more already in this trade (1.0 = full).
func appetite(key: String, sort: String, extra := 0.0) -> float:
	if sort == "":
		return 1.0
	var steps := float(glut.get(key, {}).get(sort, 0.0)) + extra
	var step := COBRA_STEP if sort == "cobra" else GLUT_STEP
	return maxf(APPETITE_FLOOR, 1.0 - step * steps)


## Notes that [param key] took [param amount] of [param sort].
func took(key: String, sort: String, amount := 1.0) -> void:
	if sort == "":
		return
	var sorts: Dictionary = glut.get(key, {})
	sorts[sort] = float(sorts.get(sort, 0.0)) + amount
	glut[key] = sorts
	changed.emit()


func tab(key: String) -> int:
	return int(tabs.get(key, 0))


func set_tab(key: String, amount: int) -> void:
	amount = clampi(amount, 0, TAB_CAP)
	if amount == 0:
		tabs.erase(key)
	else:
		tabs[key] = amount
	changed.emit()


## The sorts [param key] is full up on (appetite at FULL_UP or less).
func full_up(key: String) -> PackedStringArray:
	var out := PackedStringArray()
	for sort: String in glut.get(key, {}):
		if appetite(key, sort) <= FULL_UP:
			out.append(sort)
	return out


func _on_day_started() -> void:
	for key: String in glut.keys():
		var sorts: Dictionary = glut[key]
		for sort: String in sorts.keys():
			var left := float(sorts[sort]) - (COBRA_RECOVERY if sort == "cobra" else GLUT_RECOVERY)
			if left <= 0.0:
				sorts.erase(sort)
			else:
				sorts[sort] = left
		if sorts.is_empty():
			glut.erase(key)
	changed.emit()


func save_data() -> Dictionary:
	return {"glut": glut, "tabs": tabs}


func load_data(data: Dictionary) -> void:
	glut = {}
	for key in data.get("glut", {}):
		var sorts := {}
		for sort in data.glut[key]:
			sorts[str(sort)] = float(data.glut[key][sort])
		glut[str(key)] = sorts
	tabs = {}
	for key in data.get("tabs", {}):
		tabs[str(key)] = int(data.tabs[key])
	changed.emit()
