extends ScrollContainer
## STATUS: currencies, party portraits (+ mint), the chosen hero's sheet,
## party training, the bench and relics.

const DataDB = preload("res://core/data_db.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const Progression = preload("res://core/progression.gd")
const Heroes = preload("res://core/heroes.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const HeroPicker = preload("res://scenes/ui/menu/hero_picker.gd")

var host
var hero_idx := 0
var _picker
var _money: Label
var _name: Label
var _sub: Label
var _xp: ProgressBar
var _row_btn: Button
var _stats: GridContainer
var _train_box: VBoxContainer
var _extra: VBoxContainer
var _danger: RichTextLabel
var _rest_btn: Button
var _auto_bonfire: CheckBox
var _retreat_label: Label
var _retreat_slider: HSlider
var _dirty := true
var _extra_sig := ""


func mark_dirty() -> void:
	_dirty = true


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if host != null:
		hero_idx = host.hero_idx
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(v)
	_money = Label.new()
	_money.add_theme_color_override("font_color", Ornate.ACCENT)
	v.add_child(_money)
	_danger = RichTextLabel.new()
	_danger.bbcode_enabled = true
	_danger.fit_content = true
	_danger.scroll_active = false
	_danger.add_theme_font_size_override("normal_font_size", 12)
	_danger.tooltip_text = "How the party (as it is now) would fare. Easy / Fair / Hard / Deadly."
	v.add_child(_danger)
	_build_bonfire(v)
	_picker = HeroPicker.new()
	_picker.picked.connect(func(i):
		hero_idx = i
		if host != null:
			host.select_hero(i)
		_dirty = true)
	v.add_child(_picker)

	var head := PanelContainer.new()
	v.add_child(head)
	var hv := VBoxContainer.new()
	head.add_child(hv)
	var top := HBoxContainer.new()
	hv.add_child(top)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	top.add_child(names)
	_name = Ornate.header_label("")
	names.add_child(_name)
	_sub = Ornate.small_label("")
	names.add_child(_sub)
	_row_btn = Button.new()
	_row_btn.focus_mode = Control.FOCUS_NONE
	_row_btn.tooltip_text = "Front row heroes draw most enemy attacks."
	_row_btn.pressed.connect(func():
		var h: Dictionary = Game.state["heroes"][hero_idx]
		Game.set_row(hero_idx, "back" if h["row"] == "front" else "front")
		_dirty = true)
	top.add_child(_row_btn)
	_xp = ProgressBar.new()
	_xp.custom_minimum_size = Vector2(0, 8)
	_xp.show_percentage = false
	hv.add_child(_xp)
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 10)
	_stats.add_theme_constant_override("v_separation", 1)
	hv.add_child(_stats)

	v.add_child(Ornate.header_label("Training (whole party)"))
	_train_box = VBoxContainer.new()
	v.add_child(_train_box)
	for key in DataDB.balance()["training"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): Game.train(key))
		b.set_meta("key", key)
		_train_box.add_child(b)
	var auto := CheckBox.new()
	auto.focus_mode = Control.FOCUS_NONE
	auto.text = "Auto-train with spare gold"
	auto.button_pressed = Game.state["settings"].get("auto_train", true)
	auto.toggled.connect(func(on): Game.set_setting("auto_train", on))
	v.add_child(auto)
	_extra = VBoxContainer.new()
	v.add_child(_extra)

	Game.state_changed.connect(func(): _dirty = true)
	Game.party_changed.connect(func(): _picker.rebuild(); _dirty = true)


func _process(_delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		_refresh()


func _refresh() -> void:
	var s: Dictionary = Game.state
	var heroes: Array = s["heroes"]
	hero_idx = clampi(hero_idx, 0, heroes.size() - 1)
	if _picker.selected != hero_idx:
		_picker.select(hero_idx, false)
	_picker.refresh()
	_money.text = "Gold %s   ·   Souls %s   ·   Crystals %d" % [UiUtil.num(s["gold"]), UiUtil.num(s["souls"]), int(s["crystals"])]
	var hero: Dictionary = heroes[hero_idx]
	var cdef: Dictionary = DataDB.classes()[hero["class"]]
	var st := StatCalc.hero_stats(s, hero)
	_name.text = "%s" % hero["name"]
	_sub.text = "%s · %s potential · Lv %d" % [cdef["name"], String(hero.get("rarity", "common")).capitalize(), hero["level"]]
	_sub.add_theme_color_override("font_color", UiUtil.rarity_color(hero.get("rarity", "common")))
	_row_btn.text = "Front" if hero["row"] == "front" else "Back"
	_xp.max_value = Progression.xp_to_next(int(hero["level"]))
	_xp.value = float(hero["xp"])
	_xp.tooltip_text = "EXP %s / %s" % [UiUtil.num(hero["xp"]), UiUtil.num(_xp.max_value)]
	var magic: bool = st["damage_type"] == "magic"
	var power: float = st["magic_power"] if magic else st["attack"]
	var dps: float = power * st["attack_speed"] * (1.0 + st["crit_chance"] * (st["crit_damage"] - 1.0)) * (1.0 + st.get("damage_pct", 0.0))
	var rows := [
		["Level", str(hero["level"])],
		["EXP", "%s / %s" % [UiUtil.num(hero["xp"]), UiUtil.num(_xp.max_value)]],
		["Power rating", UiUtil.num(StatCalc.power_rating(st))],
		["Basic attack DPS", UiUtil.num(dps)],
		["Max HP", UiUtil.num(st["hp"])],
		["Magic" if magic else "Attack", UiUtil.num(power)],
		["Defense", UiUtil.num(st["defense"])],
		["Attack speed", "%.2f / s" % st["attack_speed"]],
		["Crit chance", UiUtil.pct(st["crit_chance"], 1)],
		["Crit damage", "x%.2f" % st["crit_damage"]],
		["Dodge", UiUtil.pct(st["dodge"], 1)],
		["Lifesteal", UiUtil.pct(st.get("lifesteal", 0.0), 1)],
		["Mana", "%s (+%s/s in fights)" % [UiUtil.num(st["mana"]), String.num(st["mana_regen"], 1)]],
		["Current HP / Mana", "%s / %s" % [UiUtil.pct(float(hero["hp_ratio"])), UiUtil.pct(float(hero.get("mp_ratio", 1.0)))]],
	]
	for c in _stats.get_children():
		c.queue_free()
	for r in rows:
		_stats.add_child(Ornate.small_label(r[0], Ornate.TEXT_DIM, 12))
		var val := Ornate.small_label(r[1], Ornate.TEXT, 12)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats.add_child(val)
	for b in _train_box.get_children():
		var key: String = b.get_meta("key")
		var t: Dictionary = DataDB.balance()["training"][key]
		var cost := Progression.training_cost(s, key)
		b.text = "%s  Lv %d   (%s gold)" % [t["name"], s["training"][key], UiUtil.num(cost)]
		b.disabled = float(s["gold"]) < cost
	_refresh_bonfire()
	_rebuild_extra()


func _rebuild_extra() -> void:
	var s: Dictionary = Game.state
	# Rebuilt only when something it shows changes, so buttons do not flicker.
	var sig := str([s["relics_owned"], s["relics_equipped"]])
	if sig == _extra_sig:
		return
	_extra_sig = sig
	for c in _extra.get_children():
		c.queue_free()
	var slots := StatCalc.relic_slots(s)
	_extra.add_child(Ornate.header_label("Relics %d/%d" % [s["relics_equipped"].size(), slots]))
	var flow := HFlowContainer.new()
	_extra.add_child(flow)
	var relics := DataDB.relics()
	var any := false
	for relic_id in s["relics_owned"]:
		any = true
		var equipped: bool = relic_id in s["relics_equipped"]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = ("● " if equipped else "○ ") + relics[relic_id]["name"]
		b.add_theme_color_override("font_color", UiUtil.rarity_color("relic"))
		b.tooltip_text = relics[relic_id]["description"]
		b.disabled = not equipped and s["relics_equipped"].size() >= slots
		b.pressed.connect(func():
			if equipped:
				Game.unequip_relic(relic_id)
			else:
				Game.equip_relic(relic_id))
		flow.add_child(b)
	if not any:
		flow.add_child(Ornate.small_label("None found yet: bosses and vaults may drop them."))


# ------------------------------------------------------------------ bonfire

func _build_bonfire(v: VBoxContainer) -> void:
	var box := PanelContainer.new()
	v.add_child(box)
	var bv := VBoxContainer.new()
	box.add_child(bv)
	var top := HBoxContainer.new()
	bv.add_child(top)
	var t := Ornate.header_label("Bonfire")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	_rest_btn = Button.new()
	_rest_btn.focus_mode = Control.FOCUS_NONE
	_rest_btn.text = "Rest now"
	_rest_btn.tooltip_text = "Walk back to the last bonfire: full HP and mana, no gold lost.\nThe floors since that bonfire must be climbed again."
	_rest_btn.pressed.connect(func(): Game.request_retreat())
	top.add_child(_rest_btn)
	_auto_bonfire = CheckBox.new()
	_auto_bonfire.focus_mode = Control.FOCUS_NONE
	_auto_bonfire.text = "Auto-rest when the party is hurt"
	_auto_bonfire.toggled.connect(func(on): Game.set_setting("auto_bonfire", on))
	bv.add_child(_auto_bonfire)
	var row := HBoxContainer.new()
	bv.add_child(row)
	_retreat_label = Ornate.small_label("", Ornate.TEXT_DIM, 11)
	_retreat_label.custom_minimum_size = Vector2(118, 0)
	row.add_child(_retreat_label)
	_retreat_slider = HSlider.new()
	_retreat_slider.min_value = 0.1
	_retreat_slider.max_value = 0.7
	_retreat_slider.step = 0.05
	_retreat_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_retreat_slider.focus_mode = Control.FOCUS_NONE
	_retreat_slider.value_changed.connect(func(val): _retreat_label.text = "Rest below %d%% HP" % roundi(val * 100.0))
	_retreat_slider.drag_ended.connect(func(_c): Game.set_setting("retreat_hp", _retreat_slider.value))
	row.add_child(_retreat_slider)
	var loss := roundi(100.0 * float(DataDB.balance().get("fall_gold_loss", 0.0)))
	var note := Ornate.small_label("If the party falls, it drops %d%% of its gold. Resting in time keeps it." % loss, Ornate.TEXT_DIM, 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(note)


func _refresh_bonfire() -> void:
	var s: Dictionary = Game.state
	_auto_bonfire.set_pressed_no_signal(s["settings"].get("auto_bonfire", true))
	var th := float(s["settings"].get("retreat_hp", 0.35))
	if not _retreat_slider.has_focus():
		_retreat_slider.set_value_no_signal(th)
	_retreat_label.text = "Rest below %d%% HP" % roundi(_retreat_slider.value * 100.0)
	var at_fire := int(s["floor"]) <= int(s.get("checkpoint", 1))
	_rest_btn.disabled = at_fire or Game.expedition.retreat_requested
	_rest_btn.text = "Resting after fight" if Game.expedition.retreat_requested else "Rest now"
	var n: Dictionary = Game.danger_next
	var b: Dictionary = Game.danger_boss
	if n.is_empty():
		_danger.text = ""
		return
	_danger.text = "Next floor %d: [color=%s][b]%s[/b][/color]     Guardian %d: [color=%s][b]%s[/b][/color]" % [
		n["floor"], n["color"], n["name"], b.get("floor", 0), b.get("color", "#ffffff"), b.get("name", "?")]
