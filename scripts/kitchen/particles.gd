class_name Particles
extends RefCounted
## Partículas simples desenhadas como píxeis: vapor, fumo, suor, pedaços a
## saltar da tábua e brilhos ao servir. Têm um limite para não pesar em PCs fracos.

const MAX := 300
## Cor dos pedaços que saltam ao cortar cada ingrediente.
const CHOP_COLORS := {
	"tomato": Color("e04a3f"), "lettuce": Color("6cbf4a"), "kale": Color("3a7f2f"), "potato": Color("f2d48a"),
	"cod": Color("f1eef6"), "salmon": Color("f59a6a"), "cucumber": Color("7fc25a"), "cheese": Color("f6c444"),
	"mushroom": Color("b8946a"), "onion": Color("f0dcc8"),
}

var _items: Array[Dictionary] = []
## Máximo atual (mais alto com "Partículas: Muitas").
var limit := MAX


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
		elif p.has("shape"):
			_draw_shape(ci, p, color)
		else:
			ci.draw_rect(Rect2(p["pos"].round(), Vector2.ONE * p["size"]), color)


const HEART := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(3, 1), Vector2i(4, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]


func _draw_shape(ci: CanvasItem, p: Dictionary, color: Color) -> void:
	var at: Vector2 = p["pos"].round()
	var age: float = p["max"] - p["life"]
	match p["shape"]:
		"heart":
			# Cresce, sobe a abanar e desaparece.
			var s := 1 if age > 0.12 else 0
			for c: Vector2i in HEART:
				ci.draw_rect(Rect2(at + Vector2(c) * (1 + s) - Vector2(2, 2), Vector2.ONE * (1 + s)), color)
			ci.draw_rect(Rect2(at + Vector2(-1, -1), Vector2.ONE), Color(1, 1, 1, color.a * 0.8))
		"cloud":
			var r: float = p["size"] * (1.0 + age * 0.8)
			ci.draw_circle(at, r, color)
			ci.draw_circle(at + Vector2(r * 0.7, r * 0.2), r * 0.7, color)
			ci.draw_circle(at + Vector2(-r * 0.7, r * 0.3), r * 0.6, color)
		"spark":
			# Raio do zangado: um zigue-zague amarelo.
			ci.draw_polyline(PackedVector2Array([at, at + Vector2(2, 3), at + Vector2(-1, 4), at + Vector2(1, 8)]), color, 1.0)
		"coin":
			var w := absf(cos(age * 14.0)) * 4.0 + 0.5
			ci.draw_rect(Rect2(at - Vector2(w / 2.0, 2.5), Vector2(w, 5)), Color(UiStyle.INK, color.a))
			ci.draw_rect(Rect2(at - Vector2(w / 2.0 - 0.5, 2), Vector2(maxf(w - 1, 0.5), 4)), color)
		"ring":
			var t: float = age / p["max"]
			ci.draw_arc(at, 2.0 + t * p["size"], 0, TAU, 20, color, 1.0)
		"confetti":
			var w := absf(sin(age * 10.0 + p["size"])) * 2.0 + 0.5
			ci.draw_rect(Rect2(at, Vector2(w, 2)), color)
		"drop":
			ci.draw_rect(Rect2(at, Vector2(1, 2)), color)


## Corações a subir de quem foi servido.
func hearts(at: Vector2, count := 4) -> void:
	for i in count:
		_add_shape("heart", at + Vector2(randf_range(-8, 8), randf_range(-4, 2)), Vector2(randf_range(-6, 6), randf_range(-26, -16)), 1.1 + randf() * 0.4, Color("ff5a7a"), 0)


## Nuvem escura e faíscas por cima de quem saiu zangado.
func storm(at: Vector2) -> void:
	for i in 4:
		_add_shape("cloud", at + Vector2(randf_range(-6, 6), randf_range(-3, 3)), Vector2(randf_range(-4, 4), -6), 1.3, Color(0.25, 0.22, 0.26, 0.85), 3.0 + randf() * 2.0)
	for i in 3:
		_add_shape("spark", at + Vector2(randf_range(-6, 6), 4), Vector2(0, 10), 0.6 + i * 0.2, Color("ffd34a"), 0)


## Moedas a saltar (da caixa quando se cobra).
func coins(at: Vector2, count := 6) -> void:
	for i in count:
		_add_shape("coin", at, Vector2(randf_range(-40, 40), randf_range(-90, -50)), 0.9, Color("f6c444"), 0, Vector2(0, 220))


## Onda que se espalha (ao pousar, ao servir).
func ring(at: Vector2, radius := 12.0, color := Color(1, 1, 1, 0.8), life := 0.35) -> void:
	_add_shape("ring", at, Vector2.ZERO, life, color, radius)


func confetti(at: Vector2, count := 18) -> void:
	var colors := [Color("ff6f6f"), Color("f6c444"), Color("6fcf6a"), Color("6fa8dc"), Color("eb94d6")]
	for i in count:
		_add_shape("confetti", at, Vector2(randf_range(-60, 60), randf_range(-110, -50)), 1.2 + randf() * 0.5, colors.pick_random(), randf() * 6.0, Vector2(0, 160))


## Pingos a saltar (ingrediente a cair na panela, prato no lava-loiça).
func splash(at: Vector2, color := Color("bfe3f2")) -> void:
	for i in 6:
		_add_shape("drop", at, Vector2(randf_range(-25, 25), randf_range(-45, -20)), 0.4, color, 0, Vector2(0, 200))


## Pegadas: um pozinho atrás dos pés de quem anda.
func step_dust(at: Vector2) -> void:
	_add(at + Vector2(randf_range(-2, 2), 0), Vector2(randf_range(-6, 6), randf_range(-6, -2)), 0.35, Color(0.9, 0.85, 0.75, 0.45), 1)


func _add_shape(shape: String, pos: Vector2, vel: Vector2, life: float, color: Color, size: float, acc := Vector2.ZERO) -> void:
	if _items.size() < limit:
		_items.append({"pos": pos, "vel": vel, "acc": acc, "life": life, "max": life, "color": color, "size": size, "shape": shape})


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


## Pó a flutuar devagar num raio de luz.
func mote(at: Vector2) -> void:
	_add(at, Vector2(randf_range(-3, 3), randf_range(-4, 2)), 2.5, Color(1.0, 0.95, 0.75, 0.55), 1)


## Faúlha a saltar do lume.
func ember(at: Vector2) -> void:
	_add(at, Vector2(randf_range(-8, 8), randf_range(-30, -18)), 0.6, Color("ffb347"), 1, Vector2(0, 30))


func text(at: Vector2, value: String, color: Color) -> void:
	if _items.size() < limit:
		_items.append({"pos": at, "vel": Vector2(0, -20), "acc": Vector2.ZERO, "life": 1.2, "max": 1.2,
			"color": color, "text": value})


func _add(pos: Vector2, vel: Vector2, life: float, color: Color, size: int, acc := Vector2.ZERO) -> void:
	if _items.size() < limit:
		_items.append({"pos": pos, "vel": vel, "acc": acc, "life": life, "max": life, "color": color, "size": size})
