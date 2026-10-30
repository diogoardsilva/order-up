class_name Levels
## Os restaurantes (níveis). Todos usam a mesma planta; mudam os ingredientes
## das caixas, os pratos pedidos e a decoração do salão.

## Legenda: . chão, C bancada (parede no salão), a-e caixas de ingredientes
## (pela ordem de "crates"), B tábua de cortar, S fogão, P pratos limpos,
## W lava-loiça, X lixo, M mesa para 2, N/n mesa para 4 (metade de cima/baixo),
## R caixa registadora, E porta de entrada dos clientes, 1-4 início dos chefs.
const LAYOUT: Array[String] = [
	"CabcdeCBBSSCCCCCCCCC",
	"C..........C.......C",
	"P..1.......C.M..N..C",
	"P..........C....n..C",
	"W.....3....C.M.....C",
	"W.....CCC..........C",
	"X.....CBC.......R..C",
	"C..........C.......C",
	"C..........C.M.....C",
	"C..2.......C....N..C",
	"C.....4....C.M..n..C",
	"C..........C.......E",
	"CCCBBCCCSSCCCCCCCCCC",
]

const ALL: Array[Dictionary] = [
	{"id": "classic", "stove": "pot", "name": "O Primeiro Dia", "place": "Restaurante do bairro", "theme": "classic",
		"crates": ["tomato", "lettuce"], "dishes": ["salad", "soup"], "stars": [60, 150, 260]},
	{"id": "tasca", "stove": "pan", "name": "Tasca do Zé", "place": "Portugal", "theme": "portugal",
		"crates": ["steak", "egg", "potato", "cod", "kale"], "dishes": ["bitoque", "bras", "caldo"], "stars": [80, 200, 340]},
	{"id": "sushi", "stove": "pot", "name": "Sakura Sushi", "place": "Japão", "theme": "japan",
		"crates": ["rice", "salmon", "nori", "cucumber"], "dishes": ["sashimi", "nigiri", "maki"], "stars": [70, 180, 300]},
	{"id": "diner", "stove": "pan", "name": "Rocket Diner", "place": "Estados Unidos", "theme": "diner",
		"crates": ["bun", "patty", "lettuce", "cheese", "potato"], "dishes": ["burger", "cheeseburger", "fries"], "stars": [80, 200, 340]},
	{"id": "trattoria", "stove": "oven", "name": "Trattoria Nonna", "place": "Itália", "theme": "italy",
		"crates": ["dough", "tomato", "cheese", "pasta"], "dishes": ["pizza", "spaghetti", "caprese"], "stars": [80, 200, 340]},
]

## Nome de cada ingrediente (para as caixas e o tutorial).
const INGREDIENT_NAMES := {
	"tomato": "Tomate", "lettuce": "Alface", "steak": "Bife", "egg": "Ovos", "potato": "Batatas",
	"cod": "Bacalhau", "kale": "Couve", "rice": "Arroz", "salmon": "Salmão", "nori": "Alga",
	"cucumber": "Pepino", "bun": "Pão", "patty": "Carne", "cheese": "Queijo", "pasta": "Esparguete",
	"dough": "Massa",
}


static func get_level(index: int) -> Dictionary:
	return ALL[clampi(index, 0, ALL.size() - 1)]


## Pratos que se pedem neste nível.
static func dishes(level: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in level["dishes"]:
		result.append(Recipes.by_id(id))
	return result
