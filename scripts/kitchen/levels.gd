class_name Levels
## Os restaurantes (níveis). Todos usam a mesma planta; mudam os ingredientes
## das caixas, os pratos pedidos e a decoração do salão. A cozinha tem duas
## zonas iguais (em cima e em baixo) com os ingredientes ao meio, para dois
## cozinheiros trabalharem ao mesmo tempo.

## Legenda: . chão, C bancada (parede no salão), a-g caixas de ingredientes
## (pela ordem de "crates"), B tábua de cortar, S fogão, P pratos limpos,
## W lava-loiça, X lixo, M mesa para 2, N/n mesa para 4 (metade de cima/baixo),
## R caixa registadora, H passe (balcão com campainha entre a cozinha e o salão,
## onde se deixam os pratos prontos), E porta de entrada dos clientes, D bar (torneira de
## bebidas na parede do salão), 1-4 início dos chefs. As pilhas de pratos do meio (P na
## coluna do passe) dão para a cozinha e para o salão.
const LAYOUT: Array[String] = [
	"CBBBSSSCCCCCCCCCCCCC",
	"C..........H.......C",
	"C..1.......H.M..N..C",
	"W......3...H....n..C",
	"P..........P.M.....D",
	"W..................C",
	"X.fabcdeg.......R..C",
	"W..........C.......C",
	"P..........P.M.....D",
	"W......4...H....N..C",
	"C..2.......H.M..n..C",
	"C..........H.......E",
	"CBBBSSSCCCCCCCCCCCCC",
]
## A cozinha (colunas 0 a 11) é igual em todos os níveis; o salão cresce de
## nível para nível: mais mesas e, a partir do 5.º, mais largo (24 colunas).
const KITCHEN_COLS := 12
## Coluna da caixa registadora no salão (a fila vai para a direita dela).
const REGISTER_CELL := Vector2i(16, 6)
## Mesas de cada nível: [largura da planta, [[x, y, células], ...]]. Uma mesa
## de N células tem 2N lugares (1 = mesa de 2, 2 = de 4, 3 = de 6, ...).
const TABLE_PLANS: Array = [
	[20, [[13, 2, 1], [13, 4, 1], [16, 2, 2]]],
	[20, [[13, 2, 1], [13, 4, 1], [13, 8, 1], [16, 2, 2]]],
	[20, [[13, 2, 1], [13, 4, 1], [13, 8, 1], [16, 2, 2], [16, 9, 2]]],
	[20, [[13, 2, 1], [13, 4, 1], [13, 8, 1], [13, 10, 1], [16, 2, 2], [16, 9, 2]]],
	[24, [[13, 2, 1], [13, 4, 1], [13, 8, 1], [13, 10, 1], [16, 2, 2], [16, 9, 2], [19, 2, 1], [19, 4, 1]]],
	[24, [[13, 2, 1], [13, 4, 1], [13, 8, 1], [13, 10, 1], [16, 2, 2], [16, 9, 2], [19, 2, 1], [19, 4, 1], [19, 8, 1], [19, 10, 1]]],
	[24, [[13, 2, 1], [13, 4, 1], [13, 8, 1], [13, 10, 1], [16, 2, 2], [16, 9, 2], [19, 2, 3], [19, 8, 1], [19, 10, 1]]],
	[24, [[13, 2, 1], [13, 4, 1], [13, 8, 1], [13, 10, 1], [16, 2, 2], [16, 9, 2], [19, 2, 3], [19, 8, 3]]],
	[24, [[13, 2, 1], [13, 4, 1], [13, 8, 1], [13, 10, 1], [16, 2, 2], [16, 9, 2], [19, 1, 4], [19, 8, 3]]],
	[24, [[13, 2, 1], [13, 4, 1], [13, 8, 1], [13, 10, 1], [16, 2, 2], [16, 9, 2], [19, 1, 5], [19, 7, 4]]],
]


## A planta de um nível (stage < 0, a Casa Aberta, usa a do último).
static func layout_for(stage: int) -> Array[String]:
	var plan: Array = TABLE_PLANS[stage if stage >= 0 and stage < TABLE_PLANS.size() else TABLE_PLANS.size() - 1]
	var width: int = plan[0]
	var rows: Array = []
	for y in LAYOUT.size():
		var row: String = LAYOUT[y].substr(0, KITCHEN_COLS)
		var dining := ""
		for x in range(KITCHEN_COLS, width):
			if y == 0 or y == LAYOUT.size() - 1:
				dining += "C"
			elif x == width - 1:
				dining += "D" if y == 4 or y == 8 else ("E" if y == LAYOUT.size() - 2 else "C")
			else:
				dining += "."
		rows.append((row + dining).split(""))
	rows[REGISTER_CELL.y][REGISTER_CELL.x] = "R"
	for t in plan[1]:
		var x: int = t[0]
		var y: int = t[1]
		var cells: int = t[2]
		if cells == 1:
			rows[y][x] = "M"
		else:
			rows[y][x] = "N"
			for k in range(1, cells):
				rows[y + k][x] = "n"
	var result: Array[String] = []
	for r in rows:
		result.append("".join(r))
	return result


## Letras das caixas de ingredientes na planta, pela ordem de "crates".
const CRATE_LETTERS := "abcdefg"

## Os restaurantes. Cada um tem 5 níveis ("stages"), do mais calmo ao mais
## cheio; cada nível escolhe os pratos, se há bebidas e o ritmo:
## "spawn" multiplica o tempo entre grupos (menos = mais clientes), "patience"
## a paciência, "points" os pontos pagos e "big" a vontade de vir em grupo.
## As caixas de cada nível saem dos pratos (ver crates_for()).
const ALL: Array[Dictionary] = [
	{"id": "classic", "drinks": ["water", "juice"], "stove": "pot", "name": "O Primeiro Dia", "place": "Restaurante do bairro", "theme": "classic",
		"crates": ["tomato", "lettuce", "bread", "cheese", "egg", "mushroom"],
		"dishes": ["salad", "soup", "toast", "omelette", "mush_soup", "bruschetta", "cheese_salad"], "stars": [60, 150, 260],
		"stages": [
			{"name": "Portas abertas", "desc": "Saladas e sopa, com calma.", "dishes": ["salad", "soup"], "bar": false, "spawn": 1.25, "patience": 1.3, "stars": [50, 130, 220]},
			{"name": "Tostas ao balcão", "desc": "Chegam as tostas mistas.", "dishes": ["salad", "soup", "toast"], "spawn": 1.1, "stars": [60, 150, 250]},
			{"name": "Pequeno-almoço", "desc": "Omeletes e tostas, sempre a sair.", "dishes": ["toast", "omelette", "salad"], "spawn": 1.0, "stars": [70, 170, 280]},
			{"name": "Dia de chuva", "desc": "Toda a gente quer sopa quente.", "dishes": ["soup", "mush_soup", "toast"], "spawn": 0.9, "patience": 0.9, "stars": [80, 190, 310]},
			{"name": "Casa cheia", "desc": "O menu todo, e o bairro todo à porta.", "dishes": ["salad", "soup", "toast", "omelette", "mush_soup"], "spawn": 0.75, "big": true, "points": 1.2, "stars": [100, 230, 380]},
			{"name": "Esplanada", "desc": "Abre a esplanada: bruschettas ao sol.", "dishes": ["salad", "toast", "omelette", "bruschetta"], "spawn": 0.85, "patience": 1.0, "big": true, "points": 1.25, "stars": [140, 320, 520]},
			{"name": "Feira do bairro", "desc": "Mais mesas e o menu todo.", "dishes": ["salad", "soup", "toast", "omelette", "mush_soup", "bruschetta"], "spawn": 0.8, "patience": 1.0, "big": true, "points": 1.3, "stars": [170, 380, 620]},
			{"name": "Jantar de grupo", "desc": "Chega a mesa grande, para 6.", "dishes": ["salad", "soup", "toast", "omelette", "mush_soup", "bruschetta", "cheese_salad"], "spawn": 0.78, "patience": 0.95, "big": true, "points": 1.35, "stars": [190, 430, 700]},
			{"name": "Aniversário", "desc": "Mesas de 6 e 8 e muita fome.", "dishes": ["salad", "soup", "toast", "omelette", "mush_soup", "bruschetta", "cheese_salad"], "spawn": 0.72, "patience": 0.95, "big": true, "points": 1.45, "stars": [210, 480, 780]},
			{"name": "Festa da rua", "desc": "O bairro inteiro: mesas de 8 e de 10.", "dishes": ["salad", "soup", "toast", "omelette", "mush_soup", "bruschetta", "cheese_salad"], "spawn": 0.66, "patience": 0.9, "big": true, "points": 1.55, "stars": [240, 540, 880]},
		]},
	{"id": "tasca", "drinks": ["wine", "coffee"], "stove": "pan", "name": "Tasca do Zé", "place": "Portugal", "theme": "portugal",
		"crates": ["steak", "egg", "potato", "cod", "kale", "bread", "dough"],
		"dishes": ["bitoque", "bras", "caldo", "prego", "nata", "bife_batatas", "pao_ovo"], "stars": [80, 200, 340],
		"stages": [
			{"name": "Prego e caldo", "desc": "O petisco da casa.", "dishes": ["prego", "caldo"], "bar": false, "spawn": 1.25, "patience": 1.3, "stars": [60, 150, 250]},
			{"name": "Almoço de domingo", "desc": "Bitoques para a família toda.", "dishes": ["bitoque", "caldo", "prego"], "spawn": 1.1, "big": true, "stars": [80, 200, 330]},
			{"name": "Hora do café", "desc": "Pastéis de nata acabados de sair.", "dishes": ["nata", "prego", "caldo"], "spawn": 1.0, "stars": [80, 190, 320]},
			{"name": "Bacalhau para todos", "desc": "Brás, bitoque e pressa.", "dishes": ["bras", "bitoque", "nata"], "spawn": 0.9, "patience": 0.9, "stars": [90, 220, 360]},
			{"name": "Santos Populares", "desc": "Noite de festa: tudo o que a tasca tem.", "dishes": ["bitoque", "bras", "caldo", "prego", "nata"], "spawn": 0.72, "big": true, "points": 1.2, "stars": [110, 260, 420]},
			{"name": "Petiscos", "desc": "Pão com ovo para acompanhar.", "dishes": ["prego", "caldo", "bitoque", "pao_ovo"], "spawn": 0.85, "patience": 1.0, "big": true, "points": 1.25, "stars": [140, 320, 520]},
			{"name": "Dia de feira", "desc": "Bife com batatas para a feira toda.", "dishes": ["bitoque", "bras", "caldo", "prego", "nata", "bife_batatas"], "spawn": 0.8, "patience": 1.0, "big": true, "points": 1.3, "stars": [170, 380, 620]},
			{"name": "Batizado", "desc": "A primeira mesa de 6.", "dishes": ["bitoque", "bras", "caldo", "prego", "nata", "bife_batatas", "pao_ovo"], "spawn": 0.78, "patience": 0.95, "big": true, "points": 1.35, "stars": [190, 430, 700]},
			{"name": "Festa da aldeia", "desc": "Mesas de 6 e 8, sempre a encher.", "dishes": ["bitoque", "bras", "caldo", "prego", "nata", "bife_batatas", "pao_ovo"], "spawn": 0.72, "patience": 0.95, "big": true, "points": 1.45, "stars": [210, 480, 780]},
			{"name": "Casamento minhoto", "desc": "Mesas de 8 e de 10: a família toda.", "dishes": ["bitoque", "bras", "caldo", "prego", "nata", "bife_batatas", "pao_ovo"], "spawn": 0.66, "patience": 0.9, "big": true, "points": 1.55, "stars": [240, 540, 880]},
		]},
	{"id": "sushi", "drinks": ["tea", "water"], "stove": "pot", "name": "Sakura Sushi", "place": "Japão", "theme": "japan",
		"crates": ["rice", "salmon", "nori", "cucumber", "shrimp", "noodles", "egg"],
		"dishes": ["sashimi", "nigiri", "maki", "tempura", "ramen", "uramaki", "onigiri", "tamago"], "stars": [70, 180, 300],
		"stages": [
			{"name": "Balcão de sushi", "desc": "Sashimi e nigiri.", "dishes": ["sashimi", "nigiri"], "bar": false, "spawn": 1.25, "patience": 1.3, "stars": [50, 130, 220]},
			{"name": "Rolos", "desc": "Aprendam a enrolar maki.", "dishes": ["sashimi", "nigiri", "maki"], "spawn": 1.1, "stars": [70, 180, 300]},
			{"name": "Fritos", "desc": "Tempura estaladiço e uramaki.", "dishes": ["tempura", "uramaki", "nigiri"], "spawn": 1.0, "stars": [80, 190, 320]},
			{"name": "Noite de ramen", "desc": "Taças de ramen a fumegar.", "dishes": ["ramen", "maki", "tempura"], "spawn": 0.9, "patience": 0.9, "stars": [90, 210, 350]},
			{"name": "Hanami", "desc": "Festa das cerejeiras: casa cheia.", "dishes": ["sashimi", "nigiri", "maki", "tempura", "ramen", "uramaki"], "spawn": 0.72, "big": true, "points": 1.2, "stars": [110, 260, 420]},
			{"name": "Bento", "desc": "Onigiri para levar.", "dishes": ["sashimi", "nigiri", "maki", "onigiri"], "spawn": 0.85, "patience": 1.0, "big": true, "points": 1.25, "stars": [140, 320, 520]},
			{"name": "Festival", "desc": "Mais mesas e o menu todo.", "dishes": ["sashimi", "nigiri", "maki", "tempura", "ramen", "uramaki", "onigiri"], "spawn": 0.8, "patience": 1.0, "big": true, "points": 1.3, "stars": [170, 380, 620]},
			{"name": "Tamago", "desc": "Nigiri de omelete e uma mesa de 6.", "dishes": ["sashimi", "nigiri", "maki", "tempura", "ramen", "uramaki", "onigiri", "tamago"], "spawn": 0.78, "patience": 0.95, "big": true, "points": 1.35, "stars": [190, 430, 700]},
			{"name": "Ano novo", "desc": "Mesas de 6 e 8 a celebrar.", "dishes": ["sashimi", "nigiri", "maki", "tempura", "ramen", "uramaki", "onigiri", "tamago"], "spawn": 0.72, "patience": 0.95, "big": true, "points": 1.45, "stars": [210, 480, 780]},
			{"name": "Matsuri", "desc": "Mesas de 8 e de 10: a festa maior.", "dishes": ["sashimi", "nigiri", "maki", "tempura", "ramen", "uramaki", "onigiri", "tamago"], "spawn": 0.66, "patience": 0.9, "big": true, "points": 1.55, "stars": [240, 540, 880]},
		]},
	{"id": "diner", "drinks": ["soda", "shake"], "stove": "pan", "name": "Rocket Diner", "place": "Estados Unidos", "theme": "diner",
		"crates": ["bun", "patty", "lettuce", "cheese", "potato", "sausage", "onion"],
		"dishes": ["burger", "cheeseburger", "fries", "hotdog", "rings", "cheese_fries", "onion_burger", "combo"], "stars": [80, 200, 340],
		"stages": [
			{"name": "Abertura", "desc": "Hambúrgueres e batatas.", "dishes": ["burger", "fries"], "bar": false, "spawn": 1.25, "patience": 1.3, "stars": [60, 150, 250]},
			{"name": "Cachorros", "desc": "Chegam os cachorros-quentes.", "dishes": ["hotdog", "fries", "burger"], "spawn": 1.1, "stars": [80, 190, 320]},
			{"name": "Tudo com queijo", "desc": "Cheeseburgers e batatas com queijo.", "dishes": ["cheeseburger", "cheese_fries", "rings"], "spawn": 1.0, "stars": [80, 200, 330]},
			{"name": "Drive-in", "desc": "Rápido, rápido, que o filme começa.", "dishes": ["burger", "hotdog", "rings", "fries"], "spawn": 0.85, "patience": 0.85, "stars": [90, 220, 360]},
			{"name": "Rock and roll", "desc": "Noite de jukebox: o menu todo.", "dishes": ["burger", "cheeseburger", "fries", "hotdog", "rings", "cheese_fries"], "spawn": 0.72, "big": true, "points": 1.2, "stars": [110, 260, 420]},
			{"name": "Cesto misto", "desc": "Batatas e anéis no mesmo cesto.", "dishes": ["burger", "fries", "rings", "combo"], "spawn": 0.85, "patience": 1.0, "big": true, "points": 1.25, "stars": [140, 320, 520]},
			{"name": "Sábado à noite", "desc": "Hambúrguer de cebola e o menu todo.", "dishes": ["burger", "cheeseburger", "fries", "hotdog", "rings", "cheese_fries", "onion_burger"], "spawn": 0.8, "patience": 1.0, "big": true, "points": 1.3, "stars": [170, 380, 620]},
			{"name": "Equipa de futebol", "desc": "Chega a mesa de 6.", "dishes": ["burger", "cheeseburger", "fries", "hotdog", "rings", "cheese_fries", "onion_burger", "combo"], "spawn": 0.78, "patience": 0.95, "big": true, "points": 1.35, "stars": [190, 430, 700]},
			{"name": "Baile de finalistas", "desc": "Mesas de 6 e 8.", "dishes": ["burger", "cheeseburger", "fries", "hotdog", "rings", "cheese_fries", "onion_burger", "combo"], "spawn": 0.72, "patience": 0.95, "big": true, "points": 1.45, "stars": [210, 480, 780]},
			{"name": "Quatro de Julho", "desc": "Mesas de 8 e de 10: fogo de artifício.", "dishes": ["burger", "cheeseburger", "fries", "hotdog", "rings", "cheese_fries", "onion_burger", "combo"], "spawn": 0.66, "patience": 0.9, "big": true, "points": 1.55, "stars": [240, 540, 880]},
		]},
	{"id": "trattoria", "drinks": ["wine", "coffee"], "stove": "oven", "name": "Trattoria Nonna", "place": "Itália", "theme": "italy",
		"crates": ["dough", "tomato", "cheese", "pasta", "patty", "rice", "mushroom"],
		"dishes": ["pizza", "spaghetti", "caprese", "risotto", "lasagna", "funghi", "polpette", "funghi_salad"], "stars": [80, 200, 340],
		"stages": [
			{"name": "Antipasti", "desc": "Caprese e esparguete.", "dishes": ["caprese", "spaghetti"], "bar": false, "spawn": 1.25, "patience": 1.3, "stars": [50, 140, 230]},
			{"name": "Forno a lenha", "desc": "As primeiras pizzas.", "dishes": ["pizza", "caprese", "spaghetti"], "spawn": 1.1, "stars": [80, 190, 320]},
			{"name": "Receitas da Nonna", "desc": "Lasanha e risotto, devagarinho.", "dishes": ["lasagna", "risotto", "caprese"], "spawn": 1.0, "patience": 1.1, "stars": [80, 200, 330]},
			{"name": "Noite das pizzas", "desc": "Margherita e funghi sem parar.", "dishes": ["pizza", "funghi", "spaghetti"], "spawn": 0.85, "patience": 0.9, "stars": [90, 220, 360]},
			{"name": "Casamento", "desc": "A família toda à mesa: o menu todo.", "dishes": ["pizza", "spaghetti", "caprese", "risotto", "lasagna", "funghi"], "spawn": 0.72, "big": true, "points": 1.2, "stars": [110, 260, 420]},
			{"name": "Polpette", "desc": "As almôndegas da Nonna.", "dishes": ["pizza", "spaghetti", "caprese", "polpette"], "spawn": 0.85, "patience": 1.0, "big": true, "points": 1.25, "stars": [140, 320, 520]},
			{"name": "Domingo em família", "desc": "Mais mesas e o menu todo.", "dishes": ["pizza", "spaghetti", "caprese", "risotto", "lasagna", "funghi", "polpette"], "spawn": 0.8, "patience": 1.0, "big": true, "points": 1.3, "stars": [170, 380, 620]},
			{"name": "Insalata", "desc": "Salada de cogumelos e uma mesa de 6.", "dishes": ["pizza", "spaghetti", "caprese", "risotto", "lasagna", "funghi", "polpette", "funghi_salad"], "spawn": 0.78, "patience": 0.95, "big": true, "points": 1.35, "stars": [190, 430, 700]},
			{"name": "Festa da vindima", "desc": "Mesas de 6 e 8.", "dishes": ["pizza", "spaghetti", "caprese", "risotto", "lasagna", "funghi", "polpette", "funghi_salad"], "spawn": 0.72, "patience": 0.95, "big": true, "points": 1.45, "stars": [210, 480, 780]},
			{"name": "Ferragosto", "desc": "Mesas de 8 e de 10: a Itália toda.", "dishes": ["pizza", "spaghetti", "caprese", "risotto", "lasagna", "funghi", "polpette", "funghi_salad"], "spawn": 0.66, "patience": 0.9, "big": true, "points": 1.55, "stars": [240, 540, 880]},
		]},
]
## Níveis por restaurante.
const STAGES := 10

## Nome de cada ingrediente (para as caixas e o tutorial).
const INGREDIENT_NAMES := {
	"tomato": "Tomate", "lettuce": "Alface", "steak": "Bife", "egg": "Ovos", "potato": "Batatas",
	"cod": "Bacalhau", "kale": "Couve", "rice": "Arroz", "salmon": "Salmão", "nori": "Alga",
	"cucumber": "Pepino", "bun": "Pão", "patty": "Carne", "cheese": "Queijo", "pasta": "Esparguete",
	"dough": "Massa", "bread": "Pão", "mushroom": "Cogumelos", "shrimp": "Camarão", "noodles": "Noodles",
	"sausage": "Salsichas", "onion": "Cebolas",
}


## Nome do que sai do fogão.
const PRODUCT_NAMES := {
	"soup": "Sopa", "caldo": "Caldo verde", "steak_cooked": "Bife grelhado", "egg_fried": "Ovo estrelado",
	"fries": "Batata frita", "bras": "Bacalhau à Brás", "rice_cooked": "Arroz cozido", "patty_cooked": "Carne grelhada",
	"pizza": "Pizza", "pasta_cooked": "Esparguete cozido",
	"toast": "Tosta mista", "omelette": "Omelete", "mush_soup": "Creme de cogumelos", "nata": "Pastel de nata",
	"tempura": "Tempura", "ramen": "Ramen", "sausage_cooked": "Salsicha grelhada", "onion_rings": "Anéis de cebola",
	"risotto": "Risotto", "lasagna": "Lasanha", "funghi": "Pizza de cogumelos",
	"water": "Água", "juice": "Sumo de laranja", "wine": "Vinho", "coffee": "Café", "tea": "Chá verde",
	"soda": "Refrigerante", "shake": "Batido",
}
## Nome de um ingrediente no singular (para o que se leva na mão).
const SINGULAR := {"egg": "Ovo", "potato": "Batata", "mushroom": "Cogumelo", "sausage": "Salsicha", "onion": "Cebola"}


## Nome de um conteúdo, ex. "potato_chopped" -> "Batata cortada".
static func content_name(id: String) -> String:
	if PRODUCT_NAMES.has(id):
		return PRODUCT_NAMES[id]
	var raw := id.trim_suffix("_chopped")
	var name: String = SINGULAR.get(raw, INGREDIENT_NAMES.get(raw, raw))
	if id.ends_with("_chopped"):
		# Concorda com o género: "Batata cortada", "Bacalhau cortado".
		name += " cortada" if name.ends_with("a") or name == "Couve" or name == "Alface" else " cortado"
	return name


## Nome do que um chef leva: ingrediente, prato (o nome do prato se estiver
## completo) ou panela com o que tem dentro.
static func item_name(item: Item) -> String:
	if item == null:
		return ""
	if item.is_ingredient():
		return ("%d× " % item.count if item.count > 1 else "") + content_name(item.content_id())
	if item.is_glass():
		var drink := content_name(item.contents[0]) if not item.contents.is_empty() else "Copo"
		return drink + (" e " + item_name(item.second) if item.second else "")
	if item.is_plate():
		if item.dirty:
			return "Pratos sujos" if item.stack > 1 else "Prato sujo"
		if item.contents.is_empty():
			return "%d pratos" % item.stack if item.stack > 1 else "Prato vazio"
		var dish := Recipes.match_plate(item.contents)
		var text: String = dish["name"] if not dish.is_empty() else " + ".join(item.contents.map(content_name))
		if item.second:
			text += " e " + item_name(item.second)
		return text
	if item.is_cookware():
		var tool: String = {"pot": "Panela", "pan": "Frigideira", "oven": "Forno"}.get(item.tool, "Panela")
		match item.cook_state:
			Item.Cook.READY:
				if item.portions > 1:
					return "%s: %d× %s (2 pratos)" % [tool, item.portions, content_name(item.product)]
				return "%s: %s pronto" % [tool, content_name(item.product)]
			Item.Cook.BURNT:
				return "%s: queimado!" % tool
		if item.contents.is_empty():
			return tool
		return "%s: %s" % [tool, " + ".join(item.contents.map(content_name))]
	return ""


static func get_level(index: int) -> Dictionary:
	return ALL[clampi(index, 0, ALL.size() - 1)]


## Um nível jogável: o restaurante `index` com as regras do nível `stage`
## (0 a 4). stage < 0 é a Casa Aberta, com o menu todo. O "id" é o do
## restaurante no primeiro nível (para manter as estrelas antigas) e
## "<restaurante>_<n>" nos outros.
static func build(index: int, stage: int) -> Dictionary:
	var rest: Dictionary = get_level(index)
	var level := rest.duplicate(true)
	level.erase("stages")
	level["restaurant"] = rest["id"]
	level["stage"] = stage
	level["spawn"] = 1.0
	level["patience"] = 1.0
	level["points"] = 1.0
	level["big"] = false
	if stage >= 0:
		var st: Dictionary = rest["stages"][clampi(stage, 0, STAGES - 1)]
		for key in st:
			if key != "name":
				level[key] = st[key]
		level["id"] = stage_id(index, stage)
		level["stage_name"] = st["name"]
	level["crates"] = crates_for(rest, level["dishes"])
	level["layout"] = layout_for(stage)
	return level


## Id onde se guardam as estrelas de um nível.
static func stage_id(index: int, stage: int) -> String:
	var rid: String = get_level(index)["id"]
	return rid if stage <= 0 else "%s_%d" % [rid, stage + 1]


## As caixas que estes pratos precisam, pela ordem das caixas do restaurante
## (no máximo 7: são as letras a-g da planta).
static func crates_for(rest: Dictionary, dish_ids: Array) -> Array:
	var needed: Array[String] = []
	for id in dish_ids:
		for content in Recipes.by_id(id).get("needs", []):
			for raw in Recipes.raw_for(content):
				if not needed.has(raw):
					needed.append(raw)
	var result := []
	for raw in rest["crates"]:
		if needed.has(raw):
			result.append(raw)
	for raw in needed:
		if not result.has(raw):
			result.append(raw)
	return result.slice(0, CRATE_LETTERS.length())


## Pratos que se pedem neste nível.
static func drinks(level: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# Nos primeiros níveis ninguém pede bebidas (o bar fica lá na mesma).
	if not level.get("bar", true):
		return result
	for id in level.get("drinks", []):
		result.append(Recipes.by_id(id))
	return result


static func dishes(level: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in level["dishes"]:
		result.append(Recipes.by_id(id))
	return result
