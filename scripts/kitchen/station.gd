class_name Station
extends RefCounted
## Uma célula interativa da cozinha. Por defeito é uma bancada onde se pousa
## uma coisa. Toda a lógica de jogo passa pelas estações e é chamada pela
## Kitchen, para que no M2 só o anfitrião a execute.

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
		item = held
		return null
	# Combinar ingrediente e prato, em qualquer das direções.
	if item.is_plate() and not held.is_plate() and item.try_add(held.content_id()):
		return null
	if held.is_plate() and not item.is_plate() and held.try_add(item.content_id()):
		item = null
	return held


## Chamado a cada frame enquanto um chef mantém "usar" carregado.
func use(_delta: float) -> void:
	pass


func tick(_delta: float) -> void:
	pass


## Progresso de 0 a 1 para a barra por cima, ou -1 sem barra.
func progress() -> float:
	return -1.0
