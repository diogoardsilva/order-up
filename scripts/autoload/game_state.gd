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
]
const MAX_HELPERS := 2

const SAVE_PATH := "user://save.cfg"

var mode := Mode.PLAY
## Restaurante escolhido (índice em Levels.ALL).
var level := 0
## Opção escolhida para cada ajudante (índice em HELPER_PRESETS).
var helpers: Array = [1, 0]
var tutorial_done := false
var last_ip := ""
## Mensagem a mostrar no menu (ex. ligação perdida).
var menu_message := ""
var fullscreen := true
## Volumes de 0 a 1.
var music_volume := 0.5
var sfx_volume := 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		tutorial_done = cfg.get_value("progress", "tutorial_done", false)
		last_ip = cfg.get_value("net", "last_ip", "")
		fullscreen = cfg.get_value("options", "fullscreen", true)
		music_volume = cfg.get_value("options", "music_volume", 0.5)
		sfx_volume = cfg.get_value("options", "sfx_volume", 0.8)
		var saved: Variant = cfg.get_value("progress", "helpers", helpers)
		if saved is Array and saved.size() == MAX_HELPERS:
			helpers = saved.map(func(h): return clampi(int(h), 0, HELPER_PRESETS.size() - 1))
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
	if not fullscreen:
		var screen := DisplayServer.screen_get_size()
		var size := Vector2i(1280, 720)
		if screen.x >= 1920 and screen.y >= 1080:
			size = Vector2i(1600, 900)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position((screen - size) / 2)


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))


## Melhor número de estrelas num restaurante.
func best_stars(level_id: String) -> int:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return cfg.get_value("stars", level_id, 0)


func save_stars(level_id: String, stars: int) -> void:
	if stars > best_stars(level_id):
		_save("stars", level_id, stars)


func mark_tutorial_done() -> void:
	tutorial_done = true
	_save("progress", "tutorial_done", true)


func set_helpers(value: Array) -> void:
	helpers = value.duplicate()
	_save("progress", "helpers", helpers)


func remember_ip(ip: String) -> void:
	last_ip = ip
	_save("net", "last_ip", ip)


func _save(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value(section, key, value)
	cfg.save(SAVE_PATH)
