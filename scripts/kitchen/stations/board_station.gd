class_name BoardStation
extends Station
## Tábua de cortar: pousa-se um ingrediente cru e mantém-se "usar".

const CHOP_TIME := 1.5

var _chop := 0.0


func interact(held: Item) -> Item:
	var before := item
	var result := super(held)
	if item != before:
		_chop = 0.0
	return result


func use(delta: float) -> void:
	if item == null or item.is_plate() or item.chopped:
		return
	_chop += delta
	if _chop >= CHOP_TIME:
		item.chopped = true
		_chop = 0.0


func _get_extra() -> Variant:
	return _chop if _chop > 0.0 else null


func _set_extra(extra: Variant) -> void:
	_chop = extra if extra != null else 0.0


func progress() -> float:
	return _chop / CHOP_TIME if _chop > 0.0 else -1.0
