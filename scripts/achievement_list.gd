class_name AchievementList
## As conquistas do jogo (no máximo 200). Cada uma: {"id", "name", "desc",
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
	_tiers("served", "served", "plate", [1, 10, 50, 100, 250, 500, 1000, 5000],
		["Primeiro prato", "Mãos à obra", "Cozinha a sério", "Cem pratos", "Linha de montagem",
		"Meio milhar", "Mil pratos", "Chef executivo"], "Servir %d pratos.")
	_tiers("paid", "paid", "coin", [1, 10, 50, 100, 250, 500, 1000],
		["Primeira conta", "Clientes da casa", "Casa cheia", "Cem mesas", "Freguesia fiel", "Restaurante da moda", "Mil contas"],
		"Cobrar a %d grupos.")
	_tiers("points", "points", "coin", [100, 1000, 5000, 10000, 50000, 100000],
		["Trocos", "Mil moedas", "Caixa forte", "Dez mil", "Investidor", "Milionário da tasca"],
		"Juntar %d pontos no total.")
	_tiers("tips", "tips", "coin", [50, 500, 5000],
		["Gorjeta", "Sorrisos pagos", "Toda a gente volta"], "Receber %d pontos em gorjetas.")
	_tiers("orders", "orders", "note", [1, 50, 250, 1000],
		["Bloco de notas", "Ouvido apurado", "Memória de elefante", "Nunca se engana"], "Anotar %d pedidos.")
	_tiers("drinks", "drinks", "glass", [1, 25, 100, 500, 1000],
		["Primeira rodada", "Mão de barman", "Bar aberto", "Cocktail mestre", "Mil copos"], "Servir %d bebidas.")
	_tiers("round_best", "round_best", "star", [200, 400, 700, 1000],
		["Bom serviço", "Serviço rápido", "Imparável", "Mil num dia"],
		"Fazer %d pontos numa só ronda.")
	# --- Cozinha --------------------------------------------------------------
	_tiers("chop", "chopped", "knife", [10, 100, 500, 1000, 5000],
		["Primeiros cortes", "Faca afiada", "Picadora humana", "Mil cortes", "Mestre da faca"], "Cortar %d ingredientes.")
	_tiers("cook", "cooked", "pan", [10, 100, 500, 1000, 3000],
		["Lume brando", "Tachos e panelas", "Fogão a fundo", "Mil cozinhados", "Senhor do fogão"], "Cozinhar %d vezes no fogão.")
	_tiers("wash", "washed", "sink", [10, 100, 500, 1000],
		["Mãos na água", "Lava-loiça", "Brilho de espelho", "Mil pratos lavados"], "Lavar %d pratos.")
	_tiers("throw", "thrown", "throw", [10, 100, 500], ["Lançamento", "Quarterback da cozinha", "Malabarista"], "Atirar %d ingredientes.")
	_tiers("catch", "caught", "throw", [1, 50, 250], ["Apanhei!", "Boas mãos", "Nada cai ao chão"], "Apanhar %d ingredientes atirados.")
	_tiers("dash", "dashes", "boot", [100, 1000, 10000], ["Apressado", "Sempre a correr", "Maratonista"], "Correr (dash) %d vezes.")
	# --- Rondas ---------------------------------------------------------------
	_tiers("rounds", "rounds", "clock", [1, 10, 50, 100, 250], ["Primeiro turno", "Semana de trabalho", "Veterano", "Cem turnos", "Vida de cozinha"],
		"Acabar %d rondas.")
	_tiers("minutes", "minutes", "clock", [10, 60, 300, 1200], ["Aquecimento", "Uma hora ao fogão", "Turno duplo", "Vinte horas"],
		"Jogar %d minutos.")
	_tiers("stars3", "stars3", "star", [1, 10, 50], ["Três estrelas", "Coleção de estrelas", "Guia Michelin"], "Ganhar 3 estrelas em %d rondas.")
	_tiers("perfect", "perfect", "star", [1, 10, 25], ["Ninguém saiu zangado", "Sempre a horas", "Serviço perfeito"],
		"Acabar %d rondas sem nenhum grupo falhado.")
	for level in Levels.ALL:
		var lid: String = level["id"]
		var lname: String = level["name"]
		_add("lv_%s_play" % lid, "Abrir: %s" % lname, "Jogar uma ronda em %s." % lname, "lv_%s_rounds" % lid, 1, "door")
		_add("lv_%s_s1" % lid, "%s: 1 estrela" % lname, "Ganhar pelo menos 1 estrela em %s." % lname, "lv_%s_stars_best" % lid, 1, "star")
		_add("lv_%s_s2" % lid, "%s: 2 estrelas" % lname, "Ganhar pelo menos 2 estrelas em %s." % lname, "lv_%s_stars_best" % lid, 2, "star")
		_add("lv_%s_s3" % lid, "%s: 3 estrelas" % lname, "Ganhar 3 estrelas em %s." % lname, "lv_%s_stars_best" % lid, 3, "star")
		_add("lv_%s_hard" % lid, "%s no Difícil" % lname, "Ganhar 3 estrelas em %s no Difícil." % lname, "lv_%s_hard3" % lid, 1, "fire")
		_add("lv_%s_perfect" % lid, "%s sem falhas" % lname, "Acabar uma ronda em %s sem grupos falhados." % lname, "lv_%s_perfect" % lid, 1, "star")
		_add("lv_%s_endless" % lid, "%s: Casa Aberta" % lname, "Fazer 500 pontos em Casa Aberta em %s." % lname, "lv_%s_endless_best" % lid, 500, "door")
	# --- Pratos e bebidas -----------------------------------------------------
	for r in Recipes.ALL:
		var rid: String = r["id"]
		var rname: String = r["name"]
		if r.get("drink", false):
			_add("dr_%s_1" % rid, "%s, por favor" % rname, "Servir %s." % rname, "dish_%s" % rid, 1, "glass")
			_add("dr_%s_50" % rid, "Especialista em %s" % rname, "Servir 50 de %s." % rname, "dish_%s" % rid, 50, "glass")
		else:
			_add("di_%s_1" % rid, "Estreia: %s" % rname, "Servir %s pela primeira vez." % rname, "dish_%s" % rid, 1, "plate")
			_add("di_%s_25" % rid, "%s da casa" % rname, "Servir 25 de %s." % rname, "dish_%s" % rid, 25, "plate")
	# --- Equipa, papéis e modos -----------------------------------------------
	for i in range(1, GameState.PLAYER_ROLES.size()):
		var role: String = GameState.PLAYER_ROLES[i][0]
		_add("role_%d" % i, "Hoje sou %s" % role.to_lower(), "Jogar uma ronda como %s." % role, "role_%d" % i, 1, "hat")
	_add("team_2", "A dois", "Jogar uma ronda com 2 jogadores.", "players_best", 2, "team")
	_add("team_3", "Trio", "Jogar uma ronda com 3 jogadores.", "players_best", 3, "team")
	_add("team_4", "Brigada completa", "Jogar uma ronda com 4 jogadores.", "players_best", 4, "team")
	_add("helpers_1", "Contratar", "Jogar com um ajudante.", "helpers_best", 1, "team")
	_add("helpers_4", "Equipa grande", "Jogar com 4 ajudantes.", "helpers_best", 4, "team")
	_add("helpers_8", "Restaurante a sério", "Jogar com 8 ajudantes.", "helpers_best", 8, "team")
	_add("online_1", "Ligados", "Jogar uma ronda online.", "online_rounds", 1, "net")
	_add("online_10", "Sala cheia", "Jogar 10 rondas online.", "online_rounds", 10, "net")
	_add("online_50", "Cozinha sem fronteiras", "Jogar 50 rondas online.", "online_rounds", 50, "net")
	_add("host_1", "Anfitrião", "Criar uma sala online e jogar uma ronda.", "hosted", 1, "net")
	_add("tutorial", "Aprendiz", "Acabar o tutorial.", "tutorial", 1, "hat")
	_add("easy", "Com calma", "Acabar uma ronda no Fácil.", "diff_0", 1, "clock")
	_add("normal", "Dia normal", "Acabar uma ronda no Normal.", "diff_1", 1, "clock")
	_add("hard", "Dia difícil", "Acabar uma ronda no Difícil.", "diff_2", 1, "fire")
	_add("custom", "À minha maneira", "Acabar uma ronda no Personalizado.", "diff_3", 1, "gear")
	_add("endless_10", "Até fechar", "Ficar 10 minutos com a Casa Aberta.", "endless_minutes_best", 10, "door")
	_add("endless_20", "Noite longa", "Ficar 20 minutos com a Casa Aberta.", "endless_minutes_best", 20, "door")
	_add("endless_30", "Nunca fecha", "Ficar 30 minutos com a Casa Aberta.", "endless_minutes_best", 30, "door")
	# --- Escondidas -----------------------------------------------------------
	_add("burnt_1", "Cheira a queimado", "Deixar queimar uma panela.", "burnt", 1, "fire", true)
	_add("burnt_10", "Bombeiros a caminho", "Deixar queimar 10 panelas.", "burnt", 10, "fire", true)
	_add("burnt_50", "Cozinha do inferno", "Deixar queimar 50 panelas.", "burnt", 50, "fire", true)
	_add("failed_1", "Foram-se embora", "Um grupo saiu sem comer.", "failed", 1, "storm", true)
	_add("failed_50", "Má fama", "50 grupos saíram sem comer.", "failed", 50, "storm", true)
	_add("partial", "Ao menos pagaram", "Um grupo pagou o que já estava na mesa antes de sair.", "partial", 1, "coin", true)
	_add("emote_10", "Simpatia", "Acenar 10 vezes.", "emotes", 10, "hat", true)
	_add("emote_100", "Animador de sala", "Acenar 100 vezes.", "emotes", 100, "hat", true)
	_add("zero", "Dia para esquecer", "Acabar uma ronda com 0 pontos.", "zero_round", 1, "storm", true)
	_add("ultra", "Olhos de lince", "Pôr os gráficos no Ultra.", "ultra", 1, "gear", true)
	_add("remap", "À minha medida", "Trocar um botão nos Comandos.", "remap", 1, "gear", true)
	_add("throw_far", "Lançamento perfeito", "Apanhar 10 ingredientes atirados numa só ronda.", "caught_round_best", 10, "throw", true)
	_add("night_owl", "Coruja", "Jogar entre a meia-noite e as 5 da manhã.", "night", 1, "clock", true)
	_add("speed_1", "Relâmpago", "Servir 30 pratos numa só ronda.", "served_round_best", 30, "boot", true)
	_add("speed_2", "Turbo", "Servir 50 pratos numa só ronda.", "served_round_best", 50, "boot", true)
	_add("drinks_round", "Happy hour", "Servir 20 bebidas numa só ronda.", "drinks_round_best", 20, "glass", true)
	_add("clean_round", "Loiça em dia", "Lavar 30 pratos numa só ronda.", "washed_round_best", 30, "sink", true)
	_add("chop_round", "Tempestade de facas", "Cortar 60 ingredientes numa só ronda.", "chopped_round_best", 60, "knife", true)
	_add("all_s3", "Estrela de todos", "Ganhar 3 estrelas em todos os restaurantes.", "levels_s3", Levels.ALL.size(), "star", true)
	_add("hard_all", "Ninguém nos para", "Ganhar 3 estrelas no Difícil em todos os restaurantes.", "levels_hard3", Levels.ALL.size(), "fire", true)
	_add("rich_round", "Noite de ouro", "Receber 100 pontos de gorjeta numa ronda.", "tips_round_best", 100, "coin", true)
	_add("profile", "Este sou eu", "Criar um perfil com nome.", "profile", 1, "hat", true)
