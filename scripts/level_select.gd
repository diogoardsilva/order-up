extends Control
## Escolha do restaurante e do nível. Em cima, um cartão por restaurante com a
## decoração do país e as estrelas ganhas; por baixo, os 5 níveis do
## restaurante escolhido (cada um abre com uma estrela no anterior), o que se
## cozinha nesse nível e as definições (modo, dificuldade e ajudantes).
## Cima/baixo escolhe a linha, esquerda/direita muda-a, ✕ ou Start começam e
## a bola volta ao lobby. Online só o host escolhe; os outros veem a escolha.

const CARD_SIZE := Vector2(224, 236)
const CARD_Y := 196.0
const GAP := 18.0
const TILE_SIZE := Vector2(200, 78)
const TILE_GAP := 12.0
const TILES_Y := 336.0
const INFO_RECT := Rect2(116, 426, 1048, 92)

var _index := 0
var _stage := 0
var _shown := 0.0  # posição animada do cartão selecionado
var _shown_stage := 0.0
var _time := 0.0
var _last_x := {}
var _last_y := {}
var _desc_label: Label
## Linha escolhida: 0 = restaurantes, 1 = níveis, depois as definições (ver _rows()).
var _row := 0
var _row_labels: Array[Label] = []
## Estrelas guardadas: "restaurante:nível" -> 0 a 3 (lidas uma vez).
var _stars := {}
var _shake := 0.0
## Primeira linha de definições que se vê (para os cliques do rato).
var _first_row := 0
## Quantas linhas de definições se veem de cada vez.
const VISIBLE_ROWS := 3
const SETTINGS_FROM := 2
const MODE_NAMES := ["Serviço (com estrelas)", "Casa Aberta (sem fim)"]
const MODE_DESC := ["Uma ronda com relógio: façam pontos para ganhar as 3 estrelas e abrir o nível seguinte.",
	"Preparem a cozinha com calma, abram a porta quando quiserem e fechem quando quiserem parar. Menu todo."]
var _cards: Control


func _ready() -> void:
	theme = UiStyle.theme()
	UiStyle.background(self)
	for i in Levels.ALL.size():
		for k in Levels.STAGES:
			_stars["%d:%d" % [i, k]] = GameState.best_stars(Levels.stage_id(i, k))
	_index = clampi(GameState.level, 0, Levels.ALL.size() - 1)
	_stage = clampi(GameState.stage, 0, Levels.STAGES - 1)
	if not _unlocked(_index, _stage):
		_stage = 0
	_shown = _index
	_shown_stage = _stage
	var title := UiStyle.label("Escolham o restaurante", 46, UiStyle.TEXT, 10)
	title.position = Vector2(0, 14)
	title.size = Vector2(1280, 56)
	add_child(title)
	_cards = Control.new()
	_cards.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.draw.connect(_draw_all)
	add_child(_cards)
	for i in VISIBLE_ROWS:
		var l := UiStyle.label("", 24, UiStyle.TEXT, 8)
		l.position = Vector2(0, 528 + i * 31)
		l.size = Vector2(1280, 34)
		add_child(l)
		_row_labels.append(l)
	_desc_label = UiStyle.label("", 19, UiStyle.MUTED, 6)
	_desc_label.position = Vector2(0, 626)
	_desc_label.size = Vector2(1280, 30)
	add_child(_desc_label)
	_refresh_helper()
	if Net.is_client():
		var wait := UiStyle.label("O host está a escolher o restaurante...", 22, UiStyle.TEXT, 6)
		wait.position = Vector2(0, 668)
		wait.size = Vector2(1280, 40)
		add_child(wait)
	else:
		var help := PromptBar.new([[&"move", "Escolher e mudar"], [&"pick", "Começar"], [&"dash", "Voltar"]])
		help.position = Vector2(0, 668)
		help.size = Vector2(1280, 44)
		add_child(help)
		# Para quem joga só com o rato.
		var back := UiStyle.button("Voltar", _go_back, 170, false)
		back.position = Vector2(24, 664)
		back.size = Vector2(170, 48)
		add_child(back)
		var go := UiStyle.button("Começar", _start, 190, false)
		go.position = Vector2(1066, 664)
		go.size = Vector2(190, 48)
		add_child(go)
	for source in DeviceManager.all_sources():
		source.poll()
		_last_x[source] = source.move.x
		_last_y[source] = source.move.y
	Net.level_choice_changed.connect(func(i: int, helpers: Array, endless: bool, settings: Array):
		_index = i
		_stage = int(settings[2]) if settings.size() > 2 else 0
		GameState.helpers = helpers.duplicate()
		GameState.endless = endless
		GameState.difficulty = settings[0]
		GameState.custom = settings[1].duplicate()
		_refresh_helper()
		Sfx.play("ui_move"))
	Sfx.music_on()


func _unlocked(index: int, stage: int) -> bool:
	return stage <= 0 or int(_stars.get("%d:%d" % [index, stage - 1], 0)) > 0


## As linhas de definições, por ordem: [id, nome, valor, descrição].
func _rows() -> Array:
	var rows := []
	rows.append(["mode", "Modo", MODE_NAMES[1 if GameState.endless else 0], MODE_DESC[1 if GameState.endless else 0]])
	var d: Array = GameState.DIFFICULTIES[GameState.difficulty]
	var v := GameState.difficulty_values()
	rows.append(["difficulty", "Dificuldade", d[0], "Paciência dos clientes x%s, ronda de %d min." % [str(snappedf(v["patience"], 0.01)), v["minutes"]]])
	if GameState.difficulty == GameState.DIFFICULTIES.size() - 1:
		rows.append(["patience", "Paciência dos clientes", GameState.CUSTOM_PATIENCE[GameState.custom[0]][1], "Quanto tempo esperam para pedir e pela comida."])
		rows.append(["spawn", "Clientes a chegar", GameState.CUSTOM_SPAWN[GameState.custom[1]][1], "De quanto em quanto tempo entra um grupo."])
		rows.append(["time", "Duração da ronda", GameState.CUSTOM_TIME[GameState.custom[2]][1], "No modo Serviço (a Casa Aberta não tem relógio)."])
	# Ajudantes: os escolhidos e mais um lugar vazio (até 8).
	for i in GameState.MAX_HELPERS:
		var preset: int = GameState.helpers[i]
		rows.append(["helper%d" % i, "Ajudante %d" % (i + 1), GameState.HELPER_PRESETS[preset][0], GameState.HELPER_PRESETS[preset][3]])
		if preset == 0:
			break
	return rows


func _refresh_helper() -> void:
	var rows := _rows()
	_row = clampi(_row, 0, rows.size() + SETTINGS_FROM - 1)
	var r := _row - SETTINGS_FROM
	# Janela de linhas à volta da escolhida.
	var first := clampi(r - 1, 0, maxi(rows.size() - VISIBLE_ROWS, 0))
	if r < 0:
		first = clampi(_first_row, 0, maxi(rows.size() - VISIBLE_ROWS, 0))
	_first_row = first
	for i in _row_labels.size():
		var k := first + i
		var l := _row_labels[i]
		if k >= rows.size():
			l.text = ""
			continue
		var focused := r == k
		var more := ""
		if i == 0 and first > 0:
			more = "  ▲"
		elif i == VISIBLE_ROWS - 1 and k < rows.size() - 1:
			more = "  ▼"
		l.text = ("> %s:  < %s >" if focused else "%s:  %s") % [rows[k][1], rows[k][2]] + more
		l.add_theme_color_override("font_color", UiStyle.GOLD if focused else UiStyle.TEXT)
	if _desc_label:
		match _row:
			0:
				_desc_label.text = "%s  ·  %s  ·  %d de %d estrelas" % [Levels.ALL[_index]["name"], Levels.ALL[_index]["place"], _restaurant_stars(_index), Levels.STAGES * 3]
			1:
				_desc_label.text = "Ganhem pelo menos 1 estrela num nível para abrir o seguinte." if not GameState.endless else "Na Casa Aberta joga-se com o menu todo do restaurante."
			_:
				_desc_label.text = rows[r][3]


func _restaurant_stars(index: int) -> int:
	var total := 0
	for k in Levels.STAGES:
		total += int(_stars.get("%d:%d" % [index, k], 0))
	return total


## Esquerda/direita na linha de definições escolhida.
func _change_row(dir: int) -> void:
	var id: String = _rows()[_row - SETTINGS_FROM][0]
	match id:
		"mode":
			GameState.set_endless(not GameState.endless)
		"difficulty":
			GameState.set_difficulty(posmod(GameState.difficulty + dir, GameState.DIFFICULTIES.size()), GameState.custom)
		"patience", "spawn", "time":
			var k := ["patience", "spawn", "time"].find(id)
			var sizes := [GameState.CUSTOM_PATIENCE.size(), GameState.CUSTOM_SPAWN.size(), GameState.CUSTOM_TIME.size()]
			var c := GameState.custom.duplicate()
			c[k] = posmod(c[k] + dir, sizes[k])
			GameState.set_difficulty(GameState.difficulty, c)
		_:
			var i := id.trim_prefix("helper").to_int()
			var helpers := GameState.helpers.duplicate()
			helpers[i] = posmod(helpers[i] + dir, GameState.HELPER_PRESETS.size())
			# Um lugar vazio no meio puxa os de baixo para cima.
			var kept := helpers.filter(func(h): return h != 0)
			while kept.size() < GameState.MAX_HELPERS:
				kept.append(0)
			if helpers[i] != 0:
				kept = helpers
			GameState.set_helpers(kept)
	_refresh_helper()


func _can_choose(source: InputSource) -> bool:
	if Net.is_client():
		return false
	return PlayerRegistry.has_source(source) or PlayerRegistry.players.is_empty()


func _sync() -> void:
	if Net.online:
		Net.set_level_choice.rpc(_index, GameState.helpers, GameState.endless, [GameState.difficulty, GameState.custom, _stage])


func _start() -> void:
	if not GameState.endless and not _unlocked(_index, _stage):
		Sfx.play("ui_back")
		_shake = 1.0
		return
	Sfx.play("ui_confirm")
	GameState.choose(_index, _stage)
	if Net.online:
		Net.start_level.rpc(_index, GameState.helpers, GameState.endless, [GameState.difficulty, GameState.custom, _stage])
	else:
		GameState.mode = GameState.Mode.PLAY
		Transition.go("res://scenes/level.tscn")


func _go_back() -> void:
	Sfx.play("ui_back")
	if Net.online:
		Net.return_to_lobby.rpc()
	else:
		Transition.go("res://scenes/lobby.tscn")


## Rato: clicar num restaurante ou num nível escolhe-o (clicar outra vez no
## nível escolhido começa); nas definições, a metade esquerda/direita da linha
## (ou a roda) muda o valor.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or Net.is_client():
		return
	var at := mb.position
	var wheel := mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN
	if mb.button_index != MOUSE_BUTTON_LEFT and not wheel:
		return
	var count := Levels.ALL.size()
	var start_x := (1280.0 - (count * CARD_SIZE.x + (count - 1) * GAP)) / 2.0
	for i in count:
		var rect := Rect2(Vector2(start_x + i * (CARD_SIZE.x + GAP), CARD_Y - CARD_SIZE.y / 2.0), CARD_SIZE)
		if rect.has_point(at) and not wheel:
			_row = 0
			if i != _index:
				_index = i
				_stage = 0
				while _stage < Levels.STAGES - 1 and _unlocked(_index, _stage + 1):
					_stage += 1
			_after_mouse()
			return
	var tiles_x := (1280.0 - (Levels.STAGES * TILE_SIZE.x + (Levels.STAGES - 1) * TILE_GAP)) / 2.0
	for k in Levels.STAGES:
		var rect := Rect2(Vector2(tiles_x + k * (TILE_SIZE.x + TILE_GAP), TILES_Y - 6), TILE_SIZE + Vector2(0, 6))
		if rect.has_point(at) and not wheel:
			var again := _row == 1 and _stage == k
			_row = 1
			_stage = k
			_after_mouse()
			if again:
				_start()
			return
	for i in _row_labels.size():
		var rect := Rect2(Vector2(240, 528 + i * 31), Vector2(800, 31))
		var k := _first_row + i
		if rect.has_point(at) and k < _rows().size():
			_row = k + SETTINGS_FROM
			var dir := (1 if at.x > 640 else -1) if not wheel else (-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			_change_row(dir)
			_after_mouse()
			return


func _after_mouse() -> void:
	Sfx.play("ui_move")
	_refresh_helper()
	_sync()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	_shown = lerpf(_shown, _index, minf(1.0, delta * 12.0))
	_shown_stage = lerpf(_shown_stage, _stage, minf(1.0, delta * 14.0))
	for source in DeviceManager.all_sources():
		source.poll()
		var x := source.move.x
		var last: float = _last_x.get(source, 0.0)
		_last_x[source] = x
		var y := source.move.y
		var last_y: float = _last_y.get(source, 0.0)
		_last_y[source] = y
		if not _can_choose(source):
			continue
		if absf(y) > 0.5 and absf(last_y) <= 0.5:
			_row = clampi(_row + (1 if y > 0.0 else -1), 0, _rows().size() + SETTINGS_FROM - 1)
			_refresh_helper()
			Sfx.play("ui_move")
		if absf(x) > 0.5 and absf(last) <= 0.5:
			var dir := 1 if x > 0.0 else -1
			if _row == 0:
				_index = clampi(_index + dir, 0, Levels.ALL.size() - 1)
				# Ao mudar de restaurante fica no último nível aberto.
				_stage = 0
				while _stage < Levels.STAGES - 1 and _unlocked(_index, _stage + 1):
					_stage += 1
				_refresh_helper()
			elif _row == 1:
				_stage = clampi(_stage + dir, 0, Levels.STAGES - 1)
			else:
				_change_row(dir)
			Sfx.play("ui_move")
			_sync()
		elif source.just_pressed(&"pick") or source.just_pressed(&"pause"):
			_start()
			return
		elif source.just_pressed(&"dash"):
			_go_back()
			return
	_cards.queue_redraw()


func _draw_all() -> void:
	_draw_cards()
	_draw_stages()
	_draw_stage_info()


func _draw_cards() -> void:
	var font := UiStyle.FONT
	var count := Levels.ALL.size()
	var total := count * CARD_SIZE.x + (count - 1) * GAP
	var start_x := (1280.0 - total) / 2.0
	for i in count:
		var level: Dictionary = Levels.ALL[i]
		var selected := i == _index
		var focus := clampf(1.0 - absf(_shown - i), 0.0, 1.0)
		var s := 1.0 + (0.06 if _row == 0 else 0.03) * focus
		var center := Vector2(start_x + i * (CARD_SIZE.x + GAP) + CARD_SIZE.x / 2.0, CARD_Y - 8 * focus + (sin(_time * 3.0) * 2.0 if selected and _row == 0 else 0.0))
		_cards.draw_set_transform(center, 0.0, Vector2(s, s))
		var rect := Rect2(-CARD_SIZE / 2.0, CARD_SIZE)
		if selected:
			_cards.draw_rect(rect.grow(6), UiStyle.GOLD if _row == 0 else UiStyle.GOLD.darkened(0.35))
		_cards.draw_style_box(UiStyle.paper_box(), rect)
		_draw_preview(level, Rect2(rect.position + Vector2(12, 12), Vector2(CARD_SIZE.x - 24, 112)))
		_cards.draw_string(font, rect.position + Vector2(0, 160), level["name"], HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x, 30, UiStyle.INK)
		_cards.draw_string(font, rect.position + Vector2(0, 184), level["place"], HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x, 20, UiStyle.INK_SOFT)
		# Estrelas do restaurante (soma dos 5 níveis), ou o recorde da Casa Aberta.
		if GameState.endless:
			_cards.draw_texture_rect(Art.COIN, Rect2(Vector2(-62, rect.end.y - 42), Vector2(26, 26)), false)
			_cards.draw_string(font, Vector2(-30, rect.end.y - 21), "Recorde %d" % GameState.best_endless(level["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.INK)
		else:
			_cards.draw_texture_rect(Art.STAR, Rect2(Vector2(-46, rect.end.y - 44), Vector2(30, 30)), false)
			_cards.draw_string(font, Vector2(-10, rect.end.y - 21), "%d / %d" % [_restaurant_stars(i), Levels.STAGES * 3], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiStyle.INK)
		_cards.draw_set_transform(Vector2.ZERO)


## Os 5 níveis do restaurante escolhido, como talões pendurados.
func _draw_stages() -> void:
	var font := UiStyle.FONT
	var rest: Dictionary = Levels.ALL[_index]
	var total := Levels.STAGES * TILE_SIZE.x + (Levels.STAGES - 1) * TILE_GAP
	var start_x := (1280.0 - total) / 2.0
	var dim := 0.45 if GameState.endless else 1.0
	for k in Levels.STAGES:
		var st: Dictionary = rest["stages"][k]
		var open := _unlocked(_index, k)
		var selected := k == _stage and not GameState.endless
		var focus := clampf(1.0 - absf(_shown_stage - k), 0.0, 1.0) if not GameState.endless else 0.0
		var lift := (6.0 * focus if _row == 1 else 2.0 * focus)
		var shake := sin(_time * 50.0) * 6.0 * _shake if selected else 0.0
		var rect := Rect2(Vector2(start_x + k * (TILE_SIZE.x + TILE_GAP) + shake, TILES_Y - lift), TILE_SIZE)
		if selected:
			_cards.draw_rect(rect.grow(5), Color(UiStyle.GOLD if _row == 1 else UiStyle.GOLD.darkened(0.35), dim))
		if open:
			_cards.draw_style_box(UiStyle.paper_box(), rect)
		else:
			_cards.draw_rect(rect, Color(UiStyle.PANEL, dim))
			_cards.draw_rect(rect, Color(UiStyle.INK, dim), false, 3.0)
		var ink := Color(UiStyle.INK if open else UiStyle.MUTED, dim)
		# Número grande à esquerda, num círculo.
		var c := rect.position + Vector2(30, rect.size.y / 2.0)
		_cards.draw_circle(c, 20.0, Color(UiStyle.INK if open else UiStyle.BG, dim))
		_cards.draw_circle(c, 17.0, Color(Color("d23a32") if open else UiStyle.PANEL, dim))
		_cards.draw_string(font, c + Vector2(-20, 9), str(k + 1), HORIZONTAL_ALIGNMENT_CENTER, 40, 28, Color(UiStyle.PAPER, dim))
		var name_w := TILE_SIZE.x - 62
		var name_size := 22 if font.get_string_size(st["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x <= name_w else 18
		_cards.draw_string(font, rect.position + Vector2(56, 32), st["name"], HORIZONTAL_ALIGNMENT_LEFT, name_w, name_size, ink)
		if open:
			var got := int(_stars.get("%d:%d" % [_index, k], 0))
			for j in 3:
				var tex := Art.STAR if j < got else Art.STAR_EMPTY
				_cards.draw_texture_rect(tex, Rect2(rect.position + Vector2(56 + j * 26, 42), Vector2(22, 22)), false, Color(1, 1, 1, dim))
		else:
			_draw_lock(rect.position + Vector2(64, 52), dim)
			_cards.draw_string(font, rect.position + Vector2(80, 60), "1 estrela no %d" % k, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)


func _draw_lock(at: Vector2, alpha: float) -> void:
	var ink := Color(UiStyle.INK, alpha)
	var gold := Color(UiStyle.GOLD, alpha)
	_cards.draw_arc(at + Vector2(0, -4), 5.0, PI, TAU, 10, ink, 4.0)
	_cards.draw_rect(Rect2(at + Vector2(-8, -4), Vector2(16, 13)), ink)
	_cards.draw_rect(Rect2(at + Vector2(-6, -2), Vector2(12, 9)), gold)
	_cards.draw_rect(Rect2(at + Vector2(-1, 0), Vector2(2, 4)), ink)


## O que se cozinha no nível escolhido: descrição e os pratos com o desenho.
func _draw_stage_info() -> void:
	var font := UiStyle.FONT
	var rect := INFO_RECT
	_cards.draw_style_box(UiStyle.panel_box(), rect)
	var level := Levels.build(_index, -1 if GameState.endless else _stage)
	var title: String = "Casa Aberta: menu todo" if GameState.endless else "Nível %d: %s" % [_stage + 1, level.get("stage_name", "")]
	_cards.draw_string(font, rect.position + Vector2(24, 40), title, HORIZONTAL_ALIGNMENT_LEFT, 330, 26, UiStyle.INK)
	var desc: String = "Abram e fechem a porta quando quiserem." if GameState.endless else level.get("desc", "")
	_cards.draw_string(font, rect.position + Vector2(24, 68), desc, HORIZONTAL_ALIGNMENT_LEFT, 330, 18, UiStyle.INK_SOFT)
	# Pratos do nível, com o desenho no prato.
	var dishes := Levels.dishes(level)
	var x0 := rect.position.x + 370
	var slot_w := (rect.size.x - 390) / maxf(dishes.size(), 1.0)
	slot_w = minf(slot_w, 150.0)
	for k in dishes.size():
		var cx := x0 + k * slot_w + slot_w / 2.0
		var plate := Item.for_recipe(dishes[k])
		_cards.draw_set_transform(Vector2(cx, rect.position.y + 38), 0.0, Vector2(2.5, 2.5))
		ItemArt.draw_item(_cards, plate, Vector2.ZERO)
		_cards.draw_set_transform(Vector2.ZERO)
		var dname: String = dishes[k]["name"]
		var size := 18 if font.get_string_size(dname, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x <= slot_w - 6 else 15
		_cards.draw_string(font, Vector2(cx - slot_w / 2.0, rect.position.y + 78), dname, HORIZONTAL_ALIGNMENT_CENTER, slot_w, size, UiStyle.INK)
	if not GameState.endless and Levels.drinks(level).size() > 0:
		_cards.draw_string(font, rect.position + Vector2(rect.size.x - 200, 18), "+ bebidas no bar", HORIZONTAL_ALIGNMENT_RIGHT, 180, 16, UiStyle.INK_SOFT)


## Pedacinho do salão com a decoração do país.
func _draw_preview(level: Dictionary, rect: Rect2) -> void:
	var theme_id: String = level["theme"]
	var floor_tex := Art.themed(theme_id, "floor")
	var tile := 48.0
	var cols := ceili(rect.size.x / tile)
	var rows := ceili(rect.size.y / tile)
	for y in rows:
		for x in cols:
			var dst := Rect2(rect.position + Vector2(x, y) * tile, Vector2(tile, tile)).intersection(rect)
			var src := Rect2(Vector2(x % 4, y % 4) * 24, (dst.size / 2.0))
			_cards.draw_texture_rect_region(floor_tex, dst, src)
	# Parede com decoração.
	var wall := Art.themed(theme_id, "wall_front")
	for x in cols:
		var dst := Rect2(rect.position + Vector2(x * tile, 0), Vector2(tile, tile)).intersection(rect)
		_cards.draw_texture_rect_region(wall, dst, Rect2(Vector2.ZERO, dst.size / 2.0))
	var deco := Art.themed(theme_id, "wall_deco")
	_cards.draw_texture_rect(deco, Rect2(rect.position + Vector2(rect.size.x / 2.0 - deco.get_width(), 2), deco.get_size() * 2.0), false)
	var corner := Art.themed(theme_id, "corner_deco")
	_cards.draw_texture_rect(corner, Rect2(rect.position + Vector2(4, rect.size.y - corner.get_height() * 2 - 2), corner.get_size() * 2.0), false)
	# Mesa com cadeiras.
	var table_at := rect.position + Vector2(rect.size.x / 2.0 - 24, 58)
	var chair := Art.themed(theme_id, "chair")
	_cards.draw_texture_rect(chair, Rect2(table_at - Vector2(48, 0), Vector2(-48, 48)), false)
	_cards.draw_texture_rect(chair, Rect2(table_at + Vector2(48, 0), Vector2(48, 48)), false)
	_cards.draw_texture_rect(Art.themed(theme_id, "table"), Rect2(table_at, Vector2(48, 48)), false)
	_cards.draw_rect(rect, UiStyle.INK, false, 3.0)
