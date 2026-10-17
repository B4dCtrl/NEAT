extends SceneTree
## Films a fight: slows time down and saves the tower stage frame by frame,
## starting at the first attack, so the animation can be checked as a
## contact sheet (wind-up, dash, impact, recoil...).
##   xvfb-run godot --path . -s res://tests/combat_film.gd -- <out_dir> [floor (10 = boss)] [frames] [every]

var out_dir := "user://film"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run(main, int(args[1]) if args.size() > 1 else 1, int(args[2]) if args.size() > 2 else 40, int(args[3]) if args.size() > 3 else 4)


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _run(main, floor_num: int, frames: int, every: int) -> void:
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
	game.mint_hero()
	for h in s["heroes"]:
		h["level"] = 20
	wm.set_mode("expedition")
	await _wait(20)
	var exp = game.expedition
	if floor_num >= 10:
		# Fast-forward to the first guardian fight.
		game.time_scale = 40.0
		var g := 0
		while g < 6000 and not (exp.phase == "combat" and exp.floor_info.get("type", "") == "guardian"):
			g += 1
			await process_frame
		game.time_scale = 1.0
	var stage: Control = main.get_node("ExpeditionView").find_child("Stage", true, false)
	# Wait for a fight, then for the first basic attack of the party.
	var guard := 0
	while guard < 4000:
		guard += 1
		await process_frame
		if exp.phase != "combat":
			continue
		var started := false
		for ev in game.combat_events:
			if ev.get("t", "") in ["hit", "miss"] and String(ev.get("src", "")).begins_with("h") and String(ev.get("tag", "")) == "":
				started = true
		if started:
			break
	Engine.time_scale = 0.25
	var rect := stage.get_global_rect()
	var crop := Rect2i(int(rect.position.x + rect.size.x * 0.5 - 190), int(rect.position.y), 380, int(rect.size.y))
	for i in frames:
		await _wait(every)
		var img := root.get_texture().get_image()
		img = img.get_region(crop)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(out_dir.path_join("f%02d.png" % i))
	Engine.time_scale = 1.0
	print("filmed ", frames, " frames; crop ", crop)
	quit()
