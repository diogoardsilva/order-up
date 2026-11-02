class_name FriendsMenu
extends Control
## Amigos do perfil ativo: o teu código de amigo (para dares aos outros),
## adicionar um amigo pelo código dele e a lista com quem está online.
## Se um amigo tiver uma sala aberta, dá para entrar logo.

signal closed

const REFRESH_EVERY := 10.0

var _code_label: Label
var _msg: Label
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
	col.add_child(UiStyle.label("Amigos", 52, UiStyle.TEXT, 10))
	_code_label = UiStyle.label("", 26, UiStyle.GOLD, 6)
	col.add_child(_code_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_edit = LineEdit.new()
	_edit.placeholder_text = "Código de amigo (ex. K7Q9XM)"
	_edit.max_length = 8
	_edit.custom_minimum_size = Vector2(400, 54)
	_edit.text_submitted.connect(func(_t): _add())
	row.add_child(_edit)
	_first = UiStyle.button("Adicionar", _add, 210)
	row.add_child(_first)
	_msg = UiStyle.label("", 20, UiStyle.MUTED, 4)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size.x = 620
	col.add_child(_msg)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.paper_box())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.custom_minimum_size.x = 600
	scroll.add_child(_list)
	col.add_child(panel)
	col.add_child(UiStyle.button("Voltar", func(): closed.emit(), 620))
	Online.friends_changed.connect(_refresh_list)
	Online.status_changed.connect(_refresh_header)
	visibility_changed.connect(func():
		if visible:
			_open())


func focus_first() -> void:
	_edit.grab_focus()


func _open() -> void:
	_refresh_header()
	_refresh_list()
	if await Online.ensure_account():
		_refresh_header()
		Online.heartbeat()
		Online.refresh_friends()


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
	var code := Online.friend_code()
	if not Online.enabled():
		_code_label.text = "Os amigos online ainda não estão ligados nesta versão."
	elif code.is_empty():
		_code_label.text = "A criar o teu perfil online..."
	else:
		_code_label.text = "%s, o teu código de amigo é  %s" % [Profiles.profile_name(Profiles.active), code]
	_msg.text = Online.message


func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	if Online.friends.is_empty():
		_list.add_child(UiStyle.label("Ainda não tens amigos. Dá o teu código à Bibs, à Nenas ou ao Afonso e escreve o deles aqui em cima.", 20, UiStyle.INK_SOFT))
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
	if visible and event.is_action_pressed("ui_cancel") and not _edit.has_focus():
		get_viewport().set_input_as_handled()
		Sfx.play("ui_back")
		closed.emit()
