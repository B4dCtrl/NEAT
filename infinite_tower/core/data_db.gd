extends RefCounted
## Read-only access to the JSON data tables in res://data.
## Everything balance-related lives in those files, never in code.

const FILES := {
	"classes": "res://data/classes.json",
	"enemies": "res://data/enemies.json",
	"items": "res://data/items.json",
	"floor_rules": "res://data/floor_rules.json",
	"ascension": "res://data/ascension_tree.json",
	"sprites": "res://data/sprites.json",
	"skills": "res://data/skill_tree.json",
	"platform": "res://data/platform.json",
	"quests": "res://data/quests.json",
}

static var _cache: Dictionary = {}


static func table(table_name: String) -> Dictionary:
	if not _cache.has(table_name):
		_cache[table_name] = _load_json(FILES[table_name])
	return _cache[table_name]


static func classes() -> Dictionary:
	return table("classes")


static func enemies() -> Dictionary:
	return table("enemies")["enemies"]


static func bosses() -> Dictionary:
	return table("enemies")["bosses"]


static func enemy_scaling() -> Dictionary:
	return table("enemies")["scaling"]


static func items() -> Dictionary:
	return table("items")


static func rarities() -> Dictionary:
	return table("items")["rarities"]


static func relics() -> Dictionary:
	return table("items")["relics"]


static func sets() -> Dictionary:
	return table("items")["sets"]


static func floor_rules() -> Dictionary:
	return table("floor_rules")


static func balance() -> Dictionary:
	return table("floor_rules")["balance"]


static func ascension_nodes() -> Dictionary:
	return table("ascension")["nodes"]


## Job skill tree nodes of one class, or of every class merged ("" = all;
## node ids are unique across classes).
static func skill_nodes(class_id: String = "") -> Dictionary:
	var classes: Dictionary = table("skills")["classes"]
	if class_id != "":
		return classes.get(class_id, {}).get("nodes", {})
	if not _cache.has("_all_skill_nodes"):
		var all := {}
		for c in classes:
			all.merge(classes[c]["nodes"])
		_cache["_all_skill_nodes"] = all
	return _cache["_all_skill_nodes"]


static func skill_tree(class_id: String) -> Dictionary:
	return table("skills")["classes"].get(class_id, {})


static func platform() -> Dictionary:
	return table("platform")


static func sprites() -> Dictionary:
	return table("sprites")["sprites"]


## Returns an enemy or boss definition by id.
static func unit_def(unit_id: String) -> Dictionary:
	if enemies().has(unit_id):
		return enemies()[unit_id]
	return bosses().get(unit_id, {})


static func rarity_order(rarity: String) -> int:
	return int(rarities().get(rarity, {}).get("order", 0))


static func rarity_by_order(order: int) -> String:
	for key in rarities():
		if int(rarities()[key]["order"]) == order:
			return key
	return "common"


static func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataDB: cannot open %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DataDB: invalid JSON in %s" % path)
		return {}
	return parsed
