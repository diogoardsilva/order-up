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
var _tutorial: Tutorial
var _tutorial_label: Label


func _ready() -> void:
	_orders = OrderManager.new()
	_orders.scripted = GameState.mode == GameState.Mode.TUTORIAL
	add_child(_orders)
	_kitchen = Kitchen.new(_orders)
	_kitchen.position = KITCHEN_OFFSET
	add_child(_kitchen)
	_orders.kitchen = _kitchen

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

	if _orders.scripted:
		_tutorial = Tutorial.new(_kitchen, _orders)
		var panel := PanelContainer.new()
		panel.position = Vector2(244, 2)
		panel.custom_minimum_size = Vector2(392, 40)
		var style := StyleBoxFlat.new()
		style.bg_color = UiStyle.PANEL
		style.border_color = Color("f2c94c")
		style.set_border_width_all(1)
		style.set_content_margin_all(4)
		panel.add_theme_stylebox_override("panel", style)
		_tutorial_label = Label.new()
		_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tutorial_label.custom_minimum_size.x = 382
		_tutorial_label.add_theme_font_size_override("font_size", 9)
		panel.add_child(_tutorial_label)
		layer.add_child(panel)


func _process(delta: float) -> void:
	if _tutorial:
		_tutorial.update()
		_tutorial_label.text = _tutorial.text()
		if _tutorial.is_finished() and not _finished:
			GameState.mark_tutorial_done()
			_tutorial_label.get_parent().hide()
			_finish()
	elif not _finished:
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
		var rect := Rect2(8 + i * 134, 4, 130, 36)
		_hud.draw_rect(rect, UiStyle.PANEL)
		var plate := Item.plate()
		plate.contents.assign(order["recipe"]["needs"])
		ItemArt.draw_item(_hud, plate, rect.position + Vector2(14, 15))
		_hud.draw_string(font, rect.position + Vector2(27, 12), "%s · mesa %d" % [order["recipe"]["name"], order["table"]],
			HORIZONTAL_ALIGNMENT_LEFT, 100, 9, UiStyle.TEXT)
		_hud.draw_string(font, rect.position + Vector2(27, 23), order["recipe"]["hint"],
			HORIZONTAL_ALIGNMENT_LEFT, 102, 7, UiStyle.MUTED)
		if _tutorial:
			continue
		var t: float = order["time_left"] / order["max_time"]
		var bar := Rect2(rect.position + Vector2(4, 28), Vector2(122, 4))
		_hud.draw_rect(bar, UiStyle.BG)
		_hud.draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, 4)), Color("e8574d").lerp(Color("6fcf6a"), t))
	if not _tutorial:
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
			["Tutorial concluído!", 28, UiStyle.TEXT],
			["Já sabes cozinhar, servir às mesas e lavar pratos. Agora é a sério: 3 minutos e clientes impacientes.", 10, UiStyle.TEXT],
			["Carrega em pegar para ir jogar", 10, UiStyle.MUTED],
		] if _tutorial else [
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
	if not _finished:
		return
	if _tutorial:
		GameState.mode = GameState.Mode.PLAY
		get_tree().reload_current_scene.call_deferred()
	else:
		_back_to_lobby()


func _back_to_lobby() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
