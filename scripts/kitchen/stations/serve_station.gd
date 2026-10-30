class_name ServeStation
extends Station
## Passe de entrega: aceita pratos que completem um pedido em aberto.

var orders: OrderManager


func _init(p_orders: OrderManager) -> void:
	orders = p_orders


func interact(held: Item) -> Item:
	if held != null and held.is_plate() and orders.deliver(held.contents):
		return null
	return held
