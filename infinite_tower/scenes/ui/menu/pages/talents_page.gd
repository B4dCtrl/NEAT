extends VBoxContainer
## TALENTS: the hero's job skill tree, Ragnarok style. One point per level;
## a node shows its level (3/10), lines show prerequisites, actives (with a
## gold star) are cast automatically in fights once learned.

const DataDB = preload("res://core/data_db.gd")
const Heroes = preload("res://core/heroes.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const IconTile = preload("res://scenes/ui/menu/icon_tile.gd")
const HeroPicker = preload("res://scenes/ui/menu/hero_picker.gd")
const Loc = preload("res://core/loc.gd")

const PASSIVE := Color("#3a3024")
const ACTIVE := Color("#6a2c24")
const TILE := Vector2(48, 60)
const ROW_H := 84.0

var host
var hero_idx := 0
var _picker
var _points: Label
var _job: Label
var _auto: CheckBox
var _tree: Control
var _tiles := {}
var _built_class := ""
var _dirty := true


func mark_dirty() -> void:
	_dirty = true


func _ready() -> void:
	if host != null:
		hero_idx = host.hero_idx
	_picker = HeroPicker.new()
	_picker.badge = func(h: Dictionary) -> String:
		var n := Heroes.skill_points_free(h)
		return Loc.t("%d skill point%s to spend") % [n, "" if n == 1 else "s"] if n > 0 else ""
	_picker.picked.connect(func(i):
		hero_idx = i
		if host != null:
			host.select_hero(i)
		_dirty = true)
	add_child(_picker)
	var bar := HBoxContainer.new()
	add_child(bar)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	bar.add_child(names)
	_job = Ornate.header_label("")
	names.add_child(_job)
	_points = Ornate.small_label("", Ornate.TEXT, 12)
	names.add_child(_points)
	var reset := Button.new()
	reset.focus_mode = Control.FOCUS_NONE
	reset.text = Loc.t("Reset")
	reset.tooltip_text = Loc.t("Refund every skill point of this hero")
	reset.pressed.connect(func(): Game.reset_skills(hero_idx))
	bar.add_child(reset)
	_auto = CheckBox.new()
	_auto.focus_mode = Control.FOCUS_NONE
	_auto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_auto.custom_minimum_size = Vector2(230, 0)
	_auto.text = Loc.t("Spend points automatically")
	_auto.toggled.connect(func(on): Game.set_setting("auto_skills", on))
	add_child(_auto)

	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(frame)
	_tree = Control.new()
	_tree.custom_minimum_size = Vector2(0, ROW_H * 3)
	_tree.draw.connect(_draw_links)
	_tree.resized.connect(_place)
	frame.add_child(_tree)
	add_child(Ornate.small_label(Loc.t("★ = active skill, cast automatically (uses mana)"), Ornate.TEXT_DIM, 11))
	Game.state_changed.connect(func(): _dirty = true)
	Game.party_changed.connect(func(): _picker.rebuild(); _dirty = true)


func _hero() -> Dictionary:
	var heroes: Array = Game.state["heroes"]
	return heroes[clampi(hero_idx, 0, heroes.size() - 1)]


func _build(class_id: String) -> void:
	for c in _tree.get_children():
		c.queue_free()
	_tiles.clear()
	_built_class = class_id
	var nodes := DataDB.skill_nodes(class_id)
	for id in nodes:
		var n: Dictionary = nodes[id]
		var t = IconTile.new()
		t.custom_minimum_size = TILE
		t.size = TILE
		t.glyph = n.get("icon", "star")
		t.fill = ACTIVE if n.get("kind", "") == "active" else PASSIVE
		var node_id: String = id
		t.pressed.connect(func():
			Game.learn_skill(hero_idx, node_id)
			Game.sfx_requested.emit("level"))
		_tree.add_child(t)
		_tiles[id] = t
	_place()


func _col_x(col: int) -> float:
	return _tree.size.x * (col + 0.5) / 3.0


func _place() -> void:
	var nodes := DataDB.skill_nodes(_built_class)
	for id in _tiles:
		var n: Dictionary = nodes[id]
		_tiles[id].position = Vector2(_col_x(int(n["col"])) - TILE.x * 0.5, 10.0 + int(n["row"]) * ROW_H)
	_tree.queue_redraw()


func _draw_links() -> void:
	var nodes := DataDB.skill_nodes(_built_class)
	var hero := _hero()
	for id in _tiles:
		for req in nodes[id]["requires"]:
			if not _tiles.has(req):
				continue
			var a: Vector2 = _tiles[req].position + Vector2(TILE.x * 0.5, TILE.x)
			var b: Vector2 = _tiles[id].position + Vector2(TILE.x * 0.5, 0)
			var ok := Heroes.skill_rank(hero, req) >= int(nodes[id]["requires"][req])
			var mid := Vector2(b.x, a.y + 10.0) if absf(a.x - b.x) > 1.0 else b
			_tree.draw_polyline(PackedVector2Array([a, Vector2(a.x, a.y + 10.0), mid, b]), Ornate.GOLD if ok else Ornate.OUT, 3.0)
			var need := str(int(nodes[id]["requires"][req]))
			_tree.draw_string(_tree.get_theme_default_font(), (a + b) * 0.5 + Vector2(4, 0), need, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Ornate.TEXT_DIM)
	for id in _tiles:
		if nodes[id].get("kind", "") == "active":
			var p: Vector2 = _tiles[id].position + Vector2(TILE.x - 6, 4)
			_tree.draw_string(_tree.get_theme_default_font(), p, "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Ornate.ACCENT)


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
	if _built_class != hero["class"]:
		_build(hero["class"])
	var free := Heroes.skill_points_free(hero)
	_job.text = "%s · Lv %d" % [DataDB.classes()[hero["class"]]["name"], hero["level"]]
	_points.text = Loc.t("Skill points: %d   (1 per level)") % free
	_auto.set_pressed_no_signal(Game.state["settings"].get("auto_skills", true))
	var nodes := DataDB.skill_nodes(hero["class"])
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
		for req in n["requires"]:
			reqs.append("%s %d" % [nodes[req]["name"], n["requires"][req]])
		var lines := ["%s  (Lv %d/%d)%s" % [n["name"], rank, n["max"], Loc.t("  · ACTIVE, auto-cast") if n.get("kind", "") == "active" else ""]]
		if rank > 0:
			lines.append(Loc.t("Now: ") + Heroes.describe(id, rank))
		if rank < int(n["max"]):
			lines.append(Loc.t("Next: ") + Heroes.describe(id, rank + 1))
		if not unlocked and not reqs.is_empty():
			lines.append(Loc.t("Requires ") + ", ".join(reqs))
		t.tooltip_text = "\n".join(lines)
		t.queue_redraw()
	_tree.queue_redraw()
