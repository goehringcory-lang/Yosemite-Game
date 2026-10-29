extends Node
## The player's chuckahs (acorn granaries). Acorns stored here never spoil,
## so a good fall harvest feeds a whole year of climbing.
##
## The chuckah objects in the world are just doors into this store.

signal changed

## Acorns one chuckah holds.
const CAPACITY_PER_CHUCKAH := 60
const ACORN := "black_oak_acorn"

var chuckahs_built := 0
var acorns := 0

var capacity: int:
	get:
		return chuckahs_built * CAPACITY_PER_CHUCKAH


func _ready() -> void:
	add_to_group("persist")


func start_new_game() -> void:
	chuckahs_built = 0
	acorns = 0
	changed.emit()


func build_chuckah() -> void:
	chuckahs_built += 1
	changed.emit()


## Moves as many carried acorns as will fit into storage. Returns how many.
func deposit_all() -> int:
	var amount := mini(Inventory.count(ACORN), capacity - acorns)
	if amount <= 0:
		return 0
	Inventory.remove(ACORN, amount)
	acorns += amount
	changed.emit()
	return amount


## Takes up to [param amount] acorns out of storage. Returns how many.
func withdraw(amount: int) -> int:
	amount = mini(amount, acorns)
	if amount <= 0:
		return 0
	acorns -= amount
	Inventory.add(ACORN, amount)
	changed.emit()
	return amount


func save_data() -> Dictionary:
	return {"chuckahs_built": chuckahs_built, "acorns": acorns}


func load_data(data: Dictionary) -> void:
	chuckahs_built = int(data.get("chuckahs_built", 0))
	acorns = int(data.get("acorns", 0))
	changed.emit()
