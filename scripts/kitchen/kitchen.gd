class_name Kitchen
extends Node2D
## A cozinha: grelha de estações construída a partir de um layout em texto.
## Os chefs pedem ações aqui (interact/use) em vez de mexerem nas estações
## diretamente; no M2 estes pedidos passam a ir por rede para o anfitrião.

const TILE := 24
## Legenda: . chão, C bancada, T caixa de tomates, L caixa de alfaces,
## B tábua de cortar, S fogão, P pratos, O entrega, X lixo, 1-4 início dos chefs.
const LAYOUT: Array[String] = [
	"CTTCCLLCCBBCCSSCCOOC",
	"C..................C",
	"C..................C",
	"P..1............2..C",
	"P..................X",
	"C.....CCBCCSCC.....C",
	"C.....CCCCCCCC.....C",
	"C..................C",
	"C..................C",
	"C..3............4..C",
	"C..................C",
	"C..................C",
	"CCCCBBCCCCPPCCCSSCCC",
]

const FLOOR_A := Color("d9cfc1")
const FLOOR_B := Color("cbbfae")
const COUNTER := Color("a5815f")
const COUNTER_EDGE := Color("7a5c43")

var stations := {}  # Vector2i -> Station
var spawns := {}  # slot -> Vector2
var chefs: Array[Chef] = []
var orders: OrderManager
## Só o anfitrião faz as estações avançar (cozinhar, queimar).
var simulate := true
## Células assinaladas com uma seta (usado pelo tutorial).
var hint_cells: Array[Vector2i] = []


func _init(p_orders: OrderManager) -> void:
	orders = p_orders
	for y in LAYOUT.size():
		for x in LAYOUT[y].length():
			var c := LAYOUT[y][x]
			var cell := Vector2i(x, y)
			if c.is_valid_int():
				spawns[c.to_int() - 1] = cell_center(cell)
			elif c != ".":
				var station := _make_station(c)
				station.cell = cell
				stations[cell] = station
				_add_body(cell)


func pixel_size() -> Vector2:
	return Vector2(LAYOUT[0].length(), LAYOUT.size()) * TILE


func cell_at(local_pos: Vector2) -> Vector2i:
	return Vector2i((local_pos / TILE).floor())


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE, TILE) / 2.0


func interact(chef: Chef, cell: Vector2i) -> void:
	var station: Station = stations.get(cell)
	if station:
		chef.held = station.interact(chef.held)


func use(cell: Vector2i, delta: float) -> void:
	var station: Station = stations.get(cell)
	if station:
		station.use(delta)


func _process(delta: float) -> void:
	if simulate:
		for station: Station in stations.values():
			station.tick(delta)
	queue_redraw()


func _draw() -> void:
	var cols := LAYOUT[0].length()
	for y in LAYOUT.size():
		for x in cols:
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), FLOOR_A if (x + y) % 2 == 0 else FLOOR_B)
	for station: Station in stations.values():
		_draw_station(station)
	for chef in chefs:
		var cell := chef.target_cell()
		if stations.has(cell):
			draw_rect(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)).grow(-1), chef.color, false, 2.0)
	var bob := sin(Time.get_ticks_msec() / 150.0) * 2.0
	for cell in hint_cells:
		var tip := cell_center(cell) + Vector2(0, -TILE * 0.6 + bob)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-6, -8), tip + Vector2(6, -8)]), Color("f2c94c"))
		draw_polyline(PackedVector2Array([tip, tip + Vector2(-6, -8), tip + Vector2(6, -8), tip]), UiStyle.BG, 1.0)


func _draw_station(station: Station) -> void:
	var rect := Rect2(Vector2(station.cell) * TILE, Vector2(TILE, TILE))
	var center := rect.get_center()
	draw_rect(rect, COUNTER_EDGE)
	draw_rect(rect.grow(-2), COUNTER)

	if station is CrateStation:
		draw_rect(rect.grow(-4), Color("8c6a4f"))
		var kind: Item.Kind = (station as CrateStation).ingredient
		ItemArt.draw_content(self, Item.KIND_IDS[kind], center)
	elif station is BoardStation:
		draw_rect(rect.grow(-4), Color("e2c79a"))
	elif station is StoveStation:
		_draw_stove(station as StoveStation, rect)
	elif station is PlateStation:
		for i in 3:
			draw_circle(center - Vector2(0, i * 2), 8.0, ItemArt.PLATE_RIM if i < 2 else ItemArt.PLATE)
	elif station is ServeStation:
		draw_rect(rect.grow(-3), Color("3d3248"))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, 16), "SAÍDA",
			HORIZONTAL_ALIGNMENT_CENTER, TILE, 7, UiStyle.TEXT)
	elif station is TrashStation:
		draw_rect(rect.grow(-4), Color("4a4a4a"))
		draw_rect(rect.grow(-7), Color("2e2e2e"))

	if station.item:
		ItemArt.draw_item(self, station.item, center)
	var p := station.progress()
	if p >= 0.0:
		var bar := Rect2(rect.position + Vector2(2, -6), Vector2(TILE - 4, 4))
		draw_rect(bar, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)), Color("6fcf6a"))


func _draw_stove(stove: StoveStation, rect: Rect2) -> void:
	var center := rect.get_center()
	draw_rect(rect.grow(-3), Color("3a3a3a"))
	draw_circle(center, 9.0, Color("5c5c5c"))
	match stove.state:
		StoveStation.State.FILLING, StoveStation.State.COOKING:
			for i in stove.tomatoes:
				ItemArt.draw_content(self, "tomato_chopped", center + Vector2(-3 + 6 * i, 0), 0.7)
		StoveStation.State.READY:
			draw_circle(center, 7.0, ItemArt.SOUP)
			# Alerta a piscar quando está quase a queimar.
			if stove.is_burning_soon() and int(Time.get_ticks_msec() / 200.0) % 2 == 0:
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, -2), "!",
					HORIZONTAL_ALIGNMENT_CENTER, TILE, 14, Color("e8574d"))
		StoveStation.State.BURNT:
			draw_circle(center, 7.0, Color("1e1a1a"))


func _make_station(c: String) -> Station:
	match c:
		"T": return CrateStation.new(Item.Kind.TOMATO)
		"L": return CrateStation.new(Item.Kind.LETTUCE)
		"B": return BoardStation.new()
		"S": return StoveStation.new()
		"P": return PlateStation.new()
		"O": return ServeStation.new(orders)
		"X": return TrashStation.new()
		_: return Station.new()


func _add_body(cell: Vector2i) -> void:
	var body := StaticBody2D.new()
	body.position = cell_center(cell)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE, TILE)
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)
