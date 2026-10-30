class_name CrateStation
extends Station
## Caixa de ingredientes infinita.

var ingredient: String


func _init(p_ingredient: String) -> void:
	ingredient = p_ingredient


func interact(held: Item) -> Item:
	return Item.ingredient(ingredient) if held == null else held
