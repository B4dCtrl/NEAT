extends Control
## Login screen shown before the game, like Steam's: sign in with a name and
## password, or create a new account (every account starts from zero and has
## its own encrypted save). "Remember me" skips this screen next time.

signal logged_in()

const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const Accounts = preload("res://core/accounts.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const StoryText = preload("res://scenes/ui/story_text.gd")

const TEXT := {
	"en": {
		"title": "Sign in", "create_title": "Create account", "user": "Account name", "password": "Password",
		"confirm": "Confirm password", "remember": "Remember me on this computer", "sign_in": "Sign in",
		"create": "Create account", "to_create": "New here? Create an account", "to_sign_in": "Already have an account? Sign in",
		"note": "Accounts are stored on this computer. Each one has its own encrypted save and starts from floor 1.",
		"name_length": "The name needs 3 to 16 characters.", "name_chars": "Use only letters, numbers and _ in the name.",
		"password_length": "The password needs at least 6 characters.", "name_taken": "That name is already taken.",
		"no_account": "No account with that name. Create one below.", "wrong_password": "Wrong password.",
		"mismatch": "The passwords do not match.",
	},
	"pt": {
		"title": "Entrar", "create_title": "Criar conta", "user": "Nome da conta", "password": "Senha",
		"confirm": "Confirmar senha", "remember": "Lembrar de mim neste computador", "sign_in": "Entrar",
		"create": "Criar conta", "to_create": "Novo por aqui? Crie uma conta", "to_sign_in": "Já tem conta? Entrar",
		"note": "As contas ficam neste computador. Cada uma tem seu próprio save criptografado e começa do andar 1.",
		"name_length": "O nome precisa ter de 3 a 16 caracteres.", "name_chars": "Use só letras, números e _ no nome.",
		"password_length": "A senha precisa ter pelo menos 6 caracteres.", "name_taken": "Esse nome já está em uso.",
		"no_account": "Não existe conta com esse nome. Crie uma abaixo.", "wrong_password": "Senha incorreta.",
		"mismatch": "As senhas não conferem.",
	},
}

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


static func t(key: String) -> String:
	return TEXT[StoryText.lang()].get(key, TEXT["en"].get(key, key))


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
	var note := Ornate.small_label(t("note"), Ornate.TEXT_DIM, 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(380, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)
	_set_creating(Accounts.last_user() == "")


func _field(v: VBoxContainer, label: String, secret: bool) -> LineEdit:
	v.add_child(Ornate.small_label(label, Ornate.TEXT_DIM, 12))
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
