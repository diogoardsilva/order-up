class_name CharacterMenu
extends Control
## Criar o boneco do perfil: pele, cabelo, cor do cabelo, cara e a cor
## especial. À esquerda o boneco em grande (a andar e a rodar) com a roupa da
## função escolhida; em baixo, a roupa de todas as funções. Com o comando,
## cima/baixo escolhe a linha e esquerda/direita muda o valor.

signal closed

const KEYS: Array[String] = ["skin", "hair", "hair_color", "face", "accent"]
const LABELS := {"skin": "Pele", "hair": "Cabelo", "hair_color": "Cor do cabelo", "face": "Cara", "accent": "Cor especial"}
const ROW_WIDTH := 520.0

var _look := {}
var _outfit := 1
var _rows := {}
var _first: Button
var _preview: Control
var _title: Label
var _time := 0.0


func _ready() -> void:
	size = Vector2(1280, 720)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.05, 0.92)
	dim.size = size
	add_child(dim)
	_preview = Control.new()
	_preview.position = Vector2(40, 30)
	_preview.size = Vector2(620, 660)
	_preview.draw.connect(_draw_preview)
	add_child(_preview)

	var col := VBoxContainer.new()
	col.position = Vector2(700, 30)
	col.custom_minimum_size.x = ROW_WIDTH
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	_title = UiStyle.label("O teu boneco", 44, UiStyle.TEXT, 8)
	col.add_child(_title)
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)
	col.add_child(panel)
	for key in KEYS:
		_add_row(inner, key)
	_add_row(inner, "outfit")
	var hint := UiStyle.label("Esquerda/direita muda. A cor especial aparece no lenço, no avental, no laço, na gravata e no boné. A roupa muda com a função que escolhes no lobby.", 16, UiStyle.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = ROW_WIDTH
	inner.add_child(hint)
	col.add_child(UiStyle.button("Ao calhas", func():
		Sfx.play("ui_move")
		_look = CharacterLook.random()
		_refresh(), ROW_WIDTH))
	col.add_child(UiStyle.button("Guardar", _save, ROW_WIDTH))
	col.add_child(UiStyle.button("Cancelar", func(): closed.emit(), ROW_WIDTH))
	visibility_changed.connect(func():
		if visible:
			_open())


func focus_first() -> void:
	if _first:
		_first.grab_focus()


func _open() -> void:
	_look = Profiles.look(Profiles.active).duplicate()
	_title.text = "Boneco de %s" % Profiles.profile_name(Profiles.active)
	_refresh()


func _save() -> void:
	Sfx.play("ui_confirm")
	Profiles.set_look(Profiles.active, _look)
	Profiles.add_all("custom_look", 1)
	PlayerRegistry.refresh_looks()
	closed.emit()


func _add_row(parent: Control, key: String) -> void:
	var b := UiStyle.button("", func(): _change(key, 1), ROW_WIDTH - 24)
	b.custom_minimum_size.y = 40
	b.add_theme_font_size_override("font_size", 24)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("ui_left"):
			_change(key, -1)
			b.accept_event()
		elif event.is_action_pressed("ui_right"):
			_change(key, 1)
			b.accept_event())
	parent.add_child(b)
	_rows[key] = b
	if _first == null:
		_first = b


func _change(key: String, dir: int) -> void:
	Sfx.play("ui_move")
	if key == "outfit":
		_outfit = posmod(_outfit + dir, CharacterLook.OUTFIT_NAMES.size())
	else:
		_look[key] = posmod(int(_look.get(key, 0)) + dir, CharacterLook.count(key))
	_refresh()


func _refresh() -> void:
	for key in KEYS:
		(_rows[key] as Button).text = "%s:  ◀ %s ▶" % [LABELS[key], CharacterLook.value_name(_look, key)]
	(_rows["outfit"] as Button).text = "Ver a roupa de:  ◀ %s ▶" % CharacterLook.OUTFIT_NAMES[_outfit]
	_preview.queue_redraw()


func _process(delta: float) -> void:
	if visible:
		_time += delta
		_preview.queue_redraw()


func _draw_preview() -> void:
	var ci := _preview
	var r := Rect2(Vector2.ZERO, Vector2(620, 440))
	ci.draw_style_box(UiStyle.paper_box(), r)
	# Cor especial em fundo, bem suave.
	ci.draw_rect(r.grow(-14), Color(CharacterLook.accent_color(_look), 0.12))
	# Roda: frente, lado, costas, outro lado (2 s cada), a andar.
	var phase := int(_time / 2.0) % 4
	var row: int = [0, 2, 1, 2][phase]
	var flip := phase == 3
	var col := 1 + int(_time / 0.16) % 2
	var s := 14.0
	var c := Vector2(310, 225)
	ci.draw_set_transform(c + Vector2(0, 150), 0.0, Vector2(1, 0.35))
	ci.draw_circle(Vector2.ZERO, 120.0, Color(0, 0, 0, 0.16))
	ci.draw_set_transform(c - Vector2(8, 12) * s, 0.0, Vector2(s, s))
	CharacterLook.draw(ci, _look, _outfit, col, row, Vector2.ZERO, flip)
	ci.draw_set_transform(Vector2.ZERO)
	ci.draw_string(UiStyle.FONT, Vector2(0, 425), CharacterLook.OUTFIT_NAMES[_outfit], HORIZONTAL_ALIGNMENT_CENTER, 620, 30, UiStyle.INK)
	# Todas as roupas, pequenas.
	var w := 620.0 / 6.0
	for i in 6:
		var cell := Rect2(Vector2(i * w + 4, 456), Vector2(w - 8, 196))
		ci.draw_style_box(UiStyle.paper_box(), cell)
		if i == _outfit:
			ci.draw_rect(cell.grow(-3), UiStyle.GOLD, false, 4.0)
		var ss := 5.0
		ci.draw_set_transform(cell.position + Vector2(cell.size.x / 2.0 - 8 * ss, 18), 0.0, Vector2(ss, ss))
		CharacterLook.draw(ci, _look, i, 0, 0, Vector2.ZERO)
		ci.draw_set_transform(Vector2.ZERO)
		var name: String = CharacterLook.OUTFIT_NAMES[i].replace("Ajudante de cozinha", "Ajudante").replace("Empregado de mesa", "Empregado")
		ci.draw_string(UiStyle.FONT, cell.position + Vector2(0, 182), name, HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 20, UiStyle.INK)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.play("ui_back")
		closed.emit()
