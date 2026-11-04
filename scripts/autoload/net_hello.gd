extends Node
## Aperto de mão entre versões. Fica num autoload à parte, com estas duas
## chamadas apenas e que não mudam, para funcionar mesmo entre versões
## diferentes do jogo (as outras chamadas de rede podem não bater certo).
## Quem entra diz a build que tem; se for diferente da do anfitrião, ambos
## ficam a saber quem tem de atualizar, em vez de ficarem presos à espera.


func _ready() -> void:
	multiplayer.connected_to_server.connect(func():
		hello.rpc_id(1, Updater.build(), Updater.version()))


@rpc("any_peer", "call_remote", "reliable")
func hello(build: int, version: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var mine := Updater.build()
	# Builds feitas à mão (0) não se comparam.
	if build == mine or build == 0 or mine == 0:
		return
	mismatch.rpc_id(peer, Updater.version(), mine)
	get_tree().create_timer(1.0).timeout.connect(func():
		if multiplayer.multiplayer_peer and multiplayer.get_peers().has(peer):
			multiplayer.multiplayer_peer.disconnect_peer(peer))


@rpc("authority", "call_remote", "reliable")
func mismatch(host_version: String, host_build: int) -> void:
	var msg: String
	if host_build > Updater.build():
		msg = "O anfitrião tem uma versão mais nova (%s) e tu tens a %s. Fecha e volta a abrir o jogo para atualizar e entra outra vez." % [host_version, Updater.version()]
		if Updater.can_update():
			Updater.check_now()
	else:
		msg = "O anfitrião tem uma versão mais antiga (%s) e tu tens a %s. Ele tem de fechar e voltar a abrir o jogo para atualizar." % [host_version, Updater.version()]
	Net._back_to_menu(msg)
