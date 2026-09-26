extends RefCounted
## Turns heroes + gear + sets + training + ascension + buffs + relics into final numbers.
## Flat stats add up; every "<stat>_pct" key multiplies the matching flat stat.

const DataDB = preload("res://core/data_db.gd")

const CORE_STATS := ["hp", "attack", "defense", "magic_power", "attack_speed", "crit_chance", "crit_damage", "dodge"]
## Party-wide keys: summed over the whole party instead of per hero.
const PARTY_KEYS := ["gold_pct", "drop_pct", "move_speed_pct", "xp_pct", "soul_pct", "cdr", "start_floor", "relic_slots"]
const CRIT_CAP := 0.75
const DODGE_CAP := 0.5
const CDR_CAP := 0.5


## Modifiers that apply to every hero: training, ascension tree, shrine buffs, relics,
## plus party keys (gold/drop/...) coming from any hero's equipment.
static func party_mods(state: Dictionary) -> Dictionary:
	var mods := {"specials": []}
	var bal := DataDB.balance()
	for key in state["training"]:
		var lvl := int(state["training"][key])
		if lvl > 0:
			_add_stats(mods, bal["training"][key]["stats"], lvl)
	var nodes := DataDB.ascension_nodes()
	for node_id in state["ascension"]:
		if nodes.has(node_id):
			_add_stats(mods, nodes[node_id]["stats"], int(state["ascension"][node_id]))
	for buff in state["buffs"]:
		_add_stats(mods, buff["stats"], 1)
	var relics := DataDB.relics()
	for relic_id in state["relics_equipped"]:
		var relic: Dictionary = relics.get(relic_id, {})
		if relic.has("stats"):
			_add_stats(mods, relic["stats"], 1)
		if relic.has("special"):
			mods["specials"].append(relic["special"])
	for hero in state["heroes"]:
		for slot in hero["equipment"]:
			var item = hero["equipment"][slot]
			if item == null:
				continue
			for key in item["stats"]:
				if key in PARTY_KEYS:
					mods[key] = mods.get(key, 0.0) + float(item["stats"][key])
	return mods


static func relic_slots(state: Dictionary) -> int:
	var mods := party_mods(state)
	return int(DataDB.balance()["base_relic_slots"]) + int(mods.get("relic_slots", 0))


## {set_id: equipped piece count}
static func active_sets(hero: Dictionary) -> Dictionary:
	var counts := {}
	for slot in hero["equipment"]:
		var item = hero["equipment"][slot]
		if item != null and item.get("set", "") != "":
			counts[item["set"]] = counts.get(item["set"], 0) + 1
	return counts


## Final stats for one hero. Pass a cached party_mods() when computing several heroes.
static func hero_stats(state: Dictionary, hero: Dictionary, mods: Dictionary = {}) -> Dictionary:
	if mods.is_empty():
		mods = party_mods(state)
	var cdef: Dictionary = DataDB.classes()[hero["class"]]
	var lvl := int(hero["level"])
	var flat := {}
	for key in CORE_STATS:
		flat[key] = float(cdef["base"].get(key, 0.0)) + float(cdef["growth"].get(key, 0.0)) * (lvl - 1)
	var pct := {}
	var specials: Array = mods.get("specials", []).duplicate()

	for slot in hero["equipment"]:
		var item = hero["equipment"][slot]
		if item == null:
			continue
		for key in item["stats"]:
			if key in CORE_STATS:
				flat[key] += float(item["stats"][key])
			elif not key in PARTY_KEYS:
				pct[key] = pct.get(key, 0.0) + float(item["stats"][key])

	var sets := DataDB.sets()
	var active := active_sets(hero)
	for set_id in active:
		for threshold in sets[set_id]["bonuses"]:
			if active[set_id] >= int(threshold):
				var bonus: Dictionary = sets[set_id]["bonuses"][threshold]
				for key in bonus.get("stats", {}):
					if key in CORE_STATS:
						flat[key] += float(bonus["stats"][key])
					else:
						pct[key] = pct.get(key, 0.0) + float(bonus["stats"][key])
				specials.append_array(bonus.get("specials", []))

	for key in mods:
		if key != "specials" and not key in PARTY_KEYS:
			if key in CORE_STATS:
				flat[key] += float(mods[key])
			else:
				pct[key] = pct.get(key, 0.0) + float(mods[key])

	var out := {
		"hp": flat["hp"] * (1.0 + pct.get("hp_pct", 0.0)),
		"attack": flat["attack"] * (1.0 + pct.get("attack_pct", 0.0)),
		"magic_power": flat["magic_power"] * (1.0 + pct.get("magic_power_pct", 0.0)),
		"defense": flat["defense"] * (1.0 + pct.get("defense_pct", 0.0)),
		"attack_speed": flat["attack_speed"] * (1.0 + pct.get("attack_speed_pct", 0.0)),
		"crit_chance": minf(flat["crit_chance"], CRIT_CAP),
		"crit_damage": flat["crit_damage"],
		"dodge": minf(flat["dodge"], DODGE_CAP),
		"damage_pct": pct.get("damage_pct", 0.0),
		"fire_damage_pct": pct.get("fire_damage_pct", 0.0),
		"cdr": minf(float(mods.get("cdr", 0.0)), CDR_CAP),
		"specials": specials,
		"damage_type": cdef["damage_type"],
		"element": "fire" if "fire_imbue" in specials else cdef["element"],
	}
	return out


## Power estimate used for the UI and auto-equip comparisons.
static func power_rating(stats: Dictionary) -> float:
	var offense: float = maxf(stats["attack"], stats["magic_power"]) * stats["attack_speed"]
	offense *= 1.0 + stats["crit_chance"] * (stats["crit_damage"] - 1.0)
	offense *= 1.0 + stats["damage_pct"]
	var defense: float = stats["hp"] * (1.0 + stats["defense"] / 100.0) / (1.0 - stats["dodge"])
	return sqrt(offense * defense)


static func _add_stats(target: Dictionary, stats: Dictionary, times: int) -> void:
	for key in stats:
		target[key] = target.get(key, 0.0) + float(stats[key]) * times
