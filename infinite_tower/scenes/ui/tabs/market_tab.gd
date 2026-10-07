extends MarginContainer
## The Tower Market (rotating stock: gear, heroes, a featured Legendary, relics)
## and the Steam Community Market link.

const DataDB = preload("res://core/data_db.gd")
const Market = preload("res://core/market.gd")
const PlatformServices = preload("res://core/platform_services.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const PartyTab = preload("res://scenes/ui/tabs/party_tab.gd")
const ItemSlot = preload("res://scenes/ui/item_slot.gd")

var _grid: GridContainer
var _timer: Label
var _reroll: Button
var _steam_status: Label
var _rotation := -1
var _dirty := true


func _ready() -> void:
	var v := VBoxContainer.new()
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var icon := TextureRect.new()
	icon.texture = PixelArt.icon("market")
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top.add_child(icon)
	var title := Label.new()
	title.text = "Tower Market"
	title.add_theme_color_override("font_color", Color("#f2c14e"))
	top.add_child(title)
	_timer = Label.new()
	_timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer.add_theme_color_override("font_color", Color("#9a96a8"))
	top.add_child(_timer)
	_reroll = Button.new()
	_reroll.focus_mode = Control.FOCUS_NONE
	_reroll.pressed.connect(func(): Game.market_reroll(); _dirty = true)
	top.add_child(_reroll)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)

	var steam := PanelContainer.new()
	v.add_child(steam)
	var sh := HBoxContainer.new()
	steam.add_child(sh)
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(sv)
	var st := Label.new()
	st.text = "Steam Community Market"
	st.add_theme_color_override("font_color", Color("#7fb2d9"))
	sv.add_child(st)
	_steam_status = Label.new()
	_steam_status.add_theme_font_size_override("font_size", 12)
	_steam_status.add_theme_color_override("font_color", Color("#9a96a8"))
	_steam_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(_steam_status)
	var open := Button.new()
	open.focus_mode = Control.FOCUS_NONE
	open.text = "Open Steam Market"
	open.pressed.connect(func(): PlatformServices.open_market())
	sh.add_child(open)
	var sync := Button.new()
	sync.focus_mode = Control.FOCUS_NONE
	sync.text = "Sync Steam inventory"
	sync.pressed.connect(func():
		if not PlatformServices.request_inventory():
			Game.notified.emit("info", "Steam is not available"))
	sh.add_child(sync)

	Game.state_changed.connect(_tick)
	visibility_changed.connect(func(): _dirty = true)


func _tick() -> void:
	if not is_visible_in_tree():
		return
	var now := int(Time.get_unix_time_from_system())
	_timer.text = "   New stock in %s" % UiUtil.duration(Market.seconds_to_rotation(now))
	if Market.rotation_id(now) != _rotation:
		_dirty = true
	var cost := int(Market.rules()["reroll_crystals"])
	_reroll.text = "Reroll stock (%d crystals)" % cost
	_reroll.disabled = int(Game.state["crystals"]) < cost
	for row in _grid.get_children():
		if row.has_meta("offer"):
			var btn: Button = row.get_meta("buy_button")
			var offer: Dictionary = Game.state["market"]["offers"][row.get_meta("offer")]
			btn.disabled = offer["sold"] or not Market.can_afford(Game.state, offer)


func _process(_delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		_rebuild()


func _rebuild() -> void:
	var offers := Game.market_offers()
	_rotation = int(Game.state["market"]["rotation"])
	_steam_status.text = PlatformServices.status_text() + ". Gems and set pieces are Steam items: once the Steam app is live they can be traded there."
	for c in _grid.get_children():
		c.queue_free()
	for i in offers.size():
		_grid.add_child(_offer_row(i, offers[i]))
	_tick()


func _offer_row(i: int, offer: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("offer", i)
	var h := HBoxContainer.new()
	panel.add_child(h)
	var title := ""
	var sub := ""
	var color := Color.WHITE
	if offer.has("item"):
		var cell = ItemSlot.new()
		cell.setup(offer["item"], -1, "", 44.0)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(cell)
		title = offer["item"]["name"]
		sub = "%s %s · iLvl %d" % [DataDB.rarities()[offer["item"]["rarity"]]["name"], offer["item"]["slot"].capitalize(), offer["item"]["ilvl"]]
		color = UiUtil.rarity_color(offer["item"]["rarity"])
		panel.tooltip_text = PartyTab.item_tooltip(offer["item"])
	elif offer.has("consumable"):
		var cdef: Dictionary = DataDB.items()["consumables"][offer["consumable"]]
		h.add_child(_icon(PixelArt.frames(cdef["icon"])[0]))
		title = "%s x%d" % [cdef["name"], int(offer.get("qty", 1))]
		sub = cdef["text"]
		color = Color("#e6e2d3")
		panel.tooltip_text = cdef["text"]
	elif offer.has("hero"):
		var hero: Dictionary = offer["hero"]
		var cdef: Dictionary = DataDB.classes()[hero["class"]]
		h.add_child(_icon(PixelArt.unit_frames(hero["class"], cdef["sprite"], {}, false)[0]))
		title = "%s the %s" % [hero["name"], cdef["name"]]
		sub = "Hero · %s potential (x%.2f stats)" % [hero["rarity"].capitalize(), hero["potential"]]
		color = UiUtil.rarity_color(hero["rarity"])
		panel.tooltip_text = "%s\n%s" % [cdef["role"], cdef["skill"]["description"]]
	else:
		var relic: Dictionary = DataDB.relics()[offer["relic"]]
		h.add_child(_icon(PixelArt.gem(String(offer["relic"]))))
		title = relic["name"]
		sub = "GEM · " + relic["description"]
		color = UiUtil.rarity_color("relic")
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	h.add_child(text)
	var t := Label.new()
	t.text = title
	t.add_theme_color_override("font_color", color)
	t.clip_text = true
	text.add_child(t)
	var s := Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 11)
	s.add_theme_color_override("font_color", Color("#9a96a8"))
	s.clip_text = true
	text.add_child(s)
	var buy := Button.new()
	buy.focus_mode = Control.FOCUS_NONE
	buy.custom_minimum_size = Vector2(120, 0)
	if offer["sold"]:
		buy.text = "Sold"
	else:
		buy.text = "%s %s" % [UiUtil.num(offer["price"]), "gold" if offer["currency"] == "gold" else "crystals"]
		buy.icon = PixelArt.icon("coin" if offer["currency"] == "gold" else "crystal")
	buy.pressed.connect(func(): Game.market_buy(i); _dirty = true)
	h.add_child(buy)
	panel.set_meta("buy_button", buy)
	return panel


func _icon(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(44, 44)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return r
