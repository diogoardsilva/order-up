extends Control
## Lobby local: cada dispositivo carrega no botão de pegar para entrar (até 4).

var _slots: Array[Dictionary] = []
var _pads_label: Label


func _ready() -> void:
	UiStyle.background(self)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var top := Control.new()
	top.custom_minimum_size.y = 8
	root.add_child(top)
	root.add_child(UiStyle.label(
		"Tutorial: quem vai aprender?" if GameState.mode == GameState.Mode.TUTORIAL else "Quem vai cozinhar?", 24))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)
	for i in PlayerRegistry.MAX_PLAYERS:
		row.add_child(_make_slot(i))

	root.add_child(UiStyle.label(
		"Entrar: Espaço / Enter / Cruz   ·   Sair: Shift / - / Círculo\nComeçar: Esc / Backspace / Options (sem ninguém, volta ao menu)", 11, UiStyle.MUTED))
	_pads_label = UiStyle.label("", 10, UiStyle.MUTED)
	root.add_child(_pads_label)

	# Primeira leitura sem efeito, para a tecla que abriu o lobby não contar como "entrar".
	for source in DeviceManager.all_sources():
		source.poll()
	PlayerRegistry.players_changed.connect(_refresh)
	DeviceManager.sources_changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	for source in DeviceManager.all_sources():
		source.poll()
		var joined := PlayerRegistry.has_source(source)
		if not joined and source.just_pressed(&"pick"):
			PlayerRegistry.join(source)
		elif joined and source.just_pressed(&"dash"):
			PlayerRegistry.leave(source)
		elif source.just_pressed(&"pause"):
			if not PlayerRegistry.players.is_empty():
				get_tree().change_scene_to_file("res://scenes/level.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
			return


func _make_slot(i: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = UiStyle.PANEL
	style.set_corner_radius_all(4)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	box.add_child(UiStyle.label("P%d" % (i + 1), 20))
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(32, 32)
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(swatch)
	var device := UiStyle.label("", 10)
	device.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(device)

	_slots.append({"style": style, "swatch": swatch, "device": device})
	return panel


func _refresh() -> void:
	for i in _slots.size():
		var slot := _slots[i]
		var player := PlayerRegistry.get_player(i)
		if player:
			var source: InputSource = player["source"]
			slot["swatch"].color = player["color"]
			slot["style"].border_color = player["color"]
			slot["device"].text = source.get_label() + ("" if source.is_available() else "\n(desligado)")
		else:
			slot["swatch"].color = UiStyle.BG
			slot["style"].border_color = UiStyle.PANEL
			slot["device"].text = "À espera..."
	var pads := DeviceManager.connected_pad_names()
	_pads_label.text = "Comandos ligados: " + (", ".join(pads) if pads else "nenhum")
