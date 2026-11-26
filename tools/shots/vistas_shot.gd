extends Node
## Saves screenshots of taking in each vista's view (VistaView) part way
## through its sweep, the peak-finder's arrow at Tunnel View, and the ground
## around each vista spot, register and sketch spot (VistaSpot,
## ChallengeSpot). Needs a window (not --headless).
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/vistas_shot.tscn
##   SHOT_ONLY=tunnel_view ...   (that vista's panorama only)
##   SHOT_GROUND=0 ...           (skip the ground shots)


func _ready() -> void:
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var only := OS.get_environment("SHOT_ONLY")
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 10
	for vista: Dictionary in Vistas.all():
		if only != "" and vista.id != only:
			continue
		GameClock.minutes = 16 * 60 + 30 if vista.id != "glacier_point" else 18 * 60 + 30
		Park.spotted_peaks.clear()
		var view := VistaView.new()
		view.setup_vista(vista)
		add_child(view)
		while not view._ready_to_draw:
			await get_tree().process_frame
		await get_tree().create_timer(view._sweep_time * 0.55).timeout
		await _save("%s/vista_%s.png" % [dir, vista.id])
		if vista.id == "tunnel_view":
			view._finish_sweep()
			view.point_at(str(vista.quiz_target))
			await get_tree().create_timer(1.5).timeout
			var box := DialogueBox.open(self)
			var quiz := Vistas.quiz(vista.id)
			var names: Array = []
			for id: String in quiz.options:
				names.append(Landmarks.get_landmark(id).name)
			box.choose("Peak-finder: which one is under the arrow?", names)
			await get_tree().create_timer(0.8).timeout
			await _save("%s/vista_peak_finder.png" % dir)
			box.close()
		view.queue_free()
		await get_tree().process_frame
	if OS.get_environment("SHOT_GROUND") != "0" and only == "":
		await _ground(dir)
	get_tree().quit()


func _save(path: String) -> void:
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


func _ground(dir: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 270)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera := Camera2D.new()
	viewport.add_child(camera)
	GameClock.paused = true
	GameClock.minutes = 12 * 60
	var spots: Array = []
	for vista: Dictionary in Vistas.all():
		spots.append(vista)
	for entry: Dictionary in Challenges.registers() + Challenges.sketches():
		spots.append(entry)
	for entry: Dictionary in spots:
		var region: Region = load("res://scenes/regions/%s.tscn" % entry.region).instantiate()
		viewport.add_child(region)
		StoryContent.attach(region)
		camera.position = Vector2(entry.pos[0], entry.pos[1]) + Vector2(0, -16)
		for i in 10:
			await get_tree().process_frame
		viewport.get_texture().get_image().save_png("%s/spot_%s.png" % [dir, entry.id])
		print("shot spot ", entry.id)
		viewport.remove_child(region)
		region.free()
