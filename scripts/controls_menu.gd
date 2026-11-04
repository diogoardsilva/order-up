class_name ControlsMenu
extends VBoxContainer
## Trocar os botões: escolhe-se o aparelho (comando ou um dos teclados) e depois
## carrega-se numa ação e no novo botão. Se esse botão já fazia outra coisa, as
## duas trocam. Os gatilhos L2/R2 também servem.

signal closed

const ROW_WIDTH := 520.0
const DEVICES: Array[String] = ["Comando", "Teclado (WASD)", "Teclado (setas)"]
const WAIT_TIME := 6.0

var _device := 0
var _device_button: Button
var _rows := {}  # action -> Button
## Ação à espera de um botão novo (ou &"").
var _waiting: StringName = &""
var _wait_left := 0.0
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 8)
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)
	add_child(panel)
	inner.add_child(UiStyle.label("Comandos", 34, UiStyle.INK))
	_device_button = _row_button(inner, func(): _cycle_device(1))
	_device_button.gui_input.connect(func(event: InputEvent):
		if _waiting != &"":
			return
		if event.is_action_pressed("ui_left"):
			_cycle_device(-1)
			_device_button.accept_event()
		elif event.is_action_pressed("ui_right"):
			_cycle_device(1)
			_device_button.accept_event())
	for action in Controls.ACTION_NAMES:
		_rows[action] = _row_button(inner, func(): _start_wait(action))
	_hint = UiStyle.label("", 16, UiStyle.INK_SOFT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = ROW_WIDTH
	inner.add_child(_hint)
	inner.add_child(UiStyle.button("Repor os botões de origem", func():
		Controls.reset()
		Sfx.play("ui_confirm")
		_refresh(), ROW_WIDTH))
	add_child(UiStyle.button("Voltar", func(): closed.emit(), ROW_WIDTH))
	_refresh()


func focus_first() -> void:
	_device_button.grab_focus()


func _row_button(parent: Control, on_pressed: Callable) -> Button:
	var b := UiStyle.button("", on_pressed, ROW_WIDTH)
	b.custom_minimum_size.y = 40
	b.add_theme_font_size_override("font_size", 24)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(b)
	return b


func _cycle_device(dir: int) -> void:
	_device = posmod(_device + dir, DEVICES.size())
	Sfx.play("ui_move")
	_refresh()


func _start_wait(action: StringName) -> void:
	if _waiting != &"":
		return
	_waiting = action
	# Um bocadinho de espera, para o botão que confirmou não contar já.
	_wait_left = WAIT_TIME + 0.25
	Sfx.play("ui_confirm")
	_refresh()


func _process(delta: float) -> void:
	if _waiting == &"":
		return
	_wait_left -= delta
	if _wait_left <= 0.0:
		_waiting = &""
		Sfx.play("ui_back")
	_refresh()


func _input(event: InputEvent) -> void:
	if _waiting == &"" or not is_visible_in_tree():
		return
	if _wait_left > WAIT_TIME:
		get_viewport().set_input_as_handled()
		return
	var done := false
	if _device == 0:
		if event is InputEventJoypadButton and event.pressed:
			Controls.set_pad(_waiting, (event as InputEventJoypadButton).button_index)
			done = true
		elif event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis_value > 0.6:
			var axis := (event as InputEventJoypadMotion).axis
			if axis == JOY_AXIS_TRIGGER_LEFT or axis == JOY_AXIS_TRIGGER_RIGHT:
				Controls.set_pad(_waiting, Controls.TRIGGER_L if axis == JOY_AXIS_TRIGGER_LEFT else Controls.TRIGGER_R)
				done = true
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		Controls.set_key(_device - 1, _waiting, code)
		done = true
	if event is InputEventJoypadButton or event is InputEventKey or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
	if done:
		var row: Button = _rows[_waiting]
		_waiting = &""
		Sfx.play("ui_confirm")
		_refresh()
		# Larga o foco e volta a dá-lo, para o botão carregado não ativar a linha outra vez.
		row.grab_focus.call_deferred()


func _playstation() -> bool:
	for name in DeviceManager.connected_pad_names():
		var n := String(name).to_lower()
		if n.contains("ps4") or n.contains("ps5") or n.contains("dualshock") or n.contains("dualsense") or n.contains("playstation"):
			return true
	return DeviceManager.connected_pad_names().is_empty()


func binding_text(action: StringName) -> String:
	if _device == 0:
		var id := Controls.pad_name(Controls.pad[action], _playstation())
		return Controls.PS_TEXT.get(id, id)
	var name := OS.get_keycode_string(Controls.keys[_device - 1][action])
	return KeyboardSource.KEY_NAMES_PT.get(name, name)


func _refresh() -> void:
	_device_button.text = "◀ %s ▶" % DEVICES[_device]
	for action in _rows:
		var b: Button = _rows[action]
		var value := "carrega no botão novo... %d" % ceili(minf(_wait_left, WAIT_TIME)) if action == _waiting else binding_text(action)
		b.text = "%s:  %s" % [Controls.ACTION_NAMES[action], value]
	if _waiting != &"":
		_hint.text = "Carrega no botão (ou tecla) para \"%s\". Se outro já o usar, trocam." % Controls.ACTION_NAMES[_waiting]
	else:
		_hint.text = "Escolhe uma ação e carrega no botão novo. Os gatilhos L2/R2 também dão. Mexer o chef é sempre no analógico ou nas setas/WASD."

