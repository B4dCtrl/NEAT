extends RefCounted
## The whole persistent game state is a plain Dictionary so it serialises to JSON
## without adapters. This script only builds and migrates that dictionary.

const DataDB = preload("res://core/data_db.gd")

const VERSION := 1
const HISTORY_CAP := 150

const DEFAULT_SETTINGS := {
	"always_on_top": true,
	"dock": "bottom",          # "bottom" | "top"
	"bar_width": 640,          # 0 = full usable screen width
	"bar_height": 150,
	"bar_opacity": 0.0,        # 0 = fully transparent, only the tower floats on the desktop
	"bar_x": -1,               # remembered horizontal position (-1 = near the tray)
	"art_style": "mono",       # "mono" (1-bit) | "color" (biome palettes)
	"fps_taskbar": 30,
	"master_volume": 0.8,
	"notify_glow": true,
	"auto_equip": true,
	"auto_train": true,
	"auto_salvage_below": "uncommon",  # items below this rarity are salvaged on drop
	"show_damage_numbers": true,
}


static func new_game(run_seed: int = 0) -> Dictionary:
	if run_seed == 0:
		run_seed = randi()
	var heroes := []
	var classes := DataDB.classes()
	var uid := 1
	for class_id in ["knight", "ranger", "arcanist"]:
		var hero := new_hero(class_id, classes[class_id])
		var weapon := starter_item(classes[class_id].get("starter_weapon", ""), uid)
		if not weapon.is_empty():
			hero["equipment"]["weapon"] = weapon
			uid += 1
		heroes.append(hero)
	return {
		"version": VERSION,
		"seed": run_seed,
		"rng_state": "",
		"floor": 1,
		"max_floor": 1,
		"best_floor_ever": 1,
		"wall_floor": 0,
		"wall_attempts": 0,
		"gold": 0.0,
		"souls": 0,
		"crystals": 0,
		"heroes": heroes,
		"inventory": [],
		"next_uid": uid,
		"relics_owned": [],
		"relics_equipped": [],
		"training": {"attack": 0, "hp": 0, "defense": 0},
		"ascension": {},
		"ascensions": 0,
		"buffs": [],
		"bestiary": {},
		"history": [],
		"milestones": [],
		"floors_cleared_total": 0,
		"stats": {
			"kills": 0, "bosses": 0, "floors_climbed": 0, "fights_won": 0, "fights_lost": 0,
			"fall_backs": 0, "total_gold": 0.0, "items_found": 0, "relics_found": 0,
			"play_time": 0.0, "damage_by_hero": {},
		},
		"settings": DEFAULT_SETTINGS.duplicate(true),
		"saved_at": 0,
	}


static func new_hero(class_id: String, class_def: Dictionary) -> Dictionary:
	var equipment := {}
	for slot in DataDB.items()["slots"]:
		equipment[slot] = null
	return {
		"id": class_id,
		"class": class_id,
		"name": class_def["default_name"],
		"level": 1,
		"xp": 0.0,
		"row": class_def["default_row"],
		"hp_ratio": 1.0,
		"equipment": equipment,
	}


## A plain common item built straight from a base definition.
static func starter_item(base_id: String, uid: int) -> Dictionary:
	for base in DataDB.items()["bases"]:
		if base["id"] == base_id:
			var stats: Dictionary = base["stats"].duplicate()
			return {"uid": uid, "base": base_id, "name": "Worn " + base["name"], "slot": base["slot"],
				"class": base["class"], "rarity": "common", "ilvl": 1, "stats": stats, "set": ""}
	return {}


## Fills keys added in newer versions so old saves keep loading.
static func migrate(state: Dictionary) -> Dictionary:
	var fresh := new_game(int(state.get("seed", 1)))
	for key in fresh:
		if not state.has(key):
			state[key] = fresh[key]
	for key in fresh["stats"]:
		if not state["stats"].has(key):
			state["stats"][key] = fresh["stats"][key]
	if not state["settings"].has("art_style"):
		# v1 saves used the opaque 54px strip: move them to the floating tower layout.
		for key in ["bar_width", "bar_height", "bar_opacity"]:
			state["settings"][key] = DEFAULT_SETTINGS[key]
	for key in DEFAULT_SETTINGS:
		if not state["settings"].has(key):
			state["settings"][key] = DEFAULT_SETTINGS[key]
	# JSON turns ints into floats: normalise the counters we index with.
	for key in ["seed", "floor", "max_floor", "best_floor_ever", "wall_floor",
			"wall_attempts", "souls", "crystals", "next_uid", "ascensions", "floors_cleared_total"]:
		state[key] = int(state[key])
	for hero in state["heroes"]:
		hero["level"] = int(hero["level"])
		for slot in DataDB.items()["slots"]:
			if not hero["equipment"].has(slot):
				hero["equipment"][slot] = null
	state["rng_state"] = str(state["rng_state"])
	state["milestones"] = state["milestones"].map(func(m): return int(m))
	for key in state["training"]:
		state["training"][key] = int(state["training"][key])
	for key in state["ascension"]:
		state["ascension"][key] = int(state["ascension"][key])
	state["version"] = VERSION
	return state


static func add_history(state: Dictionary, kind: String, text: String) -> void:
	var entry := {"kind": kind, "text": text, "floor": state["floor"], "time": int(Time.get_unix_time_from_system())}
	state["history"].append(entry)
	if state["history"].size() > HISTORY_CAP:
		state["history"].remove_at(0)
