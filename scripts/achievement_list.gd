class_name AchievementList
## As conquistas do jogo (umas 50: o Diogo achou 200 demasiadas). Cada uma: {"id", "name", "desc",
## "stat", "goal", "hidden", "icon"}. Ganha-se quando a estatística `stat` do
## perfil chega a `goal`. As escondidas só mostram o nome depois de ganhas.
## As estatísticas que acabam em "_best" guardam o máximo, as outras somam.

const MAX := 200

static var _all: Array[Dictionary] = []


static func all() -> Array[Dictionary]:
	if _all.is_empty():
		_build()
	return _all


static func _add(id: String, name: String, desc: String, stat: String, goal: int, icon: String, hidden := false) -> void:
	if _all.size() >= MAX:
		return
	_all.append({"id": id, "name": name, "desc": desc, "stat": stat, "goal": goal, "hidden": hidden, "icon": icon})


static func _tiers(prefix: String, stat: String, icon: String, goals: Array, names: Array, desc: String) -> void:
	for i in goals.size():
		var text: String = desc % goals[i]
		if goals[i] == 1:
			for pair in [["1 pratos", "o primeiro prato"], ["a 1 grupos", "ao primeiro grupo"], ["1 pedidos", "o primeiro pedido"],
					["1 bebidas", "a primeira bebida"], ["1 rondas", "uma ronda"], ["1 ingredientes", "um ingrediente"]]:
				text = text.replace(pair[0], pair[1])
		_add("%s_%d" % [prefix, goals[i]], names[i], text, stat, goals[i], icon)


static func _build() -> void:
	# --- Serviço ---------------------------------------------------------------
	_tiers("served", "served", "plate", [1, 50, 250, 1000],
		["Primeiro prato", "Cozinha a sério", "Linha de montagem", "Mil pratos"], "Servir %d pratos.")
	_tiers("paid", "paid", "coin", [1, 100], ["Primeira conta", "Cem mesas"], "Cobrar a %d grupos.")
	_tiers("points", "points", "coin", [1000, 10000], ["Mil moedas", "Dez mil"], "Juntar %d pontos no total.")
	_tiers("orders", "orders", "note", [50], ["Ouvido apurado"], "Anotar %d pedidos.")
	_tiers("drinks", "drinks", "glass", [1, 100], ["Primeira rodada", "Bar aberto"], "Servir %d bebidas.")
	_tiers("round_best", "round_best", "star", [400, 1000], ["Serviço rápido", "Mil num dia"], "Fazer %d pontos numa só ronda.")
	# --- Cozinha --------------------------------------------------------------
	_tiers("chop", "chopped", "knife", [100, 1000], ["Faca afiada", "Mestre da faca"], "Cortar %d ingredientes.")
	_tiers("cook", "cooked", "pan", [100], ["Tachos e panelas"], "Cozinhar %d vezes no fogão.")
	_tiers("wash", "washed", "sink", [100], ["Brilho de espelho"], "Lavar %d pratos.")
	_tiers("catch", "caught", "throw", [10], ["Boas mãos"], "Apanhar %d ingredientes atirados.")
	# --- Rondas ---------------------------------------------------------------
	_tiers("rounds", "rounds", "clock", [1, 25, 100], ["Primeiro turno", "Veterano", "Vida de cozinha"], "Acabar %d rondas.")
	_tiers("minutes", "minutes", "clock", [60, 600], ["Uma hora ao fogão", "Dez horas"], "Jogar %d minutos.")
	_tiers("stars3", "stars3", "star", [1, 10], ["Três estrelas", "Guia Michelin"], "Ganhar 3 estrelas em %d rondas.")
	_add("perfect_1", "Ninguém saiu zangado", "Acabar uma ronda sem nenhum grupo falhado.", "perfect", 1, "star")
	for level in Levels.ALL:
		var lid: String = level["id"]
		var lname: String = level["name"]
		_add("lv_%s_s3" % lid, "%s: 3 estrelas" % lname, "Ganhar 3 estrelas em %s." % lname, "lv_%s_stars_best" % lid, 3, "star")
		# 0.6: o último nível de cada restaurante (a noite de festa).
		var final_name: String = level["stages"][Levels.STAGES - 1]["name"]
		_add("lv_%s_final" % lid, "%s: %s" % [lname, final_name], "Ganhar uma estrela no último nível de %s." % lname,
			"lv_%s_%d_stars_best" % [lid, Levels.STAGES], 1, "hat")
		_add("lv_%s_final3" % lid, "%s: perfeição" % lname, "Ganhar 3 estrelas no último nível de %s." % lname,
			"lv_%s_%d_stars_best" % [lid, Levels.STAGES], 3, "star", true)
	_add("endless_10", "Até fechar", "Ficar 10 minutos com a Casa Aberta.", "endless_minutes_best", 10, "door")
	_add("endless_30", "Nunca fecha", "Ficar 30 minutos com a Casa Aberta.", "endless_minutes_best", 30, "door")
	# --- Equipa e modos -------------------------------------------------------
	_add("team_4", "Brigada completa", "Jogar uma ronda com 4 jogadores.", "players_best", 4, "team")
	_add("helpers_8", "Restaurante a sério", "Jogar com 8 ajudantes.", "helpers_best", 8, "team")
	_add("barman", "Hoje sou barman", "Jogar uma ronda como Barman.", "role_5", 1, "glass")
	_add("online_1", "Ligados", "Jogar uma ronda online.", "online_rounds", 1, "net")
	_add("online_25", "Cozinha sem fronteiras", "Jogar 25 rondas online.", "online_rounds", 25, "net")
	_add("host_1", "Anfitrião", "Criar uma sala online e jogar uma ronda.", "hosted", 1, "net")
	_add("tutorial", "Aprendiz", "Acabar o tutorial.", "tutorial", 1, "hat")
	_add("hard", "Dia difícil", "Acabar uma ronda no Difícil.", "diff_2", 1, "fire")
	# --- Escondidas -----------------------------------------------------------
	_add("burnt_1", "Cheira a queimado", "Deixar queimar uma panela.", "burnt", 1, "fire", true)
	_add("burnt_25", "Bombeiros a caminho", "Deixar queimar 25 panelas.", "burnt", 25, "fire", true)
	_add("failed_1", "Foram-se embora", "Um grupo saiu sem comer.", "failed", 1, "storm", true)
	_add("partial", "Ao menos pagaram", "Um grupo pagou o que já estava na mesa antes de sair zangado.", "partial", 1, "coin", true)
	_add("zero", "Dia para esquecer", "Acabar uma ronda com 0 pontos.", "zero_round", 1, "storm", true)
	_add("night_owl", "Coruja", "Jogar entre a meia-noite e as 5 da manhã.", "night", 1, "clock", true)
	_add("speed_1", "Relâmpago", "Servir 30 pratos numa só ronda.", "served_round_best", 30, "boot", true)
	_add("look", "Estilo próprio", "Personalizar o teu boneco.", "custom_look", 1, "hat")
	_add("account", "Na nuvem", "Criar uma conta online ou entrar numa.", "account", 1, "net")
	_add("remap", "À minha medida", "Trocar um botão nos Comandos.", "remap", 1, "gear", true)
	_add("all_s3", "Estrela de todos", "Ganhar 3 estrelas em todos os restaurantes.", "levels_s3", Levels.ALL.size(), "star", true)
	_add("hard_all", "Ninguém nos para", "Ganhar 3 estrelas no Difícil em todos os restaurantes.", "levels_hard3", Levels.ALL.size(), "fire", true)
