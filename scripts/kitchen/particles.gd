class_name Particles
extends RefCounted
## Partículas simples desenhadas como píxeis: vapor, fumo, suor, pedaços a
## saltar da tábua e brilhos ao servir. Têm um limite para não pesar em PCs fracos.

const MAX := 300

var _items: Array[Dictionary] = []


func update(delta: float) -> void:
	for p in _items:
		p["life"] -= delta
		p["vel"] += p["acc"] * delta
		p["pos"] += p["vel"] * delta
	_items = _items.filter(func(p): return p["life"] > 0.0)


func draw(ci: CanvasItem) -> void:
	var font := ThemeDB.fallback_font
	for p in _items:
		var color: Color = p["color"]
		color.a *= clampf(p["life"] / p["max"] * 1.5, 0.0, 1.0)
		if p.has("text"):
			ci.draw_string(font, (p["pos"] - Vector2(20, 0)).round(), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 40, 10, color)
		else:
			ci.draw_rect(Rect2(p["pos"].round(), Vector2.ONE * p["size"]), color)


func steam(at: Vector2) -> void:
	_add(at, Vector2(randf_range(-4, 4), -18), 1.0, Color(1, 1, 1, 0.7), 2)


func smoke(at: Vector2, heavy: bool) -> void:
	_add(at, Vector2(randf_range(-5, 5), -14), 1.4, Color("4a4a52") if heavy else Color("8a8590"), 3 if heavy else 2)


func chop(at: Vector2, item: Item) -> void:
	var color := Color("e04a3f") if item and item.kind == Item.Kind.TOMATO else Color("6cbf4a")
	_add(at, Vector2(randf_range(-30, 30), randf_range(-40, -15)), 0.4, color, 1, Vector2(0, 120))


func bubble(at: Vector2) -> void:
	_add(at, Vector2(randf_range(-3, 3), -8), 0.5, Color("e8f4fa"), 1)


func sweat(at: Vector2) -> void:
	_add(at, Vector2(randf_range(-10, 10), -20), 0.6, Color("6fa8dc"), 2, Vector2(0, 90))


func sparkle(at: Vector2) -> void:
	for i in 10:
		var dir := Vector2.RIGHT.rotated(TAU * i / 10.0)
		_add(at, dir * randf_range(25, 45), 0.5, Color("f2c94c"), 2)


func text(at: Vector2, value: String, color: Color) -> void:
	if _items.size() < MAX:
		_items.append({"pos": at, "vel": Vector2(0, -20), "acc": Vector2.ZERO, "life": 1.2, "max": 1.2,
			"color": color, "text": value})


func _add(pos: Vector2, vel: Vector2, life: float, color: Color, size: int, acc := Vector2.ZERO) -> void:
	if _items.size() < MAX:
		_items.append({"pos": pos, "vel": vel, "acc": acc, "life": life, "max": life, "color": color, "size": size})
