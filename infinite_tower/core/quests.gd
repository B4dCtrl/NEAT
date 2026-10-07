extends RefCounted
## Short-term goals that keep the player coming back:
##  - CONTRACTS: three small objectives at a time ("climb 12 floors", "defeat a
##    Guardian"...). Progress is the growth of a stats counter since the contract
##    was taken; a claimed contract is replaced right away by a new one.
##  - DAILY REWARD: one gift per calendar day, better each day of a 7-day streak;
##    missing a day starts the streak over.
## Rewards are mostly the items that speed the climb up (scrolls, warp stones,
## hourglasses), so the grind and the shortcuts feed each other.

const Loc = preload("res://core/loc.gd")
const DataDB = preload("res://core/data_db.gd")
const Loot = preload("res://core/loot_calculator.gd")


static func table() -> Dictionary:
	return DataDB.table("quests")


# ------------------------------------------------------------------ contracts

static func _new_contract(state: Dictionary, avoid: Array) -> Dictionary:
	var pool: Array = table()["contracts"].filter(func(c): return not c["id"] in avoid)
	if pool.is_empty():
		pool = table()["contracts"]
	var n := int(state.get("contracts_made", 0))
	state["contracts_made"] = n + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["seed"]) * 13 + n * 104729 + 7
	var tpl: Dictionary = pool[rng.randi() % pool.size()]
	var amount := int(round(float(tpl["amount"][0]) + float(tpl["amount"][1]) * float(state["max_floor"])))
	return {"id": tpl["id"], "stat": tpl["stat"], "start": _stat(state, tpl["stat"]), "target": maxi(1, amount)}


static func _stat(state: Dictionary, key: String) -> float:
	return float(state["stats"].get(key, 0))


## Makes sure there are `active` contracts.
static func ensure(state: Dictionary) -> void:
	if not state.has("contracts"):
		state["contracts"] = []
	var list: Array = state["contracts"]
	while list.size() < int(table()["active"]):
		list.append(_new_contract(state, list.map(func(c): return c["id"])))


static func template(contract: Dictionary) -> Dictionary:
	for t in table()["contracts"]:
		if t["id"] == contract["id"]:
			return t
	return {}


static func progress(state: Dictionary, contract: Dictionary) -> int:
	return mini(int(contract["target"]), int(_stat(state, contract["stat"]) - float(contract["start"])))


static func is_done(state: Dictionary, contract: Dictionary) -> bool:
	return progress(state, contract) >= int(contract["target"])


static func describe(contract: Dictionary) -> String:
	return String(template(contract).get("text", contract["id"])) % int(contract["target"])


## Claims a finished contract: grants its reward, takes a new one.
## Returns the reward granted ({} if not finished).
static func claim(state: Dictionary, index: int) -> Dictionary:
	ensure(state)
	var list: Array = state["contracts"]
	if index < 0 or index >= list.size() or not is_done(state, list[index]):
		return {}
	var reward: Dictionary = template(list[index]).get("reward", {})
	var granted := grant(state, reward)
	var avoid: Array = list.map(func(c): return c["id"])
	list[index] = _new_contract(state, avoid)
	state["stats"]["contracts_done"] = int(state["stats"].get("contracts_done", 0)) + 1
	return granted


# ------------------------------------------------------------------ rewards

## Gold worth of one floor at the party's best floor (so rewards stay relevant).
static func floor_gold(state: Dictionary) -> float:
	var growth := float(DataDB.enemy_scaling()["gold_growth"])
	return floorf(12.0 * pow(growth, maxi(1, int(state["max_floor"])) - 1))


## Applies a reward dictionary; returns what was actually given (for the UI).
static func grant(state: Dictionary, reward: Dictionary) -> Dictionary:
	var out := {}
	var cons: Dictionary = DataDB.items()["consumables"]
	for k in reward:
		if k == "gold_floors":
			var g := floor_gold(state) * float(reward[k])
			state["gold"] = float(state["gold"]) + g
			out["gold"] = g
		elif k == "crystals":
			state["crystals"] = int(state["crystals"]) + int(reward[k])
			out["crystals"] = int(reward[k])
		elif k == "item":
			var rng := RandomNumberGenerator.new()
			rng.seed = int(state["seed"]) * 5 + int(state["stats"].get("contracts_done", 0)) * 31 + int(state.get("daily_streak", 0))
			var item := Loot.generate_item(rng, state, maxi(1, int(state["max_floor"])), String(reward[k]))
			state["inventory"].append(item)
			out["item"] = item["name"]
		elif cons.has(k):
			state["consumables"][k] = int(state["consumables"].get(k, 0)) + int(reward[k])
			out[k] = int(reward[k])
	return out


static func reward_text(reward: Dictionary, state: Dictionary) -> String:
	var parts := []
	var cons: Dictionary = DataDB.items()["consumables"]
	for k in reward:
		if k == "gold_floors":
			parts.append(Loc.t("%d gold") % int(floor_gold(state) * float(reward[k])))
		elif k == "gold":
			parts.append(Loc.t("%d gold") % int(reward[k]))
		elif k == "crystals":
			parts.append(Loc.t("%d crystals") % int(reward[k]))
		elif k == "item":
			parts.append(Loc.t("%s item") % Loc.t(String(reward[k]).capitalize()) if not reward[k] is String or not " " in String(reward[k]) else String(reward[k]))
		elif cons.has(k):
			parts.append("%d× %s" % [int(reward[k]), cons[k]["name"]])
	return ", ".join(parts)


# ------------------------------------------------------------------ daily

## {day (1-7 of the streak the next claim gives), claimable, reward}
static func daily_status(state: Dictionary, today: String) -> Dictionary:
	var last := String(state.get("daily_last", ""))
	var streak := int(state.get("daily_streak", 0))
	var claimable := last != today
	if claimable and last != "" and last != _yesterday(today):
		streak = 0
	var days: Array = table()["daily"]
	var day := streak % days.size() if claimable else (streak - 1) % days.size()
	return {"day": day + 1, "claimable": claimable, "reward": days[maxi(0, day)], "streak": streak}


static func claim_daily(state: Dictionary, today: String) -> Dictionary:
	var st := daily_status(state, today)
	if not st["claimable"]:
		return {}
	var granted := grant(state, st["reward"])
	state["daily_streak"] = int(st["streak"]) + 1
	state["daily_last"] = today
	return granted


static func today_string() -> String:
	return Time.get_date_string_from_system()


static func _yesterday(today: String) -> String:
	var t := Time.get_unix_time_from_datetime_string(today + "T12:00:00")
	return Time.get_date_string_from_unix_time(t - 86400)
