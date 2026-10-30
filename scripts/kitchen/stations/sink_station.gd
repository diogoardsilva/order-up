class_name SinkStation
extends Station
## Lava-loiça: larga-se aqui um prato sujo, mantém-se "usar" para lavar e
## depois pega-se no prato limpo com as mãos vazias.

const WASH_TIME := 2.0

var dirty := 0
var clean := 0
var _wash := 0.0


func interact(held: Item) -> Item:
	if held == null:
		if clean > 0:
			clean -= 1
			return Item.plate()
		return null
	if held.is_plate() and held.dirty:
		dirty += 1
		return null
	return held


func use(delta: float) -> void:
	if dirty == 0:
		return
	_wash += delta
	if _wash >= WASH_TIME:
		_wash = 0.0
		dirty -= 1
		clean += 1


func progress() -> float:
	return _wash / WASH_TIME if _wash > 0.0 else -1.0
