extends Control
## The Stairborn manga: reads a chapter page by page (panels pop in in order,
## bubbles type themselves; click / Space advances) or shows the chapter list.
## Chapter 1 is the opening of the game; later chapters unlock while climbing.

signal finished(chapter_id: String)

const MangaPanel = preload("res://scenes/ui/manga_panel.gd")
const Story = preload("res://core/story.gd")
const Torment = preload("res://core/torment.gd")
const Loc = preload("res://core/loc.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")

const BG := Color("#0b0a0d")
const PAPER := Color("#f1ece0")
const GUTTER := 12.0

var _chapter: Dictionary = {}
var _page := -1
var _panels: Array = []
var _current := 0
var _page_root: Control
var _index: VBoxContainer
var _hint: Label
var _close: Button
var _prev: Button
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Ornate.theme()
	_page_root = Control.new()
	_page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page_root)
	_index = VBoxContainer.new()
	_index.add_theme_constant_override("separation", 10)
	add_child(_index)
	_close = _corner_button(-120, func(): _end(false))
	_prev = _corner_button(-230, _prev_page)
	_prev.text = "◀"
	_hint = Label.new()
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.anchor_right = 1.0
	_hint.offset_top = -28
	_hint.offset_bottom = -6
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color("#8d887e"))
	add_child(_hint)
	resized.connect(_layout)


func _corner_button(x: float, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = x
	b.offset_right = x + 104
	b.offset_top = 8
	b.offset_bottom = 38
	b.pressed.connect(cb)
	add_child(b)
	return b


## Opens a chapter, or the chapter list when id is "".
func start(id: String = "") -> void:
	_close.text = Loc.t("manga.back") if id == "" else Loc.t("manga.skip")
	if id == "":
		_show_index()
		return
	_chapter = Story.chapter(id)
	if _chapter.is_empty():
		_show_index()
		return
	_index.visible = false
	_page = -1
	_next_page()


func _show_index() -> void:
	_chapter = {}
	for c in _page_root.get_children():
		c.queue_free()
	_panels.clear()
	for c in _index.get_children():
		c.queue_free()
	_index.visible = true
	_close.text = Loc.t("manga.back")
	_prev.visible = false
	var title := Ornate.header_label(Loc.t("manga.chapters"))
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_index.add_child(title)
	for c in Story.chapters():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_index.add_child(row)
		var unlocked := Story.is_unlocked(Game.state, c["id"])
		var name := Label.new()
		name.text = Loc.t(c["title"]) if unlocked else "???"
		name.custom_minimum_size = Vector2(380, 0)
		name.add_theme_font_size_override("font_size", 18)
		name.add_theme_color_override("font_color", PAPER if unlocked else Color("#6a6458"))
		row.add_child(name)
		var info := Label.new()
		info.custom_minimum_size = Vector2(170, 0)
		info.add_theme_font_size_override("font_size", 14)
		if not unlocked:
			var u: Dictionary = c["unlock"]
			info.text = Loc.t("manga.locked_floor") % int(u["value"]) if u["type"] == "floor" else Loc.t("manga.locked_torment") % Torment.name(int(u["value"]))
			info.add_theme_color_override("font_color", Color("#8d887e"))
		elif Story.is_new(Game.state, c["id"]):
			info.text = Loc.t("manga.new")
			info.add_theme_color_override("font_color", Ornate.ACCENT)
		row.add_child(info)
		var read := Button.new()
		read.text = Loc.t("manga.read")
		read.focus_mode = Control.FOCUS_NONE
		read.disabled = not unlocked
		var cid: String = c["id"]
		read.pressed.connect(func(): start(cid))
		row.add_child(read)
	_layout()


func _process(delta: float) -> void:
	_time += delta
	if _chapter.is_empty():
		_hint.text = ""
		return
	var p = _active()
	var ready: bool = p != null and p.text_done()
	var last: bool = _page == _chapter["pages"].size() - 1 and _current == _panels.size() - 1
	_hint.text = (Loc.t("manga.end") if last else Loc.t("manga.next")) if ready else ""
	_hint.modulate.a = 0.5 + 0.5 * sin(_time * 3.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if not _chapter.is_empty():
		draw_rect(_page_rect().grow(8.0), PAPER)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _chapter.is_empty():
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_RIGHT]):
		_advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_LEFT:
		_prev_page()
		get_viewport().set_input_as_handled()


func _active():
	return _panels[_current] if _current < _panels.size() else null


func _advance() -> void:
	var p = _active()
	if p == null:
		return
	if not p.text_done():
		p.finish()
		return
	if _current + 1 < _panels.size():
		_current += 1
		_panels[_current].active = true
	elif _page + 1 < _chapter["pages"].size():
		_next_page()
	else:
		_end(true)


func _prev_page() -> void:
	if _page <= 0:
		return
	_page -= 2
	_next_page()


func _end(completed: bool) -> void:
	var id: String = _chapter.get("id", "")
	if id != "" and completed:
		Story.mark_read(Game.state, id)
	finished.emit(id)


func _next_page() -> void:
	_page += 1
	for c in _page_root.get_children():
		c.queue_free()
	_panels.clear()
	_current = 0
	_prev.visible = _page > 0
	var hero_name: String = Game.state["heroes"][0]["name"] if not Game.state.is_empty() and not Game.state["heroes"].is_empty() else "Stairborn"
	for spec in _chapter["pages"][_page]:
		var p = MangaPanel.new()
		p.setup(spec, hero_name)
		_page_root.add_child(p)
		_panels.append(p)
	_panels[0].active = true
	_layout()


func _page_rect() -> Rect2:
	var margin := Vector2(30, 50)
	return Rect2(margin, size - margin * 2.0)


func _layout() -> void:
	queue_redraw()
	_index.position = Vector2(maxf(30.0, size.x * 0.5 - 330.0), 70)
	_index.size = Vector2(minf(660.0, size.x - 60.0), size.y - 120)
	var area := _page_rect()
	_page_root.position = Vector2.ZERO
	_page_root.size = size
	for p in _panels:
		var f: Array = p.spec["rect"]
		var fr := Rect2(float(f[0]), float(f[1]), float(f[2]), float(f[3]))
		var r := Rect2(area.position + fr.position * area.size, fr.size * area.size)
		if fr.position.x > 0.0:
			r.position.x += GUTTER * 0.5
			r.size.x -= GUTTER * 0.5
		if fr.end.x < 0.999:
			r.size.x -= GUTTER * 0.5
		if fr.position.y > 0.0:
			r.position.y += GUTTER * 0.5
			r.size.y -= GUTTER * 0.5
		if fr.end.y < 0.999:
			r.size.y -= GUTTER * 0.5
		p.position = r.position
		p.size = r.size
