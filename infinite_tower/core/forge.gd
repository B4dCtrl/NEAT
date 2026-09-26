extends RefCounted
## The Forge: burns several unequipped items of one rarity into a single item
## of the next rarity, for gold (and crystals at the top). It is the main sink
## of the economy: loot keeps its value because it can climb tiers, and every
## upgrade destroys items and currency.

const DataDB = preload("res://core/data_db.gd")
const Loot = preload("res://core/loot_calculator.gd")


static func recipes() -> Dictionary:
	return DataDB.items().get("forge", {}).get("recipes", {})


static func forgeable_rarities() -> Array:
	return recipes().keys()


## The burn candidates: weakest first, never equipped (the bag only).
static func candidates(state: Dictionary, rarity: String) -> Array:
	var out: Array = state["inventory"].filter(func(it): return it["rarity"] == rarity)
	out.sort_custom(func(a, b): return int(a["ilvl"]) < int(b["ilvl"]))
	return out


## {ok, count, have, gold, crystals, to, ilvl}
static func quote(state: Dictionary, rarity: String) -> Dictionary:
	var r: Dictionary = recipes().get(rarity, {})
	if r.is_empty():
		return {"ok": false, "count": 0, "have": 0, "gold": 0.0, "crystals": 0, "to": rarity, "ilvl": 1}
	var count := int(r["count"])
	var pool := candidates(state, rarity)
	var burn := pool.slice(0, count)
	var ilvl := 1
	for it in burn:
		ilvl = maxi(ilvl, int(it["ilvl"]))
	var growth := float(DataDB.items()["item_growth"])
	var gold := floorf(float(r["gold"]) * pow(growth, ilvl - 1))
	var crystals := int(r.get("crystals", 0))
	var ok := pool.size() >= count and float(state["gold"]) >= gold and int(state["crystals"]) >= crystals
	return {"ok": ok, "count": count, "have": pool.size(), "gold": gold, "crystals": crystals, "to": r["to"], "ilvl": ilvl}


## Burns the items and returns the new one ({} if not possible). The result
## is made for `class_id` when possible so the forge never wastes a craft.
static func forge(state: Dictionary, rarity: String, class_id: String = "") -> Dictionary:
	var q := quote(state, rarity)
	if not q["ok"]:
		return {}
	var burn := candidates(state, rarity).slice(0, int(q["count"]))
	var burned := {}
	for it in burn:
		burned[int(it["uid"])] = true
	state["inventory"] = state["inventory"].filter(func(it): return not burned.has(int(it["uid"])))
	state["gold"] = float(state["gold"]) - float(q["gold"])
	state["crystals"] = int(state["crystals"]) - int(q["crystals"])
	var rng := RandomNumberGenerator.new()
	var n := int(state.get("forges", 0))
	rng.seed = int(state["seed"]) * 31 + n * 7919 + 424242
	state["forges"] = n + 1
	var item := {}
	for attempt in 12:
		item = Loot.generate_item(rng, state, int(q["ilvl"]), q["to"])
		if class_id == "" or Loot.can_equip(item, class_id):
			break
	item["forged"] = true
	state["inventory"].append(item)
	var stats: Dictionary = state["stats"]
	stats["items_forged"] = int(stats.get("items_forged", 0)) + 1
	stats["items_burned"] = int(stats.get("items_burned", 0)) + burn.size()
	return item
