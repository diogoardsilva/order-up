extends Node
## Ligação online. O anfitrião (peer 1) é dono da cozinha e dos pedidos; cada
## PC mexe os seus próprios chefs e pede as interações ao anfitrião.
## Pela internet: o anfitrião pede ao router (UPnP) para abrir a porta 7777 e
## mostra um código de sala, que é o IP público dele em letras. Os amigos
## escrevem o código (ou um IP) para entrar. Sem UPnP no router, abre-se a
## porta à mão ou usa-se o Tailscale como antes.

const PORT := 7777
const MAX_CLIENTS := 3

## Letras do código de sala (sem 0/O, 1/I/L, para não haver enganos).
const CODE_ALPHABET := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"

signal upnp_changed

var online := false
var in_game := false
## Estado do UPnP: "", "working", "ok" ou "failed".
var upnp_state := ""
var public_ip := ""
var _upnp: UPNP
var _upnp_thread: Thread


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
		_start_upnp()
	return err


## Entra numa sala: aceita um código de sala ou um IP.
func join(code_or_address: String) -> Error:
	var address := code_or_address.strip_edges()
	var decoded := decode_room(address)
	if decoded != "":
		address = decoded
	if address.is_empty():
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		online = true
		PlayerRegistry.clear()
	return err


func leave() -> void:
	_stop_upnp()
	if online:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	in_game = false
	PlayerRegistry.clear()


# --- UPnP e código de sala ------------------------------------------------------

func _start_upnp() -> void:
	if _upnp_thread != null:
		return
	upnp_state = "working"
	public_ip = ""
	upnp_changed.emit()
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_open)


## Corre numa thread: procurar o router demora uns segundos.
func _upnp_open() -> void:
	var upnp := UPNP.new()
	var ok := upnp.discover(2000, 2) == UPNP.UPNP_RESULT_SUCCESS \
		and upnp.get_gateway() != null and upnp.get_gateway().is_valid_gateway()
	if ok:
		ok = upnp.add_port_mapping(PORT, PORT, "Order Up", "UDP", 0) == UPNP.UPNP_RESULT_SUCCESS
	var ip := upnp.query_external_address() if upnp.get_gateway() != null else ""
	_upnp_done.call_deferred(upnp, ok, ip)


func _upnp_done(upnp: UPNP, ok: bool, ip: String) -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if not online:
		if ok:
			upnp.delete_port_mapping(PORT, "UDP")
		return
	_upnp = upnp if ok else null
	public_ip = ip if ip.count(".") == 3 else ""
	upnp_state = "ok" if ok else "failed"
	upnp_changed.emit()


func _stop_upnp() -> void:
	if _upnp:
		_upnp.delete_port_mapping(PORT, "UDP")
		_upnp = null
	upnp_state = ""
	public_ip = ""


func _exit_tree() -> void:
	_stop_upnp()
	if _upnp_thread:
		_upnp_thread.wait_to_finish()


## Código de sala para um IPv4: 7 letras, ex. "K7Q-9XMF".
static func encode_room(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var n := 0
	for p in parts:
		n = n * 256 + clampi(int(p), 0, 255)
	var code := ""
	for i in 7:
		code = CODE_ALPHABET[n % CODE_ALPHABET.length()] + code
		n /= CODE_ALPHABET.length()
	return code.substr(0, 3) + "-" + code.substr(3)


## O IP de um código de sala, ou "" se não for um código.
static func decode_room(code: String) -> String:
	var clean := code.to_upper().replace("-", "").replace(" ", "")
	if clean.length() != 7:
		return ""
	var n := 0
	for ch in clean:
		var v := CODE_ALPHABET.find(ch)
		if v < 0:
			return ""
		n = n * CODE_ALPHABET.length() + v
	if n >= 1 << 32:
		return ""
	return "%d.%d.%d.%d" % [(n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255]


## IPs deste PC para partilhar com os amigos (IPv4, sem o 127.0.0.1).
func local_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			result.append(address)
	return result


## Todos vão para o ecrã de escolher o restaurante (o anfitrião escolhe).
@rpc("authority", "call_local", "reliable")
func open_level_select() -> void:
	Transition.go("res://scenes/level_select.tscn")


## O anfitrião mudou o restaurante selecionado.
signal level_choice_changed(index: int, helpers: Array, endless: bool, settings: Array)


@rpc("authority", "call_remote", "reliable")
func set_level_choice(index: int, helpers: Array, endless: bool, settings: Array) -> void:
	level_choice_changed.emit(index, helpers, endless, settings)


@rpc("authority", "call_local", "reliable")
func start_level(level: int, helpers: Array, endless: bool, settings: Array) -> void:
	in_game = true
	GameState.mode = GameState.Mode.PLAY
	GameState.endless = endless
	GameState.difficulty = settings[0]
	GameState.custom = settings[1].duplicate()
	GameState.level = level
	GameState.helpers = helpers.duplicate()
	Transition.go("res://scenes/level.tscn")


@rpc("authority", "call_local", "reliable")
func return_to_lobby() -> void:
	in_game = false
	Transition.go("res://scenes/lobby.tscn")


func _back_to_menu(message: String) -> void:
	leave()
	GameState.menu_message = message
	Transition.go("res://scenes/main_menu.tscn")


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
	_back_to_menu("Não foi possível entrar na sala. Confirma o código (ou o IP); se o router do host não tiver UPnP, ele tem de abrir a porta UDP 7777.")


func _on_server_disconnected() -> void:
	_back_to_menu("A ligação ao anfitrião terminou.")
