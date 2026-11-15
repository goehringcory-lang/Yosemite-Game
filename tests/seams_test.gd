extends Node
## Checks the seams where one outdoor region's road runs off the map edge
## onto the next (see Seam): every walking seam on the Valley floor lines up
## edge to edge, the next region is laid beside this one as the player comes
## near, and walking over the edge carries on into it with no fade, no pause
## and nothing jumping on screen, and back again. Also the woods past the
## maps' edges (SeamBackdrop): trees stand off the maps, only brush and
## treetops reach over an edge and only a little, the woods darken away from
## the maps and turn with the seasons, and the birds keep to the ground.
## Run: godot --headless --path . res://tests/seams_test.tscn
## Exit code is the number of failed checks.

## Every road and trail that walks straight from one Valley floor area into
## the next: region -> its exits that are seams.
const SEAMS := {
	"yosemite_village": ["NorthsideWest", "NorthsideEast", "SouthsideWest", "SouthsideEast"],
	"leidig_meadow": ["ToVillage", "ToElCapitan"],
	"el_capitan_meadow": ["ToLeidigMeadow", "NorthsideDriveWest"],
	"big_oak_flat_junction": ["ToElCapitan"],
	"bridalveil_fall": ["ToFourMile", "ToTunnelView"],
	"tunnel_view": ["ToBridalveil"],
	"four_mile_trailhead": ["ToVillage", "ToBridalveil"],
	"housekeeping_camp": ["ToVillage", "ToCurry"],
	"curry_village": ["WestRoad", "EastRoad", "HomesteadGate"],
	"upper_pines": ["ToCurry", "ToHappyIsles"],
	"happy_isles": ["ToUpperPines", "ToTenayaCreek"],
	"tenaya_creek": ["ToHappyIsles", "ToMirrorLake"],
	"mirror_lake": ["ToTenayaCreek", "ToCrowsCamp"],
	"crows_camp": ["ToMirrorLake"],
	"ahwahnee_meadow": ["ToVillage", "ToAhwahnee"],
	"the_ahwahnee": ["ToStonemanBridge", "NorthsideDriveWest"],
	"ahwahnee_trail": ["ToHomestead", "ToAhwahnee"],
	"lamon_homestead": ["ToCurryVillage", "NorthToAhwahnee"],
}

var failures := 0


## How far the view lags the drawn player, as of the last frame drawn.
var _lag := Vector2.ZERO
var _camera: Camera2D


## Notes the lag once everything has moved this frame (this runs last).
func _process(_delta: float) -> void:
	if is_instance_valid(_camera):
		_lag = _camera.get_screen_center_position() - _camera.global_position


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	process_priority = 1 << 30
	SaveManager.save_path = "user://seams_test_save.json"
	SaveManager.delete_save()
	_check_all_seams()
	_check_backdrop()
	Engine.time_scale = 4.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	await world.go_to_region("yosemite_village", "west_road")
	# Arriving by a fade beside an edge, the camera is already settled there.
	var camera: Camera2D = world.player.get_node("Camera")
	var settled := camera.get_screen_center_position()
	for i in 10:
		await get_tree().process_frame
	check(camera.get_screen_center_position().distance_to(settled) < 2.0,
			"the camera doesn't drift after arriving by the edge (%s -> %s)" % [settled, camera.get_screen_center_position()])
	check(world.seam != null and world.seam.neighbor.region_id == "leidig_meadow", "arriving by the edge lays the next region out at once")
	check(camera.limit_left < 0, "and the camera can look over the edge")
	_check_blend(world, true)
	_check_critters(world)
	await _walk_across(world, "move_left", "leidig_meadow")
	await _walk_across(world, "move_right", "yosemite_village")
	# Off the road: the whole stretch of edge two maps share is open, so you
	# can wander over Leidig Meadow into El Capitan Meadow, well north of
	# Northside Drive, and back over the grass further south.
	await world.go_to_region("leidig_meadow", "arrival")
	for i in 30:
		await get_tree().process_frame
	world.player.global_position = world.region.to_global(Vector2(200, 96))
	await _walk_across(world, "move_left", "el_capitan_meadow")
	var off_road: Seam = world.seam
	check(off_road != null and absf(world.region.to_local(world.player.global_position).y - off_road.point.y) > Seam.CORRIDOR,
			"el_capitan_meadow: crossed well away from the road")
	_check_spans()
	# A north-south seam: from the hotel down the trail by Stoneman Bridge.
	await world.go_to_region("the_ahwahnee", "south_entry")
	# stepping in through a gate there's no fade to settle behind
	for i in 30:
		await get_tree().process_frame
	await _walk_across(world, "move_down", "ahwahnee_trail")
	_check_blend(world, true)
	var ahwahnee: Region = world.seam.neighbor
	world.seam.close()
	check(Seam._grounds(ahwahnee).all(func(g: Sprite2D) -> bool: return not g.material.get_shader_parameter("seam_on")),
			"closing a seam puts the ground's edge back")
	world.seam.open(world.region)

	# A drive that takes clock time still fades.
	check(Seam.candidates(load("res://scenes/regions/big_oak_flat_junction.tscn").instantiate()).all(
			func(e: RegionExit) -> bool: return e.minutes == 0), "roads that take clock time aren't seams")

	# Doors step straight in and out, with no dark screen.
	for into in [["welcome_center", "door"], ["yosemite_village", "welcome_center_door"]]:
		var faded := false
		world.go_to_region(into[0], into[1])
		for i in 60:
			faded = faded or world.hud.fade.color.a > 0.0
			if world.region.region_id == into[0] and world.player.can_act:
				break
			await get_tree().process_frame
		check(world.region.region_id == into[0] and world.player.can_act and not faded,
				"going through the door into %s steps straight in, with no fade" % into[0])

	world.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()
	print("%d failure(s)" % failures)
	get_tree().quit(failures)


## Each listed exit meets the next map edge to edge, and the seam back the
## other way lines up with it.
func _check_all_seams() -> void:
	var regions := {}
	for id in SEAMS:
		regions[id] = (load("res://scenes/regions/%s.tscn" % id) as PackedScene).instantiate()
	for id in SEAMS:
		var region: Region = regions[id]
		var found := Seam.candidates(region).map(func(e: RegionExit) -> String: return e.name)
		for exit_name in SEAMS[id]:
			var exit: RegionExit = region.find_child(exit_name, true, false)
			check(exit != null and exit_name in found, "%s: %s is a walking exit on the map edge" % [id, exit_name])
			if exit == null or not regions.has(exit.target_region):
				continue
			var seam := Seam.make(region, exit, regions[exit.target_region])
			check(seam != null, "%s: %s meets %s edge to edge" % [id, exit_name, exit.target_region])
			if seam:
				# the neighbor's edge tucks under this one by the overlap,
				# and the way back lands on the same spot
				check(is_equal_approx(seam._overlap(), Seam.OVERLAP), "%s: %s overlaps by %d px" % [id, exit_name, Seam.OVERLAP])
				var back := seam.reversed(region)
				check(back.offset == -seam.offset and is_equal_approx(back._overlap(), Seam.OVERLAP),
						"%s: %s lines up with the seam back" % [id, exit_name])
	for region: Region in regions.values():
		region.free()


## The woods past the maps' edges, with two maps laid side by side as at a
## seam: A, and B to its west, 200 px lower and overlapping it by 64.
func _check_backdrop() -> void:
	var was_season := GameClock.season
	var was_day := GameClock.day
	GameClock.season = GameClock.Season.SUMMER
	var a := Rect2(0, 0, 2048, 1152)
	var b := Rect2(-1984, 200, 2048, 1152)
	var maps: Array[Rect2] = [a, b]
	var merged := a.merge(b)
	var woods := SeamBackdrop.new()
	add_child(woods)
	var start := Time.get_ticks_usec()
	woods.cover(merged, maps)
	var first := (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	woods._lay_out()
	print("      the woods laid out in %.1f ms (%.1f ms with their pictures loaded): %d under the maps, %d over them, %d strips of shade" % [
			first, (Time.get_ticks_usec() - start) / 1000.0, woods._under.size(), woods._fringe.size(), woods._shade_rects.size()])
	check(woods._under.size() > 100 and woods._fringe.size() > 20, "woods stand past the maps' edges, and some reach over them")
	# nothing that reaches over a map hides more than its last couple of tiles
	var most := 0.0
	for item: Array in woods._fringe:
		var rect := Rect2(item[1], (item[0] as Texture2D).get_size())
		for map in maps:
			var on_map := rect.intersection(map)
			most = maxf(most, minf(on_map.size.x, on_map.size.y))
	check(most <= SeamBackdrop.TIP_OVER + 2.0, "what stands over a map's edge reaches at most %d px onto it (%d)" % [SeamBackdrop.TIP_OVER, most])
	# a tree's place by where it stands: below a map with only its top over
	# the edge it is drawn over the map, further up the map hides its top,
	# and hard against a map's side there is none
	var crown := Rect2(-40, -212, 80, 220)
	var below := Vector2(1000, a.end.y + 200)
	check(woods._standing(below, Rect2(below + crown.position, crown.size)) == 2, "a treetop just over a map's bottom edge is drawn over the map")
	below.y = a.end.y + 60
	check(woods._standing(below, Rect2(below + crown.position, crown.size)) == 1, "a tree close under a map has its top hidden by the map")
	var beside := Vector2(a.end.x + 4, 600)
	check(woods._standing(beside, Rect2(beside + crown.position, crown.size)) == 0, "no tree stands hard against a map's side, where the edge would slice it")
	beside.x = a.end.x + 30
	check(woods._standing(beside, Rect2(beside + crown.position, crown.size)) == 2, "a crown beside a map hangs over its edge")
	check(not woods._in_woods(Vector2(100, 100)) and woods._in_woods(Vector2(-900, 100)), "trees stand off the maps, in the corner between them")
	# the shade and the brush line the edges that face the woods (A's west
	# edge above B, B's top edge west of A), not the stretch the two maps
	# share nor the edges the camera can't look past
	check(woods._faces_woods(a, Vector2i.LEFT, 100.0) and woods._faces_woods(b, Vector2i.UP, -900.0), "the edges facing the corner between the maps face the woods")
	check(not woods._faces_woods(a, Vector2i.LEFT, 600.0), "the stretch of edge the two maps share doesn't")
	check(not woods._faces_woods(a, Vector2i.RIGHT, 600.0) and not woods._faces_woods(a, Vector2i.UP, 1000.0), "nor an edge the camera can't look past")
	var shaded := woods._shade_rects.all(func(item: Array) -> bool:
		var rect: Rect2 = item[0]
		return (a.encloses(rect) or b.encloses(rect)) and minf(rect.size.x, rect.size.y) <= 12.0)
	check(not woods._shade_rects.is_empty() and shaded, "the woods' shade lies a few pixels onto the maps' ground along those edges")
	# darker the deeper in
	check(woods._shade(0.0).get_luminance() > woods._shade(150.0).get_luminance() and woods._shade(150.0).get_luminance() > woods._shade(600.0).get_luminance(),
			"the woods darken away from the maps")
	# the year turns them: snow on the firs and a white floor in late winter
	var summer_fir := SeamBackdrop._picture("tree_white_fir", GameClock.Season.SUMMER)
	check(summer_fir != SeamBackdrop._picture("tree_white_fir", GameClock.Season.WINTER), "the woods' firs carry snow in winter")
	var summer_floor := woods._floor
	GameClock.season = GameClock.Season.WINTER
	GameClock.day = 26
	check(Seasons.snow_cover() > SeamBackdrop.SNOW_FLOOR, "snow lies late in winter (%.2f)" % Seasons.snow_cover())
	woods._process(0.0)
	check(woods._floor != summer_floor and woods._snowy, "and the woods' floor whitens with it")
	check(woods._under.any(func(item: Array) -> bool: return item[0] == SeamBackdrop._picture("tree_white_fir", GameClock.Season.WINTER)), "with the winter firs standing on it")
	woods.cover(Rect2())
	check(woods._under.is_empty() and woods._fringe.is_empty() and woods._shade_rects.is_empty() and not woods.is_processing(), "no seam, no woods")
	GameClock.season = was_season
	GameClock.day = was_day
	woods.queue_free()


## The birds and squirrels keep to the ground: none out in the woods or the
## sky past the maps' edges, in the middle of a river or up a cliff.
func _check_critters(world: Node) -> void:
	var critters: Critters = null
	for child in world.get_children():
		if child is Critters:
			critters = child
	if critters == null:
		check(false, "the world has its critters")
		return
	var region: Region = world.region
	var ground := region.get_ground()
	var merged: Rect2 = region.get_bounds().merge(world.seam.neighbor_bounds())
	check(not critters._on_land(region.to_global(merged.position - Vector2(300, 300))), "no bird lands in the woods past the maps' edges")
	var river := Vector2.INF
	var grass := Vector2.INF
	for cell in ground.get_used_cells():
		if ground.get_cell_source_id(cell) != 1:
			continue
		var kind := ground.get_cell_atlas_coords(cell).y
		var at := ground.to_global(ground.map_to_local(cell))
		if kind == 11 and river == Vector2.INF and [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].all(
				func(d: Vector2i) -> bool: return ground.get_cell_atlas_coords(cell + d).y == 11):
			river = at
		if kind in [0, 1] and grass == Vector2.INF and critters._open(at):
			grass = at
	check(river != Vector2.INF and not critters._open(river), "nor in the middle of the river")
	check(grass != Vector2.INF, "but they do on open grass and forest floor")


## Each seam opens more of its edge than the road's corridor, and where one
## edge meets two regions (the Village's west and east edges, Curry
## Village's east edge) their stretches don't overlap.
func _check_spans() -> void:
	var village: Region = (load("res://scenes/regions/yosemite_village.tscn") as PackedScene).instantiate()
	var spans := {}
	for exit_name in SEAMS["yosemite_village"]:
		var exit: RegionExit = village.find_child(exit_name, true, false)
		var neighbor: Region = (load("res://scenes/regions/%s.tscn" % exit.target_region) as PackedScene).instantiate()
		var seam := Seam.make(village, exit, neighbor)
		spans[exit_name] = seam.span
		# Southside Drive runs off near the map's foot, so there the stretch
		# is the road's corridor, cut by the map's corner.
		var least := 2.0 * Seam.CORRIDOR + 64.0 if exit_name.begins_with("Northside") else village.get_bounds().end.y - seam.point.y + Seam.CORRIDOR
		check(seam.span.y - seam.span.x >= least,
				"yosemite_village: %s opens %d px of edge (at least %d)" % [exit_name, seam.span.y - seam.span.x, least])
		neighbor.free()
	check(spans.NorthsideWest.y < spans.SouthsideWest.x and spans.NorthsideEast.y < spans.SouthsideEast.x,
			"yosemite_village: the two areas off each side get their own stretch of edge")
	village.free()


## The grounds on both sides of the open seam blend into each other.
func _check_blend(world: Node, on: bool) -> void:
	var grounds := Seam._grounds(world.region) + Seam._grounds(world.seam.neighbor)
	check(grounds.size() >= 2 and grounds.all(func(g: Sprite2D) -> bool: return g.material.get_shader_parameter("seam_on") == on),
			"%s and %s: the grounds blend over the seam" % [world.region.region_id, world.seam.neighbor.region_id])


## Walks [param action] from where the player stands until they're in
## [param into], checking the walk never stops or fades.
func _walk_across(world: Node, action: String, into: String) -> void:
	var from: String = world.region.region_id
	var player: Player = world.player
	var camera: Camera2D = player.get_node("Camera")
	_camera = camera
	for i in 600:
		if world.seam and world.seam.neighbor.region_id == into:
			break
		await get_tree().process_frame
	check(world.seam != null and world.seam.neighbor.region_id == into and world.seam.neighbor.is_inside_tree(),
			"%s: %s is laid beside it near the edge" % [from, into])
	if world.seam == null:
		return
	var shift: Vector2 = -world.seam.offset
	var faded := false
	var stopped := false
	var jump := 0.0
	var crossed := false
	# How far the view lags the player, and how much that changes from one
	# frame to the next walking along before the seam, and over it.
	var lag := Vector2.INF
	var settled := 0.0
	var lurch := 0.0
	Input.action_press(action)
	for i in 900:
		var before: Vector2 = camera.get_screen_center_position()
		var was: String = world.region.region_id
		await get_tree().process_frame
		faded = faded or world.hud.fade.color.a > 0.0
		stopped = stopped or not player.can_act or GameClock.paused
		if world.region.region_id != was:
			crossed = true
			# The camera hands over as this frame is drawn (after this
			# signal), so look a frame on: two frames' steps, in its new
			# pixels.
			await get_tree().process_frame
			jump = (camera.get_screen_center_position() - (before + shift)).length()
			# the camera's lag on the player carries over (two frames on)
			lurch = (_lag - lag).length()
			# walk on a little way into the new region
			for j in 20:
				await get_tree().physics_frame
			break
		var now := _lag
		if lag != Vector2.INF and i > 2:
			settled = maxf(settled, (now - lag).length())
		lag = now
	Input.action_release(action)
	check(crossed and world.region.region_id == into, "%s: walking on leads into %s" % [from, into])
	check(not faded, "%s -> %s: no fade" % [from, into])
	check(not stopped, "%s -> %s: the player never stops and the clock runs on" % [from, into])
	check(jump < 24.0, "%s -> %s: the view doesn't jump over the seam (%.1f px)" % [from, into, jump])
	check(lurch < 2.0 * settled + 3.0, "%s -> %s: the view glides on without a lurch (its lag on the player changes by %.1f px over the seam, up to %.1f a frame before)" % [from, into, lurch, settled])
	check(player.get_parent() == world.region.entities and world.region.position == Vector2.ZERO,
			"%s: the player is in its Entities and it sits at the origin" % into)
	check(world.seam != null and world.seam.neighbor.region_id == from and world.seam.neighbor.is_inside_tree(),
			"%s: %s stays laid out behind" % [into, from])
	check(world.region.get_bounds().has_point(world.region.to_local(player.global_position)), "%s: the player stands on its map" % into)
