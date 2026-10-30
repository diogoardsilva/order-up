class_name Recipes
## Receitas do jogo. No M4 passam para ficheiros de dados por nível.

const ALL: Array[Dictionary] = [
	{"id": "salad", "name": "Salada", "hint": "alface e tomate cortados", "needs": ["lettuce_chopped", "tomato_chopped"], "points": 20},
	{"id": "soup", "name": "Sopa", "hint": "2 tomates cortados, fogão", "needs": ["soup"], "points": 30},
]

## Ingredientes que se podem pôr diretamente num prato.
const PLATEABLE: Array[String] = ["lettuce_chopped", "tomato_chopped"]


## Devolve a receita que este prato completa, ou {} se não completa nenhuma.
static func match_plate(contents: Array[String]) -> Dictionary:
	var sorted := contents.duplicate()
	sorted.sort()
	for recipe in ALL:
		var needs: Array = recipe["needs"].duplicate()
		needs.sort()
		if needs == sorted:
			return recipe
	return {}


static func by_id(id: String) -> Dictionary:
	for recipe in ALL:
		if recipe["id"] == id:
			return recipe
	return {}
