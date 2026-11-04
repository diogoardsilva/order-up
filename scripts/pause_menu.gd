class_name PauseMenu
extends Control
## Menu de pausa (Options/Esc durante o jogo): continuar, gráficos, comandos,
## volume, voltar ao lobby ou sair. Sozinho ou no mesmo PC o jogo para; online
## não dá para parar os outros, por isso só abre o menu.

signal resumed
signal to_lobby
signal to_menu
signal restart
signal to_select

## O nível que se está a jogar (para o cartão das receitas à direita).
var level: Dictionary = {}
var _main: VBoxContainer
var _card: Control
var _graphics: GraphicsMenu
var _controls: ControlsMenu
var _first: Button
var _paused := false
var _opened_at := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiStyle.theme()
	size = Vector2(1280, 720)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.04, 0.05, 0.7)
	dim.size = size
	add_child(dim)

	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 8)
	_main.position = Vector2(110, 40)
	_main.custom_minimum_size.x = 400
	add_child(_main)
	var title := UiStyle.label("Pausa" if not Net.online else "Menu", 64, UiStyle.TEXT, 10)
	_main.add_child(title)
	if Net.online:
		_main.add_child(UiStyle.label("Online o jogo continua para os outros.", 18, UiStyle.MUTED, 4))
	_first = UiStyle.button("Continuar", close, 400)
	_main.add_child(_first)
	if not Net.is_client() and not level.is_empty() and level.has("stage_name"):
		_main.add_child(UiStyle.button("Recomeçar o nível", func(): _leave(restart), 400))
	_main.add_child(UiStyle.button("Gráficos...", func(): _show(_graphics), 400))
	_main.add_child(UiStyle.button("Comandos...", func(): _show(_controls), 400))
	var panel := PanelContainer.new()
	var vol := VBoxContainer.new()
	panel.add_child(vol)
	vol.add_child(UiStyle.volume_row("Música", GameState.music_volume, func(v): GameState.set_volumes(v, GameState.sfx_volume)))
	vol.add_child(UiStyle.volume_row("Efeitos", GameState.sfx_volume, func(v):
		GameState.set_volumes(GameState.music_volume, v)
		Sfx.play("pickup")))
	_main.add_child(panel)
	if not Net.is_client():
		_main.add_child(UiStyle.button("Escolher outro nível", func(): _leave(to_select), 400))
		_main.add_child(UiStyle.button("Voltar ao lobby", func(): _leave(to_lobby), 400))
	_main.add_child(UiStyle.button("Sair para o menu principal", func(): _leave(to_menu), 400))
	for b in _main.get_children():
		if b is Button:
			b.custom_minimum_size.y = 50

	# À direita, o talão do nível com as receitas de cada prato.
	_card = Control.new()
	_card.position = Vector2(590, 70)
	_card.size = Vector2(590, 560)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.draw.connect(_draw_card)
	add_child(_card)
	var help := PromptBar.new([[&"move", "Escolher"], [&"pick", "Confirmar"], [&"dash", "Voltar"]])
	help.position = Vector2(0, 672)
	help.size = Vector2(1280, 40)
	help.font_size = 20
	help.button_height = 28
	add_child(help)

	_graphics = GraphicsMenu.new()
	_graphics.position = Vector2(390, 12)
	_graphics.process_mode = Node.PROCESS_MODE_ALWAYS
	_graphics.closed.connect(_back)
	_graphics.hide()
	add_child(_graphics)
	_controls = ControlsMenu.new()
	_controls.position = Vector2(380, 60)
	_controls.closed.connect(_back)
	_controls.hide()
	add_child(_controls)
	hide()


## Talão de papel: restaurante, nível e como se faz cada prato.
func _draw_card() -> void:
	if level.is_empty():
		return
	var font := UiStyle.FONT
	var dishes := Levels.dishes(level)
	var rows := dishes.size()
	var h := 120.0 + rows * 62.0
	var rect := Rect2(Vector2.ZERO, Vector2(_card.size.x, minf(h, _card.size.y)))
	_card.draw_style_box(UiStyle.paper_box(), rect)
	# Picotado em cima, como num bloco de comandas.
	for x in range(10, int(rect.size.x) - 10, 14):
		_card.draw_rect(Rect2(Vector2(x, 6), Vector2(6, 2)), Color(UiStyle.INK, 0.25))
	_card.draw_string(font, Vector2(0, 50), level.get("name", ""), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 36, UiStyle.INK)
	var sub: String = level.get("place", "")
	if level.has("stage_name"):
		sub = "Nível %d  ·  %s" % [int(level["stage"]) + 1, level["stage_name"]]
	_card.draw_string(font, Vector2(0, 80), sub, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 22, UiStyle.INK_SOFT)
	_card.draw_line(Vector2(24, 96), Vector2(rect.size.x - 24, 96), Color(UiStyle.INK, 0.3), 2.0)
	var y := 104.0
	for recipe in dishes:
		if y + 56 > rect.size.y:
			break
		var plate := Item.for_recipe(recipe)
		_card.draw_set_transform(Vector2(52, y + 28), 0.0, Vector2(2.5, 2.5))
		ItemArt.draw_item(_card, plate, Vector2.ZERO)
		_card.draw_set_transform(Vector2.ZERO)
		_card.draw_string(font, Vector2(96, y + 24), recipe["name"], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 200, 24, UiStyle.INK)
		_card.draw_string(font, Vector2(96, y + 48), recipe["hint"], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 120, 18, UiStyle.INK_SOFT)
		_card.draw_string(font, Vector2(rect.size.x - 110, y + 24), "%d pts" % recipe["points"], HORIZONTAL_ALIGNMENT_RIGHT, 86, 20, UiStyle.INK_SOFT)
		y += 62.0


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	show()
	_back()
	_opened_at = Engine.get_process_frames()
	_paused = not Net.online
	if _paused:
		get_tree().paused = true
	Sfx.play("ui_confirm")
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not visible:
		return
	hide()
	if _paused:
		get_tree().paused = false
		_paused = false
	Sfx.play("ui_back")
	resumed.emit()


func _leave(sig: Signal) -> void:
	hide()
	get_tree().paused = false
	_paused = false
	sig.emit()


func _show(box: Control) -> void:
	_main.hide()
	_card.hide()
	_graphics.hide()
	_controls.hide()
	box.show()
	box.call("focus_first")
	Sfx.play("ui_confirm")


func _back() -> void:
	_graphics.hide()
	_controls.hide()
	_main.show()
	_card.show()
	_first.grab_focus()


func _process(_delta: float) -> void:
	if not visible or not _paused or Engine.get_process_frames() == _opened_at:
		return
	# Com o jogo parado os chefs não leem os comandos: o botão de pausa fecha daqui.
	for source in DeviceManager.all_sources():
		source.poll()
		if source.just_pressed(&"pause") and _main.visible:
			close()
			return


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _main.visible:
		close()
	else:
		Sfx.play("ui_back")
		_back()
