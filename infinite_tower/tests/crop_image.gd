extends SceneTree
## Crops + upscales a screenshot for inspection.
##   godot --headless --path . -s res://tests/crop_image.gd -- in.png out.png x y w h scale
func _initialize():
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	var r := Rect2i(int(a[2]), int(a[3]), int(a[4]), int(a[5]))
	var c := img.get_region(r)
	c.resize(r.size.x * int(a[6]), r.size.y * int(a[6]), Image.INTERPOLATE_NEAREST)
	c.save_png(a[1])
	quit()
