class_name MenuBackground
extends Control
## Fundo animado dos menus: soalho a deslizar devagar, comida a flutuar e um
## escurecimento nas bordas.

const SCALE := 3.0
const FOODS := ["tomato", "lettuce", "soup", "tomato_chopped", "lettuce_chopped"]

var _time := 0.0
var _floaters: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 14:
		_floaters.append({"id": FOODS[i % FOODS.size()], "x": randf(), "y": randf(),
			"speed": randf_range(0.015, 0.04), "phase": randf() * TAU, "scale": randf_range(2.0, 3.0)})


func _process(delta: float) -> void:
	_time += delta
	for f in _floaters:
		f["y"] -= f["speed"] * delta
		if f["y"] < -0.1:
			f["y"] = 1.1
			f["x"] = randf()
	queue_redraw()


func _draw() -> void:
	var tile := Art.WOOD.get_size() * SCALE
	var offset := Vector2(fmod(_time * 12.0, tile.x), fmod(_time * 6.0, tile.y))
	var y := -tile.y
	while y < size.y + tile.y:
		var x := -tile.x
		while x < size.x + tile.x:
			draw_texture_rect(Art.WOOD, Rect2(Vector2(x, y) + offset, tile), false)
			x += tile.x
		y += tile.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.07, 0.06, 0.45))
	for f in _floaters:
		var tex: Texture2D = Art.CONTENT[f["id"]]
		var s: float = f["scale"]
		var pos := Vector2(f["x"] * size.x, f["y"] * size.y + sin(_time * 1.5 + f["phase"]) * 8.0)
		draw_set_transform(pos, sin(_time + f["phase"]) * 0.2, Vector2(s, s))
		draw_texture(tex, -tex.get_size() / 2.0, Color(1, 1, 1, 0.55))
	draw_set_transform(Vector2.ZERO)
	# Vinheta.
	for i in 8:
		var a := 0.06 * (8 - i) / 8.0
		var m := i * 18.0
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 120 - m)), Color(0, 0, 0, a * 0.8))
		draw_rect(Rect2(Vector2(0, size.y - 120 + m), Vector2(size.x, 120 - m)), Color(0, 0, 0, a))
