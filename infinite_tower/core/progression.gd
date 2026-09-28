extends RefCounted
## Hero levels, gold training and the Ascension (prestige) loop.

const DataDB = preload("res://core/data_db.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const GameState = preload("res://core/game_state.gd")
const Heroes = preload("res://core/heroes.gd")


## Tibia's experience curve: reaching level L takes 50/3 (L³ - 6L² + 17L - 12)
## XP in total, so one level costs 50 (L² - 3L + 4) (100 XP at level 1-2,
## 2 200 at level 8, 485 200 at level 100).
static func xp_total(level: int) -> float:
	var l := float(level)
	return 50.0 / 3.0 * (l * l * l - 6.0 * l * l + 17.0 * l - 12.0)


static func xp_to_next(level: int) -> float:
	var l := float(level)
	return 50.0 * (l * l - 3.0 * l + 4.0)


## Adds XP to every hero; returns the names of heroes that levelled up.
static func grant_xp(state: Dictionary, amount: float) -> Array:
	var ups := []
	var max_level := int(DataDB.balance()["max_level"])
	for hero in state["heroes"]:
		if int(hero["level"]) >= max_level:
			continue
		hero["xp"] = float(hero["xp"]) + amount
		while int(hero["level"]) < max_level and float(hero["xp"]) >= xp_to_next(int(hero["level"])):
			hero["xp"] = float(hero["xp"]) - xp_to_next(int(hero["level"]))
			hero["level"] = int(hero["level"]) + 1
			if not hero["name"] in ups:
				ups.append(hero["name"])
	return ups


static func training_cost(state: Dictionary, key: String) -> float:
	var t: Dictionary = DataDB.balance()["training"][key]
	return floorf(float(t["base_cost"]) * pow(float(t["cost_growth"]), int(state["training"][key])))


static func buy_training(state: Dictionary, key: String) -> bool:
	var cost := training_cost(state, key)
	if state["gold"] < cost:
		return false
	state["gold"] -= cost
	state["training"][key] = int(state["training"][key]) + 1
	return true


## Buys the cheapest training repeatedly while affordable, keeping `reserve`
## gold untouched (e.g. saving for the next hero). Returns purchases made.
static func auto_train(state: Dictionary, reserve: float = 0.0) -> int:
	var bought := 0
	while bought < 50:
		var best_key := ""
		var best_cost := INF
		for key in state["training"]:
			var c := training_cost(state, key)
			if c < best_cost:
				best_cost = c
				best_key = key
		if best_key == "" or float(state["gold"]) - best_cost < reserve or not buy_training(state, best_key):
			break
		bought += 1
	return bought


static func souls_for_ascension(state: Dictionary) -> int:
	var bal := DataDB.balance()
	if int(state["max_floor"]) < int(bal["ascension_min_floor"]):
		return 0
	var mods := StatCalc.party_mods(state)
	var base := pow(float(state["max_floor"]) / float(bal["soul_divisor"]), float(bal["soul_exponent"]))
	return int(floor(base * (1.0 + float(mods.get("soul_pct", 0.0)))))


static func can_ascend(state: Dictionary) -> bool:
	return souls_for_ascension(state) > 0


## Prestige: resets the climb, keeps souls, crystals, relics, the tree, bestiary and history.
static func ascend(state: Dictionary) -> int:
	var souls := souls_for_ascension(state)
	if souls <= 0:
		return 0
	var fresh := GameState.new_game(int(state["seed"]) + int(state["ascensions"]) + 1)
	state["souls"] = int(state["souls"]) + souls
	state["ascensions"] = int(state["ascensions"]) + 1
	state["seed"] = fresh["seed"]
	# The roster is kept, but every hero starts over: level 1, no gear, no skills.
	for hero in state["heroes"] + state["bench"]:
		hero["level"] = 1
		hero["xp"] = 0.0
		hero["hp_ratio"] = 1.0
		hero["mp_ratio"] = 1.0
		hero["skills"] = {}
		for slot in hero["equipment"]:
			hero["equipment"][slot] = null
		GameState.give_starter_weapon(state, hero)
	state["inventory"] = []
	state["gold"] = 0.0
	state["training"] = fresh["training"]
	state["buffs"] = []
	state["wall_floor"] = 0
	state["wall_attempts"] = 0
	var mods := StatCalc.party_mods(state)
	var start := 1 + int(mods.get("start_floor", 0))
	# Founder / Guild talents: heroes come back stronger, with a purse.
	for hero in state["heroes"] + state["bench"]:
		var founder: bool = DataDB.classes()[hero["class"]].get("founder", false)
		hero["level"] = 1 + int(mods.get("founder_level" if founder else "recruit_level", 0))
	state["gold"] = float(mods.get("start_gold", 0.0))
	state["floor"] = start
	state["max_floor"] = start
	state["checkpoint"] = start
	GameState.add_history(state, "ascension", "Ascended (#%d) for %d Souls" % [state["ascensions"], souls])
	return souls


static func node_level(state: Dictionary, node_id: String) -> int:
	return int(state["ascension"].get(node_id, 0))


static func node_cost(state: Dictionary, node_id: String) -> int:
	var node: Dictionary = DataDB.ascension_nodes()[node_id]
	return int(ceil(float(node["cost"]) * pow(float(node["cost_growth"]), node_level(state, node_id))))


static func node_unlocked(state: Dictionary, node_id: String) -> bool:
	var node: Dictionary = DataDB.ascension_nodes()[node_id]
	for req in node["requires"]:
		if node_level(state, req) < int(node["requires"][req]):
			return false
	return true


static func buy_node(state: Dictionary, node_id: String) -> bool:
	var node: Dictionary = DataDB.ascension_nodes()[node_id]
	if node_level(state, node_id) >= int(node["max"]) or not node_unlocked(state, node_id):
		return false
	var cost := node_cost(state, node_id)
	if int(state["souls"]) < cost:
		return false
	state["souls"] = int(state["souls"]) - cost
	state["ascension"][node_id] = node_level(state, node_id) + 1
	return true
