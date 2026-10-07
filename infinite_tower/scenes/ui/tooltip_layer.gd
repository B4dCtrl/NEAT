extends Node
## Our own tooltips. The engine's tooltip is a native popup that opens BEHIND the
## always-on-top menu windows, so it was half hidden. This one is an
## always-on-top, click-through window of its own that follows the cursor over
## any game window (tower, every panel) and is always in front.

const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const DELAY := 0.30
const MAX_W := 380.0

var _win: Window
var _label: Label
var _target: Control = null
var _shown_text := ""
var _dwell := 0.0
var _windows: Array = []
var _scan := 0.0


func _ready() -> void:
	_win = Window.new()
	_win.borderless = true
	_win.transparent = true
	_win.transparent_bg = true
	_win.unresizable = true
	_win.always_on_top = true
	_win.unfocusable = true
	_win.mouse_passthrough = true
	_win.visible = false
	_win.theme = Ornate.theme()
	var box := PanelContainer.new()
	var sb := Ornate.inset_box(8.0)
	sb.bg_color = Color("#14100d")
	sb.border_color = Ornate.GOLD_LO
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(0, 0)
	_label.add_theme_color_override("font_color", Ornate.TEXT)
	_label.add_theme_font_size_override("font_size", 13)
	box.add_child(_label)
	_win.add_child(box)
	add_child(_win)


func _process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		_windows = [get_tree().root]
		_windows.append_array(get_tree().root.find_children("*", "Window", true, false))
	var mouse := DisplayServer.mouse_get_position()
	var hit: Control = null
	for i in range(_windows.size() - 1, -1, -1):
		var wv: Variant = _windows[i]
		if not is_instance_valid(wv):
			continue
		var w: Window = wv
		if w == _win or not w.visible or w.mode == Window.MODE_MINIMIZED:
			continue
		if Rect2i(w.position, w.size).has_point(mouse):
			hit = w.gui_get_hovered_control()
			break
	var text := ""
	var src: Control = hit
	while src != null and text == "":
		text = src.get_tooltip(src.get_local_mouse_position())
		if text == "":
			src = src.get_parent() as Control
	if text == "" or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_hide()
		return
	if src != _target or text != _shown_text:
		_target = src
		_dwell = 0.0
		if _win.visible and text == _shown_text:
			return
		_hide(false)
		_shown_text = text
	_dwell += delta
	if _dwell >= DELAY:
		_show(text, mouse)
	elif _win.visible:
		_place(mouse)


func _hide(reset: bool = true) -> void:
	if reset:
		_target = null
		_shown_text = ""
		_dwell = 0.0
	if _win.visible:
		_win.visible = false


func _show(text: String, mouse: Vector2i) -> void:
	if not _win.visible or _label.text != text:
		_label.text = text
		_label.custom_minimum_size = Vector2(0, 0)
		_win.size = Vector2i(10, 10)
		var natural := _label.get_minimum_size()
		_label.custom_minimum_size = Vector2(minf(MAX_W, maxf(natural.x, 40.0)), 0)
		_win.visible = true
		await get_tree().process_frame
		_win.size = Vector2i(_win.get_contents_minimum_size()) + Vector2i(2, 2)
	_place(mouse)


func _place(mouse: Vector2i) -> void:
	var screen := 0
	for i in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_usable_rect(i).has_point(mouse):
			screen = i
	var r := DisplayServer.screen_get_usable_rect(screen)
	var p := mouse + Vector2i(18, 20)
	if p.x + _win.size.x > r.end.x:
		p.x = mouse.x - 12 - _win.size.x
	if p.y + _win.size.y > r.end.y:
		p.y = mouse.y - 12 - _win.size.y
	_win.position = Vector2i(maxi(p.x, r.position.x), maxi(p.y, r.position.y))
