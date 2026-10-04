class_name ShopData
extends Resource
## What one vendor trades and what they say. Lives in res://data/shops/.

@export var keeper := "Trader"
@export_multiline var greeting := ""
## Said when none of the offers are available yet.
@export_multiline var nothing_yet := "Nothing for you today."
@export var offers: Array[ShopOffer] = []
