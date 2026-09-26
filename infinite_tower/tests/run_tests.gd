extends SceneTree
## Headless test runner for the pure simulation layer.
##   godot --headless --path . -s res://tests/run_tests.gd
## Add `-- --balance` to also print a long balance simulation.

const DataDB = preload("res://core/data_db.gd")
const GameState = preload("res://core/game_state.gd")
const TowerGen = preload("res://core/tower_generator.gd")
const CombatEngine = preload("res://core/combat_engine.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const Loot = preload("res://core/loot_calculator.gd")
const Inventory = preload("res://core/inventory.gd")
const Progression = preload("res://core/progression.gd")
const Expedition = preload("res://core/expedition.gd")
const SaveSystem = preload("res://core/save_system.gd")
const Heroes = preload("res://core/heroes.gd")
const Market = preload("res://core/market.gd")
const Forge = preload("res://core/forge.gd")

var failures := 0
var passes := 0


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	test_data_tables()
	test_tower_generator()
	test_combat_determinism()
	test_loot_and_inventory()
	test_expedition_determinism()
	test_fall_back()
	test_save_roundtrip()
	test_offline_progress()
	test_ascension()
	test_roster_and_skills()
	test_bonfire_and_market()
	test_variety_and_supplies()
	test_forge()
	if "--balance" in OS.get_cmdline_user_args():
		balance_report()
	print("\n%d passed, %d failed (%d ms)" % [passes, failures, Time.get_ticks_msec() - t0])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("FAIL: " + msg)


func test_data_tables() -> void:
	for t in DataDB.FILES:
		check(not DataDB.table(t).is_empty(), "table %s loads" % t)
	for biome in DataDB.floor_rules()["biomes"]:
		for e in biome["enemies"]:
			check(DataDB.enemies().has(e), "enemy %s exists" % e)
		check(DataDB.bosses().has(biome["boss"]), "boss %s exists" % biome["boss"])
	for id in DataDB.enemies():
		check(DataDB.sprites().has(DataDB.enemies()[id]["sprite"]), "sprite for %s" % id)
	for id in DataDB.bosses():
		check(DataDB.sprites().has(DataDB.bosses()[id]["sprite"]), "sprite for boss %s" % id)
	for set_id in DataDB.sets():
		check(DataDB.sets()[set_id]["pieces"].size() == DataDB.items()["slots"].size(), "set %s has all slots" % set_id)


func test_tower_generator() -> void:
	var a := TowerGen.generate(42, 137)
	var b := TowerGen.generate(42, 137)
	check(a == b, "floor generation is deterministic")
	check(TowerGen.generate(42, 10)["type"] == "guardian", "floor 10 is a guardian")
	check(TowerGen.generate(42, 25)["tier"] == "elite", "floor 25 is elite")
	check(TowerGen.generate(42, 100)["tier"] == "lord", "floor 100 is lord")
	var types := {}
	for f in range(1, 400):
		types[TowerGen.generate(7, f)["type"]] = true
	check(types.has("shrine") and types.has("vault"), "shrines and vaults appear")


func _fight(seed: int, floor_num: int) -> CombatEngine:
	var state := GameState.new_game(seed)
	var sim := Expedition.new(state)
	sim.floor_info = TowerGen.generate(seed, floor_num)
	state["floor"] = floor_num
	sim._start_combat()
	sim.combat.run_to_end()
	return sim.combat


func test_combat_determinism() -> void:
	var c1 := _fight(99, 4)
	var c2 := _fight(99, 4)
	check(c1.finished and c2.finished, "combat finishes")
	check(c1.victory == c2.victory and is_equal_approx(c1.time, c2.time), "combat is deterministic")
	check(_fight(99, 2).victory, "fresh founder beats floor 2")
	check(not _fight(99, 150).victory, "fresh party loses on floor 150")


func test_loot_and_inventory() -> void:
	var state := GameState.new_game(5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var counts := {}
	for i in 5000:
		var r := Loot.roll_rarity(rng, 50, "common", 0.0)
		counts[r] = counts.get(r, 0) + 1
	check(counts.get("common", 0) > counts.get("rare", 0), "commons outnumber rares")
	var chest_min_ok := true
	for i in 200:
		for d in Loot.boss_chest(rng, state, 25, "elite", 0.0, ""):
			if d.has("item") and DataDB.rarity_order(d["item"]["rarity"]) < DataDB.rarity_order("rare"):
				chest_min_ok = false
	check(chest_min_ok, "elite chest respects minimum rarity")
	var weapon := {}
	while weapon.is_empty() or weapon["class"] != "knight":
		weapon = Loot.generate_item(rng, state, 30, "epic")
	check(Inventory.best_hero_for(state, weapon) == 0, "knight weapon goes to the knight")
	check(Inventory.receive_item(state, weapon).begins_with("equipped"), "auto-equip upgrades")
	check(Inventory.receive_relic(state, "blood_crown"), "relic is new")
	check(not Inventory.receive_relic(state, "blood_crown"), "duplicate relic becomes crystals")
	check("blood_crown" in state["relics_equipped"], "relic auto-equipped")


func _run(seed: int, seconds: float, dt: float) -> Dictionary:
	var state := GameState.new_game(seed)
	var sim := Expedition.new(state)
	sim.record_combat_events = false
	var t := 0.0
	while t < seconds:
		sim.advance(dt)
		t += dt
		sim.events.clear()
	sim.sync_to_state()
	return state


func test_expedition_determinism() -> void:
	var a := _run(1234, 900.0, 5.0)
	var b := _run(1234, 900.0, 5.0)
	check(a["floor"] == b["floor"] and is_equal_approx(a["gold"], b["gold"]), "expedition deterministic")
	check(int(a["max_floor"]) > 8, "solo founder climbs past floor 8 in 15 min (got %d)" % a["max_floor"])
	var live := _run(1234, 900.0, 1.0 / 30.0)
	check(absi(int(live["max_floor"]) - int(a["max_floor"])) <= 10, "live stepping matches chunked stepping (%d vs %d)" % [live["max_floor"], a["max_floor"]])


func test_fall_back() -> void:
	var state := GameState.new_game(77)
	state["floor"] = 120
	state["max_floor"] = 120
	state["checkpoint"] = 111
	var sim := Expedition.new(state)
	sim.record_combat_events = false
	var fell := false
	for i in 600:
		sim.advance(1.0)
		for ev in sim.events:
			if ev["type"] == "fall_back":
				fell = true
				check(int(ev["to"]) == 111, "fall back returns to the last bonfire (got %d)" % ev["to"])
		sim.events.clear()
		if fell:
			break
	check(fell, "weak party falls back instead of game over")
	check(int(state["wall_floor"]) >= 120, "wall floor recorded")


func test_save_roundtrip() -> void:
	var state := _run(55, 300.0, 10.0)
	var path := "user://test_save.dat"
	check(SaveSystem.save_game(state, path), "save writes")
	var loaded := SaveSystem.load_game(path)
	check(not loaded.is_empty(), "save loads")
	check(int(loaded["floor"]) == int(state["floor"]) and is_equal_approx(float(loaded["gold"]), float(state["gold"])), "save roundtrip keeps data")
	check(str(loaded["rng_state"]) == str(state["rng_state"]), "rng state survives (64-bit safe)")
	var raw := FileAccess.get_file_as_bytes(path)
	check(not raw.get_string_from_ascii().contains("heroes"), "save file is encrypted")
	# Tamper: corrupt the main file, loader must fall back to the backup.
	SaveSystem.save_game(state, path)
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	f.seek(f.get_length() - 5)
	f.store_8(0x42)
	f.close()
	check(not SaveSystem.load_game(path).is_empty(), "tampered save falls back to .bak")
	SaveSystem.delete_save(path)


func test_offline_progress() -> void:
	var base := _run(321, 120.0, 10.0)
	var copy_a: Dictionary = base.duplicate(true)
	var copy_b: Dictionary = base.duplicate(true)
	var t0 := Time.get_ticks_msec()
	var rep_a := SaveSystem.simulate_offline(copy_a, 3.0 * 3600.0)
	var elapsed := Time.get_ticks_msec() - t0
	var rep_b := SaveSystem.simulate_offline(copy_b, 3.0 * 3600.0)
	check(copy_a["floor"] == copy_b["floor"] and is_equal_approx(copy_a["gold"], copy_b["gold"]), "offline progress deterministic")
	check(int(rep_a["max_floor_end"]) > int(rep_a["max_floor_start"]), "offline progress climbs")
	check(rep_a["extrapolated_seconds"] > 0.0, "long absence is extrapolated")
	check(elapsed < 15000, "3h offline computes quickly (%d ms)" % elapsed)
	print("  offline 3h: floor %d -> %d (max %d), %d kills, %d items, %d fall backs, %d ms" % [
		rep_a["floor_start"], rep_a["floor_end"], rep_a["max_floor_end"], rep_a["kills"], rep_a["items"], rep_a["fall_backs"], elapsed])
	var st := base.duplicate(true)
	st["saved_at"] = int(Time.get_unix_time_from_system()) + 1000
	check(SaveSystem.offline_seconds(st, int(Time.get_unix_time_from_system())) == 0.0, "clock rollback grants nothing")


func test_ascension() -> void:
	var state := GameState.new_game(8)
	check(not Progression.can_ascend(state), "cannot ascend at floor 1")
	state["max_floor"] = 120
	state["relics_owned"] = ["war_banner"]
	var souls := Progression.ascend(state)
	check(souls > 0 and int(state["souls"]) == souls, "ascension grants souls (%d)" % souls)
	check(int(state["floor"]) == 1 and state["relics_owned"].size() == 1, "ascension resets floor, keeps relics")
	check(Progression.buy_node(state, "might"), "can buy a tree node")
	check(not Progression.buy_node(state, "relic_vault"), "locked node cannot be bought")


func test_roster_and_skills() -> void:
	var state := GameState.new_game(11)
	check(state["heroes"].size() == 1 and state["heroes"][0]["class"] == "stairborn", "the Stairborn starts alone")
	check(not Heroes.can_mint(state), "minting costs gold")
	state["gold"] = 1e9
	var h1 := Heroes.mint(state)
	var h2 := Heroes.mint(state)
	var h3 := Heroes.mint(state)
	check(not h1.is_empty() and h1["class"] != "stairborn", "mint creates a hireable hero")
	check(state["heroes"].size() == 3 and state["bench"].size() == 1, "two extra slots, then the bench")
	check(h1["id"] != h2["id"] and h2["id"] != h3["id"], "hero ids are unique")
	check(Heroes.swap(state, 1, 0) and state["heroes"][1]["id"] == h3["id"], "bench swap")
	var hero: Dictionary = state["heroes"][0]
	hero["level"] = 6
	check(Heroes.skill_points_free(hero) == 5, "one skill point per level")
	check(not Heroes.learn_skill(hero, "fury"), "locked skill node")
	var before: float = StatCalc.hero_stats(state, hero)["hp"]
	for i in 3:
		Heroes.learn_skill(hero, "toughness")
	check(StatCalc.hero_stats(state, hero)["hp"] > before, "skills raise stats")
	check(not Heroes.learn_skill(hero, "plating"), "talent row 2 waits for its level gate")
	hero["level"] = 8
	check(Heroes.learn_skill(hero, "plating"), "prerequisite unlocks next node")
	check(Heroes.active_skills(hero).size() == 1, "one active skill at level 8")
	hero["level"] = 25
	check(Heroes.active_skills(hero).size() == 3, "three active skills at level 25")
	Heroes.toggle_active_skill(hero, Heroes.active_skills(hero)[1]["id"])
	check(Heroes.active_skills(hero).size() == 2, "a skill can be switched off")
	Heroes.auto_learn(hero)
	check(Heroes.skill_points_free(hero) == 0, "auto-learn spends every point")


func test_bonfire_and_market() -> void:
	check(TowerGen.generate(1, 21)["type"] == "bonfire", "floor 21 is a bonfire")
	check(TowerGen.bonfire_below(37) == 31, "checkpoint below 37 is 31")
	var state := GameState.new_game(12)
	state["max_floor"] = 30
	var now := 1_800_000_000
	Market.ensure_stock(state, now)
	var offers: Array = state["market"]["offers"]
	check(offers.size() >= 9, "market has stock (%d)" % offers.size())
	var copy := GameState.new_game(12)
	copy["max_floor"] = 30
	Market.ensure_stock(copy, now)
	check(str(copy["market"]["offers"][0]["item"]["name"]) == str(offers[0]["item"]["name"]), "market stock is deterministic")
	var hero_idx := -1
	for i in offers.size():
		if offers[i].has("hero"):
			hero_idx = i
	check(hero_idx >= 0, "market sells heroes")
	state["gold"] = 1e12
	check(Market.buy(state, hero_idx) and state["heroes"].size() == 2, "buying a hero adds it to the party")
	check(not Market.buy(state, hero_idx), "an offer sells once")
	check(not Market.ensure_stock(state, now + 60), "stock stays within a rotation")
	check(Market.ensure_stock(state, now + 3600), "stock rotates")


func test_variety_and_supplies() -> void:
	var bosses := {}
	var affixed := 0
	for f in range(10, 400, 10):
		var info := TowerGen.generate(3, f)
		for e in info["enemies"]:
			if DataDB.bosses().has(e):
				bosses[e] = true
	for f in range(100, 300):
		var info := TowerGen.generate(3, f)
		if not info.get("affixes", []).filter(func(a): return a != "").is_empty():
			affixed += 1
	check(bosses.size() >= 8, "many different bosses (%d)" % bosses.size())
	check(affixed > 20, "elite affixes appear (%d floors)" % affixed)
	var armored := TowerGen.enemy_stats("slime", 50, "", "armored")
	check(float(armored["defense"]) > float(TowerGen.enemy_stats("slime", 50)["defense"]), "armored affix raises defense")
	# Potions keep a hurt party alive and leave the bag afterwards.
	var state := GameState.new_game(21)
	state["consumables"] = {"health_potion": 3, "fire_bomb": 1}
	var sim := Expedition.new(state)
	sim.floor_info = TowerGen.generate(21, 10)
	state["floor"] = 10
	state["heroes"][0]["hp_ratio"] = 0.2
	sim._start_combat()
	sim.combat.run_to_end()
	check(sim.combat.consumed.get("potion", 0) >= 1, "auto-use drinks a potion when low")
	sim._end_combat()
	check(int(state["consumables"]["health_potion"]) < 3, "used potions leave the bag")


func test_forge() -> void:
	var state := GameState.new_game(77)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	state["inventory"] = []
	for i in 3:
		state["inventory"].append(Loot.generate_item(rng, state, 20, "rare"))
	state["gold"] = 1e9
	check(not Forge.quote(state, "rare")["ok"], "forge needs enough items (4 rares)")
	state["inventory"].append(Loot.generate_item(rng, state, 22, "rare"))
	var q := Forge.quote(state, "rare")
	check(q["ok"] and q["to"] == "epic" and int(q["ilvl"]) == 22, "forge quote: 4 rares -> epic at the best item level")
	var gold_before := float(state["gold"])
	var made := Forge.forge(state, "rare", "stairborn")
	check(made["rarity"] == "epic" and state["inventory"].size() == 1, "forge burns the inputs and makes one epic")
	check(float(state["gold"]) < gold_before, "forging costs gold (economy sink)")
	check(Loot.can_equip(made, "stairborn"), "forged item fits the chosen hero")


## Long run with no player input: how far does the idle loop get?
func balance_report() -> void:
	print("\n== Balance simulation (no ascension) ==")
	var state := GameState.new_game(2024)
	var sim := Expedition.new(state)
	sim.record_combat_events = false
	var t0 := Time.get_ticks_msec()
	for half_hour in 16:
		for i in 1800:
			sim.advance(1.0)
			sim.events.clear()
			# A light-touch player: recruits a hero whenever the gold allows.
			if i % 30 == 0 and state["heroes"].size() < 3 and Heroes.can_mint(state):
				Heroes.mint(state)
		var h: Array = state["heroes"]
		var mods := StatCalc.party_mods(state)
		print("t=%4.1fh floor %4d max %4d | party %d lvl %d | gold %.0f | train %d | falls %d | power %.0f" % [
			(half_hour + 1) * 0.5, state["floor"], state["max_floor"], h.size(), h[0]["level"],
			state["gold"], state["training"]["attack"], state["stats"]["fall_backs"],
			StatCalc.power_rating(StatCalc.hero_stats(state, h[0], mods))])
	print("souls available: %d  (%d ms)" % [Progression.souls_for_ascension(state), Time.get_ticks_msec() - t0])
