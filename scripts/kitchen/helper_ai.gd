class_name HelperAI
extends RefCounted
## Ajudante controlado pelo jogo. Papéis:
## - Empregado de mesa: anota pedidos, leva os pratos às mesas, cobra e lava a loiça.
## - Host: recebe os clientes (anota os pedidos) e cobra na caixa.
## - Corredor: leva os pratos do passe às mesas e os sujos ao lava-loiça.
## - Cozinheiro: prepara os pedidos e deixa os pratos prontos no passe.
## O cozinheiro pode ficar numa zona da cozinha (cima ou baixo). Com dois
## ajudantes, nenhum vai a uma estação que o outro já foi buscar.
## Só corre no anfitrião: carrega nos "botões" de um BotSource como um jogador.

enum Role { WAITER, COOK, HOST, RUNNER, PREP, BARMAN }
enum Zone { ALL, TOP, BOTTOM }
## Fila do meio da cozinha (caixas de ingredientes), partilhada pelas duas zonas.
const MIDDLE_ROW := 6

## Tempo máximo numa tarefa antes de desistir e pensar outra vez.
const TASK_TIMEOUT := 12.0

var role: Role
var zone: Zone
var chef: Chef
var kitchen: Kitchen
var orders: OrderManager
## Saída para o BotSource.
var move := Vector2.ZERO
var buttons := {}

var _astar := AStarGrid2D.new()
## Tarefa atual: {"cell": estação, "action": "pick"/"use", "until": Callable}
var _task := {}
var _path: Array[Vector2i] = []
var _task_time := 0.0
var _think_cooldown := 0.0
## Cozinheiro: o prato em que está a trabalhar.
var _job := {}
var _stuck_time := 0.0
var _last_pos := Vector2.ZERO
var _last_delta := 0.0
var _idle_time := 0.0


func _init(p_role: Role, p_chef: Chef, p_kitchen: Kitchen, p_orders: OrderManager, p_zone := Zone.ALL) -> void:
	role = p_role
	zone = p_zone
	chef = p_chef
	kitchen = p_kitchen
	orders = p_orders
	kitchen.helpers.append(self)
	var size := Vector2i(kitchen.layout[0].length(), kitchen.layout.size())
	_astar.region = Rect2i(Vector2i.ZERO, size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for y in size.y:
		for x in size.x:
			var c := kitchen.layout[y][x]
			if c != "." and not c.is_valid_int():
				_astar.set_point_solid(Vector2i(x, y))


func think(delta: float) -> void:
	buttons.clear()
	move = Vector2.ZERO
	if chef.frozen:
		return
	_task_time += delta
	_last_delta = delta
	if _task.is_empty() or _task_time > TASK_TIMEOUT:
		_think_cooldown -= delta
		if _think_cooldown > 0.0:
			return
		_think_cooldown = 0.25
		_task = _choose()
		_task_time = 0.0
		_path.clear()
		if _task.is_empty():
			_idle_time += 0.25
			if _idle_time > 1.0:
				_task = _park()
			if _task.is_empty():
				return
		else:
			_idle_time = 0.0
		_plan_path()
	_run_task()


# --- Movimento ----------------------------------------------------------------

func _my_cell() -> Vector2i:
	return kitchen.cell_at(chef.position)


## Célula livre ao lado da estação de onde se chega mais depressa. Os outros
## chefs contam como obstáculos.
func _plan_path() -> void:
	var blocked: Array[Vector2i] = []
	var mine := _my_cell()
	var task := _task.duplicate()
	for other in kitchen.chefs:
		var c := kitchen.cell_at(other.position)
		if other != chef and c != mine and _astar.is_in_boundsv(c) and not _astar.is_point_solid(c):
			_astar.set_point_solid(c)
			blocked.append(c)
	_plan_path_inner()
	for c in blocked:
		_astar.set_point_solid(c, false)
	# Sem caminho por causa dos outros chefs? Vai na mesma: eles hão de sair.
	if _path.is_empty() and not blocked.is_empty() and not task.is_empty():
		_task = task
		_plan_path_inner()


func _plan_path_inner() -> void:
	var target: Vector2i = _task["cell"]
	if _task["action"] == "stand":
		_path = _astar.get_id_path(_my_cell(), target)
		if _path.is_empty():
			_task.clear()
		return
	var cells: Array[Vector2i] = [target]
	var station := kitchen.station_at(target)
	if station is TableStation:
		cells = (station as TableStation).cells
	var best: Array[Vector2i] = []
	for c in cells:
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not _astar.is_in_boundsv(n) or _astar.is_point_solid(n):
				continue
			var path := _astar.get_id_path(_my_cell(), n)
			if not path.is_empty() and (best.is_empty() or path.size() < best.size()):
				best.assign(path)
				_task["face"] = Vector2(c - n)
	_path = best
	if _path.is_empty():
		_task.clear()


func _run_task() -> void:
	if _task.is_empty():
		return
	# Anda pelo caminho, de centro em centro de célula.
	while not _path.is_empty() and chef.position.distance_to(kitchen.cell_center(_path[0])) < 6.0:
		_path.pop_front()
	if not _path.is_empty():
		move = (kitchen.cell_center(_path[0]) - chef.position).normalized()
		if _straight_run() >= 4:
			# Corredor comprido e direito à frente: desliza, como os jogadores.
			buttons[&"dash"] = true
		# Encravado (alguém no caminho)? Procura outro caminho.
		_stuck_time = _stuck_time + _last_delta if chef.position.distance_to(_last_pos) < 0.5 else 0.0
		_last_pos = chef.position
		if _stuck_time > 0.5:
			_stuck_time = 0.0
			_plan_path()
			if _path.is_empty():
				_task.clear()
		return
	var face: Vector2 = _task.get("face", Vector2.DOWN)
	chef.facing = face
	match _task["action"]:
		"pick":
			if _task.get("pressed", false):
				_task.clear()
			else:
				buttons[&"pick"] = true
				_task["pressed"] = true
		"use":
			var until: Callable = _task["until"]
			if until.call():
				_task.clear()
			else:
				buttons[&"use"] = true
		"throw_away", "stand":
			_task.clear()


## Quantas células seguidas o caminho vai a direito na direção em que já anda
## (alinhado com o centro das células, para o deslize não bater nas esquinas).
func _straight_run() -> int:
	if _path.is_empty():
		return 0
	var to := kitchen.cell_center(_path[0]) - chef.position
	var step := Vector2i(signi(roundi(to.x)), 0) if absf(to.x) > absf(to.y) else Vector2i(0, signi(roundi(to.y)))
	var off := absf(to.y) if step.x != 0 else absf(to.x)
	if step == Vector2i.ZERO or off > 2.0:
		return 0
	var run := 1
	for i in range(1, _path.size()):
		if _path[i] - _path[i - 1] != step:
			break
		run += 1
	return run


func _go(cell: Vector2i, action := "pick", until := Callable()) -> Dictionary:
	return {"cell": cell, "action": action, "until": until}


## Outro ajudante já vai para esta estação?
func _claimed(cell: Vector2i) -> bool:
	for h in kitchen.helpers:
		if h != self and h._task.get("cell", Vector2i(-99, -99)) == cell:
			return true
	return false


## A estação fica na zona deste ajudante? (o salão e a fila do meio contam para todos)
func _in_zone(station: Station) -> bool:
	if zone == Zone.ALL or station.cell.x > Kitchen.DINING_FROM_X:
		return true
	if station.cell.y == MIDDLE_ROW:
		return true
	return station.cell.y < MIDDLE_ROW if zone == Zone.TOP else station.cell.y > MIDDLE_ROW


# --- Escolha da tarefa -----------------------------------------------------------

func _choose() -> Dictionary:
	match role:
		Role.COOK:
			return _choose_cook()
		Role.PREP:
			return _choose_prep()
		Role.BARMAN:
			return _choose_bar()
	return _choose_waiter()


## Estações que cumprem o filtro e a que se consegue chegar, das mais perto para
## as mais longe. Fica de fora o que outro ajudante já foi buscar (menos as
## caixas, o lixo e as pilhas de pratos, que dão para todos) e, se houver, o que
## é de outra zona.
func _stations(filter: Callable) -> Array:
	var shared := func(s): return s is CrateStation or s is TrashStation or s is PlateStation
	var result := kitchen.stations.values().filter(func(s): return _reachable(s) and filter.call(s) \
		and (shared.call(s) or not _claimed(s.cell)))
	var mine := result.filter(_in_zone)
	if not mine.is_empty():
		result = mine
	var here := chef.position
	result.sort_custom(func(a, b): return kitchen.cell_center(a.cell).distance_to(here) < kitchen.cell_center(b.cell).distance_to(here))
	return result


## Tem pelo menos uma célula livre ao lado (os cantos não contam).
func _reachable(station: Station) -> bool:
	var cells: Array[Vector2i] = [station.cell]
	if station is TableStation:
		cells = (station as TableStation).cells
	for c in cells:
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if _astar.is_in_boundsv(n) and not _astar.is_point_solid(n):
				return true
	return false


func _free_counter(near_dining := false) -> Station:
	var counters := _stations(func(s): return s.get_script() == Station and s.item == null and s.cell.x < Kitchen.DINING_FROM_X - 1 \
		and kitchen.layout[s.cell.y][s.cell.x] == "C")
	if near_dining:
		counters.sort_custom(func(a, b): return a.cell.x > b.cell.x)
	return counters[0] if not counters.is_empty() else null


## Bancada, passe ou bar (onde pode estar um prato ou copo pronto).
func _is_counter(s: Station) -> bool:
	return s.get_script() == Station or s is PassStation or s is BarStation


func _free_pass() -> Station:
	var passes := _stations(func(s): return s is PassStation and s.item == null)
	return passes[0] if not passes.is_empty() else null


## Há outro ajudante (ou um jogador com esse papel) que faz este trabalho de sala?
func _someone_else(takes_orders: bool) -> bool:
	for h in kitchen.helpers:
		if h == self:
			continue
		if takes_orders and h.role in [Role.WAITER, Role.HOST]:
			return true
		if not takes_orders and h.role in [Role.WAITER, Role.RUNNER, Role.BARMAN]:
			return true
	for p in PlayerRegistry.players:
		var r: int = p.get("role", 0)
		if takes_orders and r in [3, 4]:
			return true
		if not takes_orders and r in [3, 5]:
			return true
	return false


## Há um barman (ajudante ou jogador)?
func _has_barman() -> bool:
	if kitchen.helpers.any(func(h): return h != self and h.role == Role.BARMAN):
		return true
	return PlayerRegistry.players.any(func(p): return p.get("role", 0) == 5)


func _choose_waiter(takes_orders := role != Role.RUNNER, carries := role != Role.HOST) -> Dictionary:
	var held := chef.held
	if held != null:
		if held.is_plate() and not held.contents.is_empty():
			# Leva dois de uma vez se houver outro prato pronto que faça falta.
			if held.second == null:
				var wanted := _wanted_ids()
				wanted.erase(Recipes.match_plate(held.contents).get("id", ""))
				var other := _stations(func(s): return _is_counter(s) and s.item != null and s.item.is_plate() \
					and wanted.has(Recipes.match_plate(s.item.contents).get("id", "")))
				if not other.is_empty() and kitchen.cell_center(other[0].cell).distance_to(chef.position) < Kitchen.TILE * 6:
					return _go(other[0].cell)
			for c in orders.customers:
				if c.is_waiting() and (c.wants(held) or (held.second and c.wants(held.second))):
					return _go(c.table.cell)
			var spot := _free_pass()
			if spot == null:
				spot = _free_counter(true)
			return _go(spot.cell) if spot else {}
		if held.is_plate() and held.dirty:
			if held.stack < Item.MAX_STACK:
				for t in _stations(func(s): return s is TableStation and s.has_dirty()):
					return _go(t.cell)
			var sinks := _stations(func(s): return s is SinkStation)
			return _go(sinks[0].cell) if not sinks.is_empty() else {}
		if held.is_plate() and held.contents.is_empty():
			var piles := _stations(func(s): return s is PlateStation)
			return _go(piles[0].cell) if not piles.is_empty() else {}
		var trash := _stations(func(s): return s is TrashStation)
		var spot := _free_counter()
		if held.is_cookware() and spot:
			return _go(spot.cell)
		return _go(trash[0].cell) if not trash.is_empty() else {}
	# Mãos vazias.
	if takes_orders:
		for c in orders.customers:
			if c.is_calling() and not _claimed(c.table.cell):
				return _go(c.table.cell)
		if orders.front_of_queue() and not _claimed(kitchen.register.cell):
			var payer := orders.front_of_queue()
			return _go(kitchen.register.cell, "use", func(): return orders.front_of_queue() != payer)
	if not carries:
		return {}
	var ready := _stations(func(s): return _is_counter(s) and s.item != null and s.item.is_plate() \
		and orders.customers.any(func(c): return c.is_waiting() and c.wants(s.item)))
	if not ready.is_empty():
		return _go(ready[0].cell)
	# Bebidas: só se não houver barman.
	if not _has_barman() or role == Role.BARMAN:
		var pour := _pour_task()
		if not pour.is_empty():
			return pour
	var dirty := _stations(func(s): return s is TableStation and s.has_dirty())
	if not dirty.is_empty():
		return _go(dirty[0].cell)
	var sinks := _stations(func(s): return s is SinkStation and s.dirty > 0)
	if not sinks.is_empty():
		var sink: SinkStation = sinks[0]
		return _go(sink.cell, "use", func(): return sink.dirty == 0 or chef.held != null)
	var clean := _stations(func(s): return s is SinkStation and s.clean > 0)
	if not clean.is_empty():
		return _go(clean[0].cell)
	return {}


## Ids dos pratos que ainda faltam nas mesas.
func _wanted_ids() -> Array:
	var result := []
	for c in orders.customers:
		if c.is_waiting():
			for r in c.missing():
				result.append(r["id"])
	return result


# --- Cozinheiro ---------------------------------------------------------------

## Pratos que ainda ninguém tem pronto (nem em preparação por mim).
func _next_recipe() -> Dictionary:
	var ready := []
	for s in kitchen.stations.values():
		if s.item and s.item.is_plate():
			ready.append(Recipes.match_plate(s.item.contents).get("id", ""))
	for c in kitchen.chefs:
		if c.held and c.held.is_plate():
			ready.append(Recipes.match_plate(c.held.contents).get("id", ""))
	# O que o outro cozinheiro já está a fazer.
	for h in kitchen.helpers:
		if h != self and h.role == Role.COOK and not h._job.is_empty():
			ready.append(h._job["recipe"]["id"])
	for o in orders.orders:
		if o["recipe"].get("drink", false):
			continue
		var id: String = o["recipe"]["id"]
		if ready.has(id):
			ready.erase(id)
		else:
			return o["recipe"]
	return {}


func _crate_for(kind: String) -> Station:
	var crates := _stations(func(s): return s is CrateStation and s.ingredient == kind)
	return crates[0] if not crates.is_empty() else null


func _choose_cook() -> Dictionary:
	var held := chef.held
	# Um prato pronto na mão vai para o passe, para o empregado o levar.
	if held and held.is_plate() and not held.dirty and not _job.get("carry", false) \
			and not Recipes.match_plate(held.contents).is_empty():
		var spot := _free_pass()
		# Sem empregado nem corredor (ou com o passe cheio), leva-o ele à mesa.
		if spot == null or not _someone_else(false):
			for c in orders.customers:
				if c.is_waiting() and (c.wants(held) or (held.second and c.wants(held.second))):
					return _go(c.table.cell)
		if spot == null:
			spot = _free_counter()
		return _go(spot.cell) if spot else {}
	if _job.is_empty() or not _job_plate_ok():
		_job.clear()
		var recipe := _next_recipe()
		if recipe.is_empty():
			return _put_away() if held else _cook_idle()
		_job = {"recipe": recipe, "plate": Vector2i(-1, -1), "stoves": {}}
	var plate_station: Station = kitchen.stations.get(_job["plate"])
	# 1. Um prato limpo pousado numa bancada.
	if plate_station == null:
		if held and held.is_plate() and held.contents.is_empty() and not held.dirty and held.stack == 1:
			var spot := _free_counter()
			if spot:
				_job["plate"] = spot.cell
				return _go(spot.cell)
			return {}
		if held:
			return _put_away()
		var piles := _stations(func(s): return (s is PlateStation and s.count > 0) or (s is SinkStation and s.clean > 0))
		if not piles.is_empty():
			return _go(piles[0].cell)
		var sinks := _stations(func(s): return s is SinkStation and s.dirty > 0)
		if not sinks.is_empty():
			var sink: SinkStation = sinks[0]
			return _go(sink.cell, "use", func(): return sink.clean > 0)
		# Não há pratos: vai buscar os sujos às mesas (ou ajuda na sala).
		_job.clear()
		return _cook_idle()
	var carrying: bool = _job.get("carry", false) and held != null and held.is_plate()
	var plate: Item = held if carrying else plate_station.item
	if plate == null:
		_job.clear()
		return {}
	var missing: Array = _job["recipe"]["needs"].duplicate()
	for id in plate.contents:
		missing.erase(id)
	# Os fogões do que já está no prato ficam livres para o resto.
	var claimed: Dictionary = _job.get("stoves", {})
	for product in claimed.keys():
		if not missing.has(product):
			claimed.erase(product)
	if carrying:
		# Com o prato na mão: serve-o de uma panela pronta, ou volta a pousá-lo.
		for need in missing:
			var stove := _stove_for(need, false)
			if stove and stove.item.cook_state == Item.Cook.READY:
				return _go(stove.cell)
		if missing.is_empty():
			# Ficou completo na mão: no próximo passo vai para o passe.
			_job.clear()
			return {}
		_job.erase("carry")
		return _go(plate_station.cell)
	if missing.is_empty():
		# Pronto: leva-o para o passe (se já não estiver lá).
		_job.clear()
		if held:
			return _put_away()
		if not plate_station is PassStation and _free_pass() != null:
			return _go(plate_station.cell)
		return {}
	# O que tem na mão serve para alguma coisa? Senão, larga-o.
	if held and not _held_useful(missing):
		return _put_away()
	# Faz o primeiro passo possível de qualquer coisa que falte (enquanto um
	# tacho coze, adianta o resto).
	for need in missing:
		var task := _step_for(need, plate_station)
		if not task.is_empty():
			return task
	if held and held.is_ingredient():
		# Não há onde o pôr agora: deixa-o numa bancada para não ficar parado.
		var spot := _free_counter()
		if spot:
			return _go(spot.cell)
	return _cook_idle()


## Produto do fogão para este id (ou {}).
func _cook_recipe(id: String) -> Dictionary:
	for cr in Recipes.COOK:
		if cr["out"] == id:
			return cr
	return {}


func _step_for(need: String, plate_station: Station) -> Dictionary:
	var cook := _cook_recipe(need)
	if cook.is_empty():
		return _ingredient_to(need, plate_station)
	var stove := _stove_for(need, true)
	if stove == null:
		return {}
	var pot := stove.item
	if pot.cook_state == Item.Cook.BURNT:
		return _go(stove.cell) if chef.held == null else {}
	if pot.cook_state == Item.Cook.READY:
		if chef.held:
			return {}
		_job["carry"] = true
		return _go(plate_station.cell)
	# Com dois pedidos do mesmo, faz logo uma dose dupla (o dobro dos ingredientes).
	var left: Array = []
	for k in _portions_for(need):
		left.append_array(cook["in"])
	for id in pot.contents:
		left.erase(id)
	if pot.cook_state == Item.Cook.COOKING and (left.is_empty() or pot.portions >= Item.MAX_PORTIONS):
		return {}
	for id in left:
		var task := _ingredient_to(id, stove)
		if not task.is_empty():
			return task
	return {}


## O fogão onde se faz este produto: o que já lhe está atribuído ou um livre.
func _stove_for(product: String, claim: bool) -> StoveStation:
	var stoves: Dictionary = _job.get("stoves", {})
	var stove: StoveStation = kitchen.stations.get(stoves.get(product, Vector2i(-1, -1)))
	if stove and stove.item and stove.item.is_cookware():
		return stove
	if not claim:
		return null
	var used: Array = stoves.values()
	for h in kitchen.helpers:
		if h != self and not h._job.is_empty():
			used.append_array(h._job.get("stoves", {}).values())
	var wanted: Array = _cook_recipe(product).get("in", [])
	# Fogão vazio, ou um com ingredientes deixados a meio que servem para este produto.
	var fits := func(s) -> bool:
		if s.item.cook_state == Item.Cook.EMPTY:
			return true
		# Sobrou uma dose deste produto (ou está a cozer): serve já para este prato.
		if s.item.cook_state in [Item.Cook.READY, Item.Cook.COOKING] and s.item.product == product:
			return true
		if s.item.cook_state != Item.Cook.FILLING:
			return false
		var left := wanted.duplicate()
		for id in s.item.contents:
			if not left.has(id):
				return false
			left.erase(id)
		return true
	var free := _stations(func(s): return s is StoveStation and s.item != null and not used.has(s.cell) and fits.call(s))
	if free.is_empty():
		return null
	stoves[product] = free[0].cell
	_job["stoves"] = stoves
	return free[0]


## Quantas doses fazer de uma vez: duas se há pelo menos dois pedidos que
## precisam deste produto (e ainda nenhuma panela a fazê-lo).
func _portions_for(product: String) -> int:
	var n := 0
	for o in orders.orders:
		if (o["recipe"].get("needs", []) as Array).has(product):
			n += 1
	for st in kitchen.stations.values():
		if st is StoveStation and st.item and st.item.product == product and st.item.cook_state in [Item.Cook.READY, Item.Cook.COOKING] \
				and not _job.get("stoves", {}).values().has(st.cell):
			n -= st.item.portions
	return 2 if n >= 2 else 1


## O que tem na mão é um ingrediente (cru ou cortado) de algo que falta?
func _held_useful(missing: Array) -> bool:
	var held := chef.held
	if not held.is_ingredient():
		return false
	var wanted := []
	for need in missing:
		var cook := _cook_recipe(need)
		wanted.append_array(cook["in"] if not cook.is_empty() else [need])
	for id in wanted:
		if id.trim_suffix("_chopped") == held.kind:
			return true
	return false


## Leva um ingrediente (cortado se for preciso) até uma estação (prato ou panela).
## Devolve {} se este ingrediente não é o que tem na mão e as mãos estão ocupadas.
func _ingredient_to(id: String, target: Station) -> Dictionary:
	var held := chef.held
	var raw := id.trim_suffix("_chopped")
	var chop := id.ends_with("_chopped")
	if held:
		if held.is_ingredient() and held.content_id() == id:
			return _go(target.cell)
		if held.is_ingredient() and held.kind == raw and chop:
			var boards := _stations(func(s): return s is BoardStation and s.item == null)
			return _go(boards[0].cell) if not boards.is_empty() else {}
		return {}
	# Já cortado numa bancada (o ajudante de cozinha deixa-os lá)?
	var ready := _stations(func(s): return s.get_script() == Station and s.item != null and s.item.is_ingredient() \
		and s.item.content_id() == id and s.cell.x < Kitchen.DINING_FROM_X - 1)
	if not ready.is_empty():
		return _go(ready[0].cell)
	# Alguma tábua com o ingrediente a meio ou já cortado?
	var boards := _stations(func(s): return s is BoardStation and s.item != null and s.item.is_ingredient() and s.item.kind == raw)
	if not boards.is_empty():
		var board: BoardStation = boards[0]
		if board.item.chopped:
			return _go(board.cell)
		return _go(board.cell, "use", func(): return board.item == null or board.item.chopped)
	var crate := _crate_for(raw)
	return _go(crate.cell) if crate else {}


func _job_plate_ok() -> bool:
	var cell: Vector2i = _job.get("plate", Vector2i(-1, -1))
	if cell == Vector2i(-1, -1):
		return true
	var s: Station = kitchen.stations.get(cell)
	var held_plate: bool = chef.held != null and chef.held.is_plate() and _job.get("carry", false)
	return held_plate or (s != null and s.item != null and s.item.is_plate() and not s.item.dirty)


## Pousa (ou deita fora) o que tem na mão.
func _put_away() -> Dictionary:
	var held := chef.held
	if held.is_cookware():
		var stoves := _stations(func(s): return s is StoveStation and s.item == null)
		if held.cook_state == Item.Cook.BURNT or not held.contents.is_empty():
			var trash := _stations(func(s): return s is TrashStation)
			if not trash.is_empty() and held.cook_state == Item.Cook.BURNT:
				return _go(trash[0].cell)
		return _go(stoves[0].cell) if not stoves.is_empty() else {}
	if held.is_plate() and held.dirty:
		var sinks := _stations(func(s): return s is SinkStation)
		return _go(sinks[0].cell)
	var trash := _stations(func(s): return s is TrashStation)
	if held.is_ingredient() and not trash.is_empty():
		return _go(trash[0].cell)
	var spot := _free_counter()
	return _go(spot.cell) if spot else {}


func _cook_idle() -> Dictionary:
	# Sem nada para cozinhar (ou à espera do fogão): ajuda no que faltar. Leva
	# pratos prontos, traz os sujos, lava, e anota/cobra se ninguém o faz.
	if chef.held == null and _job.is_empty():
		var help := _choose_waiter(not _someone_else(true), true)
		if not help.is_empty():
			return help
	if chef.held == null:
		var sinks := _stations(func(s): return s is SinkStation and s.dirty > 0)
		if not sinks.is_empty():
			var sink: SinkStation = sinks[0]
			return _go(sink.cell, "use", func(): return sink.dirty == 0)
	return {}


# --- Bar ---------------------------------------------------------------------

## Bebidas pedidas que ainda ninguém tem (nem no bar, nem na mão).
func _drinks_needed() -> Array:
	var wanted := []
	for c in orders.customers:
		if c.is_waiting():
			for r in c.missing():
				if r.get("drink", false):
					wanted.append(r["id"])
	var have := []
	for s in kitchen.stations.values():
		if s.item and s.item.is_glass():
			have.append(s.item.contents[0])
	for ch in kitchen.chefs:
		for it in [ch.held, ch.held.second if ch.held else null]:
			if it and it.is_glass():
				have.append(it.contents[0])
	for h in have:
		wanted.erase(h)
	return wanted


## Tira uma bebida que falta (mantém "usar" na torneira até o copo encher).
func _pour_task() -> Dictionary:
	if chef.held != null:
		return {}
	for drink in _drinks_needed():
		var bars := _stations(func(s): return s is BarStation and s.drink == drink and s.item == null)
		if not bars.is_empty():
			var bar: BarStation = bars[0]
			return _go(bar.cell, "use", func(): return bar.item != null or chef.held != null)
	return {}


func _choose_bar() -> Dictionary:
	var held := chef.held
	if held == null:
		# Copo pronto no bar que faz falta numa mesa.
		var ready := _stations(func(s): return s is BarStation and s.item != null \
			and orders.customers.any(func(c): return c.is_waiting() and c.wants(s.item)))
		if not ready.is_empty():
			return _go(ready[0].cell)
		var pour := _pour_task()
		if not pour.is_empty():
			return pour
	return _choose_waiter(false, true)


# --- Ajudante de cozinha ------------------------------------------------------

## Ingredientes cortados que fazem falta aos pedidos (um por cada uso).
func _chopped_needed() -> Array:
	var need := []
	for o in orders.orders:
		var recipe: Dictionary = o["recipe"]
		if recipe.get("drink", false):
			continue
		for n in recipe["needs"]:
			var cook := _cook_recipe(n)
			for id in (cook["in"] if not cook.is_empty() else [n]):
				if String(id).ends_with("_chopped"):
					need.append(id)
	# O que já está cortado (ou a ser cortado) conta.
	for s in kitchen.stations.values():
		if s.item and s.item.is_ingredient() and (s is BoardStation or s.get_script() == Station):
			var id: String = s.item.kind + "_chopped"
			need.erase(id)
	for ch in kitchen.chefs:
		if ch.held and ch.held.is_ingredient():
			need.erase(ch.held.kind + "_chopped")
	return need


func _choose_prep() -> Dictionary:
	var held := chef.held
	if held:
		if held.is_ingredient() and held.can_chop():
			var boards := _stations(func(s): return s is BoardStation and s.item == null)
			return _go(boards[0].cell) if not boards.is_empty() else _put_away()
		if held.is_ingredient():
			# Cortado: deixa-o numa bancada perto das tábuas e dos fogões.
			var spot := _free_counter()
			return _go(spot.cell) if spot else _put_away()
		return _put_away() if not held.is_plate() else _choose_waiter(false, true)
	# Tábua com algo meu por cortar ou já cortado.
	var boards := _stations(func(s): return s is BoardStation and s.item != null and s.item.is_ingredient())
	for b: BoardStation in boards:
		if b.item.can_chop():
			return _go(b.cell, "use", func(): return b.item == null or b.item.chopped)
	# Só tira da tábua o que está cortado se houver muitas tábuas ocupadas.
	if boards.size() >= 3:
		for b: BoardStation in boards:
			if b.item.chopped:
				return _go(b.cell)
	var need := _chopped_needed()
	if not need.is_empty():
		var crate := _crate_for(String(need[0]).trim_suffix("_chopped"))
		if crate:
			return _go(crate.cell)
	# Nada para cortar: loiça.
	var sinks := _stations(func(s): return s is SinkStation and s.dirty > 0)
	if not sinks.is_empty():
		var sink: SinkStation = sinks[0]
		return _go(sink.cell, "use", func(): return sink.dirty == 0)
	if not _someone_else(false):
		var dirty := _stations(func(s): return s is TableStation and s.has_dirty())
		if not dirty.is_empty():
			return _go(dirty[0].cell)
	return {}


## Sem nada para fazer: sai do caminho, para um sítio de espera do seu papel.
func _park() -> Dictionary:
	var target := Vector2i(9, 6)
	match role:
		Role.COOK:
			target = [Vector2i(9, 3), Vector2i(9, 3), Vector2i(9, 9)][zone]
		Role.PREP:
			target = Vector2i(9, 7)
		Role.WAITER:
			target = Vector2i(14, 6)
		Role.HOST:
			target = Vector2i(17, 9)
		Role.RUNNER:
			target = Vector2i(12, 5)
		Role.BARMAN:
			target = Vector2i(18, 6)
	# Ajudantes com o mesmo papel esperam lado a lado.
	var index := kitchen.helpers.filter(func(h): return h.role == role).find(self)
	target += Vector2i(0, index % 3)
	if not _astar.is_in_boundsv(target) or _astar.is_point_solid(target) or Vector2(_my_cell()).distance_to(Vector2(target)) < 1.5:
		return {}
	return {"cell": target, "action": "stand", "until": Callable()}
