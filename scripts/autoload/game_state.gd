extends Node
## Estado global entre cenas: o modo escolhido no menu e o progresso guardado.

enum Mode { PLAY, TUTORIAL }

const SAVE_PATH := "user://save.cfg"

var mode := Mode.PLAY
var tutorial_done := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		tutorial_done = cfg.get_value("progress", "tutorial_done", false)


func mark_tutorial_done() -> void:
	tutorial_done = true
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("progress", "tutorial_done", true)
	cfg.save(SAVE_PATH)
