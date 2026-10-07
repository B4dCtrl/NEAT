extends RefCounted
## Drop tables: rarity rolls, item generation (affixes, sets), relics and chests.
## Every roll takes the RNG explicitly so offline simulation stays deterministic.

const DataDB = preload("res://core/data_db.gd")


## Weighted rarity roll. drop_bonus shifts weight toward higher tiers.
static func roll_rarity(rng: RandomNumberGenerator, floor_num: int, min_rarity: String = "common", drop_bonus: float = 0.0, allow_relic: bool = true) -> String:
	var rarities := DataDB.rarities()
	var min_order := DataDB.rarity_order(min_rarity)
	var relic_ok := allow_relic and floor_num >= int(DataDB.balance()["relic_min_floor"])
	var weights := {}
	var total := 0.0
	for key in rarities:
		var r: Dictionary = rarities[key]
		var order := int(r["order"])
		if order < min_order or (key == "relic" and not relic_ok):
			continue
		# Higher tiers get a boost from drop bonus and depth into the tower.
		var w := float(r["weight"]) * pow(1.0 + drop_bonus + floor_num / 400.0, order)
		weights[key] = w
		total += w
	var roll := rng.randf() * total
	for key in weights:
		roll -= weights[key]
		if roll <= 0.0:
			return key
	return min_rarity


static func new_uid(state: Dictionary) -> int:
	var uid := int(state["next_uid"])
	state["next_uid"] = uid + 1
	return uid


## Which set a drop belongs to: any set unlocked by this floor, strongly
## favouring the newest ones (so the tower keeps handing out fresh looks), or the
## boss's own set about half the time.
static func pick_set(rng: RandomNumberGenerator, floor_num: int, set_bias: String = "") -> String:
	var sets := DataDB.sets()
	var order: Array = DataDB.items()["set_order"]
	var open := []
	for id in order:
		if floor_num >= int(sets[id]["min_floor"]):
			open.append(id)
	if open.is_empty():
		open.append(order[0])
	if set_bias != "" and set_bias in open and rng.randf() < 0.5:
		return set_bias
	var total := 0.0
	var weights := []
	for i in open.size():
		var w := pow(1.7, i)
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in open.size():
		roll -= weights[i]
		if roll <= 0.0:
			return open[i]
	return open[open.size() - 1]


## Builds an equipment item. rarity must not be "relic". Every piece belongs to a
## set (20 tiers). Without a base_filter the set comes from pick_set(); with one
## (merge) the filter decides, and the set it allows is used as is.
static func generate_item(rng: RandomNumberGenerator, state: Dictionary, floor_num: int, rarity: String, set_bias: String = "", base_filter: Callable = Callable()) -> Dictionary:
	var data := DataDB.items()
	var rdef: Dictionary = data["rarities"][rarity]
	var bases: Array = data["bases"]
	if base_filter.is_valid():
		var picked: Array = bases.filter(base_filter)
		if not picked.is_empty():
			bases = picked
	else:
		var set_id := pick_set(rng, floor_num, set_bias)
		bases = bases.filter(func(b): return b["set"] == set_id)
	# One roll per slot (not per base), so weapons are not over-represented.
	var slots := []
	for b in bases:
		if not b["slot"] in slots:
			slots.append(b["slot"])
	var slot: String = slots[rng.randi() % slots.size()]
	var of_slot: Array = bases.filter(func(b): return b["slot"] == slot)
	var base: Dictionary = of_slot[rng.randi() % of_slot.size()]
	var ilvl := maxi(floor_num, 1)
	var scale := float(rdef["mult"]) * pow(float(data["item_growth"]), ilvl - 1) * rng.randf_range(0.9, 1.1)
	var stats := {}
	for key in base["stats"]:
		stats[key] = snappedf(float(base["stats"][key]) * scale, 0.1)
	for key in base.get("fixed", {}):
		stats[key] = float(base["fixed"][key])

	var suffix := ""
	# Only bonuses that make sense for this kind of piece (boots: speed, rings: luck...).
	var affixes: Array = data["affixes"].filter(func(a): return a.get("slots", []).is_empty() or base["slot"] in a["slots"])
	var quality := 0.8 + 0.1 * int(rdef["order"])
	for i in int(rdef["affixes"]):
		if affixes.is_empty():
			break
		var a: Dictionary = affixes.pop_at(rng.randi() % affixes.size())
		var value := rng.randf_range(float(a["min"]), float(a["max"])) * quality
		stats[a["stat"]] = snappedf(stats.get(a["stat"], 0.0) + value, 0.001)
		if suffix == "":
			suffix = a["suffix"]

	return {
		"uid": new_uid(state),
		"base": base["id"],
		"name": base["name"] + ((" " + suffix) if suffix != "" else ""),
		"slot": base["slot"],
		"class": base["class"],
		"rarity": rarity,
		"ilvl": ilvl,
		"stats": stats,
		"set": base["set"],
	}


## Picks an unowned relic, or "" when every relic is already owned.
static func roll_relic(rng: RandomNumberGenerator, state: Dictionary) -> String:
	var pool := []
	for relic_id in DataDB.relics():
		if not relic_id in state["relics_owned"]:
			pool.append(relic_id)
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]


## Economy cap: after an Epic / Legendary / Mythic drops, the next one of that
## tier can only drop `cap_floors` floors later; until then it downgrades.
static func apply_cap(state: Dictionary, rarity: String) -> String:
	var cds: Dictionary = state.get("rarity_cd", {})
	var now := int(state.get("floors_cleared_total", 0))
	var r := rarity
	while DataDB.rarity_order(r) > 0 and int(cds.get(r, 0)) > now:
		r = DataDB.rarity_by_order(DataDB.rarity_order(r) - 1)
	var cap := int(DataDB.rarities().get(r, {}).get("cap_floors", 0))
	if cap > 0:
		cds[r] = now + cap
		state["rarity_cd"] = cds
	return r


## A drop result is {"item": Dictionary} or {"relic": id} or {"crystals": n}.
static func roll_drop(rng: RandomNumberGenerator, state: Dictionary, floor_num: int, min_rarity: String, drop_bonus: float, set_bias: String = "") -> Dictionary:
	var rarity := roll_rarity(rng, floor_num, min_rarity, drop_bonus)
	if rarity != "relic":
		rarity = apply_cap(state, rarity)
	if rarity == "relic":
		var relic_id := roll_relic(rng, state)
		if relic_id == "":
			return {"crystals": 3}
		return {"relic": relic_id}
	return {"item": generate_item(rng, state, floor_num, rarity, set_bias)}


static func enemy_drops(rng: RandomNumberGenerator, state: Dictionary, floor_num: int, enemy_count: int, drop_bonus: float) -> Array:
	var out := []
	var chance := float(DataDB.balance()["base_drop_chance"]) * (1.0 + drop_bonus)
	var cons_chance := float(DataDB.items().get("consumable_drop_chance", 0.0)) * (1.0 + drop_bonus)
	for i in enemy_count:
		if rng.randf() < chance:
			out.append(roll_drop(rng, state, floor_num, "common", drop_bonus))
		if rng.randf() < cons_chance:
			out.append({"consumable": roll_consumable(rng)})
	return out


## Random consumable id, weighted.
static func roll_consumable(rng: RandomNumberGenerator) -> String:
	var table: Dictionary = DataDB.items().get("consumables", {})
	var total := 0.0
	for id in table:
		total += float(table[id]["weight"])
	var roll := rng.randf() * total
	for id in table:
		roll -= float(table[id]["weight"])
		if roll <= 0.0:
			return id
	return "health_potion"


static func boss_chest(rng: RandomNumberGenerator, state: Dictionary, floor_num: int, tier: String, drop_bonus: float, set_bias: String) -> Array:
	var chest: Dictionary = DataDB.balance()["chest"][tier]
	var out := []
	for i in int(chest["items"]):
		var rarity := roll_rarity(rng, floor_num, chest["min_rarity"], drop_bonus, false)
		# Chests keep their minimum rarity even while the cap is active.
		var capped := apply_cap(state, rarity)
		if DataDB.rarity_order(capped) >= DataDB.rarity_order(chest["min_rarity"]):
			rarity = capped
		out.append({"item": generate_item(rng, state, floor_num, rarity, set_bias)})
	if floor_num >= int(DataDB.balance()["relic_min_floor"]) and rng.randf() < float(chest["relic_chance"]) * (1.0 + drop_bonus):
		var relic_id := roll_relic(rng, state)
		out.append({"relic": relic_id} if relic_id != "" else {"crystals": 3})
	if int(chest["crystals"]) > 0:
		out.append({"crystals": int(chest["crystals"])})
	return out


## Class-locked items (weapons) fit their class, plus classes that list it in "uses".
static func can_equip(item: Dictionary, class_id: String) -> bool:
	if item["class"] == "" or item["class"] == class_id:
		return true
	return item["class"] in DataDB.classes().get(class_id, {}).get("uses", [])


static func salvage_value(item: Dictionary) -> float:
	var rdef: Dictionary = DataDB.rarities()[item["rarity"]]
	var gold_growth := float(DataDB.enemy_scaling()["gold_growth"])
	return float(rdef["salvage"]) * 3.0 * pow(gold_growth, int(item["ilvl"]) - 1)
