class_name BarStation
extends Station
## Torneira do bar, na parede do salão: mantém-se "usar" para encher um copo da
## bebida desta torneira e depois pega-se nele (como na tábua de cortar).

const POUR_TIME := 1.2

var drink := "water"
var _pour := 0.0


func _init(p_drink: String) -> void:
	drink = p_drink


func use(delta: float) -> void:
	if item != null:
		return
	_pour += delta
	if _pour >= POUR_TIME:
		_pour = 0.0
		item = Item.glass(drink)


## Só se tira o copo cheio (não se pousa nada aqui, menos um copo da mesma bebida).
func interact(held: Item) -> Item:
	if held == null:
		var taken := item
		item = null
		return taken
	if item != null and held.can_pair(item):
		return combine(held)
	return held


func catch(_thrown: Item) -> bool:
	return false


func _get_extra() -> Variant:
	return _pour if _pour > 0.0 else null


func _set_extra(extra: Variant) -> void:
	_pour = extra if extra != null else 0.0


func progress() -> float:
	return _pour / POUR_TIME if _pour > 0.0 else -1.0
