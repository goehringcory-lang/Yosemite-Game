extends Node
## Paints the Ahwahnee ground into the generated hub maps.
##   godot --headless --path . res://tools/mapgen/upgrade_hubs.tscn -- [paint|attach] [hub ids]
## Two passes: "paint" writes the pictures to assets/map/ground/. Run
## `godot --headless --path . --import` so Godot imports them, then "attach"
## adds them to the map scenes. Add hub ids to do only those hubs.

const Upgrade = preload("res://tools/mapgen/ground_upgrade.gd")
const HUBS := ["el_portal", "wawona", "tuolumne_meadows", "yosemite_valley"]


func _ready() -> void:
	var hubs := Array(OS.get_cmdline_user_args())
	var attach := "attach" in hubs
	hubs = hubs.filter(func(a): return a not in ["paint", "attach"])
	if hubs.is_empty():
		hubs = HUBS
	for hub_id: String in hubs:
		var started := Time.get_ticks_msec()
		var ok := Upgrade.apply(hub_id, attach)
		print("%s: %s (%.1f s)" % [hub_id, "ok" if ok else "failed (is the picture imported?)", (Time.get_ticks_msec() - started) / 1000.0])
	get_tree().quit()
