extends Control
## Menu principal: o restaurante a funcionar por trás, a placa com o nome e os
## botões de madeira. Rato, teclado e comando navegam os botões.

const SIGN := preload("res://assets/sprites/sign.png")
const SIGN_SCALE := 3.0
## Mesas que o "empregado invisível" do fundo serve, com um atraso.
const DEMO_TAKE_AFTER := 1.2
const DEMO_SERVE_AFTER := 3.5

var _time := 0.0
var _kitchen: Kitchen
var _orders: OrderManager
var _demo_timers := {}  # id do cliente -> segundos no estado atual
var _sign: Control
var _main_box: VBoxContainer
var _options_box: VBoxContainer
var _join_box: HBoxContainer
var _ip_edit: LineEdit
var _status: Label
var _first_button: Button
var _fullscreen_button: Button


func _ready() -> void:
	theme = UiStyle.theme()
	Sfx.set_sizzle(0.0)
	_build_background()

	# Escurece a esquerda, onde ficam a placa e os botões.
	for i in 20:
		var strip := ColorRect.new()
		strip.color = Color(0.12, 0.05, 0.05, 0.9 * (1.0 - i / 20.0))
		strip.position = Vector2(i * 38.0, 0)
		strip.size = Vector2(38, 720)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)

	_sign = Control.new()
	_sign.position = Vector2(60, 26)
	_sign.size = SIGN.get_size() * SIGN_SCALE
	_sign.pivot_offset = Vector2(_sign.size.x / 2.0, 0)
	_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign.draw.connect(_draw_sign)
	add_child(_sign)

	var column := VBoxContainer.new()
	column.position = Vector2(80, 248)
	column.custom_minimum_size = Vector2(360, 0)
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 10)
	column.add_child(_main_box)
	_first_button = UiStyle.button("Jogar", _start_local, 360)
	_main_box.add_child(_first_button)
	_main_box.add_child(UiStyle.button("Criar sala online", _host, 360))
	_main_box.add_child(UiStyle.button("Entrar numa sala online", _show_join, 360))
	_join_box = HBoxContainer.new()
	_join_box.add_theme_constant_override("separation", 10)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "IP do anfitrião"
	_ip_edit.text = GameState.last_ip
	_ip_edit.custom_minimum_size = Vector2(220, 56)
	_ip_edit.text_submitted.connect(func(_t): _join())
	_join_box.add_child(_ip_edit)
	_join_box.add_child(UiStyle.button("Ligar", _join, 130))
	_join_box.hide()
	_main_box.add_child(_join_box)
	_main_box.add_child(UiStyle.button("Opções", _show_options, 360))
	_main_box.add_child(UiStyle.button("Sair", func(): get_tree().quit(), 360))

	_options_box = _build_options()
	_options_box.hide()
	column.add_child(_options_box)

	_status = UiStyle.label(GameState.menu_message, 22, UiStyle.GOLD, 6)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 360
	column.add_child(_status)
	GameState.menu_message = ""

	var info := UiStyle.label("v%s  ·  F11: ecrã inteiro  ·  GPU: %s" % [
		ProjectSettings.get_setting("application/config/version"), RenderingServer.get_video_adapter_name()], 16, UiStyle.MUTED, 4)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.position = Vector2(16, 690)
	add_child(info)

	_first_button.grab_focus()
	_intro()
	Sfx.music_on()


func _build_background() -> void:
	# O mesmo restaurante do jogo, com clientes a entrar e a ser servidos sozinhos.
	_orders = OrderManager.new()
	add_child(_orders)
	_kitchen = Kitchen.new(_orders)
	_kitchen.quiet = true
	_kitchen.scale = Vector2(2, 2)
	_kitchen.position = Vector2(320, 62)
	_orders.kitchen = _kitchen
	# Numa camada por baixo da interface.
	var holder := CanvasLayer.new()
	holder.layer = -1
	add_child(holder)
	holder.add_child(_kitchen)
	for i in 3:
		_orders.spawn_customer(Recipes.ALL.pick_random())


func _build_options() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)
	box.add_child(panel)
	var title := UiStyle.label("Opções", 34, UiStyle.INK)
	inner.add_child(title)
	_fullscreen_button = UiStyle.button("", func():
		GameState.set_fullscreen(not GameState.fullscreen)
		_refresh_options(), 310)
	inner.add_child(_fullscreen_button)
	inner.add_child(_volume_row("Música", GameState.music_volume, func(v): GameState.set_volumes(v, GameState.sfx_volume)))
	inner.add_child(_volume_row("Efeitos", GameState.sfx_volume, func(v):
		GameState.set_volumes(GameState.music_volume, v)
		Sfx.play("pickup")))
	inner.add_child(UiStyle.label("Também podes usar F11 ou Alt+Enter.", 18, UiStyle.INK_SOFT))
	box.add_child(UiStyle.button("Voltar", _hide_options, 360))
	_refresh_options()
	return box


func _volume_row(text: String, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := UiStyle.label(text, 24, UiStyle.INK)
	label.custom_minimum_size.x = 90
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.1
	slider.value = value
	slider.custom_minimum_size = Vector2(200, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.add_theme_icon_override("grabber", Art.COIN)
	slider.add_theme_icon_override("grabber_highlight", Art.COIN)
	var track := StyleBoxFlat.new()
	track.bg_color = UiStyle.INK
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiStyle.GOLD
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.value_changed.connect(on_change)
	slider.focus_entered.connect(func(): Sfx.play("ui_move"))
	row.add_child(slider)
	return row


func _refresh_options() -> void:
	_fullscreen_button.text = "Ecrã inteiro: %s" % ("Sim" if GameState.fullscreen else "Não")


func _show_options() -> void:
	_main_box.hide()
	_options_box.show()
	_fullscreen_button.grab_focus()
	_pop(_options_box)


func _hide_options() -> void:
	_options_box.hide()
	_main_box.show()
	_first_button.grab_focus()
	_pop(_main_box)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _options_box.visible:
		Sfx.play("ui_back")
		_hide_options()


func _intro() -> void:
	# A placa cai do teto e os botões entram da esquerda um a um.
	_sign.position.y = -260
	var t := create_tween()
	t.tween_property(_sign, "position:y", 26.0, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	for i in _main_box.get_child_count():
		var b: Control = _main_box.get_child(i)
		if not b.visible:
			continue
		b.modulate.a = 0.0
		var bt := create_tween()
		bt.tween_interval(0.35 + i * 0.07)
		bt.tween_property(b, "modulate:a", 1.0, 0.25)


func _pop(node: Control) -> void:
	node.modulate.a = 0.0
	create_tween().tween_property(node, "modulate:a", 1.0, 0.2)


func _process(delta: float) -> void:
	_time += delta
	_sign.rotation = sin(_time * 1.1) * 0.03
	_sign.queue_redraw()
	_run_demo(delta)


## O "empregado invisível": anota os pedidos e serve as mesas do fundo.
func _run_demo(delta: float) -> void:
	for customer in _orders.customers:
		var t: float = _demo_timers.get(customer.id, 0.0) + delta
		if customer.is_calling() and t > DEMO_TAKE_AFTER:
			customer.take_order()
			_kitchen.show_fx(_kitchen.cell_center(customer.table.cell), "Anotado!", UiStyle.GOLD)
			t = 0.0
		elif customer.is_waiting() and customer.table.item == null and t > DEMO_SERVE_AFTER:
			var plate := Item.plate()
			plate.contents.assign(customer.recipe["needs"])
			customer.table.item = plate
			t = 0.0
		elif not customer.is_calling() and not customer.is_waiting():
			t = 0.0
		# Pratos sujos desaparecem ao fim de um bocado para as mesas voltarem a encher.
		_demo_timers[customer.id] = t
	for table in _kitchen.tables():
		if table.item and table.item.dirty and table.customer == null:
			table.item = null
	_orders.score = 0


func _draw_sign() -> void:
	_sign.draw_texture_rect(SIGN, Rect2(Vector2.ZERO, _sign.size), false)
	var font := UiStyle.FONT
	var w := _sign.size.x
	# Nome pintado na placa, com contorno escuro.
	for o in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(3, 3)]:
		_sign.draw_string(font, Vector2(0, 118) + o, "Order Up!", HORIZONTAL_ALIGNMENT_CENTER, w, 84, UiStyle.INK)
	_sign.draw_string(font, Vector2(0, 118), "Order Up!", HORIZONTAL_ALIGNMENT_CENTER, w, 84, UiStyle.GOLD)
	_sign.draw_string(font, Vector2(0, 160), "um restaurante a quatro mãos", HORIZONTAL_ALIGNMENT_CENTER, w, 24, UiStyle.PAPER)


## Na primeira vez que se joga, o jogo começa pelo tutorial.
func _start_local() -> void:
	Net.leave()
	GameState.mode = GameState.Mode.PLAY if GameState.tutorial_done else GameState.Mode.TUTORIAL
	Transition.go("res://scenes/lobby.tscn")


func _host() -> void:
	if Net.host() != OK:
		_status.text = "Não foi possível criar a sala (a porta %d já está em uso?)." % Net.PORT
		return
	GameState.mode = GameState.Mode.PLAY
	Transition.go("res://scenes/lobby.tscn")


func _show_join() -> void:
	_join_box.show()
	_ip_edit.grab_focus()


func _join() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip.is_empty() or Net.join(ip) != OK:
		_status.text = "Escreve um IP válido."
		return
	GameState.remember_ip(ip)
	_status.text = "A ligar a %s..." % ip
	multiplayer.connected_to_server.connect(func():
		GameState.mode = GameState.Mode.PLAY
		Transition.go("res://scenes/lobby.tscn"), CONNECT_ONE_SHOT)
