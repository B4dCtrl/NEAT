extends ScrollContainer
## ADMIN / TEST panel (only exists in test mode, see core/admin.gd): quick
## buttons to reach any part of the game without playing for hours.

const DataDB = preload("res://core/data_db.gd")
const Admin = preload("res://core/admin.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const Loc = preload("res://core/loc.gd")
const Torment = preload("res://core/torment.gd")

var host
const THEME_NAMES := {"climb": "Climb", "boss": "Guardian", "camp": "Bonfire", "fall": "Defeat", "elite": "Elite", "lord": "Tower Lord", "rage": "Rage"}

var _speed_label: Label
var _music_label: Label
var _floor_spin: SpinBox
var _torment_spin: SpinBox
var _reset_btn: Button
var _reset_armed := 0.0


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	var note := Ornate.small_label(Loc.t("Test mode: this save is separate from your real one and cannot trade items."), Ornate.TEXT_DIM, 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(240, 0)
	v.add_child(note)

	_section(v, Loc.t("Time"))
	var row := _row(v)
	for x in [1, 5, 20, 60]:
		_btn(row, "x%d" % x, func(): Admin.set_speed(Game, float(x)))
	_speed_label = Ornate.small_label("", Ornate.ACCENT, 11)
	v.add_child(_speed_label)

	_section(v, Loc.t("Floor"))
	row = _row(v)
	_floor_spin = SpinBox.new()
	_floor_spin.min_value = 2
	_floor_spin.max_value = 999
	_floor_spin.value = 25
	_floor_spin.custom_minimum_size = Vector2(90, 0)
	row.add_child(_floor_spin)
	_btn(row, Loc.t("Go to floor"), func(): Admin.go_to_floor(Game, int(_floor_spin.value)))
	row = _row(v)
	_btn(row, Loc.t("Next guardian"), func(): Admin.next_guardian(Game))
	_btn(row, Loc.t("Heal party"), func(): Admin.heal(Game))
	row = _row(v)
	for f in [20, 50, 100]:
		_btn(row, str(f), func(): Admin.go_to_floor(Game, f))

	_section(v, Loc.t("Resources"))
	row = _row(v)
	_btn(row, Loc.t("+%s gold") % "1k", func(): Admin.add_resource(Game, "gold", 1000.0))
	_btn(row, Loc.t("+%s gold") % "100k", func(): Admin.add_resource(Game, "gold", 100000.0))
	_btn(row, Loc.t("+%s gold") % "10M", func(): Admin.add_resource(Game, "gold", 10000000.0))
	row = _row(v)
	_btn(row, Loc.t("+%d souls") % 50, func(): Admin.add_resource(Game, "souls", 50.0))
	_btn(row, Loc.t("+%d crystals") % 100, func(): Admin.add_resource(Game, "crystals", 100.0))

	_section(v, Loc.t("Heroes"))
	row = _row(v)
	_btn(row, Loc.t("All +10 levels"), func(): Admin.level_heroes(Game, 10))
	_btn(row, Loc.t("All level 50"), func(): Admin.level_heroes(Game, 0, 50))
	row = _row(v)
	_btn(row, Loc.t("Free hero (mint)"), func(): Admin.free_hero(Game))
	row = _row(v)
	_btn(row, Loc.t("3 Common heroes (fusion)"), func(): Admin.give_heroes(Game, "common", 3))
	_btn(row, Loc.t("3 Rare heroes (fusion)"), func(): Admin.give_heroes(Game, "rare", 3))

	_section(v, Loc.t("Items"))
	row = _row(v)
	for r in ["rare", "epic", "legendary", "mythic"]:
		if DataDB.rarities().has(r):
			_btn(row, DataDB.rarities()[r]["name"] + " ×10", func(): Admin.give_items(Game, r, 10))
	row = _row(v)
	_btn(row, Loc.t("Fill the bag"), func(): Admin.fill_bag(Game))
	_btn(row, Loc.t("Supplies +5"), func(): Admin.give_supplies(Game, 5))

	_section(v, Loc.t("Collection and story"))
	row = _row(v)
	_btn(row, Loc.t("+%d caches") % 5, func(): Admin.add_caches(Game, 5))
	_btn(row, Loc.t("+%d stardust") % 500, func(): Admin.add_dust(Game, 500))
	row = _row(v)
	_btn(row, Loc.t("Call the Treasure Imp"), func(): Admin.call_imp(Game))
	_btn(row, Loc.t("All manga chapters"), func(): Admin.unlock_manga(Game))
	row = _row(v)
	_torment_spin = SpinBox.new()
	_torment_spin.min_value = 0
	_torment_spin.max_value = Torment.max_level()
	_torment_spin.value = 3
	_torment_spin.custom_minimum_size = Vector2(70, 0)
	row.add_child(_torment_spin)
	_btn(row, Loc.t("Unlock Torment"), func(): Admin.set_torment(Game, int(_torment_spin.value)))

	_section(v, Loc.t("Music and Fall Back"))
	row = _row(v)
	for t in Audio.track_names():
		_btn(row, Loc.t(String(THEME_NAMES[t])), func(): Audio.force_track(t))
	_btn(row, Loc.t("Automatic"), func(): Audio.force_track(""))
	row = _row(v)
	_btn(row, Loc.t("Test the Fall Back"), func(): Admin.test_fall(Game))
	_music_label = Ornate.small_label("", Ornate.ACCENT, 11)
	v.add_child(_music_label)

	_section(v, Loc.t("Save file"))
	row = _row(v)
	_btn(row, Loc.t("Skip intro"), func(): Admin.skip_intro(Game))
	_reset_btn = _btn(row, Loc.t("Start over"), _on_reset)
	row = _row(v)
	_btn(row, Loc.t("Open save folder"), func(): OS.shell_open(ProjectSettings.globalize_path("user://test")))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_speed_label.text = Loc.t("Speed x%d") % int(Game.time_scale) + "   ·   " + Loc.t("Floor %d") % int(Game.state["floor"])
	_music_label.text = Loc.t("Now playing: %s") % Loc.t(String(THEME_NAMES.get(Audio.current_track(), "Climb")))
	if _reset_armed > 0.0:
		_reset_armed -= delta
		if _reset_armed <= 0.0:
			_reset_btn.text = Loc.t("Start over")


func _on_reset() -> void:
	# Two clicks: wipes the test save and plays the new-player intro again.
	if _reset_armed <= 0.0:
		_reset_armed = 3.0
		_reset_btn.text = Loc.t("Click again to confirm")
		return
	_reset_armed = 0.0
	_reset_btn.text = Loc.t("Start over")
	Game.reset_save()


func _section(parent: Control, text: String) -> void:
	parent.add_child(Ornate.header_label(text))


func _row(parent: Control) -> HFlowContainer:
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 4)
	r.add_theme_constant_override("v_separation", 4)
	parent.add_child(r)
	return r


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
