class_name StoveStation
extends Station
## Fogão: tem uma panela (ou frigideira) que só coze quando está aqui em cima.
## Juntam-se ingredientes (ver Recipes.COOK) e, quando formam uma receita,
## cozinham. Tira-se o resultado com um prato, ou leva-se a panela inteira
## (mãos vazias) para servir noutro lado. Se ninguém a tirar a tempo, queima e
## é preciso deitá-la no lixo.

enum State { EMPTY, FILLING, COOKING, READY, BURNT }

## Estado da panela que está em cima (EMPTY se não houver panela).
var state: int:
	get:
		return item.cook_state if item and item.is_cookware() else State.EMPTY


func interact(held: Item) -> Item:
	# Só panelas se pousam no fogão.
	if held != null and item == null:
		if held.is_cookware():
			item = held
			return null
		return held
	return super(held)


## Só aceita ingredientes atirados para dentro da panela.
func catch(thrown: Item) -> bool:
	return item != null and combine(thrown) == null


func tick(delta: float) -> void:
	if item and item.is_cookware():
		item.cook_tick(delta)


func progress() -> float:
	return item.cook_progress() if item and item.is_cookware() else -1.0


func is_burning_soon() -> bool:
	return item != null and item.is_cookware() and item.is_burning_soon()
