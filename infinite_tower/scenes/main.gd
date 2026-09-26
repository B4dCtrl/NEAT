extends Control
## Root: hosts both views and switches between them with the window mode.

const ThemeBuilder = preload("res://scenes/ui/theme_builder.gd")

@onready var taskbar_view: Control = $TaskbarView
@onready var expedition_view: Control = $ExpeditionView

const DEBUG_SPEEDS := [1.0, 5.0, 25.0, 100.0]
var _debug_speed_idx := 0


func _ready() -> void:
	theme = ThemeBuilder.build()
	taskbar_view.expand_requested.connect(func(): WindowManager.set_mode("expedition"))
	expedition_view.collapse_requested.connect(func(): WindowManager.set_mode("taskbar"))
	WindowManager.mode_changed.connect(_on_mode_changed)
	Game.settings_changed.connect(_apply_audio)
	Game.offline_report_ready.connect(_on_offline_report)
	_apply_audio()
	_on_mode_changed(WindowManager.mode)


func _on_mode_changed(mode: String) -> void:
	taskbar_view.visible = mode == "taskbar"
	expedition_view.visible = mode == "expedition"
	if mode == "expedition":
		expedition_view.on_opened()


func _on_offline_report(report: Dictionary) -> void:
	# Never pops a window: just a glow on the bar. Details wait for the Expedition view.
	var floors := int(report["max_floor_end"]) - int(report["max_floor_start"])
	Game.notified.emit("milestone", "Welcome back! +%d floors" % maxi(floors, 0))


func _apply_audio() -> void:
	var v := float(Game.state["settings"].get("master_volume", 0.8))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(0, v <= 0.001)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mode"):
		WindowManager.toggle_mode()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and WindowManager.mode == "expedition":
		WindowManager.set_mode("taskbar")
		get_viewport().set_input_as_handled()
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		_debug_speed_idx = (_debug_speed_idx + 1) % DEBUG_SPEEDS.size()
		Game.time_scale = DEBUG_SPEEDS[_debug_speed_idx]
		Game.notified.emit("info", "Debug speed x%d" % int(Game.time_scale))
