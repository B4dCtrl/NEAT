extends SceneTree
## Opens the Inventory panel's Refine/Evolve drop-down with a full bag and
## reports whether its popup stays in front of the (always-on-top) panel.
##   xvfb-run godot --path . -s res://tests/popup_check.gd -- [hold_seconds]

const Loot = preload("res://core/loot_calculator.gd")


func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run(main, float(OS.get_cmdline_user_args()[0]) if not OS.get_cmdline_user_args().is_empty() else 0.0)


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _run(main, hold: float) -> void:
	var game = root.get_node("Game")
	var wm = root.get_node("WindowManager")
	await _wait(10)
	game.set_language("pt")
	load("res://core/accounts.gd").delete_account("popup_bot")
	game.create_account("popup_bot", "popup-pass", false)
	var s: Dictionary = game.state
	s["intro_seen"] = true
	s["tutorial_seen"] = true
	s["named"] = true
	s["gold"] = 90000.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 55:
		s["inventory"].append(Loot.generate_item(rng, s, 10 + i % 7, ["common", "uncommon", "rare"][i % 3]))
	wm.set_mode("taskbar")
	await _wait(10)
	var tv = main.get_node("TaskbarView")
	tv.panels.open("inventory")
	await _wait(30)
	var win: Window = tv.panels.window_of("inventory")
	var opt: OptionButton = win.find_children("*", "OptionButton", true, false)[0]
	opt.show_popup()
	await _wait(20)
	var pop := opt.get_popup()
	print("PANEL always_on_top=", win.always_on_top, " | POPUP visible=", pop.visible, " always_on_top=", pop.always_on_top, " transient=", pop.transient, " size=", pop.size, " items=", pop.item_count)
	if hold > 0.0:
		await create_timer(hold).timeout
	quit()
