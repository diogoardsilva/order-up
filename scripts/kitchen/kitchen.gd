class_name Kitchen
extends Node2D
## A cozinha: grelha de estações construída a partir de um layout em texto.
## Os chefs pedem ações aqui (interact/use) em vez de mexerem nas estações
## diretamente; no M2 estes pedidos passam a ir por rede para o anfitrião.

const TILE := 24
## Legenda: . chão, C bancada, T caixa de tomates, L caixa de alfaces,
## B tábua de cortar, S fogão, P pratos limpos, W lava-loiça, X lixo,
## M mesa do salão, E porta de entrada dos clientes, 1-4 início dos chefs.
const LAYOUT: Array[String] = [
	"CTTCLLCBBSSCCCCCCCCC",
	"C..........C.......C",
	"P..1.......C..M..M.C",
	"P..........C.......C",
	"W.....3....C..M..M.C",
	"W.....CCC..........C",
	"X.....CBC..........C",
	"C..........C.......C",
	"C..........C..M..M.C",
	"C..2.......C.......C",
	"C.....4....C..M..M.C",
	"C..........C.......E",
	"CCCBBCCCSSCCCCCCCCCC",
]

const FLOOR_A := Color("d9cfc1")
const FLOOR_B := Color("cbbfae")
const WOOD_A := Color("b58a63")
const WOOD_B := Color("a97f5a")
## Coluna a partir da qual começa o salão.
const DINING_FROM_X := 12
const COUNTER := Color("a5815f")
const COUNTER_EDGE := Color("7a5c43")

var stations := {}  # Vector2i -> Station
var spawns := {}  # slot -> Vector2
var chefs: Array[Chef] = []
var orders: OrderManager
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
	var number := 1
	for table in tables():
		table.number = number
		table.seat = table.cell + Vector2i.RIGHT
		number += 1


func pixel_size() -> Vector2:
	return Vector2(LAYOUT[0].length(), LAYOUT.size()) * TILE


func cell_at(local_pos: Vector2) -> Vector2i:
	return Vector2i((local_pos / TILE).floor())


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE, TILE) / 2.0


## Mesas do salão, ordenadas de cima para baixo e da esquerda para a direita.
func tables() -> Array[TableStation]:
	var result: Array[TableStation] = []
	for station: Station in stations.values():
		if station is TableStation:
			result.append(station)
	result.sort_custom(func(a, b): return a.cell.y < b.cell.y or (a.cell.y == b.cell.y and a.cell.x < b.cell.x))
	return result


## Caminho da porta até à cadeira da mesa, pelo corredor da direita e pela
## fila livre por baixo da mesa.
func path_to_seat(table: TableStation) -> Array[Vector2]:
	var door := Vector2i.ZERO
	for station: Station in stations.values():
		if LAYOUT[station.cell.y][station.cell.x] == "E":
			door = station.cell
	var corridor_x := door.x - 1
	var below := table.seat.y + 1
	return [cell_center(door), cell_center(Vector2i(corridor_x, door.y)),
		cell_center(Vector2i(corridor_x, below)), cell_center(Vector2i(table.seat.x, below)),
		cell_center(table.seat)]


func interact(chef: Chef, cell: Vector2i) -> void:
	var station: Station = stations.get(cell)
	if station:
		chef.held = station.interact(chef.held)


func use(cell: Vector2i, delta: float) -> void:
	var station: Station = stations.get(cell)
	if station:
		station.use(delta)


func _process(delta: float) -> void:
	for station: Station in stations.values():
		station.tick(delta)
	queue_redraw()


func _draw() -> void:
	var cols := LAYOUT[0].length()
	for y in LAYOUT.size():
		for x in cols:
			var even := (x + y) % 2 == 0
			# Salão com soalho de madeira, cozinha com mosaico.
			var color := (WOOD_A if even else WOOD_B) if x >= DINING_FROM_X else (FLOOR_A if even else FLOOR_B)
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), color)
	for station: Station in stations.values():
		_draw_station(station)
	for customer in orders.customers:
		_draw_customer(customer)
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
		var count: int = (station as PlateStation).count
		for i in count:
			draw_circle(center - Vector2(0, i * 2), 8.0, ItemArt.PLATE_RIM if i < count - 1 else ItemArt.PLATE)
	elif station is SinkStation:
		var sink := station as SinkStation
		draw_rect(rect.grow(-3), Color("9fb8c8"))
		draw_rect(rect.grow(-6), Color("5d8aa8"))
		var font := ThemeDB.fallback_font
		if sink.dirty > 0:
			draw_string(font, rect.position + Vector2(2, 9), "%d" % sink.dirty, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("8c6a4f"))
		if sink.clean > 0:
			draw_circle(center + Vector2(3, 3), 6.0, ItemArt.PLATE)
			draw_string(font, rect.position + Vector2(14, 22), "%d" % sink.clean, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiStyle.BG)
	elif station is TableStation:
		_draw_table(station as TableStation, rect)
	elif LAYOUT[station.cell.y][station.cell.x] == "E":
		draw_rect(rect, Color("5a4a63"))
		draw_rect(rect.grow(-3), Color("8c6a4f"))
		draw_circle(center + Vector2(-5, 0), 1.5, Color("f2c94c"))
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


func _draw_table(table: TableStation, rect: Rect2) -> void:
	draw_rect(rect, Color("6b4f3a"))
	draw_rect(rect.grow(-2), Color("f4f0e8"))
	draw_rect(Rect2(rect.position + Vector2(2, rect.size.y - 6), Vector2(rect.size.x - 4, 4)), Color("e8574d"))
	# Cadeira.
	var seat := Rect2(Vector2(table.seat) * TILE, Vector2(TILE, TILE))
	draw_rect(seat.grow(-6), Color("8c6a4f"))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(2, 9), "%d" % table.number,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiStyle.MUTED)


func _draw_customer(customer: Customer) -> void:
	var at := customer.pos
	draw_circle(at + Vector2(0, 3), 7.0, Color(0, 0, 0, 0.2))
	draw_circle(at, 7.0, customer.color)
	draw_circle(at + Vector2(0, -6), 4.0, Color("f1c27d"))
	var font := ThemeDB.fallback_font
	match customer.state:
		Customer.State.THINKING:
			draw_string(font, at + Vector2(-12, -14), "...", HORIZONTAL_ALIGNMENT_CENTER, 24, 10, UiStyle.BG)
		Customer.State.WAITING:
			# Balão com o pedido e a paciência.
			var bubble := Rect2(at + Vector2(-11, -36), Vector2(22, 22))
			draw_rect(bubble, Color.WHITE)
			var plate := Item.plate()
			plate.contents.assign(customer.recipe["needs"])
			ItemArt.draw_item(self, plate, bubble.get_center())
			var t := customer.patience / customer.max_patience
			draw_rect(Rect2(bubble.position + Vector2(0, 23), Vector2(22, 3)), UiStyle.BG)
			draw_rect(Rect2(bubble.position + Vector2(0, 23), Vector2(22 * t, 3)), Color("e8574d").lerp(Color("6fcf6a"), t))
		Customer.State.LEAVING:
			if customer.angry:
				draw_string(font, at + Vector2(-12, -12), "!!", HORIZONTAL_ALIGNMENT_CENTER, 24, 12, Color("e8574d"))


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
		"W": return SinkStation.new()
		"M": return TableStation.new()
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
