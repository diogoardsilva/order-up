class_name ItemArt
## Desenho dos itens com os sprites de pixel art.

const TOMATO := Color("e04a3f")
const SOUP := Color("e0703f")
const PLATE := Color("f4f0e8")
const PLATE_RIM := Color("bdb4a6")


static func draw_item(ci: CanvasItem, item: Item, at: Vector2) -> void:
	if not item.is_plate():
		draw_content(ci, item.content_id(), at)
		return
	if item.stack > 1:
		# Prato de baixo, a espreitar.
		Art.centered(ci, Art.PLATE, at + Vector2(0, 2))
		if item.dirty:
			Art.centered(ci, Art.DIRT, at + Vector2(1, 2))
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


static func draw_content(ci: CanvasItem, id: String, at: Vector2) -> void:
	var tex := Art.food(id)
	if tex:
		Art.centered(ci, tex, at)
