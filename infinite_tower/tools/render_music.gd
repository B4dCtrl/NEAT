extends SceneTree
## Renders every music theme to a WAV file and prints its stats, so the music
## can be inspected without playing the game (length, loudness, peak, how
## smoothly the loop closes).
##   godot --headless --path . -s res://tools/render_music.gd -- <out_dir> [theme ...]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if not args.is_empty() else "user://music"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var themes: Array = args.slice(1) if args.size() > 1 else ["climb", "boss", "elite", "lord", "rage", "fall", "camp"]
	_run(out_dir, themes)


func _run(out_dir: String, themes: Array) -> void:
	await process_frame
	var audio = root.get_node("Audio")
	for t in themes:
		var t0 := Time.get_ticks_msec()
		var wav: AudioStreamWAV = await audio.render(t)
		if wav == null:
			print(t, ": not rendered")
			continue
		var d := wav.data
		var n := d.size() / 2
		var sum := 0.0
		var peak := 0
		for i in n:
			var v := d.decode_s16(i * 2)
			sum += float(v) * float(v)
			peak = maxi(peak, absi(v))
		var rms := sqrt(sum / n) / 32768.0
		var seam := absf(float(d.decode_s16((n - 1) * 2)) - float(d.decode_s16(0))) / 32768.0
		wav.save_to_wav(out_dir.path_join(t + ".wav"))
		print("%-6s %5.1fs  rms %.3f  peak %.2f  loop seam %.4f  rendered in %d ms" % [t, float(n) / wav.mix_rate, rms, float(peak) / 32768.0, seam, Time.get_ticks_msec() - t0])
	quit()
