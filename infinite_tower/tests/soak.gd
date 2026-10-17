extends SceneTree
## Stability soak: plays the real game fast for a while (climbs, fights, falls,
## bosses), opens and closes every panel, flips languages and modes, opens a
## cache and catches the imp. Any script error shows up in the log.
##   xvfb-run godot --path . -s res://tests/soak.gd -- [seconds]

var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run(float(args[0]) if not args.is_empty() else 180.0)


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _run(seconds: float) -> void:
	var game = root.get_node("Game")
	var wm = root.get_node("WindowManager")
	await _wait(10)
	var Accounts = load("res://core/accounts.gd")
	Accounts.delete_account("soak_bot")
	game.create_account("soak_bot", "soak-pass", false)
	game.state["intro_seen"] = true
	game.state["tutorial_seen"] = true
	game.state["named"] = true
	wm.set_mode("taskbar")
	var tv = main.get_node("TaskbarView")
	var start := Time.get_ticks_msec()
	var langs := ["pt", "es", "en"]
	var round := 0
	game.time_scale = 60.0
	while (Time.get_ticks_msec() - start) / 1000.0 < seconds:
		round += 1
		await _wait(90)
		var id: String = tv.panels.ORDER[round % tv.panels.ORDER.size()]
		tv.panels.open(id)
		await _wait(20)
		if round % 5 == 0:
			game.set_language(langs[(round / 5) % langs.size()])
			await _wait(10)
		tv.panels.close_all()
		if round % 7 == 0:
			wm.set_mode("expedition")
			var tabs: TabContainer = main.get_node("ExpeditionView").find_child("Tabs", true, false)
			for t in tabs.get_tab_count():
				tabs.current_tab = t
				await _wait(5)
			wm.set_mode("taskbar")
		if round % 4 == 0 and float(game.state["gold"]) > 0.0:
			game.mint_hero()
		if round % 9 == 0:
			game.imp_left = 5.0
			await _wait(5)
			game.catch_imp()
			game.open_cache()
		if round % 11 == 0:
			game.save()
	game.time_scale = 1.0
	print("SOAK DONE rounds=%d floor=%d best=%d heroes=%d falls=%d" % [round, game.state["floor"], game.state["best_floor_ever"], game.state["heroes"].size(), int(game.state["stats"].get("falls", 0))])
	quit()
