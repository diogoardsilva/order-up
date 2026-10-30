extends Node
## Lista de fontes de input disponíveis: dois esquemas de teclado e cada
## comando ligado. Comandos ligados/desligados a quente são detetados aqui.

signal sources_changed

var keyboard_sources: Array[InputSource] = [KeyboardSource.new(0), KeyboardSource.new(1)]
# Uma fonte por device id, mantida mesmo quando o comando se desliga, para o
# jogador recuperar o mesmo chef ao voltar a ligá-lo.
var _pads := {}


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for device in Input.get_connected_joypads():
		_pads[device] = GamepadSource.new(device)


func all_sources() -> Array[InputSource]:
	var result: Array[InputSource] = keyboard_sources.duplicate()
	for pad: GamepadSource in _pads.values():
		if pad.is_available():
			result.append(pad)
	return result


func connected_pad_names() -> PackedStringArray:
	var names := PackedStringArray()
	for device in Input.get_connected_joypads():
		names.append("#%d %s" % [device, Input.get_joy_name(device)])
	return names


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected and not _pads.has(device):
		_pads[device] = GamepadSource.new(device)
	sources_changed.emit()
