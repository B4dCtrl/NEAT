extends SceneTree
## Turns raw PixelLab downloads into game-ready sprites in res://assets/sprites.
##   godot --headless --path . -s res://tools/import_pixellab.gd -- <raw_dir>
##
## <raw_dir> layout:
##   units/<id>.png            single image (enemies, bosses: generated facing LEFT)
##   icons/<id>.png            item / HUD icons (copied as-is, trimmed)
##   heroes/<class>/east.png   hero facing right
##   heroes/<class>/walk/*.png optional walk frames facing right (sorted by name)
##
## Every unit is trimmed to its visible pixels, packed into square frames with
## the feet on the bottom edge, and written as a horizontal strip. Units face
## RIGHT in the game (the renderer mirrors enemies), so left-facing art is flipped.

const OUT := "res://assets/sprites/"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -- <raw_dir>")
		quit(1)
		return
	var raw: String = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var count := 0
	for f in _pngs(raw.path_join("units")):
		_write_strip([_load(raw.path_join("units").path_join(f))], f.get_basename(), true)
		count += 1
	for f in _pngs(raw.path_join("icons")):
		var img := _load(raw.path_join("icons").path_join(f))
		_trim(img).save_png(ProjectSettings.globalize_path(OUT + f))
		count += 1
	var hero_dir := raw.path_join("heroes")
	if DirAccess.dir_exists_absolute(hero_dir):
		for cls in DirAccess.get_directories_at(hero_dir):
			var frames := []
			var walk := hero_dir.path_join(cls).path_join("walk")
			for f in _pngs(walk):
				frames.append(_load(walk.path_join(f)))
			if frames.is_empty():
				frames.append(_load(hero_dir.path_join(cls).path_join("east.png")))
			_write_strip(frames, cls, false)
			count += 1
	print("imported %d sprites into %s" % [count, OUT])
	quit()


func _pngs(dir: String) -> Array:
	if not DirAccess.dir_exists_absolute(dir):
		return []
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			out.append(f)
	out.sort()
	return out


func _load(path: String) -> Image:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGBA8)
	return img


func _trim(img: Image) -> Image:
	var r := img.get_used_rect()
	return img.get_region(r) if r.size.x > 0 else img


## Packs frames into equal square cells (feet bottom-centred) and saves a strip.
func _write_strip(frames: Array, id: String, flip: bool) -> void:
	var trimmed := []
	var side := 0
	for f in frames:
		var t := _trim(f)
		if flip:
			t.flip_x()
		trimmed.append(t)
		side = maxi(side, maxi(t.get_width(), t.get_height()))
	var strip := Image.create(side * trimmed.size(), side, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for i in trimmed.size():
		var t: Image = trimmed[i]
		var pos := Vector2i(i * side + (side - t.get_width()) / 2, side - t.get_height())
		strip.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), pos)
	strip.save_png(ProjectSettings.globalize_path(OUT + id + ".png"))
