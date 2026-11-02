class_name PlateStation
extends Station
## Pilha de pratos limpos. Os pratos são poucos: voltam sujos das mesas e
## têm de ser lavados no lava-loiça.

var count := 3


func interact(held: Item) -> Item:
	if held == null:
		if count > 0:
			count -= 1
			return Item.plate()
		return null
	if held.is_plate() and not held.dirty and held.contents.is_empty():
		# Com pratos na mão leva-se mais um; com a pilha cheia (ou sem pratos aqui) devolvem-se.
		if count > 0 and held.stack < Item.MAX_STACK:
			count -= 1
			held.stack += 1
			return held
		count += held.stack
		return null
	return held


func _get_extra() -> Variant:
	return count


func _set_extra(extra: Variant) -> void:
	count = extra if extra != null else 0


func catch(_thrown: Item) -> bool:
	return false
