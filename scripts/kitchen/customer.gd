class_name Customer
extends RefCounted
## Um cliente no salão: entra pela porta, senta-se, pensa, chama um chef para
## lhe anotar o pedido, espera com a paciência a descer, come e sai, deixando o
## prato sujo na mesa.

enum State { ARRIVING, THINKING, CALLING, WAITING, EATING, LEAVING, GONE }

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
## Linha da folha de sprites (penteado).
var look := randi() % Art.CUSTOMER_LOOKS

## Número único (dado pelo anfitrião) para os outros PCs saberem quem é quem.
var id := 0
## Nos outros PCs: posição recebida e se está a andar.
var net_pos := Vector2.ZERO
var net_moving := false

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


## Parado (não está a andar entre a porta e a mesa).
func is_still() -> bool:
	return _path.is_empty() and not net_moving


func is_waiting() -> bool:
	return state == State.WAITING


## Está a chamar alguém para lhe anotar o pedido.
func is_calling() -> bool:
	return state == State.CALLING


## Um chef foi à mesa anotar o pedido: passa a ser um talão.
func take_order() -> void:
	state = State.WAITING


## O jogador trouxe a comida certa.
func serve() -> void:
	state = State.EATING
	_timer = 0.0


func serialize() -> Array:
	return [id, table.cell, recipe["id"], state, pos, patience, max_patience, angry, color, look, not is_still()]


## Cria ou atualiza (nos outros PCs) um cliente com o estado do anfitrião.
static func from_net(data: Array, existing: Customer, p_table: TableStation) -> Customer:
	var customer := existing
	if customer == null:
		var path: Array[Vector2] = [data[4]]
		customer = Customer.new(p_table, Recipes.by_id(data[2]), path, data[6])
		customer.id = data[0]
		customer._path.clear()
	customer.table = p_table
	customer.state = data[3]
	customer.net_pos = data[4]
	customer.patience = data[5]
	customer.angry = data[7]
	customer.color = data[8]
	customer.look = data[9]
	customer.net_moving = data[10]
	return customer


## Avança o cliente. Devolve true no frame em que a paciência acaba.
func tick(delta: float, patience_runs: bool) -> bool:
	match state:
		State.ARRIVING:
			if _walk(delta):
				state = State.THINKING
		State.THINKING:
			_timer += delta
			if _timer >= THINK_TIME:
				state = State.CALLING
		State.CALLING, State.WAITING:
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
