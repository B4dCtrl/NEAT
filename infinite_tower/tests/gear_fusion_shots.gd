extends SceneTree
## Screenshots of the class-bound gear (class badges, dimmed pieces) and the hero
## fusion box. Run in test mode:
##   xvfb-run godot --path . -s res://tests/gear_fusion_shots.gd -- --admin <out_dir>

const Admin = preload("res://core/admin.gd")

var out_dir := "user://screenshots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run(main)


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _run(main) -> void:
	var game = root.get_node("Game")
	var wm = root.get_node("WindowManager")
	await _wait(20)
	game.state["intro_seen"] = true
	game.state["tutorial_seen"] = true
	game.state["named"] = true
	game.set_language("pt")
	wm.set_mode("taskbar")
	await _wait(10)
	Admin.go_to_floor(game, 31)
	Admin.give_heroes(game, "common", 3)
	Admin.give_heroes(game, "rare", 3)
	Admin.level_heroes(game, 0, 12)
	Admin.fill_bag(game)
	Admin.give_items(game, "epic", 8)
	await _wait(40)
	var tv = main.get_node("TaskbarView")
	tv.panels.open("heroes")
	tv.panels.open("inventory")
	await _wait(50)
	_scroll_down(tv.panels.window_of("heroes"))
	await _wait(10)
	await _shot("gear_fusion_pt", tv)
	game.set_language("en")
	await _wait(30)
	_scroll_down(tv.panels.window_of("heroes"))
	await _wait(10)
	await _shot("gear_fusion_en", tv)
	quit()


func _scroll_down(node: Node) -> void:
	for c in node.find_children("*", "ScrollContainer", true, false):
		c.scroll_vertical = 100000


func _shot(name: String, tv) -> void:
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
