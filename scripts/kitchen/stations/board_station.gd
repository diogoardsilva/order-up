class_name BoardStation
extends Station
## Tábua de cortar: pousa-se um ingrediente cru (ou vários iguais) e
## mantém-se "usar". Vários cortam-se de uma vez, a demorar um pouco mais.

const CHOP_TIME := 1.5

var _chop := 0.0


func interact(held: Item) -> Item:
	var before := item
	var result := super(held)
	if item != before:
		_chop = 0.0
	return result


func use(delta: float) -> void:
	if item == null or not item.can_chop():
		return
	_chop += delta
	if _chop >= chop_time():
		item.chopped = true
		_chop = 0.0


func chop_time() -> float:
	var n := item.count if item else 1
	return CHOP_TIME * (1.0 + 0.6 * (n - 1))


func _get_extra() -> Variant:
	return _chop if _chop > 0.0 else null


func _set_extra(extra: Variant) -> void:
	_chop = extra if extra != null else 0.0


func progress() -> float:
	return _chop / chop_time() if _chop > 0.0 else -1.0
