class_name PassStation
extends Station
## Passe: balcão entre a cozinha e o salão, com campainha. Quem cozinha deixa
## aqui o prato pronto e quem serve (um jogador ou o ajudante) leva-o à mesa.
## Toca a campainha quando fica cá um prato completo.

signal plate_ready(cell: Vector2i)

var _was_ready := false


func interact(held: Item) -> Item:
	var result := super(held)
	_check_ready()
	return result


func catch(thrown: Item) -> bool:
	var ok := super(thrown)
	_check_ready()
	return ok


## Tem um prato completo de alguma receita?
func has_ready_plate() -> bool:
	return item != null and item.is_plate() and not item.dirty and not Recipes.match_plate(item.contents).is_empty()


func _check_ready() -> void:
	var ready := has_ready_plate()
	if ready and not _was_ready:
		plate_ready.emit(cell)
	_was_ready = ready
