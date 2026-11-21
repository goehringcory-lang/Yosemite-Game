class_name ShopData
extends Resource
## What one vendor trades and what they say. Lives in res://data/shops/.

@export var keeper := "Trader"
@export_multiline var greeting := ""
## Said when none of the offers are available yet.
@export_multiline var nothing_yet := "Nothing for you today."
@export var offers: Array[ShopOffer] = []
## A quest "talk" target id for this keeper, so a quest can send the player
## here (the Mountain Shop clerk hands over the guidebook this way).
@export var talk_target := ""
## What they want most and least in trade (TradeValues.TASTES): "climber",
## "store", "outfitter", "angler", or "" for anyone's tastes.
@export var tastes := ""

## Selling gear back (GearSale). Gear ids this keeper will buy off you.
@export var buys_gear: PackedStringArray = []
## Their share of a piece's GearData.trade_value when they buy it.
@export_range(0.0, 1.0) var buy_rate := 0.5
## What they pay you with, as item ids (food that keeps; climbers never
## pay in King Cobra, they drink it).
@export var pays_with: PackedStringArray = ["beef_jerky", "pilot_bread", "dried_apples"]
## Pieces a climber goes after, one at a time, a different one every few
## days; they pay its full value for it (GearSale.wanted).
@export var wants: PackedStringArray = []
## True for the Camp 4 climber you can share a King Cobra with after a new
## route (GearSale.toast).
@export var toasts := false
