extends SceneTree
## Captures the comic intro pages and the tutorial (fresh save required).
##   xvfb-run godot --path . -s res://tests/story_shots.gd -- <out_dir>

var out_dir := "user://story_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run(main)


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _run(main) -> void:
	await _wait(20)
	var comic = main.get("_comic")
	for page in 3:
		# Reveal each panel and let its caption type out before the next one.
		var n: int = comic._panels.size()
		for i in n:
			await _wait(30)
			comic._panels[i].reveal = 1.0
			comic._panels[i].finish_caption()
			if i < n - 1:
				comic._advance()      # next panel
		await _wait(20)
		await _shot("story_page_%d" % (page + 1))
		comic._advance()              # next page / finish
	await _wait(30)
	await _shot("story_tutorial_1")
	var tut = main.get("_tutorial")
	for i in 5:
		tut._show(i + 1)
	await _wait(10)
	await _shot("story_tutorial_6")
	quit()
