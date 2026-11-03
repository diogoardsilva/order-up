extends Node
## Contas online no Supabase do Diogo (ver supabase/migrations/*_accounts.sql).
## Cada perfil deste PC pode estar ligado a uma conta (utilizador + palavra-
## -passe). O progresso (estatísticas, conquistas e o boneco) fica na conta:
## entrando com o mesmo utilizador no Windows, no Mac ou no Linux tem-se tudo.
## Os dois lados juntam-se sem perder nada (o máximo de cada estatística e
## todas as conquistas). O jogo só chama funções (RPC) com a chave pública;
## as tabelas estão fechadas e o PC só guarda um token de sessão.
## Enquanto o jogo está aberto, avisa a cada 30 s que a conta ativa está
## online e, se for host, o código da sala para os amigos entrarem.

signal friends_changed
signal status_changed

const URL := "https://cbwkqshpblvvkxnohpfp.supabase.co"
const ANON_KEY := "sb_publishable_SDtVBrJ8R3Vl0bWHFFQ96w_4Dmndf5K"
const HEARTBEAT_EVERY := 30.0
## Depois de mudar alguma coisa, espera um pouco antes de enviar (junta várias).
const SYNC_DELAY := 15.0

var friends: Array = []
## Última mensagem para mostrar (erros e confirmações).
var message := ""
var busy := false
var _beat := HEARTBEAT_EVERY - 3.0
## Perfis com mudanças por enviar -> segundos desde a última mudança.
var _pending := {}
var _syncing := {}
## De 2 em 2 minutos vai buscar o que mudou noutro PC.
var _pull := 0.0


func enabled() -> bool:
	return URL != "" and ANON_KEY != ""


func _ready() -> void:
	Profiles.saved.connect(_on_profiles_saved)
	# Ao abrir o jogo, traz o que se ganhou noutros PCs.
	await get_tree().process_frame
	for i in Profiles.profiles.size():
		if logged_in(i):
			await sync(i)


func _process(delta: float) -> void:
	if not enabled():
		return
	_beat += delta
	if _beat >= HEARTBEAT_EVERY:
		_beat = 0.0
		heartbeat()
	_pull += delta
	if _pull >= 120.0:
		_pull = 0.0
		for i in Profiles.profiles.size():
			if logged_in(i) and not _pending.has(i):
				sync(i)
	for i in _pending.keys():
		_pending[i] += delta
		if _pending[i] >= SYNC_DELAY:
			_pending.erase(i)
			sync(i)


func _notification(what: int) -> void:
	# A fechar o jogo: tenta enviar o que falta (sem esperar pela resposta).
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		for i in _pending.keys():
			if logged_in(i):
				# Sem o boneco: pode haver um mais recente na conta.
				var progress := _export(i)
				progress.erase("look")
				_rpc("ou_save", {"p_token": token(i), "p_name": Profiles.profile_name(i), "p_progress": progress}, true)


# --- Conta ---------------------------------------------------------------------

## Dados online do perfil: {"user", "token", "code"} (vazio se não tem conta).
func account(index := Profiles.active) -> Dictionary:
	if index < 0 or index >= Profiles.profiles.size():
		return {}
	return Profiles.profiles[index].get("online", {})


func logged_in(index := Profiles.active) -> bool:
	return token(index) != ""


func token(index := Profiles.active) -> String:
	return account(index).get("token", "")


func username(index := Profiles.active) -> String:
	return account(index).get("user", "")


func friend_code(index := Profiles.active) -> String:
	return account(index).get("code", "") if logged_in(index) else ""


## Cria uma conta nova com o progresso deste perfil.
func register(index: int, user: String, password: String) -> bool:
	if not _check_input(user, password):
		return false
	var result = await _rpc("ou_register", {"p_username": user.strip_edges(), "p_password": password,
		"p_name": user.strip_edges(), "p_progress": _export(index), "p_device": OS.get_name()})
	if result is Array and not result.is_empty():
		_link(index, result[0])
		message = "Conta criada! Entra com \"%s\" no outro PC para teres o mesmo progresso." % username(index)
		status_changed.emit()
		return true
	return false


## Entra numa conta que já existe: o progresso da conta junta-se ao deste perfil.
func login(index: int, user: String, password: String) -> bool:
	if not _check_input(user, password):
		return false
	# Se a conta já está noutro perfil deste PC, passa a usar esse.
	for i in Profiles.profiles.size():
		if i != index and logged_in(i) and username(i).to_lower() == user.strip_edges().to_lower():
			Profiles.active = i
			Profiles.save()
			message = "Já tinhas esta conta neste PC: mudei para o perfil %s." % Profiles.profile_name(i)
			status_changed.emit()
			return true
	var result = await _rpc("ou_login", {"p_username": user.strip_edges(), "p_password": password, "p_device": OS.get_name()})
	if result is Array and result.is_empty():
		message = "Palavra-passe errada."
		status_changed.emit()
		return false
	if result is Array:
		var row: Dictionary = result[0]
		Profiles.profiles[index]["name"] = str(row.get("username", Profiles.profile_name(index))).left(16)
		_link(index, row)
		# Ao entrar, o boneco da conta ganha ao deste PC (se não for mais antigo).
		var progress = row.get("progress")
		if progress is Dictionary:
			_import(index, progress, true)
		await sync(index)
		message = "Entraste como %s. O progresso está junto." % Profiles.profile_name(index)
		status_changed.emit()
		return true
	return false


func logout(index := Profiles.active) -> void:
	if not logged_in(index):
		return
	await sync(index)
	var t := token(index)
	var user := username(index)
	Profiles.profiles[index]["online"] = {"user": user}
	Profiles.save()
	friends = []
	friends_changed.emit()
	message = "Saíste da conta. O progresso fica neste PC e na conta."
	status_changed.emit()
	_rpc("ou_logout", {"p_token": t}, true)


## Envia o progresso deste perfil e recebe o da conta (junto). Também serve
## para trazer o que se ganhou noutro PC.
func sync(index := Profiles.active) -> void:
	if not enabled() or not logged_in(index) or _syncing.get(index, false):
		return
	_syncing[index] = true
	_pending.erase(index)
	var t := token(index)
	# Primeiro traz o que está na conta (o boneco mais recente ganha), depois
	# envia tudo junto. Sem isto, cada PC escrevia o seu boneco por cima.
	var current = await _rpc("ou_load", {"p_token": t}, true)
	if index < Profiles.profiles.size() and token(index) == t and current is Array and not current.is_empty() \
			and current[0].get("progress") is Dictionary:
		_import(index, current[0]["progress"])
	if index >= Profiles.profiles.size() or token(index) != t:
		_syncing.erase(index)
		return
	var result = await _rpc("ou_save", {"p_token": t, "p_name": Profiles.profile_name(index), "p_progress": _export(index)}, true)
	_syncing.erase(index)
	# O perfil pode ter sido apagado ou mudado entretanto.
	if index >= Profiles.profiles.size() or token(index) != t:
		return
	if result is Dictionary:
		_import(index, result)


func _on_profiles_saved() -> void:
	for i in Profiles.profiles.size():
		if logged_in(i) and not _pending.has(i):
			_pending[i] = 0.0


func _check_input(user: String, password: String) -> bool:
	if not enabled():
		message = "As contas online não estão ligadas nesta versão."
	elif not RegEx.create_from_string("^[A-Za-z0-9_.-]{3,16}$").search(user.strip_edges()):
		message = "O utilizador tem de ter 3 a 16 letras ou números (sem espaços nem acentos)."
	elif password.length() < 4:
		message = "A palavra-passe tem de ter pelo menos 4 letras."
	else:
		return true
	status_changed.emit()
	return false


func _link(index: int, row: Dictionary) -> void:
	# O perfil passa a ter o nome da conta (e deixa de se poder mudar).
	if str(row.get("username", "")) != "":
		Profiles.profiles[index]["name"] = str(row["username"]).left(16)
	Profiles.profiles[index]["online"] = {"user": str(row.get("username", "")), "token": str(row.get("token", "")),
		"code": str(row.get("friend_code", ""))}
	var progress = row.get("progress")
	if progress is Dictionary:
		_import(index, progress)
	if int(Profiles.profiles[index]["stats"].get("account", 0)) < 1:
		Profiles.add_to(index, "account", 1)
	Profiles.save()
	heartbeat()
	refresh_friends()


func _export(index: int) -> Dictionary:
	var p: Dictionary = Profiles.profiles[index]
	return {"stats": p["stats"], "unlocked": p["unlocked"], "look": p.get("look", {})}


## Junta o progresso que veio da conta ao deste perfil (sem avisos de conquista:
## essas já foram ganhas noutro sítio).
func _import(index: int, progress: Dictionary, prefer_remote_look := false) -> void:
	var p: Dictionary = Profiles.profiles[index]
	var changed := false
	var stats = progress.get("stats")
	if stats is Dictionary:
		for k in stats:
			var v := int(stats[k])
			if v > int(p["stats"].get(k, 0)):
				p["stats"][k] = v
				changed = true
	var unlocked = progress.get("unlocked")
	if unlocked is Dictionary:
		for k in unlocked:
			if not p["unlocked"].has(k):
				p["unlocked"][k] = int(unlocked[k])
				changed = true
	# O boneco: fica o que foi mudado há menos tempo. Ao entrar, o da conta.
	var look = progress.get("look")
	if look is Dictionary and not (look as Dictionary).is_empty():
		var mine: Dictionary = p.get("look", {})
		# Empate (bonecos de antes da 0.5.6, sem data): ganha o da conta.
		if prefer_remote_look or int(look.get("t", 0)) >= int(mine.get("t", 0)):
			var clean := CharacterLook.clean(look)
			if clean != mine:
				p["look"] = clean
				changed = true
				PlayerRegistry.refresh_looks()
	if changed:
		Profiles.save(false)


# --- Amigos --------------------------------------------------------------------

func heartbeat() -> void:
	if not enabled() or not logged_in():
		return
	var room := ""
	if Net.online and Net.is_host() and Net.public_ip != "":
		room = Net.encode_room(Net.public_ip)
	var in_level: bool = get_tree().current_scene != null and get_tree().current_scene.scene_file_path.ends_with("level.tscn")
	var status := "A jogar" if Net.in_game or in_level else "No menu"
	if room != "":
		status = "Sala aberta"
	await _rpc("ou_heartbeat", {"p_token": token(), "p_room": room, "p_status": status}, true)


func add_friend(code: String) -> void:
	if not logged_in():
		return
	var clean := code.strip_edges().replace(" ", "")
	var result = await _rpc("ou_add_friend", {"p_token": token(), "p_code": clean})
	if result is String:
		message = "%s é agora teu amigo." % result
		Profiles.add_all("friend", 1)
		await refresh_friends()
	status_changed.emit()


func remove_friend(code: String) -> void:
	if not logged_in():
		return
	await _rpc("ou_remove_friend", {"p_token": token(), "p_code": code})
	await refresh_friends()


func refresh_friends() -> void:
	if not enabled() or not logged_in():
		friends = []
		friends_changed.emit()
		return
	var result = await _rpc("ou_list_friends", {"p_token": token()}, true)
	if result is Array:
		friends = result
	friends_changed.emit()


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


# --- Pedidos -------------------------------------------------------------------

const ERRORS := {
	"código não existe": "Não há ninguém com esse código ou utilizador.",
	"esse és tu": "Esse és tu!",
	"utilizador já existe": "Esse utilizador já existe. Se é teu, carrega em Entrar.",
	"utilizador não existe": "Esse utilizador não existe. Para o criar, carrega em Criar conta.",
	"nome de utilizador inválido": "O utilizador tem de ter 3 a 20 letras ou números (sem espaços nem acentos).",
	"palavra-passe curta": "A palavra-passe tem de ter pelo menos 4 letras.",
	"espera um minuto": "Muitas tentativas erradas. Espera um minuto.",
	"sessão terminada": "A sessão terminou. Entra outra vez na conta.",
}


## Chama uma função do Supabase. Devolve o resultado (JSON) ou null se falhar.
## Com `quiet`, os erros de ligação não mudam a mensagem (pedidos de fundo).
func _rpc(fn: String, body: Dictionary, quiet := false) -> Variant:
	busy = true
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	var headers := PackedStringArray(["apikey: " + ANON_KEY, "Content-Type: application/json"])
	# As chaves antigas (JWT) também vão no Authorization; as novas (sb_publishable_) não.
	if not ANON_KEY.begins_with("sb_"):
		headers.append("Authorization: Bearer " + ANON_KEY)
	# ORDERUP_ONLINE_URL serve para testar com um servidor local.
	var base := OS.get_environment("ORDERUP_ONLINE_URL")
	var err := http.request((base if base != "" else URL) + "/rest/v1/rpc/" + fn, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		busy = false
		if not quiet:
			message = "Sem ligação à internet."
			status_changed.emit()
		return null
	var res: Array = await http.request_completed
	http.queue_free()
	busy = false
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		if not quiet:
			message = "Sem ligação ao servidor. Estás ligado à internet?"
			status_changed.emit()
		return null
	var code: int = res[1]
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	if OS.has_environment("ORDERUP_ONLINE_DEBUG"): print("RPC ", fn, " ", res[0], " ", res[1], " ", text.left(120))
	var data = JSON.parse_string(text) if not text.is_empty() else true
	if code >= 400:
		var why: String = str(data.get("message", "erro %d" % code)) if data is Dictionary else "erro %d" % code
		if why == "sessão terminada":
			_drop_session(body.get("p_token", ""))
		elif why.contains("Could not find the function") or code == 404:
			why = "O servidor ainda tem a versão antiga. Corre o supabase-setup.sql novo no Supabase."
		message = ERRORS.get(why, why)
		status_changed.emit()
		return null
	return data


## O token deixou de valer (saiu-se noutro sítio ou a base foi refeita).
func _drop_session(t: String) -> void:
	if t == "":
		return
	for i in Profiles.profiles.size():
		if token(i) == t:
			Profiles.profiles[i]["online"] = {"user": username(i)}
			Profiles.save()
