extends Control
## The opening story, told as an animated comic: two pages of panels that pop in
## one after another with typed captions, then a splash page with the title.
## Click / Space / Enter advances, "Skip" jumps to the end.

signal finished()

const ComicPanel = preload("res://scenes/ui/comic_panel.gd")
const StoryText = preload("res://scenes/ui/story_text.gd")

## Page layouts: [scene id, rect in page fractions (x, y, w, h), caption on top].
const PAGES := [
	[["tower", Rect2(0.0, 0.0, 1.0, 0.52), true],
	 ["heroes", Rect2(0.0, 0.54, 0.55, 0.46), true],
	 ["lost", Rect2(0.57, 0.54, 0.43, 0.46), false]],
	[["withering", Rect2(0.0, 0.0, 0.48, 1.0), true],
	 ["birth", Rect2(0.5, 0.0, 0.5, 1.0), false]],
	[["first_step", Rect2(0.0, 0.0, 1.0, 1.0), false]],
]
const PAPER := Color("#e8e0cc")
const GUTTER := 14.0

var _page := -1
var _panels: Array = []
var _current := 0
var _page_root: Control
var _hint: Label
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_page_root = Control.new()
	_page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page_root)
	var skip := Button.new()
	skip.text = StoryText.comic("skip")
	skip.focus_mode = Control.FOCUS_NONE
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -110
	skip.offset_right = -12
	skip.offset_top = 10
	skip.offset_bottom = 40
	skip.pressed.connect(func(): finished.emit())
	add_child(skip)
	_hint = Label.new()
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.anchor_right = 1.0
	_hint.offset_top = -30
	_hint.offset_bottom = -8
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color("#6a6458"))
	add_child(_hint)
	resized.connect(_layout)


func start() -> void:
	_page = -1
	_next_page()


func _process(delta: float) -> void:
	_time += delta
	var p = _active_panel()
	var ready: bool = p != null and p.caption_done()
	var last: bool = _page == PAGES.size() - 1 and _current == _panels.size() - 1
	_hint.text = (StoryText.comic("begin") if last else StoryText.comic("next")) if ready else ""
	_hint.modulate.a = 0.5 + 0.5 * sin(_time * 3.0)


var _halftone: ImageTexture


## Halftone dots on the paper, like cheap comic print (one tiled texture).
func _make_halftone() -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(PAPER)
	var dot := PAPER.darkened(0.06)
	for p in [Vector2i(3, 3), Vector2i(9, 9)]:
		for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			img.set_pixelv(p + o, dot)
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	if _halftone == null:
		_halftone = _make_halftone()
	draw_texture_rect(_halftone, Rect2(Vector2.ZERO, size), true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		_advance()
		get_viewport().set_input_as_handled()


func _active_panel():
	return _panels[_current] if _current < _panels.size() else null


func _advance() -> void:
	var p = _active_panel()
	if p == null:
		return
	if p.reveal < 1.0 or not p.caption_done():
		p.reveal = 1.0
		p.finish_caption()
		return
	if _current + 1 < _panels.size():
		_current += 1
		_panels[_current].active = true
	elif _page + 1 < PAGES.size():
		_next_page()
	else:
		finished.emit()


func _next_page() -> void:
	_page += 1
	for c in _page_root.get_children():
		c.queue_free()
	_panels.clear()
	_current = 0
	for spec in PAGES[_page]:
		var p = ComicPanel.new()
		p.setup(spec[0], StoryText.comic(spec[0]), spec[2])
		p.set_meta("frac", spec[1])
		_page_root.add_child(p)
		_panels.append(p)
	_panels[0].active = true
	_layout()


func _layout() -> void:
	var margin := Vector2(28, 52)
	var area := Rect2(margin, size - margin * 2.0)
	_page_root.position = Vector2.ZERO
	_page_root.size = size
	for p in _panels:
		var f: Rect2 = p.get_meta("frac")
		var r := Rect2(area.position + f.position * area.size, f.size * area.size)
		# Gutters between panels.
		if f.position.x > 0.0:
			r.position.x += GUTTER * 0.5
			r.size.x -= GUTTER * 0.5
		if f.end.x < 1.0:
			r.size.x -= GUTTER * 0.5
		if f.position.y > 0.0:
			r.position.y += GUTTER * 0.5
			r.size.y -= GUTTER * 0.5
		if f.end.y < 1.0:
			r.size.y -= GUTTER * 0.5
		p.position = r.position
		p.size = r.size
