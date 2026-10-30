class_name RemoteSource
extends InputSource
## Jogador que está noutro PC. Não lê input aqui: o chef dele é mexido pela rede.

var label: String


func _init(p_label: String) -> void:
	label = p_label


func get_label() -> String:
	return label + " (online)"
