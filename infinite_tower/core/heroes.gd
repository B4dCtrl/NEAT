extends RefCounted
## Hero roster: the founder starts alone, up to `party_slots` heroes climb together,
## extra heroes wait on the bench. New heroes are bought in the Market or MINTED:
## generated from scratch with a random class, name and rarity (potential).
## Also owns the per-class job skill tree (Ragnarok style).

const DataDB = preload("res://core/data_db.gd")
const StatCalc = preload("res://core/stat_calculator.gd")

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
		"mp_ratio": 1.0,
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
## Veteran Recruits (Ascension) makes new heroes start at a higher level.
static func add_hero(state: Dictionary, hero: Dictionary) -> String:
	var bonus := int(StatCalc.party_mods(state).get("recruit_level", 0))
	if int(hero["level"]) == 1 and bonus > 0:
		hero["level"] = 1 + bonus
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

static func _discount(state: Dictionary) -> float:
	return 1.0 - minf(0.6, float(StatCalc.party_mods(state).get("mint_discount", 0.0)))


static func mint_cost(state: Dictionary) -> float:
	var h: Dictionary = DataDB.balance()["hire"]
	return floorf(float(h["mint_gold_base"]) * pow(float(h["mint_gold_growth"]), int(state.get("mints", 0))) * _discount(state))


static func hire_price(state: Dictionary) -> float:
	var h: Dictionary = DataDB.balance()["hire"]
	return floorf(float(h["gold_base"]) * pow(float(h["gold_growth"]), maxi(0, total_heroes(state) - 1)) * _discount(state))


static func roll_rarity(rng: RandomNumberGenerator, luck: float = 0.0) -> String:
	var table: Dictionary = DataDB.balance()["hero_rarities"]
	var weights := {}
	var total := 0.0
	for k in table:
		# Noble Blood (Ascension) shifts weight away from common heroes.
		weights[k] = float(table[k]["weight"]) * (1.0 if k == "common" else 1.0 + luck)
		total += weights[k]
	var roll := rng.randf() * total
	for k in table:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return "common"


## A brand-new random hero. Deterministic for a given (seed, salt).
static func generate(state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var classes := hireable_classes()
	var names: Array = DataDB.balance()["hero_names"]
	var class_id: String = classes[rng.randi() % classes.size()]
	var hero_name: String = names[rng.randi() % names.size()]
	return make_hero(state, class_id, hero_name, roll_rarity(rng, float(StatCalc.party_mods(state).get("rarity_luck", 0.0))))


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


# ------------------------------------------------------------------ job skill tree
# Ragnarok-style: one point per level, a tree per class. Passives add stats per
# rank; actives are learned with points, grow with rank and are auto-cast.

static func skill_points_total(hero: Dictionary) -> int:
	return (int(hero["level"]) - 1) * int(DataDB.table("skills")["points_per_level"])


static func skill_points_spent(hero: Dictionary) -> int:
	var nodes := DataDB.skill_nodes(hero["class"])
	var spent := 0
	for k in hero.get("skills", {}):
		if nodes.has(k):
			spent += int(hero["skills"][k])
	return spent


static func skill_points_free(hero: Dictionary) -> int:
	return skill_points_total(hero) - skill_points_spent(hero)


static func skill_rank(hero: Dictionary, node_id: String) -> int:
	return int(hero.get("skills", {}).get(node_id, 0))


static func skill_unlocked(hero: Dictionary, node_id: String) -> bool:
	var node: Dictionary = DataDB.skill_nodes(hero["class"]).get(node_id, {})
	if node.is_empty():
		return false
	for req in node["requires"]:
		if skill_rank(hero, req) < int(node["requires"][req]):
			return false
	return true


static func learn_skill(hero: Dictionary, node_id: String) -> bool:
	var node: Dictionary = DataDB.skill_nodes(hero["class"]).get(node_id, {})
	if node.is_empty() or skill_points_free(hero) <= 0 or skill_rank(hero, node_id) >= int(node["max"]) or not skill_unlocked(hero, node_id):
		return false
	if not hero.has("skills"):
		hero["skills"] = {}
	hero["skills"][node_id] = skill_rank(hero, node_id) + 1
	return true


static func reset_skills(hero: Dictionary) -> void:
	hero["skills"] = {}


## Drops ranks of nodes that are not in the hero's class tree (old saves).
static func clean_skills(hero: Dictionary) -> void:
	var nodes := DataDB.skill_nodes(hero["class"])
	var kept := {}
	for k in hero.get("skills", {}):
		if nodes.has(k):
			kept[k] = hero["skills"][k]
	hero["skills"] = kept


## Spends free points following the class' "auto" order: one point in each
## node of the list in turn, until everything reachable is maxed.
static func auto_learn(hero: Dictionary) -> int:
	var order: Array = DataDB.skill_tree(hero["class"]).get("auto", DataDB.skill_nodes(hero["class"]).keys())
	var learned := 0
	while skill_points_free(hero) > 0 and learned < 200:
		var any := false
		for id in order:
			if skill_points_free(hero) <= 0:
				break
			if learn_skill(hero, id):
				learned += 1
				any = true
		if not any:
			break
	return learned


# ------------------------------------------------------------------ active skills

## Value of a scaled field at `rank` ([rank 1 value, added per extra rank]).
static func _scaled(pair: Array, rank: int) -> float:
	return float(pair[0]) + float(pair[1]) * maxi(0, rank - 1)


## The combat skill a learned active node casts at `rank`.
static func skill_at_rank(node_id: String, rank: int) -> Dictionary:
	var node: Dictionary = DataDB.skill_nodes().get(node_id, {})
	var def: Dictionary = node.get("skill", {})
	var sk := {"id": node_id, "name": node.get("name", node_id), "icon": node.get("icon", "star"), "rank": rank}
	for k in def:
		if k != "scale":
			sk[k] = def[k]
	for k in def.get("scale", {}):
		sk[k] = _scaled(def["scale"][k], rank)
	if sk.has("hits"):
		sk["hits"] = int(floor(float(sk["hits"])))
	sk["mana"] = roundi(float(sk.get("mana", 0)))
	return sk


## Human text of a node at a rank ("{mult}%" and friends filled in).
static func describe(node_id: String, rank: int) -> String:
	var node: Dictionary = DataDB.skill_nodes().get(node_id, {})
	var text: String = node.get("text", "")
	if node.get("kind", "") != "active":
		return text
	var sk := skill_at_rank(node_id, maxi(rank, 1))
	text = text.replace("{mult}", str(roundi(float(sk.get("mult", 0.0)) * 100.0)))
	text = text.replace("{value_pct}", str(roundi((float(sk.get("value", 1.0)) - 1.0) * 100.0)))
	text = text.replace("{value}", str(roundi(float(sk.get("value", 0.0)) * 100.0)))
	text = text.replace("{duration}", String.num(float(sk.get("duration", 0.0)), 1))
	text = text.replace("{hits}", str(int(sk.get("hits", 0))))
	return "%s · %d mana · %ss cooldown" % [text, int(sk["mana"]), String.num(float(sk.get("cooldown", 0.0)), 0)]


## Active nodes of a class (ids), in tree order.
static func class_skills(class_id: String) -> Array:
	var nodes := DataDB.skill_nodes(class_id)
	var ids: Array = nodes.keys().filter(func(id): return nodes[id].get("kind", "") == "active")
	ids.sort_custom(func(a, b): return int(nodes[a]["row"]) * 10 + int(nodes[a]["col"]) < int(nodes[b]["row"]) * 10 + int(nodes[b]["col"]))
	return ids


static func active_skill_learned(hero: Dictionary, node_id: String) -> bool:
	return skill_rank(hero, node_id) > 0


static func active_skill_enabled(hero: Dictionary, node_id: String) -> bool:
	return not node_id in hero.get("skills_off", [])


## Turns a learned skill's auto-cast on/off.
static func toggle_active_skill(hero: Dictionary, skill_id: String) -> void:
	var off: Array = hero.get("skills_off", [])
	if skill_id in off:
		off.erase(skill_id)
	else:
		off.append(skill_id)
	hero["skills_off"] = off


## What this hero auto-casts in a fight (learned, switched on), at its rank.
static func active_skills(hero: Dictionary) -> Array:
	var out := []
	for id in class_skills(hero["class"]):
		if active_skill_learned(hero, id) and active_skill_enabled(hero, id):
			out.append(skill_at_rank(id, skill_rank(hero, id)))
	return out
