class_name StoveStation
extends Station
## Fogão: juntam-se ingredientes (ver Recipes.COOK) e, quando formam uma
## receita, cozinham. O resultado tira-se com um prato; se ninguém o tirar a
## tempo, queima e é preciso esvaziar o fogão com as mãos vazias. Com as mãos
## vazias também se tira o último ingrediente posto, para emendar enganos.

enum State { EMPTY, FILLING, COOKING, READY, BURNT }

const COOK_TIME := 6.0
const BURN_TIME := 8.0
const MAX_CONTENTS := 3

var state := State.EMPTY
var contents: Array[String] = []
var product := ""
var _timer := 0.0


func interact(held: Item) -> Item:
	if held == null:
		if state == State.BURNT:
			_reset()
		elif state in [State.FILLING, State.COOKING]:
			var id: String = contents.pop_back()
			_update_state()
			var item := Item.ingredient(id.trim_suffix("_chopped"))
			item.chopped = id.ends_with("_chopped")
			return item
		return null
	if not held.is_plate() and state in [State.EMPTY, State.FILLING, State.COOKING] and contents.size() < MAX_CONTENTS:
		var next := contents.duplicate()
		next.append(held.content_id())
		if Recipes.cook_possible(next):
			contents.append(held.content_id())
			_update_state()
			return null
	if held.is_plate() and state == State.READY and held.try_add(product):
		_reset()
	return held


func tick(delta: float) -> void:
	if state == State.COOKING:
		_timer += delta
		if _timer >= COOK_TIME:
			state = State.READY
			_timer = 0.0
	elif state == State.READY:
		_timer += delta
		if _timer >= BURN_TIME:
			state = State.BURNT


func progress() -> float:
	return _timer / COOK_TIME if state == State.COOKING else -1.0


## O resultado está quase a queimar (para o alerta a piscar).
func is_burning_soon() -> bool:
	return state == State.READY and _timer > BURN_TIME * 0.5


## Panela, frigideira ou forno, conforme o que lá está (null = vazio).
func tool() -> String:
	return Recipes.cook_tool(contents) if not contents.is_empty() else ""


func _update_state() -> void:
	_timer = 0.0
	var cook := Recipes.cook_match(contents)
	if contents.is_empty():
		state = State.EMPTY
	elif cook.is_empty():
		state = State.FILLING
	else:
		state = State.COOKING
		product = cook["out"]


func _get_extra() -> Variant:
	return null if state == State.EMPTY else [state, contents, _timer, product]


func _set_extra(extra: Variant) -> void:
	if extra == null:
		_reset()
	else:
		state = extra[0]
		contents.assign(extra[1])
		_timer = extra[2]
		product = extra[3]


func _reset() -> void:
	state = State.EMPTY
	contents.clear()
	product = ""
	_timer = 0.0
