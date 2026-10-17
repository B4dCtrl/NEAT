extends SceneTree
## Writes the third-party notices the installer ships next to the game:
## Godot's license and the licenses of the libraries inside it, plus the
## symbol font's.  godot --headless --path . -s res://tools/make_notices.gd


func _initialize() -> void:
	var out := PackedStringArray()
	out.append("Stairborn uses the Godot Engine (https://godotengine.org).")
	out.append("")
	out.append(Engine.get_license_text())
	out.append("")
	out.append("=== Components included in the Godot Engine ===")
	for part in Engine.get_copyright_info():
		out.append("")
		out.append("- " + String(part["name"]))
		for p in part["parts"]:
			out.append("  License: " + String(p["license"]))
			for c in p["copyright"]:
				out.append("  Copyright " + String(c))
	out.append("")
	out.append("=== Licenses ===")
	var licenses: Dictionary = Engine.get_license_info()
	for k in licenses:
		out.append("")
		out.append("--- " + String(k) + " ---")
		out.append(String(licenses[k]))
	out.append("")
	out.append("=== Stairborn Symbols font ===")
	out.append(FileAccess.get_file_as_string("res://assets/fonts/LICENSE-stairborn_symbols.txt"))
	var f := FileAccess.open("res://tools/installer/THIRD_PARTY_NOTICES.txt", FileAccess.WRITE)
	f.store_string("\n".join(out))
	print("notices written")
	quit()
