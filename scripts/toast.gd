class_name Toast
extends Control
## Aviso de conquista: desce do topo, fica uns segundos e sobe. Se vierem
## várias de seguida, aparecem uma de cada vez.

const SHOW_TIME := 3.6
const SIZE := Vector2(430, 74)

var _queue: Array = []
var _current := {}
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1280, 720)


func push(profile_name: String, achievement: Dictionary) -> void:
	_queue.append({"who": profile_name, "a": achievement})


func _process(delta: float) -> void:
	if _current.is_empty():
		if _queue.is_empty():
			return
		_current = _queue.pop_front()
		_time = 0.0
		Sfx.play("achievement")
	_time += delta
	if _time > SHOW_TIME:
		_current = {}
	queue_redraw()


func _draw() -> void:
	if _current.is_empty():
		return
	var t := _time
	var slide := minf(t / 0.3, 1.0)
	if t > SHOW_TIME - 0.3:
		slide = maxf((SHOW_TIME - t) / 0.3, 0.0)
	slide = 1.0 - pow(1.0 - slide, 3.0)
	var rect := Rect2(Vector2(640 - SIZE.x / 2.0, -SIZE.y + slide * (SIZE.y + 14)), SIZE)
	draw_rect(Rect2(rect.position + Vector2(4, 5), rect.size), Color(0, 0, 0, 0.35))
	draw_style_box(UiStyle.panel_box(), rect)
	var a: Dictionary = _current["a"]
	var c := rect.position + Vector2(38, SIZE.y / 2.0)
	# Medalha com brilho a rodar.
	var shine := t * 2.0
	for i in 8:
		var ang := shine + i * TAU / 8.0
		draw_line(c, c + Vector2.from_angle(ang) * 30.0, Color(1, 0.85, 0.3, 0.22 * slide), 4.0)
	draw_circle(c, 22, Color("8a5a1c"))
	draw_circle(c, 19, Color("f2c94c"))
	draw_circle(c + Vector2(-5, -5), 7, Color(1, 1, 1, 0.35))
	icon(self, c, 13.0, a["icon"], Color("6b3d14"))
	var font := UiStyle.FONT
	var x := rect.position.x + 72
	var head := "Conquista%s · %s" % [" escondida" if a["hidden"] else "", _current["who"]]
	draw_string(font, Vector2(x, rect.position.y + 26), head, HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 84, 15, UiStyle.INK_SOFT)
	draw_string(font, Vector2(x, rect.position.y + 52), a["name"], HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 84, 24, UiStyle.INK)


## Ícone simples de cada tipo de conquista, desenhado com primitivas.
static func icon(ci: CanvasItem, c: Vector2, r: float, kind: String, col: Color) -> void:
	match kind:
		"plate":
			ci.draw_circle(c, r, col)
			ci.draw_circle(c, r * 0.68, Color("f2c94c"))
			ci.draw_arc(c, r * 0.68, 0, TAU, 20, col, 1.5)
		"coin":
			ci.draw_circle(c, r, col)
			ci.draw_string(UiStyle.FONT, c + Vector2(-r * 0.35, r * 0.45), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.4), Color("f2c94c"))
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var rr := r if i % 2 == 0 else r * 0.45
				pts.append(c + Vector2.from_angle(-PI / 2 + i * PI / 5) * rr)
			ci.draw_colored_polygon(pts, col)
		"knife":
			ci.draw_line(c + Vector2(-r, r), c + Vector2(r * 0.2, -r * 0.2), col, r * 0.35)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(r, -r), c + Vector2(r * 0.3, r * 0.1)]), col)
		"pan":
			ci.draw_circle(c + Vector2(-r * 0.2, 0), r * 0.7, col)
			ci.draw_line(c + Vector2(r * 0.4, 0), c + Vector2(r * 1.1, 0), col, r * 0.3)
		"glass":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r), c + Vector2(r * 0.6, -r),
				c + Vector2(r * 0.4, r), c + Vector2(-r * 0.4, r)]), col)
		"fire":
			ci.draw_circle(c + Vector2(0, r * 0.3), r * 0.65, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.65, r * 0.2), c + Vector2(0, -r), c + Vector2(r * 0.65, r * 0.2)]), col)
		"clock":
			ci.draw_arc(c, r * 0.85, 0, TAU, 20, col, r * 0.25)
			ci.draw_line(c, c + Vector2(0, -r * 0.6), col, 2.0)
			ci.draw_line(c, c + Vector2(r * 0.45, 0), col, 2.0)
		"team", "net":
			for dx in [-0.5, 0.5]:
				ci.draw_circle(c + Vector2(r * dx, -r * 0.35), r * 0.32, col)
				ci.draw_circle(c + Vector2(r * dx, r * 0.55), r * 0.5, col)
		"hat":
			ci.draw_circle(c + Vector2(0, -r * 0.3), r * 0.6, col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.1), Vector2(r * 1.1, r * 0.9)), col)
		"door":
			ci.draw_rect(Rect2(c - Vector2(r * 0.6, r), Vector2(r * 1.2, r * 2)), col)
			ci.draw_circle(c + Vector2(r * 0.3, 0), r * 0.12, Color("f2c94c"))
		"sink":
			ci.draw_rect(Rect2(c + Vector2(-r, 0), Vector2(r * 2, r * 0.7)), col)
			ci.draw_circle(c + Vector2(0, -r * 0.5), r * 0.25, col)
		"throw", "boot", "note", "storm", "gear":
			ci.draw_circle(c, r * 0.8, col)
		_:
			ci.draw_circle(c, r * 0.8, col)
