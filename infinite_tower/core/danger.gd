extends RefCounted
## "How hard is the next fight?" Simulates it on a copy of the state with the
## party as it is right now (wounds and mana included) and grades the result.
## Keeps the challenge readable without exposing any numbers.

const DataDB = preload("res://core/data_db.gd")
const TowerGen = preload("res://core/tower_generator.gd")
const Expedition = preload("res://core/expedition.gd")

const Loc = preload("res://core/loc.gd")
const LEVELS := [
	{"name": "Easy", "color": "#7ee07e"},
	{"name": "Fair", "color": "#e8d44d"},
	{"name": "Hard", "color": "#ff9d2a"},
	{"name": "Deadly", "color": "#ff4f4f"},
]


## {level 0..3, name, color, floor}. Non-fight floors grade as Easy.
static func assess(state: Dictionary, floor_num: int) -> Dictionary:
	var info := TowerGen.generate(int(state["seed"]), floor_num)
	if info["enemies"].is_empty():
		return _grade(0, floor_num)
	var copy: Dictionary = state.duplicate(true)
	copy["floor"] = floor_num
	var sim := Expedition.new(copy)
	sim.record_combat_events = false
	sim.floor_info = info
	sim._start_combat()
	sim.combat.run_to_end()
	if not sim.combat.victory:
		return _grade(3, floor_num)
	var left := 0.0
	for u in sim.combat.heroes:
		left += u.hp_ratio() if u.alive else 0.0
	left /= maxf(1.0, sim.combat.heroes.size())
	return _grade(0 if left > 0.6 else (1 if left > 0.3 else 2), floor_num)


static func next_guardian(floor_num: int) -> int:
	var every := int(DataDB.floor_rules()["archetypes"]["guardian_every"])
	return (floor_num / every + 1) * every


static func _grade(level: int, floor_num: int) -> Dictionary:
	var d: Dictionary = LEVELS[level].duplicate()
	d["name"] = Loc.t(d["name"])
	d["level"] = level
	d["floor"] = floor_num
	return d
