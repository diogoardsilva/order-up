class_name Customer
extends RefCounted
## Um grupo de clientes (1 a 4 pessoas) no salão: entram pela porta, sentam-se
## à mesa, pensam, chamam um chef para lhes anotar o pedido (um prato por
## pessoa), esperam pela comida, comem e deixam os pratos sujos na mesa. Depois
## um deles vai pagar à caixa registadora e os outros saem. Cada fase tem a sua
## paciência.

enum State { ARRIVING, THINKING, CALLING, WAITING, EATING, TO_REGISTER, AT_REGISTER, LEAVING, GONE }

const WALK_SPEED := 70.0
const THINK_TIME := 1.5
const EAT_TIME := 4.0
## Atraso entre cada pessoa do grupo a começar a andar.
const FOLLOW_DELAY := 0.35
## Paciência de cada fase, em segundos. Grupos maiores esperam mais pela comida.
const ORDER_PATIENCE := 35.0
const FOOD_PATIENCE := 80.0
const FOOD_PATIENCE_PER_PERSON := 20.0
const PAY_PATIENCE := 45.0
const COLORS: Array[Color] = [Color("8e7cc3"), Color("e69138"), Color("6fa8dc"), Color("c27ba0"), Color("93c47d")]

var table: TableStation
## Um prato por pessoa.
var recipes: Array[Dictionary] = []
var state := State.ARRIVING
## Pessoas do grupo: a primeira é quem vai pagar.
var members: Array[Member] = []
var patience := 0.0
var max_patience := 1.0
var angry := false
## Gorjeta ganha pela rapidez a servir; paga-se na caixa com a conta.
var tip := 0
## Número único (dado pelo anfitrião) para os outros PCs saberem quem é quem.
var id := 0

var _timer := 0.0


class Member:
	var pos := Vector2.ZERO
	var path: Array[Vector2] = []
	var delay := 0.0
	var seat := Vector2i.ZERO
	var look := randi() % Art.CUSTOMER_LOOKS
	var color: Color = COLORS.pick_random()
	## Vai a caminho da porta; ao chegar sai (deixa de se desenhar).
	var exiting := false
	var gone := false
	## Nos outros PCs: posição recebida e se está a andar.
	var net_pos := Vector2.ZERO
	var net_moving := false

	func walk(delta: float) -> bool:
		if delay > 0.0:
			delay -= delta
			return false
		if path.is_empty():
			return true
		pos = pos.move_toward(path[0], WALK_SPEED * delta)
		if pos.is_equal_approx(path[0]):
			path.pop_front()
		return path.is_empty()

	func is_still() -> bool:
		return path.is_empty() and not net_moving


func _init(p_table: TableStation, p_recipes: Array, kitchen: Kitchen) -> void:
	table = p_table
	recipes.assign(p_recipes)
	for i in recipes.size():
		var m := Member.new()
		m.seat = table.seats[i]
		m.path = kitchen.path_to_seat(table, m.seat)
		m.pos = m.path.pop_front()
		m.delay = i * FOLLOW_DELAY
		members.append(m)


## Posição de quem vai pagar (o "chefe" do grupo).
var pos: Vector2:
	get:
		return members[0].pos


func size() -> int:
	return recipes.size()


func is_still() -> bool:
	return members.all(func(m: Member): return m.is_still())


func is_waiting() -> bool:
	return state == State.WAITING


## Está a chamar alguém para lhe anotar o pedido.
func is_calling() -> bool:
	return state == State.CALLING


## Quem paga está na fila da caixa, já parado.
func is_at_register() -> bool:
	return state == State.AT_REGISTER and members[0].path.is_empty()


func is_seated() -> bool:
	return state in [State.THINKING, State.CALLING, State.WAITING, State.EATING]


## Pratos que ainda faltam levar à mesa.
func missing() -> Array[Dictionary]:
	var left: Array[Dictionary] = recipes.duplicate()
	for item in table.items:
		var r := Recipes.match_plate(item.contents)
		for i in left.size():
			if left[i]["id"] == r.get("id"):
				left.remove_at(i)
				break
	return left


## Este prato ainda faz falta a alguém da mesa?
func wants(plate: Item) -> bool:
	var r := Recipes.match_plate(plate.contents)
	return not r.is_empty() and missing().any(func(m): return m["id"] == r["id"])


func points() -> int:
	var total := tip
	for r in recipes:
		total += r["points"]
	return total


## Um chef foi à mesa anotar o pedido: passa a ser talões.
func take_order() -> void:
	state = State.WAITING
	_set_patience(FOOD_PATIENCE + FOOD_PATIENCE_PER_PERSON * (size() - 1))


## A comida está toda na mesa.
func serve(p_tip: int) -> void:
	tip = p_tip
	state = State.EATING
	_timer = 0.0


## Acabaram de comer: quem paga vai para a fila da caixa, os outros saem.
func go_pay(kitchen: Kitchen, queue_index: int) -> void:
	state = State.TO_REGISTER
	for item in table.items:
		item.contents.clear()
		item.dirty = true
	table.customer = null
	members[0].path = kitchen.path_to_register(table, members[0].seat, queue_index)
	for i in range(1, members.size()):
		members[i].path = kitchen.path_from_seat(table, members[i].seat)
		members[i].delay = i * FOLLOW_DELAY
		members[i].exiting = true
	_set_patience(PAY_PATIENCE)


## A fila andou: avança até ao novo lugar (ou muda o destino, se ainda vem a caminho).
func move_in_queue(spot: Vector2) -> void:
	var m := members[0]
	if m.path.is_empty():
		m.path = [spot]
	else:
		m.path[-1] = spot


## Desistiram (ou pagaram): saem todos pela porta.
func leave(kitchen: Kitchen, from_register := -1) -> void:
	var was_seated := is_seated()
	state = State.LEAVING
	if table.customer == self:
		table.customer = null
	for i in members.size():
		var m := members[i]
		if m.gone or m.exiting:
			continue
		m.exiting = true
		if i == 0 and from_register >= 0:
			m.path = kitchen.path_from_register(from_register)
		elif was_seated:
			m.path = kitchen.path_from_seat(table, m.seat)
			m.delay = i * FOLLOW_DELAY


func serialize() -> Array:
	var people := members.map(func(m: Member): return [m.pos, not m.path.is_empty() and m.delay <= 0.0, m.look, m.color, m.gone, m.seat])
	return [id, table.cell, recipes.map(func(r): return r["id"]), state, people, patience, max_patience, angry]


## Cria ou atualiza (nos outros PCs) um grupo com o estado do anfitrião.
static func from_net(data: Array, existing: Customer, p_table: TableStation) -> Customer:
	var customer := existing
	if customer == null:
		customer = Customer.new_remote(p_table, data[2].map(func(rid): return Recipes.by_id(rid)), data[4].size())
		customer.id = data[0]
	customer.table = p_table
	customer.state = data[3]
	for i in mini(data[4].size(), customer.members.size()):
		var m := customer.members[i]
		var d: Array = data[4][i]
		if existing == null:
			m.pos = d[0]
		m.net_pos = d[0]
		m.net_moving = d[1]
		m.look = d[2]
		m.color = d[3]
		m.gone = d[4]
		m.seat = d[5]
	customer.patience = data[5]
	customer.max_patience = data[6]
	customer.angry = data[7]
	return customer


## Grupo vazio para os outros PCs (sem caminhos; as posições vêm por rede).
static func new_remote(p_table: TableStation, p_recipes: Array, count: int) -> Customer:
	var c: Customer = Customer.new(p_table, [], null)
	c.recipes.assign(p_recipes)
	for i in count:
		c.members.append(Member.new())
	return c


## Avança o grupo. Devolve true no frame em que a paciência acaba.
func tick(delta: float, patience_runs: bool) -> bool:
	var all_arrived := true
	for m in members:
		if m.gone:
			continue
		if not m.walk(delta):
			all_arrived = false
		elif m.exiting:
			m.gone = true
	match state:
		State.ARRIVING:
			if all_arrived:
				state = State.THINKING
		State.THINKING:
			_timer += delta
			if _timer >= THINK_TIME:
				state = State.CALLING
				_set_patience(ORDER_PATIENCE)
		State.CALLING, State.WAITING:
			if patience_runs and _lose_patience(delta):
				angry = true
				return true
		State.EATING:
			_timer += delta
		State.TO_REGISTER:
			if members[0].path.is_empty():
				state = State.AT_REGISTER
		State.AT_REGISTER:
			if patience_runs and _lose_patience(delta):
				angry = true
				return true
		State.LEAVING:
			if members.all(func(m: Member): return m.gone):
				state = State.GONE
	return false


## Já acabaram de comer (o OrderManager manda-os para a caixa).
func finished_eating() -> bool:
	return state == State.EATING and _timer >= EAT_TIME


func _set_patience(seconds: float) -> void:
	max_patience = seconds
	patience = seconds


func _lose_patience(delta: float) -> bool:
	patience -= delta
	return patience <= 0.0
