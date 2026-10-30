class_name RegisterStation
extends Station
## Caixa registadora: os clientes fazem fila aqui depois de comer e um chef
## cobra-lhes mantendo "usar", como a cortar ou a lavar.

const PAY_TIME := 1.5

var orders: OrderManager
var _pay := 0.0


## Não se pousa nada na caixa.
func interact(held: Item) -> Item:
	return held


func use(delta: float) -> void:
	var customer := orders.front_of_queue()
	if customer == null:
		_pay = 0.0
		return
	_pay += delta
	if _pay >= PAY_TIME:
		_pay = 0.0
		orders.charge(customer)


func _get_extra() -> Variant:
	return _pay if _pay > 0.0 else null


func _set_extra(extra: Variant) -> void:
	_pay = extra if extra != null else 0.0


func progress() -> float:
	return _pay / PAY_TIME if _pay > 0.0 else -1.0
