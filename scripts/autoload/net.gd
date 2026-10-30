extends Node
## Ligação online. O anfitrião (peer 1) é dono da cozinha e dos pedidos; cada
## PC mexe os seus próprios chefs e pede as interações ao anfitrião. Para
## jogar pela internet sem abrir portas no router, usem o Tailscale e o IP
## 100.x.x.x do anfitrião.

const PORT := 7777
const MAX_CLIENTS := 3

var online := false
var in_game := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_host() -> bool:
	return not online or multiplayer.is_server()


func is_client() -> bool:
	return online and not multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if online else 1


func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		online = true
		PlayerRegistry.clear()
	return err


func join(address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		online = true
		PlayerRegistry.clear()
	return err


func leave() -> void:
	if online:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	in_game = false
	PlayerRegistry.clear()


## IPs deste PC para partilhar com os amigos (IPv4, sem o 127.0.0.1).
func local_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			result.append(address)
	return result


@rpc("authority", "call_local", "reliable")
func start_level() -> void:
	in_game = true
	GameState.mode = GameState.Mode.PLAY
	get_tree().change_scene_to_file("res://scenes/level.tscn")


@rpc("authority", "call_local", "reliable")
func return_to_lobby() -> void:
	in_game = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _back_to_menu(message: String) -> void:
	leave()
	GameState.menu_message = message
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_peer_connected(peer: int) -> void:
	if not multiplayer.is_server():
		return
	if in_game:
		# Por agora não se entra a meio de uma ronda.
		multiplayer.multiplayer_peer.disconnect_peer(peer)
		return
	PlayerRegistry.send_to(peer)


func _on_peer_disconnected(peer: int) -> void:
	if multiplayer.is_server():
		PlayerRegistry.remove_peer(peer)


func _on_connection_failed() -> void:
	_back_to_menu("Não foi possível ligar ao anfitrião. Confirma o IP e a firewall.")


func _on_server_disconnected() -> void:
	_back_to_menu("A ligação ao anfitrião terminou.")
