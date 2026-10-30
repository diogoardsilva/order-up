extends Control
## Menu principal. Rato, teclado e comando navegam os botões.

var _join_box: HBoxContainer
var _ip_edit: LineEdit
var _status: Label


func _ready() -> void:
	UiStyle.background(self)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	box.add_child(UiStyle.label("Order Up!", 40))
	box.add_child(UiStyle.label("v%s · protótipo" % ProjectSettings.get_setting("application/config/version"), 12, UiStyle.MUTED))

	var play := _button("Jogar (local)", _start_local)
	box.add_child(play)
	box.add_child(_button("Criar sala online", _host))
	box.add_child(_button("Entrar numa sala online", _show_join))

	_join_box = HBoxContainer.new()
	_join_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "IP do anfitrião"
	_ip_edit.text = GameState.last_ip
	_ip_edit.custom_minimum_size.x = 130
	_ip_edit.text_submitted.connect(func(_t): _join())
	_join_box.add_child(_ip_edit)
	var connect_button := Button.new()
	connect_button.text = "Ligar"
	connect_button.pressed.connect(_join)
	_join_box.add_child(connect_button)
	_join_box.hide()
	box.add_child(_join_box)

	box.add_child(_button("Sair", func(): get_tree().quit()))
	_status = UiStyle.label(GameState.menu_message, 10, Color("f2c94c"))
	box.add_child(_status)
	GameState.menu_message = ""
	play.grab_focus()

	var info := UiStyle.label("GPU: %s" % RenderingServer.get_video_adapter_name(), 10, UiStyle.MUTED)
	info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info.position.y -= 18
	add_child(info)


## Na primeira vez que se joga, o jogo começa pelo tutorial.
func _start_local() -> void:
	Net.leave()
	GameState.mode = GameState.Mode.PLAY if GameState.tutorial_done else GameState.Mode.TUTORIAL
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _host() -> void:
	if Net.host() != OK:
		_status.text = "Não foi possível criar a sala (a porta %d já está em uso?)." % Net.PORT
		return
	GameState.mode = GameState.Mode.PLAY
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


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
		get_tree().change_scene_to_file("res://scenes/lobby.tscn"), CONNECT_ONE_SHOT)


func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 22)
	b.pressed.connect(on_pressed)
	return b
