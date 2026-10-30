class_name Art
## Sprites de pixel art (gerados por tools/make_sprites.py) e ajudas para os desenhar.

const CHEF := preload("res://assets/sprites/chef.png")
const CHEF_TINT := preload("res://assets/sprites/chef_tint.png")
const CUSTOMER := preload("res://assets/sprites/customer.png")
const CUSTOMER_TINT := preload("res://assets/sprites/customer_tint.png")
const FLOOR := preload("res://assets/sprites/floor.png")
const WOOD := preload("res://assets/sprites/wood.png")
const COUNTER := preload("res://assets/sprites/counter.png")
const STOVE := preload("res://assets/sprites/stove.png")
const WALL_TOP := preload("res://assets/sprites/wall_top.png")
const WALL_FRONT := preload("res://assets/sprites/wall_front.png")
const BACKWALL_KITCHEN := preload("res://assets/sprites/backwall_kitchen.png")
const WINDOW := preload("res://assets/sprites/window.png")
const PLANT := preload("res://assets/sprites/plant.png")
const SHELF := preload("res://assets/sprites/shelf.png")
const CRATE := preload("res://assets/sprites/crate.png")
const BOARD := preload("res://assets/sprites/board.png")
const POT := preload("res://assets/sprites/pot.png")
const SINK := preload("res://assets/sprites/sink.png")
const TRASH := preload("res://assets/sprites/trash.png")
const TABLE := preload("res://assets/sprites/table.png")
const CHAIR := preload("res://assets/sprites/chair.png")
const DOOR := preload("res://assets/sprites/door.png")
const BUBBLE := preload("res://assets/sprites/bubble.png")
const PLATE := preload("res://assets/sprites/plate.png")
const DIRT := preload("res://assets/sprites/dirt.png")
const CONTENT := {
	"tomato": preload("res://assets/sprites/tomato.png"),
	"lettuce": preload("res://assets/sprites/lettuce.png"),
	"tomato_chopped": preload("res://assets/sprites/tomato_chopped.png"),
	"lettuce_chopped": preload("res://assets/sprites/lettuce_chopped.png"),
	"soup": preload("res://assets/sprites/soup.png"),
}

const CHEF_FRAME := Vector2i(16, 24)
const CUSTOMER_FRAME := Vector2i(16, 22)
## Linhas da folha de clientes (penteados diferentes).
const CUSTOMER_LOOKS := 4


## Desenha uma textura centrada num ponto (arredondado ao píxel).
static func centered(ci: CanvasItem, tex: Texture2D, at: Vector2, modulate := Color.WHITE) -> void:
	ci.draw_texture(tex, (at - tex.get_size() / 2.0).round(), modulate)


## Desenha uma frame de uma folha de sprites. `flip` espelha na horizontal.
static func frame(ci: CanvasItem, sheet: Texture2D, size: Vector2i, col: int, row: int,
		top_left: Vector2, flip := false, modulate := Color.WHITE) -> void:
	var src := Rect2(Vector2(col * size.x, row * size.y), size)
	var dst := Rect2(top_left.round(), size)
	if flip:
		dst = Rect2(dst.position + Vector2(size.x, 0), Vector2(-size.x, size.y))
	ci.draw_texture_rect_region(sheet, dst, src, modulate)
