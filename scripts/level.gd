extends Node2D
## Um nível: cozinha, chefs, pedidos, HUD e ecrã de resultados.

const ROUND_TIME := 180.0
const KITCHEN_OFFSET := Vector2(80, 44)
## Pontos para 1, 2 e 3 estrelas.
const STAR_SCORES: Array[int] = [40, 100, 180]

var _orders: OrderManager
var _kitchen: Kitchen
var _hud: Control
var _time_left := ROUND_TIME
var _finished := false


func _ready() -> void:
	_orders = OrderManager.new()
	add_child(_orders)
	_kitchen = Kitchen.new(_orders)
	_kitchen.position = KITCHEN_OFFSET
	add_child(_kitchen)

	for p in PlayerRegistry.players:
		var chef := Chef.new()
		chef.source = p["source"]
		chef.color = p["color"]
		chef.slot = p["slot"]
		chef.kitchen = _kitchen
		chef.position = _kitchen.spawns[p["slot"]]
		chef.pause_requested.connect(_back_to_lobby)
		chef.confirm_pressed.connect(_on_confirm)
		_kitchen.add_child(chef)
		_kitchen.chefs.append(chef)

	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	layer.add_child(_hud)


func _process(delta: float) -> void:
	if not _finished:
		_time_left = maxf(_time_left - delta, 0.0)
		if _time_left == 0.0:
			_finish()
	_hud.queue_redraw()


func _finish() -> void:
	_finished = true
	_orders.active = false
	for chef in _kitchen.chefs:
		chef.frozen = true


func _stars() -> int:
	return STAR_SCORES.filter(func(s): return _orders.score >= s).size()


func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	# Pedidos.
	for i in _orders.orders.size():
		var order := _orders.orders[i]
		var rect := Rect2(8 + i * 76, 4, 70, 36)
		_hud.draw_rect(rect, UiStyle.PANEL)
		var plate := Item.plate()
		plate.contents.assign(order["recipe"]["needs"])
		ItemArt.draw_item(_hud, plate, rect.position + Vector2(14, 15))
		_hud.draw_string(font, rect.position + Vector2(26, 14), order["recipe"]["name"],
			HORIZONTAL_ALIGNMENT_LEFT, 44, 8, UiStyle.TEXT)
		var t: float = order["time_left"] / OrderManager.ORDER_TIME
		var bar := Rect2(rect.position + Vector2(4, 28), Vector2(62, 4))
		_hud.draw_rect(bar, UiStyle.BG)
		_hud.draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, 4)), Color("e8574d").lerp(Color("6fcf6a"), t))
	# Pontos e tempo.
	var secs := ceili(_time_left)
	_hud.draw_string(font, Vector2(500, 18), "%d:%02d" % [secs / 60, secs % 60],
		HORIZONTAL_ALIGNMENT_RIGHT, 132, 16, UiStyle.TEXT)
	_hud.draw_string(font, Vector2(500, 36), "Pontos: %d" % _orders.score,
		HORIZONTAL_ALIGNMENT_RIGHT, 132, 12, Color("f2c94c"))
	# FPS para medir o desempenho em PCs fracos.
	_hud.draw_string(font, Vector2(4, 356), "FPS %d" % Engine.get_frames_per_second(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiStyle.MUTED)

	if _finished:
		_hud.draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(0, 0, 0, 0.7))
		var lines := [
			["Fim do serviço!", 28, UiStyle.TEXT],
			["Entregues: %d   ·   Falhados: %d" % [_orders.delivered_count, _orders.failed_count], 12, UiStyle.TEXT],
			["Pontos: %d" % _orders.score, 20, Color("f2c94c")],
			["★".repeat(_stars()) + "☆".repeat(3 - _stars()), 28, Color("f2c94c")],
			["Carrega em pegar para voltar ao lobby", 10, UiStyle.MUTED],
		]
		var y := 110.0
		for line in lines:
			_hud.draw_string(font, Vector2(0, y), line[0], HORIZONTAL_ALIGNMENT_CENTER, 640, line[1], line[2])
			y += line[1] + 14


func _on_confirm() -> void:
	if _finished:
		_back_to_lobby()


func _back_to_lobby() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
