extends VBoxContainer
## FUSION: spare heroes of one rarity become one hero of the next rarity.
## Shared by the HEROES panel and the Party tab. Pick which rarity to fuse and
## which hero to keep (it carries its level, gear and skills over); the others
## are consumed. Two clicks, so nothing is lost by accident.

const DataDB = preload("res://core/data_db.gd")
const Heroes = preload("res://core/heroes.gd")
const Loc = preload("res://core/loc.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")

var _hint: Label
var _group_pick: OptionButton
var _keep_pick: OptionButton
var _preview: Label
var _result: Label
var _btn: Button
var _groups: Array = []
var _sig := ""
var _armed := 0.0
var _want_rarity := ""
var _want_keep := ""


func _ready() -> void:
	add_theme_constant_override("separation", 3)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(Ornate.header_label(Loc.t("Fuse heroes")))
	_hint = _wrapped("", Ornate.TEXT, 11)
	_group_pick = OptionButton.new()
	_group_pick.focus_mode = Control.FOCUS_NONE
	_group_pick.item_selected.connect(func(_i): _want_keep = ""; _group_changed())
	add_child(_group_pick)
	_keep_pick = OptionButton.new()
	_keep_pick.focus_mode = Control.FOCUS_NONE
	_keep_pick.item_selected.connect(func(i): _want_keep = String(_keep_pick.get_item_metadata(i)); _update_preview())
	add_child(_keep_pick)
	_preview = _wrapped("", Ornate.TEXT_DIM, 11)
	_btn = Button.new()
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.pressed.connect(_on_fuse)
	add_child(_btn)
	_result = _wrapped("", Ornate.ACCENT, 12)
	Game.party_changed.connect(func(): _sig = "")
	Game.state_changed.connect(_update_preview)
	_refresh()


func _wrapped(text: String, color: Color, size: int) -> Label:
	var l := Ornate.small_label(text, color, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	add_child(l)
	return l


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _armed > 0.0:
		_armed -= delta
		if _armed <= 0.0:
			_update_preview()
	var s: Dictionary = Game.state
	var sig := str(Heroes.fusable(s).map(func(h): return [h["id"], h["rarity"], h["level"], h["name"]]))
	if sig != _sig:
		_sig = sig
		_refresh()


## Rebuilds the two drop-downs from the heroes you own.
func _refresh() -> void:
	_groups = Heroes.fusion_groups(Game.state)
	var n := Heroes.fusion_count()
	_hint.text = Loc.t("Fuse %d heroes of the same rarity into one hero of the next rarity. You keep the one you choose, with its level, gear and skills; the others are consumed and their gear goes back to the bag. The Stairborn cannot be fused.") % n
	_group_pick.clear()
	var pick := 0
	for i in _groups.size():
		var g: Dictionary = _groups[i]
		_group_pick.add_item(Loc.t("%d× %s → %s  (%s gold)") % [n, Loc.t(String(g["rarity"]).capitalize()), Loc.t(String(g["to"]).capitalize()), UiUtil.num(float(g["fee"]))])
		_group_pick.set_item_metadata(i, g["rarity"])
		if g["rarity"] == _want_rarity:
			pick = i
	var has := not _groups.is_empty()
	_group_pick.visible = has
	_keep_pick.visible = has
	_btn.visible = has
	_preview.visible = has
	if has:
		_group_pick.select(pick)
		_group_changed()
	else:
		_hint.text += "\n" + _counts_text()


func _counts_text() -> String:
	var counts := Heroes.fusion_counts(Game.state)
	var bits := []
	for r in DataDB.balance()["hero_rarities"]:
		if int(counts.get(r, 0)) > 0:
			bits.append("%s ×%d" % [Loc.t(String(r).capitalize()), int(counts[r])])
	if bits.is_empty():
		return Loc.t("You have no heroes to fuse yet.")
	return Loc.t("You have: %s") % ", ".join(bits)


func _group_changed() -> void:
	if _groups.is_empty():
		return
	var g: Dictionary = _groups[maxi(0, _group_pick.selected)]
	_want_rarity = g["rarity"]
	_keep_pick.clear()
	var sel := 0
	for i in g["heroes"].size():
		var h: Dictionary = g["heroes"][i]
		var where := Loc.t("party") if Heroes.in_party(Game.state, h) else Loc.t("reserve")
		_keep_pick.add_item(Loc.t("Keep %s · %s · %s · %s") % [h["name"], DataDB.classes()[h["class"]]["name"], UiUtil.lv(int(h["level"])), where])
		_keep_pick.set_item_metadata(i, h["id"])
		if h["id"] == _want_keep:
			sel = i
	_keep_pick.select(sel)
	_want_keep = String(_keep_pick.get_item_metadata(sel))
	_update_preview()


func _plan() -> Dictionary:
	if _want_rarity == "":
		return {}
	return Heroes.fusion_plan(Game.state, _want_rarity, _want_keep)


func _update_preview() -> void:
	if _btn == null or not _btn.visible:
		return
	var plan := _plan()
	var why := Heroes.fusion_blocker(Game.state, plan)
	if plan.is_empty():
		_preview.text = ""
		_btn.disabled = true
		return
	var keep: Dictionary = plan["keep"]
	var burn: Array = plan["burn"].map(func(b): return "%s (%s)" % [b["name"], UiUtil.lv(int(b["level"]))])
	var potential := float(DataDB.balance()["hero_rarities"][plan["to"]]["potential"])
	_preview.text = Loc.t("%s becomes %s (stats ×%.2f).") % [keep["name"], Loc.t(String(plan["to"]).capitalize()), potential]
	_preview.text += "\n" + Loc.t("Fused away: %s.") % ", ".join(burn)
	_preview.add_theme_color_override("font_color", UiUtil.rarity_color(plan["to"]))
	_btn.disabled = why != ""
	if _armed > 0.0:
		_btn.text = Loc.t("Click again to fuse")
	elif why != "":
		_btn.text = Loc.t("Fuse  (%s gold)") % UiUtil.num(float(plan["fee"]))
		_btn.tooltip_text = why
	else:
		_btn.text = Loc.t("Fuse  (%s gold)") % UiUtil.num(float(plan["fee"]))
		_btn.tooltip_text = ""


func _on_fuse() -> void:
	if _armed <= 0.0:
		_armed = 3.0
		_update_preview()
		return
	_armed = 0.0
	var plan := Game.fuse_heroes(_want_rarity, _want_keep)
	if plan.is_empty():
		return
	var keep: Dictionary = plan["keep"]
	_want_keep = ""
	_result.text = Loc.t("%s is now %s!") % [keep["name"], Loc.t(String(plan["to"]).capitalize())]
	if int(plan.get("returned_items", 0)) > 0:
		_result.text += " " + Loc.t("%d items went back to the bag.") % int(plan["returned_items"])
	_result.add_theme_color_override("font_color", UiUtil.rarity_color(plan["to"]))
	_sig = ""
