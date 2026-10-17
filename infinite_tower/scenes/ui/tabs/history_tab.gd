extends MarginContainer
## Expedition log: bosses, relics, legendary finds, fall backs, ascensions.

const Loc = preload("res://core/loc.gd")

const KIND_COLORS := {
	"boss": "#ff6b6b", "relic": "#b388ff", "loot": "#ff9d2a", "fall": "#9aa4b2",
	"ascension": "#7fe8ff", "milestone": "#7fe8ff", "offline": "#5fd35f", "info": "#e6e2d3",
}

var _log: RichTextLabel
var _last_size := -1
var _tz := 0                # seconds to add to UTC for the player's clock


func _ready() -> void:
	_tz = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = false
	add_child(_log)
	visibility_changed.connect(func(): _last_size = -1)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var history: Array = Game.state["history"]
	var marker := history.size() * 100000 + (int(history[-1]["time"]) % 100000 if not history.is_empty() else 0)
	if marker == _last_size:
		return
	_last_size = marker
	var lines := []
	for i in range(history.size() - 1, -1, -1):
		var e: Dictionary = history[i]
		var d := Time.get_datetime_dict_from_unix_time(int(e["time"]) + _tz)
		# "{day}/{month}" in Portuguese and Spanish, "{month}/{day}" in English.
		var when := Loc.t("{month}/{day} {time}").format({"day": "%02d" % d["day"], "month": "%02d" % d["month"], "time": "%02d:%02d" % [d["hour"], d["minute"]]})
		lines.append("[color=#5a566a]%s  %s[/color]  [color=%s]%s[/color]" % [when, Loc.t("Fl. %d") % int(e["floor"]), KIND_COLORS.get(e["kind"], "#e6e2d3"), e["text"]])
	_log.text = "\n".join(lines)
