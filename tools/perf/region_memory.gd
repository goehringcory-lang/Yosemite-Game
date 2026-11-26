extends Node
## Lists what holds GPU memory in each region World keeps: textures drawn by
## its nodes (by size), viewports, and shader parameters with textures.
## Run under a renderer: xvfb-run godot --path . res://tools/perf/region_memory.tscn
## PERF_REGIONS=a,b,c (default a Valley loop).

func _ready() -> void:
	SaveManager.save_path = "user://region_memory_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	for i in 5:
		await get_tree().process_frame
	Park.open_world = true
	Settings.journeys = OS.get_environment("PERF_JOURNEYS") != ""
	# PERF_OFF=ClassA,ClassB frees World's children of those script classes,
	# to find what holds memory
	for off in OS.get_environment("PERF_OFF").split(",", false):
		for child in world.find_children("*", "", true, false):
			var script: Script = child.get_script()
			if child.get_class() == off or (script and script.get_global_name() == off):
				child.queue_free()
	await get_tree().process_frame
	var ids := OS.get_environment("PERF_REGIONS").split(",", false)
	if ids.is_empty():
		ids = PackedStringArray(["yosemite_village", "leidig_meadow", "el_capitan_meadow", "curry_village"])
	for id in ids:
		var before := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
		# "stay" waits where the player is, to tell growth over time from
		# growth per trip
		if id != "stay":
			await world.go_to_region(id, "arrival", int(OS.get_environment("PERF_MINUTES")))
		for i in (300 if id == "stay" else 30):
			await get_tree().process_frame
		var after := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
		print("== %s: +%.0f MB texture memory (now %.0f MB)" % [id, (after - before) / 1048576.0, after / 1048576.0])
		if OS.get_environment("PERF_QUIET") == "":
			_report(world.region)
	SaveManager.delete_save()
	get_tree().quit()


func _report(region: Node) -> void:
	var seen := {}
	var rows := []
	for node in region.find_children("*", "", true, false):
		for prop in node.get_property_list():
			if prop.type != TYPE_OBJECT:
				continue
			var value = node.get(prop.name)
			if value is Texture2D:
				_add(value, "%s.%s" % [node.name, prop.name], seen, rows)
			elif value is ShaderMaterial:
				for p in (value as ShaderMaterial).shader.get_shader_uniform_list():
					var t = value.get_shader_parameter(p.name)
					if t is Texture2D:
						_add(t, "%s.material.%s" % [node.name, p.name], seen, rows)
		if node is SubViewport:
			var size: Vector2i = (node as SubViewport).size
			rows.append([size.x * size.y * 4, "SubViewport %s %s" % [node.get_path(), size]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var total := 0
	for r in rows:
		total += r[0]
	print("   %d textures, %.0f MB (RGBA estimate)" % [rows.size(), total / 1048576.0])
	for r in rows.slice(0, 12):
		print("   %6.1f MB  %s" % [r[0] / 1048576.0, r[1]])


func _add(tex: Texture2D, where: String, seen: Dictionary, rows: Array) -> void:
	var key := tex.get_rid()
	if seen.has(key):
		return
	seen[key] = true
	rows.append([tex.get_width() * tex.get_height() * 4, "%s %dx%d %s" % [where, tex.get_width(), tex.get_height(), tex.resource_path.get_file()]])

