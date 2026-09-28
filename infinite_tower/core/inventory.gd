extends RefCounted
## Equipment, inventory and relic management. Pure functions over the state dict.

const DataDB = preload("res://core/data_db.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const Loot = preload("res://core/loot_calculator.gd")


## Power of a hero if `item` were equipped in its slot (null = slot emptied).
static func power_with(state: Dictionary, hero: Dictionary, slot: String, item, mods: Dictionary) -> float:
	var previous = hero["equipment"][slot]
	hero["equipment"][slot] = item
	var power := StatCalc.power_rating(StatCalc.hero_stats(state, hero, mods))
	hero["equipment"][slot] = previous
	return power


## Hero index that gains the most from `item`, or -1 when nobody improves.
static func best_hero_for(state: Dictionary, item: Dictionary) -> int:
	var mods := StatCalc.party_mods(state)
	var best := -1
	var best_gain := 0.0
	for i in state["heroes"].size():
		var hero: Dictionary = state["heroes"][i]
		if not Loot.can_equip(item, hero["class"]):
			continue
		var current := StatCalc.power_rating(StatCalc.hero_stats(state, hero, mods))
		var gain := power_with(state, hero, item["slot"], item, mods) / maxf(current, 0.001) - 1.0
		if gain > best_gain + 0.0001:
			best_gain = gain
			best = i
	return best


## Adds a freshly dropped item. Returns "stored" or "salvaged:<gold>".
## Nothing is equipped automatically: gear is always the player's choice.
static func receive_item(state: Dictionary, item: Dictionary) -> String:
	var settings: Dictionary = state["settings"]
	var threshold := DataDB.rarity_order(settings.get("auto_salvage_below", "common"))
	if DataDB.rarity_order(item["rarity"]) < threshold and item.get("set", "") == "":
		var gold := Loot.salvage_value(item)
		state["gold"] += gold
		return "salvaged:%d" % int(gold)
	state["inventory"].append(item)
	_enforce_cap(state)
	return "stored"


## Equips an item (from anywhere) on a hero; the replaced item goes to the inventory.
static func equip(state: Dictionary, hero_idx: int, item: Dictionary) -> bool:
	var hero: Dictionary = state["heroes"][hero_idx]
	if not Loot.can_equip(item, hero["class"]):
		return false
	_remove_from_inventory(state, int(item["uid"]))
	var old = hero["equipment"][item["slot"]]
	# Equipping binds the item to the account: it can no longer be traded.
	item["bound"] = true
	hero["equipment"][item["slot"]] = item
	if old != null:
		state["inventory"].append(old)
		_enforce_cap(state)
	return true


static func equip_uid(state: Dictionary, hero_idx: int, uid: int) -> bool:
	var item = find_inventory_item(state, uid)
	return item != null and equip(state, hero_idx, item)


static func unequip(state: Dictionary, hero_idx: int, slot: String) -> void:
	var hero: Dictionary = state["heroes"][hero_idx]
	var item = hero["equipment"][slot]
	if item != null:
		hero["equipment"][slot] = null
		state["inventory"].append(item)


static func salvage(state: Dictionary, uid: int) -> float:
	var item = find_inventory_item(state, uid)
	if item == null:
		return 0.0
	_remove_from_inventory(state, uid)
	var gold := Loot.salvage_value(item)
	state["gold"] += gold
	return gold


## Salvages every stored item strictly below `rarity` (set pieces are kept).
static func salvage_below(state: Dictionary, rarity: String) -> float:
	var threshold := DataDB.rarity_order(rarity)
	var total := 0.0
	for item in state["inventory"].duplicate():
		if DataDB.rarity_order(item["rarity"]) < threshold and item.get("set", "") == "":
			total += salvage(state, int(item["uid"]))
	return total


static func find_inventory_item(state: Dictionary, uid: int):
	for item in state["inventory"]:
		if int(item["uid"]) == uid:
			return item
	return null


## Returns true when the relic is new. Duplicates become crystals.
static func receive_relic(state: Dictionary, relic_id: String) -> bool:
	if relic_id in state["relics_owned"]:
		state["crystals"] += 3
		return false
	state["relics_owned"].append(relic_id)
	if state["relics_equipped"].size() < StatCalc.relic_slots(state):
		state["relics_equipped"].append(relic_id)
	return true


static func equip_relic(state: Dictionary, relic_id: String) -> bool:
	if not relic_id in state["relics_owned"] or relic_id in state["relics_equipped"]:
		return false
	if state["relics_equipped"].size() >= StatCalc.relic_slots(state):
		return false
	state["relics_equipped"].append(relic_id)
	return true


static func unequip_relic(state: Dictionary, relic_id: String) -> void:
	state["relics_equipped"].erase(relic_id)


static func _remove_from_inventory(state: Dictionary, uid: int) -> void:
	var inv: Array = state["inventory"]
	for i in inv.size():
		if int(inv[i]["uid"]) == uid:
			inv.remove_at(i)
			return


## Keeps the bag bounded: the weakest non-set items are salvaged first.
static func _enforce_cap(state: Dictionary) -> void:
	var cap := int(DataDB.balance()["inventory_cap"])
	var inv: Array = state["inventory"]
	while inv.size() > cap:
		var worst_idx := -1
		var worst_key := INF
		for i in inv.size():
			var it: Dictionary = inv[i]
			var key := DataDB.rarity_order(it["rarity"]) * 100000.0 + float(it["ilvl"]) + (1e9 if it.get("set", "") != "" else 0.0)
			if key < worst_key:
				worst_key = key
				worst_idx = i
		state["gold"] += Loot.salvage_value(inv[worst_idx])
		inv.remove_at(worst_idx)
