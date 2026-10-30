class_name TableStation
extends Station
## Mesa do salão, para 2 ou 4 pessoas. Recebe os pratos do grupo sentado (um
## por pessoa) e, quando eles saem, fica com os pratos sujos até alguém os levar.

var number := 0
var customer: Customer
## Células das cadeiras, onde as pessoas do grupo se sentam.
var seats: Array[Vector2i] = []
## Células ocupadas pela mesa (a de 4 ocupa duas, uma por cima da outra).
var cells: Array[Vector2i] = []
## Pratos em cima da mesa.
var items: Array[Item] = []


func capacity() -> int:
	return seats.size()


func is_free() -> bool:
	return customer == null and items.is_empty()


func has_dirty() -> bool:
	return customer == null and items.any(func(i: Item): return i.dirty)


func interact(held: Item) -> Item:
	if held == null:
		# Só se levantam os pratos sujos depois de o grupo sair.
		if has_dirty():
			return items.pop_back()
		return null
	# Com um prato sujo na mão, leva-se mais um desta mesa.
	if has_dirty() and held.can_stack(items.back()):
		held.stack += items.pop_back().stack
		return held
	if customer != null and customer.is_waiting() and held.is_plate() and customer.wants(held):
		items.append(held)
		return null
	return held


func _get_extra() -> Variant:
	return null if items.is_empty() else items.map(func(i: Item): return Item.serialize(i))


func _set_extra(extra: Variant) -> void:
	items.clear()
	if extra != null:
		for d in extra:
			items.append(Item.deserialize(d))
