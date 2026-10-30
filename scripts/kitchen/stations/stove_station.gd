class_name StoveStation
extends Station
## Fogão com panela fixa: 2 tomates cortados fazem uma sopa. Se ninguém a
## servir a tempo, queima e é preciso esvaziar a panela (mãos vazias).

enum State { EMPTY, FILLING, COOKING, READY, BURNT }

const NEEDED := 2
const COOK_TIME := 6.0
const BURN_TIME := 8.0

var state := State.EMPTY
var tomatoes := 0
var _timer := 0.0


func interact(held: Item) -> Item:
	if held == null:
		if state == State.BURNT:
			_reset()
		return null
	if not held.is_plate() and held.content_id() == "tomato_chopped" \
			and state in [State.EMPTY, State.FILLING]:
		tomatoes += 1
		state = State.COOKING if tomatoes >= NEEDED else State.FILLING
		_timer = 0.0
		return null
	if held.is_plate() and state == State.READY and held.try_add("soup"):
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


## A sopa está quase a queimar (para o alerta a piscar).
func is_burning_soon() -> bool:
	return state == State.READY and _timer > BURN_TIME * 0.5


func _get_extra() -> Variant:
	return null if state == State.EMPTY else [state, tomatoes, _timer]


func _set_extra(extra: Variant) -> void:
	if extra == null:
		_reset()
	else:
		state = extra[0]
		tomatoes = extra[1]
		_timer = extra[2]


func _reset() -> void:
	state = State.EMPTY
	tomatoes = 0
	_timer = 0.0
