class_name TrashStation
extends Station
## Caixote do lixo: deita fora ingredientes, esvazia pratos e panelas
## (também o que queimou).


func interact(held: Item) -> Item:
	if held == null:
		return null
	if held.is_plate():
		held.contents.clear()
		return held
	if held.is_cookware():
		held.empty_cookware()
		return held
	return null


## Apanha o que lhe atirarem (vai para o lixo).
func catch(_thrown: Item) -> bool:
	return true
