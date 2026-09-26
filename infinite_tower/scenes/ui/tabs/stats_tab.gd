extends MarginContainer
## Live damage meter (DPS per hero) and lifetime statistics.

const DataDB = preload("res://core/data_db.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")

const HERO_COLORS := [Color("#3d6fd1"), Color("#3f8f4a"), Color("#7a3fc2")]

var _meter: Control
var _totals: Label
var _general: Label
var _refresh_left := 0.0


func _ready() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	var t := Label.new()
	t.text = "Damage meter (current / last fight)"
	left.add_child(t)
	_meter = Control.new()
	_meter.custom_minimum_size = Vector2(0, 120)
	_meter.draw.connect(_draw_meter)
	left.add_child(_meter)
	_totals = Label.new()
	left.add_child(_totals)
	_general = Label.new()
	_general.custom_minimum_size = Vector2(300, 0)
	h.add_child(_general)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_meter.queue_redraw()
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = 0.5
	var s: Dictionary = Game.state
	var st: Dictionary = s["stats"]
	var lines := ["Lifetime damage:"]
	for hero in s["heroes"]:
		lines.append("  %s: %s" % [hero["name"], UiUtil.num(float(st["damage_by_hero"].get(hero["id"], 0.0)))])
	_totals.text = "\n".join(lines)
	_general.text = "\n".join([
		"Time played: %s" % UiUtil.duration(st["play_time"]),
		"Floors climbed: %d" % st["floors_climbed"],
		"Best floor ever: %d" % s["best_floor_ever"],
		"Monsters slain: %d" % st["kills"],
		"Guardians defeated: %d" % st["bosses"],
		"Fights won / lost: %d / %d" % [st["fights_won"], st["fights_lost"]],
		"Fall Backs: %d" % st["fall_backs"],
		"Gold earned: %s" % UiUtil.num(st["total_gold"]),
		"Items found: %d" % st["items_found"],
		"Relics found: %d / %d" % [s["relics_owned"].size(), DataDB.relics().size()],
		"Ascensions: %d" % s["ascensions"],
	])


## DPS of the live fight when there is one, otherwise the last finished fight.
func _dps() -> Array:
	var exp = Game.expedition
	var out := [0.0, 0.0, 0.0]
	if exp.combat != null and exp.phase == "combat" and exp.combat.time > 0.5:
		for u in exp.combat.heroes:
			out[u.index] = u.damage_dealt / exp.combat.time
	else:
		var lf: Dictionary = exp.last_fight
		var t := maxf(float(lf.get("time", 0.0)), 0.1)
		for i in Game.state["heroes"].size():
			out[i] = float(lf.get("damage", {}).get(Game.state["heroes"][i]["id"], 0.0)) / t
	return out


func _draw_meter() -> void:
	var dps := _dps()
	var top: float = maxf(dps.max(), 1.0)
	var total: float = dps[0] + dps[1] + dps[2]
	var font := get_theme_default_font()
	var row_h := _meter.size.y / 3.0
	for i in 3:
		var y := i * row_h + 4.0
		var w: float = (_meter.size.x - 160.0) * dps[i] / top
		_meter.draw_rect(Rect2(120, y, _meter.size.x - 160.0, row_h - 10.0), Color(1, 1, 1, 0.05))
		_meter.draw_rect(Rect2(120, y, w, row_h - 10.0), HERO_COLORS[i])
		var hero: Dictionary = Game.state["heroes"][i]
		_meter.draw_string(font, Vector2(0, y + row_h * 0.55), hero["name"], HORIZONTAL_ALIGNMENT_LEFT, 110, 14)
		var share: float = dps[i] / total if total > 0.0 else 0.0
		_meter.draw_string(font, Vector2(126, y + row_h * 0.55), "%s DPS  (%s)" % [UiUtil.num(dps[i]), UiUtil.pct(share)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
