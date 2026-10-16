extends SceneTree
## Captures every manga page (all chapters) and the tutorial.
##   xvfb-run godot --path . -s res://tests/story_shots.gd -- <out_dir> [lang]

var out_dir := "user://story_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run(main, args[1] if args.size() > 1 else "")


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _read_chapter(main, id: String) -> void:
	var reader = main.get("_comic")
	var Story = load("res://core/story.gd")
	var pages: int = Story.chapter(id)["pages"].size()
	for page in pages:
		var n: int = reader._panels.size()
		for i in n:
			await _wait(8)
			reader._panels[i].active = true
			reader._panels[i].finish()
			if i < n - 1:
				reader._advance()
		await _wait(25)
		await _shot("manga_%s_page_%d" % [id, page + 1])
		if page < pages - 1:
			reader._advance()


func _run(main, lang: String) -> void:
	var game = root.get_node("Game")
	await _wait(20)
	if lang != "":
		game.set_language(lang)
	var Accounts = load("res://core/accounts.gd")
	Accounts.delete_account("story_bot")
	game.create_account("story_bot", "story-pass", false)
	main._after_login()
	await _wait(20)
	await _read_chapter(main, "c1")
	game.state["heroes"][0]["name"] = "Kael"
	for id in ["c2", "c3", "c4", "c5"]:
		load("res://core/story.gd").box(game.state)["unlocked"].append(id)
		main._on_story_requested("manga:" + id)
		await _wait(10)
		await _read_chapter(main, id)
	main._on_story_requested("manga")
	await _wait(15)
	await _shot("manga_index")
	quit()
