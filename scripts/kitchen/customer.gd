class_name Customer
extends RefCounted
## Um cliente no salão: entra pela porta, senta-se, pensa, pede, espera com a
## paciência a descer, come e sai, deixando o prato sujo na mesa.

enum State { ARRIVING, THINKING, WAITING, EATING, LEAVING, GONE }

const WALK_SPEED := 70.0
const THINK_TIME := 1.5
const EAT_TIME := 4.0
const COLORS: Array[Color] = [Color("8e7cc3"), Color("e69138"), Color("6fa8dc"), Color("c27ba0"), Color("93c47d")]

var table: TableStation
var recipe: Dictionary
var state := State.ARRIVING
var pos := Vector2.ZERO
var patience := 0.0
var max_patience := 0.0
var angry := false
var color: Color = COLORS.pick_random()

var _timer := 0.0
var _path: Array[Vector2] = []
var _exit_path: Array[Vector2] = []


func _init(p_table: TableStation, p_recipe: Dictionary, path: Array[Vector2], p_patience: float) -> void:
	table = p_table
	recipe = p_recipe
	max_patience = p_patience
	patience = p_patience
	_path = path.duplicate()
	_exit_path = path.duplicate()
	_exit_path.reverse()
	pos = _path.pop_front()


func is_waiting() -> bool:
	return state == State.WAITING


## O jogador trouxe a comida certa.
func serve() -> void:
	state = State.EATING
	_timer = 0.0


## Avança o cliente. Devolve true no frame em que a paciência acaba.
func tick(delta: float, patience_runs: bool) -> bool:
	match state:
		State.ARRIVING:
			if _walk(delta):
				state = State.THINKING
		State.THINKING:
			_timer += delta
			if _timer >= THINK_TIME:
				state = State.WAITING
		State.WAITING:
			if patience_runs:
				patience -= delta
				if patience <= 0.0:
					angry = true
					_leave()
					return true
		State.EATING:
			_timer += delta
			if _timer >= EAT_TIME:
				table.item.contents.clear()
				table.item.dirty = true
				_leave()
		State.LEAVING:
			if _walk(delta):
				state = State.GONE
	return false


func _leave() -> void:
	state = State.LEAVING
	table.customer = null
	_path = _exit_path.duplicate()


## Anda até ao próximo ponto do caminho. Devolve true quando chega ao fim.
func _walk(delta: float) -> bool:
	if _path.is_empty():
		return true
	pos = pos.move_toward(_path[0], WALK_SPEED * delta)
	if pos.is_equal_approx(_path[0]):
		_path.pop_front()
	return _path.is_empty()
