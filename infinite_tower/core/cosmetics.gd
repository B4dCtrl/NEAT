extends RefCounted
## COSMETICS: tower skins, pets and auras. They change only how the climb looks,
## never the stats, so they can be traded freely without breaking the game.
##
## How they are earned (the Bongo Cat / Task Bar Hero loop):
##   - a Climber's Cache every `every_minutes` of real play with the game open,
##     at most `weekly_cap` per week (the supply the market can count on);
##   - the Treasure Imp, when you catch it (its own small weekly cap).
## Duplicates break into Stardust; Stardust crafts any non-legendary cosmetic,
## so legendaries stay scarce. Data: data/cosmetics.json.

const DataDB = preload("res://core/data_db.gd")

const KINDS := ["tower", "pet", "aura"]
const WEEK := 604800


static func rules() -> Dictionary:
	return DataDB.table("cosmetics")


static func items() -> Dictionary:
	return rules()["items"]


static func def(id: String) -> Dictionary:
	return items().get(id, {})


## The cosmetics block of a save, created on first use.
static func box(state: Dictionary) -> Dictionary:
	if not state.has("cosmetics") or typeof(state["cosmetics"]) != TYPE_DICTIONARY:
		state["cosmetics"] = {}
	var c: Dictionary = state["cosmetics"]
	for k in ["owned", "equipped"]:
		if not c.has(k):
			c[k] = {}
	for k in ["dust", "caches", "opened", "week", "week_count", "imp_week_count"]:
		if not c.has(k):
			c[k] = 0
	if not c.has("progress"):
		c["progress"] = 0.0
	return c


static func week_id(unix: int) -> int:
	return int(unix / WEEK)


static func _roll_week(c: Dictionary, unix: int) -> void:
	var w := week_id(unix)
	if int(c["week"]) != w:
		c["week"] = w
		c["week_count"] = 0
		c["imp_week_count"] = 0


## Real play time with the game open. Returns how many caches were earned.
static func tick(state: Dictionary, seconds: float, unix: int) -> int:
	var c := box(state)
	_roll_week(c, unix)
	var cache: Dictionary = rules()["cache"]
	if int(c["week_count"]) >= int(cache["weekly_cap"]):
		return 0
	c["progress"] = float(c["progress"]) + seconds
	var every := float(cache["every_minutes"]) * 60.0
	var got := 0
	while float(c["progress"]) >= every and int(c["week_count"]) < int(cache["weekly_cap"]):
		c["progress"] = float(c["progress"]) - every
		c["week_count"] = int(c["week_count"]) + 1
		c["caches"] = int(c["caches"]) + 1
		got += 1
	if int(c["week_count"]) >= int(cache["weekly_cap"]):
		c["progress"] = 0.0     # time past the cap is not banked for next week
	return got


## Seconds of play until the next cache (-1 when this week's cap is reached).
static func seconds_to_next(state: Dictionary, unix: int) -> float:
	var c := box(state)
	_roll_week(c, unix)
	var cache: Dictionary = rules()["cache"]
	if int(c["week_count"]) >= int(cache["weekly_cap"]):
		return -1.0
	return maxf(0.0, float(cache["every_minutes"]) * 60.0 - float(c["progress"]))


## The Treasure Imp's prize cache (its own weekly cap). Returns true if granted.
static func grant_imp_cache(state: Dictionary, unix: int) -> bool:
	var c := box(state)
	_roll_week(c, unix)
	if int(c["imp_week_count"]) >= int(rules()["cache"]["imp_weekly_cap"]):
		return false
	c["imp_week_count"] = int(c["imp_week_count"]) + 1
	c["caches"] = int(c["caches"]) + 1
	return true


static func roll_rarity(rng: RandomNumberGenerator) -> String:
	var odds: Dictionary = rules()["cache"]["odds"]
	var total := 0.0
	for k in odds:
		total += float(odds[k])
	var roll := rng.randf() * total
	for k in odds:
		roll -= float(odds[k])
		if roll <= 0.0:
			return k
	return "common"


## Opens one cache: returns the cosmetic id ("" when there is no cache).
## Seeded by the save (no reroll by reloading).
static func open_cache(state: Dictionary) -> String:
	var c := box(state)
	if int(c["caches"]) <= 0:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["seed"]) * 131 + int(c["opened"]) * 104729 + 77
	var rarity := roll_rarity(rng)
	var pool := []
	for id in items():
		if items()[id]["rarity"] == rarity:
			pool.append(id)
	if pool.is_empty():
		return ""
	var id: String = pool[rng.randi() % pool.size()]
	c["caches"] = int(c["caches"]) - 1
	c["opened"] = int(c["opened"]) + 1
	c["owned"][id] = int(c["owned"].get(id, 0)) + 1
	return id


static func owned(state: Dictionary, id: String) -> int:
	return int(box(state)["owned"].get(id, 0))


static func equipped(state: Dictionary, kind: String) -> String:
	var id: String = box(state)["equipped"].get(kind, "")
	return id if owned(state, id) > 0 else ""


static func equip(state: Dictionary, id: String) -> bool:
	if owned(state, id) <= 0:
		return false
	box(state)["equipped"][def(id)["kind"]] = id
	return true


static func unequip(state: Dictionary, kind: String) -> void:
	box(state)["equipped"].erase(kind)


## Breaks ONE duplicate into Stardust (the last copy is never destroyed).
static func salvage(state: Dictionary, id: String) -> int:
	var c := box(state)
	if owned(state, id) < 2:
		return 0
	var dust := int(rules()["dust"][def(id)["rarity"]])
	c["owned"][id] = owned(state, id) - 1
	c["dust"] = int(c["dust"]) + dust
	return dust


static func craft_cost(id: String) -> int:
	return int(rules()["craft"].get(def(id).get("rarity", ""), -1))


static func craft(state: Dictionary, id: String) -> bool:
	var cost := craft_cost(id)
	var c := box(state)
	if cost < 0 or int(c["dust"]) < cost:
		return false
	c["dust"] = int(c["dust"]) - cost
	c["owned"][id] = owned(state, id) + 1
	return true


## {unique, total}
static func collection(state: Dictionary) -> Dictionary:
	var n := 0
	for id in items():
		if owned(state, id) > 0:
			n += 1
	return {"unique": n, "total": items().size()}
