class_name ShopOffer
extends Resource
## One thing a vendor trades: a piece of gear or an item, paid for in food.
##
## Prices are in food energy, the currency of hungry climbers: the vendor
## takes food from your pack, the soonest to spoil first, until the price
## is covered.

@export_enum("gear", "item") var kind := "gear"
## A GearData id (kind "gear") or ItemData id (kind "item").
@export var id := ""
@export var amount := 1
## Food energy the vendor wants for it.
@export var price := 30
## A straight swap instead: items the vendor wants for it, as item id ->
## count (Greg takes fish for his best flies). When set, [member price] is
## ignored.
@export var trade: Dictionary = {}
## Gear you must already own for this offer to show up, as gear id -> count.
## Trades round out a rack; the piece that opens a new tier comes from quests.
@export var requires: Dictionary = {}
## Largest number you can own through trades (0 = no limit).
@export var max_owned := 0
