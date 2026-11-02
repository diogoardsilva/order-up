class_name ItemArt
## Desenho dos itens com os sprites de pixel art.

const TOMATO := Color("e04a3f")
const SOUP := Color("e0703f")
const PLATE := Color("f4f0e8")
const PLATE_RIM := Color("bdb4a6")


static func draw_item(ci: CanvasItem, item: Item, at: Vector2) -> void:
	if item.is_cookware():
		_draw_cookware(ci, item, at)
		return
	if not item.is_plate():
		draw_content(ci, item.content_id(), at)
		return
	if item.is_glass():
		if item.second:
			draw_item(ci, item.second, at + Vector2(-5, 3))
			at += Vector2(4, -2)
		draw_glass(ci, item.contents[0] if not item.contents.is_empty() else "", at)
		return
	if item.second:
		# Segundo prato com comida, ao lado.
		draw_item(ci, item.second, at + Vector2(-5, 3))
		at += Vector2(4, -2)
	if item.stack > 1:
		# Pratos de baixo, a espreitar.
		for k in range(item.stack - 1, 0, -1):
			Art.centered(ci, Art.PLATE, at + Vector2(0, k * 2))
			if item.dirty:
				Art.centered(ci, Art.DIRT, at + Vector2(1, k * 2))
		at += Vector2(0, -2)
	Art.centered(ci, Art.PLATE, at)
	if item.dirty:
		Art.centered(ci, Art.DIRT, at)
	# Um prato completo desenha-se montado (ex. o hambúrguer), se houver sprite.
	var dish := Recipes.match_plate(item.contents)
	if not dish.is_empty() and item.contents.size() > 1 and Art.food("dish_" + dish["id"]):
		Art.centered(ci, Art.food("dish_" + dish["id"]), at + Vector2(0, -1))
		return
	var n := item.contents.size()
	for i in n:
		draw_content(ci, item.contents[i], at + OFFSETS[n - 1][i])


const OFFSETS := [
	[Vector2.ZERO],
	[Vector2(-3, -1), Vector2(3, 1)],
	[Vector2(-4, -2), Vector2(4, -1), Vector2(0, 2)],
]


static func _draw_cookware(ci: CanvasItem, item: Item, at: Vector2) -> void:
	Art.centered(ci, Art.COOK_TOOLS[item.cook_look()], at)
	match item.cook_state:
		Item.Cook.FILLING, Item.Cook.COOKING:
			var n := item.contents.size()
			for i in n:
				draw_content(ci, item.contents[i], at + Vector2((i - (n - 1) / 2.0) * 5.0, 0))
		Item.Cook.READY:
			draw_content(ci, item.product, at)
		Item.Cook.BURNT:
			ci.draw_circle(at, 6.0, Color("1e1a1a"))


## Copo de vidro com a bebida, um reflexo e (no vinho) pé.
static func draw_glass(ci: CanvasItem, drink: String, at: Vector2) -> void:
	var c: Color = Recipes.DRINK_COLORS.get(drink, Color("bfe3f2"))
	var ink := Color("3b2027")
	at = at.round()
	if drink == "wine":
		ci.draw_rect(Rect2(at + Vector2(-3, -6), Vector2(7, 6)), ink)
		ci.draw_rect(Rect2(at + Vector2(-2, -5), Vector2(5, 4)), Color("e8f4fa"))
		ci.draw_rect(Rect2(at + Vector2(-2, -3), Vector2(5, 2)), c)
		ci.draw_rect(Rect2(at + Vector2(0, 0), Vector2(1, 3)), ink)
		ci.draw_rect(Rect2(at + Vector2(-2, 3), Vector2(5, 1)), ink)
		return
	if drink == "coffee" or drink == "tea":
		# Chávena com pires.
		ci.draw_rect(Rect2(at + Vector2(-5, 2), Vector2(11, 2)), ink)
		ci.draw_rect(Rect2(at + Vector2(-4, 2), Vector2(9, 1)), Color("f4f0e8"))
		ci.draw_rect(Rect2(at + Vector2(-3, -3), Vector2(7, 6)), ink)
		ci.draw_rect(Rect2(at + Vector2(-2, -2), Vector2(5, 4)), Color("f4f0e8"))
		ci.draw_rect(Rect2(at + Vector2(-2, -2), Vector2(5, 1)), c)
		ci.draw_rect(Rect2(at + Vector2(4, -1), Vector2(2, 2)), ink)
		return
	ci.draw_rect(Rect2(at + Vector2(-3, -5), Vector2(7, 10)), ink)
	ci.draw_rect(Rect2(at + Vector2(-2, -4), Vector2(5, 8)), Color("e8f4fa"))
	ci.draw_rect(Rect2(at + Vector2(-2, -2), Vector2(5, 6)), c)
	ci.draw_rect(Rect2(at + Vector2(-2, -2), Vector2(5, 1)), c.lightened(0.35))
	ci.draw_rect(Rect2(at + Vector2(-2, -4), Vector2(1, 6)), Color(1, 1, 1, 0.6))
	if drink == "shake" or drink == "soda":
		ci.draw_rect(Rect2(at + Vector2(1, -8), Vector2(1, 5)), Color("e8574d"))


static func draw_content(ci: CanvasItem, id: String, at: Vector2) -> void:
	if Recipes.is_drink(id):
		draw_glass(ci, id, at)
		return
	var tex := Art.food(id)
	if tex:
		Art.centered(ci, tex, at)
