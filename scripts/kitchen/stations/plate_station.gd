class_name PlateStation
extends Station
## Pilha de pratos limpos. Os pratos são poucos: voltam sujos das mesas e
## têm de ser lavados no lava-loiça.

var count := 2


func interact(held: Item) -> Item:
	if held == null:
		if count > 0:
			count -= 1
			return Item.plate()
		return null
	# Devolver um prato limpo e vazio à pilha.
	if held.is_plate() and not held.dirty and held.contents.is_empty():
		count += 1
		return null
	return held
