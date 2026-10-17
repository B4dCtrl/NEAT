extends SceneTree
## Opens every expedition tab and every taskbar panel with a well-stocked save
## and writes all visible UI text (labels, buttons, tooltips, menus) to a JSON
## file, so tools/i18n/find_english.py can spot text left in English.
##   xvfb-run godot --path . -s res://tests/ui_text_dump.gd -- <out.json> <lang>

const Cosmetics = preload("res://core/cosmetics.gd")
const DataDB = preload("res://core/data_db.gd")
const Loot = preload("res://core/loot_calculator.gd")

var texts := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run(main, args[0], args[1] if args.size() > 1 else "pt")


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _run(main, out_path: String, lang: String) -> void:
	var game = root.get_node("Game")
	var wm = root.get_node("WindowManager")
	await _wait(10)
	game.set_language(lang)
	_collect(root, "login")
	var Accounts = load("res://core/accounts.gd")
	Accounts.delete_account("ui_text_bot")
	game.create_account("ui_text_bot", "ui-text-pass", false)
	await _wait(2)
	var s: Dictionary = game.state
	s["intro_seen"] = true
	s["tutorial_seen"] = true
	s["named"] = true
	s["gold"] = 50000.0
	s["crystals"] = 40
	s["souls"] = 12.0
	game.mint_hero()
	game.mint_hero()
	for h in s["heroes"]:
		h["level"] = 30
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 12:
		var rarity: String = ["common", "uncommon", "rare", "epic", "legendary"][i % 5]
		s["inventory"].append(Loot.generate_item(rng, s, 25 + i, rarity))
	for c in DataDB.items()["consumables"]:
		s["consumables"][c] = 2
	var box := Cosmetics.box(s)
	box["caches"] = 2
	for id in ["tower_ember", "pet_emberkit", "aura_rainbow"]:
		box["owned"][id] = 1
	s["torment_unlocked"] = 2
	wm.set_mode("expedition")
	await _wait(30)
	game.time_scale = 20.0
	await _wait(200)
	game.time_scale = 1.0
	var tabs: TabContainer = main.get_node("ExpeditionView").find_child("Tabs", true, false)
	for i in tabs.get_tab_count():
		tabs.current_tab = i
		await _wait(15)
		_collect(main.get_node("ExpeditionView"), "tab_%d" % i)
	wm.set_mode("taskbar")
	await _wait(20)
	var tv = main.get_node("TaskbarView")
	_collect(tv, "taskbar")
	for id in tv.panels.ORDER:
		tv.panels.open(id)
		await _wait(25)
		_collect(tv.panels.window_of(id), "panel_" + id)
		tv.panels.close_all()
		await _wait(3)
	main._on_story_requested("manga")
	await _wait(15)
	_collect(main, "manga_index")
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(texts, "\t"))
	print("dumped ", texts.size(), " screens to ", out_path)
	quit()


func _collect(n: Node, screen: String) -> void:
	if not texts.has(screen):
		texts[screen] = []
	var out: Array = texts[screen]
	var stack: Array = [n]
	while not stack.is_empty():
		var c = stack.pop_back()
		stack.append_array(c.get_children())
		if c is Control and c.is_visible_in_tree():
			for prop in ["text", "tooltip_text", "placeholder_text"]:
				if prop in c and typeof(c.get(prop)) == TYPE_STRING and String(c.get(prop)).strip_edges() != "":
					out.append(String(c.get(prop)))
			if c is RichTextLabel:
				out.append(c.get_parsed_text())
			if c is OptionButton:
				for i in c.item_count:
					out.append(c.get_item_text(i))
			if c is TabContainer:
				for i in c.get_tab_count():
					out.append(c.get_tab_title(i))
			if c is Tree and c.get_root() != null:
				var it: TreeItem = c.get_root()
				while it != null:
					for col in c.columns:
						out.append(it.get_text(col))
					it = it.get_next_in_tree()
