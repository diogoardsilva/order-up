class_name ItemArt
## Desenho provisório dos itens, feito por código. Fica até termos sprites.

const TOMATO := Color("e04a3f")
const LETTUCE := Color("6cbf4a")
const SOUP := Color("e0703f")
const PLATE := Color("f4f0e8")
const PLATE_RIM := Color("bdb4a6")


static func draw_item(ci: CanvasItem, item: Item, at: Vector2) -> void:
	if not item.is_plate():
		draw_content(ci, item.content_id(), at)
		return
	ci.draw_circle(at, 9.0, PLATE_RIM)
	ci.draw_circle(at, 8.0, PLATE)
	if item.dirty:
		for p in [Vector2(-3, -2), Vector2(2, 1), Vector2(-1, 3)]:
			ci.draw_circle(at + p, 1.5, Color("8c6a4f"))
	var n := item.contents.size()
	for i in n:
		var offset := Vector2.ZERO if n == 1 else Vector2(-3.0 + 6.0 * i, 0)
		draw_content(ci, item.contents[i], at + offset, 0.75)


static func draw_content(ci: CanvasItem, id: String, at: Vector2, scale := 1.0) -> void:
	var r := 6.0 * scale
	match id:
		"tomato":
			ci.draw_circle(at, r, TOMATO)
			ci.draw_rect(Rect2(at + Vector2(-1, -r - 1), Vector2(3, 3)), LETTUCE)
		"lettuce":
			ci.draw_circle(at, r, LETTUCE)
			ci.draw_circle(at + Vector2(-1, -1), r * 0.5, LETTUCE.lightened(0.3))
		"tomato_chopped", "lettuce_chopped":
			var color := TOMATO if id.begins_with("tomato") else LETTUCE
			for p in [Vector2(-3, -2), Vector2(2, -3), Vector2(0, 2)]:
				ci.draw_rect(Rect2(at + p * scale - Vector2(2, 2) * scale, Vector2(4, 4) * scale), color)
		"soup":
			ci.draw_circle(at, r, SOUP)
			ci.draw_circle(at + Vector2(-2, -2) * scale, 1.5 * scale, SOUP.lightened(0.35))
