class_name CrateStation
extends Station
## Caixa de ingredientes infinita.

var ingredient: Item.Kind


func _init(p_ingredient: Item.Kind) -> void:
	ingredient = p_ingredient


func interact(held: Item) -> Item:
	return Item.ingredient(ingredient) if held == null else held
