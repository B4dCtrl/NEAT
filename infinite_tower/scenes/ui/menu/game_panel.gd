extends Control
## One floating menu window: ornate frame, title ribbon, close button and a
## page inside. Panels open above the tower and sit side by side.

signal close_requested(panel_id: String)

const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const Glyphs = preload("res://scenes/ui/menu/glyphs.gd")

var panel_id := ""
var title := ""
var page: Control
var _close_rect := Rect2()
var _close_hover := false
var _appear := 0.0


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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _close_rect.has_point(event.position):
			close_requested.emit(panel_id)
		accept_event()
