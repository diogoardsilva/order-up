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


static func draw_content(ci: CanvasItem, id: String, at: Vector2) -> void:
	var tex := Art.food(id)
	if tex:
		Art.centered(ci, tex, at)
