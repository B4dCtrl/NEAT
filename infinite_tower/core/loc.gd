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
