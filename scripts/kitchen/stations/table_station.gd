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
		# Só se levantam os pratos sujos depois de o grupo sair (todos de uma vez, até 4).
		if has_dirty():
			var taken: Item = items.pop_back()
			while has_dirty() and taken.can_stack(items.back()):
				taken.stack += items.pop_back().stack
			return taken
		return null
	# Com pratos sujos na mão, levam-se também os desta mesa.
	if has_dirty() and held.can_stack(items.back()):
		while has_dirty() and held.can_stack(items.back()):
			held.stack += items.pop_back().stack
		return held
	if customer != null and customer.is_waiting() and held.is_plate():
		# Com dois pratos na mão, entrega o que fizer falta.
		if customer.wants(held):
			var rest := held.second
			held.second = null
			items.append(held)
			return rest
		if held.second and customer.wants(held.second):
			items.append(held.second)
			held.second = null
			return held
	return held


func _get_extra() -> Variant:
	return null if items.is_empty() else items.map(func(i: Item): return Item.serialize(i))


func _set_extra(extra: Variant) -> void:
	items.clear()
	if extra != null:
		for d in extra:
			items.append(Item.deserialize(d))


func catch(_thrown: Item) -> bool:
	return false
