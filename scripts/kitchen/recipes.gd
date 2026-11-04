class_name Recipes
## Comida do jogo: pratos (o que os clientes pedem), o que se cozinha no fogão
## e que ingredientes se podem cortar ou pôr no prato. Cada nível usa só uma
## parte destes pratos (ver Levels).

## Pratos. "needs" é o que tem de estar no prato (por qualquer ordem).
const ALL: Array[Dictionary] = [
	{"id": "salad", "name": "Salada", "hint": "alface e tomate cortados", "needs": ["lettuce_chopped", "tomato_chopped"], "points": 20},
	{"id": "soup", "name": "Sopa", "hint": "2 tomates cortados, fogão", "needs": ["soup"], "points": 30},
	{"id": "toast", "name": "Tosta mista", "hint": "pão + queijo cortado, frigideira", "needs": ["toast"], "points": 30},
	{"id": "omelette", "name": "Omelete", "hint": "ovo + queijo cortado, frigideira", "needs": ["omelette"], "points": 30},
	{"id": "mush_soup", "name": "Creme de cogumelos", "hint": "2 cogumelos cortados, fogão", "needs": ["mush_soup"], "points": 35},
	# Tasca portuguesa.
	{"id": "bitoque", "name": "Bitoque", "hint": "bife e ovo na frigideira + batata cortada frita", "needs": ["steak_cooked", "egg_fried", "fries"], "points": 50},
	{"id": "bras", "name": "Bacalhau à Brás", "hint": "bacalhau e batata cortados + ovo, tudo na frigideira", "needs": ["bras"], "points": 45},
	{"id": "caldo", "name": "Caldo Verde", "hint": "couve e batata cortadas, fogão", "needs": ["caldo"], "points": 35},
	{"id": "prego", "name": "Prego no pão", "hint": "pão + bife na frigideira", "needs": ["bread", "steak_cooked"], "points": 35},
	{"id": "nata", "name": "Pastel de nata", "hint": "massa + ovo, forno", "needs": ["nata"], "points": 30},
	# Sushi japonês.
	{"id": "sashimi", "name": "Sashimi", "hint": "salmão cortado", "needs": ["salmon_chopped"], "points": 15},
	{"id": "nigiri", "name": "Nigiri", "hint": "arroz cozido + salmão cortado", "needs": ["rice_cooked", "salmon_chopped"], "points": 30},
	{"id": "maki", "name": "Maki", "hint": "arroz cozido + alga + pepino cortado", "needs": ["rice_cooked", "nori", "cucumber_chopped"], "points": 40},
	{"id": "tempura", "name": "Tempura", "hint": "camarão na frigideira", "needs": ["tempura"], "points": 25},
	{"id": "ramen", "name": "Ramen", "hint": "massa ramen + ovo, panela", "needs": ["ramen"], "points": 40},
	{"id": "uramaki", "name": "Uramaki", "hint": "arroz cozido + alga + tempura", "needs": ["rice_cooked", "nori", "tempura"], "points": 50},
	# Diner americano.
	{"id": "burger", "name": "Hambúrguer", "hint": "pão + carne grelhada + alface cortada", "needs": ["bun", "patty_cooked", "lettuce_chopped"], "points": 40},
	{"id": "cheeseburger", "name": "Cheeseburger", "hint": "pão + carne grelhada + queijo cortado", "needs": ["bun", "patty_cooked", "cheese_chopped"], "points": 40},
	{"id": "fries", "name": "Batatas Fritas", "hint": "batata cortada na frigideira", "needs": ["fries"], "points": 20},
	{"id": "hotdog", "name": "Cachorro-quente", "hint": "pão + salsicha na frigideira", "needs": ["bun", "sausage_cooked"], "points": 35},
	{"id": "rings", "name": "Anéis de cebola", "hint": "cebola cortada na frigideira", "needs": ["onion_rings"], "points": 25},
	{"id": "cheese_fries", "name": "Batatas com queijo", "hint": "batatas fritas + queijo cortado", "needs": ["fries", "cheese_chopped"], "points": 30},
	# Trattoria italiana.
	{"id": "pizza", "name": "Pizza", "hint": "massa + tomate e queijo cortados, forno", "needs": ["pizza"], "points": 45},
	{"id": "spaghetti", "name": "Esparguete", "hint": "esparguete + tomate cortado, panela", "needs": ["pasta_cooked"], "points": 35},
	{"id": "caprese", "name": "Caprese", "hint": "tomate e queijo cortados", "needs": ["tomato_chopped", "cheese_chopped"], "points": 20},
	{"id": "risotto", "name": "Risotto de cogumelos", "hint": "arroz + cogumelos cortados, panela", "needs": ["risotto"], "points": 40},
	{"id": "lasagna", "name": "Lasanha", "hint": "esparguete + carne + queijo cortado, forno", "needs": ["lasagna"], "points": 50},
	{"id": "funghi", "name": "Pizza de cogumelos", "hint": "massa + queijo e cogumelos cortados, forno", "needs": ["funghi"], "points": 50},
	# Bebidas: servem-se num copo, tirado no bar (mantém "usar" na torneira).
	{"id": "water", "name": "Água", "hint": "bar: copo de água", "needs": ["water"], "points": 8, "drink": true},
	{"id": "juice", "name": "Sumo de laranja", "hint": "bar: sumo de laranja", "needs": ["juice"], "points": 12, "drink": true},
	{"id": "wine", "name": "Vinho", "hint": "bar: copo de vinho", "needs": ["wine"], "points": 15, "drink": true},
	{"id": "coffee", "name": "Café", "hint": "bar: máquina do café", "needs": ["coffee"], "points": 10, "drink": true},
	{"id": "tea", "name": "Chá verde", "hint": "bar: chá verde", "needs": ["tea"], "points": 10, "drink": true},
	{"id": "soda", "name": "Refrigerante", "hint": "bar: refrigerante", "needs": ["soda"], "points": 10, "drink": true},
	{"id": "shake", "name": "Batido", "hint": "bar: batido", "needs": ["shake"], "points": 15, "drink": true},
]
## Cor de cada bebida (no copo).
const DRINK_COLORS := {
	"water": Color("bfe3f2"), "juice": Color("f6a13a"), "wine": Color("8e1f3a"), "coffee": Color("5a3422"),
	"tea": Color("9cc25a"), "soda": Color("3a2420"), "shake": Color("f2a7c4"),
}


static func is_drink(id: String) -> bool:
	return DRINK_COLORS.has(id)

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
	{"in": ["bread", "cheese_chopped"], "out": "toast", "tool": "pan"},
	{"in": ["egg", "cheese_chopped"], "out": "omelette", "tool": "pan"},
	{"in": ["mushroom_chopped", "mushroom_chopped"], "out": "mush_soup", "tool": "pot"},
	{"in": ["dough", "egg"], "out": "nata", "tool": "oven"},
	{"in": ["shrimp"], "out": "tempura", "tool": "pan"},
	{"in": ["noodles", "egg"], "out": "ramen", "tool": "pot"},
	{"in": ["sausage"], "out": "sausage_cooked", "tool": "pan"},
	{"in": ["onion_chopped"], "out": "onion_rings", "tool": "pan"},
	{"in": ["rice", "mushroom_chopped"], "out": "risotto", "tool": "pot"},
	{"in": ["pasta", "patty", "cheese_chopped"], "out": "lasagna", "tool": "oven"},
	{"in": ["dough", "cheese_chopped", "mushroom_chopped"], "out": "funghi", "tool": "oven"},
]

## Ingredientes crus que se cortam na tábua.
const CHOPPABLE: Array[String] = ["tomato", "lettuce", "potato", "cod", "salmon", "cucumber", "cheese", "kale", "mushroom", "onion"]
## O que se pode pôr diretamente num prato, junto com outras coisas.
const PLATEABLE: Array[String] = [
	"lettuce_chopped", "tomato_chopped", "salmon_chopped", "cucumber_chopped", "cheese_chopped",
	"nori", "bun", "steak_cooked", "egg_fried", "fries", "rice_cooked", "patty_cooked",
	"bread", "tempura", "sausage_cooked", "onion_rings",
]
## Resultados do fogão que ocupam o prato inteiro.
const SOLO: Array[String] = ["soup", "caldo", "bras", "pizza", "pasta_cooked", "toast", "omelette", "mush_soup",
	"nata", "ramen", "risotto", "lasagna", "funghi"]
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


## A receita de fogão que estes ingredientes completam, ou {}. Com o dobro
## dos ingredientes dá 2 doses: o resultado traz "portions" (1 ou 2).
static func cook_match(contents: Array) -> Dictionary:
	var sorted := contents.duplicate()
	sorted.sort()
	for portions in [1, 2]:
		for cook in COOK:
			var needs: Array = []
			for k in portions:
				needs.append_array(cook["in"])
			needs.sort()
			if needs == sorted:
				var result: Dictionary = cook.duplicate()
				result["portions"] = portions
				return result
	return {}


## Estes ingredientes ainda podem vir a ser alguma receita de fogão (uma ou
## duas doses)?
static func cook_possible(contents: Array) -> bool:
	for cook in COOK:
		var left: Array = cook["in"].duplicate()
		left.append_array(cook["in"])
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
		left.append_array(cook["in"])
		var ok := true
		for id in contents:
			if not left.has(id):
				ok = false
				break
			left.erase(id)
		if ok:
			return cook["tool"]
	return "pot"


## Ingredientes crus (das caixas) que fazem falta para um conteúdo de prato,
## ex. "caldo" -> ["kale", "potato"]. As bebidas não precisam de caixas.
static func raw_for(id: String) -> Array[String]:
	var result: Array[String] = []
	if is_drink(id):
		return result
	if id.ends_with("_chopped"):
		result.append(id.trim_suffix("_chopped"))
		return result
	for cook in COOK:
		if cook["out"] == id:
			for part in cook["in"]:
				for raw in raw_for(part):
					if not result.has(raw):
						result.append(raw)
			return result
	result.append(id)
	return result
