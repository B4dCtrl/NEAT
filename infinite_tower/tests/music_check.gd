extends SceneTree
## Plays through the music logic with a real window (audio goes to a dummy
## driver): every theme must finish rendering, and the theme picked for each
## kind of moment must be the right one.
##   xvfb-run godot --path . -s res://tests/music_check.gd

const TowerGen = preload("res://core/tower_generator.gd")

var fails := 0


func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func _run() -> void:
	var game = root.get_node("Game")
	var audio = root.get_node("Audio")
	for i in 20:
		await process_frame
	load("res://core/accounts.gd").delete_account("music_bot")
	game.create_account("music_bot", "music-pass", false)
	game.state["intro_seen"] = true
	var t0 := Time.get_ticks_msec()
	var guard := 0
	while audio._tracks.size() < audio.track_names().size() and guard < 20000:
		guard += 1
		await process_frame
	print("themes ready: ", audio._tracks.keys(), " after ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	_check(audio._tracks.size() == audio.track_names().size(), "every theme rendered")
	_check(audio.current_track() == "climb", "the game starts on the climbing theme")
	var exp = game.expedition
	var seed_: int = int(game.state["seed"])
	var found := {}
	for f in range(2, 400):
		var tier := TowerGen.boss_tier(f)
		if tier != "" and not found.has(tier) and not TowerGen.is_bonfire(f):
			found[tier] = f
	print("boss floors: ", found)
	for tier in found:
		game.state["floor"] = found[tier]
		exp.floor_info = TowerGen.generate(seed_, found[tier])
		exp.phase = "intro"
		var want: String = {"guardian": "boss", "elite": "elite", "lord": "lord"}[tier]
		_check(audio._pick_track() == want, "%s floor %d plays '%s' (got '%s')" % [tier, found[tier], want, audio._pick_track()])
	# Enraged boss.
	game.state["floor"] = found["lord"]
	exp.floor_info = TowerGen.generate(seed_, found["lord"])
	exp._start_combat()
	for u in exp.combat.enemies:
		if u.is_boss:
			u.enraged = true
	_check(audio._pick_track() == "rage", "an enraged boss plays 'rage' (got '%s')" % audio._pick_track())
	# After the fight the climb theme returns.
	exp.combat = null
	exp.phase = "walk"
	_check(audio._pick_track() == "climb", "walking after a boss is the climbing theme")
	# Defeat and bonfire.
	game.state["floor"] = 18
	game.state["checkpoint"] = 11
	exp._fall_back()
	_check(audio._pick_track() == "fall", "a defeat plays the lament (got '%s')" % audio._pick_track())
	exp.phase = "pause"
	exp.falling = ""
	exp.floor_info = {"type": "bonfire"}
	_check(audio._pick_track() == "camp", "the bonfire plays the calm theme (got '%s')" % audio._pick_track())
	exp.floor_info = {}
	exp.phase = "walk"
	# Real switching with a crossfade.
	audio.force_track("elite")
	for i in 5:
		await process_frame
	_check(audio.current_track() == "elite", "forcing a theme switches to it")
	await create_timer(1.8).timeout
	_check(audio._music.playing and not audio._music_b.playing, "after the crossfade only one player is left")
	audio.force_track("")
	print("RESULT fails=", fails)
	quit()
