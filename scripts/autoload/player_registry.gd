extends Node
## Jogadores da sessão (1-4), locais ou noutros PCs. Online, só o anfitrião
## altera a lista; os outros pedem para entrar/sair e recebem a lista dele.

signal players_changed

const MAX_PLAYERS := 4
const COLORS: Array[Color] = [Color("e8574d"), Color("4d9be8"), Color("f2c94c"), Color("6fcf6a")]

## Cada entrada: {"slot", "source", "color", "peer", "source_id", "label"}
var players: Array[Dictionary] = []


func join(source: InputSource) -> void:
	if Net.is_client():
		_request_join.rpc_id(1, source.get_id(), source.get_label())
	else:
		_add(source, Net.my_id(), source.get_id(), source.get_label())


func leave(source: InputSource) -> void:
	if Net.is_client():
		_request_leave.rpc_id(1, source.get_id())
	else:
		_remove(func(p): return p["source"] == source)


func has_source(source: InputSource) -> bool:
	return players.any(func(p): return p["source"] == source)


func get_player(slot: int) -> Dictionary:
	for p in players:
		if p["slot"] == slot:
			return p
	return {}


func remove_peer(peer: int) -> void:
	_remove(func(p): return p["peer"] == peer)


func clear() -> void:
	players.clear()
	players_changed.emit()


## Envia a lista atual a um PC que acabou de se ligar.
func send_to(peer: int) -> void:
	_sync.rpc_id(peer, _export())


func _add(source: InputSource, peer: int, source_id: String, label: String) -> void:
	if players.size() >= MAX_PLAYERS or players.any(func(p): return p["peer"] == peer and p["source_id"] == source_id):
		return
	var slot := 0
	while get_player(slot):
		slot += 1
	players.append({"slot": slot, "source": source, "color": COLORS[slot],
		"peer": peer, "source_id": source_id, "label": label})
	players.sort_custom(func(a, b): return a["slot"] < b["slot"])
	_changed()


func _remove(filter: Callable) -> void:
	var before := players.size()
	players = players.filter(func(p): return not filter.call(p))
	if players.size() != before:
		_changed()


func _changed() -> void:
	players_changed.emit()
	if Net.online and multiplayer.is_server():
		_sync.rpc(_export())


func _export() -> Array:
	return players.map(func(p): return [p["slot"], p["peer"], p["source_id"], p["label"]])


@rpc("any_peer", "call_remote", "reliable")
func _request_join(source_id: String, label: String) -> void:
	if multiplayer.is_server() and not Net.in_game:
		_add(RemoteSource.new(label), multiplayer.get_remote_sender_id(), source_id, label)


@rpc("any_peer", "call_remote", "reliable")
func _request_leave(source_id: String) -> void:
	if multiplayer.is_server():
		var peer := multiplayer.get_remote_sender_id()
		_remove(func(p): return p["peer"] == peer and p["source_id"] == source_id)


@rpc("authority", "call_remote", "reliable")
func _sync(list: Array) -> void:
	players.clear()
	for e in list:
		var source: InputSource = DeviceManager.find(e[2]) if e[1] == Net.my_id() else null
		if source == null:
			source = RemoteSource.new(e[3])
		players.append({"slot": e[0], "source": source, "color": COLORS[e[0]],
			"peer": e[1], "source_id": e[2], "label": e[3]})
	players_changed.emit()
