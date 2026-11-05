extends Node
## Screenshots of the park's wider wildlife: squirrels, acorn woodpeckers
## and a bobcat frozen mid-stalk in Leidig Meadow; a peregrine falcon
## stooping over El Capitan Meadow; great gray owls hunting Crane Flat at
## dusk; the high country's squirrels and nutcrackers at Tuolumne; and the
## Wildlife journal.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/wildlife_shot.tscn

var world: Node
var dir := ""


func _ready() -> void:
	SaveManager.save_path = "user://wildlife_shot_save.json"
	SaveManager.delete_save()
	world = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	dir = OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	Weather.today()
	Weather._today = {"snow": 0.0, "rain": 0.0, "clouds": 0.2}
	await _valley()
	await _peregrine()
	await _owls()
	await _high_country()
	await _journal()
	SaveManager.delete_save()
	get_tree().quit()


func _go(region: String, spawn: String, hour: float, season: int) -> Vector2:
	await world.go_to_region(region, spawn)
	for i in 12:
		await get_tree().process_frame
	GameClock.minutes = int(hour * 60)
	GameClock.season = season
	GameClock.paused = true
	GameClock.time_changed.emit(GameClock.hour, GameClock.minutes % 60)
	Weather._today = {"snow": 0.0, "rain": 0.0, "clouds": 0.2}
	_critters()._birds.clear()
	_critters()._squirrels.clear()
	_critters()._flies.clear()
	return world.player.global_position


func _critters() -> Critters:
	return world.find_children("*", "Critters", true, false)[0]


func _valley() -> void:
	var at := await _go("leidig_meadow", "meadow", 8.5, GameClock.Season.FALL)
	var critters := _critters()
	critters.set_process(false)
	var gray := critters.add_squirrel("western_gray_squirrel", at + Vector2(-150, -70))
	gray.alert = true
	var ground := critters.add_squirrel("california_ground_squirrel", at + Vector2(-90, 110))
	ground.facing = -1
	var runner := critters.add_squirrel("western_gray_squirrel", at + Vector2(140, 120))
	runner.state = "run"
	runner.steps = 0.05
	critters.add_bird("acorn_woodpecker", at + Vector2(-210, 20))
	var peck := critters.add_bird("acorn_woodpecker", at + Vector2(-185, 34))
	peck.pecked = 1.0
	peck.facing = -1
	critters.queue_redraw()
	var bobcats: Bobcats = world.find_children("*", "Bobcats", true, false)[0]
	var cat := bobcats.add_group(at + Vector2(170, -30), at + Vector2(600, -30))
	bobcats.set_process(false)
	cat.state = "watch"
	cat.facing = -1
	cat.queue_redraw()
	var stalker := bobcats.add_group(at + Vector2(260, 60), at + Vector2(700, 60))
	stalker.state = "forage"
	stalker.timer = 2.0
	stalker.queue_redraw()
	await _snap("wildlife_valley")
	bobcats._clear()
	bobcats.set_process(true)
	critters._squirrels.clear()
	critters._birds.clear()
	critters.set_process(true)


func _peregrine() -> void:
	await _go("el_capitan_meadow", "meadow", 11.0, GameClock.Season.SPRING)
	var falcons: Falcons = world.find_children("*", "Falcons", true, false)[0]
	var view := falcons._view()
	var soaring := falcons.send_one()
	soaring.pos = view.get_center() + Vector2(-260, 40)
	soaring.vel = Vector2(Falcons.SOAR_SPEED, 0)
	soaring.time = 99.0
	soaring.flap = 1.5
	var stooper := falcons.send_one()
	stooper.pos = view.get_center() + Vector2(40, 30)
	stooper.time = 0.0
	falcons._process(0.016)
	for i in 14:
		falcons._process(0.03)
	falcons.set_process(false)
	await _snap("wildlife_peregrine")
	falcons._falcons.clear()
	falcons._prey.clear()
	falcons.set_process(true)


func _owls() -> void:
	var at := await _go("crane_flat", "meadow", 18.75, GameClock.Season.FALL)
	var owls: Owls = world.find_children("*", "Owls", true, false)[0]
	var sitting := owls.add_group(at + Vector2(-90, 20), at + Vector2(-500, 20))
	var flying := owls.add_group(at + Vector2(80, -50), at + Vector2(600, -50))
	for i in 3:
		await get_tree().process_frame
	owls.set_process(false)
	sitting.state = "forage"
	sitting.facing = 1
	(sitting as GreatGrayOwl)._in_state = 1.0
	sitting.queue_redraw()
	flying.state = "wander"
	flying.queue_redraw()
	await _snap("wildlife_owls")
	owls._clear()
	owls.set_process(true)


func _high_country() -> void:
	var at := await _go("tuolumne_meadows", "arrival", 10.0, GameClock.Season.SUMMER)
	var critters := _critters()
	critters.set_process(false)
	critters.add_squirrel("golden_mantled_ground_squirrel", at + Vector2(-120, 70))
	var chick := critters.add_squirrel("douglas_squirrel", at + Vector2(130, 60))
	chick.alert = true
	chick.facing = -1
	critters.add_bird("clarks_nutcracker", at + Vector2(-60, -80))
	var nut := critters.add_bird("clarks_nutcracker", at + Vector2(90, -70))
	nut.facing = -1
	nut.pecked = 1.0
	critters.queue_redraw()
	await _snap("wildlife_high_country")
	critters._squirrels.clear()
	critters._birds.clear()
	critters.set_process(true)


func _journal() -> void:
	FieldLog.start_new_game()
	for id in ["stellers_jay", "robin", "acorn_woodpecker", "peregrine_falcon", "great_gray_owl", "western_gray_squirrel",
			"california_ground_squirrel", "bobcat", "mule_deer", "black_bear", "butterfly_0", "brown_trout", "mountain_chickadee"]:
		FieldLog.spot(id, true)
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	journal.open(Journal.Tab.WILDLIFE)
	for i in 9:
		journal.move_cursor(Vector2i(1, 0))
	await _snap("wildlife_journal")
	for i in 7:
		journal.move_cursor(Vector2i(0, 1))
	await _snap("wildlife_journal_more")
	journal.close()


func _snap(shot_name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
