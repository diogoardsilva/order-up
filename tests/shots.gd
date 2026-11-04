extends Node
## Capturas para mostrar o progresso (corre na CI com xvfb):
## godot res://tests/shots.tscn -> grava PNGs em user://shots ou em $SHOTS_DIR.

var _dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dir = OS.get_environment("SHOTS_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir().path_join("shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	GameState.tutorial_done = true
	GameState.booted = true
	GameState.welcome_done = true
	# A raiz ainda está a montar os filhos: espera um frame antes de abrir ecrãs.
	_run.call_deferred()


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _open(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	get_tree().root.add_child(scene)
	return scene


func _run() -> void:
	await get_tree().process_frame
	# Um nível já com estrelas, para se ver a fila de níveis aberta.
	GameState.save_stars(Levels.stage_id(1, 0), 3)
	GameState.save_stars(Levels.stage_id(1, 1), 2)
	var s := _open("res://scenes/main_menu.tscn")
	await _wait(3.0)
	await _shot("01-menu")
	s.queue_free()

	var keyboards := DeviceManager.all_sources().filter(func(x): return x is KeyboardSource)
	for k in keyboards:
		PlayerRegistry.join(k)
	s = _open("res://scenes/lobby.tscn")
	await _wait(1.5)
	await _shot("02-lobby")
	s.queue_free()

	GameState.level = 1
	GameState.stage = 6
	GameState.endless = false
	s = _open("res://scenes/level_select.tscn")
	await _wait(1.5)
	await _shot("03-escolher-nivel")
	s.queue_free()

	GameState.level = 2
	GameState.stage = 9
	GameState.mode = GameState.Mode.PLAY
	var level: Node = _open("res://scenes/level.tscn")
	await _wait(9.0)
	await _shot("04-sushi-matsuri")
	# Doses duplas e molhos de ingredientes.
	var kitchen: Kitchen = level._kitchen
	var stoves := kitchen.stations.values().filter(func(st): return st is StoveStation)
	var pot: Item = stoves[0].item if stoves[0].item else Item.cookware("pot")
	pot.empty_cookware()
	for id in ["noodles", "egg", "noodles", "egg"]:
		pot.cook_add(id)
	pot.cook_tick(100.0)
	stoves[0].item = pot
	var boards := kitchen.stations.values().filter(func(st): return st is BoardStation)
	var shrimp := Item.ingredient("shrimp")
	shrimp.count = 4
	boards[0].item = shrimp
	if not kitchen.chefs.is_empty():
		var salmon := Item.ingredient("salmon")
		salmon.count = 2
		kitchen.chefs[0].held = salmon
	await _wait(0.5)
	await _shot("05-doses-e-molhos")
	level._pause_menu.open()
	await _wait(0.8)
	await _shot("06-pausa")
	level._pause_menu.close()
	level._orders.score = 320
	level._time_left = 0.0
	await _wait(4.0)
	await _shot("07-fim-do-nivel")
	level.queue_free()

	# Ecrã de atualizações e boas-vindas da primeira vez.
	get_tree().paused = false
	var menu := _open("res://scenes/main_menu.tscn")
	var boot: Node = load("res://scripts/boot_screen.gd").new()
	menu.add_child(boot)
	await _wait(0.6)
	boot.preview("downloading", 0.62)
	await _wait(0.2)
	await _shot("08-atualizar")
	boot.queue_free()
	var welcome: Node = load("res://scripts/welcome_flow.gd").new()
	menu.add_child(welcome)
	await _wait(1.0)
	await _shot("09-boas-vindas")
	welcome._open_account()
	await _wait(0.6)
	await _shot("10-conta")
	welcome._friends.closed.emit()
	await _wait(0.6)
	await _shot("11-boneco")
	welcome.queue_free()
	menu._show_changelog()
	await _wait(0.6)
	await _shot("12-novidades")
	for c in menu.get_children():
		if c.has_signal("closed") and c.get_script() == load("res://scripts/changelog_menu.gd"):
			c.closed.emit()
	await _wait(0.3)
	menu._go_page(menu._online_box)
	menu._show_join()
	await _wait(0.8)
	await _shot("13-entrar-sala")
	# Um salão pequeno (nível 1) para comparar.
	menu.queue_free()
	GameState.level = 0
	GameState.stage = 0
	var small: Node = _open("res://scenes/level.tscn")
	await _wait(9.0)
	await _shot("14-nivel-1")
	small.queue_free()
	print("SHOTS DONE")
	get_tree().quit()
