extends Node2D
## Um nível: cozinha, chefs, pedidos, HUD e ecrã de resultados.
## Online, o anfitrião simula a cozinha e envia o estado ~20 vezes por segundo;
## cada PC mexe os seus chefs, envia-lhe as posições e pede as interações.
## O mundo é pixel art a 640x360 desenhado a 2x; a HUD é desenhada a 1280x720.

const ROUND_TIME := 180.0
## Duração desta ronda (depende da dificuldade).
var _round_time := ROUND_TIME
const KITCHEN_OFFSET := Vector2(80, 44)
const WORLD_SCALE := 2.0
## Frames de física entre envios (60 / 3 = 20 por segundo).
const NET_SEND_EVERY := 3
## Lugar do primeiro ajudante (os jogadores são 0 a 3; os ajudantes 4 e 5).
const HELPER_SLOT := 4
const HELPER_COLORS: Array[Color] = [Color("9aa4b4"), Color("b49a7a"), Color("8fb39a"), Color("b48fae"),
	Color("a9a37a"), Color("7aa3b4"), Color("b4867a"), Color("8a8fb4")]

var _orders: OrderManager
var _level: Dictionary
var _vignette: Texture2D
var _got_snapshot := false
var _kitchen: Kitchen
var _hud: Control
var _time_left := ROUND_TIME
var _finished := false
var _pause_menu: PauseMenu
var _tutorial: Tutorial
var _tutorial_step := -1
var _cards := {}  # cartão da coluna da esquerda -> posição animada
var _card_frame := 0
var _ui_parts: Array[Dictionary] = []  # partículas da HUD (brilhos, confetes)
var _flying: Array[Dictionary] = []  # moedas a voar da caixa para a pontuação
var _opened := false
var _open_anim := 2.4  # quando aparece o "Abrimos!" (_clock)
# Modo Casa Aberta: preparar com a porta fechada, abrir e fechar quando se quer.
var _endless := false
var _open := false
var _closing := false
var _open_time := 0.0
var _new_record := false
var _ctx_anim := {}  # slot do chef -> animação da legenda por cima da estação
var _tutorial_anim := 0.0  # 0 → 1 quando aparece um passo novo
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
	_orders.drinks = Levels.drinks(_level)
	var diff := GameState.difficulty_values()
	_orders.patience_scale = diff["patience"]
	_orders.spawn_every = OrderManager.SPAWN_EVERY * diff["spawn"]
	_round_time = diff["minutes"] * 60.0
	_time_left = _round_time
	_endless = GameState.endless and not _orders.scripted
	_orders.closed = _endless
	add_child(_orders)
	_kitchen = Kitchen.new(_orders, _level)
	_kitchen.name = "Kitchen"
	_kitchen.position = KITCHEN_OFFSET * WORLD_SCALE
	_kitchen.scale = Vector2.ONE * WORLD_SCALE
	add_child(_kitchen)
	_orders.kitchen = _kitchen
	if _endless:
		_kitchen.door_button = true
		_kitchen.door_used.connect(_on_door)
		_open_anim = -10.0
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

	_start_profiles()
	var pause_layer := CanvasLayer.new()
	pause_layer.layer = 10
	add_child(pause_layer)
	_pause_menu = PauseMenu.new()
	pause_layer.add_child(_pause_menu)
	_pause_menu.resumed.connect(_on_resume)
	_pause_menu.to_lobby.connect(_back_to_lobby)
	_pause_menu.to_menu.connect(func():
		Net.leave()
		Transition.go("res://scenes/main_menu.tscn"))

	if _orders.scripted:
		_tutorial = Tutorial.new(_kitchen, _orders)

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
		# Comprimido: com 8 ajudantes o estado passava do tamanho de um pacote.
		var raw := var_to_bytes(_snapshot())
		var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
		_ready_peers = _ready_peers.filter(func(p): return multiplayer.get_peers().has(p))
		for peer in _ready_peers:
			_rpc_snapshot_packed.rpc_id(peer, raw.size(), packed)
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
		if _tutorial.step != _tutorial_step:
			if _tutorial_step >= 0:
				Sfx.play("step_done", -2.0, 0.0)
			_tutorial_step = _tutorial.step
			_tutorial_anim = 0.0
		_tutorial_anim = minf(_tutorial_anim + delta * 3.0, 1.0)
		if _tutorial.is_finished() and not _finished:
			GameState.mark_tutorial_done()
			_finish()
	elif _endless:
		_kitchen.hint_cells.clear()
		if not _open:
			_kitchen.hint_cells.append(_kitchen.door_cell())
		if _open and not _finished:
			_open_time += delta
			# Cada vez mais clientes: de 15 em 15 segundos até um grupo a cada 6.
			var base: float = OrderManager.SPAWN_EVERY * GameState.difficulty_values()["spawn"]
			_orders.spawn_every = maxf(base * 0.4, base - _open_time / 40.0)
			if _closing and _orders.customers.is_empty() and Net.is_host():
				_finish()
	elif not _finished and Net.is_host():
		_time_left = maxf(_time_left - delta, 0.0)
		if _time_left == 0.0:
			_finish()
	# Tique-taque nos últimos 10 segundos.
	var sec := ceili(_time_left)
	if not _tutorial and not _endless and not _finished and sec <= 10 and sec != _last_second:
		Sfx.play("ui_move", -4.0, 0.0)
	_last_second = sec
	# Pontuação a subir aos poucos, com um "pulo" quando aumenta.
	if _orders.score > _last_score:
		_spawn_coins(_orders.score - _last_score)
	_last_score = _orders.score
	_update_ui_fx(delta)
	Sfx.set_murmur(0.0 if _finished else minf(_orders.customers.size() / 6.0, 1.0))
	# "Abrimos!" quando sai o letreiro do restaurante.
	if not _opened and not _tutorial and _clock > _open_anim and _open_anim > 0.0:
		_opened = true
		Sfx.play("go", -4.0, 0.0)
		_confetti(Vector2(640, 300), 40, 1.4)
	# A pontuação só sobe quando as moedas chegam.
	if _flying.is_empty() or _finished:
		_shown_score = move_toward(_shown_score, _orders.score, maxf(40.0, absf(_orders.score - _shown_score) * 4.0) * delta)
	_score_pulse = maxf(_score_pulse - delta * 2.5, 0.0)
	if _finished:
		_finish_time += delta
		var stars := _stars() if not _tutorial else 0
		if _new_record and _stars_played == 0 and _finish_time > 1.2:
			_stars_played = 1
			Sfx.play("star", -2.0, 0.0)
			Sfx.play("sparkle", -6.0, 0.0)
			_confetti(Vector2(640, 440), 50, 1.2)
		while _stars_played < stars and _finish_time > 1.0 + _stars_played * 0.45:
			_stars_played += 1
			Sfx.play("star", -2.0, 0.0)
			Sfx.play("sparkle", -6.0, 0.0)
			_confetti(Vector2(640 + (_stars_played - 2) * 110, 140 + 280), 26, 0.7)
	# Ao longo da ronda a luz passa de fim de tarde a noite (iluminação Ultra).
	if _endless:
		# Dia e noite a passar devagar (um ciclo a cada 6 minutos).
		_kitchen.evening = 0.2 + 0.75 * (0.5 - 0.5 * cos(_open_time / 360.0 * TAU))
	else:
		_kitchen.evening = 0.15 + 0.85 * (1.0 - _time_left / _round_time) if not _tutorial else 0.3
	_hud.queue_redraw()


func _exit_tree() -> void:
	Sfx.set_murmur(0.0)
	if not _finished:
		Profiles.add("seconds", roundi(_played_time()))
		_seconds_to_minutes()
	Profiles.end_round()


## Perfis dos jogadores deste PC (os convidados não contam).
func _local_profiles() -> Array:
	var result := []
	for p in PlayerRegistry.players:
		if p["peer"] == Net.my_id() or not Net.online:
			result.append([Profiles.for_source(p["source_id"]), p.get("role", 0)])
	return result


func _start_profiles() -> void:
	Profiles.start_round(_local_profiles().map(func(e): return e[0]))


func _played_time() -> float:
	return _open_time if _endless else _round_time - _time_left


## Os minutos jogados contam aos segundos (para não se perderem rondas curtas).
func _seconds_to_minutes() -> void:
	for i in Profiles.playing:
		var st: Dictionary = Profiles.profiles[i]["stats"]
		var secs := int(st.get("seconds", 0))
		var mins := secs / 60
		if mins > int(st.get("minutes", 0)):
			Profiles.add_to(i, "minutes", mins - int(st.get("minutes", 0)))


## Fim da ronda: estrelas, rondas, papéis, modos... para as conquistas.
func _record_round() -> void:
	var lid: String = _level["id"]
	Profiles.add("seconds", roundi(_played_time()))
	_seconds_to_minutes()
	if _tutorial:
		Profiles.add("tutorial")
		return
	var stars := _stars()
	var score := _orders.score
	Profiles.add("rounds")
	Profiles.add("lv_%s_rounds" % lid)
	Profiles.best("round_best", score)
	if score == 0:
		Profiles.add("zero_round")
	if _endless:
		Profiles.best("lv_%s_endless_best" % lid, score)
		Profiles.best("endless_minutes_best", floori(_open_time / 60.0))
	else:
		Profiles.add("diff_%d" % GameState.difficulty)
		Profiles.best("lv_%s_stars_best" % lid, stars)
		if stars >= 3:
			Profiles.add("stars3")
			if GameState.difficulty == 2:
				Profiles.add("lv_%s_hard3" % lid)
		if _orders.failed_count == 0 and _orders.paid_count > 0:
			Profiles.add("perfect")
			Profiles.add("lv_%s_perfect" % lid)
	Profiles.best("players_best", PlayerRegistry.players.size())
	var helpers := 0
	for h in GameState.helpers:
		if GameState.HELPER_PRESETS[h][1] >= 0:
			helpers += 1
	Profiles.best("helpers_best", helpers)
	if Net.online:
		Profiles.add("online_rounds")
		if Net.is_host():
			Profiles.add("hosted")
	for e in _local_profiles():
		if e[0] >= 0 and e[1] > 0:
			Profiles.add_to(e[0], "role_%d" % e[1], 1)


func _finish() -> void:
	_finished = true
	_record_round()
	Profiles.end_round()
	if _endless:
		_new_record = GameState.save_endless(_level["id"], _orders.score)
	elif not _tutorial:
		GameState.save_stars(_level["id"], _stars())
	_orders.active = false
	Sfx.play("round_end")
	Sfx.play("swoosh", -2.0, 0.0)
	for chef in _kitchen.chefs:
		chef.frozen = true
		chef.celebrate = _tutorial != null or _stars() > 0 or (_endless and _orders.score > 0)


func _stars() -> int:
	if _endless:
		return 0
	# As estrelas pedem mais pontos em rondas mais compridas.
	var scale := _round_time / ROUND_TIME
	return _level["stars"].filter(func(s): return _orders.score >= s * scale).size()


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
	_draw_tutorial()
	_draw_endless_banner()
	_draw_players()
	if not _tutorial:
		# Relógio e pontos à direita.
		var secs := ceili(_time_left) if not _endless else floori(_open_time)
		var urgent := secs <= 30 and not _finished and not _endless
		var clock_rect := Rect2(1132, 10, 138, 60)
		_hud.draw_style_box(UiStyle.panel_box(), clock_rect)
		_hud.draw_texture_rect(Art.CLOCK, Rect2(clock_rect.position + Vector2(14, 18), Vector2(24, 24)), false)
		var pulse := 1.0 + (0.12 * absf(sin(_clock * 6.0)) if urgent else 0.0)
		_hud.draw_set_transform(clock_rect.position + Vector2(90, 40), 0.0, Vector2(pulse, pulse))
		var clock_text := "%d:%02d" % [secs / 60, secs % 60]
		var clock_color := UiStyle.RED if urgent else UiStyle.INK
		if _endless and not _open:
			clock_text = "Fechado"
			clock_color = UiStyle.RED
		elif _endless and _closing and fmod(_clock, 1.6) < 0.8:
			clock_text = "A fechar"
			clock_color = UiStyle.INK_SOFT
		_hud.draw_string(font, Vector2(-44, 0), clock_text, HORIZONTAL_ALIGNMENT_CENTER, 88, 30 if clock_text.length() <= 5 else 22, clock_color)
		_hud.draw_set_transform(Vector2.ZERO)
		var score_rect := Rect2(1132, 78, 138, 60)
		_hud.draw_style_box(UiStyle.panel_box(), score_rect)
		_hud.draw_texture_rect(Art.COIN, Rect2(score_rect.position + Vector2(14, 18), Vector2(24, 24)), false)
		var s := 1.0 + _score_pulse * 0.35
		_hud.draw_set_transform(score_rect.position + Vector2(90, 40), 0.0, Vector2(s, s))
		_hud.draw_string(font, Vector2(-44, 0), "%d" % roundi(_shown_score), HORIZONTAL_ALIGNMENT_CENTER, 88, 30, UiStyle.INK)
		_hud.draw_set_transform(Vector2.ZERO)
	# Nome do restaurante no início da ronda.
	if _clock < 2.4 and not _tutorial:
		var a := clampf(minf(_clock / 0.3, (2.4 - _clock) / 0.4), 0.0, 1.0)
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
	_draw_ui_fx()
	# "Abrimos!" a crescer e a desaparecer.
	if not _tutorial and _clock > _open_anim and _clock < _open_anim + 1.2:
		var t := (_clock - _open_anim) / 1.2
		var s := 0.6 + ease(minf(t * 3.0, 1.0), 0.3) * 0.6 + t * 0.15
		var a := 1.0 - clampf((t - 0.6) / 0.4, 0.0, 1.0)
		_hud.draw_set_transform(Vector2(640, 330), sin(t * 8.0) * 0.04 * (1.0 - t), Vector2(s, s))
		_hud.draw_string(UiStyle.FONT, Vector2(-300, 4), "Abrimos!", HORIZONTAL_ALIGNMENT_CENTER, 600, 84, Color(UiStyle.INK, a))
		_hud.draw_string(UiStyle.FONT, Vector2(-300, 0), "Abrimos!", HORIZONTAL_ALIGNMENT_CENTER, 600, 84, Color(UiStyle.GOLD, a))
		_hud.draw_set_transform(Vector2.ZERO)


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
	var dishes: Array = (_orders.menu + _orders.drinks).filter(func(r): return counts.has(r["id"]))
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
		var raw := _raw_ingredients(recipe) if not recipe.get("drink", false) else []
		var raw_h := 36.0 if not raw.is_empty() else 0.0
		var rect := Rect2(_card("d" + id, Vector2(x, y)), Vector2(w, 40 + hint_h + raw_h))
		if pulse > 0.0:
			_hud.draw_rect(rect.grow(2 + pulse * 3), Color(UiStyle.GOLD, pulse))
		_hud.draw_style_box(UiStyle.paper_box(), rect)
		var plate := Item.for_recipe(recipe)
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
		_hud.draw_multiline_string(font, rect.position + Vector2(8, 49 + raw_h), hint,
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
		var rect := Rect2(_card("m%d" % customer.id, Vector2(x, y)) + shake, Vector2(w, 46))
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
				var plate := Item.for_recipe(missing[k])
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
	_prune_cards()


## Posição animada de um cartão: entra a deslizar da esquerda e, quando os de
## cima desaparecem, sobe suavemente em vez de saltar.
func _card(key: String, target: Vector2) -> Vector2:
	var c: Dictionary = _cards.get(key, {})
	var dt := get_process_delta_time()
	if c.is_empty():
		c = {"y": target.y, "age": 0.0}
		_cards[key] = c
		if _clock > 0.5:
			Sfx.play("pop", -10.0, 0.1)
	c["age"] += dt
	c["y"] = lerpf(c["y"], target.y, minf(dt * 12.0, 1.0))
	c["frame"] = _card_frame
	c["x"] = target.x
	var slide := 1.0 - ease(minf(c["age"] / 0.35, 1.0), -2.5)
	return Vector2(target.x - slide * 170.0, c["y"])


## Cartões que deixaram de aparecer: um brilho onde estavam (pedido servido).
func _prune_cards() -> void:
	for key in _cards.keys():
		var c: Dictionary = _cards[key]
		if c["frame"] != _card_frame:
			if String(key).begins_with("m") and not _finished:
				for i in 10:
					_ui_parts.append({"pos": Vector2(c["x"] + randf_range(10, 140), c["y"] + randf_range(5, 40)), "vel": Vector2(randf_range(-40, 40), randf_range(-60, -20)),
						"life": 0.6, "max": 0.6, "color": UiStyle.GOLD, "size": 3.0, "acc": Vector2.ZERO})
			_cards.erase(key)
	_card_frame += 1


## Partículas da HUD e moedas a voar para a pontuação.
func _update_ui_fx(delta: float) -> void:
	for p in _ui_parts:
		p["life"] -= delta
		p["vel"] += p["acc"] * delta
		p["pos"] += p["vel"] * delta
	_ui_parts = _ui_parts.filter(func(p): return p["life"] > 0.0)
	for f in _flying:
		f["t"] += delta
		if f["t"] >= f["dur"] and not f["done"]:
			f["done"] = true
			_score_pulse = 1.0
			Sfx.play("coin", -12.0, 0.2)
			for i in 4:
				_ui_parts.append({"pos": f["to"], "vel": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40, 90),
					"life": 0.35, "max": 0.35, "color": UiStyle.GOLD, "size": 3.0, "acc": Vector2.ZERO})
	_flying = _flying.filter(func(f): return not f["done"])


func _draw_ui_fx() -> void:
	for p in _ui_parts:
		var c: Color = p["color"]
		c.a *= clampf(p["life"] / p["max"] * 1.5, 0.0, 1.0)
		var sz: float = p["size"]
		if p.get("confetti", false):
			var w := absf(sin(p["life"] * 9.0 + sz)) * 6.0 + 1.0
			_hud.draw_rect(Rect2(p["pos"] - Vector2(w, 3) / 2.0, Vector2(w, 4)), c)
		else:
			_hud.draw_rect(Rect2(p["pos"] - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), c)
	for f in _flying:
		var t: float = clampf(f["t"] / f["dur"], 0.0, 1.0)
		if t <= 0.0:
			continue
		var e := ease(t, 1.8)
		var from: Vector2 = f["from"]
		var to: Vector2 = f["to"]
		var ctrl: Vector2 = (from + to) / 2.0 + Vector2(f["bend"], -160)
		var pos := from.lerp(ctrl, e).lerp(ctrl.lerp(to, e), e)
		var spin := absf(cos(f["t"] * 12.0))
		var size := Vector2(22 * maxf(spin, 0.15), 22) * (1.0 + sin(t * PI) * 0.4)
		_hud.draw_texture_rect(Art.COIN, Rect2(pos - size / 2.0, size), false)


func _spawn_coins(amount: int) -> void:
	var from := _to_screen(_kitchen.register_center() + Vector2(0, -10))
	var n := clampi(amount / 8, 3, 9)
	for i in n:
		_flying.append({"t": -i * 0.06, "dur": 0.75, "from": from + Vector2(randf_range(-10, 10), 0), "to": Vector2(1132 + 26, 78 + 30),
			"bend": randf_range(-120, 60), "done": false})


func _confetti(at: Vector2, count: int, spread := 1.0) -> void:
	var colors := [Color("ff6f6f"), UiStyle.GOLD, Color("6fcf6a"), Color("6fa8dc"), Color("eb94d6"), Color("fff8e6")]
	for i in count:
		_ui_parts.append({"pos": at + Vector2(randf_range(-20, 20), 0), "vel": Vector2(randf_range(-260, 260) * spread, randf_range(-420, -160)),
			"life": 1.6 + randf() * 0.8, "max": 2.2, "color": colors.pick_random(), "size": randf() * 6.0,
			"acc": Vector2(0, 520), "confetti": true})


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
			# Por baixo dos pés, para não tapar a legenda do botão por cima da estação.
			_tag(_to_screen(chef.position + Vector2(0, 17)), Levels.item_name(chef.held), 15, Color("fff8e6"), chef.color.darkened(0.45))
		if chef.slot >= HELPER_SLOT or not chef.is_local:
			continue
		var target := _kitchen.station_at(chef.target_cell())
		if target and target.item and not target is CrateStation:
			_tag(_to_screen(_kitchen.cell_center(target.cell) + Vector2(0, -15)), Levels.item_name(target.item), 13, Color(UiStyle.INK, 0.85), UiStyle.TEXT)
		_draw_context_prompt(chef, target)


## O que o botão faz agora, mesmo por cima da estação para onde o jogador está
## virado: "[✕] Anotar", "[□] Cortar", "[□] Cobrar"... Aparece com um pulo.
func _draw_context_prompt(chef: Chef, target: Station) -> void:
	var actions := _context_actions(chef, target) if target else []
	var key := str(chef.slot)
	var shown: Dictionary = _ctx_anim.get(key, {"text": "", "t": 0.0, "cell": Vector2i(-1, -1)})
	var label := str(actions)
	if label != shown["text"] or (target and target.cell != shown["cell"]):
		shown = {"text": label, "t": 0.0, "cell": target.cell if target else Vector2i(-1, -1)}
	shown["t"] = minf(shown["t"] + get_process_delta_time() * 6.0, 1.0)
	_ctx_anim[key] = shown
	if actions.is_empty():
		return
	var st: float = shown["t"]
	var pop := 1.0 + 0.25 * sin(st * PI) * (1.0 - st)
	var h := 20.0 * pop
	var center := _to_screen(_kitchen.cell_center(target.cell) + Vector2(0, -27))
	center.y -= (1.0 - ease(shown["t"], -2.0)) * 8.0
	# Fundo escuro arredondado para se ler por cima de tudo.
	var font_size := 15
	var w := 0.0
	for a in actions:
		w += Glyphs.width(chef.source, a[0], h) + 5 + UiStyle.FONT.get_string_size(a[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 10
	var rect := Rect2(center - Vector2(w / 2.0 + 4, h / 2.0 + 3), Vector2(w + 6, h + 6))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.06, 0.07, 0.82 * shown["t"])
	box.set_corner_radius_all(8)
	box.border_color = Color(chef.color, 0.9 * shown["t"])
	box.set_border_width_all(2)
	_hud.draw_style_box(box, rect)
	var x := rect.position.x + 6
	for a in actions:
		var pressed: bool = a[0] == &"use" and chef.use_down
		x += Glyphs.draw(_hud, chef.source, a[0], Vector2(x, center.y), h, pressed) + 5
		_hud.draw_string(UiStyle.FONT, Vector2(x, center.y + font_size * 0.36), a[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(UiStyle.TEXT, shown["t"]))
		x += UiStyle.FONT.get_string_size(a[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 10


## As ações que fazem alguma coisa nesta estação com o que o chef leva na mão.
func _context_actions(chef: Chef, st: Station) -> Array:
	var held := chef.held
	var out := []
	if _endless and st.cell == _kitchen.door_cell():
		if _finished:
			return out
		return [[&"pick", "Abrir o restaurante" if not _open else ("Reabrir" if _closing else "Fechar o restaurante")]]
	if held == null:
		if st is CrateStation:
			out.append([&"pick", "Pegar"])
		elif st is TableStation:
			var t := st as TableStation
			if t.customer and t.customer.is_calling():
				out.append([&"pick", "Anotar pedido"])
			elif t.has_dirty():
				out.append([&"pick", "Levantar pratos"])
		elif st is RegisterStation:
			if _orders.front_of_queue():
				out.append([&"use", "Cobrar"])
		elif st is SinkStation:
			var sink := st as SinkStation
			if sink.dirty > 0:
				out.append([&"use", "Lavar"])
			if sink.clean > 0:
				out.append([&"pick", "Pegar prato"])
		elif st is PlateStation:
			out.append([&"pick", "Pegar prato"])
		elif st.item:
			if st is BoardStation and st.item.can_chop():
				out.append([&"use", "Cortar"])
			out.append([&"pick", "Pegar"])
		return out
	if st is TableStation:
		var t := st as TableStation
		if t.customer and t.customer.is_waiting() and held.is_plate() and (t.customer.wants(held) or (held.second and t.customer.wants(held.second))):
			out.append([&"pick", "Servir"])
		elif t.has_dirty() and held.is_plate() and held.dirty:
			out.append([&"pick", "Levantar pratos"])
	elif st is TrashStation:
		out.append([&"pick", "Deitar fora" if not held.is_cookware() else "Despejar"])
	elif st is SinkStation:
		if held.is_plate() and held.dirty:
			out.append([&"pick", "Pôr a lavar"])
	elif st is StoveStation:
		if st.item == null and held.is_cookware():
			out.append([&"pick", "Pôr ao lume"])
		elif st.item and held.is_ingredient():
			out.append([&"pick", "Juntar"])
		elif st.item and held.is_plate() and st.item.cook_state == StoveStation.State.READY:
			out.append([&"pick", "Servir no prato"])
	elif st is CrateStation or st is RegisterStation or st is PlateStation:
		pass
	elif st.item == null:
		out.append([&"pick", "Pousar"])
	elif held.is_plate() or st.item.is_plate() or st.item.is_cookware():
		out.append([&"pick", "Juntar"])
	return out


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
	var n := _kitchen.chefs.size()
	var h := 112.0 if n <= 4 else (86.0 if n <= 6 else (546.0 - 4.0 * (n - 1)) / n)
	if h < 60.0:
		_draw_players_compact(y)
		return
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


## Muitos chefs (com ajudantes): linhas pequenas com a cara e o nome.
func _draw_players_compact(y: float) -> void:
	var n := _kitchen.chefs.size()
	var h := minf(56.0, (712.0 - y) / n - 3.0)
	for chef in _kitchen.chefs:
		var rect := Rect2(1130, y, 140, h)
		_hud.draw_style_box(UiStyle.paper_box(), rect)
		var s := clampf(h / 22.0, 1.4, 2.2)
		var bob := roundf(sin(_clock * 3.0 + chef.slot) * 1.0)
		_hud.draw_set_transform(rect.position + Vector2(6, 2 + bob), 0.0, Vector2(s, s))
		Art.frame(_hud, Art.CHEFS[chef.character], Art.CHEF_FRAME, 0, 0, Vector2.ZERO, false, Color.WHITE)
		Art.frame(_hud, Art.CHEF_TINT, Art.CHEF_FRAME, 0, 0, Vector2.ZERO, false, chef.color)
		_hud.draw_set_transform(Vector2.ZERO)
		var label := _helper_name(chef.slot) if chef.slot >= HELPER_SLOT else "P%d %s" % [chef.slot + 1, Art.CHEF_NAMES[chef.character]]
		_hud.draw_string(UiStyle.FONT, rect.position + Vector2(44, h / 2.0 + 6), label, HORIZONTAL_ALIGNMENT_LEFT, 92,
			_fit_size(label, 92, 17, 11), chef.color.darkened(0.45))
		y += h + 3


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
	if _endless:
		_draw_endless_results(x, y, w)
		return
	if _tutorial:
		_hud.draw_string(font, Vector2(x, y + 110), "Tutorial concluído!", HORIZONTAL_ALIGNMENT_CENTER, w, 52, UiStyle.INK)
		_hud.draw_multiline_string(font, Vector2(x + 50, y + 180), "Já sabes anotar pedidos, cozinhar, servir às mesas e lavar pratos. Agora é a sério: 3 minutos e clientes impacientes.",
			HORIZONTAL_ALIGNMENT_CENTER, w - 100, 24, -1, UiStyle.INK_SOFT)
		_prompt(Vector2(x + w / 2.0, y + 380), "{pick} Ir jogar")
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
		if full:
			# Raios de luz a rodar atrás das estrelas ganhas.
			var glow := clampf(age / 0.3, 0.0, 1.0)
			for k in 10:
				var ang := _clock * 0.6 + k * TAU / 10.0 + i
				var p1 := center + Vector2.RIGHT.rotated(ang - 0.12) * 70.0
				var p2 := center + Vector2.RIGHT.rotated(ang + 0.12) * 70.0
				_hud.draw_colored_polygon(PackedVector2Array([center, p1, p2]), Color(UiStyle.GOLD, 0.22 * glow))
		var tex := Art.STAR if full else Art.STAR_EMPTY
		var size := tex.get_size() * s / 2.0
		_hud.draw_texture_rect(tex, Rect2(center - size / 2.0, size), false)
	_prompt(Vector2(x + w / 2.0, y + 395), "À espera do host..." if Net.is_client() else "{pick} Voltar ao lobby")


## Legenda a piscar devagar, com o botão desenhado. `center` é o meio da linha.
func _prompt(center: Vector2, text: String) -> void:
	var a := 0.7 + 0.3 * sin(_clock * 4.0)
	var sources := _local_sources()
	var w := _rich_width(sources, text, 26)
	var bounce := absf(sin(_clock * 3.0)) * 2.0
	Glyphs.draw_rich(_hud, sources, text, center - Vector2(w / 2.0, 22 + bounce), w + 4, 26, Color(UiStyle.INK, a))


func _rich_width(sources: Array, text: String, size: int) -> float:
	var w := 0.0
	for word in text.split(" "):
		for t in Glyphs._tokens(word):
			w += Glyphs._token_w(sources, t, size * 1.25, size)
		w += UiStyle.FONT.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return w


## Fontes de input dos jogadores deste PC (para desenhar os botões certos).
func _local_sources() -> Array:
	var out := []
	for chef in _kitchen.chefs:
		if chef.is_local and chef.slot < HELPER_SLOT and chef.source:
			out.append(chef.source)
	if out.is_empty():
		out.append(Glyphs.primary_source())
	return out


## Painel do tutorial: por baixo dos talões, com os botões desenhados no texto.
## Cada passo novo entra a deslizar e com um brilho.
func _draw_tutorial() -> void:
	if not _tutorial or _tutorial.is_finished() or _finished:
		return
	var sources := _local_sources()
	var text := _tutorial.text()
	var w := 150.0
	var inner := w - 18.0
	var text_h := Glyphs.draw_rich(_hud, sources, text, Vector2.ZERO, inner, 17, UiStyle.INK, 1.3, true)
	var t := ease(_tutorial_anim, -2.4)
	var rect := Rect2(Vector2(6 - (1.0 - t) * 190.0, maxf(_tickets_bottom + 8.0, 120.0)), Vector2(w, text_h + 44))
	_hud.draw_style_box(UiStyle.paper_box(), rect)
	# Cabeçalho: "Passo 3 de 16" e uma barra de progresso.
	var head := rect.position + Vector2(10, 8)
	_hud.draw_string(UiStyle.FONT, head + Vector2(0, 12), "Passo %d de %d" % [_tutorial.step + 1, _tutorial.steps.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiStyle.INK_SOFT)
	var bar := Rect2(head + Vector2(0, 18), Vector2(inner, 4))
	_hud.draw_rect(bar, Color(UiStyle.INK, 0.15))
	var done := float(_tutorial.step) / _tutorial.steps.size()
	_hud.draw_rect(Rect2(bar.position, Vector2(bar.size.x * done, bar.size.y)), UiStyle.GOLD)
	Glyphs.draw_rich(_hud, sources, text, rect.position + Vector2(9, 32), inner, 17, UiStyle.INK, 1.3)
	# Brilho a passar quando chega um passo novo.
	if _tutorial_anim < 1.0:
		_hud.draw_rect(rect, Color(1, 0.95, 0.7, 0.35 * (1.0 - _tutorial_anim)))


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
	if _finished:
		if Net.is_host():
			_back_to_lobby()
		return
	if _pause_menu.is_open():
		_pause_menu.close()
		return
	_pause_menu.open()
	# Online o jogo não para: os chefs deste PC ficam quietos enquanto o menu está aberto.
	if Net.online:
		for chef in _kitchen.chefs:
			if chef.is_local and not chef.source is BotSource:
				chef.frozen = true


func _on_resume() -> void:
	if _finished:
		return
	for chef in _kitchen.chefs:
		if chef.is_local and not chef.source is BotSource:
			chef.frozen = false


## Um jogador saiu da sala: o chef dele desaparece.
## O ajudante controlado pelo jogo (empregado de mesa ou cozinheiro). Só o
## anfitrião o faz pensar; nos outros PCs segue as posições recebidas.
func _add_helper(index: int, preset: int) -> void:
	var role: int = GameState.HELPER_PRESETS[preset][1]
	var zone: int = GameState.HELPER_PRESETS[preset][2]
	var chef := Chef.new()
	chef.slot = HELPER_SLOT + index
	chef.color = HELPER_COLORS[index]
	chef.character = [2, 4, 5, 3, 1, 0][role]
	chef.kitchen = _kitchen
	# Começa no sítio do trabalho dele (o segundo um pouco ao lado).
	var start: Vector2i = {
		HelperAI.Role.WAITER: Vector2i(15, 5), HelperAI.Role.HOST: Vector2i(17, 7), HelperAI.Role.RUNNER: Vector2i(12, 6),
		HelperAI.Role.PREP: Vector2i(5, 5), HelperAI.Role.BARMAN: Vector2i(18, 5),
	}.get(role, [Vector2i(9, 5), Vector2i(9, 2), Vector2i(9, 10)][zone])
	chef.position = _kitchen.cell_center(_free_cell_near(start))
	chef.is_local = not Net.is_client()
	var brain := HelperAI.new(role as HelperAI.Role, chef, _kitchen, _orders, zone as HelperAI.Zone)
	chef.source = BotSource.new(brain)
	# Os ajudantes passam por entre os outros chefs (e os jogadores por entre
	# eles): nunca ficam encravados frente a frente num corredor.
	chef.collision_layer = 2
	chef.collision_mask = 1
	chef.interact_requested.connect(_on_interact.bind(chef))
	chef.throw_requested.connect(_on_throw.bind(chef))
	_kitchen.add_child(chef)
	_kitchen.chefs.append(chef)


## Célula de chão livre mais perto (sem outro chef em cima).
func _free_cell_near(start: Vector2i) -> Vector2i:
	var taken := _kitchen.chefs.map(func(c): return _kitchen.cell_at(c.position))
	for radius in 8:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := start + Vector2i(dx, dy)
				if c.y < 0 or c.y >= Kitchen.LAYOUT.size() or c.x < 0 or c.x >= Kitchen.LAYOUT[0].length():
					continue
				var ch := Kitchen.LAYOUT[c.y][c.x]
				if (ch == "." or ch.is_valid_int()) and not taken.has(c):
					return c
	return start


## Nome curto do ajudante para o retrato.
func _helper_name(slot: int) -> String:
	var preset: int = GameState.helpers[slot - HELPER_SLOT]
	return ["Empregado", "Cozinheiro", "Host", "Corredor", "Aj. cozinha", "Barman"][GameState.HELPER_PRESETS[preset][1]]


func _on_players_changed() -> void:
	for chef in _kitchen.chefs.duplicate():
		if chef.slot < HELPER_SLOT and PlayerRegistry.get_player(chef.slot).is_empty():
			_kitchen.chefs.erase(chef)
			chef.queue_free()


## Casa Aberta: a porta abre o restaurante, fecha-o (deixa de entrar gente e,
## quando sair o último cliente, acaba) ou reabre-o. Só no anfitrião.
func _on_door(_chef: Chef) -> void:
	if _finished:
		return
	if not _open:
		_set_door(true, false)
	else:
		_set_door(true, not _closing)


## Muda o estado da porta, com sons e efeitos (no anfitrião e nos outros PCs).
func _set_door(open: bool, closing: bool) -> void:
	if open == _open and closing == _closing:
		return
	var opening := open and not _open
	_open = open
	_closing = closing
	_orders.closed = not open or closing
	var at := _kitchen.cell_center(_kitchen.door_cell())
	if opening:
		_open_anim = _clock
		_opened = false
		_kitchen._door_time = _kitchen._time
		Sfx.play("door", -2.0, 0.0)
		# O primeiro grupo chega logo.
		_orders._spawn = _orders.spawn_every - 1.5
	elif closing:
		Sfx.play("ui_back", -2.0, 0.0)
		_kitchen.particles.text(at + Vector2(0, -20), "A fechar...", UiStyle.GOLD)
	else:
		Sfx.play("ui_confirm", -2.0, 0.0)
		_kitchen.particles.text(at + Vector2(0, -20), "Reaberto!", UiStyle.GREEN)


## Casa Aberta: aviso por cima do salão enquanto se prepara ou se está a fechar.
func _draw_endless_banner() -> void:
	if not _endless or _finished or (_open and not _closing) or _clock < 2.4:
		return
	var text := "Casa Aberta: preparem a cozinha com calma (cortem, cozinhem, tenham pratos prontos). Quando estiverem prontos, vão à porta e carreguem em {pick} para abrir." if not _open \
		else "A fechar: já não entra ninguém. Atendam e cobrem os últimos clientes. Para continuar, {pick} na porta para reabrir."
	var sources := _local_sources()
	var w := 520.0
	var text_h := Glyphs.draw_rich(_hud, sources, text, Vector2.ZERO, w - 32, 20, UiStyle.INK, 1.3, true)
	var a := clampf((_clock - 2.4) / 0.4, 0.0, 1.0)
	var rect := Rect2(Vector2(1280 - 150 - w - 20, 96 - (1.0 - ease(a, -2.0)) * 40.0), Vector2(w, text_h + 26))
	_hud.draw_style_box(UiStyle.paper_box(), rect)
	Glyphs.draw_rich(_hud, sources, text, rect.position + Vector2(16, 14), w - 32, 20, UiStyle.INK, 1.3)


func _draw_endless_results(x: float, y: float, w: float) -> void:
	var font := UiStyle.FONT
	var secs := floori(_open_time)
	_hud.draw_string(font, Vector2(x, y + 86), "Casa fechada!", HORIZONTAL_ALIGNMENT_CENTER, w, 52, UiStyle.INK)
	_hud.draw_string(font, Vector2(x, y + 132), "Aberto %d:%02d    Pratos servidos: %d" % [secs / 60, secs % 60, _orders.delivered_count],
		HORIZONTAL_ALIGNMENT_CENTER, w, 24, UiStyle.INK_SOFT)
	_hud.draw_string(font, Vector2(x, y + 162), "Pagos: %d    Falhados: %d" % [_orders.paid_count, _orders.failed_count],
		HORIZONTAL_ALIGNMENT_CENTER, w, 24, UiStyle.INK_SOFT)
	_hud.draw_texture_rect(Art.COIN, Rect2(Vector2(x + w / 2 - 90, y + 196), Vector2(36, 36)), false)
	_hud.draw_string(font, Vector2(x + w / 2 - 44, y + 228), "%d" % roundi(_shown_score), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UiStyle.INK)
	if _new_record and _finish_time > 1.2:
		var pop := 1.0 + maxf(0.0, 1.0 - (_finish_time - 1.2) / 0.25) * 0.5
		_hud.draw_set_transform(Vector2(x + w / 2.0, y + 300), sin(_clock * 3.0) * 0.05, Vector2(pop, pop))
		_hud.draw_string(font, Vector2(-200, 4), "Novo recorde!", HORIZONTAL_ALIGNMENT_CENTER, 400, 44, UiStyle.INK)
		_hud.draw_string(font, Vector2(-200, 0), "Novo recorde!", HORIZONTAL_ALIGNMENT_CENTER, 400, 44, UiStyle.GOLD)
		_hud.draw_set_transform(Vector2.ZERO)
	else:
		_hud.draw_string(font, Vector2(x, y + 300), "Recorde: %d" % GameState.best_endless(_level["id"]), HORIZONTAL_ALIGNMENT_CENTER, w, 26, UiStyle.INK_SOFT)
	_prompt(Vector2(x + w / 2.0, y + 395), "À espera do host..." if Net.is_client() else "{pick} Voltar ao lobby")


func _snapshot() -> Array:
	var chefs := _kitchen.chefs.map(func(c: Chef):
		return [c.slot, c.position, c.facing, Item.serialize(c.held), c.use_down, c.emote_left])
	var stations := []
	for station: Station in _kitchen.stations.values():
		var data: Variant = station.serialize()
		if data != null:
			stations.append([station.cell, data])
	return [chefs, stations, _orders.serialize(), _time_left, _finished, _kitchen.serialize_loose(), [_open, _closing, _open_time]]


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
func _rpc_snapshot_packed(size: int, packed: PackedByteArray) -> void:
	if size <= 0 or size > 1 << 20:
		return
	var data = bytes_to_var(packed.decompress(size, FileAccess.COMPRESSION_ZSTD))
	if data is Array:
		_rpc_snapshot(data)


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
	if _endless and data.size() > 6:
		_set_door(data[6][0], data[6][1])
		_open_time = data[6][2]
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
