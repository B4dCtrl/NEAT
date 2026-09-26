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
var _bench_btn: Button
var _stats: GridContainer
var _train_box: VBoxContainer
var _extra: VBoxContainer
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
	_picker = HeroPicker.new()
	_picker.show_mint = true
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
	_bench_btn = Button.new()
	_bench_btn.focus_mode = Control.FOCUS_NONE
	_bench_btn.text = "Send this hero to the bench"
	_bench_btn.pressed.connect(func(): Game.bench_hero(hero_idx); hero_idx = 0)
	v.add_child(_bench_btn)

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
		["Current HP", UiUtil.pct(float(hero["hp_ratio"]))],
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
	_bench_btn.visible = heroes.size() > 1
	_rebuild_extra()


func _rebuild_extra() -> void:
	var s: Dictionary = Game.state
	# Rebuilt only when something it shows changes, so buttons do not flicker.
	var sig := str([s["bench"].size(), s["heroes"].size(), hero_idx, s["relics_owned"], s["relics_equipped"]])
	if sig == _extra_sig:
		return
	_extra_sig = sig
	for c in _extra.get_children():
		c.queue_free()
	if not s["bench"].is_empty():
		_extra.add_child(Ornate.header_label("Bench"))
		for b in s["bench"].size():
			var h: Dictionary = s["bench"][b]
			var row := HBoxContainer.new()
			var l := Ornate.small_label("%s · %s · Lv %d" % [h["name"], DataDB.classes()[h["class"]]["name"], h["level"]], UiUtil.rarity_color(h.get("rarity", "common")), 12)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var sw := Button.new()
			sw.focus_mode = Control.FOCUS_NONE
			var full: bool = s["heroes"].size() >= Heroes.party_slots()
			sw.text = "Swap in" if full else "Join"
			sw.tooltip_text = "Swaps with the hero selected above" if full else "Joins the party"
			var target: int = hero_idx if full else s["heroes"].size()
			sw.pressed.connect(func(): Game.swap_hero(target, b))
			row.add_child(sw)
			_extra.add_child(row)
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
