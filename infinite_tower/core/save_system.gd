extends RefCounted
## Encrypted local save + deterministic offline progress.
##
## The save is JSON encrypted with FileAccess.open_encrypted_with_pass (AES-256,
## with a built-in MD5 integrity check: tampered files fail to open). Writes go to
## a temp file first and the previous save is kept as a .bak.
## NOTE: the key is baked into the build, so this is tamper-resistance, not DRM.

const DataDB = preload("res://core/data_db.gd")
const GameState = preload("res://core/game_state.gd")
const Expedition = preload("res://core/expedition.gd")
const Progression = preload("res://core/progression.gd")

const SAVE_PATH := "user://stairborn_v2.dat"
const BACKUP_PATH := "user://stairborn_v2.bak"
const TEMP_PATH := "user://stairborn_v2.tmp"
const SAVE_KEY := "stairborn::v1::a7c3f19e5d"


static func save_game(state: Dictionary, path: String = SAVE_PATH, key: String = SAVE_KEY) -> bool:
	state["saved_at"] = int(Time.get_unix_time_from_system())
	var tmp := path.get_basename() + ".tmp"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open_encrypted_with_pass(tmp, FileAccess.WRITE, key)
	if file == null:
		push_error("SaveSystem: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(state))
	file.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	var bak := path.get_basename() + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			dir.remove(bak.get_file())
		dir.rename(path.get_file(), bak.get_file())
	return dir.rename(tmp.get_file(), path.get_file()) == OK


## Returns the migrated state, or {} when no valid save exists (falls back to the .bak).
static func load_game(path: String = SAVE_PATH, key: String = SAVE_KEY) -> Dictionary:
	for candidate in [path, path.get_basename() + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open_encrypted_with_pass(candidate, FileAccess.READ, key)
		if file == null:
			push_warning("SaveSystem: %s is unreadable or tampered" % candidate)
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("heroes"):
			return GameState.migrate(parsed)
	return {}


static func delete_save(path: String = SAVE_PATH) -> void:
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return
	for f in [path, path.get_basename() + ".bak", path.get_basename() + ".tmp"]:
		if FileAccess.file_exists(f):
			dir.remove(f.get_file())


## Seconds of offline time to award (clock rollbacks give nothing, long absences are capped).
static func offline_seconds(state: Dictionary, now_unix: int) -> float:
	var saved := int(state.get("saved_at", 0))
	if saved <= 0:
		return 0.0
	var cap := float(DataDB.balance()["offline_max_hours"]) * 3600.0
	return clampf(float(now_unix - saved), 0.0, cap)


## Runs the real simulation for the time spent away. Up to `offline_sim_cap_seconds`
## are simulated floor by floor; any remainder is paid out at the gold/xp rate the
## party reached, so a 12h absence stays cheap to compute. Deterministic for a
## given (state, seconds).
static func simulate_offline(state: Dictionary, seconds: float) -> Dictionary:
	var report := {
		"seconds": seconds, "floor_start": state["floor"], "floor_end": state["floor"],
		"max_floor_start": state["max_floor"], "gold": 0.0, "kills": 0, "bosses": 0,
		"items": 0, "best_item": {}, "relics": [], "fall_backs": 0, "levels": 0,
		"crystals": 0, "extrapolated_seconds": 0.0,
	}
	if seconds < 1.0:
		return report
	var sim_cap := float(DataDB.balance()["offline_sim_cap_seconds"])
	var simulated := minf(seconds, sim_cap)
	var earned_before := float(state["stats"]["total_gold"])
	var kills_before := int(state["stats"]["kills"])
	var bosses_before := int(state["stats"]["bosses"])
	var crystals_before := int(state["crystals"])
	var levels_before := _total_levels(state)
	var xp_before := _total_xp_value(state)

	var sim := Expedition.new(state)
	sim.record_combat_events = false
	var done := 0.0
	while done < simulated:
		var step := minf(60.0, simulated - done)
		sim.advance(step)
		done += step
		_tally_events(sim.events, report)
		sim.events.clear()
	sim.sync_to_state()

	var remainder := seconds - simulated
	if remainder > 0.0:
		# Pay the rest at the observed income rates, without advancing floors.
		var gold_rate := (float(state["stats"]["total_gold"]) - earned_before) / simulated
		var xp_rate := maxf(_total_xp_value(state) - xp_before, 0.0) / simulated / float(state["heroes"].size())
		var extra_gold := maxf(gold_rate, 0.0) * remainder
		state["gold"] = float(state["gold"]) + extra_gold
		state["stats"]["total_gold"] = float(state["stats"]["total_gold"]) + extra_gold
		Progression.grant_xp(state, xp_rate * remainder)
		report["extrapolated_seconds"] = remainder

	report["floor_end"] = state["floor"]
	report["max_floor_end"] = state["max_floor"]
	report["gold"] = float(state["stats"]["total_gold"]) - earned_before
	report["kills"] = int(state["stats"]["kills"]) - kills_before
	report["bosses"] = int(state["stats"]["bosses"]) - bosses_before
	report["crystals"] = int(state["crystals"]) - crystals_before
	report["levels"] = _total_levels(state) - levels_before
	return report


static func _tally_events(events: Array, report: Dictionary) -> void:
	for ev in events:
		match ev["type"]:
			"loot":
				report["items"] += 1
				var item: Dictionary = ev["item"]
				var best: Dictionary = report["best_item"]
				if best.is_empty() or DataDB.rarity_order(item["rarity"]) > DataDB.rarity_order(best["rarity"]):
					report["best_item"] = item
			"relic":
				if ev["new"]:
					report["relics"].append(ev["id"])
			"fall_back":
				report["fall_backs"] += 1


static func _total_levels(state: Dictionary) -> int:
	var total := 0
	for hero in state["heroes"]:
		total += int(hero["level"])
	return total


## Cumulative XP owned by the party (levels converted back to XP).
static func _total_xp_value(state: Dictionary) -> float:
	var total := 0.0
	for hero in state["heroes"]:
		for lvl in range(1, int(hero["level"])):
			total += Progression.xp_to_next(lvl)
		total += float(hero["xp"])
	return total

