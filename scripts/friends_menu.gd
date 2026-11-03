class_name FriendsMenu
extends Control
## Conta online e amigos do perfil ativo. Sem conta: entrar (utilizador e
## palavra-passe) ou criar uma; o progresso fica na conta e é o mesmo em
## qualquer PC. Com conta: o código de amigo, adicionar amigos pelo código ou
## pelo utilizador, a lista com quem está online (e entrar na sala deles) e
## sair da conta.

signal closed

const REFRESH_EVERY := 10.0

var _code_label: Label
var _msg: Label
var _login_box: VBoxContainer
var _friends_box: VBoxContainer
var _user_edit: LineEdit
var _pass_edit: LineEdit
var _login_button: Button
var _edit: LineEdit
var _list: VBoxContainer
var _first: Button
var _refresh_time := 0.0


func _ready() -> void:
	size = Vector2(1280, 720)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.05, 0.9)
	dim.size = size
	add_child(dim)
	var col := VBoxContainer.new()
	col.position = Vector2(330, 30)
	col.custom_minimum_size.x = 620
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.add_child(UiStyle.label("Conta online", 52, UiStyle.TEXT, 10))
	_code_label = UiStyle.label("", 26, UiStyle.GOLD, 6)
	_code_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_code_label.custom_minimum_size.x = 620
	col.add_child(_code_label)
	_msg = UiStyle.label("", 20, UiStyle.MUTED, 4)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size.x = 620

	# Sem conta: entrar ou criar.
	_login_box = VBoxContainer.new()
	_login_box.add_theme_constant_override("separation", 10)
	col.add_child(_login_box)
	_user_edit = LineEdit.new()
	_user_edit.placeholder_text = "Utilizador (ex. diogo)"
	_user_edit.max_length = 16
	_user_edit.custom_minimum_size = Vector2(620, 54)
	_login_box.add_child(_user_edit)
	_pass_edit = LineEdit.new()
	_pass_edit.placeholder_text = "Palavra-passe"
	_pass_edit.secret = true
	_pass_edit.max_length = 64
	_pass_edit.custom_minimum_size = Vector2(620, 54)
	_pass_edit.text_submitted.connect(func(_t): _login())
	_user_edit.text_submitted.connect(func(_t): _pass_edit.grab_focus())
	_login_box.add_child(_pass_edit)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	_login_button = UiStyle.button("Entrar", _login, 305)
	buttons.add_child(_login_button)
	buttons.add_child(UiStyle.button("Criar conta", _register, 305))
	_login_box.add_child(buttons)
	_login_box.add_child(_msg)
	var why := UiStyle.label("Com conta, as conquistas, as estatísticas e o teu boneco ficam guardados online. Entra com o mesmo utilizador no Windows, no Mac ou no Linux e tens tudo igual. Também dá para adicionar amigos.", 18, UiStyle.MUTED)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size.x = 620
	_login_box.add_child(why)

	# Com conta: amigos.
	_friends_box = VBoxContainer.new()
	_friends_box.add_theme_constant_override("separation", 10)
	col.add_child(_friends_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_friends_box.add_child(row)
	_edit = LineEdit.new()
	_edit.placeholder_text = "Código ou utilizador de um amigo"
	_edit.max_length = 20
	_edit.custom_minimum_size = Vector2(400, 54)
	_edit.text_submitted.connect(func(_t): _add())
	row.add_child(_edit)
	_first = UiStyle.button("Adicionar", _add, 210)
	row.add_child(_first)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.paper_box())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.custom_minimum_size.x = 600
	scroll.add_child(_list)
	_friends_box.add_child(panel)
	_friends_box.add_child(UiStyle.button("Sair da conta", func():
		Sfx.play("ui_back")
		await Online.logout()
		_refresh_header()
		focus_first(), 620))
	col.add_child(UiStyle.button("Voltar", func(): closed.emit(), 620))
	Online.friends_changed.connect(_refresh_list)
	Online.status_changed.connect(_refresh_header)
	visibility_changed.connect(func():
		if visible:
			_open())


func focus_first() -> void:
	if Online.logged_in():
		_edit.grab_focus()
	elif _user_edit.text.is_empty():
		_user_edit.grab_focus()
	else:
		_pass_edit.grab_focus()


func _open() -> void:
	Online.message = ""
	_user_edit.text = Online.username()
	_pass_edit.text = ""
	_refresh_header()
	_refresh_list()
	if Online.logged_in():
		Online.heartbeat()
		Online.refresh_friends()
		Online.sync()


func _login() -> void:
	Sfx.play("ui_confirm")
	Online.message = "A entrar..."
	_refresh_header()
	if await Online.login(Profiles.active, _user_edit.text, _pass_edit.text):
		_pass_edit.text = ""
		_refresh_header()
		focus_first()


func _register() -> void:
	Sfx.play("ui_confirm")
	Online.message = "A criar a conta..."
	_refresh_header()
	if await Online.register(Profiles.active, _user_edit.text, _pass_edit.text):
		_pass_edit.text = ""
		_refresh_header()
		focus_first()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_time += delta
	if _refresh_time > REFRESH_EVERY:
		_refresh_time = 0.0
		Online.refresh_friends()


func _add() -> void:
	if _edit.text.strip_edges().is_empty():
		return
	Sfx.play("ui_confirm")
	await Online.add_friend(_edit.text)
	_edit.text = ""


func _refresh_header() -> void:
	var logged := Online.logged_in()
	_login_box.visible = not logged
	_friends_box.visible = logged
	# A mensagem fica na caixa que está à vista.
	var box: Control = _friends_box if logged else _login_box
	if _msg.get_parent() != box:
		_msg.get_parent().remove_child(_msg)
		box.add_child(_msg)
		box.move_child(_msg, 1 if logged else 3)
	if not Online.enabled():
		_code_label.text = "As contas online não estão ligadas nesta versão."
	elif not logged:
		_code_label.text = "Perfil local %s: entra numa conta online ou cria uma. O perfil passa a ter o nome da conta." % Profiles.profile_name(Profiles.active)
	else:
		_code_label.text = "Conta %s  ·  código de amigo  %s" % [Online.username(), Online.friend_code()]
	_msg.text = Online.message


func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	if Online.friends.is_empty():
		_list.add_child(UiStyle.label("Ainda não tens amigos. Para te adicionarem, dá o teu código de amigo (%s) ou o teu utilizador (%s). Para adicionares alguém, escreve o código ou o utilizador dessa pessoa aqui em cima." % [Online.friend_code(), Online.username()], 20, UiStyle.INK_SOFT))
		(_list.get_child(-1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	for f in Online.friends:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var online: bool = f.get("online", false)
		var dot := UiStyle.label("●", 26, Color("6fcf6a") if online else Color("9c8a78"))
		row.add_child(dot)
		var info := UiStyle.label("%s   (%s)" % [f.get("name", "?"), f.get("friend_code", "")], 24, UiStyle.INK)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.custom_minimum_size.x = 300
		row.add_child(info)
		var status: String = (f.get("status", "") if f.get("status") != null else "") if online else "Offline"
		var st := UiStyle.label(status, 18, UiStyle.INK_SOFT)
		st.custom_minimum_size.x = 120
		row.add_child(st)
		var room = f.get("room_code")
		if online and room is String and room != "":
			row.add_child(UiStyle.button("Entrar na sala", func(): Online.join_room(room), 170))
		else:
			var code: String = f.get("friend_code", "")
			var rm := UiStyle.button("Remover", func(): Online.remove_friend(code), 130)
			rm.modulate.a = 0.7
			row.add_child(rm)
		_list.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not _edit.has_focus() and not _user_edit.has_focus() and not _pass_edit.has_focus():
		get_viewport().set_input_as_handled()
		Sfx.play("ui_back")
		closed.emit()
