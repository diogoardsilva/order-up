class_name ProfilesMenu
extends Control
## Perfis e conquistas: à esquerda os perfis deste PC (escolher, criar,
## mudar o nome, apagar); à direita as conquistas do perfil escolhido, com o
## progresso de cada uma. As escondidas aparecem como "???" até se ganharem.

signal closed

const TILE := Vector2(404, 74)

var _list: VBoxContainer
var _name_edit: LineEdit
var _grid: GridContainer
var _scroll: ScrollContainer
var _header: Label
var _filter := 0  # 0 todas, 1 ganhas, 2 por ganhar
var _filter_button: Button
var _first: Button
var _friends: FriendsMenu
var _character: CharacterMenu


func _ready() -> void:
	size = Vector2(1280, 720)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.05, 0.85)
	dim.size = size
	add_child(dim)
	var left := VBoxContainer.new()
	left.position = Vector2(30, 24)
	left.custom_minimum_size.x = 340
	left.add_theme_constant_override("separation", 8)
	add_child(left)
	left.add_child(UiStyle.label("Perfis", 44, UiStyle.TEXT, 8))
	var panel := PanelContainer.new()
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	panel.add_child(_list)
	left.add_child(panel)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nome do perfil novo"
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(340, 50)
	_name_edit.text_submitted.connect(func(_t): _create())
	left.add_child(_name_edit)
	left.add_child(UiStyle.button("Criar perfil", _create, 340))
	left.add_child(UiStyle.button("Mudar o nome", func():
		if Online.logged_in(Profiles.active):
			Sfx.play("ui_back")
			_name_edit.text = ""
			_name_edit.placeholder_text = "Com conta online, o nome é o da conta"
		elif not _name_edit.text.strip_edges().is_empty():
			Profiles.rename(Profiles.active, _name_edit.text)
			_name_edit.text = ""
			_name_edit.placeholder_text = "Nome do perfil novo"
			_refresh(), 340))
	left.add_child(UiStyle.button("Apagar este perfil", func():
		Profiles.remove(Profiles.active)
		_refresh(), 340))
	left.add_child(UiStyle.button("O meu boneco", func():
		Sfx.play("ui_confirm")
		_character.show()
		_character.focus_first(), 340))
	left.add_child(UiStyle.button("Conta online e amigos", _show_friends, 340))
	left.add_child(UiStyle.button("Voltar", func(): closed.emit(), 340))

	var right := VBoxContainer.new()
	right.position = Vector2(400, 24)
	right.add_theme_constant_override("separation", 8)
	add_child(right)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	right.add_child(head)
	_header = UiStyle.label("", 34, UiStyle.TEXT, 8)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.custom_minimum_size.x = 560
	head.add_child(_header)
	_filter_button = UiStyle.button("", func():
		_filter = (_filter + 1) % 3
		_refresh(), 260)
	head.add_child(_filter_button)
	var back := PanelContainer.new()
	back.add_theme_stylebox_override("panel", UiStyle.paper_box())
	right.add_child(back)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(840, 590)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	back.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(_grid)
	_friends = FriendsMenu.new()
	_friends.hide()
	_friends.closed.connect(func():
		_friends.hide()
		focus_first())
	add_child(_friends)
	_character = CharacterMenu.new()
	_character.hide()
	_character.closed.connect(func():
		_character.hide()
		_refresh()
		focus_first())
	add_child(_character)
	Profiles.changed.connect(_refresh)
	_refresh()


func focus_first() -> void:
	if _first:
		_first.grab_focus()


func _show_friends() -> void:
	Sfx.play("ui_confirm")
	_friends.show()
	_friends.focus_first()


func _create() -> void:
	Profiles.create(_name_edit.text)
	_name_edit.text = ""
	Sfx.play("ui_confirm")
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	for c in _list.get_children():
		c.queue_free()
	_first = null
	for i in Profiles.profiles.size():
		var p: Dictionary = Profiles.profiles[i]
		var mark := "● " if i == Profiles.active else "   "
		var cloud := "  · online" if Online.logged_in(i) else "  · local"
		var b := UiStyle.button("%s%s  (%d)%s" % [mark, p["name"], Profiles.unlocked_count(i), cloud], func():
			Profiles.active = i
			Profiles.save()
			Sfx.play("ui_confirm")
			_refresh(), 320)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 44
		_list.add_child(b)
		if i == Profiles.active or _first == null:
			_first = b
	var all := AchievementList.all()
	var index := Profiles.active
	_header.text = "Conquistas de %s: %d / %d" % [Profiles.profile_name(index), Profiles.unlocked_count(index), all.size()]
	_filter_button.text = ["Ver: todas", "Ver: ganhas", "Ver: por ganhar"][_filter]
	for c in _grid.get_children():
		c.queue_free()
	for a in all:
		var got := Profiles.is_unlocked(index, a["id"])
		if (_filter == 1 and not got) or (_filter == 2 and got):
			continue
		var tile := Control.new()
		tile.custom_minimum_size = TILE
		tile.draw.connect(_draw_tile.bind(tile, a, got, Profiles.progress(index, a)))
		_grid.add_child(tile)


func _draw_tile(tile: Control, a: Dictionary, got: bool, progress: float) -> void:
	var r := Rect2(Vector2.ZERO, tile.size)
	tile.draw_rect(r, Color("fff3d6") if got else Color("e9d6b4"))
	tile.draw_rect(r, Color(UiStyle.INK, 0.35), false, 2.0)
	var c := Vector2(36, r.size.y / 2.0)
	var secret: bool = a["hidden"] and not got
	tile.draw_circle(c, 24, Color("8a5a1c") if got else Color("a89074"))
	tile.draw_circle(c, 21, Color("f2c94c") if got else Color("cdb898"))
	if secret:
		tile.draw_string(UiStyle.FONT, c + Vector2(-8, 10), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("7a6550"))
	else:
		Toast.icon(tile, c, 14.0, a["icon"], Color("6b3d14") if got else Color("7a6550"))
	var font := UiStyle.FONT
	var name: String = "???" if secret else a["name"]
	var desc: String = "Conquista escondida." if secret else a["desc"]
	tile.draw_string(font, Vector2(70, 28), name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80, 20, UiStyle.INK)
	tile.draw_string(font, Vector2(70, 48), desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80, 14, UiStyle.INK_SOFT)
	if not got and not secret and a["goal"] > 1:
		var bar := Rect2(Vector2(70, 56), Vector2(r.size.x - 84, 8))
		tile.draw_rect(bar, Color(UiStyle.INK, 0.2))
		tile.draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), UiStyle.GOLD)


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _friends.visible and not _character.visible and event.is_action_pressed("ui_cancel") and not _name_edit.has_focus():
		get_viewport().set_input_as_handled()
		Sfx.play("ui_back")
		closed.emit()
	# Com o comando, cima/baixo no fim da lista dos perfis desliza as conquistas.
	if visible and event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == JOY_AXIS_RIGHT_Y:
		_scroll.scroll_vertical += int((event as InputEventJoypadMotion).axis_value * 40.0)
