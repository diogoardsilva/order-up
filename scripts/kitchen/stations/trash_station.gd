class_name TrashStation
extends Station
## Caixote do lixo: deita fora ingredientes e esvazia pratos.


func interact(held: Item) -> Item:
	if held != null and held.is_plate():
		held.contents.clear()
		return held
	return null
