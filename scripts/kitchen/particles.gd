class_name Particles
extends RefCounted
## Partículas simples desenhadas como píxeis: vapor, fumo, suor, pedaços a
## saltar da tábua e brilhos ao servir. Têm um limite para não pesar em PCs fracos.

const MAX := 300
## Cor dos pedaços que saltam ao cortar cada ingrediente.
const CHOP_COLORS := {
	"tomato": Color("e04a3f"), "lettuce": Color("6cbf4a"), "kale": Color("3a7f2f"), "potato": Color("f2d48a"),
	"cod": Color("f1eef6"), "salmon": Color("f59a6a"), "cucumber": Color("7fc25a"), "cheese": Color("f6c444"),
}

var _items: Array[Dictionary] = []


func update(delta: float) -> void:
	for p in _items:
		p["life"] -= delta
		p["vel"] += p["acc"] * delta
		p["pos"] += p["vel"] * delta
	_items = _items.filter(func(p): return p["life"] > 0.0)


func draw(ci: CanvasItem) -> void:
	var font := UiStyle.FONT
	for p in _items:
		var color: Color = p["color"]
		color.a *= clampf(p["life"] / p["max"] * 1.5, 0.0, 1.0)
		if p.has("text"):
			# Cresce ao aparecer e tem sombra para se ler sobre qualquer fundo.
			var age: float = p["max"] - p["life"]
			var s := 1.0 + maxf(0.0, 0.15 - age) * 4.0
			ci.draw_set_transform(p["pos"].round(), 0.0, Vector2(s, s))
			var shadow := Color(UiStyle.INK, color.a)
			ci.draw_string(font, Vector2(-30, 1), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 60, 11, shadow)
			ci.draw_string(font, Vector2(-30, 0), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 60, 11, color)
			ci.draw_set_transform(Vector2.ZERO)
		else:
			ci.draw_rect(Rect2(p["pos"].round(), Vector2.ONE * p["size"]), color)


func steam(at: Vector2) -> void:
	_add(at, Vector2(randf_range(-4, 4), -18), 1.0, Color(1, 1, 1, 0.7), 2)


func smoke(at: Vector2, heavy: bool) -> void:
	_add(at, Vector2(randf_range(-5, 5), -14), 1.4, Color("4a4a52") if heavy else Color("8a8590"), 3 if heavy else 2)


func chop(at: Vector2, item: Item) -> void:
	var color: Color = CHOP_COLORS.get(item.kind if item else "", Color("e6cfa0"))
	_add(at, Vector2(randf_range(-30, 30), randf_range(-40, -15)), 0.4, color, 1, Vector2(0, 120))


func bubble(at: Vector2) -> void:
	_add(at, Vector2(randf_range(-3, 3), -8), 0.5, Color("e8f4fa"), 1)


func sweat(at: Vector2) -> void:
	_add(at, Vector2(randf_range(-10, 10), -20), 0.6, Color("6fa8dc"), 2, Vector2(0, 90))


func sparkle(at: Vector2) -> void:
	for i in 10:
		var dir := Vector2.RIGHT.rotated(TAU * i / 10.0)
		_add(at, dir * randf_range(25, 45), 0.5, Color("f2c94c"), 2)


func dust(at: Vector2, dir: Vector2) -> void:
	_add(at, dir * randf_range(20, 40) + Vector2(randf_range(-10, 10), randf_range(-12, -4)), 0.35,
		Color(0.95, 0.9, 0.8, 0.8), 2)


func text(at: Vector2, value: String, color: Color) -> void:
	if _items.size() < MAX:
		_items.append({"pos": at, "vel": Vector2(0, -20), "acc": Vector2.ZERO, "life": 1.2, "max": 1.2,
			"color": color, "text": value})


func _add(pos: Vector2, vel: Vector2, life: float, color: Color, size: int, acc := Vector2.ZERO) -> void:
	if _items.size() < MAX:
		_items.append({"pos": pos, "vel": vel, "acc": acc, "life": life, "max": life, "color": color, "size": size})
