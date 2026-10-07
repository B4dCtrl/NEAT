extends VBoxContainer
## SOULS: the Ascension reset and the permanent Soul tree.
## Ascending sends the party back to floor 1 for Souls; Souls buy bonuses
## that never reset (four columns: Founder, Guild, Climb, Fortune).

const DataDB = preload("res://core/data_db.gd")
const Progression = preload("res://core/progression.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const IconTile = preload("res://scenes/ui/menu/icon_tile.gd")
const Loc = preload("res://core/loc.gd")

const COLUMNS := ["Founder", "Guild", "Climb", "Fortune"]
const COL_COLORS := [Color("#6a2c24"), Color("#4a3a1e"), Color("#24456e"), Color("#2d5a2a")]
const ICONS := {
	"founders_might": "helm", "born_again": "heal", "founders_will": "star", "soul_harvest": "skull",
	"guild_discount": "coin", "veterans": "banner", "noble_blood": "burst", "head_start": "boot", "relic_vault": "lock",
	"might": "sword", "vitality": "heart", "bulwark": "shield", "swiftness": "wind",
	"greed": "coin", "starting_purse": "bag", "fortune": "target", "wisdom": "book",
}
const TILE := Vector2(52, 60)

var host
var _souls: Label
var _info: Label
var _ascend: Button
var _confirm: ConfirmationDialog
var _grid: Control
var _tiles := {}
var _sig := ""


func _ready() -> void:
	_souls = Ornate.header_label("")
	add_child(_souls)
	_info = Ornate.small_label("", Ornate.TEXT, 11)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	_ascend = Button.new()
	_ascend.focus_mode = Control.FOCUS_NONE
	_ascend.pressed.connect(func(): _confirm.popup_centered())
	add_child(_ascend)
	_confirm = ConfirmationDialog.new()
	_confirm.title = Loc.t("Ascend?")
	_confirm.dialog_text = Loc.t("The party goes back to the base of the tower.\nLevels, gear, gold and training are lost.\nSouls, Crystals, Gems, heroes and this tree are kept.")
	_confirm.confirmed.connect(func(): Game.ascend())
	add_child(_confirm)

	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	_grid = Control.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.draw.connect(_draw_links)
	_grid.resized.connect(_place)
	scroll.add_child(_grid)
	var nodes := DataDB.ascension_nodes()
	var max_row := 0
	for id in nodes:
		max_row = maxi(max_row, int(nodes[id]["row"]))
		var t = IconTile.new()
		t.custom_minimum_size = TILE
		t.size = TILE
		t.glyph = ICONS.get(id, "star")
		t.fill = COL_COLORS[clampi(int(nodes[id]["col"]), 0, 3)]
		var node_id: String = id
		t.pressed.connect(func():
			Game.buy_ascension_node(node_id)
			Game.sfx_requested.emit("level")
			_sig = "")
		_grid.add_child(t)
		_tiles[id] = t
	_grid.custom_minimum_size = Vector2(0, 22 + (max_row + 1) * (TILE.y + 12))
	Game.state_changed.connect(func(): _sig = "")


func _col_x(c: int) -> float:
	return _grid.size.x * (c + 0.5) / 4.0


func _place() -> void:
	var nodes := DataDB.ascension_nodes()
	for id in _tiles:
		_tiles[id].position = Vector2(_col_x(int(nodes[id]["col"])) - TILE.x * 0.5, 20 + int(nodes[id]["row"]) * (TILE.y + 12))
	_grid.queue_redraw()


func _draw_links() -> void:
	var font := _grid.get_theme_default_font()
	for c in 4:
		var w := font.get_string_size(COLUMNS[c], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		_grid.draw_string(font, Vector2(_col_x(c) - w * 0.5, 12), COLUMNS[c], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Ornate.ACCENT)
	var nodes := DataDB.ascension_nodes()
	for id in nodes:
		for req in nodes[id]["requires"]:
			var a: Vector2 = _tiles[req].position + Vector2(TILE.x * 0.5, TILE.x)
			var b: Vector2 = _tiles[id].position + Vector2(TILE.x * 0.5, 0)
			var ok := Progression.node_level(Game.state, req) >= int(nodes[id]["requires"][req])
			_grid.draw_line(a, b, Ornate.GOLD if ok else Ornate.OUT, 3.0)


func _process(_delta: float) -> void:
	if _sig == "" and is_visible_in_tree():
		_sig = "x"
		_refresh()


func _refresh() -> void:
	var s: Dictionary = Game.state
	var souls := Progression.souls_for_ascension(s)
	var min_floor := int(DataDB.balance()["ascension_min_floor"])
	_souls.text = Loc.t("Souls: %s   ·   Ascensions: %d") % [UiUtil.num(s["souls"]), s["ascensions"]]
	if souls > 0:
		_info.text = Loc.t("Ascending now: +%s Souls (best floor this run: %d). The deeper you climb, the more Souls.") % [UiUtil.num(souls), s["max_floor"]]
	else:
		_info.text = Loc.t("Reach floor %d to Ascend (best this run: %d). Ascending restarts the climb for Souls; Souls buy permanent bonuses below.") % [min_floor, s["max_floor"]]
	_ascend.text = Loc.t("ASCEND  (+%s Souls)") % UiUtil.num(souls)
	_ascend.disabled = souls <= 0
	var nodes := DataDB.ascension_nodes()
	for id in _tiles:
		var n: Dictionary = nodes[id]
		var t = _tiles[id]
		var lvl := Progression.node_level(s, id)
		var cost := Progression.node_cost(s, id)
		var unlocked := Progression.node_unlocked(s, id)
		t.rank_text = "%d/%d" % [lvl, n["max"]]
		t.maxed = lvl >= int(n["max"])
		t.locked = not unlocked
		t.available = unlocked and not t.maxed and int(s["souls"]) >= cost
		var reqs := []
		for req in n["requires"]:
			reqs.append("%s %d" % [nodes[req]["name"], n["requires"][req]])
		t.tooltip_text = "%s  [%d/%d]\n%s\n%s" % [n["name"], lvl, n["max"], n["text"],
			Loc.t("MAX") if t.maxed else (Loc.t("Cost: %d Souls") % cost if unlocked else Loc.t("Requires ") + ", ".join(reqs))]
		t.queue_redraw()
	_grid.queue_redraw()
