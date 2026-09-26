extends RefCounted
## Hero roster: the founder starts alone, up to `party_slots` heroes climb together,
## extra heroes wait on the bench. New heroes are bought in the Market or MINTED:
## generated from scratch with a random class, name and rarity (potential).
## Also owns the per-hero skill tree.

const DataDB = preload("res://core/data_db.gd")

const FOUNDER_CLASS := "stairborn"


static func new_uid(state: Dictionary) -> int:
	var uid := int(state["next_uid"])
	state["next_uid"] = uid + 1
	return uid


static func make_hero(state: Dictionary, class_id: String, hero_name: String, rarity: String = "common") -> Dictionary:
	var cdef: Dictionary = DataDB.classes()[class_id]
	var equipment := {}
	for slot in DataDB.items()["slots"]:
		equipment[slot] = null
	var rdef: Dictionary = DataDB.balance()["hero_rarities"].get(rarity, {"potential": 1.0})
	return {
		"id": "hero_%d" % new_uid(state),
		"class": class_id,
		"name": hero_name,
		"rarity": rarity,
		"potential": float(rdef["potential"]),
		"level": 1,
		"xp": 0.0,
		"row": cdef["default_row"],
		"hp_ratio": 1.0,
		"equipment": equipment,
		"skills": {},
	}


static func party_slots() -> int:
	return int(DataDB.balance()["party_slots"])


static func hireable_classes() -> Array:
	var out := []
	for id in DataDB.classes():
		if not DataDB.classes()[id].get("founder", false):
			out.append(id)
	return out


static func total_heroes(state: Dictionary) -> int:
	return state["heroes"].size() + state["bench"].size()


## Joins the party when there is a free slot, otherwise the bench.
static func add_hero(state: Dictionary, hero: Dictionary) -> String:
	if state["heroes"].size() < party_slots():
		state["heroes"].append(hero)
		return "party"
	state["bench"].append(hero)
	return "bench"


static func swap(state: Dictionary, party_idx: int, bench_idx: int) -> bool:
	if party_idx < 0 or bench_idx < 0 or bench_idx >= state["bench"].size():
		return false
	var incoming: Dictionary = state["bench"][bench_idx]
	if party_idx >= state["heroes"].size():
		if state["heroes"].size() >= party_slots():
			return false
		state["bench"].remove_at(bench_idx)
		state["heroes"].append(incoming)
		return true
	state["bench"][bench_idx] = state["heroes"][party_idx]
	state["heroes"][party_idx] = incoming
	return true


static func bench_hero(state: Dictionary, party_idx: int) -> bool:
	if state["heroes"].size() <= 1 or party_idx >= state["heroes"].size():
		return false
	state["bench"].append(state["heroes"][party_idx])
	state["heroes"].remove_at(party_idx)
	return true


# ------------------------------------------------------------------ minting

static func mint_cost(state: Dictionary) -> float:
	var h: Dictionary = DataDB.balance()["hire"]
	return floorf(float(h["mint_gold_base"]) * pow(float(h["mint_gold_growth"]), int(state.get("mints", 0))))


static func hire_price(state: Dictionary) -> float:
	var h: Dictionary = DataDB.balance()["hire"]
	return floorf(float(h["gold_base"]) * pow(float(h["gold_growth"]), maxi(0, total_heroes(state) - 1)))


static func roll_rarity(rng: RandomNumberGenerator) -> String:
	var table: Dictionary = DataDB.balance()["hero_rarities"]
	var total := 0.0
	for k in table:
		total += float(table[k]["weight"])
	var roll := rng.randf() * total
	for k in table:
		roll -= float(table[k]["weight"])
		if roll <= 0.0:
			return k
	return "common"


## A brand-new random hero. Deterministic for a given (seed, salt).
static func generate(state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var classes := hireable_classes()
	var names: Array = DataDB.balance()["hero_names"]
	var class_id: String = classes[rng.randi() % classes.size()]
	var hero_name: String = names[rng.randi() % names.size()]
	return make_hero(state, class_id, hero_name, roll_rarity(rng))


static func can_mint(state: Dictionary) -> bool:
	return float(state["gold"]) >= mint_cost(state)


## Spends gold and mints a hero. Returns the hero ({} if unaffordable).
static func mint(state: Dictionary) -> Dictionary:
	var cost := mint_cost(state)
	if float(state["gold"]) < cost:
		return {}
	state["gold"] = float(state["gold"]) - cost
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["seed"]) * 7 + int(state.get("mints", 0)) * 65537 + 12345
	state["mints"] = int(state.get("mints", 0)) + 1
	var hero := generate(state, rng)
	add_hero(state, hero)
	return hero


## Gold to keep aside so auto-training does not eat the next recruit's price.
static func gold_reserve(state: Dictionary) -> float:
	if state["heroes"].size() < party_slots():
		return minf(mint_cost(state), hire_price(state))
	return 0.0


# ------------------------------------------------------------------ skill tree

static func skill_points_total(hero: Dictionary) -> int:
	return (int(hero["level"]) - 1) * int(DataDB.table("skills")["points_per_level"])


static func skill_points_spent(hero: Dictionary) -> int:
	var spent := 0
	for k in hero.get("skills", {}):
		spent += int(hero["skills"][k])
	return spent


static func skill_points_free(hero: Dictionary) -> int:
	return skill_points_total(hero) - skill_points_spent(hero)


static func skill_rank(hero: Dictionary, node_id: String) -> int:
	return int(hero.get("skills", {}).get(node_id, 0))


static func skill_unlocked(hero: Dictionary, node_id: String) -> bool:
	var node: Dictionary = DataDB.skill_nodes()[node_id]
	for req in node["requires"]:
		if skill_rank(hero, req) < int(node["requires"][req]):
			return false
	return true


static func learn_skill(hero: Dictionary, node_id: String) -> bool:
	var node: Dictionary = DataDB.skill_nodes()[node_id]
	if skill_points_free(hero) <= 0 or skill_rank(hero, node_id) >= int(node["max"]) or not skill_unlocked(hero, node_id):
		return false
	if not hero.has("skills"):
		hero["skills"] = {}
	hero["skills"][node_id] = skill_rank(hero, node_id) + 1
	return true


static func reset_skills(hero: Dictionary) -> void:
	hero["skills"] = {}


## Spends free points automatically, cycling through the class' preferred branch.
static func auto_learn(hero: Dictionary) -> int:
	var nodes := DataDB.skill_nodes()
	var prefer: String = DataDB.classes()[hero["class"]].get("skill_branch", "might")
	var learned := 0
	while skill_points_free(hero) > 0 and learned < 100:
		var best := ""
		var best_rank := 1 << 30
		for id in nodes:
			if not skill_unlocked(hero, id) or skill_rank(hero, id) >= int(nodes[id]["max"]):
				continue
			# Prefer the class branch, then the lowest-ranked node (spreads points).
			var r := skill_rank(hero, id) + (0 if nodes[id]["branch"] == prefer else 3)
			if r < best_rank:
				best_rank = r
				best = id
		if best == "" or not learn_skill(hero, best):
			break
		learned += 1
	return learned
