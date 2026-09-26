extends Control
## TASKBAR MODE: the thin always-visible strip.
##   [ party ]  ~~~ staircase ~~~  FLOOR 382 | Slime | 18.2k gold | +1 Relic  [»]
## Focus safety: nothing here ever grabs keyboard focus or raises the window.
## Notifications are shown as a soft glow around the bar only.

signal expand_requested()

const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")

const NOTIFY_COLORS := {
	"legendary": Color("#ff9d2a"), "relic": Color("#b388ff"), "boss": Color("#ff4f4f"),
	"fall": Color("#7a8494"), "milestone": Color("#7fe8ff"), "set": Color("#5fd35f"), "info": Color("#c9d1d9"),
}
const DRAG_THRESHOLD := 6.0

@onready var stage: Control = %Stage
@onready var floor_label: Label = %FloorLabel
@onready var enemy_label: Label = %EnemyLabel
@onready var gold_label: Label = %GoldLabel
@onready var notify_label: Label = %NotifyLabel
@onready var notify_icon: TextureRect = %NotifyIcon
@onready var expand_button: Button = %ExpandButton

var _glow_color := Color.TRANSPARENT
var _glow_left := 0.0
var _notify_left := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _t := 0.0


func _ready() -> void:
	%FloorIcon.texture = PixelArt.icon("floor")
	%EnemyIcon.texture = PixelArt.icon("skull")
	%GoldIcon.texture = PixelArt.icon("coin")
	notify_icon.texture = PixelArt.icon("relic")
	for n in [expand_button]:
		n.focus_mode = Control.FOCUS_NONE
	expand_button.pressed.connect(func(): expand_requested.emit())
	Game.notified.connect(_on_notified)
	_set_notify_visible(false)
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	_glow_left = maxf(0.0, _glow_left - delta)
	if _notify_left > 0.0:
		_notify_left -= delta
		if _notify_left <= 0.0:
			_set_notify_visible(false)
	_refresh()
	queue_redraw()


func _refresh() -> void:
	floor_label.text = "FLOOR %d" % Game.state["floor"]
	enemy_label.text = Game.current_enemy_name()
	gold_label.text = UiUtil.num(Game.state["gold"])
	var compact := size.x < 900.0
	enemy_label.visible = not compact
	%EnemyIcon.visible = not compact
	%Sep1.visible = not compact


func _on_notified(kind: String, text: String) -> void:
	if not Game.state["settings"].get("notify_glow", true) and kind != "relic":
		return
	_glow_color = NOTIFY_COLORS.get(kind, Color.WHITE)
	_glow_left = 6.0 if kind in ["relic", "legendary", "boss"] else 3.0
	notify_label.text = text
	notify_label.add_theme_color_override("font_color", _glow_color)
	var icon_id := "relic" if kind in ["relic", "set"] else ("sword" if kind == "legendary" else ("skull" if kind == "boss" else "crystal"))
	notify_icon.texture = PixelArt.icon(icon_id)
	_notify_left = 8.0
	_set_notify_visible(true)


func _set_notify_visible(v: bool) -> void:
	notify_label.visible = v
	notify_icon.visible = v
	%Sep3.visible = v


func _draw() -> void:
	var opacity := float(Game.state["settings"].get("bar_opacity", 0.92))
	var bg := Color(0.06, 0.06, 0.09, opacity)
	var radius := 8
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	if _glow_left > 0.0:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		var c := _glow_color
		c.a = clampf(_glow_left / 2.0, 0.0, 1.0) * (0.45 + 0.4 * pulse)
		sb.border_color = c
		sb.set_border_width_all(2)
		sb.shadow_color = Color(c.r, c.g, c.b, c.a * 0.6)
		sb.shadow_size = 4
	draw_style_box(sb, Rect2(Vector2.ZERO, size))


# Click expands, drag slides the bar along its dock edge.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_dragging = false
			_press_pos = event.global_position
		else:
			if _pressing and not _dragging:
				expand_requested.emit()
			_pressing = false
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _pressing:
		if not _dragging and event.global_position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			WindowManager.nudge_bar(int(event.relative.x))
		accept_event()
