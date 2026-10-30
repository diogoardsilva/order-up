class_name InputSource
extends RefCounted
## Fonte de input abstrata. O Chef só fala com isto, nunca diretamente com o
## teclado ou o comando, para que local e online (M2) usem o mesmo código.

const ACTIONS: Array[StringName] = [&"pick", &"use", &"dash", &"throw", &"emote", &"pause"]

var move := Vector2.ZERO
var _down := {}
var _prev := {}


## Chamar uma vez por frame, só pelo dono atual da fonte (lobby ou chef).
func poll() -> void:
	_prev = _down.duplicate()
	move = _read_move() if is_available() else Vector2.ZERO
	for action in ACTIONS:
		_down[action] = is_available() and _read_action(action)


func is_down(action: StringName) -> bool:
	return _down.get(action, false)


func just_pressed(action: StringName) -> bool:
	return _down.get(action, false) and not _prev.get(action, false)


func get_id() -> String:
	return ""


func get_label() -> String:
	return ""


## Nome do botão/tecla para mostrar no ecrã.
func prompt(_action: StringName) -> String:
	return "?"


func is_available() -> bool:
	return true


func _read_move() -> Vector2:
	return Vector2.ZERO


func _read_action(_action: StringName) -> bool:
	return false
