extends RefCounted
## Formatting helpers shared by all views.

const DataDB = preload("res://core/data_db.gd")

const SUFFIXES := ["", "k", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


## 18234 -> "18.2k", 3.4e9 -> "3.40B". Beyond the table: "1.2e45".
static func num(value: float) -> String:
	var v := absf(value)
	var sign := "-" if value < 0.0 else ""
	if v < 1000.0:
		return sign + str(int(v))
	var tier := int(floor(log(v) / log(1000.0)))
	if tier >= SUFFIXES.size():
		return sign + String.num_scientific(v).replace("+", "")
	var scaled := v / pow(1000.0, tier)
	var digits := 2 if scaled < 10.0 else (1 if scaled < 100.0 else 0)
	return sign + String.num(scaled, digits) + SUFFIXES[tier]


static func pct(value: float, digits: int = 0) -> String:
	return String.num(value * 100.0, digits) + "%"


static func rarity_color(rarity: String) -> Color:
	return Color.html(DataDB.rarities().get(rarity, {}).get("color", "#ffffff"))


static func duration(seconds: float) -> String:
	var s := int(seconds)
	if s < 60:
		return "%ds" % s
	if s < 3600:
		return "%dm %02ds" % [s / 60, s % 60]
	return "%dh %02dm" % [s / 3600, (s % 3600) / 60]


## Human-readable stat line for item tooltips ("+12.5% Attack").
static func stat_line(key: String, value: float) -> String:
	var names := {
		"power": "Power (Attack & Magic)",
		"hp": "HP", "attack": "Attack", "defense": "Defense", "magic_power": "Magic Power",
		"attack_speed_pct": "Attack Speed", "crit_chance": "Crit Chance", "crit_damage": "Crit Damage",
		"dodge": "Dodge", "hp_pct": "HP", "attack_pct": "Attack", "defense_pct": "Defense",
		"magic_power_pct": "Magic Power", "damage_pct": "Damage", "fire_damage_pct": "Fire Damage",
		"gold_pct": "Gold Find", "drop_pct": "Drop Chance", "move_speed_pct": "Movement Speed",
		"xp_pct": "XP", "soul_pct": "Souls", "cdr": "Cooldown Reduction",
		"lifesteal": "Lifesteal", "thorns": "Thorns", "regen": "HP regen/s", "mana_regen_pct": "Mana Regen",
	}
	var label: String = names.get(key, key.capitalize())
	if key in ["hp", "attack", "defense", "magic_power", "power"]:
		return "+%s %s" % [num(value), label]
	return "+%s %s" % [pct(value, 1), label]
