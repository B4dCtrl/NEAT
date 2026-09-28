extends RefCounted
## Item MERGE: several unequipped items of the same kind (slot, and weapon
## class for weapons) and the same rarity fuse into ONE random item of that
## same kind, one rarity higher. It costs gold (and crystals at the top), so it
## is the main sink of the economy: weak loot keeps a use, strong loot stays rare.

const DataDB = preload("res://core/data_db.gd")
const Loot = preload("res://core/loot_calculator.gd")


static func recipes() -> Dictionary:
	return DataDB.items().get("forge", {}).get("recipes", {})


static func forgeable_rarities() -> Array:
	return recipes().keys()


## "helm/" or "weapon/ranger": items with the same key merge together.
static func kind_key(item: Dictionary) -> String:
	return "%s/%s" % [item["slot"], item.get("class", "")]


static func kind_name(key: String) -> String:
	var slot := key.get_slice("/", 0)
	var cls := key.get_slice("/", 1)
	if cls != "":
		return "%s (%s)" % [slot.capitalize(), DataDB.classes().get(cls, {}).get("name", cls.capitalize())]
	return slot.capitalize()


## The merge candidates of one rarity and kind: weakest first, bag only.
static func candidates(state: Dictionary, rarity: String, key: String) -> Array:
	var out: Array = state["inventory"].filter(func(it): return it["rarity"] == rarity and kind_key(it) == key)
	out.sort_custom(func(a, b): return int(a["ilvl"]) < int(b["ilvl"]))
	return out


## Every (rarity, kind) group in the bag: [{rarity, key, have, need}], fullest first.
static func groups(state: Dictionary) -> Array:
	var counts := {}
	for it in state["inventory"]:
		if not recipes().has(it["rarity"]):
			continue
		var k: String = it["rarity"] + "|" + kind_key(it)
		counts[k] = int(counts.get(k, 0)) + 1
	var out := []
	for k in counts:
		var rarity: String = k.get_slice("|", 0)
		out.append({"rarity": rarity, "key": k.get_slice("|", 1), "have": counts[k], "need": int(recipes()[rarity]["count"])})
	out.sort_custom(func(a, b):
		var ra: float = float(a["have"]) / a["need"]
		var rb: float = float(b["have"]) / b["need"]
		return ra > rb if ra != rb else DataDB.rarity_order(a["rarity"]) > DataDB.rarity_order(b["rarity"]))
	return out


## {ok, count, have, gold, crystals, to, ilvl}
static func quote(state: Dictionary, rarity: String, key: String) -> Dictionary:
	var r: Dictionary = recipes().get(rarity, {})
	if r.is_empty():
		return {"ok": false, "count": 0, "have": 0, "gold": 0.0, "crystals": 0, "to": rarity, "ilvl": 1}
	var count := int(r["count"])
	var pool := candidates(state, rarity, key)
	var used := pool.slice(0, count)
	var ilvl := 1
	for it in used:
		ilvl = maxi(ilvl, int(it["ilvl"]))
	var growth := float(DataDB.items()["item_growth"])
	var gold := floorf(float(r["gold"]) * pow(growth, ilvl - 1))
	var crystals := int(r.get("crystals", 0))
	var ok := pool.size() >= count and float(state["gold"]) >= gold and int(state["crystals"]) >= crystals
	return {"ok": ok, "count": count, "have": pool.size(), "gold": gold, "crystals": crystals, "to": r["to"], "ilvl": ilvl}


## Fuses the items and returns the new one ({} if not possible).
static func merge(state: Dictionary, rarity: String, key: String) -> Dictionary:
	var q := quote(state, rarity, key)
	if not q["ok"]:
		return {}
	var used := candidates(state, rarity, key).slice(0, int(q["count"]))
	var gone := {}
	for it in used:
		gone[int(it["uid"])] = true
	state["inventory"] = state["inventory"].filter(func(it): return not gone.has(int(it["uid"])))
	state["gold"] = float(state["gold"]) - float(q["gold"])
	state["crystals"] = int(state["crystals"]) - int(q["crystals"])
	var rng := RandomNumberGenerator.new()
	var n := int(state.get("forges", 0))
	rng.seed = int(state["seed"]) * 31 + n * 7919 + 424242
	state["forges"] = n + 1
	var slot := key.get_slice("/", 0)
	var cls := key.get_slice("/", 1)
	var item := Loot.generate_item(rng, state, int(q["ilvl"]), q["to"], "",
		func(b): return b["slot"] == slot and String(b["class"]) == cls)
	item["forged"] = true
	state["inventory"].append(item)
	var stats: Dictionary = state["stats"]
	stats["items_forged"] = int(stats.get("items_forged", 0)) + 1
	stats["items_burned"] = int(stats.get("items_burned", 0)) + used.size()
	return item
