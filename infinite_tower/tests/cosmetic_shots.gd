extends SceneTree
## Visual check of the collectibles: tower skin, pet, aura, the Treasure Imp,
## and the Collection + Status (Torment) panels.
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s res://tests/cosmetic_shots.gd -- <out_dir> [lang]

const Cosmetics = preload("res://core/cosmetics.gd")

var out_dir := "user://screenshots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run(main, args[1] if args.size() > 1 else "pt")


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _run(main, lang: String) -> void:
	var game = root.get_node("Game")
	var wm = root.get_node("WindowManager")
	await _wait(20)
	game.set_language(lang)
	var Accounts = load("res://core/accounts.gd")
	Accounts.delete_account("cosmetic_bot")
	game.create_account("cosmetic_bot", "cosmetic-pass", false)
	await _wait(2)
	game.state["intro_seen"] = true
	game.state["tutorial_seen"] = true
	game.state["named"] = true
	game.state["torment_unlocked"] = 3
	var box := Cosmetics.box(game.state)
	box["caches"] = 6
	box["dust"] = 180
	for id in ["tower_ember", "pet_emberkit", "aura_rainbow", "pet_slimelet", "aura_dust", "tower_mossy"]:
		box["owned"][id] = 2 if id == "pet_slimelet" else 1
	for id in ["tower_ember", "pet_emberkit", "aura_rainbow"]:
		Cosmetics.equip(game.state, id)
	wm.set_mode("taskbar")
	await _wait(10)
	game.time_scale = 20.0
	await _wait(120)
	game.time_scale = 1.0
	for i in 600:
		if game.expedition.phase == "walk":
			break
		await process_frame
	game.imp_left = 12.0
	await _wait(40)
	await _shot_desktop("cos_01_taskbar_skin_pet_aura_imp", main.get_node("TaskbarView"))
	var big := root.get_texture().get_image()
	big.resize(big.get_width() * 3, big.get_height() * 3, Image.INTERPOLATE_NEAREST)
	big.save_png(out_dir.path_join("cos_01b_zoom.png"))
	var tv = main.get_node("TaskbarView")
	tv.panels.open("collection")
	tv.panels.open("status")
	await _wait(40)
	await _shot_desktop("cos_02_collection_status", tv)
	game.open_cache()
	await _wait(30)
	await _shot_desktop("cos_03_cache_opened", tv)
	quit()


## The tower and every open panel are separate OS windows: paint them onto
## a fake desktop at their real screen positions.
func _shot_desktop(name: String, tv) -> void:
	await process_frame
	await process_frame
	var wins: Array = [root]
	for id in tv.panels.open_ids():
		wins.append(tv.panels.window_of(id))
	var box := Rect2i(root.position, root.size)
	for w in wins:
		box = box.merge(Rect2i(w.position, w.size))
	box = box.grow(16)
	var out := Image.create(box.size.x, box.size.y + 48, false, Image.FORMAT_RGBA8)
	for y in out.get_height():
		var c: Color = Color("#202226") if y >= box.size.y else Color("#2b5d8a").lerp(Color("#7fb2d9"), float(y) / box.size.y)
		for x in out.get_width():
			out.set_pixel(x, y, c)
	for w in wins:
		var img: Image = w.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), w.position - box.position)
	out.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", out.get_size())
