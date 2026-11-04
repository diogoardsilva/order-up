extends Node
## Jogadores da sessão (1-4), locais ou noutros PCs. Online, só o anfitrião
## altera a lista; os outros pedem para entrar/sair e recebem a lista dele.

signal players_changed

const MAX_PLAYERS := 4
const COLORS: Array[Color] = [Color("e8574d"), Color("4d9be8"), Color("f2c94c"), Color("6fcf6a")]

## Cada entrada: {"slot", "source", "color", "peer", "source_id", "label", "character", "role", "name", "look"}
## ("name" é o nome do perfil escolhido nesse PC, ou "Convidado"; "look" é o
## boneco desse perfil, ou {} para convidados). "character" -1 = o boneco do
## perfil; 0-5 = um dos bonecos predefinidos (CharacterLook.preset).
var players: Array[Dictionary] = []


func join(source: InputSource) -> void:
	var index := Profiles.for_source(source.get_id())
	var name := Profiles.profile_name(index)
	var look := Profiles.look(index) if index >= 0 else {}
	if Net.is_client():
		_request_join.rpc_id(1, source.get_id(), source.get_label(), name, look)
	else:
		_add(source, Net.my_id(), source.get_id(), source.get_label(), name, look)


## Troca o perfil de um jogador deste PC (dir = -1 ou +1).
func cycle_profile(source: InputSource, dir: int) -> void:
	var index := Profiles.cycle_source(source.get_id(), dir)
	var name := Profiles.profile_name(index)
	var look := Profiles.look(index) if index >= 0 else {}
	if Net.is_client():
		_request_name.rpc_id(1, source.get_id(), name, look)
	else:
		_set_name(func(p): return p["source"] == source, name, look)


## O boneco do perfil mudou (no menu): atualiza os jogadores deste PC que o usam.
func refresh_looks() -> void:
	for p in players:
		if p["peer"] == Net.my_id() and p["source"] is InputSource:
			var index: int = Profiles.by_source.get(p["source_id"], -2)
			if index >= 0:
				if Net.is_client():
					_request_name.rpc_id(1, p["source_id"], Profiles.profile_name(index), Profiles.look(index))
				else:
					_set_name(func(q): return q == p, Profiles.profile_name(index), Profiles.look(index))


func _set_name(filter: Callable, name: String, look: Dictionary) -> void:
	for p in players:
		if filter.call(p):
			p["name"] = name.left(16)
			p["look"] = CharacterLook.clean(look) if not look.is_empty() else {}
			if not look.is_empty():
				p["character"] = -1
			elif p["character"] < 0:
				p["character"] = p["slot"]
			_changed()


@rpc("any_peer", "call_remote", "reliable")
func _request_name(source_id: String, name: String, look: Dictionary) -> void:
	if multiplayer.is_server() and not Net.in_game:
		var peer := multiplayer.get_remote_sender_id()
		_set_name(func(p): return p["peer"] == peer and p["source_id"] == source_id, name, look)


## O boneco que um jogador está a usar.
func look_of(p: Dictionary) -> Dictionary:
	var look: Dictionary = p.get("look", {})
	if p.get("character", 0) < 0 and not look.is_empty():
		return look
	return CharacterLook.preset(maxi(p.get("character", 0), 0))


## Nome por baixo do boneco: o do perfil, ou o do boneco predefinido.
func look_name(p: Dictionary) -> String:
	if p.get("character", 0) < 0:
		return "O meu boneco"
	return CharacterLook.PRESET_NAMES[posmod(p.get("character", 0), CharacterLook.PRESET_NAMES.size())]


func leave(source: InputSource) -> void:
	Profiles.forget_source(source.get_id())
	if Net.is_client():
		_request_leave.rpc_id(1, source.get_id())
	else:
		_remove(func(p): return p["source"] == source)


## Muda o personagem de um jogador local (dir = -1 ou +1).
func cycle_character(source: InputSource, dir: int) -> void:
	if Net.is_client():
		_request_character.rpc_id(1, source.get_id(), dir)
	else:
		_cycle(func(p): return p["source"] == source, dir)


## Muda o papel de um jogador local (Livre, Cozinheiro, ... ver GameState.PLAYER_ROLES).
func cycle_role(source: InputSource, dir: int) -> void:
	if Net.is_client():
		_request_role.rpc_id(1, source.get_id(), dir)
	else:
		_cycle_role(func(p): return p["source"] == source, dir)


func _cycle_role(filter: Callable, dir: int) -> void:
	for p in players:
		if filter.call(p):
			p["role"] = posmod(p.get("role", 0) + dir, GameState.PLAYER_ROLES.size())
			_changed()


@rpc("any_peer", "call_remote", "reliable")
func _request_role(source_id: String, dir: int) -> void:
	if multiplayer.is_server() and not Net.in_game:
		var peer := multiplayer.get_remote_sender_id()
		_cycle_role(func(p): return p["peer"] == peer and p["source_id"] == source_id, dir)


func _cycle(filter: Callable, dir: int) -> void:
	for p in players:
		if filter.call(p):
			# Com perfil: -1 (o boneco do perfil) e os 6 predefinidos.
			var first := -1 if not (p.get("look", {}) as Dictionary).is_empty() else 0
			var n := CharacterLook.PRESET_NAMES.size() - first
			p["character"] = posmod(p["character"] - first + dir, n) + first
			_changed()


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
	Profiles.by_source.clear()
	players_changed.emit()


## Envia a lista atual a um PC que acabou de se ligar.
func send_to(peer: int) -> void:
	_sync.rpc_id(peer, _export())


func _add(source: InputSource, peer: int, source_id: String, label: String, name := "", look := {}) -> void:
	if players.size() >= MAX_PLAYERS or players.any(func(p): return p["peer"] == peer and p["source_id"] == source_id):
		return
	var slot := 0
	while get_player(slot):
		slot += 1
	# Cada jogador começa com um personagem diferente.
	var character := slot
	while players.any(func(p): return p["character"] == character):
		character = (character + 1) % CharacterLook.PRESET_NAMES.size()
	if not look.is_empty():
		character = -1
	players.append({"slot": slot, "source": source, "color": COLORS[slot],
		"peer": peer, "source_id": source_id, "label": label, "character": character, "role": 0,
		"name": name.left(16) if name != "" else "Jogador %d" % (slot + 1),
		"look": CharacterLook.clean(look) if not look.is_empty() else {}})
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
	return players.map(func(p): return [p["slot"], p["peer"], p["source_id"], p["label"], p["character"], p.get("role", 0), p.get("name", ""), p.get("look", {})])


@rpc("any_peer", "call_remote", "reliable")
func _request_join(source_id: String, label: String, name: String, look: Dictionary) -> void:
	if multiplayer.is_server() and not Net.in_game:
		_add(RemoteSource.new(label), multiplayer.get_remote_sender_id(), source_id, label, name, look)


@rpc("any_peer", "call_remote", "reliable")
func _request_character(source_id: String, dir: int) -> void:
	if multiplayer.is_server() and not Net.in_game:
		var peer := multiplayer.get_remote_sender_id()
		_cycle(func(p): return p["peer"] == peer and p["source_id"] == source_id, dir)


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
			"peer": e[1], "source_id": e[2], "label": e[3], "character": e[4], "role": e[5] if e.size() > 5 else 0, "name": e[6] if e.size() > 6 else "",
			"look": e[7] if e.size() > 7 and e[7] is Dictionary else {}})
	players_changed.emit()
