extends RefCounted
## TORMENT: difficulty tiers chosen by the player (Normal, Torment I..X), in the
## spirit of Diablo's torments and Task Bar Hero's difficulty levels.
## Monsters hit harder and are tougher; gold, XP and loot get better, and only
## Torment drops Lord's Sigils. Each tier unlocks by reaching a floor while
## playing on the tier below. Unlocks survive Ascension; the choice can only be
## changed outside a fight. Numbers live in floor_rules.json -> balance.torment.

const DataDB = preload("res://core/data_db.gd")
const Loc = preload("res://core/loc.gd")
const ROMAN := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]


static func rules() -> Dictionary:
	return DataDB.balance()["torment"]


static func max_level() -> int:
	return int(rules()["levels"])


static func unlocked(state: Dictionary) -> int:
	return clampi(int(state.get("torment_unlocked", 0)), 0, max_level())


static func current(state: Dictionary) -> int:
	return clampi(int(state.get("torment", 0)), 0, unlocked(state))


static func name(level: int) -> String:
	return Loc.t("Normal") if level <= 0 else Loc.t("Torment %s") % ROMAN[mini(level, ROMAN.size() - 1)]


## Floor to reach, while playing on level-1, to unlock `level`.
static func unlock_floor(level: int) -> int:
	return int(rules()["unlock_floor"]) + int(rules()["unlock_step"]) * (level - 1)


## Multipliers applied to every monster of a fight at this level.
static func enemy_mult(level: int) -> Dictionary:
	var r := rules()
	return {
		"hp": pow(float(r["hp_mult"]), level),
		"attack": pow(float(r["attack_mult"]), level),
		"defense": pow(float(r["defense_mult"]), level),
	}


## Party-wide bonuses (merged into StatCalc.party_mods).
static func mods(level: int) -> Dictionary:
	if level <= 0:
		return {}
	var r := rules()
	return {
		"gold_pct": float(r["gold_bonus"]) * level,
		"xp_pct": float(r["xp_bonus"]) * level,
		"drop_pct": float(r["drop_bonus"]) * level,
	}


static func sigil_chance(level: int) -> float:
	return float(rules()["sigil_chance"]) * level


static func apply_enemy(stats: Dictionary, level: int) -> Dictionary:
	if level <= 0:
		return stats
	var m := enemy_mult(level)
	stats["hp"] = float(stats["hp"]) * m["hp"]
	stats["attack"] = float(stats["attack"]) * m["attack"]
	stats["magic_power"] = float(stats["magic_power"]) * m["attack"]
	stats["defense"] = float(stats["defense"]) * m["defense"]
	return stats


## Called when a new floor is reached. Returns the level just unlocked, or 0.
static func check_unlock(state: Dictionary) -> int:
	var nxt := unlocked(state) + 1
	if nxt > max_level() or current(state) != nxt - 1:
		return 0
	if int(state["floor"]) < unlock_floor(nxt):
		return 0
	state["torment_unlocked"] = nxt
	return nxt


static func record_best(state: Dictionary) -> void:
	var best: Dictionary = state.get("torment_best", {})
	var key := str(current(state))
	best[key] = maxi(int(best.get(key, 0)), int(state["floor"]))
	state["torment_best"] = best


static func set_level(state: Dictionary, level: int) -> bool:
	if level < 0 or level > unlocked(state):
		return false
	state["torment"] = level
	return true


## "Monsters +70% HP, +40% damage · +50% gold, +35% XP, +25% drops"
static func describe(level: int) -> String:
	if level <= 0:
		return Loc.t("The tower as it is.")
	var m := enemy_mult(level)
	var b := mods(level)
	return Loc.t("Monsters: x%.1f HP, x%.1f damage. Rewards: +%d%% gold, +%d%% XP, +%d%% drops, Lord's Sigils.") % [
		m["hp"], m["attack"], roundi(b["gold_pct"] * 100.0), roundi(b["xp_pct"] * 100.0), roundi(b["drop_pct"] * 100.0)]
