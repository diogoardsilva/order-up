class_name OrderManager
extends Node
## Pedidos em aberto, pontuação e falhas da ronda.

signal delivered(points: int)
signal failed

const MAX_ORDERS := 4
const ORDER_TIME := 60.0
const SPAWN_EVERY := 18.0
const FAIL_PENALTY := 10
const MAX_TIP := 10

## Cada pedido: {"recipe": Dictionary, "time_left": float}
var orders: Array[Dictionary] = []
var score := 0
var delivered_count := 0
var failed_count := 0
var active := true

var _spawn := 0.0


func _ready() -> void:
	_add_order()
	_add_order()


func _process(delta: float) -> void:
	if not active:
		return
	_spawn += delta
	if orders.is_empty() or (_spawn >= SPAWN_EVERY and orders.size() < MAX_ORDERS):
		_spawn = 0.0
		_add_order()
	for order in orders.duplicate():
		order["time_left"] -= delta
		if order["time_left"] <= 0.0:
			orders.erase(order)
			score = maxi(score - FAIL_PENALTY, 0)
			failed_count += 1
			failed.emit()


## Entrega um prato. Serve o pedido mais antigo dessa receita e devolve true.
func deliver(contents: Array[String]) -> bool:
	var recipe := Recipes.match_plate(contents)
	if recipe.is_empty() or not active:
		return false
	for order in orders:
		if order["recipe"]["id"] == recipe["id"]:
			var points: int = recipe["points"] + roundi(MAX_TIP * order["time_left"] / ORDER_TIME)
			orders.erase(order)
			score += points
			delivered_count += 1
			delivered.emit(points)
			return true
	return false


func _add_order() -> void:
	orders.append({"recipe": Recipes.ALL.pick_random(), "time_left": ORDER_TIME})
