class_name TableStation
extends Station
## Mesa do salão. Recebe o prato do cliente sentado e, quando ele sai, fica
## com o prato sujo até alguém o levar.

var number := 0
var customer: Customer
## Célula da cadeira (à direita da mesa), onde o cliente se senta.
var seat: Vector2i


func is_free() -> bool:
	return customer == null and item == null


func interact(held: Item) -> Item:
	if held == null:
		# Só se levanta o prato sujo depois de o cliente sair.
		if item != null and item.dirty:
			var taken := item
			item = null
			return taken
		return null
	if item == null and customer != null and customer.is_waiting() and held.is_plate() \
			and Recipes.match_plate(held.contents).get("id") == customer.recipe["id"]:
		item = held
		return null
	return held
