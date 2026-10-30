extends Node
## Estado global entre cenas: o modo escolhido no menu e o progresso guardado.

enum Mode { PLAY, TUTORIAL }

const SAVE_PATH := "user://save.cfg"

var mode := Mode.PLAY
var tutorial_done := false
var last_ip := ""
## Mensagem a mostrar no menu (ex. ligação perdida).
var menu_message := ""


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		tutorial_done = cfg.get_value("progress", "tutorial_done", false)
		last_ip = cfg.get_value("net", "last_ip", "")


func mark_tutorial_done() -> void:
	tutorial_done = true
	_save("progress", "tutorial_done", true)


func remember_ip(ip: String) -> void:
	last_ip = ip
	_save("net", "last_ip", ip)


func _save(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value(section, key, value)
	cfg.save(SAVE_PATH)
