extends RefCounted
## Dark, slightly pixel-flavoured UI theme built in code (no binary .tres to merge).

const BG := Color("#12111a")
const PANEL := Color("#1b1a26")
const PANEL_LIGHT := Color("#262436")
const BORDER := Color("#3a3752")
const TEXT := Color("#e6e2d3")
const TEXT_DIM := Color("#9a96a8")
const ACCENT := Color("#f2c14e")


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 14

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.3))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_color", "TabContainer", TEXT_DIM)
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_hovered_color", "TabContainer", Color.WHITE)
	t.set_color("default_color", "RichTextLabel", TEXT)

	t.set_stylebox("panel", "Panel", _box(BG, BORDER, 0, 0))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, BORDER, 1, 6))
	t.set_stylebox("normal", "Button", _box(PANEL_LIGHT, BORDER, 1, 4))
	t.set_stylebox("hover", "Button", _box(PANEL_LIGHT.lightened(0.1), ACCENT.darkened(0.3), 1, 4))
	t.set_stylebox("pressed", "Button", _box(PANEL_LIGHT.darkened(0.2), ACCENT, 1, 4))
	t.set_stylebox("disabled", "Button", _box(PANEL.darkened(0.2), BORDER.darkened(0.3), 1, 4))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TabContainer", _box(PANEL, BORDER, 1, 8))
	t.set_stylebox("tab_selected", "TabContainer", _box(PANEL, ACCENT.darkened(0.2), 1, 6, true))
	t.set_stylebox("tab_unselected", "TabContainer", _box(BG, BORDER, 1, 6, true))
	t.set_stylebox("tab_hovered", "TabContainer", _box(PANEL_LIGHT, BORDER, 1, 6, true))
	t.set_stylebox("panel", "ItemList", _box(BG, BORDER, 1, 4))
	t.set_stylebox("panel", "Tree", _box(BG, BORDER, 1, 4))
	t.set_stylebox("background", "ProgressBar", _box(BG, BORDER, 1, 0))
	t.set_stylebox("fill", "ProgressBar", _box(ACCENT.darkened(0.2), Color.TRANSPARENT, 0, 0))
	t.set_stylebox("panel", "TooltipPanel", _box(Color("#0c0b12"), ACCENT.darkened(0.4), 1, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("separation", "VBoxContainer", 6)
	return t


static func _box(bg: Color, border: Color, border_w: int, margin: int, tab: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(3)
	if tab:
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
	else:
		sb.set_content_margin_all(margin)
	return sb
