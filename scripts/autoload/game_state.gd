extends Node
## Estado global entre cenas: o modo escolhido no menu, o progresso e as
## opções guardadas (ecrã inteiro e volumes). F11 ou Alt+Enter troca o ecrã inteiro.

enum Mode { PLAY, TUTORIAL }
## Ajudantes controlados pelo jogo (até 2). Cada opção: [nome, papel, zona, descrição],
## com o papel e a zona de HelperAI (papel -1 = sem ajudante).
const HELPER_PRESETS: Array = [
	["Nenhum", -1, 0, "Sem ajudante neste lugar."],
	["Empregado de mesa", 0, 0, "Anota pedidos, leva os pratos do passe às mesas, cobra e lava a loiça."],
	["Host (anota e cobra)", 2, 0, "Recebe os clientes: anota os pedidos e cobra na caixa. Não leva pratos."],
	["Corredor (passe > mesas)", 3, 0, "Leva os pratos prontos do passe às mesas e os sujos para o lava-loiça."],
	["Cozinheiro (zona de cima)", 1, 1, "Cozinha só na zona de cima e deixa os pratos no passe de cima."],
	["Cozinheiro (zona de baixo)", 1, 2, "Cozinha só na zona de baixo e deixa os pratos no passe de baixo."],
	["Cozinheiro (cozinha toda)", 1, 0, "Cozinha onde estiver livre e deixa os pratos no passe."],
	["Ajudante de cozinha", 4, 0, "Corta os ingredientes que vão fazer falta e deixa-os nas bancadas, e lava a loiça."],
	["Barman", 5, 0, "Tira as bebidas no bar e leva-as às mesas. Quando não há bebidas, ajuda a levar pratos."],
]
## Papéis que um jogador pode escolher no lobby: [nome, descrição]. O papel
## diz onde começa e o que os ajudantes deixam para ele.
const PLAYER_ROLES: Array = [
	["Livre", "Faz um bocadinho de tudo."],
	["Cozinheiro", "Cozinha os pratos."],
	["Ajudante de cozinha", "Corta ingredientes e lava a loiça."],
	["Empregado de mesa", "Anota, leva os pratos e cobra."],
	["Host", "Recebe os clientes e cobra."],
	["Barman", "Tira as bebidas e leva-as às mesas."],
]
const MAX_HELPERS := 8

## Dificuldade: [nome, paciência dos clientes (x), intervalo entre grupos (x), minutos da ronda].
const DIFFICULTIES: Array = [
	["Fácil", 2.2, 1.35, 5],
	["Normal", 1.6, 1.0, 4],
	["Difícil", 1.0, 0.8, 3],
	["Personalizado", 0.0, 0.0, 0],
]
## Opções do modo personalizado.
const CUSTOM_PATIENCE: Array = [[0.75, "Pouca (x0.75)"], [1.0, "Normal (x1)"], [1.6, "Mais (x1.6)"], [2.2, "Muita (x2.2)"], [3.0, "Imensa (x3)"], [5.0, "Infinita quase (x5)"]]
const CUSTOM_SPAWN: Array = [[1.8, "Muito poucos"], [1.35, "Poucos"], [1.0, "Normal"], [0.8, "Muitos"], [0.6, "Imensos"]]
const CUSTOM_TIME: Array = [[2, "2 min"], [3, "3 min"], [4, "4 min"], [5, "5 min"], [8, "8 min"], [12, "12 min"]]

const SAVE_PATH := "user://save.cfg"

var mode := Mode.PLAY
## Restaurante escolhido (índice em Levels.ALL).
var level := 0
## Nível dentro do restaurante (0 a Levels.STAGES - 1).
var stage := 0
## Opção escolhida para cada ajudante (índice em HELPER_PRESETS).
var helpers: Array = [1, 0, 0, 0, 0, 0, 0, 0]
## Modo Casa Aberta: sem relógio, abre-se a porta quando se quer e só acaba
## quando se fecha.
var endless := false
var difficulty := 1
## Índices nas opções do modo personalizado: [paciência, clientes, tempo].
var custom := [2, 2, 2]
var tutorial_done := false
## Já viu as boas-vindas (conta e boneco) da primeira vez.
var welcome_done := false
## O ecrã de atualizações já apareceu nesta sessão.
var booted := false
var last_ip := ""
## Mensagem a mostrar no menu (ex. ligação perdida).
var menu_message := ""
var fullscreen := true
## Volumes de 0 a 1.
var music_volume := 0.5
var sfx_volume := 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Interpolação da física só para quem a pede (os chefs): o resto do jogo
	# mexe-se a cada frame e não precisa.
	get_tree().physics_interpolation = true
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		tutorial_done = cfg.get_value("progress", "tutorial_done", false)
		welcome_done = cfg.get_value("progress", "welcome_done", false)
		endless = cfg.get_value("progress", "endless", false)
		difficulty = clampi(cfg.get_value("progress", "difficulty", 1), 0, DIFFICULTIES.size() - 1)
		var c: Variant = cfg.get_value("progress", "custom", custom)
		if c is Array and c.size() == 3:
			custom = [clampi(c[0], 0, CUSTOM_PATIENCE.size() - 1), clampi(c[1], 0, CUSTOM_SPAWN.size() - 1), clampi(c[2], 0, CUSTOM_TIME.size() - 1)]
		level = clampi(cfg.get_value("progress", "level", 0), 0, 4)
		stage = clampi(cfg.get_value("progress", "stage", 0), 0, 4)
		last_ip = cfg.get_value("net", "last_ip", "")
		fullscreen = cfg.get_value("options", "fullscreen", true)
		music_volume = cfg.get_value("options", "music_volume", 0.5)
		sfx_volume = cfg.get_value("options", "sfx_volume", 0.8)
		var saved: Variant = cfg.get_value("progress", "helpers", helpers)
		if saved is Array and saved.size() >= 1:
			helpers = saved.map(func(h): return clampi(int(h), 0, HELPER_PRESETS.size() - 1)).slice(0, MAX_HELPERS)
	while helpers.size() < MAX_HELPERS:
		helpers.append(0)
	_apply_window()
	_apply_volumes()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and (key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed)):
		set_fullscreen(not fullscreen)
		get_viewport().set_input_as_handled()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	_save("options", "fullscreen", on)


func set_volumes(music: float, sfx: float) -> void:
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	_apply_volumes()
	_save("options", "music_volume", music_volume)
	_save("options", "sfx_volume", sfx_volume)


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	# O tamanho da janela (resolução) é escolhido em Screen.
	var screen_node := get_node_or_null("/root/Screen")
	if not fullscreen and screen_node:
		screen_node.apply_window_size()


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))


## Melhor número de estrelas num restaurante.
func best_stars(level_id: String) -> int:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	# As estrelas também ficam no perfil (e na conta online).
	return maxi(cfg.get_value("stars", level_id, 0), _profile_stat("lv_%s_stars_best" % level_id))


## Um nível está aberto se for o primeiro do restaurante ou se o anterior
## já tiver pelo menos uma estrela.
func stage_unlocked(index: int, p_stage: int) -> bool:
	return p_stage <= 0 or best_stars(Levels.stage_id(index, p_stage - 1)) > 0


## Estrelas ganhas num restaurante (soma dos níveis).
func restaurant_stars(index: int) -> int:
	var total := 0
	for k in Levels.STAGES:
		total += best_stars(Levels.stage_id(index, k))
	return total


## Lembra o último restaurante e nível escolhidos.
func choose(index: int, p_stage: int) -> void:
	level = index
	stage = p_stage
	_save("progress", "level", index)
	_save("progress", "stage", p_stage)


func save_stars(level_id: String, stars: int) -> void:
	if stars > best_stars(level_id):
		_save("stars", level_id, stars)


func mark_welcome_done() -> void:
	welcome_done = true
	_save("progress", "welcome_done", true)


func mark_tutorial_done() -> void:
	tutorial_done = true
	var profiles := get_node_or_null("/root/Profiles")
	if profiles:
		profiles.add_all("tutorial", 1)
	_save("progress", "tutorial_done", true)


func set_difficulty(index: int, p_custom: Array) -> void:
	difficulty = index
	custom = p_custom.duplicate()
	_save("progress", "difficulty", difficulty)
	_save("progress", "custom", custom)


## Valores da dificuldade atual: {"patience", "spawn", "minutes"}.
func difficulty_values() -> Dictionary:
	if difficulty == DIFFICULTIES.size() - 1:
		return {"patience": CUSTOM_PATIENCE[custom[0]][0], "spawn": CUSTOM_SPAWN[custom[1]][0], "minutes": CUSTOM_TIME[custom[2]][0]}
	var d: Array = DIFFICULTIES[difficulty]
	return {"patience": d[1], "spawn": d[2], "minutes": d[3]}


func set_endless(on: bool) -> void:
	endless = on
	_save("progress", "endless", on)


## Recorde do modo Casa Aberta num restaurante.
func best_endless(level_id: String) -> int:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return maxi(cfg.get_value("endless", level_id, 0), _profile_stat("lv_%s_endless_best" % level_id))


func save_endless(level_id: String, score: int) -> bool:
	if score <= best_endless(level_id):
		return false
	_save("endless", level_id, score)
	return true


func set_helpers(value: Array) -> void:
	helpers = value.duplicate()
	_save("progress", "helpers", helpers)


func remember_ip(ip: String) -> void:
	last_ip = ip
	_save("net", "last_ip", ip)


func _profile_stat(stat: String) -> int:
	var profiles := get_node_or_null("/root/Profiles")
	if profiles == null or profiles.active >= profiles.profiles.size():
		return 0
	return int(profiles.profiles[profiles.active]["stats"].get(stat, 0))


func _save(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value(section, key, value)
	cfg.save(SAVE_PATH)
