extends RefCounted
## Hero roster: the founder starts alone, up to `party_slots` heroes climb together,
## extra heroes wait on the bench. New heroes are bought in the Market or MINTED:
## generated from scratch with a random class, name and rarity (potential).
## Also owns the per-class job skill tree (Ragnarok style).

const DataDB = preload("res://core/data_db.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const Loc = preload("res://core/loc.gd")
const Loot = preload("res://core/loot_calculator.gd")

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


## A player-chosen hero name: trimmed, 1 to 16 characters, no BBCode brackets.
static func clean_name(raw: String) -> String:
	var s := raw.strip_edges().replace("[", "").replace("]", "").replace("\n", " ").replace("\t", " ")
	while "  " in s:
		s = s.replace("  ", " ")
	return s.substr(0, 16).strip_edges()


static func rename(state: Dictionary, hero_id: String, raw: String) -> bool:
	var nm := clean_name(raw)
	if nm == "":
		return false
	for h in state["heroes"] + state["bench"]:
		if h["id"] == hero_id:
			h["name"] = nm
			return true
	return false


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


## Gold for the next hero: it depends on how many heroes you already own (the
## founder counts), so a full team makes every extra hero a real investment.
static func mint_cost(state: Dictionary) -> float:
	var h: Dictionary = DataDB.balance()["hire"]
	var k := total_heroes(state) + 1
	var table: Dictionary = h["mint_table"]
	var base: float
	if table.has(str(k)):
		base = float(table[str(k)])
	else:
		var last := 2
		for key in table:
			last = maxi(last, int(key))
		base = float(table[str(last)]) * pow(float(h["mint_growth_after"]), k - last)
	return floorf(base * _discount(state))


## Best floor reached that the next hero slot demands.
static func mint_floor_required(state: Dictionary) -> int:
	var h: Dictionary = DataDB.balance()["hire"]
	var k := total_heroes(state) + 1
	var table: Dictionary = h["mint_floor"]
	if table.has(str(k)):
		return int(table[str(k)])
	var last := 2
	for key in table:
		last = maxi(last, int(key))
	return int(table[str(last)]) + int(h["mint_floor_step_after"]) * (k - last)


## "" when minting is possible, else why not (shown on the button).
static func mint_blocker(state: Dictionary) -> String:
	var need := mint_floor_required(state)
	if int(state.get("best_floor_ever", 1)) < need:
		return Loc.t("Reach floor %d first") % need
	if float(state["gold"]) < mint_cost(state):
		return Loc.t("Not enough gold")
	return ""


static func hire_price(state: Dictionary) -> float:
	var h: Dictionary = DataDB.balance()["hire"]
	return floorf(mint_cost(state) * float(h["market_premium"]))


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
	return mint_blocker(state) == ""


## Spends gold and mints a hero. Returns the hero ({} if unaffordable).
static func mint(state: Dictionary) -> Dictionary:
	var cost := mint_cost(state)
	if mint_blocker(state) != "":
		return {}
	state["gold"] = float(state["gold"]) - cost
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["seed"]) * 7 + int(state.get("mints", 0)) * 65537 + 12345
	state["mints"] = int(state.get("mints", 0)) + 1
	var hero := generate(state, rng)
	add_hero(state, hero)
	return hero


# ------------------------------------------------------------------ fusion
# `count` heroes of one rarity (never the Stairborn) become ONE hero of the next
# rarity: the one you keep brings its level, gear and skills to the new rarity,
# the others are consumed and their gear returns to the bag. It is where spare
# heroes go: the reserve is useful for more than swapping.

static func fusion_count() -> int:
	return int(DataDB.balance().get("fusion", {}).get("count", 3))


## The rarity a fusion of `rarity` makes ("" when it is already the top one).
static func next_rarity(rarity: String) -> String:
	var order: Array = DataDB.balance()["hero_rarities"].keys()
	var i := order.find(rarity)
	return order[i + 1] if i >= 0 and i + 1 < order.size() else ""


static func is_founder(hero: Dictionary) -> bool:
	return bool(DataDB.classes().get(hero["class"], {}).get("founder", false))


static func in_party(state: Dictionary, hero: Dictionary) -> bool:
	return state["heroes"].any(func(h): return h["id"] == hero["id"])


## Gold for the fusion that makes a hero of `to_rarity`.
static func fusion_fee(to_rarity: String) -> float:
	return float(DataDB.balance().get("fusion", {}).get("fee", {}).get(to_rarity, 0.0))


## Heroes of the party and the reserve that may be fused (everyone but the founder).
static func fusable(state: Dictionary) -> Array:
	var out := []
	for h in state["heroes"] + state["bench"]:
		if not is_founder(h):
			out.append(h)
	return out


## How many fusable heroes there are of each rarity.
static func fusion_counts(state: Dictionary) -> Dictionary:
	var out := {}
	for h in fusable(state):
		var r := String(h.get("rarity", "common"))
		out[r] = int(out.get(r, 0)) + 1
	return out


## Every fusion that could be done now: [{rarity, to, fee, heroes}] with the
## heroes of that rarity strongest first.
static func fusion_groups(state: Dictionary) -> Array:
	var out := []
	var all := fusable(state)
	for r in DataDB.balance()["hero_rarities"]:
		var to := next_rarity(r)
		if to == "":
			continue
		var of := all.filter(func(h): return String(h.get("rarity", "common")) == r)
		if of.size() < fusion_count():
			continue
		of.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
		out.append({"rarity": r, "to": to, "fee": fusion_fee(to), "heroes": of})
	return out


## What a fusion would do: {keep, burn, to, fee} or {} when it cannot be done.
## `keep_id` "" keeps the highest level; the heroes consumed are the weakest
## others (reserve ones first), unless `burn_ids` names them.
static func fusion_plan(state: Dictionary, rarity: String, keep_id: String = "", burn_ids: Array = []) -> Dictionary:
	var to := next_rarity(rarity)
	if to == "":
		return {}
	var pool := fusable(state).filter(func(h): return String(h.get("rarity", "common")) == rarity)
	if pool.size() < fusion_count():
		return {}
	pool.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
	var keep: Dictionary = pool[0]
	if keep_id != "":
		var found := pool.filter(func(h): return h["id"] == keep_id)
		if found.is_empty():
			return {}
		keep = found[0]
	var others := pool.filter(func(h): return h["id"] != keep["id"])
	var burn := []
	if burn_ids.is_empty():
		# Weakest first; between equals the reserve goes before the party.
		others.sort_custom(func(a, b):
			var pa := 1 if in_party(state, a) else 0
			var pb := 1 if in_party(state, b) else 0
			return pa < pb if pa != pb else int(a["level"]) < int(b["level"]))
		burn = others.slice(0, fusion_count() - 1)
	else:
		for id in burn_ids:
			var f := others.filter(func(h): return h["id"] == id)
			if f.is_empty() or burn.size() >= fusion_count() - 1:
				return {}
			burn.append(f[0])
		if burn.size() != fusion_count() - 1:
			return {}
	return {"keep": keep, "burn": burn, "to": to, "fee": fusion_fee(to)}


## "" when the fusion can be done, else why not.
static func fusion_blocker(state: Dictionary, plan: Dictionary) -> String:
	if plan.is_empty():
		return Loc.t("Not enough heroes of the same rarity")
	if float(state["gold"]) < float(plan["fee"]):
		return Loc.t("Not enough gold")
	return ""


## Does the fusion. Returns the plan that was carried out ({} if it could not be).
static func fuse(state: Dictionary, rarity: String, keep_id: String = "", burn_ids: Array = []) -> Dictionary:
	var plan := fusion_plan(state, rarity, keep_id, burn_ids)
	if fusion_blocker(state, plan) != "":
		return {}
	state["gold"] = float(state["gold"]) - float(plan["fee"])
	var keep: Dictionary = plan["keep"]
	var cap := int(DataDB.balance()["inventory_cap"])
	var returned := 0
	var sold := 0.0
	for b in plan["burn"]:
		# Their gear goes back to the bag (or is salvaged when the bag is full).
		for slot in b["equipment"]:
			var item = b["equipment"][slot]
			if item == null:
				continue
			if state["inventory"].size() < cap:
				state["inventory"].append(item)
				returned += 1
			else:
				sold += Loot.salvage_value(item)
		state["heroes"] = state["heroes"].filter(func(h): return h["id"] != b["id"])
		state["bench"] = state["bench"].filter(func(h): return h["id"] != b["id"])
	state["gold"] = float(state["gold"]) + sold
	# The party must never be left empty.
	if state["heroes"].is_empty():
		state["bench"] = state["bench"].filter(func(h): return h["id"] != keep["id"])
		state["heroes"].append(keep)
	var rdef: Dictionary = DataDB.balance()["hero_rarities"][plan["to"]]
	keep["rarity"] = plan["to"]
	keep["potential"] = float(rdef["potential"])
	keep["hp_ratio"] = 1.0
	keep["mp_ratio"] = 1.0
	var st: Dictionary = state["stats"]
	st["fusions"] = int(st.get("fusions", 0)) + 1
	plan["returned_items"] = returned
	plan["salvaged_gold"] = sold
	return plan


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
	return Loc.t("%s · %d mana · %ss cooldown") % [text, int(sk["mana"]), String.num(float(sk.get("cooldown", 0.0)), 0)]


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
