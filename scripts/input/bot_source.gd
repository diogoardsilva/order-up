class_name BotSource
extends InputSource
## "Comando" do ajudante: em vez de ler teclas, pergunta à HelperAI o que fazer.

var brain: HelperAI


func _init(p_brain: HelperAI) -> void:
	brain = p_brain


func poll() -> void:
	_prev = _down.duplicate()
	brain.think(chef_delta())
	move = brain.move
	for action in ACTIONS:
		_down[action] = brain.buttons.get(action, false)


func chef_delta() -> float:
	return 1.0 / maxf(1.0, Engine.physics_ticks_per_second)


func get_label() -> String:
	return "Ajudante"
