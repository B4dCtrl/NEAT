extends RefCounted
## Language packs. Each pack is a flat JSON file in res://data/lang/<code>.json
## ("menu.status": "Status"). A missing key falls back to English, then to the
## key itself, so an incomplete pack never breaks the game. To add a language,
## drop a new <code>.json there and list it in LANGUAGES.
##
## The chosen language is stored outside the accounts (user://language.cfg) so
## the login screen already speaks it.

const CONFIG := "user://language.cfg"
## code -> name in that language (shown in the selectors)
const LANGUAGES := {"en": "English", "pt": "Português", "es": "Español"}

static var lang := ""
static var _packs := {}


static func _ensure() -> void:
	if lang != "":
		return
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG) == OK and LANGUAGES.has(String(cfg.get_value("ui", "lang", ""))):
		lang = String(cfg.get_value("ui", "lang"))
	else:
		var os_lang := OS.get_locale_language()
		lang = os_lang if LANGUAGES.has(os_lang) else "en"


static func current() -> String:
	_ensure()
	return lang


static func set_language(code: String) -> void:
	if not LANGUAGES.has(code):
		return
	_ensure()
	lang = code
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "lang", code)
	cfg.save(CONFIG)


static func _pack(code: String) -> Dictionary:
	if not _packs.has(code):
		var f := FileAccess.open("res://data/lang/%s.json" % code, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		_packs[code] = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _packs[code]


## Translated text for `key`.
static func t(key: String) -> String:
	_ensure()
	var p := _pack(lang)
	if p.has(key):
		return String(p[key])
	var en := _pack("en")
	return String(en.get(key, key))


# ------------------------------------------------------------------ data texts

## JSON keys whose string values are player-facing text (see localize()).
const TEXT_KEYS := ["name", "description", "text", "role", "suffix", "title"]
## Dictionaries of piece names: {slot: name}
const NAME_MAPS := ["pieces", "weapons"]

const STAT_LABEL := {
	"attack_pct": "Attack", "magic_power_pct": "Magic", "hp_pct": "HP", "defense_pct": "Defense",
	"crit_chance": "Crit chance", "crit_damage": "Crit damage", "attack_speed_pct": "Attack speed",
	"dodge": "Dodge", "damage_pct": "Damage", "fire_damage_pct": "Fire damage", "gold_pct": "Gold",
	"drop_pct": "Drop chance", "move_speed_pct": "Climb speed", "lifesteal": "Lifesteal",
	"thorns": "Thorns (reflect)", "regen": "HP regen per second", "mana_regen_pct": "Mana regeneration",
}
const SPECIAL_LABEL := {
	"fire_imbue": "attacks become Fire", "burning_soul": "attacks apply a burn over time",
	"regrowth": "Regrowth: slowly heals", "chain_lightning": "crits chain lightning",
}


## Translates, in place, every player-facing text of a data table (names,
## descriptions, ...). The English original is kept under "<key>_en".
static func localize(node: Variant) -> void:
	if node is Dictionary:
		for key in node.keys():
			var v: Variant = node[key]
			if key in TEXT_KEYS and v is String and v != "":
				node[key + "_en"] = v
				node[key] = t(v)
			elif key in NAME_MAPS and v is Dictionary:
				for k2 in v.keys():
					if v[k2] is String:
						v[k2] = t(v[k2])
			elif v is Dictionary or v is Array:
				localize(v)
	elif node is Array:
		for v in node:
			if v is Dictionary or v is Array:
				localize(v)


## "+10% HP, +12% Attack, attacks become Fire" in the current language.
static func bonus_text(stats: Dictionary, specials: Array) -> String:
	var parts := []
	for k in stats:
		var v := float(stats[k]) * 100.0
		var num := String.num(v, 1)
		if num.ends_with(".0"):
			num = num.substr(0, num.length() - 2)
		parts.append("+%s%% %s" % [num, t(STAT_LABEL.get(k, k))])
	for s in specials:
		parts.append(t(SPECIAL_LABEL.get(s, s)))
	return ", ".join(parts)


## Fraction of the English keys a pack translates (for the language menu).
static func coverage(code: String) -> float:
	var en := _pack("en")
	if en.is_empty():
		return 1.0
	var p := _pack(code)
	var n := 0
	for k in en:
		if p.has(k):
			n += 1
	return float(n) / en.size()
