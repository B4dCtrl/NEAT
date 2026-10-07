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
const Danger = preload("res://core/danger.gd")

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
	test_mana_bonfire_danger()
	test_accounts()
	test_quests_and_languages()
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
	check(Inventory.receive_item(state, weapon) == "stored", "drops are never auto-equipped")
	check(state["heroes"][0]["equipment"]["weapon"]["uid"] != weapon["uid"], "the old weapon stays until the player swaps it")
	Inventory.equip(state, 0, weapon)
	check(weapon.get("bound", false), "equipping binds the item")
	# Economy cap: a Legendary blocks the next Legendary for a while.
	state["floors_cleared_total"] = 100
	check(Loot.apply_cap(state, "legendary") == "legendary", "first legendary drops")
	check(Loot.apply_cap(state, "legendary") == "epic", "the next one is capped down to epic")
	state["floors_cleared_total"] = 200
	check(Loot.apply_cap(state, "legendary") == "legendary", "the cap wears off with floors")
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
	state["best_floor_ever"] = 9999
	check(int(Heroes.mint_cost(state)) == 120, "2nd hero costs 120")
	var h1 := Heroes.mint(state)
	check(int(Heroes.mint_cost(state)) == 400, "3rd hero costs 400")
	var h2 := Heroes.mint(state)
	check(int(Heroes.mint_cost(state)) == 520, "4th hero costs 520")
	var h3 := Heroes.mint(state)
	check(int(Heroes.mint_cost(state)) == 650, "5th hero costs 650")
	check(int(Heroes.hire_price(state)) > 650, "buying a known hero costs more than minting")
	state["best_floor_ever"] = 10
	check(Heroes.mint_blocker(state) != "" and Heroes.mint_floor_required(state) == 50, "5th hero needs floor 50")
	state["best_floor_ever"] = 9999
	check(not h1.is_empty() and h1["class"] != "stairborn", "mint creates a hireable hero")
	check(state["heroes"].size() == 3 and state["bench"].size() == 1, "two extra slots, then the bench")
	check(h1["id"] != h2["id"] and h2["id"] != h3["id"], "hero ids are unique")
	check(Heroes.swap(state, 1, 0) and state["heroes"][1]["id"] == h3["id"], "bench swap")
	var hero: Dictionary = state["heroes"][0]
	hero["level"] = 6
	check(Heroes.skill_points_free(hero) == 5, "one skill point per level")
	check(not Heroes.learn_skill(hero, "sb_cleaver"), "Stair Cleaver needs Stair Mastery 3")
	check(not Heroes.learn_skill(hero, "kn_bash"), "a Knight skill is not in the Stairborn tree")
	var before: float = StatCalc.hero_stats(state, hero)["hp"]
	for i in 3:
		Heroes.learn_skill(hero, "sb_endurance")
	check(StatCalc.hero_stats(state, hero)["hp"] > before, "passives raise stats")
	check(Heroes.active_skills(hero).is_empty(), "no active skill until one is learned")
	check(Heroes.learn_skill(hero, "sb_second_wind"), "an active skill costs a point")
	check(Heroes.active_skills(hero).size() == 1 and int(Heroes.active_skills(hero)[0]["rank"]) == 1, "learned skills are auto-cast at their level")
	Heroes.learn_skill(hero, "sb_second_wind")
	check(float(Heroes.active_skills(hero)[0]["value"]) > 0.15, "a higher skill level is stronger")
	Heroes.toggle_active_skill(hero, "sb_second_wind")
	check(Heroes.active_skills(hero).is_empty(), "auto-cast can be switched off")
	Heroes.toggle_active_skill(hero, "sb_second_wind")
	hero["level"] = 40
	Heroes.auto_learn(hero)
	check(Heroes.skill_points_free(hero) == 0, "auto-learn spends every point")
	check(Heroes.skill_rank(hero, "sb_cleaver") > 0, "auto-learn reaches the deeper skills")
	# Tibia: 100 XP for level 2, 50 (L^2 - 3L + 4) per level after.
	check(is_equal_approx(Progression.xp_to_next(1), 100.0) and is_equal_approx(Progression.xp_to_next(8), 2200.0), "Tibia experience curve")
	check(is_equal_approx(Progression.xp_total(8), 4200.0), "Tibia total XP for level 8")


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
	var helm := func(b): return b["slot"] == "helm"
	for i in 3:
		state["inventory"].append(Loot.generate_item(rng, state, 20, "rare", "", helm))
	# A rare boot does not count towards the helm group.
	state["inventory"].append(Loot.generate_item(rng, state, 20, "rare", "", func(b): return b["slot"] == "boots"))
	state["gold"] = 1e9
	check(not Forge.quote(state, "rare", "helm/")["ok"], "merge needs 4 items of the same kind")
	state["inventory"].append(Loot.generate_item(rng, state, 22, "rare", "", helm))
	var q := Forge.quote(state, "rare", "helm/")
	check(q["ok"] and q["to"] == "epic" and int(q["ilvl"]) == 22, "merge quote: 4 rare helms -> 1 epic at the best item level")
	var gold_before := float(state["gold"])
	var made := Forge.merge(state, "rare", "helm/")
	check(made["rarity"] == "epic" and made["slot"] == "helm", "merge makes one epic of the same kind")
	check(state["inventory"].size() == 2, "the 4 helms are gone, the boot stays")
	check(float(state["gold"]) < gold_before, "merging costs gold (economy sink)")
	check(Forge.groups(state).size() >= 1, "merge groups are listed")


func test_mana_bonfire_danger() -> void:
	var state := GameState.new_game(31)
	state["heroes"][0]["level"] = 12
	var sim := Expedition.new(state)
	sim.floor_info = TowerGen.generate(31, 6)
	state["floor"] = 6
	sim._start_combat()
	var u = sim.combat.heroes[0]
	check(u.max_mana > 0.0, "heroes have mana")
	u.mana = 0.0
	u.hp = u.max_hp * 0.3
	for i in 5:
		sim.combat.step()
	check(u.mana < 20.0, "no mana, no Second Wind (needs 30)")
	sim.combat.run_to_end()
	sim._end_combat()
	check(float(state["heroes"][0]["mp_ratio"]) < 1.0, "mana carries over after a fight")
	# Retreat: back to the checkpoint, fully rested, gold kept.
	state["checkpoint"] = 1
	state["floor"] = 7
	state["gold"] = 1000.0
	state["heroes"][0]["hp_ratio"] = 0.2
	sim.retreat_to_bonfire()
	check(int(state["floor"]) == 1 and float(state["heroes"][0]["hp_ratio"]) == 1.0 and float(state["heroes"][0]["mp_ratio"]) == 1.0, "retreat rests at the bonfire")
	check(float(state["gold"]) == 1000.0, "retreating keeps the gold")
	state["floor"] = 7
	sim._fall_back()
	check(float(state["gold"]) < 1000.0, "falling drops gold")
	var fresh := GameState.new_game(31)
	check(int(Danger.assess(fresh, 150)["level"]) == 3, "floor 150 is Deadly for a new party")
	check(int(Danger.assess(fresh, 2)["level"]) <= 1, "floor 2 is Easy or Fair for a new party")

func test_accounts() -> void:
	var Accounts = load("res://core/accounts.gd")
	var a := "zz_test_alice"
	var b := "zz_test_bob"
	Accounts.delete_account(a)
	Accounts.delete_account(b)
	check(Accounts.register("ab", "secret1") == "name_length", "names need 3+ characters")
	check(Accounts.register("bad name!", "secret1") == "name_chars", "names are letters, numbers and _")
	check(Accounts.register(a, "123") == "password_length", "passwords need 6+ characters")
	check(Accounts.register(a, "alice-pass") == "", "account created")
	check(Accounts.register(a.to_upper(), "other-pass") == "name_taken", "names are unique, case-insensitive")
	check(Accounts.verify(a, "alice-pass") and not Accounts.verify(a, "wrong-pass"), "password check")
	var reg_text := FileAccess.get_file_as_string("user://accounts.json")
	check(not reg_text.contains("alice-pass"), "the password itself is never stored")
	Accounts.register(b, "bob-pass-1")
	# Each account has its own save, locked with its own password-derived key.
	var sa := GameState.new_game(1)
	sa["floor"] = 42
	check(SaveSystem.save_game(sa, Accounts.save_path(a), Accounts.save_key(a, "alice-pass")), "alice's save written")
	check(int(SaveSystem.load_game(Accounts.save_path(a), Accounts.save_key(a, "alice-pass"))["floor"]) == 42, "alice loads her own save")
	check(SaveSystem.load_game(Accounts.save_path(b), Accounts.save_key(b, "bob-pass-1")).is_empty(), "bob starts from zero")
	check(SaveSystem.load_game(Accounts.save_path(a), Accounts.save_key(a, "wrong-pass")).is_empty(), "a wrong key cannot open alice's save")
	Accounts.remember(a, Accounts.save_key(a, "alice-pass"))
	check(Accounts.remembered().get("user", "") == a, "remember me")
	Accounts.forget()
	check(Accounts.remembered().is_empty(), "forget on logout")
	Accounts.delete_account(a)
	Accounts.delete_account(b)
	check(not Accounts.exists(a), "account deleted")
	# Steam identity: no password, and a typed name can never impersonate it.
	var Platform = load("res://core/platform_services.gd")
	check(Platform.steam_user().is_empty(), "no Steam user outside Steam")
	Platform._fake_user = {"id": "76561190000000001", "name": "SteamPlayer"}
	var su: Dictionary = Platform.steam_user()
	var skey: String = Accounts.external_login("steam", su["id"], su["name"])
	check(skey.begins_with("@steam:") and Accounts.exists(skey), "steam account created on first launch")
	check(Accounts.check_name(skey) != "", "a typed name cannot be a steam key")
	check(not Accounts.verify(skey, ""), "steam accounts have no password login")
	var k1: String = Accounts.external_save_key("steam", su["id"])
	check(k1 == Accounts.external_save_key("steam", su["id"]) and k1 != Accounts.external_save_key("steam", "76561190000000002"), "same Steam id, same save key on every PC")
	var steam_state := GameState.new_game(3)
	steam_state["floor"] = 17
	check(SaveSystem.save_game(steam_state, Accounts.save_path(skey), k1), "steam save written")
	check(int(SaveSystem.load_game(Accounts.save_path(skey), k1)["floor"]) == 17, "steam save loads")
	Accounts.delete_account(skey)
	Platform._fake_user = {}
	check(Expedition.walk_time(1) < Expedition.walk_time(30) and Expedition.walk_time(30) < Expedition.walk_time(60), "the first floors are quicker")
	check(is_equal_approx(Expedition.walk_time(500), float(DataDB.balance()["travel_time"])), "late floors use the full pace")


func test_quests_and_languages() -> void:
	var Quests = load("res://core/quests.gd")
	var Loc = load("res://core/loc.gd")
	var state := GameState.new_game(9)
	Quests.ensure(state)
	check(state["contracts"].size() == 3, "three contracts at a time")
	var ids: Array = state["contracts"].map(func(c): return c["id"])
	check(ids.size() == ids.duplicate().filter(func(i): return ids.count(i) == 1).size(), "the three contracts are different")
	var c: Dictionary = state["contracts"][0]
	check(not Quests.is_done(state, c), "a fresh contract is not done")
	check(Quests.claim(state, 0).is_empty(), "cannot claim an unfinished contract")
	state["stats"][c["stat"]] = float(state["stats"].get(c["stat"], 0)) + float(c["target"])
	check(Quests.is_done(state, c), "progress follows the stat")
	var before := str(c)
	var got: Dictionary = Quests.claim(state, 0)
	check(not got.is_empty() and str(state["contracts"][0]) != before, "claiming pays out and renews the contract")
	# Daily streak: consecutive days grow, a missed day resets.
	check(Quests.daily_status(state, "2026-05-01")["claimable"], "daily reward is claimable")
	check(not Quests.claim_daily(state, "2026-05-01").is_empty(), "day 1 claimed")
	check(Quests.claim_daily(state, "2026-05-01").is_empty(), "only once a day")
	Quests.claim_daily(state, "2026-05-02")
	check(int(state["daily_streak"]) == 2, "consecutive days build a streak")
	Quests.claim_daily(state, "2026-05-05")
	check(int(state["daily_streak"]) == 1, "a missed day resets the streak")
	# Warp Stone jumps to the highest bonfire reached.
	state["max_floor"] = 47
	state["floor"] = 3
	var sim := Expedition.new(state)
	check(sim.warp_target() == 41, "warp target is the highest bonfire (41)")
	sim.warp_to(41)
	check(int(state["floor"]) == 41 and int(state["checkpoint"]) == 41, "warp moves the party and the checkpoint")
	# Language packs: every language covers the English keys, and falls back safely.
	for code in Loc.LANGUAGES:
		check(Loc.coverage(code) >= 0.99, "language pack %s is complete (%.0f%%)" % [code, Loc.coverage(code) * 100.0])
	Loc.lang = "pt"
	check(Loc.t("panel.inventory") == "INVENTÁRIO", "Portuguese pack")
	Loc.lang = "es"
	check(Loc.t("panel.quests") == "MISIONES", "Spanish pack")
	check(Loc.t("does.not.exist") == "does.not.exist", "unknown key falls back to itself")
	# Data texts (names, descriptions, set bonuses) follow the language too.
	for code in ["pt", "es"]:
		Loc.lang = code
		DataDB.reload_language()
		check(DataDB.classes()["knight"]["name"] != "Knight", "%s: class names translated" % code)
		check(DataDB.items()["bases"][0]["name"] != "Iron Sword", "%s: item names translated" % code)
		check(DataDB.items()["bases"][0]["name_en"] == "Iron Sword", "%s: English name is kept" % code)
		check(DataDB.rarities()["epic"]["name"] != "Epic", "%s: rarity names translated" % code)
		var bonus_text: String = DataDB.sets()["frostbound"]["bonuses"]["2"]["text"]
		check(bonus_text != "" and not "Defense" in bonus_text, "%s: set bonus text composed in the language (%s)" % [code, bonus_text])
		var gem_item := {"base": "iron_sword", "name": "Iron Sword of Fury", "suffix_en": "of Fury"}
		DataDB.localize_item(gem_item)
		check(not "Iron Sword" in gem_item["name"] and not "of Fury" in gem_item["name"], "%s: item name relocalized (%s)" % [code, gem_item["name"]])
	Loc.lang = "en"
	DataDB.reload_language()
	check(DataDB.classes()["knight"]["name"] == "Knight", "English restored")


## Long run with no player input: how far does the idle loop get?
func balance_report() -> void:
	print("\n== Balance simulation (no ascension) ==")
	var state := GameState.new_game(2024)
	var sim := Expedition.new(state)
	sim.record_combat_events = false
	var t0 := Time.get_ticks_msec()
	# Checkpoints in minutes: dense at the start (the Steam refund window is 2 h).
	var checkpoints := [5, 10, 20, 30, 45, 60, 90, 120, 180, 240, 300, 360, 420, 480]
	var elapsed := 0
	for minute in checkpoints:
		var seconds: int = (minute - elapsed) * 60
		elapsed = minute
		for i in seconds:
			sim.advance(1.0)
			sim.events.clear()
			# A light-touch player: recruits a hero whenever the gold allows.
			if i % 30 == 0 and state["heroes"].size() < 3 and Heroes.can_mint(state):
				Heroes.mint(state)
			# ... and equips the best item for each hero every 5 minutes (gear is manual now).
			if i % 300 == 299:
				for item in state["inventory"].duplicate():
					var idx := Inventory.best_hero_for(state, item)
					if idx >= 0:
						Inventory.equip(state, idx, item)
		var h: Array = state["heroes"]
		var mods := StatCalc.party_mods(state)
		print("t=%4dm floor %4d max %4d | party %d lvl %d | gold %.0f | train %d | falls %d | power %.0f" % [
			minute, state["floor"], state["max_floor"], h.size(), h[0]["level"],
			state["gold"], state["training"]["attack"], state["stats"]["fall_backs"],
			StatCalc.power_rating(StatCalc.hero_stats(state, h[0], mods))])
	print("souls available: %d  (%d ms)" % [Progression.souls_for_ascension(state), Time.get_ticks_msec() - t0])
