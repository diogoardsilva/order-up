class_name CrateStation
extends Station
## Caixa de ingredientes infinita.

var ingredient: String


func _init(p_ingredient: String) -> void:
	ingredient = p_ingredient


func interact(held: Item) -> Item:
	if held == null:
		return Item.ingredient(ingredient)
	# Atalho: com uma panela ou um prato na mão, o ingrediente vai direto para lá.
	if held.is_cookware():
		held.cook_add(ingredient)
	elif held.is_plate():
		held.try_add(ingredient)
	return held


func catch(_thrown: Item) -> bool:
	return false
