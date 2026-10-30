class_name Recipes
## Comida do jogo: pratos (o que os clientes pedem), o que se cozinha no fogão
## e que ingredientes se podem cortar ou pôr no prato. Cada nível usa só uma
## parte destes pratos (ver Levels).

## Pratos. "needs" é o que tem de estar no prato (por qualquer ordem).
const ALL: Array[Dictionary] = [
	{"id": "salad", "name": "Salada", "hint": "alface e tomate cortados", "needs": ["lettuce_chopped", "tomato_chopped"], "points": 20},
	{"id": "soup", "name": "Sopa", "hint": "2 tomates cortados, fogão", "needs": ["soup"], "points": 30},
	# Tasca portuguesa.
	{"id": "bitoque", "name": "Bitoque", "hint": "bife e ovo na frigideira + batata cortada frita", "needs": ["steak_cooked", "egg_fried", "fries"], "points": 50},
	{"id": "bras", "name": "Bacalhau à Brás", "hint": "bacalhau e batata cortados + ovo, tudo na frigideira", "needs": ["bras"], "points": 45},
	{"id": "caldo", "name": "Caldo Verde", "hint": "couve e batata cortadas, fogão", "needs": ["caldo"], "points": 35},
	# Sushi japonês.
	{"id": "sashimi", "name": "Sashimi", "hint": "salmão cortado", "needs": ["salmon_chopped"], "points": 15},
	{"id": "nigiri", "name": "Nigiri", "hint": "arroz cozido + salmão cortado", "needs": ["rice_cooked", "salmon_chopped"], "points": 30},
	{"id": "maki", "name": "Maki", "hint": "arroz cozido + alga + pepino cortado", "needs": ["rice_cooked", "nori", "cucumber_chopped"], "points": 40},
	# Diner americano.
	{"id": "burger", "name": "Hambúrguer", "hint": "pão + carne grelhada + alface cortada", "needs": ["bun", "patty_cooked", "lettuce_chopped"], "points": 40},
	{"id": "cheeseburger", "name": "Cheeseburger", "hint": "pão + carne grelhada + queijo cortado", "needs": ["bun", "patty_cooked", "cheese_chopped"], "points": 40},
	{"id": "fries", "name": "Batatas Fritas", "hint": "batata cortada na frigideira", "needs": ["fries"], "points": 20},
	# Trattoria italiana.
	{"id": "pizza", "name": "Pizza", "hint": "massa + tomate e queijo cortados, forno", "needs": ["pizza"], "points": 45},
	{"id": "spaghetti", "name": "Esparguete", "hint": "esparguete + tomate cortado, panela", "needs": ["pasta_cooked"], "points": 35},
	{"id": "caprese", "name": "Caprese", "hint": "tomate e queijo cortados", "needs": ["tomato_chopped", "cheese_chopped"], "points": 20},
]

## O que se cozinha no fogão: "in" são os ingredientes (por qualquer ordem) e
## "out" o resultado, que se tira com um prato. "tool" muda o desenho.
const COOK: Array[Dictionary] = [
	{"in": ["tomato_chopped", "tomato_chopped"], "out": "soup", "tool": "pot"},
	{"in": ["kale_chopped", "potato_chopped"], "out": "caldo", "tool": "pot"},
	{"in": ["steak"], "out": "steak_cooked", "tool": "pan"},
	{"in": ["egg"], "out": "egg_fried", "tool": "pan"},
	{"in": ["potato_chopped"], "out": "fries", "tool": "pan"},
	{"in": ["cod_chopped", "potato_chopped", "egg"], "out": "bras", "tool": "pan"},
	{"in": ["rice"], "out": "rice_cooked", "tool": "pot"},
	{"in": ["patty"], "out": "patty_cooked", "tool": "pan"},
	{"in": ["dough", "tomato_chopped", "cheese_chopped"], "out": "pizza", "tool": "oven"},
	{"in": ["pasta", "tomato_chopped"], "out": "pasta_cooked", "tool": "pot"},
]

## Ingredientes crus que se cortam na tábua.
const CHOPPABLE: Array[String] = ["tomato", "lettuce", "potato", "cod", "salmon", "cucumber", "cheese", "kale"]
## O que se pode pôr diretamente num prato, junto com outras coisas.
const PLATEABLE: Array[String] = [
	"lettuce_chopped", "tomato_chopped", "salmon_chopped", "cucumber_chopped", "cheese_chopped",
	"nori", "bun", "steak_cooked", "egg_fried", "fries", "rice_cooked", "patty_cooked",
]
## Resultados do fogão que ocupam o prato inteiro.
const SOLO: Array[String] = ["soup", "caldo", "bras", "pizza", "pasta_cooked"]
## Máximo de coisas num prato.
const PLATE_MAX := 3


## Devolve o prato que estes conteúdos completam, ou {} se não completam nenhum.
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


## A receita de fogão que estes ingredientes completam, ou {}.
static func cook_match(contents: Array) -> Dictionary:
	var sorted := contents.duplicate()
	sorted.sort()
	for cook in COOK:
		var needs: Array = cook["in"].duplicate()
		needs.sort()
		if needs == sorted:
			return cook
	return {}


## Estes ingredientes ainda podem vir a ser alguma receita de fogão?
static func cook_possible(contents: Array) -> bool:
	for cook in COOK:
		var left: Array = cook["in"].duplicate()
		var ok := true
		for id in contents:
			if not left.has(id):
				ok = false
				break
			left.erase(id)
		if ok:
			return true
	return false


## Ferramenta para desenhar o fogão com estes ingredientes ("pot", "pan" ou "oven").
static func cook_tool(contents: Array) -> String:
	for cook in COOK:
		var left: Array = cook["in"].duplicate()
		var ok := true
		for id in contents:
			if not left.has(id):
				ok = false
				break
			left.erase(id)
		if ok:
			return cook["tool"]
	return "pot"
