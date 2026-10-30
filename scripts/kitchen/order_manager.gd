class_name OrderManager
extends Node
## Clientes do salão, os pedidos deles, pontuação e falhas da ronda.

signal delivered(points: int, at: Vector2)
signal failed(at: Vector2)

const MAX_CUSTOMERS := 4
const PATIENCE := 70.0
const SPAWN_EVERY := 14.0
const FIRST_SPAWN := 2.0
const FAIL_PENALTY := 10
const MAX_TIP := 10

var kitchen: Kitchen
var customers: Array[Customer] = []
## Pedidos à espera (para os talões): {"recipe", "time_left", "table"}
var orders: Array[Dictionary] = []
var score := 0
var delivered_count := 0
var failed_count := 0
var active := true
## No tutorial os clientes não chegam sozinhos nem perdem a paciência.
var scripted := false

var _spawn := SPAWN_EVERY - FIRST_SPAWN


func _process(delta: float) -> void:
	if active and not scripted:
		_spawn += delta
		if _spawn >= SPAWN_EVERY and customers.size() < MAX_CUSTOMERS:
			if spawn_customer(Recipes.ALL.pick_random()):
				_spawn = 0.0
	for customer in customers.duplicate():
		if customer.tick(delta, active and not scripted):
			score = maxi(score - FAIL_PENALTY, 0)
			failed_count += 1
			failed.emit(kitchen.cell_center(customer.table.cell))
		if customer.state == Customer.State.GONE:
			customers.erase(customer)
		# A comida chegou à mesa: o cliente começa a comer e paga.
		elif customer.is_waiting() and customer.table.item != null:
			_pay(customer)
	_refresh_orders()


## Senta um cliente numa mesa livre ao acaso. Devolve false se não houver mesa.
func spawn_customer(recipe: Dictionary) -> bool:
	var free := kitchen.tables().filter(func(t: TableStation): return t.is_free())
	if free.is_empty():
		return false
	var table: TableStation = free.pick_random()
	var customer := Customer.new(table, recipe, kitchen.path_to_seat(table), PATIENCE)
	table.customer = customer
	customers.append(customer)
	return true


func _pay(customer: Customer) -> void:
	var points: int = customer.recipe["points"] + roundi(MAX_TIP * customer.patience / customer.max_patience)
	score += points
	delivered_count += 1
	customer.serve()
	delivered.emit(points, kitchen.cell_center(customer.table.cell))


func _refresh_orders() -> void:
	orders.clear()
	for customer in customers:
		if customer.is_waiting():
			orders.append({"recipe": customer.recipe, "time_left": customer.patience,
				"max_time": customer.max_patience, "table": customer.table.number})
