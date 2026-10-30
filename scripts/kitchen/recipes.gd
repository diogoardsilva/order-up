class_name Recipes
## Receitas do jogo. No M4 passam para ficheiros de dados por nível.

const ALL: Array[Dictionary] = [
	{"id": "salad", "name": "Salada", "needs": ["lettuce_chopped", "tomato_chopped"], "points": 20},
	{"id": "soup", "name": "Sopa de tomate", "needs": ["soup"], "points": 30},
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
