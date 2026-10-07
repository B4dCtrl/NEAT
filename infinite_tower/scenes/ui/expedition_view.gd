extends Control
## EXPEDITION MODE: the full RPG management window.

signal collapse_requested()

const DataDB = preload("res://core/data_db.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const Loc = preload("res://core/loc.gd")

@onready var stage: Control = %Stage
@onready var status_label: Label = %StatusLabel
@onready var buffs_label: Label = %BuffsLabel
@onready var currencies: HBoxContainer = %Currencies
@onready var offline_dialog: AcceptDialog = %OfflineDialog

var _currency_labels := {}
var _camp_btn: Button


## Texts that live in the scene file or are named after nodes.
func _apply_texts() -> void:
	%Subtitle.text = Loc.t("The Infinite Tower")
	%CollapseButton.text = "  " + Loc.t("Taskbar Mode") + "  "
	%CollapseButton.tooltip_text = Loc.t("Back to the taskbar (Esc / Tab)")
	offline_dialog.title = Loc.t("While you were away...")
	offline_dialog.ok_button_text = Loc.t("Keep climbing")
	var tabs: TabContainer = $Margin/VBox/Tabs
	for i in tabs.get_child_count():
		tabs.set_tab_title(i, Loc.t(tabs.get_child(i).name))


func _ready() -> void:
	%Title.text = ProjectSettings.get_setting("application/config/name", "STAIRBORN")
	%CollapseButton.pressed.connect(func(): collapse_requested.emit())
	var help := Button.new()
	help.text = " ? "
	help.focus_mode = Control.FOCUS_NONE
	help.tooltip_text = Loc.t("How to play")
	help.pressed.connect(func(): Game.story_requested.emit("tutorial"))
	%CollapseButton.get_parent().add_child(help)
	%CollapseButton.get_parent().move_child(help, %CollapseButton.get_index())
	for c in [["floor", Loc.t("Max floor")], ["coin", Loc.t("Gold")], ["soul", Loc.t("Souls")], ["crystal", Loc.t("Crystals")]]:
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
	# Bonfire camping: stop at the next bonfire to rearrange gear, then move on.
	_camp_btn = Button.new()
	_camp_btn.focus_mode = Control.FOCUS_NONE
	_camp_btn.pressed.connect(func():
		if Game.expedition.is_camping():
			Game.leave_camp()
		else:
			Game.camp_at_next_bonfire(not Game.state["settings"].get("camp_at_bonfire", false))
		_refresh())
	%StatusLabel.get_parent().add_child(_camp_btn)
	Game.state_changed.connect(_refresh)
	Game.language_changed.connect(_apply_texts)
	_apply_texts()
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
	var phase_text := {"walk": Loc.t("Climbing"), "intro": Loc.t("A Guardian appears!"), "combat": Loc.t("Fighting"), "pause": Loc.t("Catching breath"), "camp": Loc.t("Camping at the bonfire")}
	var line := Loc.t("Floor %d  ·  %s  ·  %s") % [s["floor"], biome, phase_text.get(exp.phase, "")]
	if exp.phase == "pause" and exp.after_pause == "walk":
		line = Loc.t("FALL BACK! Tumbling down to the bonfire on floor %d...") % s["floor"]
	line += Loc.t("   |   Checkpoint: floor %d") % int(s.get("checkpoint", 1))
	if int(s["wall_floor"]) > 0:
		line += Loc.t("   |   Wall: floor %d (x%d)") % [s["wall_floor"], s["wall_attempts"]]
	status_label.text = line
	var buffs := []
	for b in s["buffs"]:
		buffs.append("%s (%d)" % [b["name"], b["floors_left"]])
	buffs_label.text = "  ".join(buffs)
	if exp.is_camping():
		_camp_btn.text = Loc.t("Leave camp ▶")
	elif s["settings"].get("camp_at_bonfire", false):
		_camp_btn.text = Loc.t("Will camp at next bonfire ✓")
	else:
		_camp_btn.text = Loc.t("Camp at next bonfire")


func _show_offline_report(r: Dictionary) -> void:
	var lines := []
	lines.append(Loc.t("You were away for %s.") % UiUtil.duration(r["seconds"]))
	lines.append("")
	lines.append(Loc.t("Floor %d  ->  %d   (best %d)") % [r["floor_start"], r["floor_end"], r["max_floor_end"]])
	lines.append(Loc.t("Gold earned: %s") % UiUtil.num(r["gold"]))
	lines.append(Loc.t("Monsters slain: %d   Guardians: %d") % [r["kills"], r["bosses"]])
	lines.append(Loc.t("Items found: %d   Hero levels: +%d") % [r["items"], r["levels"]])
	if r["fall_backs"] > 0:
		lines.append(Loc.t("Fall Backs: %d") % r["fall_backs"])
	if not r["best_item"].is_empty():
		lines.append(Loc.t("Best find: %s [%s]") % [r["best_item"]["name"], DataDB.rarities()[r["best_item"]["rarity"]]["name"]])
	for relic_id in r["relics"]:
		lines.append(Loc.t("GEM: %s!") % DataDB.relics()[relic_id]["name"])
	offline_dialog.dialog_text = "\n".join(lines)
	offline_dialog.popup_centered()
