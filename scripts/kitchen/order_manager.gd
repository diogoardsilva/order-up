class_name OrderManager
extends Node
## Grupos de clientes do salão, os pedidos deles, a fila da caixa, pontuação e falhas.

signal served(at: Vector2)
signal paid(points: int, at: Vector2)
signal failed(at: Vector2)

const MAX_CUSTOMERS := 5
const SPAWN_EVERY := 15.0
## Probabilidade de cada tamanho de grupo (1, 2, 3 e 4 pessoas).
const GROUP_WEIGHTS: Array[float] = [0.3, 0.4, 0.18, 0.12]
const BIG_GROUP_WEIGHTS: Array[float] = [0.12, 0.33, 0.25, 0.3]
const FIRST_SPAWN := 2.0
const FAIL_PENALTY := 10
const MAX_TIP := 10

var kitchen: Kitchen
var customers: Array[Customer] = []
## Pratos à espera (para os talões): {"recipe", "time_left", "max_time", "table", "id"}
var orders: Array[Dictionary] = []
## Fila da caixa, da frente para trás.
var queue: Array[Customer] = []
var score := 0
var delivered_count := 0
var paid_count := 0
var failed_count := 0
var active := true
## No tutorial os clientes não chegam sozinhos nem perdem a paciência.
var scripted := false
## Casa Aberta: com a porta fechada não entra ninguém.
var closed := false
## Segundos entre grupos (no modo Casa Aberta vai descendo com o tempo).
var spawn_every := SPAWN_EVERY

## Pratos que os clientes deste restaurante pedem.
var menu: Array[Dictionary] = Recipes.ALL.slice(0, 2)
## Bebidas do bar deste restaurante.
var drinks: Array[Dictionary] = []
## Dificuldade: multiplicador da paciência dos clientes.
var patience_scale := 1.0
## Multiplicador dos pontos pagos (os níveis de festa pagam mais).
var points_scale := 1.0
## Grupos maiores (níveis de festa e almoços de família).
var big_groups := false
## Pontos pagos por pratos entregues a mesas que se foram embora antes do fim.
var partial_paid := 0
var _spawn := SPAWN_EVERY - FIRST_SPAWN
var _next_id := 1


func _process(delta: float) -> void:
	if active and not scripted and not closed:
		_spawn += delta
		if _spawn >= spawn_every and customers.size() < MAX_CUSTOMERS:
			if spawn_group(_random_order()):
				_spawn = 0.0
	for customer in customers.duplicate():
		if customer.tick(delta, active and not scripted):
			_fail(customer)
		if customer.state == Customer.State.GONE:
			customers.erase(customer)
		elif customer.is_waiting() and customer.missing().is_empty():
			# A comida está toda na mesa: comem e depois vão pagar.
			delivered_count += customer.size()
			customer.serve(roundi(MAX_TIP * customer.size() * customer.patience / customer.max_patience))
			served.emit(kitchen.cell_center(customer.table.cell))
		elif customer.finished_eating():
			customer.go_pay(kitchen, queue.size())
			queue.append(customer)
	_refresh_orders()


## Um pedido ao acaso: um prato do menu por pessoa.
func _random_order() -> Array[Dictionary]:
	var roll := randf()
	var size := 1
	for w in (BIG_GROUP_WEIGHTS if big_groups else GROUP_WEIGHTS):
		roll -= w
		if roll <= 0.0:
			break
		size += 1
	var order: Array[Dictionary] = []
	for i in mini(size, 4):
		order.append(menu.pick_random())
	return order


## Senta um grupo (um prato por pessoa) na mesa livre mais pequena onde caiba.
## Devolve false se não houver mesa.
func spawn_group(order: Array) -> bool:
	var free := kitchen.tables().filter(func(t: TableStation): return t.is_free() and t.capacity() >= order.size())
	if free.is_empty():
		return false
	var smallest: int = free.map(func(t: TableStation): return t.capacity()).min()
	free = free.filter(func(t: TableStation): return t.capacity() == smallest)
	var table: TableStation = free.pick_random()
	var customer := Customer.new(table, order, kitchen)
	customer.patience_scale = patience_scale
	if not drinks.is_empty() and not scripted:
		for i in order.size():
			if randf() < 0.55:
				customer.drinks.append(drinks.pick_random())
	customer.id = _next_id
	_next_id += 1
	table.customer = customer
	customers.append(customer)
	return true


## O primeiro da fila, se já lá chegou.
func front_of_queue() -> Customer:
	return queue[0] if not queue.is_empty() and queue[0].is_at_register() else null


## Um chef acabou de cobrar ao primeiro da fila.
func charge(customer: Customer) -> void:
	var points := roundi(customer.points() * points_scale)
	score += points
	paid_count += 1
	paid.emit(points, kitchen.register_center())
	_leave_queue(customer)


func _fail(customer: Customer) -> void:
	var at := kitchen.register_center() if queue.has(customer) else kitchen.cell_center(customer.table.cell)
	# O que já estava na mesa paga-se na mesma (sem gorjeta), e a multa é menor.
	var part := customer.delivered_points() if customer.is_waiting() else 0
	score = maxi(score - FAIL_PENALTY + part, 0)
	if part > 0:
		partial_paid += part
		if not kitchen.quiet:
			Profiles.add("partial")
		paid.emit(part, at + Vector2(0, -12))
	failed_count += 1
	failed.emit(at)
	if queue.has(customer):
		_leave_queue(customer)
	else:
		customer.leave(kitchen)


func _leave_queue(customer: Customer) -> void:
	customer.leave(kitchen, queue.find(customer))
	queue.erase(customer)
	for i in queue.size():
		queue[i].move_in_queue(kitchen.register_spot(i))


func serialize() -> Array:
	return [score, delivered_count, failed_count, customers.map(func(c: Customer): return c.serialize()), paid_count]


## Nos outros PCs: aplica o estado do anfitrião.
func apply(data: Array) -> void:
	score = data[0]
	delivered_count = data[1]
	failed_count = data[2]
	paid_count = data[4]
	var old := {}
	for customer in customers:
		old[customer.id] = customer
	customers.clear()
	for c in data[3]:
		var table: TableStation = kitchen.stations.get(c[1])
		customers.append(Customer.from_net(c, old.get(c[0]), table))
	for table in kitchen.tables():
		table.customer = null
	for customer in customers:
		if customer.is_seated():
			customer.table.customer = customer
	_refresh_orders()


func _refresh_orders() -> void:
	orders.clear()
	for customer in customers:
		if customer.is_waiting():
			var missing := customer.missing()
			for i in missing.size():
				orders.append({"recipe": missing[i], "time_left": customer.patience,
					"max_time": customer.max_patience, "table": customer.table.number, "id": customer.id * 10 + i})
