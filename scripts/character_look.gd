class_name CharacterLook
## Boneco personalizável: pele, cabelo (estilo e cor), cara (bigode, barba,
## óculos...) e uma cor especial que aparece na roupa. A roupa muda com a
## função (Livre, Cozinheiro, Ajudante de cozinha, Empregado de mesa, Host,
## Barman). As folhas de sprites (16x24, 3 direções x 3 passos, como as
## antigas de tools/make_sprites.py) são montadas aqui a partir de pixel art
## em texto, com contorno automático, e ficam em cache.
##
## Um "look" é um Dictionary pequeno (vai na conta online e pela rede):
## {"skin": int, "hair": int, "hair_color": int, "face": int, "accent": int}

const FRAME := Vector2i(16, 24)
const OUTLINE := Color("3b2027")

const SKINS: Array = [
	["Muito clara", "ffe3c4", "f2b98f"], ["Clara", "ffd7a8", "efa877"], ["Morena", "e8b07a", "c8834f"],
	["Média", "d39260", "ac6a3c"], ["Escura", "97603c", "74452a"], ["Muito escura", "6b4229", "4e2e1b"],
]
const HAIR_STYLES: Array[String] = ["Curto", "Comprido", "Carrapito", "Rabo de cavalo", "Encaracolado", "Rapado", "Careca"]
const HAIR_COLORS: Array = [
	["Castanho", "8a4e2a", "5e321c"], ["Loiro", "f2c45a", "c88f32"], ["Preto", "3d3045", "241c2b"],
	["Ruivo", "d8642e", "9e3e1c"], ["Grisalho", "cfc8d6", "958ca0"], ["Roxo", "b07ad8", "7e4fa6"],
	["Rosa", "f28ab0", "c45a84"], ["Azul", "5aa8e0", "3a70a8"], ["Verde", "7cc46a", "4c8a42"],
	["Castanho escuro", "5a3a2a", "3a2418"],
]
const FACES: Array[String] = ["Nada", "Bigode", "Barba", "Sardas", "Óculos", "Óculos e barba"]
## A cor especial: aparece no lenço, no avental, no laço, na gravata, no boné...
const ACCENTS: Array = [
	["Vermelho", "e8574d"], ["Laranja", "f0914e"], ["Amarelo", "f2c94c"], ["Verde", "6fcf6a"],
	["Menta", "5fd6b8"], ["Azul", "4d9be8"], ["Anil", "6a6ee8"], ["Roxo", "a874e0"],
	["Rosa", "f07ab8"], ["Coral", "ff8a7a"], ["Dourado", "d9a538"], ["Preto", "3a3540"],
]
## Roupa de cada função (o mesmo índice de GameState.PLAYER_ROLES).
const OUTFIT_NAMES: Array[String] = ["Livre", "Cozinheiro", "Ajudante de cozinha", "Empregado de mesa", "Host", "Barman"]

## Cabeça (linhas 0-6) quando não há chapéu, por estilo de cabelo.
const HAIR_TOP := {
	"curto": [
		"................",
		"................",
		"................",
		"....hhhhhhhh....",
		"...hhhhhhhhhH...",
		"...hhhhhhhhhH...",
		"...hhhhhhhhHH...",
	],
	"carrapito": [
		"................",
		"......hhhH......",
		".....hhhhHH.....",
		"....hhhhhhhH....",
		"...hhhhhhhhhH...",
		"...hhhhhhhhhH...",
		"...hhhhhhhhHH...",
	],
	"encaracolado": [
		"................",
		"................",
		".....hhHhhH.....",
		"...hhhhhhhhhH...",
		"..hhHhhhHhhhhH..",
		"..hhhhhhhhhhHH..",
		"..hhhhHhhhhHhH..",
	],
	"rapado": [
		"................",
		"................",
		"................",
		"................",
		"....hhhhhhhh....",
		"...hhhhhhhhhH...",
		"...hhhhhhhhhH...",
	],
	"careca": [
		"................",
		"................",
		"................",
		"................",
		"....ssssssss....",
		"...sssssssssS...",
		"...ssssssssSS...",
	],
}
const FACE_DOWN := [
	"...hssssssssh...",
	"...ssessssesS...",
	"...ssessssesS...",
	"...scsssssscS...",
	"....SssmmssS....",
	".....SSSSSS.....",
]
const FACE_UP := [
	"...hhhhhhhhhh...",
	"...hhhhhhhhhH...",
	"...hhhhhhhhhH...",
	"...hhhhhhhhHH...",
	"....HhhhhhhH....",
	".....SSSSSS.....",
]
const FACE_SIDE := [
	"...hhhhssssss...",
	"...hhhsssssess..",
	"...hhhsssssess..",
	"...hhSssssscss..",
	"....hSsssssSs...",
	".....SSSSS......",
]
## Corpo (linhas 13-19). Letras: o/O roupa, k/K painel da frente, d botões,
## a/A cor especial, s mãos.
const BODY_DOWN := [
	"...ooonnnnooo...",
	"..ooooonnooooO..",
	".ooooodoodoooOO.",
	".ooookkkkkkkoOO.",
	".sOokkkkkkkkOOs.",
	"..OokkkkkkkkOO..",
	"...oKKKKKKKKO...",
]
const BODY_UP := [
	"...oooooooooo...",
	"..oooooooooooO..",
	".ooooooooooooOO.",
	".oooooooooooOOO.",
	".sooooooooooOOs.",
	"..OooooooooOO...",
	"...oooooooooO...",
]
const BODY_SIDE := [
	"....ooooonn.....",
	"....oooooonk....",
	"...oOoooooookk..",
	"...oOoooookkk...",
	"...oOssoookkk...",
	"...OOssookkKK...",
	"....OOOOKKKK....",
]
const LEGS_DOWN := [
	["....pppppppP....", "....ppP..ppP....", "....bbb..bbb....", "................"],
	["....pppppppP....", "....ppP...pP....", "....bbb.........", "................"],
	["....pppppppP....", "....pP...ppP....", ".........bbb....", "................"],
]
const LEGS_SIDE := [
	[".....ppppP......", ".....ppPpP......", ".....bbbbbb.....", "................"],
	["....pppppPP.....", "...ppP...pP.....", "...bbb...bbb....", "................"],
	[".....ppppP......", "......ppP.......", "......bbbb......", "................"],
]
const HATS := {
	"toque": [
		"................",
		"....wwwwwwww....",
		"...wwwwwwwwwW...",
		"..wwwwwwwwwwWW..",
		"..wwwwwwwwwwWW..",
		"...WwwwwwwwWW...",
		"...aaaaaaaaAA...",
	],
	"bandana": [
		"................",
		"................",
		"................",
		"....aaaaaaaa....",
		"...aawaaaawaA...",
		"...aaaaawaaaA...",
		"...AAAAAAAAAA...",
	],
	"bone": [
		"................",
		"................",
		"................",
		"....aaaaaaaa....",
		"...aaaaaaaaaA...",
		"...aaaaaaaaaAA..",
		"..AAAAAAAAAAAAA.",
	],
}

## Roupa por função: chapéu (ou "" = cabelo), cores de o/O (roupa), k/K (frente),
## n (gola), d (botões), p/P (calças), b (sapatos). "a"/"A" = cor especial.
const OUTFITS: Array = [
	{"hat": "", "o": "a", "O": "A", "k": "a", "K": "6b3a1f", "n": "a", "d": "a", "p": "4a6a9c", "P": "34507a", "b": "e8e4ec"},
	{"hat": "toque", "o": "ffffff", "O": "d9d3e6", "k": "a", "K": "A", "n": "a", "d": "aaa2c0", "p": "5a5560", "P": "423e48", "b": "2a262f"},
	{"hat": "bandana", "o": "8fa8c0", "O": "6a7f98", "k": "f1eef6", "K": "c9c2d6", "n": "8fa8c0", "d": "6a7f98", "p": "4a3a5c", "P": "352a45", "b": "5c3420"},
	{"hat": "", "o": "2e2a36", "O": "1f1c26", "k": "f1eef6", "K": "d9d3e6", "n": "a", "d": "f2c94c", "p": "2a262f", "P": "1d1a21", "b": "1d1a21"},
	{"hat": "", "o": "34385a", "O": "252842", "k": "f1eef6", "K": "d9d3e6", "n": "a", "d": "a", "p": "2a2c44", "P": "1e2034", "b": "1d1a21"},
	{"hat": "bone", "o": "35303f", "O": "25212c", "k": "a", "K": "A", "n": "35303f", "d": "a", "p": "3d5a84", "P": "2c4266", "b": "5c3420"},
]

static var _cache := {}


## Boneco ao acaso (para perfis novos).
static func random() -> Dictionary:
	return {"skin": randi() % SKINS.size(), "hair": randi() % 5, "hair_color": randi() % HAIR_COLORS.size(),
		"face": [0, 0, 0, 1, 2, 3, 4].pick_random(), "accent": randi() % ACCENTS.size()}


## Os seis bonecos de antes (Rui, Bia, Tó, Inês, Zé, Mia), para convidados e ajudantes.
static func preset(i: int) -> Dictionary:
	var list := [
		{"skin": 1, "hair": 0, "hair_color": 0, "face": 0, "accent": 0},
		{"skin": 1, "hair": 1, "hair_color": 1, "face": 3, "accent": 5},
		{"skin": 2, "hair": 0, "hair_color": 2, "face": 1, "accent": 2},
		{"skin": 4, "hair": 3, "hair_color": 9, "face": 0, "accent": 3},
		{"skin": 3, "hair": 4, "hair_color": 3, "face": 2, "accent": 7},
		{"skin": 1, "hair": 2, "hair_color": 5, "face": 4, "accent": 8},
	]
	return list[posmod(i, list.size())].duplicate()


const PRESET_NAMES: Array[String] = ["Rui", "Bia", "Tó", "Inês", "Zé", "Mia"]


## Garante que os valores existem (vem do disco ou da internet).
static func clean(look: Variant) -> Dictionary:
	var src: Dictionary = look if look is Dictionary else {}
	var out := preset(0)
	var sizes := {"skin": SKINS.size(), "hair": HAIR_STYLES.size(), "hair_color": HAIR_COLORS.size(),
		"face": FACES.size(), "accent": ACCENTS.size()}
	for k in sizes:
		if src.has(k):
			out[k] = posmod(int(src[k]), sizes[k])
	return out


static func accent_color(look: Dictionary) -> Color:
	return Color(ACCENTS[posmod(int(look.get("accent", 0)), ACCENTS.size())][1])


## Nome da opção atual de um campo (para os menus).
static func value_name(look: Dictionary, key: String) -> String:
	var v := int(look.get(key, 0))
	match key:
		"skin": return SKINS[posmod(v, SKINS.size())][0]
		"hair": return HAIR_STYLES[posmod(v, HAIR_STYLES.size())]
		"hair_color": return HAIR_COLORS[posmod(v, HAIR_COLORS.size())][0]
		"face": return FACES[posmod(v, FACES.size())]
		"accent": return ACCENTS[posmod(v, ACCENTS.size())][0]
	return ""


static func count(key: String) -> int:
	return {"skin": SKINS.size(), "hair": HAIR_STYLES.size(), "hair_color": HAIR_COLORS.size(),
		"face": FACES.size(), "accent": ACCENTS.size()}.get(key, 1)


## Folha do boneco com a roupa de uma função: [cor, silhueta branca].
static func sheets(look: Dictionary, outfit: int) -> Array:
	var l := clean(look)
	outfit = posmod(outfit, OUTFITS.size())
	var key := "%d.%d.%d.%d.%d.%d" % [l["skin"], l["hair"], l["hair_color"], l["face"], l["accent"], outfit]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(FRAME.x * 3, FRAME.y * 3, false, Image.FORMAT_RGBA8)
	var pal := _palette(l, outfit)
	for d in 3:
		for step in 3:
			var rows := _frame_rows(l, outfit, d, step)
			_paint(img, rows, pal, Vector2i(step * FRAME.x, d * FRAME.y))
	var sil := img.duplicate() as Image
	for y in sil.get_height():
		for x in sil.get_width():
			if sil.get_pixel(x, y).a > 0.0:
				sil.set_pixel(x, y, Color.WHITE)
	var result := [ImageTexture.create_from_image(img), ImageTexture.create_from_image(sil)]
	_cache[key] = result
	return result


## Desenha um passo do boneco (como Art.frame).
static func draw(ci: CanvasItem, look: Dictionary, outfit: int, col: int, row: int, top_left: Vector2,
		flip := false, modulate := Color.WHITE) -> void:
	Art.frame(ci, sheets(look, outfit)[0], FRAME, col, row, top_left, flip, modulate)


static func draw_silhouette(ci: CanvasItem, look: Dictionary, outfit: int, col: int, row: int, top_left: Vector2,
		flip := false, modulate := Color.WHITE) -> void:
	Art.frame(ci, sheets(look, outfit)[1], FRAME, col, row, top_left, flip, modulate)


static func _palette(l: Dictionary, outfit: int) -> Dictionary:
	var skin: Array = SKINS[l["skin"]]
	var hair: Array = HAIR_COLORS[l["hair_color"]]
	var accent := accent_color(l)
	var pal := {
		"s": Color(skin[1]), "S": Color(skin[2]), "e": Color("3b2027"), "c": Color("f48a7a"), "m": Color("b8504a"),
		"h": Color(hair[1]), "H": Color(hair[2]), "a": accent, "A": accent.darkened(0.3),
		"w": Color("ffffff"), "W": Color("d9d3e6"), "g": Color("2a262f"), "f": Color(skin[2]).darkened(0.15),
	}
	var o: Dictionary = OUTFITS[outfit]
	for k in ["o", "O", "k", "K", "n", "d", "p", "P", "b"]:
		var v: String = o[k]
		pal[k] = pal[v] if pal.has(v) and v.length() == 1 else Color(v)
	return pal


static func _put(rows: Array, x: int, y: int, ch: String) -> void:
	var r: String = rows[y]
	rows[y] = r.substr(0, x) + ch + r.substr(x + 1)


## As 24 linhas de texto de um passo: d = 0 de frente, 1 de costas, 2 de lado.
static func _frame_rows(l: Dictionary, outfit: int, d: int, step: int) -> Array:
	var style: String = ["curto", "curto", "carrapito", "curto", "encaracolado", "rapado", "careca"][l["hair"]]
	var hat: String = OUTFITS[outfit]["hat"]
	var top: Array = (HATS[hat] if hat != "" else HAIR_TOP[style]).duplicate()
	var face: Array = [FACE_DOWN, FACE_UP, FACE_SIDE][d].duplicate()
	var body: Array = [BODY_DOWN, BODY_UP, BODY_SIDE][d].duplicate()
	var legs: Array = (LEGS_SIDE if d == 2 else LEGS_DOWN)[step]
	var rows: Array = top + face + body + legs
	var bald := style == "careca"
	if bald and hat == "":
		for y in range(7, 13):
			rows[y] = (rows[y] as String).replace("h", "s").replace("H", "S")
	if hat == "bone" and d == 2:
		# O boné de lado: a pala para a frente.
		rows[6] = "...AAAAAAAAAAAA."
	# Cabelo comprido / rabo de cavalo / caracóis por cima dos ombros.
	match style:
		"curto":
			if l["hair"] == 1:
				_long_hair(rows, d)
			elif l["hair"] == 3:
				_ponytail(rows, d)
		"encaracolado":
			if d == 0:
				for y in range(7, 10):
					_put(rows, 2, y, "h"); _put(rows, 13, y, "H")
			elif d == 2:
				for y in range(7, 11):
					_put(rows, 2, y, "h")
	# Cara: bigode, barba, sardas, óculos (não se veem de costas).
	var f: int = l["face"]
	if d != 1:
		if f == 1:
			if d == 0:
				for x in range(6, 10):
					_put(rows, x, 10, "H")
			else:
				_put(rows, 11, 11, "H"); _put(rows, 12, 11, "H")
		if f == 2 or f == 5:
			if d == 0:
				for x in range(5, 11):
					_put(rows, x, 11, "h")
				for x in range(6, 10):
					_put(rows, x, 12, "H")
				_put(rows, 4, 10, "h"); _put(rows, 11, 10, "H")
				_put(rows, 7, 11, "m"); _put(rows, 8, 11, "m")
			else:
				for x in range(6, 12):
					_put(rows, x, 11, "h")
				for x in range(7, 11):
					_put(rows, x, 12, "H")
		if f == 3:
			if d == 0:
				_put(rows, 4, 9, "f"); _put(rows, 11, 9, "f"); _put(rows, 5, 10, "f"); _put(rows, 10, 10, "f")
			else:
				_put(rows, 10, 10, "f"); _put(rows, 12, 10, "f")
		if f == 4 or f == 5:
			if d == 0:
				for x in [4, 6, 7, 8, 9, 11]:
					_put(rows, x, 8, "g")
			else:
				for x in [10, 11, 13]:
					_put(rows, x, 8, "g")
	# Detalhes da roupa: laço do empregado, gravata do host, avental de lado.
	if d == 0:
		if outfit == 3:
			_put(rows, 6, 13, "A"); _put(rows, 7, 13, "a"); _put(rows, 8, 13, "a"); _put(rows, 9, 13, "A")
		elif outfit == 4:
			for y in range(13, 18):
				_put(rows, 7, y, "a"); _put(rows, 8, y, "A")
	return rows


static func _long_hair(rows: Array, d: int) -> void:
	if d == 0:
		for y in range(7, 12):
			_put(rows, 2, y, "h"); _put(rows, 13, y, "H")
	elif d == 1:
		for y in [12, 13, 14]:
			for x in range(5, 11):
				_put(rows, x, y, "h" if y < 14 else "H")
	else:
		for y in range(7, 13):
			_put(rows, 2, y, "h")
		_put(rows, 3, 13, "H"); _put(rows, 3, 12, "h")


static func _ponytail(rows: Array, d: int) -> void:
	if d == 1:
		for y in [12, 13, 14, 15]:
			_put(rows, 7, y, "h"); _put(rows, 8, y, "H")
	elif d == 2:
		_put(rows, 2, 7, "h"); _put(rows, 1, 8, "h"); _put(rows, 1, 9, "h"); _put(rows, 1, 10, "H"); _put(rows, 2, 10, "H")


static func _paint(img: Image, rows: Array, pal: Dictionary, at: Vector2i) -> void:
	var mask := {}
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			var ch := r[x]
			if ch == "." or not pal.has(ch):
				continue
			img.set_pixel(at.x + x, at.y + y, pal[ch])
			mask[Vector2i(x, y)] = true
	# Contorno de 1 pixel à volta da silhueta.
	for y in FRAME.y:
		for x in FRAME.x:
			if mask.has(Vector2i(x, y)):
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if mask.has(Vector2i(x, y) + o):
					img.set_pixel(at.x + x, at.y + y, OUTLINE)
					break
