extends RefCounted
## "Share my climb": renders a 1200x630 card (the size social networks and
## Discord preview best) with the party, its looks and its records, saves it as a
## PNG in Pictures/Stairborn and shows it in the file manager. Bragging is how
## idle games spread, so it is one click away.

const DataDB = preload("res://core/data_db.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const Cosmetics = preload("res://core/cosmetics.gd")
const CosmeticArt = preload("res://scenes/entities/cosmetic_art.gd")
const Torment = preload("res://core/torment.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const Loc = preload("res://core/loc.gd")

const W := 1200
const H := 630


## Builds the card and saves it. Returns the file path ("" on failure).
static func make(tree: SceneTree, state: Dictionary) -> String:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	tree.root.add_child(vp)
	var root := Control.new()
	root.size = Vector2(W, H)
	root.theme = Ornate.theme()
	vp.add_child(root)
	_build(root, state)
	await tree.process_frame
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null:
		return ""
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	dir = (dir if dir != "" else OS.get_user_data_dir()).path_join("Stairborn")
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")
	var path := dir.path_join("stairborn-%s.png" % stamp)
	if img.save_png(path) != OK:
		return ""
	return path


static func _label(parent: Control, text: String, size: int, color: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#0b0806"))
	l.add_theme_constant_override("outline_size", maxi(2, size / 8))
	parent.add_child(l)
	return l


static func _build(root: Control, s: Dictionary) -> void:
	var skin := Cosmetics.equipped(s, "tower")
	var sky := Color(Cosmetics.def(skin)["colors"]["sky"]) if skin != "" else Color("#141019")
	var bg := ColorRect.new()
	bg.color = sky.darkened(0.2)
	bg.size = Vector2(W, H)
	root.add_child(bg)
	# warm band behind the party
	var band := ColorRect.new()
	band.color = Color(1, 0.8, 0.4, 0.07)
	band.position = Vector2(0, 360)
	band.size = Vector2(W, 190)
	root.add_child(band)
	if skin != "":
		var t := TextureRect.new()
		t.texture = CosmeticArt.icon(skin)
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.position = Vector2(W - 260, 40)
		t.size = Vector2(220, 220)
		t.modulate.a = 0.85
		root.add_child(t)

	_label(root, "STAIRBORN", 72, Ornate.ACCENT, Vector2(48, 30))
	var founder: Dictionary = s["heroes"][0]
	_label(root, Loc.t("%s's climb") % founder["name"], 30, Ornate.TEXT, Vector2(52, 120))
	var lines := [
		Loc.t("Best floor: %d") % int(s["best_floor_ever"]),
		Loc.t("Difficulty: %s") % Torment.name(Torment.unlocked(s)),
		Loc.t("Ascensions: %d") % int(s["ascensions"]),
	]
	var col := Cosmetics.collection(s)
	lines.append(Loc.t("Looks collected: %d/%d") % [int(col["unique"]), int(col["total"])])
	for i in lines.size():
		_label(root, lines[i], 26, Ornate.TEXT_DIM, Vector2(54, 175 + i * 36))

	# the party, big, with its pet
	var mods := StatCalc.party_mods(s)
	var x := 80.0
	for hero in s["heroes"]:
		var cdef: Dictionary = DataDB.classes()[hero["class"]]
		var f := PixelArt.unit_frames(hero["class"], cdef["sprite"], {}, false)
		var tr := TextureRect.new()
		tr.texture = f[0]
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tr.position = Vector2(x, 360)
		tr.size = Vector2(150, 170)
		root.add_child(tr)
		var nm := _label(root, hero["name"], 20, UiUtil.rarity_color(hero.get("rarity", "common")), Vector2(x, 530))
		nm.custom_minimum_size = Vector2(150, 0)
		_label(root, Loc.t("Lv %d · Power %s") % [int(hero["level"]), UiUtil.num(StatCalc.power_rating(StatCalc.hero_stats(s, hero, mods)))], 16, Ornate.TEXT_DIM, Vector2(x, 558))
		x += 190.0
	var pet := Cosmetics.equipped(s, "pet")
	if pet != "":
		var pt := TextureRect.new()
		pt.texture = CosmeticArt.icon(pet)
		pt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		pt.position = Vector2(x - 20, 450)
		pt.size = Vector2(80, 80)
		root.add_child(pt)
	# the rarest look owned
	var best := ""
	for id in Cosmetics.items():
		if Cosmetics.owned(s, id) > 0 and (best == "" or DataDB.rarity_order(Cosmetics.def(id)["rarity"]) > DataDB.rarity_order(Cosmetics.def(best)["rarity"])):
			best = id
	if best != "":
		var d := Cosmetics.def(best)
		_label(root, Loc.t("Rarest look: %s") % d["name"], 22, UiUtil.rarity_color(d["rarity"]), Vector2(W - 520, 300))
	_label(root, Loc.t("Climb with me: Stairborn on Steam"), 20, Ornate.TEXT_DIM, Vector2(W - 520, H - 50))
