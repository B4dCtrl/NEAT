extends Control
## Login screen shown before the game, like Steam's: sign in with a name and
## password, or create a new account (every account starts from zero and has
## its own encrypted save). "Remember me" skips this screen next time.

signal logged_in()

const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const Accounts = preload("res://core/accounts.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const Loc = preload("res://core/loc.gd")

var _creating := false
var _title: Label
var _user: LineEdit
var _pass: LineEdit
var _confirm: LineEdit
var _confirm_label: Label
var _remember: CheckBox
var _go: Button
var _switch: Button
var _error: Label
var _lang: OptionButton
var _note: Label
var _user_label: Label
var _pass_label: Label


static func t(key: String) -> String:
	return Loc.t(key if key.begins_with("login.") else "err." + key if key in ["name_length", "name_chars", "password_length", "name_taken", "no_account", "wrong_password", "mismatch"] else "login." + key)


func _ready() -> void:
	theme = Ornate.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("#0d0b10")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var logo := Label.new()
	logo.text = "STAIRBORN"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 40)
	logo.add_theme_color_override("font_color", Ornate.ACCENT)
	logo.add_theme_color_override("font_outline_color", Ornate.OUT)
	logo.add_theme_constant_override("outline_size", 8)
	col.add_child(logo)
	var hero := TextureRect.new()
	hero.texture = PixelArt.unit_frames("stairborn", "stairborn", {}, false)[0]
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero.custom_minimum_size = Vector2(0, 96)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(hero)

	var frame := _Frame.new()
	frame.custom_minimum_size = Vector2(380, 360)
	col.add_child(frame)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	margin.add_theme_constant_override("margin_top", 42)
	frame.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	margin.add_child(v)
	_title = Ornate.header_label("")
	frame.title_label = _title
	_user = _field(v, t("user"), false)
	_user.text = Accounts.last_user()
	_pass = _field(v, t("password"), true)
	_confirm_label = Ornate.small_label(t("confirm"), Ornate.TEXT_DIM, 12)
	v.add_child(_confirm_label)
	_confirm = LineEdit.new()
	_confirm.secret = true
	_confirm.max_length = 64
	_confirm.text_submitted.connect(func(_s): _submit())
	var sb := Ornate.inset_box(6.0)
	_confirm.add_theme_stylebox_override("normal", sb)
	_confirm.add_theme_stylebox_override("focus", sb)
	_confirm.add_theme_color_override("font_color", Ornate.TEXT)
	v.add_child(_confirm)
	_remember = CheckBox.new()
	_remember.text = t("remember")
	_remember.focus_mode = Control.FOCUS_NONE
	v.add_child(_remember)
	_error = Ornate.small_label("", Ornate.BAD, 12)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.custom_minimum_size = Vector2(300, 0)
	v.add_child(_error)
	_go = Button.new()
	_go.custom_minimum_size = Vector2(0, 34)
	_go.pressed.connect(_submit)
	v.add_child(_go)
	_switch = Button.new()
	_switch.flat = true
	_switch.focus_mode = Control.FOCUS_NONE
	_switch.add_theme_color_override("font_color", Ornate.ACCENT)
	_switch.pressed.connect(func(): _set_creating(not _creating))
	v.add_child(_switch)
	_lang = OptionButton.new()
	_lang.focus_mode = Control.FOCUS_NONE
	for code in Loc.LANGUAGES:
		_lang.add_item(Loc.LANGUAGES[code])
		_lang.set_item_metadata(_lang.item_count - 1, code)
		if code == Loc.current():
			_lang.select(_lang.item_count - 1)
	_lang.item_selected.connect(func(i): Game.set_language(_lang.get_item_metadata(i)))
	col.add_child(_lang)
	Game.language_changed.connect(_retranslate)
	var note := Ornate.small_label(t("note"), Ornate.TEXT_DIM, 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(380, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note = note
	col.add_child(note)
	var ver := Ornate.small_label("v" + str(ProjectSettings.get_setting("application/config/version", "")), Ornate.TEXT_DIM, 11)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ver)
	_set_creating(Accounts.last_user() == "")


func _field(v: VBoxContainer, label: String, secret: bool) -> LineEdit:
	var lbl := Ornate.small_label(label, Ornate.TEXT_DIM, 12)
	v.add_child(lbl)
	if secret:
		_pass_label = lbl
	else:
		_user_label = lbl
	var e := LineEdit.new()
	e.secret = secret
	e.max_length = 16 if not secret else 64
	e.text_submitted.connect(func(_s): _submit())
	var sb := Ornate.inset_box(6.0)
	e.add_theme_stylebox_override("normal", sb)
	e.add_theme_stylebox_override("focus", sb)
	e.add_theme_color_override("font_color", Ornate.TEXT)
	v.add_child(e)
	return e


func _retranslate() -> void:
	_user_label.text = t("user")
	_pass_label.text = t("password")
	_confirm_label.text = t("confirm")
	_remember.text = t("remember")
	_note.text = t("note")
	_set_creating(_creating)


func start() -> void:
	_error.text = ""
	_pass.text = ""
	_confirm.text = ""
	_set_creating(Accounts.last_user() == "")
	(_pass if _user.text != "" else _user).grab_focus.call_deferred()


func _set_creating(on: bool) -> void:
	_creating = on
	_title.text = t("create_title") if on else t("title")
	_confirm.visible = on
	_confirm_label.visible = on
	_go.text = t("create") if on else t("sign_in")
	_switch.text = t("to_sign_in") if on else t("to_create")
	_error.text = ""
	queue_redraw()


func _submit() -> void:
	var err := ""
	if _creating:
		if _pass.text != _confirm.text:
			err = "mismatch"
		else:
			err = Game.create_account(_user.text, _pass.text, _remember.button_pressed)
	else:
		err = Game.sign_in(_user.text, _pass.text, _remember.button_pressed)
	if err != "":
		_error.text = t(err)
		if err == "no_account":
			_set_creating(true)
			_error.text = t(err)
		Game.sfx_requested.emit("miss")
		return
	_pass.text = ""
	_confirm.text = ""
	Game.sfx_requested.emit("fanfare")
	logged_in.emit()


## Ornate frame with the ribbon title drawn behind the form.
class _Frame extends Control:
	const O = preload("res://scenes/ui/menu/ornate.gd")
	var title_label: Label

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var title := title_label.text if title_label != null else ""
		O.draw_frame(self, Rect2(Vector2.ZERO, size), title.to_upper(), get_theme_default_font(), 15)
