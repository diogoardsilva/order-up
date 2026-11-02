class_name GraphicsMenu
extends VBoxContainer
## Definições de gráficos: predefinição (Baixo, Médio, Alto, Ultra) e cada
## opção à parte. Com o comando ou o teclado, esquerda/direita muda o valor;
## com o rato, clicar avança. As mudanças veem-se logo no restaurante por trás.

signal closed

const ROW_WIDTH := 500.0

var _rows := {}  # id -> Button
var _first: Button


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)
	add_child(panel)
	inner.add_child(UiStyle.label("Gráficos", 34, UiStyle.INK))
	var gpu := RenderingServer.get_video_adapter_name()
	var info := UiStyle.label("Placa: %s  ·  sugerido: %s" % [gpu if gpu else "?", Gfx.PRESET_NAMES[Gfx.suggested_preset()]], 16, UiStyle.INK_SOFT)
	info.clip_text = true
	info.custom_minimum_size.x = ROW_WIDTH
	inner.add_child(info)
	_add_row(inner, "preset")
	for id in Gfx.OPTIONS:
		_add_row(inner, id)
	_add_row(inner, "vsync")
	_add_row(inner, "fps_limit")
	_add_row(inner, "show_fps")
	var hint := UiStyle.label("Esquerda/direita muda o valor. O Ultra puxa pela placa: se o FPS cair, baixa as sombras ou o pós-processamento.", 16, UiStyle.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = ROW_WIDTH
	inner.add_child(hint)
	add_child(UiStyle.button("Voltar", func(): closed.emit(), ROW_WIDTH))
	Gfx.changed.connect(_refresh)
	_refresh()


func focus_first() -> void:
	_first.grab_focus()


func _add_row(parent: Control, id: String) -> void:
	var b := UiStyle.button("", func(): _change(id, 1), ROW_WIDTH)
	b.custom_minimum_size.y = 40
	b.add_theme_font_size_override("font_size", 24)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("ui_left"):
			_change(id, -1)
			b.accept_event()
		elif event.is_action_pressed("ui_right"):
			_change(id, 1)
			b.accept_event())
	parent.add_child(b)
	_rows[id] = b
	if _first == null:
		_first = b


func _change(id: String, dir: int) -> void:
	Sfx.play("ui_move")
	match id:
		"preset":
			Gfx.cycle_preset(dir)
		"vsync":
			Gfx.set_vsync(not Gfx.vsync)
		"fps_limit":
			Gfx.cycle_fps_limit(dir)
		"show_fps":
			Gfx.set_show_fps(not Gfx.show_fps)
		_:
			Gfx.cycle(id, dir)


func _refresh() -> void:
	for id in _rows:
		var name: String
		var value: String
		match id:
			"preset":
				name = "Qualidade"
				value = Gfx.preset_name()
			"vsync":
				name = "VSync"
				value = "Ligado" if Gfx.vsync else "Desligado"
			"fps_limit":
				name = "Limite de FPS"
				value = Gfx.fps_limit_name()
			"show_fps":
				name = "Mostrar FPS"
				value = "Sim" if Gfx.show_fps else "Não"
			_:
				name = Gfx.OPTIONS[id][0]
				value = Gfx.level_name(id)
		(_rows[id] as Button).text = "  %s:   < %s >" % [name, value]
