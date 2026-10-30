extends Control
## Menu principal. Rato, teclado e comando navegam os botões.

var _join_box: HBoxContainer
var _ip_edit: LineEdit
var _status: Label
var _title: Label
var _time := 0.0
var _chefs: Control


func _ready() -> void:
	theme = UiStyle.theme()
	UiStyle.background(self)

	# Chefs a desfilar em baixo, cada um com o seu personagem.
	_chefs = Control.new()
	_chefs.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chefs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chefs.draw.connect(_draw_chefs)
	add_child(_chefs)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 12)
	box.position.y -= 40
	add_child(box)

	_title = UiStyle.label("Order Up!", 110, UiStyle.GOLD, 18)
	_title.pivot_offset = Vector2(300, 60)
	box.add_child(_title)
	box.add_child(UiStyle.label("um restaurante a quatro mãos  ·  v%s" % ProjectSettings.get_setting("application/config/version"), 22, UiStyle.TEXT, 8))
	var gap := Control.new()
	gap.custom_minimum_size.y = 16
	box.add_child(gap)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var play := UiStyle.button("Jogar", _start_local)
	buttons.add_child(play)
	buttons.add_child(UiStyle.button("Criar sala online", _host))
	buttons.add_child(UiStyle.button("Entrar numa sala online", _show_join))
	for b in buttons.get_children():
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_join_box = HBoxContainer.new()
	_join_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_join_box.add_theme_constant_override("separation", 10)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "IP do anfitrião"
	_ip_edit.text = GameState.last_ip
	_ip_edit.custom_minimum_size = Vector2(260, 56)
	_ip_edit.text_submitted.connect(func(_t): _join())
	_join_box.add_child(_ip_edit)
	_join_box.add_child(UiStyle.button("Ligar", _join, 130))
	_join_box.hide()
	buttons.add_child(_join_box)

	var quit := UiStyle.button("Sair", func(): get_tree().quit())
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.add_child(quit)
	_status = UiStyle.label(GameState.menu_message, 22, UiStyle.GOLD, 6)
	box.add_child(_status)
	GameState.menu_message = ""
	play.grab_focus()

	var info := UiStyle.label("GPU: %s" % RenderingServer.get_video_adapter_name(), 16, UiStyle.MUTED, 4)
	info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info.position.y -= 28
	add_child(info)

	# Entrada: o título cai e os botões aparecem um a um.
	_title.scale = Vector2(0.3, 0.3)
	create_tween().tween_property(_title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	for i in buttons.get_child_count():
		var b: Control = buttons.get_child(i)
		b.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.15 + i * 0.08)
		t.tween_property(b, "modulate:a", 1.0, 0.25)
	Sfx.music_on()


func _process(delta: float) -> void:
	_time += delta
	_title.rotation = sin(_time * 1.3) * 0.025
	_chefs.queue_redraw()


func _draw_chefs() -> void:
	var scale := 4.0
	var w := size.x + 200.0
	for i in Art.CHEFS.size():
		var x := fmod(_time * 50.0 + i * w / Art.CHEFS.size(), w) - 100.0
		var pos := Vector2(x, size.y - 46)
		var col := 1 + int(_time / 0.15 + i) % 2
		_chefs.draw_set_transform(pos, 0.0, Vector2(scale, scale))
		_chefs.draw_circle(Vector2(0, 0), 6.0, Color(0, 0, 0, 0.25))
		var tl := Vector2(-Art.CHEF_FRAME.x / 2.0, -Art.CHEF_FRAME.y + 1 - (1 if col == 1 else 0))
		Art.frame(_chefs, Art.CHEFS[i], Art.CHEF_FRAME, col, 2, tl)
		Art.frame(_chefs, Art.CHEF_TINT, Art.CHEF_FRAME, col, 2, tl, false, PlayerRegistry.COLORS[i % 4])
	_chefs.draw_set_transform(Vector2.ZERO)


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
