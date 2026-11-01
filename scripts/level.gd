extends Node2D
## Um nível: cozinha, chefs, pedidos, HUD e ecrã de resultados.
## Online, o anfitrião simula a cozinha e envia o estado ~20 vezes por segundo;
## cada PC mexe os seus chefs, envia-lhe as posições e pede as interações.
## O mundo é pixel art a 640x360 desenhado a 2x; a HUD é desenhada a 1280x720.

const ROUND_TIME := 180.0
const KITCHEN_OFFSET := Vector2(80, 44)
const WORLD_SCALE := 2.0
## Frames de física entre envios (60 / 3 = 20 por segundo).
const NET_SEND_EVERY := 3
## Lugar do primeiro ajudante (os jogadores são 0 a 3; os ajudantes 4 e 5).
const HELPER_SLOT := 4
const HELPER_COLORS: Array[Color] = [Color("9aa4b4"), Color("b49a7a")]

var _orders: OrderManager
var _level: Dictionary
var _vignette: Texture2D
var _got_snapshot := false
var _kitchen: Kitchen
var _hud: Control
var _time_left := ROUND_TIME
var _finished := false
var _tutorial: Tutorial
var _tutorial_label: Label
var _ready_peers: Array[int] = []
var _net_frame := 0
# Animações da HUD.
var _clock := 0.0
var _dish_last := {}  # id do prato -> quantos faltavam no último frame
var _dish_pulse := {}  # id do prato -> brilho quando aumenta
var _tickets_bottom := 0.0
var _shown_score := 0.0
var _score_pulse := 0.0
var _last_score := 0
var _finish_time := 0.0
var _last_second := -1
var _stars_played := 0


func _ready() -> void:
	_orders = OrderManager.new()
	_orders.scripted = GameState.mode == GameState.Mode.TUTORIAL and not Net.online
	if _orders.scripted:
		GameState.level = 0
	_level = Levels.get_level(GameState.level)
	_orders.menu = Levels.dishes(_level)
	add_child(_orders)
	_kitchen = Kitchen.new(_orders, _level)
	_kitchen.name = "Kitchen"
	_kitchen.position = KITCHEN_OFFSET * WORLD_SCALE
	_kitchen.scale = Vector2.ONE * WORLD_SCALE
	add_child(_kitchen)
	_orders.kitchen = _kitchen
	# Cor, vinheta e bloom por cima do mundo (conforme as opções de gráficos).
	add_child(PostFX.new(1))
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
		chef.character = p.get("character", 0)
		chef.kitchen = _kitchen
		chef.position = _kitchen.spawns[p["slot"]]
		chef.is_local = not p["source"] is RemoteSource
		chef.pause_requested.connect(_on_pause)
		chef.confirm_pressed.connect(_on_confirm)
		chef.interact_requested.connect(_on_interact.bind(chef))
		chef.throw_requested.connect(_on_throw.bind(chef))
		_kitchen.add_child(chef)
		_kitchen.chefs.append(chef)
	if not _orders.scripted:
		for i in GameState.helpers.size():
			if GameState.HELPER_PRESETS[GameState.helpers[i]][1] >= 0:
				_add_helper(i, GameState.helpers[i])

	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	layer.add_child(_hud)

	if _orders.scripted:
		_tutorial = Tutorial.new(_kitchen, _orders)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiStyle.paper_box())
		# Na coluna da esquerda, por baixo dos talões (no tutorial há no máximo 2).
		panel.position = Vector2(6, 262)
		panel.custom_minimum_size = Vector2(150, 0)
		_tutorial_label = UiStyle.label("", 17, UiStyle.INK)
		_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tutorial_label.custom_minimum_size.x = 128
		panel.add_child(_tutorial_label)
		layer.add_child(panel)

	PlayerRegistry.players_changed.connect(_on_players_changed)
	if Net.is_client():
		_rpc_client_ready.rpc_id(1)
	Sfx.music_on("game")


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
		# Até chegar o primeiro estado, avisa o anfitrião de que está pronto (o
		# primeiro aviso pode chegar antes de o nível dele existir).
		if not _got_snapshot and _net_frame % 30 == 0:
			_rpc_client_ready.rpc_id(1)
		for chef in _kitchen.chefs:
			if chef.is_local:
				_rpc_chef_state.rpc_id(1, chef.slot, chef.position, chef.facing, chef.use_down, chef.emote_left)


func _process(delta: float) -> void:
	_clock += delta
	if _tutorial:
		_tutorial.update()
		_tutorial_label.text = _tutorial.text()
		# Por baixo dos cartões de pedidos.
		_tutorial_label.get_parent().position.y = maxf(_tickets_bottom + 8.0, 120.0)
		if _tutorial.is_finished() and not _finished:
			GameState.mark_tutorial_done()
			_tutorial_label.get_parent().hide()
			_finish()
	elif not _finished and Net.is_host():
		_time_left = maxf(_time_left - delta, 0.0)
		if _time_left == 0.0:
			_finish()
	# Tique-taque nos últimos 10 segundos.
	var sec := ceili(_time_left)
	if not _tutorial and not _finished and sec <= 10 and sec != _last_second:
		Sfx.play("ui_move", -4.0, 0.0)
	_last_second = sec
	# Pontuação a subir aos poucos, com um "pulo" quando aumenta.
	if _orders.score > _last_score:
		_score_pulse = 1.0
	_last_score = _orders.score
	_shown_score = move_toward(_shown_score, _orders.score, maxf(40.0, absf(_orders.score - _shown_score) * 4.0) * delta)
	_score_pulse = maxf(_score_pulse - delta * 2.5, 0.0)
	if _finished:
		_finish_time += delta
		var stars := _stars() if not _tutorial else 0
		while _stars_played < stars and _finish_time > 1.0 + _stars_played * 0.45:
			_stars_played += 1
			Sfx.play("coin", 0.0, 0.0)
	# Ao longo da ronda a luz passa de fim de tarde a noite (iluminação Ultra).
	_kitchen.evening = 0.15 + 0.85 * (1.0 - _time_left / ROUND_TIME) if not _tutorial else 0.3
	_hud.queue_redraw()


func _finish() -> void:
	_finished = true
	if not _tutorial:
		GameState.save_stars(_level["id"], _stars())
	_orders.active = false
	Sfx.play("round_end")
	for chef in _kitchen.chefs:
		chef.frozen = true


func _stars() -> int:
	return _level["stars"].filter(func(s): return _orders.score >= s).size()


func _draw_hud() -> void:
	var font := UiStyle.FONT
	# Vinheta: cantos mais escuros.
	if _vignette == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0.08, 0.03, 0.03, 0.55))
		g.add_point(0.6, Color(0, 0, 0, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.05, 0.5)
		tex.width = 128
		tex.height = 72
		_vignette = tex
	# Com pós-processamento a vinheta é feita no shader.
	if Gfx.post == 0 and Gfx.lighting > 0:
		_hud.draw_texture_rect(_vignette, Rect2(Vector2.ZERO, Vector2(1280, 720)), false)
	_draw_world_labels()
	_draw_tickets()
	_draw_players()
	if not _tutorial:
		# Relógio e pontos à direita.
		var secs := ceili(_time_left)
		var urgent := secs <= 30 and not _finished
		var clock_rect := Rect2(1132, 10, 138, 60)
		_hud.draw_style_box(UiStyle.panel_box(), clock_rect)
		_hud.draw_texture_rect(Art.CLOCK, Rect2(clock_rect.position + Vector2(14, 18), Vector2(24, 24)), false)
		var pulse := 1.0 + (0.12 * absf(sin(_clock * 6.0)) if urgent else 0.0)
		_hud.draw_set_transform(clock_rect.position + Vector2(90, 40), 0.0, Vector2(pulse, pulse))
		_hud.draw_string(font, Vector2(-44, 0), "%d:%02d" % [secs / 60, secs % 60], HORIZONTAL_ALIGNMENT_CENTER, 88, 30,
			UiStyle.RED if urgent else UiStyle.INK)
		_hud.draw_set_transform(Vector2.ZERO)
		var score_rect := Rect2(1132, 78, 138, 60)
		_hud.draw_style_box(UiStyle.panel_box(), score_rect)
		_hud.draw_texture_rect(Art.COIN, Rect2(score_rect.position + Vector2(14, 18), Vector2(24, 24)), false)
		var s := 1.0 + _score_pulse * 0.35
		_hud.draw_set_transform(score_rect.position + Vector2(90, 40), 0.0, Vector2(s, s))
		_hud.draw_string(font, Vector2(-44, 0), "%d" % roundi(_shown_score), HORIZONTAL_ALIGNMENT_CENTER, 88, 30, UiStyle.INK)
		_hud.draw_set_transform(Vector2.ZERO)
	# Nome do restaurante no início da ronda.
	if _clock < 3.0 and not _tutorial:
		var a := clampf(minf(_clock / 0.3, (3.0 - _clock) / 0.5), 0.0, 1.0)
		var banner := Rect2(440, 300 - (1.0 - a) * 30, 400, 96)
		_hud.draw_style_box(UiStyle.panel_box(), banner)
		_hud.draw_string(font, banner.position + Vector2(0, 48), _level["name"], HORIZONTAL_ALIGNMENT_CENTER, banner.size.x, 40, Color(UiStyle.INK, a))
		_hud.draw_string(font, banner.position + Vector2(0, 78), _level["place"], HORIZONTAL_ALIGNMENT_CENTER, banner.size.x, 22, Color(UiStyle.INK_SOFT, a))
	# FPS para medir o desempenho em PCs fracos.
	if Gfx.show_fps:
		_hud.draw_string(font, Vector2(8, 712), "FPS %d" % Engine.get_frames_per_second(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.MUTED)
	if _finished:
		_draw_results()


func _draw_tickets() -> void:
	# Coluna da esquerda, em duas partes, para nunca passar do ecrã:
	# 1. "Para cozinhar": um cartão por prato do menu, com quantos faltam e a receita.
	# 2. "Mesas": um cartão por grupo, do mais impaciente para o menos, com o que
	#    falta e a paciência. Quem ainda não fez o pedido aparece com "!".
	var font := UiStyle.FONT
	var x := 6.0
	var w := 148.0
	var y := 8.0
	var counts := {}
	for order in _orders.orders:
		var id: String = order["recipe"]["id"]
		counts[id] = counts.get(id, 0) + 1
	var dishes: Array = _orders.menu.filter(func(r): return counts.has(r["id"]))
	if not dishes.is_empty():
		y = _hud_header(Vector2(x, y), w, "Para cozinhar")
	for recipe in dishes:
		var id: String = recipe["id"]
		var n: int = counts[id]
		if n > _dish_last.get(id, 0):
			_dish_pulse[id] = 1.0
		var pulse: float = _dish_pulse.get(id, 0.0)
		var hint: String = recipe["hint"]
		var hint_h := font.get_multiline_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, w - 14, 13, 3).y
		var raw := _raw_ingredients(recipe)
		var rect := Rect2(Vector2(x, y), Vector2(w, 40 + hint_h + 36))
		if pulse > 0.0:
			_hud.draw_rect(rect.grow(2 + pulse * 3), Color(UiStyle.GOLD, pulse))
		_hud.draw_style_box(UiStyle.paper_box(), rect)
		var plate := Item.plate()
		plate.contents.assign(recipe["needs"])
		_hud.draw_set_transform(rect.position + Vector2(20, 18), 0.0, Vector2(2, 2))
		ItemArt.draw_item(_hud, plate, Vector2.ZERO)
		_hud.draw_set_transform(Vector2.ZERO)
		# Quantos faltam, num autocolante por cima do prato.
		var count_rect := Rect2(rect.position + Vector2(22, 20), Vector2(24, 16))
		_hud.draw_rect(count_rect.grow(1), UiStyle.INK)
		_hud.draw_rect(count_rect, Color("a02530"))
		_hud.draw_string(font, count_rect.position + Vector2(0, 14), "x%d" % n, HORIZONTAL_ALIGNMENT_CENTER, count_rect.size.x, 17, UiStyle.TEXT)
		var name: String = recipe["name"]
		var name_size := _fit_size(name, w - 54, 21, 13)
		_hud.draw_string(font, rect.position + Vector2(50, 25), name, HORIZONTAL_ALIGNMENT_LEFT, w - 54, name_size, UiStyle.INK)
		# Os ingredientes crus, desenhados e com o nome, para se reconhecerem nas caixas.
		var cell_w := (w - 8) / maxf(raw.size(), 1)
		for k in raw.size():
			var at := rect.position + Vector2(4 + cell_w * (k + 0.5), 52)
			_hud.draw_set_transform(at, 0.0, Vector2(1.5, 1.5))
			ItemArt.draw_content(_hud, raw[k], Vector2.ZERO)
			_hud.draw_set_transform(Vector2.ZERO)
			var raw_name: String = Levels.SINGULAR.get(raw[k], Levels.INGREDIENT_NAMES.get(raw[k], raw[k]))
			_hud.draw_string(font, at + Vector2(-cell_w / 2.0, 20), raw_name, HORIZONTAL_ALIGNMENT_CENTER, cell_w, _fit_size(raw_name, cell_w - 2, 13, 10), UiStyle.INK)
		_hud.draw_multiline_string(font, rect.position + Vector2(8, 49 + 36), hint,
			HORIZONTAL_ALIGNMENT_LEFT, w - 14, 13, 3, UiStyle.INK_SOFT)
		y += rect.size.y + 6
	for id in _dish_pulse.keys():
		_dish_pulse[id] = maxf(_dish_pulse[id] - get_process_delta_time() * 2.5, 0.0)
	_dish_last = counts

	var groups: Array = _orders.customers.filter(func(c: Customer): return c.is_waiting() or c.is_calling())
	groups.sort_custom(func(a: Customer, b: Customer): return a.patience / a.max_patience < b.patience / b.max_patience)
	if not groups.is_empty():
		y = _hud_header(Vector2(x, y + 2), w, "Mesas")
	var shown := 0
	for customer: Customer in groups:
		if y > 700 - 52:
			_hud.draw_string(font, Vector2(x, y + 16), "+%d mesas" % (groups.size() - shown), HORIZONTAL_ALIGNMENT_CENTER, w, 18, UiStyle.TEXT)
			break
		shown += 1
		var t := customer.patience / customer.max_patience
		var shake := Vector2(sin(_clock * 40.0) * 2.0, 0) if t < 0.25 and not _tutorial else Vector2.ZERO
		var rect := Rect2(Vector2(x, y) + shake, Vector2(w, 46))
		_hud.draw_style_box(UiStyle.paper_box(), rect)
		var badge := Rect2(rect.position + Vector2(6, 6), Vector2(36, 24))
		_hud.draw_rect(badge, Color("a02530"))
		_hud.draw_string(font, badge.position + Vector2(0, 19), "M%d" % customer.table.number, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 20, UiStyle.TEXT)
		if customer.is_calling():
			var a := 0.6 + 0.4 * sin(_clock * 6.0)
			_hud.draw_string(font, rect.position + Vector2(48, 24), "! anotar", HORIZONTAL_ALIGNMENT_LEFT, w - 52, 19, Color(UiStyle.RED, a))
		else:
			var missing := customer.missing()
			var step := minf(25.0, (w - 70.0) / maxf(missing.size() - 1, 1))
			for k in missing.size():
				var plate := Item.plate()
				plate.contents.assign(missing[k]["needs"])
				_hud.draw_set_transform(rect.position + Vector2(58 + k * step, 19), 0.0, Vector2(1.5, 1.5))
				ItemArt.draw_item(_hud, plate, Vector2.ZERO)
				_hud.draw_set_transform(Vector2.ZERO)
		if not _tutorial:
			var bar := Rect2(rect.position + Vector2(8, rect.size.y - 11), Vector2(rect.size.x - 16, 5))
			_hud.draw_rect(bar.grow(1), UiStyle.INK)
			_hud.draw_rect(bar, Color("c9a877"))
			_hud.draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)), UiStyle.RED.lerp(UiStyle.GREEN, t))
		y += rect.size.y + 5
	_tickets_bottom = y


## Nomes por cima do mundo, para se perceber que ingrediente é cada um: o nome
## em cada caixa, o que cada chef leva na mão e o que está na estação para onde
## um jogador está virado. Desenhados na HUD para ficarem nítidos.
func _draw_world_labels() -> void:
	if _finished:
		return
	for station: Station in _kitchen.stations.values():
		if station is CrateStation:
			var name: String = Levels.INGREDIENT_NAMES.get((station as CrateStation).ingredient, "")
			_tag(_to_screen(_kitchen.cell_center(station.cell) + Vector2(0, 8)), name, 14, UiStyle.PAPER, UiStyle.INK)
	for chef in _kitchen.chefs:
		if chef.held:
			_tag(_to_screen(chef.position + Vector2(0, -27)), Levels.item_name(chef.held), 15, Color("fff8e6"), chef.color.darkened(0.45))
		if chef.slot >= HELPER_SLOT or not chef.is_local:
			continue
		var target := _kitchen.station_at(chef.target_cell())
		if target and target.item and not target is CrateStation:
			_tag(_to_screen(_kitchen.cell_center(target.cell) + Vector2(0, -15)), Levels.item_name(target.item), 13, Color(UiStyle.INK, 0.85), UiStyle.TEXT)


func _to_screen(kitchen_pos: Vector2) -> Vector2:
	return _kitchen.position + kitchen_pos * WORLD_SCALE


## Etiqueta centrada num ponto do ecrã.
func _tag(center: Vector2, text: String, size: int, bg: Color, fg: Color) -> void:
	if text.is_empty():
		return
	var w := UiStyle.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 8
	var rect := Rect2((center - Vector2(w / 2.0, size * 0.55)).round(), Vector2(w, size + 2))
	_hud.draw_rect(rect.grow(1), UiStyle.INK)
	_hud.draw_rect(rect, bg)
	_hud.draw_string(UiStyle.FONT, rect.position + Vector2(4, size * 0.8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fg)


## Ingredientes crus de um prato (sem repetir), pela ordem da receita.
func _raw_ingredients(recipe: Dictionary) -> Array:
	var result := []
	for need: String in recipe["needs"]:
		var parts: Array = [need]
		for cr in Recipes.COOK:
			if cr["out"] == need:
				parts = cr["in"]
		for part: String in parts:
			var raw := part.trim_suffix("_chopped")
			if not result.has(raw):
				result.append(raw)
	return result


## Título pequeno de uma secção da coluna da esquerda. Devolve o y seguinte.
func _hud_header(at: Vector2, width: float, text: String) -> float:
	UiStyle.shadow_text(_hud, at + Vector2(4, 16), text, 18, UiStyle.GOLD)
	return at.y + 24


## Nomes compridos ("Bacalhau à Brás") encolhem para caber.
func _fit_size(text: String, width: float, size: int, min_size: int) -> int:
	while size > min_size and UiStyle.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size


## Retratos dos jogadores e dos ajudantes na coluna da direita (compactos,
## para caberem 4 jogadores e 2 ajudantes).
func _draw_players() -> void:
	var y := 150.0 if not _tutorial else 10.0
	var h := 112.0 if _kitchen.chefs.size() <= 4 else 86.0
	for chef in _kitchen.chefs:
		var rect := Rect2(1130, y, 140, h)
		_hud.draw_style_box(UiStyle.panel_box(), rect)
		var bob := roundf(sin(_clock * 3.0 + chef.slot) * 2.0)
		var s := 3.0 if h > 100 else 2.4
		var top_left := rect.position + Vector2(70 - 8 * s, 10 + bob)
		_hud.draw_set_transform(top_left, 0.0, Vector2(s, s))
		Art.frame(_hud, Art.CHEFS[chef.character], Art.CHEF_FRAME, 0, 0, Vector2.ZERO)
		Art.frame(_hud, Art.CHEF_TINT, Art.CHEF_FRAME, 0, 0, Vector2.ZERO, false, chef.color)
		_hud.draw_set_transform(Vector2.ZERO)
		var label := _helper_name(chef.slot) if chef.slot >= HELPER_SLOT else "P%d %s" % [chef.slot + 1, Art.CHEF_NAMES[chef.character]]
		_hud.draw_string(UiStyle.FONT, rect.position + Vector2(0, h - 8), label,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, chef.color.darkened(0.35))
		y += h + 8


func _draw_results() -> void:
	var font := UiStyle.FONT
	var fade := clampf(_finish_time / 0.4, 0.0, 1.0)
	_hud.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.1, 0.04, 0.05, 0.65 * fade))
	var drop := 1.0 - ease(clampf((_finish_time - 0.15) / 0.5, 0.0, 1.0), -2.0)
	var rect := Rect2(Vector2(320, 140 - drop * 700), Vector2(640, 440))
	_hud.draw_style_box(UiStyle.panel_box(), rect)
	var x := rect.position.x
	var w := rect.size.x
	var y := rect.position.y
	if _tutorial:
		_hud.draw_string(font, Vector2(x, y + 110), "Tutorial concluído!", HORIZONTAL_ALIGNMENT_CENTER, w, 52, UiStyle.INK)
		_hud.draw_multiline_string(font, Vector2(x + 50, y + 180), "Já sabes anotar pedidos, cozinhar, servir às mesas e lavar pratos. Agora é a sério: 3 minutos e clientes impacientes.",
			HORIZONTAL_ALIGNMENT_CENTER, w - 100, 24, -1, UiStyle.INK_SOFT)
		_prompt(Vector2(x, y + 380), w, "Carrega em pegar para ir jogar")
		return
	_hud.draw_string(font, Vector2(x, y + 90), "Fim do serviço!", HORIZONTAL_ALIGNMENT_CENTER, w, 52, UiStyle.INK)
	_hud.draw_string(font, Vector2(x, y + 140), "Pagos: %d    Falhados: %d" % [_orders.paid_count, _orders.failed_count],
		HORIZONTAL_ALIGNMENT_CENTER, w, 24, UiStyle.INK_SOFT)
	_hud.draw_texture_rect(Art.COIN, Rect2(Vector2(x + w / 2 - 90, y + 168), Vector2(36, 36)), false)
	_hud.draw_string(font, Vector2(x + w / 2 - 44, y + 200), "%d" % roundi(_shown_score), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UiStyle.INK)
	for i in 3:
		var center := Vector2(x + w / 2 + (i - 1) * 110, y + 280)
		var age := _finish_time - (1.0 + i * 0.45)
		var full := i < _stars_played
		var s := 4.5
		if full:
			s *= 1.0 + 0.6 * maxf(0.0, 1.0 - age / 0.25) if age < 0.25 else 1.0
		var tex := Art.STAR if full else Art.STAR_EMPTY
		var size := tex.get_size() * s / 2.0
		_hud.draw_texture_rect(tex, Rect2(center - size / 2.0, size), false)
	_prompt(Vector2(x, y + 395), w, "À espera do host..." if Net.is_client() else "Carrega em pegar para voltar ao lobby")


func _prompt(at: Vector2, width: float, text: String) -> void:
	var a := 0.55 + 0.45 * sin(_clock * 4.0)
	_hud.draw_string(UiStyle.FONT, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, 22, Color(UiStyle.INK, a))


func _on_interact(chef: Chef) -> void:
	if Net.is_client():
		_rpc_interact.rpc_id(1, chef.slot, chef.position, chef.facing)
	elif not chef.frozen:
		_kitchen.interact(chef, chef.target_cell())


func _on_throw(chef: Chef) -> void:
	if Net.is_client():
		_rpc_throw.rpc_id(1, chef.slot, chef.position, chef.facing)
	elif not chef.frozen:
		_kitchen.throw_item(chef)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_throw(slot: int, pos: Vector2, dir: Vector2) -> void:
	var chef := _remote_chef(slot)
	if chef and not chef.frozen:
		chef.position = pos
		chef.net_target = pos
		chef.facing = dir
		_kitchen.throw_item(chef)


func _on_pause() -> void:
	if Net.is_host():
		_back_to_lobby()


## Um jogador saiu da sala: o chef dele desaparece.
## O ajudante controlado pelo jogo (empregado de mesa ou cozinheiro). Só o
## anfitrião o faz pensar; nos outros PCs segue as posições recebidas.
func _add_helper(index: int, preset: int) -> void:
	var role: int = GameState.HELPER_PRESETS[preset][1]
	var zone: int = GameState.HELPER_PRESETS[preset][2]
	var chef := Chef.new()
	chef.slot = HELPER_SLOT + index
	chef.color = HELPER_COLORS[index]
	chef.character = [2, 4, 5, 3][role]
	chef.kitchen = _kitchen
	# Começa no sítio do trabalho dele (o segundo um pouco ao lado).
	var start: Vector2i = {
		HelperAI.Role.WAITER: Vector2i(15, 5), HelperAI.Role.HOST: Vector2i(17, 7), HelperAI.Role.RUNNER: Vector2i(12, 6),
	}.get(role, [Vector2i(9, 5), Vector2i(9, 2), Vector2i(9, 10)][zone])
	chef.position = _kitchen.cell_center(start + Vector2i(index, 0))
	chef.is_local = not Net.is_client()
	var brain := HelperAI.new(role as HelperAI.Role, chef, _kitchen, _orders, zone as HelperAI.Zone)
	chef.source = BotSource.new(brain)
	chef.interact_requested.connect(_on_interact.bind(chef))
	chef.throw_requested.connect(_on_throw.bind(chef))
	_kitchen.add_child(chef)
	_kitchen.chefs.append(chef)


## Nome curto do ajudante para o retrato.
func _helper_name(slot: int) -> String:
	var preset: int = GameState.helpers[slot - HELPER_SLOT]
	return ["Empregado", "Cozinheiro", "Host", "Corredor"][GameState.HELPER_PRESETS[preset][1]]


func _on_players_changed() -> void:
	for chef in _kitchen.chefs.duplicate():
		if chef.slot < HELPER_SLOT and PlayerRegistry.get_player(chef.slot).is_empty():
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
	return [chefs, stations, _orders.serialize(), _time_left, _finished, _kitchen.serialize_loose()]


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
	_got_snapshot = true
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
	_kitchen.apply_loose(data[5])
	_time_left = data[3]
	if data[4] and not _finished:
		_finish()


func _on_confirm() -> void:
	if not _finished or Net.is_client():
		return
	if _tutorial:
		GameState.mode = GameState.Mode.PLAY
		Transition.reload()
	else:
		_back_to_lobby()


func _back_to_lobby() -> void:
	if Net.online:
		Net.return_to_lobby.rpc()
	else:
		Transition.go("res://scenes/lobby.tscn")
