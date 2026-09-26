extends VBoxContainer
## TALENTS: the per-hero talent tree. A red level gauge on the left shows the
## level gates of each row; three columns (Might / Guard / Cunning) of icons
## with ranks. Click an icon to spend a point.

const DataDB = preload("res://core/data_db.gd")
const Heroes = preload("res://core/heroes.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const IconTile = preload("res://scenes/ui/menu/icon_tile.gd")
const HeroPicker = preload("res://scenes/ui/menu/hero_picker.gd")

const BRANCH_COLORS := {"might": Color("#7a2a22"), "guard": Color("#24456e"), "cunning": Color("#2d5a2a")}
const ROW_H := 62.0
const GAUGE_W := 34.0

var host
var hero_idx := 0
var _picker
var _points: Label
var _auto: CheckBox
var _tree: Control
var _tiles := {}
var _dirty := true


func mark_dirty() -> void:
	_dirty = true


func _ready() -> void:
	if host != null:
		hero_idx = host.hero_idx
	_picker = HeroPicker.new()
	_picker.badge = func(h: Dictionary) -> String:
		var n := Heroes.skill_points_free(h)
		return "%d talent point%s to spend" % [n, "" if n == 1 else "s"] if n > 0 else ""
	_picker.picked.connect(func(i):
		hero_idx = i
		if host != null:
			host.select_hero(i)
		_dirty = true)
	add_child(_picker)
	var bar := HBoxContainer.new()
	add_child(bar)
	_points = Ornate.header_label("")
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_points)
	var reset := Button.new()
	reset.focus_mode = Control.FOCUS_NONE
	reset.text = "Reset"
	reset.tooltip_text = "Refund every talent point of this hero"
	reset.pressed.connect(func(): Game.reset_skills(hero_idx))
	bar.add_child(reset)
	_auto = CheckBox.new()
	_auto.focus_mode = Control.FOCUS_NONE
	_auto.text = "Spend points automatically"
	_auto.toggled.connect(func(on): Game.set_setting("auto_skills", on))
	add_child(_auto)

	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(frame)
	_tree = Control.new()
	_tree.custom_minimum_size = Vector2(0, ROW_H * 4 + 20)
	_tree.draw.connect(_draw_tree)
	_tree.resized.connect(_place_tiles)
	frame.add_child(_tree)
	var tree: Dictionary = DataDB.table("skills")
	for id in tree["nodes"]:
		var n: Dictionary = tree["nodes"][id]
		var t = IconTile.new()
		t.custom_minimum_size = Vector2(44, 56)
		t.size = t.custom_minimum_size
		t.glyph = n.get("icon", "star")
		t.fill = BRANCH_COLORS.get(n["branch"], Color("#5a2a24"))
		var node_id: String = id
		t.pressed.connect(func():
			Game.learn_skill(hero_idx, node_id)
			Game.sfx_requested.emit("level"))
		_tree.add_child(t)
		_tiles[id] = t
	Game.state_changed.connect(func(): _dirty = true)
	Game.party_changed.connect(func(): _picker.rebuild(); _dirty = true)


func _columns() -> Array:
	return DataDB.table("skills")["branches"].keys()


func _col_x(col: int) -> float:
	var usable := _tree.size.x - GAUGE_W
	return GAUGE_W + usable * (col + 0.5) / 3.0


func _place_tiles() -> void:
	var nodes := DataDB.skill_nodes()
	var cols := _columns()
	for id in _tiles:
		var n: Dictionary = nodes[id]
		var t = _tiles[id]
		t.position = Vector2(_col_x(cols.find(n["branch"])) - 22.0, 18.0 + int(n["row"]) * ROW_H)
	_tree.queue_redraw()


func _draw_tree() -> void:
	var nodes := DataDB.skill_nodes()
	var cols := _columns()
	var font := _tree.get_theme_default_font()
	var names: Dictionary = DataDB.table("skills")["branches"]
	for c in cols.size():
		var label: String = names[cols[c]]
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		_tree.draw_string(font, Vector2(_col_x(c) - w * 0.5, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Ornate.ACCENT)
	# prerequisite links
	for id in nodes:
		for req in nodes[id]["requires"]:
			var a: Vector2 = _tiles[req].position + Vector2(22, 44)
			var b: Vector2 = _tiles[id].position + Vector2(22, 0)
			var hero := _hero()
			var ok := hero.is_empty() or Heroes.skill_rank(hero, req) >= int(nodes[id]["requires"][req])
			_tree.draw_line(a, b, Ornate.GOLD if ok else Ornate.OUT, 3.0)
	# level gauge with the row gates
	var hero := _hero()
	var top := 18.0
	var bottom := 18.0 + ROW_H * 3 + 44.0
	var gx := 12.0
	_tree.draw_rect(Rect2(gx - 5, top - 2, 10, bottom - top + 4), Ornate.OUT)
	_tree.draw_rect(Rect2(gx - 3, top, 6, bottom - top), Color("#3a1512"))
	var lvl := int(hero.get("level", 1))
	var fill := 0.0
	for r in 4:
		var y0 := top + r * ROW_H + 22.0
		if lvl >= Heroes.row_level(r):
			fill = y0
		if r < 3 and lvl >= Heroes.row_level(r):
			var nxt := Heroes.row_level(r + 1)
			fill = y0 + ROW_H * clampf(float(lvl - Heroes.row_level(r)) / maxf(1.0, nxt - Heroes.row_level(r)), 0.0, 1.0)
	_tree.draw_rect(Rect2(gx - 3, top, 6, clampf(fill - top, 0.0, bottom - top)), Color("#d8392c"))
	for r in 4:
		var y := top + r * ROW_H + 22.0
		var gate := Heroes.row_level(r)
		var open := lvl >= gate
		_tree.draw_circle(Vector2(gx, y), 7.0, Ornate.OUT)
		_tree.draw_circle(Vector2(gx, y), 5.0, Ornate.GOLD if open else Ornate.GOLD_LO.darkened(0.3))
		var txt := str(gate)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		_tree.draw_string_outline(font, Vector2(gx + 9, y + 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Ornate.OUT)
		_tree.draw_string(font, Vector2(gx + 9, y + 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Ornate.TEXT if open else Ornate.TEXT_DIM)


func _hero() -> Dictionary:
	var heroes: Array = Game.state["heroes"]
	return heroes[clampi(hero_idx, 0, heroes.size() - 1)] if not heroes.is_empty() else {}


func _process(_delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		_refresh()


func _refresh() -> void:
	hero_idx = clampi(hero_idx, 0, Game.state["heroes"].size() - 1)
	if _picker.selected != hero_idx:
		_picker.select(hero_idx, false)
	_picker.refresh()
	var hero := _hero()
	var free := Heroes.skill_points_free(hero)
	_points.text = "Talent points: %d" % free
	_auto.set_pressed_no_signal(Game.state["settings"].get("auto_skills", true))
	var nodes := DataDB.skill_nodes()
	for id in _tiles:
		var n: Dictionary = nodes[id]
		var t = _tiles[id]
		var rank := Heroes.skill_rank(hero, id)
		var unlocked := Heroes.skill_unlocked(hero, id)
		t.rank_text = "%d/%d" % [rank, n["max"]]
		t.locked = not unlocked and rank == 0
		t.maxed = rank >= int(n["max"])
		t.available = unlocked and not t.maxed and free > 0
		var reqs := []
		if int(hero["level"]) < Heroes.row_level(int(n["row"])):
			reqs.append("hero level %d" % Heroes.row_level(int(n["row"])))
		for req in n["requires"]:
			reqs.append("%s %d" % [nodes[req]["name"], n["requires"][req]])
		t.tooltip_text = "%s  [%d/%d]\n%s%s" % [n["name"], rank, n["max"], n["text"], ("\nRequires " + ", ".join(reqs)) if not unlocked and not reqs.is_empty() else ""]
		t.queue_redraw()
	_tree.queue_redraw()
