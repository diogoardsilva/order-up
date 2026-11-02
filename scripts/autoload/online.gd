extends Node
## Perfil online e amigos, guardados no Supabase do Diogo (ver
## /mnt/project-files/online/supabase-setup.sql). Cada perfil deste PC tem um
## código de amigo (6 letras) e um segredo que só este PC sabe. O jogo só chama
## funções (RPC) com a chave pública "anon": as tabelas estão fechadas.
## Enquanto o jogo está aberto, avisa a cada 30 s que o perfil ativo está
## online e, se for host, o código da sala para os amigos entrarem.

signal friends_changed
signal status_changed

const URL := "https://cbwkqshpblvvkxnohpfp.supabase.co"
const ANON_KEY := ""
const HEARTBEAT_EVERY := 30.0

var friends: Array = []
## Última mensagem para mostrar (erros e confirmações).
var message := ""
var busy := false
var _beat := HEARTBEAT_EVERY - 2.0


func enabled() -> bool:
	return URL != "" and ANON_KEY != ""


func _process(delta: float) -> void:
	if not enabled():
		return
	_beat += delta
	if _beat >= HEARTBEAT_EVERY:
		_beat = 0.0
		heartbeat()


## Dados online do perfil (vazio se ainda não foi criado).
func account(index := Profiles.active) -> Dictionary:
	if index < 0 or index >= Profiles.profiles.size():
		return {}
	return Profiles.profiles[index].get("online", {})


func friend_code(index := Profiles.active) -> String:
	return account(index).get("code", "")


## Cria o perfil online (se ainda não existir) e devolve true quando há código.
func ensure_account(index := Profiles.active) -> bool:
	if not enabled():
		message = "Os amigos online ainda não estão ligados nesta versão."
		status_changed.emit()
		return false
	if friend_code(index) != "":
		return true
	var result = await _rpc("create_profile", {"p_name": Profiles.profile_name(index)})
	if result is Array and not result.is_empty():
		Profiles.profiles[index]["online"] = {"code": result[0]["friend_code"], "secret": result[0]["secret"]}
		Profiles.save()
		status_changed.emit()
		return true
	return false


func heartbeat() -> void:
	if not enabled() or friend_code() == "":
		return
	var room := ""
	if Net.online and Net.is_host() and Net.public_ip != "":
		room = Net.encode_room(Net.public_ip)
	var status := "A jogar" if Net.in_game or get_tree().current_scene and get_tree().current_scene.scene_file_path.ends_with("level.tscn") else "No menu"
	if room != "":
		status = "Sala aberta"
	await _rpc("heartbeat", {"p_secret": account()["secret"], "p_room": room, "p_status": status})


func add_friend(code: String) -> void:
	if not await ensure_account():
		return
	var clean := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	var result = await _rpc("add_friend", {"p_secret": account()["secret"], "p_code": clean})
	if result is String:
		message = "%s é agora teu amigo." % result
		Profiles.add_all("friend", 1)
		await refresh_friends()
	status_changed.emit()


func remove_friend(code: String) -> void:
	if friend_code() == "":
		return
	await _rpc("remove_friend", {"p_secret": account()["secret"], "p_code": code})
	await refresh_friends()


func refresh_friends() -> void:
	if not enabled() or friend_code() == "":
		friends = []
		friends_changed.emit()
		return
	var result = await _rpc("list_friends", {"p_secret": account()["secret"]})
	if result is Array:
		friends = result
	friends_changed.emit()


func rename(index: int) -> void:
	if enabled() and friend_code(index) != "":
		await _rpc("rename_profile", {"p_secret": account(index)["secret"], "p_name": Profiles.profile_name(index)})


## Entra na sala de um amigo (o código que ele publicou).
func join_room(room: String) -> bool:
	if room.is_empty() or Net.join(room) != OK:
		message = "Não deu para entrar na sala."
		status_changed.emit()
		return false
	message = "A entrar na sala %s..." % room
	status_changed.emit()
	multiplayer.connected_to_server.connect(func():
		GameState.mode = GameState.Mode.PLAY
		Transition.go("res://scenes/lobby.tscn"), CONNECT_ONE_SHOT)
	return true


## Chama uma função do Supabase. Devolve o resultado (JSON) ou null se falhar.
func _rpc(fn: String, body: Dictionary) -> Variant:
	busy = true
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	var headers := PackedStringArray(["apikey: " + ANON_KEY, "Authorization: Bearer " + ANON_KEY,
		"Content-Type: application/json"])
	var err := http.request(URL + "/rest/v1/rpc/" + fn, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		busy = false
		message = "Sem ligação à internet."
		status_changed.emit()
		return null
	var res: Array = await http.request_completed
	http.queue_free()
	busy = false
	var code: int = res[1]
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	var data = JSON.parse_string(text) if not text.is_empty() else true
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		message = "Sem ligação ao servidor."
		status_changed.emit()
		return null
	if code >= 400:
		var why: String = data.get("message", "erro %d" % code) if data is Dictionary else "erro %d" % code
		message = {"código não existe": "Esse código de amigo não existe.", "esse és tu": "Esse é o teu próprio código."}.get(why, why)
		status_changed.emit()
		return null
	return data
