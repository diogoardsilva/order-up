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
	Art.centered(ci, Art.PLATE, at)
	if item.dirty:
		Art.centered(ci, Art.DIRT, at)
	var n := item.contents.size()
	for i in n:
		var offset := Vector2.ZERO if n == 1 else Vector2(-3.0 + 6.0 * i, -1.0 + 2.0 * i)
		draw_content(ci, item.contents[i], at + offset)


static func draw_content(ci: CanvasItem, id: String, at: Vector2) -> void:
	if Art.CONTENT.has(id):
		Art.centered(ci, Art.CONTENT[id], at)
