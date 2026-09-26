extends RefCounted
## Short-lived combat visuals: slashes, arrows, fireballs, hit sparks, crit
## starbursts, dodge whooshes and one effect per skill. Purely cosmetic; the
## stage spawns them from combat events and draws them above the sprites.

var fx: Array = []          # {kind, a, b, t, dur, delay, color, s}
var particles: Array = []   # {p, v, t, dur, color, s, g}
var shake := 0.0
var _rng := RandomNumberGenerator.new()


func clear() -> void:
	fx.clear()
	particles.clear()
	shake = 0.0


func spawn(kind: String, a: Vector2, b: Vector2, color: Color, s: float = 1.0, dur: float = 0.3, delay: float = 0.0) -> void:
	if fx.size() > 160:
		return
	fx.append({"kind": kind, "a": a, "b": b, "t": -delay, "dur": dur, "color": color, "s": s})


func burst_particles(at: Vector2, color: Color, count: int, speed: float, s: float = 1.0, gravity: float = 0.0, dur: float = 0.5) -> void:
	for i in count:
		if particles.size() > 300:
			return
		var ang := _rng.randf() * TAU
		var v := Vector2(cos(ang), sin(ang)) * speed * _rng.randf_range(0.4, 1.0)
		particles.append({"p": at, "v": v, "t": 0.0, "dur": dur * _rng.randf_range(0.7, 1.2), "color": color, "s": s, "g": gravity})


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


func shake_offset() -> Vector2:
	if shake <= 0.0:
		return Vector2.ZERO
	return Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * shake * 6.0


func update(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.5)
	for f in fx:
		f["t"] += delta
	fx = fx.filter(func(f): return f["t"] < f["dur"])
	for p in particles:
		p["t"] += delta
		p["v"].y += p["g"] * delta
		p["p"] += p["v"] * delta
	particles = particles.filter(func(p): return p["t"] < p["dur"])


func draw(ci: CanvasItem, px: float) -> void:
	for f in fx:
		if f["t"] < 0.0:
			continue
		var k: float = f["t"] / f["dur"]
		call("_draw_" + f["kind"], ci, f, k, px * f["s"])
	for p in particles:
		var c: Color = p["color"]
		c.a *= 1.0 - p["t"] / p["dur"]
		var sz: float = px * p["s"]
		ci.draw_rect(Rect2(p["p"] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), c)


# ------------------------------------------------------------------ shapes

func _fade(c: Color, k: float) -> Color:
	var o := c
	o.a *= 1.0 - k
	return o


func _draw_slash(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	# Three swift arcs crossing the target.
	var b: Vector2 = f["b"]
	var r := 9.0 * u
	for i in 3:
		var start := -2.4 + i * 0.35 + k * 1.4
		ci.draw_arc(b + Vector2(-2 * u + i * 2 * u, -i * u), r, start, start + 1.2, 8, _fade(f["color"], k), maxf(1.0, u * (1.4 - i * 0.3)))


func _draw_claw(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	var b: Vector2 = f["b"]
	for i in 3:
		var off := Vector2((i - 1) * 3.0 * u, 0)
		var p0 := b + off + Vector2(4, -6) * u
		var p1 := p0.lerp(b + off + Vector2(-4, 6) * u, minf(1.0, k * 2.5))
		ci.draw_line(p0, p1, _fade(f["color"], k), maxf(1.0, u))


func _draw_arrow(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	var a: Vector2 = f["a"]
	var b: Vector2 = f["b"]
	var p := a.lerp(b, k) + Vector2(0, -sin(k * PI) * 6.0 * u)
	var dir := (b - a).normalized()
	ci.draw_line(p - dir * 7.0 * u, p, Color("#c9a36b"), maxf(1.0, u * 0.8))
	ci.draw_line(p, p - dir.rotated(0.5) * 2.5 * u, Color("#e0e6ee"), maxf(1.0, u * 0.8))
	ci.draw_line(p, p - dir.rotated(-0.5) * 2.5 * u, Color("#e0e6ee"), maxf(1.0, u * 0.8))


func _draw_bolt(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	# Fireballs and enemy orbs: a glowing ball with a short trail.
	var a: Vector2 = f["a"]
	var b: Vector2 = f["b"]
	var c: Color = f["color"]
	for i in 4:
		var kk := maxf(0.0, k - i * 0.08)
		var p := a.lerp(b, kk) + Vector2(0, -sin(kk * PI) * 5.0 * u)
		var cc := c
		cc.a = 0.9 - i * 0.22
		ci.draw_circle(p, (3.2 - i * 0.6) * u, cc)
	ci.draw_circle(a.lerp(b, k) + Vector2(0, -sin(k * PI) * 5.0 * u), 1.4 * u, Color(1, 1, 0.85))


func _draw_spark(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	var b: Vector2 = f["b"]
	var r := (2.0 + k * 5.0) * u
	for i in 4:
		var d := Vector2.RIGHT.rotated(i * PI * 0.5 + 0.4)
		ci.draw_line(b + d * r * 0.4, b + d * r, _fade(f["color"], k), maxf(1.0, u * 0.7))


func _draw_burst(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	ci.draw_arc(f["b"], (3.0 + k * 14.0) * u, 0, TAU, 20, _fade(f["color"], k), maxf(1.0, u * 1.2 * (1.0 - k)))


func _draw_crit(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	# Big starburst behind the hit.
	var b: Vector2 = f["b"]
	var pts := PackedVector2Array()
	var rays := 8
	for i in rays * 2:
		var r := (10.0 if i % 2 == 0 else 4.0) * u * (0.6 + k * 0.8)
		pts.append(b + Vector2.RIGHT.rotated(i * PI / rays + k) * r)
	ci.draw_colored_polygon(pts, _fade(f["color"], k))
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), _fade(Color.WHITE, k), maxf(1.0, u * 0.6))


func _draw_whoosh(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	var b: Vector2 = f["b"]
	for i in 3:
		var y := (i - 1) * 4.0 * u
		var x0 := b.x - (10.0 - k * 6.0) * u
		ci.draw_line(Vector2(x0, b.y + y), Vector2(x0 + 8.0 * u, b.y + y), _fade(f["color"], k), maxf(1.0, u * 0.6))


func _draw_dome(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	var c: Color = f["color"]
	c.a = 0.35 * (1.0 - k) + 0.1
	var r: float = 22.0 * u * (0.7 + 0.3 * minf(1.0, k * 4.0))
	ci.draw_arc(f["b"], r, PI, TAU, 24, c, maxf(1.0, u * 1.5))
	var fill := c
	fill.a *= 0.35
	ci.draw_circle(f["b"], r, fill)


func _draw_rain(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	var b: Vector2 = f["b"]
	for i in 7:
		var x := b.x + (i - 3) * 5.0 * u
		var y := b.y - 30.0 * u + fposmod(k * 60.0 + i * 11.0, 30.0) * u
		ci.draw_line(Vector2(x, y), Vector2(x - 2 * u, y - 6 * u), _fade(Color("#e0e6ee"), k * 0.5), maxf(1.0, u * 0.6))


func _draw_meteor(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	var b: Vector2 = f["b"]
	var a: Vector2 = b + Vector2(-30, -60) * u
	var p := a.lerp(b, minf(1.0, k * 1.4))
	for i in 5:
		var q := a.lerp(b, maxf(0.0, minf(1.0, k * 1.4) - i * 0.06))
		ci.draw_circle(q, (6.0 - i) * u, Color(1.0, 0.5 - i * 0.07, 0.1, 0.9 - i * 0.16))
	ci.draw_circle(p, 3.0 * u, Color(1, 0.95, 0.7))


func _draw_heal(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	for i in 4:
		var p: Vector2 = f["b"] + Vector2((i - 1.5) * 6.0 * u, -k * 16.0 * u - (i % 2) * 5.0 * u)
		var c := _fade(Color("#5fd35f"), k)
		ci.draw_rect(Rect2(p - Vector2(1, 3) * u, Vector2(2, 6) * u), c)
		ci.draw_rect(Rect2(p - Vector2(3, 1) * u, Vector2(6, 2) * u), c)


func _draw_shockwave(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	var a: Vector2 = f["a"]
	var r := k * 70.0 * u
	ci.draw_arc(a, r, PI * 0.55, PI * 1.45, 20, _fade(f["color"], k), maxf(1.0, u * 2.0 * (1.0 - k)))
	ci.draw_arc(a, r * 0.8, PI * 0.6, PI * 1.4, 20, _fade(f["color"], k * 1.3), maxf(1.0, u))


func _draw_drain(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	var a: Vector2 = f["a"]
	var b: Vector2 = f["b"]
	var pts := PackedVector2Array()
	for i in 9:
		var q := float(i) / 8.0
		pts.append(a.lerp(b, q) + Vector2(0, sin(q * PI * 3.0 + k * 12.0) * 3.0 * u))
	ci.draw_polyline(pts, _fade(f["color"], k), maxf(1.0, u))


func _draw_hexshield(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		pts.append(f["b"] + Vector2.RIGHT.rotated(i * TAU / 6.0 + k) * 18.0 * u)
	ci.draw_polyline(pts, _fade(f["color"], k * 0.8), maxf(1.0, u * 1.2))


func _draw_aura(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	var c: Color = f["color"]
	c.a = 0.3 * (1.0 - k) * (0.6 + 0.4 * sin(k * 30.0))
	ci.draw_circle(f["b"], 16.0 * u, c)


func _draw_lightning(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	var a: Vector2 = f["a"]
	var b: Vector2 = f["b"]
	var pts := PackedVector2Array([a])
	for i in range(1, 6):
		pts.append(a.lerp(b, i / 6.0) + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3)) * u)
	pts.append(b)
	ci.draw_polyline(pts, _fade(Color("#fff27a"), k), maxf(1.0, u))


func _draw_bomb(ci: CanvasItem, f: Dictionary, k: float, u: float) -> void:
	var a: Vector2 = f["a"]
	var b: Vector2 = f["b"]
	var p := a.lerp(b, k) + Vector2(0, -sin(k * PI) * 30.0 * u)
	ci.draw_circle(p, 3.5 * u, Color("#2a2a33"))
	ci.draw_circle(p + Vector2(2, -3) * u, 1.2 * u, Color("#ffb13d"))
