extends SceneTree
## Shows the upgrade hints: a party in weak gear and a bag with better and
## worse items. Prints the scan time and saves the Inventory panel.
##   xvfb-run godot --path . -s res://tests/upgrade_shots.gd -- <out_dir> [lang]

const Loot = preload("res://core/loot_calculator.gd")
const Inventory = preload("res://core/inventory.gd")

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
	await _wait(10)
	game.set_language(lang)
	load("res://core/accounts.gd").delete_account("upgrade_bot")
	game.create_account("upgrade_bot", "upgrade-pass", false)
	var s: Dictionary = game.state
	s["intro_seen"] = true
	s["tutorial_seen"] = true
	s["named"] = true
	s["gold"] = 90000.0
	game.mint_hero()
	game.mint_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for h in s["heroes"]:
		h["level"] = 25
	# Everyone wears weak common gear; the bag holds a mix of weaker and stronger pieces.
	for h in s["heroes"]:
		for slot in ["helm", "chest", "boots"]:
			for t in 30:
				var it: Dictionary = Loot.generate_item(rng, s, 2, "common", "", func(b): return b["slot"] == slot)
				if Loot.can_equip(it, h["class"]):
					h["equipment"][slot] = it
					break
	for i in 40:
		s["inventory"].append(Loot.generate_item(rng, s, 3 + i * 2 % 40, ["common", "uncommon", "rare", "epic"][i % 4]))
	var t0 := Time.get_ticks_usec()
	var scan: Dictionary = game.upgrades()
	print("SCAN ms=", (Time.get_ticks_usec() - t0) / 1000.0, " bag=", s["inventory"].size(), " heroes=", s["heroes"].size(), " upgrades=", scan["total"], " per_hero=", scan["per_hero"])
	game.inventory_changed.emit()
	wm.set_mode("taskbar")
	await _wait(20)
	var tv = main.get_node("TaskbarView")
	tv.panels.open("inventory")
	await _wait(50)
	await _shot_desktop("up_01_inventory", tv)
	# Tooltip of the first highlighted item.
	for id in scan["items"]:
		var info: Dictionary = scan["items"][id]
		if not info["top_for"].is_empty():
			var it = game.state["inventory"].filter(func(x): return int(x["uid"]) == int(id))[0]
			var tip: String = load("res://scenes/ui/tabs/party_tab.gd").item_tooltip(it, load("res://core/upgrades.gd").hint_lines(s, it, info["gains"]))
			print("TOOLTIP:\n", tip.get_slice("\n\n", 0))
			break
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
