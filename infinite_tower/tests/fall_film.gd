extends SceneTree
## Films a Fall Back (the party turns into spirits and rolls down to the
## bonfire) frame by frame, to check the animation as a contact sheet.
##   xvfb-run godot --path . -s res://tests/fall_film.gd -- <out_dir> [from_floor] [frames] [every] [style mono|color]

var out_dir := "user://film"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run(main, int(args[1]) if args.size() > 1 else 18, int(args[2]) if args.size() > 2 else 48, int(args[3]) if args.size() > 3 else 8, args[4] if args.size() > 4 else "mono")


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _run(main, from_floor: int, frames: int, every: int, style: String) -> void:
	var game = root.get_node("Game")
	var wm = root.get_node("WindowManager")
	await _wait(10)
	game.set_language("pt")
	load("res://core/accounts.gd").delete_account("film_bot")
	game.create_account("film_bot", "film-pass", false)
	var s: Dictionary = game.state
	s["intro_seen"] = true
	s["tutorial_seen"] = true
	s["named"] = true
	s["gold"] = 50000.0
	s["settings"]["art_style"] = style
	game.settings_changed.emit()
	game.mint_hero()
	game.mint_hero()
	wm.set_mode("expedition")
	await _wait(20)
	var exp = game.expedition
	var stage: Control = main.get_node("ExpeditionView").find_child("Stage", true, false)
	s["floor"] = from_floor
	s["max_floor"] = from_floor
	s["checkpoint"] = 10
	exp.combat = null
	exp.after_pause = "next_floor"
	exp._set_phase("pause", 100.0)
	await _wait(3)
	stage._snap_camera()
	await _wait(25)
	var rect := stage.get_global_rect()
	var crop := Rect2i(int(rect.position.x + rect.size.x * 0.5 - 190), int(rect.position.y), 380, int(rect.size.y))
	exp._fall_back()
	Engine.time_scale = 0.5
	for i in frames:
		await _wait(every)
		var img := root.get_texture().get_image()
		img = img.get_region(crop)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(out_dir.path_join("f%02d.png" % i))
	Engine.time_scale = 1.0
	print("filmed ", frames, " frames; floor now ", s["floor"], " phase ", exp.phase, " crop ", crop)
	quit()
