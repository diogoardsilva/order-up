extends Node
## Comandos personalizáveis: que botão do comando e que tecla de cada esquema de
## teclado faz cada ação (pegar, usar, correr...). Os gatilhos L2/R2 contam como
## botões (ver TRIGGER_L e TRIGGER_R). Guarda-se em user://save.cfg, secção "controls".

signal changed

const SAVE_PATH := "user://save.cfg"
## Códigos "de botão" para os gatilhos, que no Godot são eixos.
const TRIGGER_L := 100
const TRIGGER_R := 101
const TRIGGER_PRESS := 0.55

## Ações que se podem trocar, pela ordem do menu, com o nome em português.
const ACTION_NAMES := {
	&"pick": "Pegar / pousar",
	&"use": "Usar (cortar, lavar, cobrar)",
	&"dash": "Correr",
	&"throw": "Atirar ingrediente",
	&"emote": "Acenar",
	&"pause": "Pausa",
}

const DEFAULT_PAD := {
	&"pick": JOY_BUTTON_A, &"use": JOY_BUTTON_X, &"dash": JOY_BUTTON_B,
	&"throw": JOY_BUTTON_Y, &"emote": JOY_BUTTON_LEFT_SHOULDER, &"pause": JOY_BUTTON_START,
}
const DEFAULT_KEYS := [
	{&"pick": KEY_SPACE, &"use": KEY_E, &"dash": KEY_SHIFT, &"throw": KEY_Q, &"emote": KEY_R, &"pause": KEY_ESCAPE},
	{&"pick": KEY_ENTER, &"use": KEY_PERIOD, &"dash": KEY_SLASH, &"throw": KEY_COMMA, &"emote": KEY_M, &"pause": KEY_BACKSPACE},
]

## Nome de cada botão no DualShock/DualSense e no Xbox (para as legendas).
const PS_NAMES := {
	JOY_BUTTON_A: "cross", JOY_BUTTON_B: "circle", JOY_BUTTON_X: "square", JOY_BUTTON_Y: "triangle",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", TRIGGER_L: "L2", TRIGGER_R: "R2",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_START: "OPTIONS", JOY_BUTTON_BACK: "SHARE",
	JOY_BUTTON_TOUCHPAD: "PAD",
}
const XBOX_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", TRIGGER_L: "LT", TRIGGER_R: "RT",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS", JOY_BUTTON_START: "MENU", JOY_BUTTON_BACK: "VIEW",
}
## Nome em texto (para o menu) dos símbolos do DualShock.
const PS_TEXT := {"cross": "Cruz", "circle": "Círculo", "square": "Quadrado", "triangle": "Triângulo"}

var pad := DEFAULT_PAD.duplicate()
var keys: Array[Dictionary] = [DEFAULT_KEYS[0].duplicate(), DEFAULT_KEYS[1].duplicate()]


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for action in ACTION_NAMES:
		pad[action] = int(cfg.get_value("controls", "pad_" + action, pad[action]))
		for i in keys.size():
			keys[i][action] = int(cfg.get_value("controls", "kb%d_%s" % [i, action], keys[i][action]))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	for action in ACTION_NAMES:
		cfg.set_value("controls", "pad_" + action, pad[action])
		for i in keys.size():
			cfg.set_value("controls", "kb%d_%s" % [i, action], keys[i][action])
	cfg.save(SAVE_PATH)
	changed.emit()


## O comando `device` tem o botão (ou gatilho) `code` carregado?
func pad_down(device: int, code: int) -> bool:
	if code == TRIGGER_L:
		return Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > TRIGGER_PRESS
	if code == TRIGGER_R:
		return Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > TRIGGER_PRESS
	return Input.is_joy_button_pressed(device, code as JoyButton)


func pad_name(code: int, playstation: bool) -> String:
	var names := PS_NAMES if playstation else XBOX_NAMES
	if names.has(code):
		return names[code]
	return "B%d" % code


## Muda o botão do comando de uma ação. Se outra ação já o usava, trocam.
func set_pad(action: StringName, code: int) -> void:
	for other in pad:
		if other != action and pad[other] == code:
			pad[other] = pad[action]
	pad[action] = code
	save()


func set_key(layout: int, action: StringName, keycode: int) -> void:
	var map: Dictionary = keys[layout]
	for other in map:
		if other != action and map[other] == keycode:
			map[other] = map[action]
	map[action] = keycode
	save()


func reset() -> void:
	pad = DEFAULT_PAD.duplicate()
	keys = [DEFAULT_KEYS[0].duplicate(), DEFAULT_KEYS[1].duplicate()]
	save()
