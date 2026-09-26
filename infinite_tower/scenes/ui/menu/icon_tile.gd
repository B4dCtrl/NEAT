extends Control
## A framed icon square used by the talent tree and the skills list:
## glyph, rank ("3/10"), locked/maxed states and a cooldown sweep.

signal pressed()

const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const Glyphs = preload("res://scenes/ui/menu/glyphs.gd")

var glyph := ""
var texture: Texture2D = null   # overrides the glyph (portraits)
var fill := Color("#5a2a24")
var rim := Color("#8a5a1c")
var rank_text := ""
var locked := false
var maxed := false
var highlight := false
var available := false          # can be clicked right now (pulses)
var cooldown := 0.0             # 0..1 share of the cooldown still to go
var dim := false
var _hover := false
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(40, 40)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _process(delta: float) -> void:
	if available or cooldown > 0.0:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y - (12.0 if rank_text != "" else 0.0))
	var r := Rect2(Vector2((size.x - s) * 0.5, 0), Vector2(s, s))
	var edge := rim
	if maxed:
		edge = Ornate.GOLD
	elif highlight or (_hover and not locked):
		edge = Ornate.ACCENT
	Ornate.draw_tile(self, r, fill.darkened(0.45) if locked else fill, edge, _hover)
	var tex: Texture2D = texture if texture != null else (Glyphs.texture(glyph) if glyph != "" else null)
	if tex != null:
		var pad := s * 0.16
		var mod := Color(0.45, 0.42, 0.4) if locked or dim else Color.WHITE
		var ts := Vector2(tex.get_size())
		var area := r.grow(-pad)
		var k := minf(area.size.x / ts.x, area.size.y / ts.y)
		var dst := Rect2(area.get_center() - ts * k * 0.5, ts * k)
		draw_texture_rect(tex, dst, false, mod)
	if cooldown > 0.0:
		# Clockwise sweep over the icon while the skill recharges.
		var c := r.get_center()
		var pts := PackedVector2Array([c])
		var a0 := -PI * 0.5
		var steps := 20
		for i in steps + 1:
			var a := a0 + TAU * (1.0 - cooldown) + TAU * cooldown * i / steps
			pts.append(c + Vector2(cos(a), sin(a)) * s)
		var clip := PackedVector2Array()
		for p in pts:
			clip.append(Vector2(clampf(p.x, r.position.x + 4, r.end.x - 4), clampf(p.y, r.position.y + 4, r.end.y - 4)))
		draw_colored_polygon(clip, Color(0, 0, 0, 0.55))
	if available:
		var a := 0.35 + 0.35 * sin(_t * 5.0)
		draw_rect(r.grow(-2), Color(1, 0.85, 0.4, a), false, 2.0)
	if locked:
		var lk := Glyphs.texture("lock")
		draw_texture_rect(lk, Rect2(r.end - Vector2(16, 16), Vector2(14, 14)), false)
	if rank_text != "":
		var font := get_theme_default_font()
		var fs := 11
		var tw := font.get_string_size(rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(size.x * 0.5 - tw * 0.5, size.y - 1)
		draw_string_outline(font, p, rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Ornate.OUT)
		draw_string(font, p, rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ornate.ACCENT if maxed else Ornate.TEXT)
