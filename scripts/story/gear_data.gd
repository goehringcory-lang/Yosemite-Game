class_name GearData
extends Resource
## One piece of climbing gear. Gear comes from quest rewards and trades, and
## climbing routes list the gear they need (see RouteData).

@export var id: String
@export var display_name: String
@export_multiline var description: String
## Painted icon used in the journal. Files live in res://assets/sprites/gear/.
@export var icon: Texture2D
## Rough progression tier (0-4), used to sort the gear list.
@export var tier := 0
## What it's worth in a trade, in food energy (the unit every price uses):
## a climber buying it from you pays a share of this (GearSale), and the
## trade values the economy reads (TradeValues.gear_value) start here.
@export var trade_value := 0
## Lent or given as a keepsake (Ansel's camera): nobody will buy it off you.
@export var keepsake := false
## What sort of gear it is, for the gear tent's groups and the climbing
## screen: "cam", "nut", "rope", "draw", "wall", "ice", "body" (harness,
## shoes, chalk, belay device), "camp" or "other". A route needing an id that
## is its own kind ("cam", "rope") takes any gear of that kind.
@export var kind := "other"
## A label for the size, like "#0.75" or "70 m"; empty if it has none.
@export var size := ""
## The crack widths it protects, on the Camalot scale the climbing screen
## shares (0 #0.3, 1 #0.4, 2 #0.5, 3 #0.75, 4 #1, 5 #2, 6 #3, 7 #4): a cam
## fits one width, a nut a range. -1 for gear that isn't protection.
@export var width_min := -1
@export var width_max := -1
## The sling's color (a cam's Black Diamond color), for racks and icons.
@export var color := Color(0.6, 0.6, 0.6)
## A stand-in that never sits on your rack: "cam" means "any cam", and
## Gear.add("cam") hands out the next size (CamSizes).
@export var generic := false
