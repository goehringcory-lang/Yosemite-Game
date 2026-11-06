extends Node
## Renders the Guardian's camp at the Lamon Homestead (Camp, CampPiece) with
## everything the story gives it, for checking the layout. Needs a window.
## Environment:
##   SHOT_STAGE  "start" (a new game), "middle" (through the Nose), or "end"
##               (every quest, summits and fish logged). Default "end".
##   SHOT_DIR    folder for the PNG (default user://)
## Run: xvfb-run godot --path . res://tools/shots/camp_shot.tscn

const MIDDLE := ["clark_register", "shop_guidebook", "shop_outfit", "partner_apron", "lamon_orchard", "leonard_belay",
	"eichorn_apron", "robbins_clean", "hodges_patrol", "degnan_bread", "curry_starter", "ansel_monolith", "wren_apron",
	"eichorn_spires", "salathe_steel", "johnson_astroman", "robbins_roof", "harding_summit"]


func _ready() -> void:
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var stage := OS.get_environment("SHOT_STAGE") if OS.get_environment("SHOT_STAGE") != "" else "end"
	NewGame.reset()
	GameClock.minutes = 9 * 60
	if stage != "start":
		QuestLog.completed.assign(MIDDLE)
		Gear.add("rope")
		Gear.add("cam", 6)
		Gear.add("quickdraw", 5)
		Achievements.summits = {"sentinel_rock": {"day": 1}, "el_capitan": {"day": 2}}
	if stage == "end":
		for quest: QuestData in QuestLog.QUESTS:
			if not quest.id in QuestLog.completed:
				QuestLog.completed.append(quest.id)
		Gear.add("ice_axe")
		Achievements.summits = {"sentinel_rock": {"day": 1}, "el_capitan": {"day": 2}, "cathedral_peak": {"day": 3},
			"half_dome": {"day": 4}, "higher_cathedral_spire": {"day": 5}}
		Achievements.fish = {"brown_trout": {"count": 2, "biggest": 19, "trophies": 0}}
	Camp.changed.emit()
	var region: Region = load("res://scenes/regions/lamon_homestead.tscn").instantiate()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(680, 420)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(region)
	StoryContent.attach(region)
	var camera := Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.position = Vector2(110, 150)
	viewport.add_child(camera)
	for i in 10:
		await get_tree().process_frame
	viewport.get_texture().get_image().save_png("%s/camp_%s.png" % [dir, stage])
	get_tree().quit()
