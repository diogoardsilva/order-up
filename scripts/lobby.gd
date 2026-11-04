extends Control
## Lobby: cada dispositivo carrega no botão de pegar para entrar (até 4) e
## escolhe o personagem com esquerda/direita. Online, os jogadores de todos os
## PCs aparecem aqui e só o anfitrião começa.

const SLOT_SIZE := Vector2(270, 410)

var _slots: Array[LobbySlot] = []
var _pads_label: Label
var _room_label: Label
## Último valor de move.x de cada fonte, para detetar o toque em esquerda/direita.
var _last_x := {}
var _last_y := {}


func _ready() -> void:
	theme = UiStyle.theme()
	UiStyle.background(self)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var top := Control.new()
	top.custom_minimum_size.y = 18
	root.add_child(top)
	root.add_child(UiStyle.label(
		"Tutorial: quem vai aprender?" if GameState.mode == GameState.Mode.TUTORIAL else "Quem vai cozinhar?", 52, UiStyle.TEXT, 10))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	root.add_child(row)
	for i in PlayerRegistry.MAX_PLAYERS:
		var slot := LobbySlot.new()
		slot.index = i
		slot.custom_minimum_size = SLOT_SIZE
		row.add_child(slot)
		_slots.append(slot)

	# Legendas com os botões desenhados como no comando (ou teclado).
	var help := PromptBar.new([[&"pick", "Entrar"], [&"move", "Chef (⇆) e papel (⇅)"], [&"throw", "Perfil"], [&"dash", "Sair / voltar"], [&"pause", "Começar"]])
	help.custom_minimum_size = Vector2(1280, 44)
	root.add_child(help)
	var help2 := UiStyle.label("Sem ninguém no lobby, Sair / voltar volta ao menu principal.", 18, UiStyle.MUTED, 4)
	root.add_child(help2)
	_pads_label = UiStyle.label("", 18, UiStyle.MUTED, 6)
	root.add_child(_pads_label)
	_room_label = UiStyle.label(_room_text(), 22, UiStyle.GOLD, 6)
	root.add_child(_room_label)

	# Primeira leitura sem efeito, para a tecla que abriu o lobby não contar como "entrar".
	for source in DeviceManager.all_sources():
		source.poll()
		_last_x[source] = source.move.x
		_last_y[source] = source.move.y
	PlayerRegistry.players_changed.connect(_refresh)
	Net.upnp_changed.connect(func(): _room_label.text = _room_text())
	DeviceManager.sources_changed.connect(_refresh)
	_refresh()
	Sfx.music_on()


func _process(_delta: float) -> void:
	for source in DeviceManager.all_sources():
		source.poll()
		var joined := PlayerRegistry.has_source(source)
		var x := source.move.x
		var last: float = _last_x.get(source, 0.0)
		_last_x[source] = x
		var y := source.move.y
		var last_y: float = _last_y.get(source, 0.0)
		_last_y[source] = y
		if joined and absf(y) > 0.5 and absf(last_y) <= 0.5:
			PlayerRegistry.cycle_role(source, 1 if y > 0.0 else -1)
			Sfx.play("ui_move")
		if joined and absf(x) > 0.5 and absf(last) <= 0.5:
			var dir := 1 if x > 0.0 else -1
			PlayerRegistry.cycle_character(source, dir)
			for slot in _slots:
				var p := PlayerRegistry.get_player(slot.index)
				if p and p["source"] == source:
					slot.bump(dir)
			Sfx.play("ui_move")
		if joined and source.just_pressed(&"throw"):
			PlayerRegistry.cycle_profile(source, 1)
			Sfx.play("ui_move")
		if not joined and source.just_pressed(&"pick"):
			PlayerRegistry.join(source)
			Sfx.play("ui_confirm")
		elif joined and source.just_pressed(&"dash"):
			PlayerRegistry.leave(source)
			Sfx.play("ui_back")
		elif not joined and source.just_pressed(&"dash"):
			# A bola volta atrás: sem ninguém no lobby (ou num PC que só está a ver), volta ao menu.
			if PlayerRegistry.players.is_empty() or (Net.online and not _has_local_player()):
				Net.leave()
				Sfx.play("ui_back")
				Transition.go("res://scenes/main_menu.tscn")
				return
		elif source.just_pressed(&"pause"):
			# Start só serve para começar.
			if PlayerRegistry.players.is_empty() or (Net.is_client() and not joined):
				Sfx.play("ui_back")
			elif GameState.mode == GameState.Mode.TUTORIAL and not Net.online:
				# O tutorial é sempre no primeiro restaurante.
				Sfx.play("ui_confirm")
				GameState.level = 0
				Transition.go("res://scenes/level.tscn")
			elif Net.online and Net.is_host():
				Sfx.play("ui_confirm")
				Net.open_level_select.rpc()
			elif not Net.online:
				Sfx.play("ui_confirm")
				Transition.go("res://scenes/level_select.tscn")
			return


func _has_local_player() -> bool:
	for p in PlayerRegistry.players:
		if not p["source"] is RemoteSource:
			return true
	return false


func _room_text() -> String:
	if not Net.online:
		return ""
	if Net.is_host():
		var lan := "Na mesma rede: %s" % " ou ".join(Net.local_addresses())
		match Net.upnp_state:
			"working":
				return "A abrir a sala na internet (UPnP)...   %s" % lan
			"ok":
				if Net.public_ip != "":
					return "Código da sala: %s   ·   %s" % [Net.encode_room(Net.public_ip), lan]
		return "O router não abriu a porta (UPnP). Abre a porta UDP %d à mão ou usa o Tailscale.   %s" % [Net.PORT, lan]
	return "Ligado à sala. Só o host pode começar."


func _refresh() -> void:
	for slot in _slots:
		slot.set_player(PlayerRegistry.get_player(slot.index))
	var pads := DeviceManager.connected_pad_names()
	_pads_label.text = "Comandos ligados: " + (", ".join(pads) if pads else "nenhum")
