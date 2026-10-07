extends Control
## Root: hosts the taskbar and expedition views, the story (comic intro +
## tutorial) and the system tray icon. Closing the window hides the game in the
## tray while the climb goes on; the tray menu brings it back or quits.

const ThemeBuilder = preload("res://scenes/ui/theme_builder.gd")
const NameView = preload("res://scenes/ui/name_view.gd")
const TooltipLayer = preload("res://scenes/ui/tooltip_layer.gd")
const ComicIntro = preload("res://scenes/ui/comic_intro.gd")
const TutorialView = preload("res://scenes/ui/tutorial_view.gd")
const StoryText = preload("res://scenes/ui/story_text.gd")
const LoginView = preload("res://scenes/ui/login_view.gd")
const Loc = preload("res://core/loc.gd")

@onready var taskbar_view: Control = $TaskbarView
@onready var expedition_view: Control = $ExpeditionView

const DEBUG_SPEEDS := [1.0, 5.0, 25.0, 100.0]
const TRAY_SHOW := 0
const TRAY_EXPEDITION := 1
const TRAY_QUIT := 2

var _debug_speed_idx := 0
var _comic: Control
var _tutorial: Control
var _name_view: Control
var _story_stage := ""           # "login" | "intro" | "tutorial" while the story window is up
var _login: Control
var _tray: Node = null
var _tray_menu: PopupMenu


func _ready() -> void:
	theme = ThemeBuilder.build()
	get_tree().auto_accept_quit = false
	add_child(TooltipLayer.new())
	_comic = ComicIntro.new()
	_comic.set_anchors_preset(Control.PRESET_FULL_RECT)
	_comic.visible = false
	_comic.finished.connect(_on_intro_done)
	add_child(_comic)
	_name_view = NameView.new()
	_name_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_name_view.visible = false
	_name_view.finished.connect(_on_name_done)
	add_child(_name_view)
	_tutorial = TutorialView.new()
	_tutorial.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial.visible = false
	_tutorial.finished.connect(_on_tutorial_done)
	add_child(_tutorial)
	_login = LoginView.new()
	_login.set_anchors_preset(Control.PRESET_FULL_RECT)
	_login.visible = false
	_login.logged_in.connect(_after_login)
	add_child(_login)
	Game.account_changed.connect(func():
		if not Game.logged_in():
			# Logged out: back to the login screen.
			_story_stage = "login"
			if WindowManager.mode == "story":
				_on_mode_changed("story")
			else:
				WindowManager.set_mode("story"))

	taskbar_view.expand_requested.connect(func(): WindowManager.set_mode("expedition"))
	taskbar_view.close_requested.connect(_close_to_tray)
	expedition_view.collapse_requested.connect(func(): WindowManager.set_mode("taskbar"))
	WindowManager.mode_changed.connect(_on_mode_changed)
	Game.settings_changed.connect(_apply_audio)
	Game.offline_report_ready.connect(_on_offline_report)
	Game.story_requested.connect(_on_story_requested)
	_apply_audio()
	_setup_tray()
	if not Game.logged_in():
		_story_stage = "login"
	else:
		_story_stage = _next_story_stage()
	_on_mode_changed(WindowManager.mode)


## What still has to be shown after logging in: the comic, the guide, or nothing.
func _next_story_stage() -> String:
	if not Game.state.get("intro_seen", false):
		return "intro"
	if not Game.state.get("named", false):
		return "name"
	if not Game.state.get("tutorial_seen", false):
		return "tutorial"
	return ""


func _after_login() -> void:
	_story_stage = _next_story_stage()
	if _story_stage == "":
		_end_story()
	else:
		_on_mode_changed("story")


# ------------------------------------------------------------------ story

func _on_story_requested(what: String) -> void:
	_story_stage = what
	if WindowManager.mode == "story":
		_on_mode_changed("story")
	else:
		WindowManager.set_mode("story")


func _on_intro_done() -> void:
	Game.state["intro_seen"] = true
	_story_stage = _next_story_stage()
	if _story_stage == "":
		_end_story()
	else:
		_on_mode_changed("story")


func _on_name_done() -> void:
	_story_stage = _next_story_stage()
	if _story_stage == "":
		_end_story()
	else:
		_on_mode_changed("story")


func _on_tutorial_done() -> void:
	Game.state["tutorial_seen"] = true
	_end_story()


func _end_story() -> void:
	_story_stage = ""
	Game.save()
	WindowManager.set_mode("taskbar")


func _on_mode_changed(mode: String) -> void:
	var story := mode == "story"
	taskbar_view.visible = mode == "taskbar"
	expedition_view.visible = mode == "expedition"
	_comic.visible = story and _story_stage == "intro"
	_name_view.visible = story and _story_stage == "name"
	if _name_view.visible:
		_name_view.start()
	_tutorial.visible = story and _story_stage == "tutorial"
	_login.visible = story and _story_stage == "login"
	if _login.visible:
		_login.start()
	if _comic.visible:
		_comic.start()
	if _tutorial.visible:
		_tutorial.start()
	if story and _story_stage == "":
		WindowManager.set_mode("taskbar")
	if mode == "expedition":
		expedition_view.on_opened()


func _on_offline_report(report: Dictionary) -> void:
	# Never pops a window: just a glow on the bar. Details wait for the Expedition view.
	var floors := int(report["max_floor_end"]) - int(report["max_floor_start"])
	Game.notified.emit("milestone", Loc.t("Welcome back! +%d floors") % maxi(floors, 0))


func _apply_audio() -> void:
	var v := float(Game.state["settings"].get("master_volume", 0.8))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(0, v <= 0.001)


# ------------------------------------------------------------------ tray

func tray_supported() -> bool:
	return ClassDB.class_exists("StatusIndicator") and DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR)


func _setup_tray() -> void:
	if not tray_supported():
		return
	_tray_menu = PopupMenu.new()
	_tray_menu.prefer_native_menu = true
	_tray_menu.add_item(StoryText.ui("tray_show"), TRAY_SHOW)
	_tray_menu.add_item(StoryText.ui("tray_expedition"), TRAY_EXPEDITION)
	_tray_menu.add_separator()
	_tray_menu.add_item(StoryText.ui("tray_quit"), TRAY_QUIT)
	_tray_menu.id_pressed.connect(_on_tray_menu)
	add_child(_tray_menu)
	_tray = ClassDB.instantiate("StatusIndicator")
	_tray.set("icon", load("res://icon.svg"))
	_tray.set("tooltip", "Stairborn")
	add_child(_tray)
	_tray.set("menu", _tray.get_path_to(_tray_menu))
	_tray.connect("pressed", func(button: int, _pos: Vector2i):
		if button == MOUSE_BUTTON_LEFT:
			_show_from_tray("taskbar"))
	Game.floor_changed.connect(func(f: int): _tray.set("tooltip", Loc.t("Stairborn · Floor %d") % f))


func _on_tray_menu(id: int) -> void:
	match id:
		TRAY_SHOW:
			_show_from_tray("taskbar")
		TRAY_EXPEDITION:
			_show_from_tray("expedition")
		TRAY_QUIT:
			_quit()


func _show_from_tray(mode: String) -> void:
	# Nobody logged in yet: the tray can only bring back the login screen.
	WindowManager.show_from_tray(mode if Game.logged_in() else "story")


func _quit() -> void:
	Game.save()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_to_tray()


## Close button / window X: keeps climbing in the system tray when there is
## one, otherwise saves and quits.
func _close_to_tray() -> void:
	Game.save()
	if tray_supported() and _story_stage == "":
		WindowManager.hide_to_tray()
	else:
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if WindowManager.mode == "story":
		return
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
