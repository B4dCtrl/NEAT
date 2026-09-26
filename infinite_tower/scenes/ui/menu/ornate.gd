extends RefCounted
## The ornate look of the in-game menu: maroon frames with gold studs, a red
## title ribbon and leather-brown insets, all drawn in code on a 2px pixel grid.

const OUT := Color("#120a09")
const FRAME := Color("#4d2420")
const FRAME_HI := Color("#74392d")
const FRAME_LO := Color("#2b1310")
const GOLD := Color("#e0ac48")
const GOLD_LO := Color("#8a5a1c")
const INNER := Color("#35251d")
const INNER_LO := Color("#231812")
const RIBBON := Color("#9a2c22")
const RIBBON_LO := Color("#5e1812")
const TEXT := Color("#f3e5c4")
const TEXT_DIM := Color("#b39c7c")
const ACCENT := Color("#ffd46b")
const GOOD := Color("#7ee07e")
const BAD := Color("#ff7a6b")

const P := 2.0          # size of one "pixel" of the frame
const BORDER := 12.0    # frame thickness (content starts inside it)
const RIBBON_H := 26.0  # title ribbon height; it overhangs the frame top


## Full panel frame. `rect` includes the ribbon overhang at the top.
static func draw_frame(ci: CanvasItem, rect: Rect2, title: String, font: Font, font_size: int) -> void:
	var body := Rect2(rect.position + Vector2(0, RIBBON_H * 0.5), rect.size - Vector2(0, RIBBON_H * 0.5))
	# drop shadow
	ci.draw_rect(Rect2(body.position + Vector2(P * 2, P * 2), body.size), Color(0, 0, 0, 0.35))
	ci.draw_rect(body, OUT)
	var f := body.grow(-P)
	ci.draw_rect(f, FRAME)
	# bevel
	ci.draw_rect(Rect2(f.position, Vector2(f.size.x, P)), FRAME_HI)
	ci.draw_rect(Rect2(f.position, Vector2(P, f.size.y)), FRAME_HI)
	ci.draw_rect(Rect2(f.position + Vector2(0, f.size.y - P), Vector2(f.size.x, P)), FRAME_LO)
	ci.draw_rect(Rect2(f.position + Vector2(f.size.x - P, 0), Vector2(P, f.size.y)), FRAME_LO)
	# inner gold line + content well
	var inner := body.grow(-(BORDER - P * 2))
	ci.draw_rect(inner, GOLD_LO)
	ci.draw_rect(inner.grow(-P), OUT)
	ci.draw_rect(inner.grow(-P * 2), INNER)
	# studs on the corners and along the edges
	for c in [f.position, Vector2(f.end.x, f.position.y), Vector2(f.position.x, f.end.y), f.end]:
		_stud(ci, c + Vector2(signf(f.get_center().x - c.x), signf(f.get_center().y - c.y)) * 4.0)
	var n := int(f.size.y / 90.0)
	for i in range(1, n):
		var y := f.position.y + f.size.y * i / n
		_stud(ci, Vector2(f.position.x + 4.0, y))
		_stud(ci, Vector2(f.end.x - 4.0, y))
	if title != "":
		draw_ribbon(ci, Vector2(rect.get_center().x, rect.position.y + RIBBON_H * 0.5), title, font, font_size)


static func _stud(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_rect(Rect2(at - Vector2(P * 1.5, P * 1.5), Vector2(P * 3, P * 3)), OUT)
	ci.draw_rect(Rect2(at - Vector2(P, P), Vector2(P * 2, P * 2)), GOLD)
	ci.draw_rect(Rect2(at - Vector2(P, P), Vector2(P, P)), Color("#fff0b0"))


## Red banner with notched ends and gold edges, centred on `center`.
static func draw_ribbon(ci: CanvasItem, center: Vector2, title: String, font: Font, font_size: int) -> void:
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var w := tw + 56.0
	var h := RIBBON_H
	var r := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	# tails
	for side in [-1.0, 1.0]:
		var x0: float = r.position.x if side < 0 else r.end.x
		var tail := PackedVector2Array([
			Vector2(x0, r.position.y + 5), Vector2(x0 + side * 16, r.position.y + 5),
			Vector2(x0 + side * 10, r.get_center().y + 2), Vector2(x0 + side * 16, r.end.y + 3),
			Vector2(x0, r.end.y + 3)])
		ci.draw_colored_polygon(tail, RIBBON_LO)
		ci.draw_polyline(tail + PackedVector2Array([tail[0]]), OUT, P)
	ci.draw_rect(r, OUT)
	ci.draw_rect(r.grow(-P), GOLD_LO)
	ci.draw_rect(r.grow(-P * 2), RIBBON)
	ci.draw_rect(Rect2(r.position + Vector2(P * 2, P * 2), Vector2(r.size.x - P * 4, P)), Color("#c2463a"))
	ci.draw_rect(Rect2(r.position + Vector2(P * 2, r.size.y - P * 3), Vector2(r.size.x - P * 4, P)), RIBBON_LO)
	# little gold diamonds either side of the title
	for side in [-1.0, 1.0]:
		var d: Vector2 = r.get_center() + Vector2(side * (tw * 0.5 + 14.0), 0)
		ci.draw_colored_polygon(PackedVector2Array([d + Vector2(0, -4), d + Vector2(4, 0), d + Vector2(0, 4), d + Vector2(-4, 0)]), GOLD)
	var base := Vector2(r.get_center().x - tw * 0.5, r.get_center().y + font_size * 0.36)
	ci.draw_string_outline(font, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, OUT)
	ci.draw_string(font, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ACCENT)


## A framed square tile (item slots, talent and skill icons).
static func draw_tile(ci: CanvasItem, r: Rect2, fill: Color, rim: Color, lit: bool) -> void:
	ci.draw_rect(r, OUT)
	ci.draw_rect(r.grow(-P), rim)
	ci.draw_rect(r.grow(-P * 2), fill)
	ci.draw_rect(Rect2(r.position + Vector2(P * 2, P * 2), Vector2(r.size.x - P * 4, P)), fill.lightened(0.25 if lit else 0.1))
	ci.draw_rect(Rect2(r.position + Vector2(P * 2, r.size.y - P * 3), Vector2(r.size.x - P * 4, P)), fill.darkened(0.35))


static func inset_box(margin: float = 6.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = INNER_LO
	sb.border_color = OUT
	sb.set_border_width_all(2)
	sb.border_blend = false
	sb.set_content_margin_all(margin)
	return sb


static func _button_box(bg: Color, rim: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = rim
	sb.set_border_width_all(2)
	sb.shadow_color = OUT
	sb.shadow_size = 0
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


## Theme for everything inside the menu panels.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 12
	for cls in ["Label", "Button", "CheckBox", "CheckButton", "OptionButton"]:
		t.set_color("font_color", cls, TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.25))
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "Button", _button_box(Color("#6a2c24"), OUT))
	t.set_stylebox("hover", "Button", _button_box(Color("#83382c"), GOLD_LO))
	t.set_stylebox("pressed", "Button", _button_box(Color("#4a1d18"), GOLD))
	t.set_stylebox("disabled", "Button", _button_box(Color("#3a2520"), OUT))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for cls in ["OptionButton"]:
		t.set_stylebox("normal", cls, _button_box(Color("#6a2c24"), OUT))
		t.set_stylebox("hover", cls, _button_box(Color("#83382c"), GOLD_LO))
		t.set_stylebox("pressed", cls, _button_box(Color("#4a1d18"), GOLD))
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
	for cls in ["CheckBox"]:
		for s in ["normal", "hover", "pressed", "hover_pressed"]:
			t.set_stylebox(s, cls, StyleBoxEmpty.new())
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", inset_box())
	t.set_stylebox("panel", "TooltipPanel", _button_box(INNER_LO, GOLD_LO))
	t.set_color("font_color", "TooltipLabel", TEXT)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = OUT
	bar_bg.set_content_margin_all(1)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("#c9362a")
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	var grab := StyleBoxFlat.new()
	grab.bg_color = GOLD_LO
	grab.set_content_margin_all(3)
	var track := StyleBoxFlat.new()
	track.bg_color = INNER_LO
	track.set_content_margin_all(3)
	for sb_cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb_cls, track)
		t.set_stylebox("grabber", sb_cls, grab)
		t.set_stylebox("grabber_highlight", sb_cls, grab)
		t.set_stylebox("grabber_pressed", sb_cls, grab)
	var slider := StyleBoxFlat.new()
	slider.bg_color = OUT
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = GOLD_LO
	slider_fill.content_margin_top = 3
	slider_fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider)
	t.set_stylebox("grabber_area", "HSlider", slider_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("separation", "VBoxContainer", 5)
	return t


static func small_label(text: String, color: Color = TEXT_DIM, size: int = 11) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	return l


static func header_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", ACCENT)
	l.add_theme_color_override("font_outline_color", OUT)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_font_size_override("font_size", 13)
	return l
