extends SceneTree
## Visual smoke test: boots the real game, fast-forwards and saves PNGs.
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s res://tests/screenshot.gd -- <out_dir>

var out_dir := "user://screenshots"
var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	if name.contains("taskbar"):
		img = _over_desktop(img)
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size())


func _run() -> void:
	var game = root.get_node("Game")
	var wm = root.get_node("WindowManager")
	await _wait(10)
	await _shot("01_taskbar_start")
	game.time_scale = 30.0
	await _wait(240)
	game.time_scale = 1.0
	await _wait(20)
	await _shot("01b_taskbar_walk")
	game.time_scale = 30.0
	await _wait(60)
	game.time_scale = 1.0
	# Try to catch a fight in progress.
	for i in 300:
		if game.expedition.phase == "combat" and game.expedition.combat.time > 1.0:
			break
		await process_frame
	await _shot("02_taskbar_combat")
	# Recruit two heroes so the party screens are full.
	game.state["gold"] = float(game.state["gold"]) + 5000.0
	game.mint_hero()
	game.mint_hero()
	await _wait(30)
	wm.set_mode("expedition")
	await _wait(30)
	var tabs: TabContainer = main.get_node("ExpeditionView").find_child("Tabs", true, false)
	var names := ["party", "equipment", "skills", "market", "ascension", "bestiary", "history", "stats", "settings"]
	for i in names.size():
		tabs.current_tab = i
		await _wait(12)
		await _shot("1%d_expedition_%s" % [i, names[i]])
	# Boss close-up on the next guardian floor.
	wm.set_mode("taskbar")
	game.time_scale = 40.0
	for i in 3000:
		if game.expedition.phase in ["intro", "combat"] and game.expedition.floor_info.get("type", "") == "guardian":
			break
		await process_frame
	game.time_scale = 1.0
	await _wait(60)
	await _shot("03_taskbar_boss")
	quit()


## Transparent pixels would show the real desktop: fake a wallpaper + taskbar
## behind them so the screenshot reads like the real thing.
func _over_desktop(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var bar := 48
	var out := Image.create(w, h + bar, false, Image.FORMAT_RGBA8)
	for y in h + bar:
		for x in w:
			var c: Color
			if y >= h:
				c = Color("#202226")
			else:
				c = Color("#2b5d8a").lerp(Color("#7fb2d9"), float(y) / h).lerp(Color("#e8c9a0"), float(x) / w * 0.35)
			out.set_pixel(x, y, c)
	out.blend_rect(img, Rect2i(0, 0, w, h), Vector2i.ZERO)
	return out
