extends Control
## EXPEDITION MODE: the full RPG management window.

signal collapse_requested()

const DataDB = preload("res://core/data_db.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")

@onready var stage: Control = %Stage
@onready var status_label: Label = %StatusLabel
@onready var buffs_label: Label = %BuffsLabel
@onready var currencies: HBoxContainer = %Currencies
@onready var offline_dialog: AcceptDialog = %OfflineDialog

var _currency_labels := {}


func _ready() -> void:
	%Title.text = ProjectSettings.get_setting("application/config/name", "STAIRBORN")
	%CollapseButton.pressed.connect(func(): collapse_requested.emit())
	for c in [["floor", "Max floor"], ["coin", "Gold"], ["soul", "Souls"], ["crystal", "Crystals"]]:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.tooltip_text = c[1]
		var icon := TextureRect.new()
		icon.texture = PixelArt.icon(c[0])
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var lbl := Label.new()
		box.add_child(icon)
		box.add_child(lbl)
		currencies.add_child(box)
		_currency_labels[c[0]] = lbl
	Game.state_changed.connect(_refresh)
	_refresh()


func on_opened() -> void:
	_refresh()
	if not Game.offline_report.is_empty():
		_show_offline_report(Game.offline_report)
		Game.clear_offline_report()


func _refresh() -> void:
	if not visible:
		return
	var s: Dictionary = Game.state
	_currency_labels["floor"].text = str(s["max_floor"])
	_currency_labels["coin"].text = UiUtil.num(s["gold"])
	_currency_labels["soul"].text = UiUtil.num(s["souls"])
	_currency_labels["crystal"].text = str(s["crystals"])
	var exp = Game.expedition
	var info: Dictionary = exp.floor_info
	var biome: String = info.get("biome_name", "")
	var phase_text := {"walk": "Climbing", "intro": "A Guardian appears!", "combat": "Fighting", "pause": "Catching breath"}
	var line := "Floor %d  ·  %s  ·  %s" % [s["floor"], biome, phase_text.get(exp.phase, "")]
	if exp.phase == "pause" and exp.after_pause == "walk":
		line = "Floor %d  ·  FALL BACK! Regrouping..." % s["floor"]
	if int(s["wall_floor"]) > 0:
		line += "   |   Wall: floor %d (x%d)" % [s["wall_floor"], s["wall_attempts"]]
	status_label.text = line
	var buffs := []
	for b in s["buffs"]:
		buffs.append("%s (%d)" % [b["name"], b["floors_left"]])
	buffs_label.text = "  ".join(buffs)


func _show_offline_report(r: Dictionary) -> void:
	var lines := []
	lines.append("You were away for %s." % UiUtil.duration(r["seconds"]))
	lines.append("")
	lines.append("Floor %d  ->  %d   (best %d)" % [r["floor_start"], r["floor_end"], r["max_floor_end"]])
	lines.append("Gold earned: %s" % UiUtil.num(r["gold"]))
	lines.append("Monsters slain: %d   Guardians: %d" % [r["kills"], r["bosses"]])
	lines.append("Items found: %d   Hero levels: +%d" % [r["items"], r["levels"]])
	if r["fall_backs"] > 0:
		lines.append("Fall Backs: %d" % r["fall_backs"])
	if not r["best_item"].is_empty():
		lines.append("Best find: %s [%s]" % [r["best_item"]["name"], DataDB.rarities()[r["best_item"]["rarity"]]["name"]])
	for relic_id in r["relics"]:
		lines.append("RELIC: %s!" % DataDB.relics()[relic_id]["name"])
	offline_dialog.dialog_text = "\n".join(lines)
	offline_dialog.popup_centered()
