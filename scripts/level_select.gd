extends Control
## Escolha do restaurante: um cartão por nível com a decoração do país, os
## pratos e as melhores estrelas. Esquerda/direita escolhe o restaurante,
## cima/baixo o ajudante, pegar começa e dash volta ao lobby. Online só o
## anfitrião escolhe; os outros veem a escolha.

const CARD_SIZE := Vector2(224, 400)
const GAP := 18.0

var _index := 0
var _shown := 0.0  # posição animada do cartão selecionado
var _time := 0.0
var _last_x := {}
var _last_y := {}
var _helper_label: Label
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
	_helper_label = UiStyle.label("", 28, UiStyle.GOLD, 8)
	_helper_label.position = Vector2(0, 590)
	_helper_label.size = Vector2(1280, 40)
	add_child(_helper_label)
	_refresh_helper()
	var help := UiStyle.label(_help_text(), 22, UiStyle.TEXT, 6)
	help.position = Vector2(0, 652)
	help.size = Vector2(1280, 40)
	add_child(help)
	for source in DeviceManager.all_sources():
		source.poll()
		_last_x[source] = source.move.x
		_last_y[source] = source.move.y
	Net.level_choice_changed.connect(func(i: int, helper: int):
		_index = i
		GameState.helper = helper as GameState.Helper
		_refresh_helper()
		Sfx.play("ui_move"))
	Sfx.music_on()


func _help_text() -> String:
	if Net.is_client():
		return "O anfitrião está a escolher o restaurante..."
	return "Restaurante: esquerda / direita      Ajudante: cima / baixo      Começar: pegar      Voltar: dash"


func _refresh_helper() -> void:
	_helper_label.text = "Ajudante:  < %s >" % GameState.HELPER_NAMES[GameState.helper]


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
			GameState.helper = wrapi(GameState.helper + (1 if y > 0.0 else -1), 0, GameState.HELPER_NAMES.size()) as GameState.Helper
			_refresh_helper()
			Sfx.play("ui_move")
			if Net.online:
				Net.set_level_choice.rpc(_index, GameState.helper)
		if absf(x) > 0.5 and absf(last) <= 0.5:
			_index = clampi(_index + (1 if x > 0.0 else -1), 0, Levels.ALL.size() - 1)
			Sfx.play("ui_move")
			if Net.online:
				Net.set_level_choice.rpc(_index, GameState.helper)
		elif source.just_pressed(&"pick"):
			Sfx.play("ui_confirm")
			GameState.level = _index
			if Net.online:
				Net.start_level.rpc(_index, GameState.helper)
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
		var center := Vector2(start_x + i * (CARD_SIZE.x + GAP) + CARD_SIZE.x / 2.0, 360 - 10 * focus + (sin(_time * 3.0) * 2.0 if selected else 0.0))
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
			var plate := Item.plate()
			plate.contents.assign(dishes[k]["needs"])
			_cards.draw_set_transform(center + Vector2(rect.position.x + 34, y) * s, 0.0, Vector2(2, 2) * s)
			ItemArt.draw_item(_cards, plate, Vector2.ZERO)
			_cards.draw_set_transform(center, 0.0, Vector2(s, s))
			_cards.draw_string(font, Vector2(rect.position.x + 60, y + 7), dishes[k]["name"], HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 66, 20, UiStyle.INK)
		# Melhores estrelas.
		var best := GameState.best_stars(level["id"])
		for k in 3:
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
