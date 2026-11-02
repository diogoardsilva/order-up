class_name Station
extends RefCounted
## Uma célula interativa da cozinha. Por defeito é uma bancada onde se pousa
## uma coisa. Toda a lógica de jogo passa pelas estações e é chamada pela
## Kitchen, para que online só o anfitrião a execute.

var cell: Vector2i
## O que está pousado em cima.
var item: Item


## Pegar/largar: recebe o que o chef segura e devolve o que ele fica a segurar.
func interact(held: Item) -> Item:
	if held == null:
		var taken := item
		item = null
		return taken
	if item == null:
		# Com dois pratos na mão pousa-se só o de cima.
		var rest := held.second
		held.second = null
		item = held
		return rest
	return combine(held)


## Juntar o que se tem na mão com o que está pousado. Devolve o que fica na mão.
func combine(held: Item) -> Item:
	# Pegar no prato pousado por cima dos que já se leva.
	if held.can_stack(item):
		held.stack += item.stack
		item = null
		return held
	# Dois pratos com comida: o segundo vai na outra mão.
	if held.can_pair(item):
		held.second = item
		item = null
		return held
	if held.is_cookware():
		if item.is_plate():
			held.pour_into(item)
		elif item.is_ingredient() and held.cook_add(item.content_id()):
			item = null
		return held
	if item.is_cookware():
		if held.is_plate():
			item.pour_into(held)
			return held
		if held.is_ingredient() and item.cook_add(held.content_id()):
			return null
		return held
	# Combinar ingrediente e prato, em qualquer das direções.
	if item.is_plate() and held.is_ingredient() and item.try_add(held.content_id()):
		return null
	if held.is_plate() and item.is_ingredient() and held.try_add(item.content_id()):
		item = null
	return held


## Esta estação aceita um item atirado? (só bancadas vazias e combinações)
func catch(thrown: Item) -> bool:
	if item == null:
		item = thrown
		return true
	return combine(thrown) == null


## Estado para enviar aos outros PCs, ou null se a estação está vazia.
func serialize() -> Variant:
	var extra: Variant = _get_extra()
	return null if item == null and extra == null else [Item.serialize(item), extra]


## Aplica o estado vindo do anfitrião (null = vazia).
func apply(data: Variant) -> void:
	item = Item.deserialize(data[0]) if data != null else null
	_set_extra(data[1] if data != null else null)


## Estado próprio de cada tipo de estação (progresso, pratos...).
func _get_extra() -> Variant:
	return null


func _set_extra(_extra: Variant) -> void:
	pass


## Chamado a cada frame enquanto um chef mantém "usar" carregado.
func use(_delta: float) -> void:
	pass


func tick(_delta: float) -> void:
	pass


## Progresso de 0 a 1 para a barra por cima, ou -1 sem barra.
func progress() -> float:
	return -1.0
