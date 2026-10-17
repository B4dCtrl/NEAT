extends SceneTree
## Test mode end to end. Run it WITH the flag:
##   xvfb-run godot --path . -s res://tests/admin_check.gd -- --admin <out_dir>
## Checks that the test account lives apart from real ones, that the ADMIN
## actions work and that the save cannot trade; saves a screenshot of the panel.

const Admin = preload("res://core/admin.gd")
const Trade = preload("res://core/trade.gd")
const Accounts = preload("res://core/accounts.gd")

var out_dir := "user://screenshots"
var fails := 0


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


func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func _run(main) -> void:
	var game = root.get_node("Game")
	var wm = root.get_node("WindowManager")
	await _wait(20)
	_check(Admin.enabled(), "test mode is on")
	_check(Accounts.registry_path.begins_with("user://test/"), "accounts live in the test folder")
	_check(game.account == "teste", "the test account signed in by itself")
	_check(game.state.get("test_save", false), "the save is marked as a test save")
	_check(Trade.lock_reason(game.state) != "", "a test save cannot trade")
	game.state["intro_seen"] = true
	game.state["tutorial_seen"] = true
	game.state["named"] = true
	wm.set_mode("taskbar")
	await _wait(10)
	Admin.go_to_floor(game, 30)
	await _wait(150)
	_check(int(game.state["floor"]) >= 30, "jumped to floor 30 (now %d)" % int(game.state["floor"]))
	_check(int(game.state["best_floor_ever"]) >= 30, "floor 30 counts as reached")
	Admin.level_heroes(game, 0, 40)
	_check(int(game.state["heroes"][0]["level"]) == 40, "heroes set to level 40")
	var before: int = game.state["inventory"].size()
	Admin.give_items(game, "epic", 5)
	_check(game.state["inventory"].size() == before + 5, "five epic items in the bag")
	Admin.add_resource(game, "gold", 5000.0)
	Admin.add_resource(game, "crystals", 7.0)
	Admin.set_torment(game, 3)
	_check(int(game.state["torment_unlocked"]) == 3, "Torment 3 unlocked")
	Admin.unlock_manga(game)
	_check(game.state["manga"]["unlocked"].size() >= 5, "all manga chapters unlocked")
	Admin.set_speed(game, 20.0)
	_check(game.time_scale == 20.0, "speed x20")
	Admin.set_speed(game, 1.0)
	Admin.free_hero(game)
	_check(game.state["heroes"].size() >= 2, "a free hero joined the party")
	_check(not FileAccess.file_exists("user://accounts.json") or not (FileAccess.get_file_as_string("user://accounts.json").contains("\"teste\"")), "the real accounts file was not touched")
	var tv = main.get_node("TaskbarView")
	tv.panels.open("admin")
	tv.panels.open("inventory")
	await _wait(40)
	await _shot_desktop("admin_panel", tv)
	print("RESULT fails=", fails)
	quit()


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
