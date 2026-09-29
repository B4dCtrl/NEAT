extends ScrollContainer
## QUESTS: the daily reward (7-day streak) and three contracts. Rewards are
## mostly climb-speeding items, so finishing goals feeds the climb.

const DataDB = preload("res://core/data_db.gd")
const Quests = preload("res://core/quests.gd")
const Loc = preload("res://core/loc.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")

var host
var _daily_box: VBoxContainer
var _contracts_box: VBoxContainer
var _sig := ""


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(v)
	v.add_child(Ornate.header_label(Loc.t("quests.daily")))
	_daily_box = VBoxContainer.new()
	v.add_child(_daily_box)
	v.add_child(Ornate.header_label(Loc.t("quests.contracts")))
	_contracts_box = VBoxContainer.new()
	v.add_child(_contracts_box)
	var hint := Ornate.small_label(Loc.t("quests.hint"), Ornate.TEXT_DIM, 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(220, 0)
	v.add_child(hint)
	Game.language_changed.connect(func(): _sig = "")


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	Quests.ensure(Game.state)
	var s: Dictionary = Game.state
	var sig := str([Loc.lang, Quests.today_string(), s.get("daily_last", ""), s.get("daily_streak", 0), s["contracts"].map(func(c): return [c["id"], Quests.progress(s, c)])])
	if sig != _sig:
		_sig = sig
		_rebuild()


func _rebuild() -> void:
	var s: Dictionary = Game.state
	for c in _daily_box.get_children():
		c.queue_free()
	for c in _contracts_box.get_children():
		c.queue_free()
	var st := Quests.daily_status(s, Quests.today_string())
	var days: Array = Quests.table()["daily"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	_daily_box.add_child(row)
	for i in days.size():
		var day_label := Label.new()
		day_label.text = str(i + 1)
		day_label.custom_minimum_size = Vector2(26, 22)
		day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var claimed: bool = (int(st["streak"]) % days.size() > i) if st["claimable"] else (int(st["streak"]) - 1) % days.size() >= i
		var today: bool = i + 1 == int(st["day"])
		day_label.add_theme_color_override("font_color", Ornate.GOOD if claimed and not (today and st["claimable"]) else (Ornate.ACCENT if today else Ornate.TEXT_DIM))
		day_label.tooltip_text = Quests.reward_text(days[i], s)
		row.add_child(day_label)
	var reward := Ornate.small_label(Loc.t("quests.today") % [int(st["day"]), Quests.reward_text(st["reward"], s)], Ornate.TEXT, 11)
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward.custom_minimum_size = Vector2(230, 0)
	_daily_box.add_child(reward)
	var claim := Button.new()
	claim.focus_mode = Control.FOCUS_NONE
	claim.text = Loc.t("quests.claim") if st["claimable"] else Loc.t("quests.come_back")
	claim.disabled = not st["claimable"]
	claim.pressed.connect(func(): Game.claim_daily(); _sig = "")
	_daily_box.add_child(claim)

	for i in s["contracts"].size():
		var c: Dictionary = s["contracts"][i]
		var panel := PanelContainer.new()
		_contracts_box.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		panel.add_child(v)
		var title := Ornate.small_label(Quests.describe(c), Ornate.ACCENT, 12)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size = Vector2(230, 0)
		v.add_child(title)
		var bar := ProgressBar.new()
		bar.max_value = float(c["target"])
		bar.value = float(Quests.progress(s, c))
		bar.custom_minimum_size = Vector2(0, 8)
		bar.show_percentage = false
		v.add_child(bar)
		var foot := HBoxContainer.new()
		v.add_child(foot)
		var rw := Ornate.small_label("%d/%d · %s" % [Quests.progress(s, c), int(c["target"]), Quests.reward_text(Quests.template(c).get("reward", {}), s)], Ornate.TEXT_DIM, 11)
		rw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rw.custom_minimum_size = Vector2(150, 0)
		foot.add_child(rw)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = Loc.t("quests.claim")
		b.disabled = not Quests.is_done(s, c)
		var idx: int = i
		b.pressed.connect(func(): Game.claim_contract(idx); _sig = "")
		foot.add_child(b)
