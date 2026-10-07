extends SceneTree
## Loads every .gd file so parse errors anywhere (UI included) show up.
##   godot --headless --path . -s res://tools/check_scripts.gd
func _initialize() -> void:
	var bad := 0
	var n := 0
	for path in _scan("res://"):
		n += 1
		var s = load(path)
		if s == null or (s is GDScript and not s.can_instantiate() and not s.is_tool() and s.get_instance_base_type() == ""):
			bad += 1
			print("BAD: ", path)
	print("checked %d scripts, %d bad" % [n, bad])
	quit(1 if bad > 0 else 0)


func _scan(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with(".") and d != "export":
			out.append_array(_scan(dir.path_join(d)))
	return out
