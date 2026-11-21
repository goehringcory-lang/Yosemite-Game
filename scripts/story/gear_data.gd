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
