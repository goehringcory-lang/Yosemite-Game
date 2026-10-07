class_name EasterEggs
extends RefCounted
## Small hidden touches added to regions when they first load. They need no
## edits to the generated hub scenes, so a map rebuild keeps them. The moving
## ones (the Firefall and the moonbow) are placed by the story overlays; this
## class handles the conditional sign text, the readable bear boxes, and the
## Camp 4 headlamp. Described for developers in docs/DESIGN.md ("Easter eggs").

const BEAR_BOX_TEXT := "Bear box. Food, coolers, and anything with a smell go in here, day and night. Black bears in Yosemite learned to open cars for food."
const FIREFALL_TEXT := "The call is going up from the rim: 'Let the fire fall!' High above the wall, the bonfire's glow sits on Glacier Point, and a ribbon of embers begins to run down the granite."
const MOONBOW_TEXT := "Full moon in spring. The spray at the base catches the light, and a faint white arc forms in the mist: a moonbow."
const MIDNIGHT_TEXT := "Past midnight. The bolt is freshly chalked, and a headlamp sits on the ledge."
const CLARK_NOTE_TEXT := "A note is pinned inside the window, in Clark's hand: 'Write it at the front of the book, not the back.'"


## Dresses [param region] for its Easter eggs. Safe to call once per region.
static func dress(region: Region) -> void:
	match region.region_id:
		"curry_village":
			_bear_boxes(region)
			var board := _sign(region, "FirefallBoard")
			if board:
				board.extra_text = FIREFALL_TEXT
				board.extra_season = GameClock.Season.SUMMER
				board.extra_when = GameClock.is_firefall_time
		"yosemite_village":
			_bear_boxes(region)
			var fall := _sign(region, "LowerFallSign")
			if fall:
				fall.extra_text = MOONBOW_TEXT
				fall.extra_season = GameClock.Season.SPRING
				fall.extra_full_moon = true
				fall.extra_hours = Vector2i(GameClock.MOONBOW_FROM_HOUR, GameClock.MOONBOW_TO_HOUR)
			var boulder := _sign(region, "ColumbiaBoulder")
			if boulder:
				boulder.extra_text = MIDNIGHT_TEXT
				boulder.extra_hours = Vector2i(0, 4)
				var lamp := Headlamp.new()
				lamp.name = "Headlamp"
				lamp.position = Vector2(6, -26)
				boulder.add_child(lamp)
		"wawona":
			var clark := _sign(region, "Sign_Clarks_Station")
			if clark:
				clark.extra_text = CLARK_NOTE_TEXT
				clark.extra_after_quest = "tenaya_ahwahnee"


## Finds an InfoSign by name anywhere in the region (generated maps nest theirs).
static func _sign(region: Region, node_name: String) -> InfoSign:
	return region.find_child(node_name, true, false) as InfoSign


## Turns each BearBox prop into a readable sign.
static func _bear_boxes(region: Region) -> void:
	for node in region.entities.get_children():
		if node is StaticBody2D and "BearBox" in String(node.name) and not node is InfoSign:
			make_readable(node, "Bear Box", BEAR_BOX_TEXT, Vector2(20, 16), Vector2(0, -6))


## Gives a plain prop an InfoSign's behavior: the sign script and a hitbox the
## player's interact button can reach. Returns the node as an InfoSign.
static func make_readable(body: StaticBody2D, title: String, text: String, hit_size: Vector2, hit_center: Vector2) -> InfoSign:
	body.set_script(preload("res://scripts/objects/info_sign.gd"))
	body.set("title", title)
	body.set("text", text)
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = hit_size
	shape.shape = rect
	shape.position = hit_center
	hitbox.add_child(shape)
	body.add_child(hitbox)
	return body as InfoSign
