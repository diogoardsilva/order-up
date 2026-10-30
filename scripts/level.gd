extends Node2D
## Um nível: cozinha, chefs, pedidos, HUD e ecrã de resultados.
## Online, o anfitrião simula a cozinha e envia o estado ~20 vezes por segundo;
## cada PC mexe os seus chefs, envia-lhe as posições e pede as interações.

const ROUND_TIME := 180.0
const KITCHEN_OFFSET := Vector2(80, 44)
## Pontos para 1, 2 e 3 estrelas.
const STAR_SCORES: Array[int] = [40, 100, 180]
const PAPER := Color("f6e6c4")
const PAPER_INK := Color("3b2027")
## Frames de física entre envios (60 / 3 = 20 por segundo).
const NET_SEND_EVERY := 3

var _orders: OrderManager
var _kitchen: Kitchen
var _hud: Control
var _time_left := ROUND_TIME
var _finished := false
var _tutorial: Tutorial
var _tutorial_label: Label
var _ready_peers: Array[int] = []
var _net_frame := 0


func _ready() -> void:
	_orders = OrderManager.new()
	_orders.scripted = GameState.mode == GameState.Mode.TUTORIAL and not Net.online
	add_child(_orders)
	_kitchen = Kitchen.new(_orders)
	_kitchen.name = "Kitchen"
	_kitchen.position = KITCHEN_OFFSET
	add_child(_kitchen)
	_orders.kitchen = _kitchen
	if Net.is_client():
		_orders.process_mode = Node.PROCESS_MODE_DISABLED
		_kitchen.simulate = false
	elif Net.online:
		_kitchen.fx.connect(func(at: Vector2, text: String, color: Color, sparkle: bool):
			for peer in _ready_peers:
				_rpc_fx.rpc_id(peer, at, text, color, sparkle))

	for p in PlayerRegistry.players:
		var chef := Chef.new()
		chef.source = p["source"]
		chef.color = p["color"]
		chef.slot = p["slot"]
		chef.kitchen = _kitchen
		chef.position = _kitchen.spawns[p["slot"]]
		chef.is_local = not p["source"] is RemoteSource
		chef.pause_requested.connect(_on_pause)
		chef.confirm_pressed.connect(_on_confirm)
		chef.interact_requested.connect(_on_interact.bind(chef))
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

	PlayerRegistry.players_changed.connect(_on_players_changed)
	if Net.is_client():
		_rpc_client_ready.rpc_id(1)


func _physics_process(delta: float) -> void:
	if Net.is_host():
		for chef in _kitchen.chefs:
			if chef.use_down and chef.held == null and not chef.frozen:
				_kitchen.use(chef.target_cell(), delta)
	if not Net.online:
		return
	_net_frame += 1
	if _net_frame % NET_SEND_EVERY != 0:
		return
	if Net.is_host():
		var snapshot := _snapshot()
		_ready_peers = _ready_peers.filter(func(p): return multiplayer.get_peers().has(p))
		for peer in _ready_peers:
			_rpc_snapshot.rpc_id(peer, snapshot)
	else:
		for chef in _kitchen.chefs:
			if chef.is_local:
				_rpc_chef_state.rpc_id(1, chef.slot, chef.position, chef.facing, chef.use_down, chef.emote_left)


func _process(delta: float) -> void:
	if _tutorial:
		_tutorial.update()
		_tutorial_label.text = _tutorial.text()
		if _tutorial.is_finished() and not _finished:
			GameState.mark_tutorial_done()
			_tutorial_label.get_parent().hide()
			_finish()
	elif not _finished and Net.is_host():
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
		# Talão de papel.
		_hud.draw_rect(rect.grow(1), PAPER_INK)
		_hud.draw_rect(rect, PAPER)
		_hud.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), Color("fff8e6"))
		_hud.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 2), Vector2(rect.size.x, 2)), Color("e6cfa0"))
		var plate := Item.plate()
		plate.contents.assign(order["recipe"]["needs"])
		ItemArt.draw_item(_hud, plate, rect.position + Vector2(14, 15))
		_hud.draw_string(font, rect.position + Vector2(27, 12), "%s · mesa %d" % [order["recipe"]["name"], order["table"]],
			HORIZONTAL_ALIGNMENT_LEFT, 100, 9, PAPER_INK)
		_hud.draw_string(font, rect.position + Vector2(27, 23), order["recipe"]["hint"],
			HORIZONTAL_ALIGNMENT_LEFT, 102, 7, Color("94532a"))
		if _tutorial:
			continue
		var t: float = order["time_left"] / order["max_time"]
		var bar := Rect2(rect.position + Vector2(4, 28), Vector2(122, 4))
		_hud.draw_rect(bar, Color("c9a877"))
		_hud.draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, 4)), Color("e8574d").lerp(Color("6fcf6a"), t))
	if not _tutorial:
		var secs := ceili(_time_left)
		_shadow_text(font, Vector2(500, 18), "%d:%02d" % [secs / 60, secs % 60], 16, Color("fff8e6"))
		_shadow_text(font, Vector2(500, 36), "Pontos: %d" % _orders.score, 12, Color("f2c94c"))
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
			["À espera do anfitrião..." if Net.is_client() else "Carrega em pegar para voltar ao lobby", 10, UiStyle.MUTED],
		]
		var y := 110.0
		for line in lines:
			_hud.draw_string(font, Vector2(0, y), line[0], HORIZONTAL_ALIGNMENT_CENTER, 640, line[1], line[2])
			y += line[1] + 14


func _shadow_text(font: Font, at: Vector2, text: String, size: int, color: Color) -> void:
	_hud.draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_RIGHT, 132, size, PAPER_INK)
	_hud.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_RIGHT, 132, size, color)


func _on_interact(chef: Chef) -> void:
	if Net.is_client():
		_rpc_interact.rpc_id(1, chef.slot, chef.position, chef.facing)
	elif not chef.frozen:
		_kitchen.interact(chef, chef.target_cell())


func _on_pause() -> void:
	if Net.is_host():
		_back_to_lobby()


## Um jogador saiu da sala: o chef dele desaparece.
func _on_players_changed() -> void:
	for chef in _kitchen.chefs.duplicate():
		if PlayerRegistry.get_player(chef.slot).is_empty():
			_kitchen.chefs.erase(chef)
			chef.queue_free()


func _snapshot() -> Array:
	var chefs := _kitchen.chefs.map(func(c: Chef):
		return [c.slot, c.position, c.facing, Item.serialize(c.held), c.use_down, c.emote_left])
	var stations := []
	for station: Station in _kitchen.stations.values():
		var data: Variant = station.serialize()
		if data != null:
			stations.append([station.cell, data])
	return [chefs, stations, _orders.serialize(), _time_left, _finished]


func _chef_for_slot(slot: int) -> Chef:
	for chef in _kitchen.chefs:
		if chef.slot == slot:
			return chef
	return null


## Chef de um jogador remoto, só se o PC que enviou for mesmo o dono dele.
func _remote_chef(slot: int) -> Chef:
	var player := PlayerRegistry.get_player(slot)
	if player.is_empty() or player["peer"] != multiplayer.get_remote_sender_id():
		return null
	return _chef_for_slot(slot)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_ready() -> void:
	var peer := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and not _ready_peers.has(peer):
		_ready_peers.append(peer)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_chef_state(slot: int, pos: Vector2, dir: Vector2, use: bool, emote: float) -> void:
	var chef := _remote_chef(slot)
	if chef:
		chef.net_target = pos
		chef.facing = dir
		chef.use_down = use
		chef.emote_left = emote


@rpc("any_peer", "call_remote", "reliable")
func _rpc_interact(slot: int, pos: Vector2, dir: Vector2) -> void:
	var chef := _remote_chef(slot)
	if chef and not chef.frozen:
		# A posição do pedido manda: o pacote de movimento pode ainda não ter chegado.
		chef.position = pos
		chef.net_target = pos
		chef.facing = dir
		_kitchen.interact(chef, chef.target_cell())


@rpc("authority", "call_remote", "reliable")
func _rpc_fx(at: Vector2, text: String, color: Color, sparkle: bool) -> void:
	_kitchen.show_fx(at, text, color, sparkle)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_snapshot(data: Array) -> void:
	for c in data[0]:
		var chef := _chef_for_slot(c[0])
		if chef == null:
			continue
		chef.held = Item.deserialize(c[3])
		if not chef.is_local:
			chef.net_target = c[1]
			chef.facing = c[2]
			chef.use_down = c[4]
			chef.emote_left = c[5]
	var by_cell := {}
	for s in data[1]:
		by_cell[s[0]] = s[1]
	for station: Station in _kitchen.stations.values():
		station.apply(by_cell.get(station.cell))
	_orders.apply(data[2])
	_time_left = data[3]
	if data[4] and not _finished:
		_finish()


func _on_confirm() -> void:
	if not _finished or Net.is_client():
		return
	if _tutorial:
		GameState.mode = GameState.Mode.PLAY
		get_tree().reload_current_scene.call_deferred()
	else:
		_back_to_lobby()


func _back_to_lobby() -> void:
	if Net.online:
		Net.return_to_lobby.rpc()
	else:
		get_tree().change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
