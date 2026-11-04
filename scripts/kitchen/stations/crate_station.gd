class_name CrateStation
extends Station
## Caixa de ingredientes infinita.

var ingredient: String


func _init(p_ingredient: String) -> void:
	ingredient = p_ingredient


func interact(held: Item) -> Item:
	if held == null:
		return Item.ingredient(ingredient)
	# Com o mesmo ingrediente na mão, leva-se mais um (até 4 pequenos ou 2 grandes).
	if held.is_ingredient() and held.kind == ingredient and not held.chopped and held.count < held.max_count():
		held.count += 1
		return held
	# Atalho: com uma panela ou um prato na mão, o ingrediente vai direto para lá.
	if held.is_cookware():
		held.cook_add(ingredient)
	elif held.is_plate():
		held.try_add(ingredient)
	return held


func catch(_thrown: Item) -> bool:
	return false
