extends ScrollContainer
## HEROES: who fights and how new heroes are made, in one place.
##   Party   - the (up to 3) heroes who climb. Click one to select it.
##   Mint    - creates a brand-new random hero (odds shown) for gold.
##   Reserve - heroes waiting on the bench: "Swap in" puts one in the
##             selected party slot (or an empty one).

const DataDB = preload("res://core/data_db.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const Heroes = preload("res://core/heroes.gd")
const Loc = preload("res://core/loc.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const IconTile = preload("res://scenes/ui/menu/icon_tile.gd")

var host
var hero_idx := 0
var _party: VBoxContainer
var _mint_btn: Button
var _mint_info: Label
var _odds: GridContainer
var _reserve: VBoxContainer
var _last_minted := ""
var _sig := ""
var _name_edit: LineEdit


func mark_dirty() -> void:
	_sig = ""


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if host != null:
		hero_idx = host.hero_idx
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(v)

	v.add_child(Ornate.header_label("Party · %d slots" % Heroes.party_slots()))
	var hint := Ornate.small_label("These heroes climb and fight. Click a portrait to select it; a reserve hero swaps in for the selected one.", Ornate.TEXT_DIM, 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(200, 0)
	v.add_child(hint)
	_party = VBoxContainer.new()
	_party.add_theme_constant_override("separation", 3)
	v.add_child(_party)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	v.add_child(name_row)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = Loc.t("Name of the selected hero")
	_name_edit.text_submitted.connect(func(_s): _rename())
	name_row.add_child(_name_edit)
	var name_btn := Button.new()
	name_btn.text = Loc.t("Rename")
	name_btn.focus_mode = Control.FOCUS_NONE
	name_btn.pressed.connect(_rename)
	name_row.add_child(name_btn)

	var mint := PanelContainer.new()
	v.add_child(mint)
	var mv := VBoxContainer.new()
	mint.add_child(mv)
	mv.add_child(Ornate.header_label("Mint a new hero"))
	var how := Ornate.small_label("Creates a random hero: class (Knight, Ranger or Arcanist), name and rarity. Rarer heroes have better stats for life. New heroes join an empty party slot, otherwise the reserve.", Ornate.TEXT, 11)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(200, 0)
	mv.add_child(how)
	_odds = GridContainer.new()
	_odds.columns = 3
	_odds.add_theme_constant_override("h_separation", 10)
	_odds.add_theme_constant_override("v_separation", 0)
	mv.add_child(_odds)
	_mint_btn = Button.new()
	_mint_btn.focus_mode = Control.FOCUS_NONE
	_mint_btn.pressed.connect(_mint)
	mv.add_child(_mint_btn)
	_mint_info = Ornate.small_label("", Ornate.ACCENT, 12)
	_mint_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mint_info.custom_minimum_size = Vector2(200, 0)
	mv.add_child(_mint_info)

	v.add_child(Ornate.header_label("Reserve"))
	_reserve = VBoxContainer.new()
	_reserve.add_theme_constant_override("separation", 3)
	v.add_child(_reserve)

	Game.party_changed.connect(mark_dirty)
	Game.state_changed.connect(_refresh_mint)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var s: Dictionary = Game.state
	var sig := str([hero_idx, s["heroes"].size(), s["bench"].size()] + s["heroes"].map(func(h): return [h["id"], h["level"], h["name"]]) + s["bench"].map(func(h): return [h["id"], h["level"]]))
	if sig != _sig:
		_sig = sig
		_rebuild()


func _rename() -> void:
	var s: Dictionary = Game.state
	if hero_idx < s["heroes"].size():
		Game.rename_hero(s["heroes"][hero_idx]["id"], _name_edit.text)


func _rebuild() -> void:
	var s: Dictionary = Game.state
	hero_idx = clampi(hero_idx, 0, s["heroes"].size() - 1)
	if _name_edit != null and not _name_edit.has_focus():
		_name_edit.text = s["heroes"][hero_idx]["name"]
	for c in _party.get_children():
		c.queue_free()
	for i in Heroes.party_slots():
		if i < s["heroes"].size():
			_party.add_child(_hero_row(s["heroes"][i], i, true))
		else:
			var empty := PanelContainer.new()
			var l := Ornate.small_label("Empty slot — mint a hero below or swap one in from the reserve.", Ornate.TEXT_DIM, 11)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(200, 0)
			empty.add_child(l)
			_party.add_child(empty)
	for c in _reserve.get_children():
		c.queue_free()
	if s["bench"].is_empty():
		var none := Ornate.small_label("Nobody waiting. Minted heroes land here when the party is full.", Ornate.TEXT_DIM, 11)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(200, 0)
		_reserve.add_child(none)
	for b in s["bench"].size():
		_reserve.add_child(_hero_row(s["bench"][b], b, false))
	_odds_table()
	_refresh_mint()


func _hero_row(h: Dictionary, idx: int, in_party: bool) -> Control:
	var cdef: Dictionary = DataDB.classes()[h["class"]]
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	panel.add_child(row)
	var t = IconTile.new()
	t.custom_minimum_size = Vector2(40, 40)
	t.texture = PixelArt.unit_frames(h["class"], cdef["sprite"], {}, false)[0]
	t.fill = Color("#2e1f19")
	t.rim = UiUtil.rarity_color(h.get("rarity", "common")).darkened(0.2)
	t.highlight = in_party and idx == hero_idx
	row.add_child(t)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	var name_l := Ornate.small_label(h["name"], UiUtil.rarity_color(h.get("rarity", "common")), 12)
	name_l.clip_text = true
	info.add_child(name_l)
	var st := StatCalc.hero_stats(Game.state, h)
	var l1 := Ornate.small_label("%s · %s · Lv %d" % [cdef["name"], String(h.get("rarity", "common")).capitalize(), h["level"]], Ornate.TEXT_DIM, 11)
	l1.clip_text = true
	info.add_child(l1)
	var l2 := Ornate.small_label("Power %s" % UiUtil.num(StatCalc.power_rating(st)), Ornate.TEXT_DIM, 11)
	l2.clip_text = true
	info.add_child(l2)
	if in_party:
		t.pressed.connect(func(): _select(idx))
		if Game.state["heroes"].size() > 1:
			var bench := Button.new()
			bench.focus_mode = Control.FOCUS_NONE
			bench.text = "Rest"
			bench.tooltip_text = "Send to the reserve (keeps level and gear)"
			bench.pressed.connect(func(): Game.bench_hero(idx); hero_idx = 0)
			row.add_child(bench)
	else:
		var sw := Button.new()
		sw.focus_mode = Control.FOCUS_NONE
		var full: bool = Game.state["heroes"].size() >= Heroes.party_slots()
		sw.text = "Swap in" if full else "Join"
		var target: int = hero_idx if full else Game.state["heroes"].size()
		sw.tooltip_text = ("Takes the place of %s in the party" % Game.state["heroes"][hero_idx]["name"]) if full else "Joins the empty party slot"
		sw.pressed.connect(func(): Game.swap_hero(target, idx))
		row.add_child(sw)
	return panel


func _select(i: int) -> void:
	hero_idx = i
	if host != null:
		host.select_hero(i)
	_sig = ""


func _odds_table() -> void:
	for c in _odds.get_children():
		c.queue_free()
	var table: Dictionary = DataDB.balance()["hero_rarities"]
	var total := 0.0
	for k in table:
		total += float(table[k]["weight"])
	for k in table:
		_odds.add_child(Ornate.small_label(String(k).capitalize(), UiUtil.rarity_color(k), 11))
		_odds.add_child(Ornate.small_label("%d%%" % roundi(100.0 * float(table[k]["weight"]) / total), Ornate.TEXT, 11))
		_odds.add_child(Ornate.small_label("stats x%.2f" % float(table[k]["potential"]), Ornate.TEXT_DIM, 11))


func _refresh_mint() -> void:
	if _mint_btn == null or not is_visible_in_tree():
		return
	var cost := Heroes.mint_cost(Game.state)
	_mint_btn.text = "Mint hero  (%s gold)" % UiUtil.num(cost)
	var why := Heroes.mint_blocker(Game.state)
	_mint_btn.disabled = why != ""
	if _last_minted == "":
		_mint_info.text = "You have %s gold. Hero #%d costs more than the last (%s)." % [UiUtil.num(Game.state["gold"]), Heroes.total_heroes(Game.state) + 1, why if why != "" else "ready"]


func _mint() -> void:
	var before: int = Game.state["heroes"].size() + Game.state["bench"].size()
	Game.mint_hero()
	var all: Array = Game.state["heroes"] + Game.state["bench"]
	if all.size() > before:
		var h: Dictionary = all.filter(func(x): return x["id"] == _newest_id(all))[0]
		var in_party: bool = Game.state["heroes"].any(func(x): return x["id"] == h["id"])
		var where := "joined the party" if in_party else "is waiting in the reserve"
		_last_minted = h["id"]
		_mint_info.text = "New hero: %s the %s (%s) %s!" % [h["name"], DataDB.classes()[h["class"]]["name"], String(h["rarity"]).capitalize(), where]
		_mint_info.add_theme_color_override("font_color", UiUtil.rarity_color(h["rarity"]))
		Game.sfx_requested.emit("fanfare")
	_sig = ""


static func _newest_id(all: Array) -> String:
	var best := ""
	var best_n := -1
	for h in all:
		var n := int(String(h["id"]).get_slice("_", 1))
		if n > best_n:
			best_n = n
			best = h["id"]
	return best
