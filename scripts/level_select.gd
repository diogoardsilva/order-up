extends Control
## Escolha do restaurante: um cartão por nível com a decoração do país, os
## pratos e as melhores estrelas. Por baixo, os dois ajudantes controlados
## pelo jogo. Cima/baixo escolhe a linha (restaurante, ajudante 1, ajudante 2),
## esquerda/direita muda-a, pegar começa e dash volta ao lobby. Online só o
## host escolhe; os outros veem a escolha.

const CARD_SIZE := Vector2(224, 400)
const GAP := 18.0

var _index := 0
var _shown := 0.0  # posição animada do cartão selecionado
var _time := 0.0
var _last_x := {}
var _last_y := {}
var _desc_label: Label
## Linha escolhida: 0 = restaurantes, depois as definições (ver _rows()).
var _row := 0
var _row_labels: Array[Label] = []
## Quantas linhas de definições se veem de cada vez.
const VISIBLE_ROWS := 3
const MODE_NAMES := ["Serviço (3 minutos, com estrelas)", "Casa Aberta (sem fim)"]
const MODE_DESC := ["Ronda de 3 minutos: façam pontos para ganhar as 3 estrelas.",
	"Preparem a cozinha com calma, abram a porta quando quiserem e fechem quando quiserem parar."]
var _cards: Control


func _ready() -> void:
	theme = UiStyle.theme()
	UiStyle.background(self)
	_index = clampi(GameState.level, 0, Levels.ALL.size() - 1)
	_shown = _index
	var title := UiStyle.label("Escolham o restaurante", 52, UiStyle.TEXT, 10)
	title.position = Vector2(0, 26)
	title.size = Vector2(1280, 60)
	add_child(title)
	_cards = Control.new()
	_cards.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.draw.connect(_draw_cards)
	add_child(_cards)
	for i in VISIBLE_ROWS:
		var l := UiStyle.label("", 24, UiStyle.TEXT, 8)
		l.position = Vector2(0, 540 + i * 31)
		l.size = Vector2(1280, 34)
		add_child(l)
		_row_labels.append(l)
	_refresh_helper()
	_desc_label = UiStyle.label("", 19, UiStyle.MUTED, 6)
	_desc_label.position = Vector2(0, 634)
	_desc_label.size = Vector2(1280, 30)
	add_child(_desc_label)
	if Net.is_client():
		var wait := UiStyle.label(_help_text(), 22, UiStyle.TEXT, 6)
		wait.position = Vector2(0, 668)
		wait.size = Vector2(1280, 40)
		add_child(wait)
	else:
		var help := PromptBar.new([[&"move", "Escolher e mudar"], [&"pick", "Começar"], [&"dash", "Voltar"]])
		help.position = Vector2(0, 668)
		help.size = Vector2(1280, 44)
		add_child(help)
	for source in DeviceManager.all_sources():
		source.poll()
		_last_x[source] = source.move.x
		_last_y[source] = source.move.y
	Net.level_choice_changed.connect(func(i: int, helpers: Array, endless: bool, settings: Array):
		_index = i
		GameState.helpers = helpers.duplicate()
		GameState.endless = endless
		GameState.difficulty = settings[0]
		GameState.custom = settings[1].duplicate()
		_refresh_helper()
		Sfx.play("ui_move"))
	Sfx.music_on()


func _help_text() -> String:
	if Net.is_client():
		return "O host está a escolher o restaurante..."
	return "Cima / baixo: escolher a linha      Esquerda / direita: mudar      Começar: pegar      Voltar: dash"


## As linhas de definições, por ordem: [id, nome, valor, descrição].
func _rows() -> Array:
	var rows := []
	rows.append(["mode", "Modo", MODE_NAMES[1 if GameState.endless else 0], MODE_DESC[1 if GameState.endless else 0]])
	var d: Array = GameState.DIFFICULTIES[GameState.difficulty]
	var v := GameState.difficulty_values()
	rows.append(["difficulty", "Dificuldade", d[0], "Paciência dos clientes x%.2g, ronda de %d min." % [v["patience"], v["minutes"]]])
	if GameState.difficulty == GameState.DIFFICULTIES.size() - 1:
		rows.append(["patience", "Paciência dos clientes", GameState.CUSTOM_PATIENCE[GameState.custom[0]][1], "Quanto tempo esperam para pedir e pela comida."])
		rows.append(["spawn", "Clientes a chegar", GameState.CUSTOM_SPAWN[GameState.custom[1]][1], "De quanto em quanto tempo entra um grupo."])
		rows.append(["time", "Duração da ronda", GameState.CUSTOM_TIME[GameState.custom[2]][1], "No modo Serviço (a Casa Aberta não tem relógio)."])
	# Ajudantes: os escolhidos e mais um lugar vazio (até 8).
	var shown := 0
	for i in GameState.MAX_HELPERS:
		var preset: int = GameState.helpers[i]
		rows.append(["helper%d" % i, "Ajudante %d" % (i + 1), GameState.HELPER_PRESETS[preset][0], GameState.HELPER_PRESETS[preset][3]])
		shown += 1
		if preset == 0:
			break
	return rows


func _refresh_helper() -> void:
	var rows := _rows()
	_row = clampi(_row, 0, rows.size())
	# Janela de linhas à volta da escolhida.
	var first := clampi(_row - 2, 0, maxi(rows.size() - VISIBLE_ROWS, 0))
	for i in _row_labels.size():
		var k := first + i
		var l := _row_labels[i]
		if k >= rows.size():
			l.text = ""
			continue
		var focused := _row == k + 1
		var more := ""
		if i == 0 and first > 0:
			more = "  ▲"
		elif i == VISIBLE_ROWS - 1 and k < rows.size() - 1:
			more = "  ▼"
		l.text = ("> %s:  < %s >" if focused else "%s:  %s") % [rows[k][1], rows[k][2]] + more
		l.add_theme_color_override("font_color", UiStyle.GOLD if focused else UiStyle.TEXT)
	if _desc_label:
		_desc_label.text = rows[_row - 1][3] if _row > 0 else ""


## Esquerda/direita na linha de definições escolhida.
func _change_row(dir: int) -> void:
	var id: String = _rows()[_row - 1][0]
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


func _process(delta: float) -> void:
	_time += delta
	_shown = lerpf(_shown, _index, minf(1.0, delta * 12.0))
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
			_row = clampi(_row + (1 if y > 0.0 else -1), 0, _rows().size())
			_refresh_helper()
			Sfx.play("ui_move")
		if absf(x) > 0.5 and absf(last) <= 0.5:
			var dir := 1 if x > 0.0 else -1
			if _row == 0:
				_index = clampi(_index + dir, 0, Levels.ALL.size() - 1)
			else:
				_change_row(dir)
			Sfx.play("ui_move")
			if Net.online:
				Net.set_level_choice.rpc(_index, GameState.helpers, GameState.endless, [GameState.difficulty, GameState.custom])
		elif source.just_pressed(&"pick"):
			Sfx.play("ui_confirm")
			GameState.level = _index
			if Net.online:
				Net.start_level.rpc(_index, GameState.helpers, GameState.endless, [GameState.difficulty, GameState.custom])
			else:
				GameState.mode = GameState.Mode.PLAY
				Transition.go("res://scenes/level.tscn")
			return
		elif source.just_pressed(&"dash") or source.just_pressed(&"pause"):
			Sfx.play("ui_back")
			if Net.online:
				Net.return_to_lobby.rpc()
			else:
				Transition.go("res://scenes/lobby.tscn")
			return
	_cards.queue_redraw()


func _draw_cards() -> void:
	var font := UiStyle.FONT
	var count := Levels.ALL.size()
	var total := count * CARD_SIZE.x + (count - 1) * GAP
	var start_x := (1280.0 - total) / 2.0
	for i in count:
		var level: Dictionary = Levels.ALL[i]
		var selected := i == _index
		var focus := clampf(1.0 - absf(_shown - i), 0.0, 1.0)
		var s := 1.0 + 0.06 * focus
		var center := Vector2(start_x + i * (CARD_SIZE.x + GAP) + CARD_SIZE.x / 2.0, 322 - 10 * focus + (sin(_time * 3.0) * 2.0 if selected else 0.0))
		_cards.draw_set_transform(center, 0.0, Vector2(s, s))
		var rect := Rect2(-CARD_SIZE / 2.0, CARD_SIZE)
		if selected:
			_cards.draw_rect(rect.grow(6), UiStyle.GOLD)
		_cards.draw_style_box(UiStyle.paper_box(), rect)
		_draw_preview(level, Rect2(rect.position + Vector2(12, 12), Vector2(CARD_SIZE.x - 24, 132)))
		_cards.draw_string(font, rect.position + Vector2(0, 178), level["name"], HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x, 30, UiStyle.INK)
		_cards.draw_string(font, rect.position + Vector2(0, 202), level["place"], HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x, 20, UiStyle.INK_SOFT)
		# Pratos do restaurante.
		var dishes := Levels.dishes(level)
		for k in dishes.size():
			var y := rect.position.y + 236 + k * 40
			var plate := Item.for_recipe(dishes[k])
			_cards.draw_set_transform(center + Vector2(rect.position.x + 34, y) * s, 0.0, Vector2(2, 2) * s)
			ItemArt.draw_item(_cards, plate, Vector2.ZERO)
			_cards.draw_set_transform(center, 0.0, Vector2(s, s))
			_cards.draw_string(font, Vector2(rect.position.x + 60, y + 7), dishes[k]["name"], HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 66, 20, UiStyle.INK)
		# Melhores estrelas (ou o recorde, no modo Casa Aberta).
		var best := GameState.best_stars(level["id"])
		if GameState.endless:
			_cards.draw_texture_rect(Art.COIN, Rect2(Vector2(-60, rect.end.y - 44), Vector2(28, 28)), false)
			_cards.draw_string(font, Vector2(-26, rect.end.y - 22), "Recorde %d" % GameState.best_endless(level["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.INK)
			best = -1
		for k in (3 if best >= 0 else 0):
			var tex := Art.STAR if k < best else Art.STAR_EMPTY
			_cards.draw_texture_rect(tex, Rect2(Vector2(-54 + k * 36, rect.end.y - 46) - Vector2(16, 0), Vector2(32, 32)), false)
		_cards.draw_set_transform(Vector2.ZERO)


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
	var table_at := rect.position + Vector2(rect.size.x / 2.0 - 24, 70)
	var chair := Art.themed(theme_id, "chair")
	_cards.draw_texture_rect(chair, Rect2(table_at - Vector2(48, 0), Vector2(-48, 48)), false)
	_cards.draw_texture_rect(chair, Rect2(table_at + Vector2(48, 0), Vector2(48, 48)), false)
	_cards.draw_texture_rect(Art.themed(theme_id, "table"), Rect2(table_at, Vector2(48, 48)), false)
	_cards.draw_rect(rect, UiStyle.INK, false, 3.0)
