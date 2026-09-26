extends Control
## One menu panel (its own floating window): ornate frame, title ribbon that
## doubles as the drag handle, close button and a page inside.

signal close_requested(panel_id: String)
## The player is dragging the panel by its title: move its window to `pos`.
signal dragged(panel_id: String, pos: Vector2i)

const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const Glyphs = preload("res://scenes/ui/menu/glyphs.gd")

var panel_id := ""
var title := ""
var page: Control
var _close_rect := Rect2()
var _close_hover := false
var _appear := 0.0
var _dragging := false
var _drag_mouse := Vector2i.ZERO
var _drag_win := Vector2i.ZERO


func setup(id: String, title_: String, page_: Control, panel_size: Vector2) -> void:
	panel_id = id
	title = title_
	page = page_
	size = panel_size
	custom_minimum_size = panel_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var side := int(Ornate.BORDER + 2)
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_right", side)
	margin.add_theme_constant_override("margin_top", int(Ornate.RIBBON_H + 8))
	margin.add_theme_constant_override("margin_bottom", side)
	add_child(margin)
	margin.add_child(page)
	_close_rect = Rect2(panel_size.x - 30, Ornate.RIBBON_H * 0.5 + 4, 20, 20)
	pivot_offset = Vector2(panel_size.x * 0.5, panel_size.y)
	scale = Vector2(0.94, 0.94)
	modulate.a = 0.0


func _process(delta: float) -> void:
	if _appear < 1.0:
		_appear = minf(1.0, _appear + delta * 8.0)
		var k := 1.0 - pow(1.0 - _appear, 3.0)
		scale = Vector2.ONE * lerpf(0.94, 1.0, k)
		modulate.a = k
	var hover := _close_rect.has_point(get_local_mouse_position())
	if hover != _close_hover:
		_close_hover = hover
		queue_redraw()


func _draw() -> void:
	Ornate.draw_frame(self, Rect2(Vector2.ZERO, size), title, get_theme_default_font(), 15)
	Ornate.draw_tile(self, _close_rect, Color("#7a2a22") if not _close_hover else Color("#a3382c"), Ornate.GOLD_LO if not _close_hover else Ornate.GOLD, _close_hover)
	draw_texture_rect(Glyphs.texture("close"), _close_rect.grow(-4), false)


## The ribbon / top frame is the handle that moves the panel window.
func _is_handle(p: Vector2) -> bool:
	return p.y < Ornate.RIBBON_H + 10.0 and not _close_rect.has_point(p)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _close_rect.has_point(event.position):
				close_requested.emit(panel_id)
			elif _is_handle(event.position):
				# Screen-space drag, so the panel can cross onto another monitor.
				_dragging = true
				_drag_mouse = DisplayServer.mouse_get_position()
				_drag_win = get_window().position
		else:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion:
		mouse_default_cursor_shape = Control.CURSOR_MOVE if _is_handle(event.position) else Control.CURSOR_ARROW
		if _dragging:
			dragged.emit(panel_id, _drag_win + DisplayServer.mouse_get_position() - _drag_mouse)
			accept_event()
