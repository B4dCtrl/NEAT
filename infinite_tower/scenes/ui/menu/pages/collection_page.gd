extends ScrollContainer
## COLLECTION: Climber's Caches and the cosmetics they hold (tower skins, pets,
## auras). Open caches, equip a look, break duplicates into Stardust and craft
## the pieces you are missing (legendaries cannot be crafted).

const DataDB = preload("res://core/data_db.gd")
const Cosmetics = preload("res://core/cosmetics.gd")
const CosmeticArt = preload("res://scenes/entities/cosmetic_art.gd")
const Loc = preload("res://core/loc.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")

const KIND_TITLES := {"tower": "Tower skins", "pet": "Pets", "aura": "Auras"}

var host
var _caches: Label
var _open_btn: Button
var _timer: Label
var _dust: Label
var _reveal: HBoxContainer
var _reveal_icon: TextureRect
var _reveal_name: Label
var _grids := {}
var _detail: Label
var _equip_btn: Button
var _salvage_btn: Button
var _craft_btn: Button
var _selected := ""
var _sig := ""


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	add_child(v)

	var cache_box := PanelContainer.new()
	v.add_child(cache_box)
	var cv := VBoxContainer.new()
	cache_box.add_child(cv)
	var top := HBoxContainer.new()
	cv.add_child(top)
	_caches = Ornate.header_label("")
	_caches.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_caches)
	_open_btn = Button.new()
	_open_btn.focus_mode = Control.FOCUS_NONE
	_open_btn.text = Loc.t("Open")
	_open_btn.pressed.connect(_open)
	top.add_child(_open_btn)
	_timer = Ornate.small_label("", Ornate.TEXT_DIM, 11)
	_timer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_timer.custom_minimum_size = Vector2(240, 0)
	cv.add_child(_timer)
	_dust = Ornate.small_label("", Ornate.ACCENT, 12)
	cv.add_child(_dust)
	_reveal = HBoxContainer.new()
	_reveal.visible = false
	cv.add_child(_reveal)
	_reveal_icon = TextureRect.new()
	_reveal_icon.custom_minimum_size = Vector2(48, 48)
	_reveal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reveal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reveal_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_reveal.add_child(_reveal_icon)
	_reveal_name = Ornate.header_label("")
	_reveal_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reveal_name.custom_minimum_size = Vector2(180, 0)
	_reveal.add_child(_reveal_name)

	for kind in Cosmetics.KINDS:
		v.add_child(Ornate.header_label(Loc.t(KIND_TITLES[kind])))
		var g := GridContainer.new()
		g.columns = 6
		g.add_theme_constant_override("h_separation", 4)
		g.add_theme_constant_override("v_separation", 4)
		v.add_child(g)
		_grids[kind] = g

	var dbox := PanelContainer.new()
	v.add_child(dbox)
	var dv := VBoxContainer.new()
	dbox.add_child(dv)
	_detail = Ornate.small_label(Loc.t("Select a look to equip it, break a duplicate or craft it."), Ornate.TEXT, 11)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(240, 0)
	dv.add_child(_detail)
	var actions := HBoxContainer.new()
	dv.add_child(actions)
	_equip_btn = _button(actions, Loc.t("Equip"), func(): Game.equip_cosmetic(_selected))
	_salvage_btn = _button(actions, Loc.t("Break duplicate"), func(): Game.salvage_cosmetic(_selected))
	_craft_btn = _button(actions, Loc.t("Craft"), func(): Game.craft_cosmetic(_selected))
	var note := Ornate.small_label(Loc.t("Looks never change stats. Every look is a Steam item: once Stairborn is on Steam they can be traded on the Community Market."), Ornate.TEXT_DIM, 10)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(240, 0)
	v.add_child(note)

	Game.cosmetics_changed.connect(func(): _sig = "")
	Game.cosmetic_obtained.connect(_show_reveal)
	Game.language_changed.connect(func(): _sig = "")


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _open() -> void:
	Game.open_cache()


func _show_reveal(id: String) -> void:
	var d := Cosmetics.def(id)
	_reveal.visible = true
	_reveal_icon.texture = CosmeticArt.icon(id)
	_reveal_name.text = "%s\n%s" % [d["name"], DataDB.rarities()[d["rarity"]]["name"]]
	_reveal_name.add_theme_color_override("font_color", UiUtil.rarity_color(d["rarity"]))
	_selected = id
	_sig = ""


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var s: Dictionary = Game.state
	var c := Cosmetics.box(s)
	var unix := int(Time.get_unix_time_from_system())
	var left := Cosmetics.seconds_to_next(s, unix)
	var cache: Dictionary = Cosmetics.rules()["cache"]
	if left < 0.0:
		_timer.text = Loc.t("Weekly limit reached (%d/%d). New caches next week.") % [int(c["week_count"]), int(cache["weekly_cap"])]
	else:
		_timer.text = Loc.t("Next cache in %s of play (%d/%d this week).") % [UiUtil.duration(left), int(c["week_count"]), int(cache["weekly_cap"])]
	var sig := str([c["caches"], c["dust"], c["owned"], c["equipped"], _selected, Loc.current()])
	if sig == _sig:
		return
	_sig = sig
	var col := Cosmetics.collection(s)
	_caches.text = Loc.t("Climber's Caches: %d") % int(c["caches"])
	_open_btn.disabled = int(c["caches"]) <= 0
	_dust.text = Loc.t("Stardust %d   ·   Collection %d/%d") % [int(c["dust"]), int(col["unique"]), int(col["total"])]
	_rebuild_grids()
	_refresh_detail()


func _rebuild_grids() -> void:
	for kind in _grids:
		for ch in _grids[kind].get_children():
			ch.queue_free()
	var items := Cosmetics.items()
	var ids := items.keys()
	ids.sort_custom(func(a, b): return DataDB.rarity_order(items[a]["rarity"]) < DataDB.rarity_order(items[b]["rarity"]))
	for id in ids:
		var d: Dictionary = items[id]
		var n := Cosmetics.owned(Game.state, id)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(42, 42)
		b.icon = CosmeticArt.icon(id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 30)
		var rim := UiUtil.rarity_color(d["rarity"])
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#1a1410") if n > 0 else Color("#0c0a08")
		sb.border_color = rim if n > 0 else rim.darkened(0.6)
		sb.set_border_width_all(3 if id == _selected else (2 if Cosmetics.equipped(Game.state, d["kind"]) == id else 1))
		if Cosmetics.equipped(Game.state, d["kind"]) == id:
			sb.bg_color = rim.darkened(0.7)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		if n <= 0:
			b.self_modulate = Color(0.15, 0.15, 0.18, 1.0)
		elif n > 1:
			b.text = "x%d" % n
			b.add_theme_font_size_override("font_size", 9)
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.tooltip_text = "%s\n%s · %s%s" % [d["name"], DataDB.rarities()[d["rarity"]]["name"], Loc.t(KIND_TITLES[d["kind"]]),
			("\n" + Loc.t("Owned: %d") % n) if n > 0 else ("\n" + Loc.t("Not found yet"))]
		var sid: String = id
		b.pressed.connect(func(): _selected = sid; _sig = "")
		_grids[d["kind"]].add_child(b)


func _refresh_detail() -> void:
	if _selected == "":
		_equip_btn.disabled = true
		_salvage_btn.disabled = true
		_craft_btn.disabled = true
		return
	var d := Cosmetics.def(_selected)
	var n := Cosmetics.owned(Game.state, _selected)
	var rules := Cosmetics.rules()
	var cost := Cosmetics.craft_cost(_selected)
	var lines := ["%s  [%s]" % [d["name"], DataDB.rarities()[d["rarity"]]["name"]], Loc.t("Owned: %d") % n]
	lines.append(Loc.t("Break a duplicate: +%d Stardust") % int(rules["dust"][d["rarity"]]))
	lines.append(Loc.t("Craft: %d Stardust") % cost if cost >= 0 else Loc.t("Legendary looks cannot be crafted: only caches drop them."))
	_detail.text = "\n".join(lines)
	_detail.add_theme_color_override("font_color", UiUtil.rarity_color(d["rarity"]))
	var on := Cosmetics.equipped(Game.state, d["kind"]) == _selected
	_equip_btn.text = Loc.t("Unequip") if on else Loc.t("Equip")
	_equip_btn.disabled = n <= 0
	_salvage_btn.disabled = n < 2
	_craft_btn.disabled = cost < 0 or int(Cosmetics.box(Game.state)["dust"]) < cost
