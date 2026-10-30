class_name HelperAI
extends RefCounted
## Ajudante controlado pelo jogo. Como empregado de mesa anota pedidos, leva os
## pratos prontos às mesas, cobra na caixa e trata da loiça. Como cozinheiro
## prepara os pedidos dos talões e deixa os pratos prontos numa bancada.
## Só corre no anfitrião: carrega nos "botões" de um BotSource como um jogador.

enum Role { WAITER, COOK }

## Tempo máximo numa tarefa antes de desistir e pensar outra vez.
const TASK_TIMEOUT := 12.0

var role: Role
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


func _init(p_role: Role, p_chef: Chef, p_kitchen: Kitchen, p_orders: OrderManager) -> void:
	role = p_role
	chef = p_chef
	kitchen = p_kitchen
	orders = p_orders
	var size := Vector2i(Kitchen.LAYOUT[0].length(), Kitchen.LAYOUT.size())
	_astar.region = Rect2i(Vector2i.ZERO, size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for y in size.y:
		for x in size.x:
			var c := Kitchen.LAYOUT[y][x]
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
			return
		_plan_path()
	_run_task()


# --- Movimento ----------------------------------------------------------------

func _my_cell() -> Vector2i:
	return kitchen.cell_at(chef.position)


## Célula livre ao lado da estação de onde se chega mais depressa. Os outros
## chefs contam como obstáculos.
func _plan_path() -> void:
	var blocked: Array[Vector2i] = []
	for other in kitchen.chefs:
		var c := kitchen.cell_at(other.position)
		if other != chef and _astar.is_in_boundsv(c) and not _astar.is_point_solid(c):
			_astar.set_point_solid(c)
			blocked.append(c)
	_plan_path_inner()
	for c in blocked:
		_astar.set_point_solid(c, false)


func _plan_path_inner() -> void:
	var target: Vector2i = _task["cell"]
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
		"throw_away":
			_task.clear()


func _go(cell: Vector2i, action := "pick", until := Callable()) -> Dictionary:
	return {"cell": cell, "action": action, "until": until}


# --- Escolha da tarefa -----------------------------------------------------------

func _choose() -> Dictionary:
	return _choose_waiter() if role == Role.WAITER else _choose_cook()


## Estações que cumprem o filtro e a que se consegue chegar, das mais perto para as mais longe.
func _stations(filter: Callable) -> Array:
	var result := kitchen.stations.values().filter(func(s): return _reachable(s) and filter.call(s))
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
		and Kitchen.LAYOUT[s.cell.y][s.cell.x] == "C")
	if near_dining:
		counters.sort_custom(func(a, b): return a.cell.x > b.cell.x)
	return counters[0] if not counters.is_empty() else null


func _choose_waiter() -> Dictionary:
	var held := chef.held
	if held != null:
		if held.is_plate() and not held.contents.is_empty():
			# Leva dois de uma vez se houver outro prato pronto que faça falta.
			if held.second == null:
				var wanted := _wanted_ids()
				wanted.erase(Recipes.match_plate(held.contents).get("id", ""))
				var other := _stations(func(s): return s.get_script() == Station and s.item != null and s.item.is_plate() \
					and wanted.has(Recipes.match_plate(s.item.contents).get("id", "")))
				if not other.is_empty() and kitchen.cell_center(other[0].cell).distance_to(chef.position) < Kitchen.TILE * 6:
					return _go(other[0].cell)
			for c in orders.customers:
				if c.is_waiting() and (c.wants(held) or (held.second and c.wants(held.second))):
					return _go(c.table.cell)
			var spot := _free_counter(true)
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
	for c in orders.customers:
		if c.is_calling():
			return _go(c.table.cell)
	if orders.front_of_queue():
		var payer := orders.front_of_queue()
		return _go(kitchen.register.cell, "use", func(): return orders.front_of_queue() != payer)
	var ready := _stations(func(s): return s.get_script() == Station and s.item != null and s.item.is_plate() \
		and orders.customers.any(func(c): return c.is_waiting() and c.wants(s.item)))
	if not ready.is_empty():
		return _go(ready[0].cell)
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
	for o in orders.orders:
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
		return {}
	var carrying: bool = _job.get("carry", false) and held != null and held.is_plate()
	var plate: Item = held if carrying else plate_station.item
	if plate == null:
		_job.clear()
		return {}
	var missing: Array = _job["recipe"]["needs"].duplicate()
	for id in plate.contents:
		missing.erase(id)
	if carrying:
		# Com o prato na mão: serve-o de uma panela pronta, ou volta a pousá-lo.
		for need in missing:
			var stove := _stove_for(need, false)
			if stove and stove.item.cook_state == Item.Cook.READY:
				return _go(stove.cell)
		_job.erase("carry")
		return _go(plate_station.cell)
	if missing.is_empty():
		# Pronto: fica na bancada para alguém o levar.
		_job.clear()
		return _put_away() if held else {}
	# O que tem na mão serve para alguma coisa? Senão, larga-o.
	if held and not _held_useful(missing):
		return _put_away()
	# Faz o primeiro passo possível de qualquer coisa que falte (enquanto um
	# tacho coze, adianta o resto).
	for need in missing:
		var task := _step_for(need, plate_station)
		if not task.is_empty():
			return task
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
	if pot.cook_state == Item.Cook.COOKING:
		return {}
	var left: Array = cook["in"].duplicate()
	for id in pot.contents:
		left.erase(id)
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
	var free := _stations(func(s): return s is StoveStation and s.item != null and s.item.cook_state == Item.Cook.EMPTY and not used.has(s.cell))
	if free.is_empty():
		return null
	stoves[product] = free[0].cell
	_job["stoves"] = stoves
	return free[0]


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
	# Sem nada para cozinhar: lava pratos.
	var sinks := _stations(func(s): return s is SinkStation and s.dirty > 0)
	if not sinks.is_empty() and chef.held == null:
		var sink: SinkStation = sinks[0]
		return _go(sink.cell, "use", func(): return sink.dirty == 0)
	return {}
