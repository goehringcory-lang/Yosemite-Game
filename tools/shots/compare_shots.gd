extends SceneTree
## Compares two folders of screenshots with the same names, pixel by pixel,
## and prints one line per picture: the share of pixels that differ by more
## than THRESHOLD in any channel, and the mean difference. Writes a picture
## of the differences beside each pair (red where they differ) into OUT_DIR.
## Exits 1 if any picture is missing or differs on more than MAX_SHARE of its
## pixels.
## Run: godot --headless --path . --script res://tools/shots/compare_shots.gd -- BEFORE_DIR AFTER_DIR OUT_DIR [MAX_SHARE]

## Differences at or under this (out of 255) are noise: dithering, a
## shimmer's frame.
const THRESHOLD := 24


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("usage: -- BEFORE_DIR AFTER_DIR OUT_DIR [MAX_SHARE]")
		quit(2)
		return
	var before_dir := args[0]
	var after_dir := args[1]
	var out_dir := args[2]
	var max_share := float(args[3]) if args.size() > 3 else 0.02
	DirAccess.make_dir_recursive_absolute(out_dir)
	var failed := 0
	var names := Array(DirAccess.get_files_at(before_dir)).filter(func(n: String) -> bool: return n.ends_with(".png"))
	names.sort()
	for file: String in names:
		var a := Image.load_from_file(before_dir.path_join(file))
		if not FileAccess.file_exists(after_dir.path_join(file)):
			print("MISSING  %s" % file)
			failed += 1
			continue
		var b := Image.load_from_file(after_dir.path_join(file))
		if a.get_size() != b.get_size():
			print("SIZE     %s  %s vs %s" % [file, a.get_size(), b.get_size()])
			failed += 1
			continue
		a.convert(Image.FORMAT_RGB8)
		b.convert(Image.FORMAT_RGB8)
		# one sample per game pixel is enough, and keeps this quick
		while a.get_width() > 960:
			a.resize(a.get_width() / 2, a.get_height() / 2, Image.INTERPOLATE_NEAREST)
			b.resize(b.get_width() / 2, b.get_height() / 2, Image.INTERPOLATE_NEAREST)
		var w := a.get_width()
		var h := a.get_height()
		var da := a.get_data()
		var db := b.get_data()
		var diff := Image.create(w, h, false, Image.FORMAT_RGB8)
		var differing := 0
		var total := 0.0
		for y in h:
			for x in w:
				var i := (y * w + x) * 3
				var d := maxi(maxi(absi(da[i] - db[i]), absi(da[i + 1] - db[i + 1])), absi(da[i + 2] - db[i + 2]))
				total += d
				var grey := (da[i] + da[i + 1] + da[i + 2]) / 765.0 * 0.35
				if d > THRESHOLD:
					differing += 1
					diff.set_pixel(x, y, Color(1, 0.1, 0.1))
				else:
					diff.set_pixel(x, y, Color(grey, grey, grey))
		var share := float(differing) / float(w * h)
		var ok := share <= max_share
		if not ok:
			failed += 1
		print("%s  %-40s %6.2f%% of pixels differ, mean %.2f" % ["ok  " if ok else "DIFF", file, share * 100.0, total / float(w * h)])
		diff.save_png(out_dir.path_join(file.get_basename() + "_diff.png"))
	print("%d of %d pictures match" % [names.size() - failed, names.size()])
	quit(1 if failed > 0 or names.is_empty() else 0)
