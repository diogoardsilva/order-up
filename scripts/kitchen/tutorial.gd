class_name Tutorial
extends RefCounted
## Tutorial guiado: uma salada e uma sopa, passo a passo. Cada passo tem um
## texto, as estações a assinalar e uma condição que o dá por concluído.

var kitchen: Kitchen
var orders: OrderManager
var step := 0
var steps: Array[Dictionary] = []


func _init(p_kitchen: Kitchen, p_orders: OrderManager) -> void:
	kitchen = p_kitchen
	orders = p_orders
	orders.spawn_customer(Recipes.ALL[0])
	var lettuce := func(s): return s is CrateStation and s.ingredient == Item.Kind.LETTUCE
	var tomato := func(s): return s is CrateStation and s.ingredient == Item.Kind.TOMATO
	var board := func(s): return s is BoardStation
	var plates := func(s): return s is PlateStation
	var stove := func(s): return s is StoveStation
	var waiting_table := func(s): return s is TableStation and s.customer != null and s.customer.state <= Customer.State.WAITING
	var dirty_table := func(s): return s is TableStation and s.item != null and s.item.dirty
	var sink := func(s): return s is SinkStation
	steps = [
		{"text": "Chegou um cliente ao salão. O balão por cima dele diz o que quer: uma salada. Vai à caixa de alfaces e carrega em {pick} para pegar numa.",
			"where": [lettuce], "done": func(): return _held_ids().has("lettuce")},
		{"text": "Fica virado para uma tábua de cortar e carrega em {pick} para pousar a alface.",
			"where": [board], "done": func(): return _board_ids().has("lettuce")},
		{"text": "Mantém {use} carregado, virado para a tábua, até a barra verde encher.",
			"where": [board], "done": func(): return _all_ids().has("lettuce_chopped")},
		{"text": "Pega num prato limpo da pilha de pratos ({pick}). Há poucos pratos, por isso vais ter de os lavar.",
			"where": [plates], "done": func(): return _plates().any(func(p): return true)},
		{"text": "Com o prato na mão, vai à tábua e carrega em {pick}: a alface cortada vai para o prato.",
			"where": [board], "done": func(): return _plate_has("lettuce_chopped")},
		{"text": "Falta o tomate: pega num, corta-o na tábua e junta-o ao prato. (Podes pousar o prato numa bancada.)",
			"where": [tomato, board], "done": func(): return _plate_matches("salad")},
		{"text": "Salada pronta! Leva-a ao salão, fica virado para a mesa do cliente e carrega em {pick}.",
			"where": [waiting_table], "done": func(): return orders.delivered_count >= 1},
		{"text": "Chegou outro cliente, que quer sopa. Corta 2 tomates e põe-nos no fogão ({pick} virado para o fogão).",
			"where": [tomato, board, stove], "done": func(): return _stoves().any(func(s): return s.state >= StoveStation.State.COOKING)},
		{"text": "A sopa está a cozer. Quando estiver pronta, recolhe-a com um prato. Não a deixes queimar: se queimar, esvazia a panela com as mãos vazias.",
			"where": [plates, stove], "done": func(): return _plate_has("soup")},
		{"text": "Leva a sopa à mesa do cliente.",
			"where": [waiting_table], "done": func(): return orders.delivered_count >= 2},
		{"text": "Quando um cliente acaba de comer, sai e deixa o prato sujo na mesa. Vai buscá-lo com {pick}.",
			"where": [dirty_table], "done": func(): return kitchen.chefs.any(func(c): return c.held != null and c.held.dirty)},
		{"text": "Leva o prato sujo ao lava-loiça, larga-o com {pick} e mantém {use} para o lavar.",
			"where": [sink], "done": func(): return _sinks().any(func(s): return s.clean > 0)},
	]


func is_finished() -> bool:
	return step >= steps.size()


func update() -> void:
	while not is_finished() and steps[step]["done"].call():
		step += 1
		if step == 7:
			orders.spawn_customer(Recipes.ALL[1])
	kitchen.hint_cells.clear()
	if not is_finished():
		for filter: Callable in steps[step]["where"]:
			for station: Station in kitchen.stations.values():
				if filter.call(station):
					kitchen.hint_cells.append(station.cell)


## Texto do passo atual com os botões de todos os jogadores, ex. "Espaço / Cruz".
func text() -> String:
	if is_finished():
		return ""
	var line: String = steps[step]["text"]
	for action in [&"pick", &"use"]:
		var names := PackedStringArray()
		for p in PlayerRegistry.players:
			var name: String = p["source"].prompt(action)
			if not names.has(name):
				names.append(name)
		line = line.replace("{%s}" % action, " / ".join(names))
	return "Passo %d de %d: %s" % [step + 1, steps.size(), line]


func _held_ids() -> Array:
	return kitchen.chefs.filter(func(c): return c.held != null).map(func(c): return c.held.content_id())


func _board_ids() -> Array:
	return kitchen.stations.values().filter(func(s): return s is BoardStation and s.item != null) \
		.map(func(s): return s.item.content_id())


func _all_ids() -> Array:
	var items: Array = kitchen.chefs.map(func(c): return c.held)
	items.append_array(kitchen.stations.values().map(func(s): return s.item))
	return items.filter(func(i): return i != null).map(func(i): return i.content_id())


func _plates() -> Array:
	var items: Array = kitchen.chefs.map(func(c): return c.held)
	items.append_array(kitchen.stations.values().map(func(s): return s.item))
	return items.filter(func(i): return i != null and i.is_plate())


func _plate_has(id: String) -> bool:
	return _plates().any(func(p): return p.contents.has(id))


func _plate_matches(recipe_id: String) -> bool:
	return _plates().any(func(p): return Recipes.match_plate(p.contents).get("id") == recipe_id)


func _sinks() -> Array:
	return kitchen.stations.values().filter(func(s): return s is SinkStation)


func _stoves() -> Array:
	return kitchen.stations.values().filter(func(s): return s is StoveStation)
