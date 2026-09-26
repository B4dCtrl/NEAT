extends RefCounted
## The climb itself: walk -> arrive -> (fight | shrine | vault | boss) -> next floor.
## advance(dt) consumes simulated seconds; the live game calls it every frame and
## the offline simulator calls it with hours at once. Both run the exact same code.
##
## High-level happenings are queued in `events` for the presentation layer.

const DataDB = preload("res://core/data_db.gd")
const TowerGen = preload("res://core/tower_generator.gd")
const CombatEngine = preload("res://core/combat_engine.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const Loot = preload("res://core/loot_calculator.gd")
const Inventory = preload("res://core/inventory.gd")
const Progression = preload("res://core/progression.gd")
const GameState = preload("res://core/game_state.gd")
const Heroes = preload("res://core/heroes.gd")

var state: Dictionary
var rng := RandomNumberGenerator.new()
var phase := "walk"          # walk | intro | combat | pause | camp
var phase_left := 0.0
var phase_total := 1.0
var after_pause := ""        # next_floor | walk
var floor_info := {}
var combat = null            # CombatEngine while fighting
var tick_acc := 0.0
var record_combat_events := true
var events: Array = []
## The last Fall Back, for the tumble-down animation: {from, to}.
var last_fall := {}
## Damage per hero over the last finished fight, for the DPS panel.
var last_fight := {"time": 0.0, "damage": {}}
## The player pressed "Rest at bonfire": retreat after the current fight.
var retreat_requested := false


func _init(state_: Dictionary) -> void:
	state = state_
	rng.seed = int(state["seed"])
	var saved := str(state.get("rng_state", ""))
	if saved != "" and saved != "0":
		rng.state = saved.to_int()
	_begin_walk()


## Persists the RNG position into the state (call before saving).
func sync_to_state() -> void:
	state["rng_state"] = str(rng.state)


func walk_progress() -> float:
	return 1.0 - phase_left / maxf(phase_total, 0.001) if phase == "walk" else 0.0


func advance(dt: float) -> void:
	var budget := dt
	var guard := 0
	while budget > 1e-6 and guard < 1000000:
		guard += 1
		if phase == "combat":
			tick_acc += budget
			budget = 0.0
			while tick_acc >= CombatEngine.TICK and not combat.finished:
				combat.step()
				tick_acc -= CombatEngine.TICK
			if combat.finished:
				budget = tick_acc
				tick_acc = 0.0
				_end_combat()
		elif phase == "camp":
			# Camping at a bonfire: time passes, the party waits for the player.
			budget = 0.0
		else:
			var used := minf(budget, phase_left)
			phase_left -= used
			budget -= used
			if phase_left <= 1e-6:
				_phase_done()


func _phase_done() -> void:
	match phase:
		"walk":
			_arrive_floor()
		"intro":
			_start_combat()
		"pause":
			if after_pause == "next_floor":
				_next_floor()
			else:
				_begin_walk()


func _set_phase(p: String, duration: float) -> void:
	phase = p
	phase_left = duration
	phase_total = maxf(duration, 0.001)


func _begin_walk() -> void:
	var mods := StatCalc.party_mods(state)
	var travel := float(DataDB.balance()["travel_time"]) / (1.0 + float(mods.get("move_speed_pct", 0.0)))
	combat = null
	_set_phase("walk", travel)


func _arrive_floor() -> void:
	var bal := DataDB.balance()
	floor_info = TowerGen.generate(int(state["seed"]), int(state["floor"]))
	events.append({"type": "floor", "floor": state["floor"], "info": floor_info})
	match floor_info["type"]:
		"guardian":
			var boss_def := DataDB.unit_def(floor_info["enemies"][0])
			events.append({"type": "boss", "floor": state["floor"], "name": boss_def["name"], "tier": floor_info["tier"]})
			_set_phase("intro", float(bal["boss_intro_time"]))
		"shrine":
			_use_shrine(floor_info["shrine"])
			after_pause = "next_floor"
			_set_phase("pause", float(bal["event_pause"]))
		"vault":
			_open_vault()
			after_pause = "next_floor"
			_set_phase("pause", float(bal["event_pause"]))
		"bonfire":
			_rest_at_bonfire()
		_:
			_start_combat()


func _start_combat() -> void:
	var bal := DataDB.balance()
	var mods := StatCalc.party_mods(state)
	var classes := DataDB.classes()
	var hero_entries := []
	for i in state["heroes"].size():
		var hero: Dictionary = state["heroes"][i]
		hero_entries.append({
			"index": i,
			"class_id": hero["class"],
			"class_def": classes[hero["class"]],
			"name": hero["name"],
			"stats": StatCalc.hero_stats(state, hero, mods),
			"hp_ratio": maxf(float(hero["hp_ratio"]), 0.05),
			"mp_ratio": float(hero.get("mp_ratio", 1.0)),
			"row": hero["row"],
			"skills": Heroes.active_skills(hero),
		})
	var enemy_entries := []
	var affixes: Array = floor_info.get("affixes", [])
	for i in floor_info["enemies"].size():
		var enemy_id: String = floor_info["enemies"][i]
		var is_boss := DataDB.bosses().has(enemy_id)
		var affix: String = affixes[i] if i < affixes.size() else ""
		enemy_entries.append({
			"id": enemy_id,
			"def": DataDB.unit_def(enemy_id),
			"stats": TowerGen.enemy_stats(enemy_id, int(state["floor"]), floor_info["tier"] if is_boss else "", affix),
			"is_boss": is_boss,
		})
	combat = CombatEngine.new()
	var limit: float = float(bal["boss_time_limit"]) if floor_info["type"] == "guardian" else float(bal["combat_time_limit"])
	var floor_num := int(state["floor"])
	var supplies: Dictionary = state.get("consumables", {})
	combat.setup(hero_entries, enemy_entries, rng, {
		"time_limit": limit,
		"record_events": record_combat_events,
		"party_specials": mods.get("specials", []),
		"summon_factory": func(unit_id: String) -> Dictionary:
			return {"id": unit_id, "def": DataDB.unit_def(unit_id), "stats": TowerGen.enemy_stats(unit_id, floor_num), "is_boss": false},
		"supplies": {"potion": int(supplies.get("health_potion", 0)), "bomb": int(supplies.get("fire_bomb", 0)), "mana": int(supplies.get("mana_potion", 0))},
		"auto_supplies": state["settings"].get("auto_supplies", true),
	})
	tick_acc = 0.0
	phase = "combat"
	events.append({"type": "combat_start", "floor": state["floor"]})


func _end_combat() -> void:
	var bal := DataDB.balance()
	var stats: Dictionary = state["stats"]
	var fight_damage := {}
	for u in combat.heroes:
		if u.index >= state["heroes"].size():
			continue
		var hero: Dictionary = state["heroes"][u.index]
		hero["hp_ratio"] = u.hp_ratio() if u.alive else 0.0
		hero["mp_ratio"] = u.mp_ratio()
		fight_damage[hero["id"]] = u.damage_dealt
		stats["damage_by_hero"][hero["id"]] = float(stats["damage_by_hero"].get(hero["id"], 0.0)) + u.damage_dealt
	last_fight = {"time": combat.time, "damage": fight_damage}
	# Potions and bombs used during the fight come out of the bag.
	var used: Dictionary = combat.consumed
	for key in used:
		var id: String = {"potion": "health_potion", "bomb": "fire_bomb", "mana": "mana_potion"}.get(key, key)
		var bag: Dictionary = state["consumables"]
		bag[id] = maxi(0, int(bag.get(id, 0)) - int(used[key]))
	combat.consumed = {}
	events.append({"type": "combat_end", "victory": combat.victory, "floor": state["floor"]})

	if not combat.victory:
		stats["fights_lost"] += 1
		_fall_back()
		return

	stats["fights_won"] += 1
	var mods := StatCalc.party_mods(state)
	var gold := 0.0
	var xp := 0.0
	var set_bias := ""
	for u in combat.enemies:
		gold += u.gold
		xp += u.xp
		stats["kills"] += 1
		var entry: Dictionary = state["bestiary"].get(u.def_id, {"kills": 0, "first_floor": state["floor"]})
		entry["kills"] = int(entry["kills"]) + 1
		state["bestiary"][u.def_id] = entry
		if u.is_boss:
			set_bias = DataDB.unit_def(u.def_id).get("set_bias", "")
	gold *= 1.0 + float(mods.get("gold_pct", 0.0))
	xp *= 1.0 + float(mods.get("xp_pct", 0.0))
	_add_gold(gold)
	for hero_name in Progression.grant_xp(state, xp):
		events.append({"type": "level_up", "name": hero_name})
	if state["settings"].get("auto_skills", true):
		for hero in state["heroes"]:
			Heroes.auto_learn(hero)
	# Fallen heroes get back up once the floor is won.
	for hero in state["heroes"]:
		hero["hp_ratio"] = maxf(float(hero["hp_ratio"]), 0.1)

	var drop_bonus := float(mods.get("drop_pct", 0.0))
	var drops: Array
	if floor_info["type"] == "guardian":
		stats["bosses"] += 1
		var boss_name: String = DataDB.unit_def(floor_info["enemies"][0])["name"]
		GameState.add_history(state, "boss", "Defeated %s on floor %d" % [boss_name, state["floor"]])
		drops = Loot.boss_chest(rng, state, int(state["floor"]), floor_info["tier"], drop_bonus, set_bias)
		events.append({"type": "chest", "floor": state["floor"], "tier": floor_info["tier"]})
		after_pause = "next_floor"
		_set_phase("pause", float(bal["chest_pause"]))
	else:
		drops = Loot.enemy_drops(rng, state, int(state["floor"]), combat.enemies.size(), drop_bonus)
		after_pause = "next_floor"
		_set_phase("pause", 0.4)
	for d in drops:
		_grant_drop(d)
	# Auto-bonfire: too hurt to go on (and no bonfire right ahead) -> go rest.
	if _should_retreat() and not TowerGen.is_bonfire(int(state["floor"]) + 1):
		retreat_requested = false
		retreat_to_bonfire()


## Wiped out: the party wakes up at the last bonfire, fully healed.
func _fall_back() -> void:
	var bal := DataDB.balance()
	var from := int(state["floor"])
	var to := mini(int(state.get("checkpoint", 1)), from)
	if to == from:
		to = maxi(1, TowerGen.bonfire_below(from - 1))
	state["floor"] = to
	if int(state["wall_floor"]) == from:
		state["wall_attempts"] = int(state["wall_attempts"]) + 1
	else:
		state["wall_floor"] = from
		state["wall_attempts"] = 1
	state["stats"]["fall_backs"] += 1
	restore_party()
	# Dying hurts: the party drops part of its gold on the stairs. Retreating
	# to the bonfire in time (auto-bonfire) keeps it.
	var lost := floorf(float(state["gold"]) * float(bal.get("fall_gold_loss", 0.0)))
	state["gold"] = float(state["gold"]) - lost
	last_fall = {"from": from, "to": to, "gold_lost": lost}
	GameState.add_history(state, "fall", "Fell from floor %d back to the bonfire on %d (lost %d gold)" % [from, to, int(lost)])
	events.append({"type": "fall_back", "from": from, "to": to, "gold_lost": lost})
	after_pause = "walk"
	_set_phase("pause", float(bal["fallback_pause"]))


## Bonfire: rest (full heal), tidy up gear, learn skills, set the checkpoint.
func _rest_at_bonfire() -> void:
	var bal := DataDB.balance()
	var f := int(state["floor"])
	state["checkpoint"] = f
	restore_party()
	if state["settings"].get("auto_equip", true):
		for item in state["inventory"].duplicate():
			var idx := Inventory.best_hero_for(state, item)
			if idx >= 0:
				Inventory.equip(state, idx, item)
	if state["settings"].get("auto_skills", true):
		for hero in state["heroes"]:
			Heroes.auto_learn(hero)
	events.append({"type": "bonfire", "floor": f})
	after_pause = "next_floor"
	if state["settings"].get("camp_at_bonfire", false):
		GameState.add_history(state, "info", "Camping at the bonfire on floor %d" % f)
		phase = "camp"
		phase_left = 0.0
		phase_total = 1.0
	else:
		_set_phase("pause", float(bal["bonfire_rest"]))


## Bonfire rest: HP and mana back to full.
func restore_party() -> void:
	for hero in state["heroes"]:
		hero["hp_ratio"] = 1.0
		hero["mp_ratio"] = 1.0


## Average HP share of the party (fallen heroes count as 0).
func party_hp() -> float:
	if state["heroes"].is_empty():
		return 1.0
	var total := 0.0
	for hero in state["heroes"]:
		total += float(hero["hp_ratio"])
	return total / state["heroes"].size()


## Walks back to the last bonfire to rest: full HP and mana, no gold lost,
## but the floors since the bonfire must be climbed again.
func retreat_to_bonfire() -> void:
	retreat_requested = false
	var to := int(state.get("checkpoint", 1))
	var from := int(state["floor"])
	state["floor"] = to
	restore_party()
	state["stats"]["retreats"] = int(state["stats"].get("retreats", 0)) + 1
	last_fall = {"from": from, "to": to, "retreat": true}
	GameState.add_history(state, "info", "Retreated from floor %d to rest at the bonfire on %d" % [from, to])
	events.append({"type": "retreat", "from": from, "to": to})
	combat = null
	after_pause = "next_floor"
	_set_phase("pause", float(DataDB.balance()["fallback_pause"]))


## Auto-bonfire: after a won fight, retreat when the party is too hurt to go on.
func _should_retreat() -> bool:
	if retreat_requested:
		return true
	if not state["settings"].get("auto_bonfire", true):
		return false
	if int(state["floor"]) <= int(state.get("checkpoint", 1)):
		return false
	return party_hp() < float(state["settings"].get("retreat_hp", 0.35))


func is_camping() -> bool:
	return phase == "camp"


func leave_camp() -> void:
	if phase == "camp":
		state["settings"]["camp_at_bonfire"] = false
		_next_floor()


func _next_floor() -> void:
	var bal := DataDB.balance()
	state["floor"] = int(state["floor"]) + 1
	state["stats"]["floors_climbed"] += 1
	state["floors_cleared_total"] = int(state["floors_cleared_total"]) + 1
	if int(state["floor"]) > int(state["max_floor"]):
		state["max_floor"] = state["floor"]
	if int(state["floor"]) > int(state["best_floor_ever"]):
		state["best_floor_ever"] = state["floor"]
		_check_milestones()
	if int(state["floor"]) > int(state["wall_floor"]) and int(state["wall_floor"]) > 0:
		events.append({"type": "wall_broken", "floor": state["wall_floor"]})
		state["wall_floor"] = 0
		state["wall_attempts"] = 0

	var kept := []
	for buff in state["buffs"]:
		buff["floors_left"] = int(buff["floors_left"]) - 1
		if int(buff["floors_left"]) > 0:
			kept.append(buff)
	state["buffs"] = kept

	# Wounds carry over between floors: only bonfires (and potions / healing
	# skills) restore HP. heal_per_floor is 0 by default.
	var heal := float(bal["heal_per_floor"])
	if heal > 0.0:
		for hero in state["heroes"]:
			hero["hp_ratio"] = minf(1.0, float(hero["hp_ratio"]) + heal)

	if state["settings"].get("auto_train", true):
		Progression.auto_train(state, Heroes.gold_reserve(state))

	var mods := StatCalc.party_mods(state)
	var interval := int(bal["merchants_eye_interval"])
	if "merchants_eye" in mods.get("specials", []) and int(state["floors_cleared_total"]) % interval == 0:
		var rarity := Loot.roll_rarity(rng, int(state["floor"]), "rare", float(mods.get("drop_pct", 0.0)), false)
		_grant_drop({"item": Loot.generate_item(rng, state, int(state["floor"]), rarity)})
	_begin_walk()


func _use_shrine(shrine: Dictionary) -> void:
	events.append({"type": "shrine", "name": shrine["name"], "text": shrine["text"]})
	if shrine.has("trade_gold_pct"):
		var cost := float(state["gold"]) * float(shrine["trade_gold_pct"])
		if cost >= 1.0:
			state["gold"] -= cost
			var mods := StatCalc.party_mods(state)
			var rarity := Loot.roll_rarity(rng, int(state["floor"]), shrine["trade_min_rarity"], float(mods.get("drop_pct", 0.0)), false)
			_grant_drop({"item": Loot.generate_item(rng, state, int(state["floor"]), rarity)})
		return
	state["buffs"].append({"id": shrine["id"], "name": shrine["name"], "stats": shrine["stats"], "floors_left": int(shrine["floors"])})


func _open_vault() -> void:
	var bal := DataDB.balance()
	var mods := StatCalc.party_mods(state)
	var floor_num := int(state["floor"])
	events.append({"type": "vault", "floor": floor_num})
	var gold := float(bal["vault_gold_mult"]) * 4.0 * pow(float(DataDB.enemy_scaling()["gold_growth"]), floor_num - 1)
	_add_gold(gold * (1.0 + float(mods.get("gold_pct", 0.0))))
	for i in int(bal["vault_items"]):
		_grant_drop(Loot.roll_drop(rng, state, floor_num, "uncommon", float(mods.get("drop_pct", 0.0))))


func _grant_drop(drop: Dictionary) -> void:
	if drop.has("item"):
		var item: Dictionary = drop["item"]
		state["stats"]["items_found"] += 1
		var result := Inventory.receive_item(state, item)
		if DataDB.rarity_order(item["rarity"]) >= DataDB.rarity_order("legendary") or item.get("set", "") != "":
			GameState.add_history(state, "loot", "Found %s [%s]" % [item["name"], DataDB.rarities()[item["rarity"]]["name"]])
		events.append({"type": "loot", "item": item, "result": result})
	elif drop.has("relic"):
		var relic_id: String = drop["relic"]
		var is_new := Inventory.receive_relic(state, relic_id)
		if is_new:
			state["stats"]["relics_found"] += 1
			var relic_name: String = DataDB.relics()[relic_id]["name"]
			GameState.add_history(state, "relic", "RELIC found: %s" % relic_name)
		events.append({"type": "relic", "id": relic_id, "new": is_new})
	elif drop.has("consumable"):
		var cid: String = drop["consumable"]
		state["consumables"][cid] = int(state["consumables"].get(cid, 0)) + 1
		events.append({"type": "consumable", "id": cid})
	elif drop.has("crystals"):
		state["crystals"] = int(state["crystals"]) + int(drop["crystals"])
		events.append({"type": "crystals", "amount": int(drop["crystals"])})


func _add_gold(amount: float) -> void:
	state["gold"] = float(state["gold"]) + amount
	state["stats"]["total_gold"] = float(state["stats"]["total_gold"]) + amount


func _check_milestones() -> void:
	for m in DataDB.floor_rules()["milestones"]:
		var f := int(m["floor"])
		if int(state["best_floor_ever"]) >= f and not f in state["milestones"]:
			state["milestones"].append(f)
			state["crystals"] = int(state["crystals"]) + int(m["crystals"])
			GameState.add_history(state, "milestone", "Milestone: %s (floor %d)" % [m["name"], f])
			events.append({"type": "milestone", "name": m["name"], "achievement": m["achievement"], "crystals": int(m["crystals"])})
