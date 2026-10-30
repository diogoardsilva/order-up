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

## Coluna a partir da qual começa o salão.
const DINING_FROM_X := 12

var stations := {}  # Vector2i -> Station
var spawns := {}  # slot -> Vector2
var chefs: Array[Chef] = []
var orders: OrderManager
## Células assinaladas com uma seta (usado pelo tutorial).
var hint_cells: Array[Vector2i] = []
var particles := Particles.new()


func _init(p_orders: OrderManager) -> void:
	orders = p_orders
	orders.delivered.connect(func(points: int, at: Vector2):
		particles.sparkle(at)
		particles.text(at + Vector2(0, -20), "+%d" % points, Color("f2c94c")))
	orders.failed.connect(func(at: Vector2):
		particles.text(at + Vector2(0, -20), "-%d" % OrderManager.FAIL_PENALTY, Color("e8574d")))
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
	if station is TableStation and (station as TableStation).customer != null \
			and (station as TableStation).customer.is_calling():
		# Anotar o pedido não precisa de mãos livres.
		(station as TableStation).customer.take_order()
		particles.text(cell_center(cell) + Vector2(0, -20), "Anotado!", Color("f2c94c"))
	elif station:
		chef.held = station.interact(chef.held)


func use(cell: Vector2i, delta: float) -> void:
	var station: Station = stations.get(cell)
	if station:
		station.use(delta)


func _process(delta: float) -> void:
	for station: Station in stations.values():
		station.tick(delta)
	_emit_ambient(delta)
	particles.update(delta)
	queue_redraw()


## Fumo, vapor e suor que saem das estações e dos clientes.
func _emit_ambient(delta: float) -> void:
	for station: Station in stations.values():
		var center := cell_center(station.cell)
		if station is StoveStation:
			var stove := station as StoveStation
			if stove.state == StoveStation.State.COOKING and randf() < delta * 6.0:
				particles.steam(center + Vector2(randf_range(-5, 5), -6))
			elif stove.state == StoveStation.State.READY and stove.is_burning_soon() and randf() < delta * 10.0:
				particles.smoke(center + Vector2(randf_range(-5, 5), -6), false)
			elif stove.state == StoveStation.State.BURNT and randf() < delta * 8.0:
				particles.smoke(center + Vector2(randf_range(-5, 5), -6), true)
		elif station is BoardStation and station.progress() > 0.0 and randf() < delta * 12.0:
			particles.chop(center, station.item)
		elif station is SinkStation and station.progress() > 0.0 and randf() < delta * 10.0:
			particles.bubble(center + Vector2(randf_range(-7, 7), randf_range(-3, 3)))
	for customer in orders.customers:
		if (customer.is_waiting() or customer.is_calling()) and customer.patience < customer.max_patience * 0.3 and randf() < delta * 3.0:
			particles.sweat(customer.pos + Vector2(6, -14))


func _draw() -> void:
	var cols := LAYOUT[0].length()
	for y in LAYOUT.size():
		for x in cols:
			draw_texture(Art.WOOD if x >= DINING_FROM_X else Art.FLOOR, Vector2(x, y) * TILE)
	# Cadeiras primeiro, para os clientes sentados ficarem por cima.
	for table in tables():
		draw_texture(Art.CHAIR, Vector2(table.seat) * TILE)
	for station: Station in stations.values():
		_draw_station(station)
	for chef in chefs:
		var cell := chef.target_cell()
		if stations.has(cell):
			draw_rect(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)).grow(-1), chef.color, false, 1.0)
	for customer in orders.customers:
		_draw_customer(customer)
	var bob := sin(Time.get_ticks_msec() / 150.0) * 2.0
	for cell in hint_cells:
		var tip := (cell_center(cell) + Vector2(0, -TILE * 0.6 + bob)).round()
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-6, -8), tip + Vector2(6, -8)]), Color("f2c94c"))
		draw_polyline(PackedVector2Array([tip, tip + Vector2(-6, -8), tip + Vector2(6, -8), tip]), UiStyle.BG, 1.0)
	particles.draw(self)


func _draw_station(station: Station) -> void:
	var rect := Rect2(Vector2(station.cell) * TILE, Vector2(TILE, TILE))
	var center := rect.get_center() + Vector2(0, -3)  # tampo da bancada (sem a frente)
	if station is TableStation:
		_draw_table(station as TableStation, rect)
	elif LAYOUT[station.cell.y][station.cell.x] == "E":
		draw_texture(Art.DOOR, rect.position)
	else:
		draw_texture(Art.COUNTER, rect.position)

	if station is CrateStation:
		draw_texture(Art.CRATE, rect.position + Vector2(0, -2))
		ItemArt.draw_content(self, Item.KIND_IDS[(station as CrateStation).ingredient], center + Vector2(0, -2))
	elif station is BoardStation:
		draw_texture(Art.BOARD, rect.position)
	elif station is StoveStation:
		_draw_stove(station as StoveStation, rect)
	elif station is PlateStation:
		for i in (station as PlateStation).count:
			Art.centered(self, Art.PLATE, center - Vector2(0, i * 2))
	elif station is SinkStation:
		var sink := station as SinkStation
		draw_texture(Art.SINK, rect.position)
		for i in sink.dirty:
			var plate := Item.plate()
			plate.dirty = true
			ItemArt.draw_item(self, plate, center + Vector2(-3, -i * 2))
		for i in sink.clean:
			Art.centered(self, Art.PLATE, rect.position + Vector2(18, 16 - i * 2))
	elif station is TrashStation:
		draw_texture(Art.TRASH, rect.position)

	if station.item:
		ItemArt.draw_item(self, station.item, center)
	var p := station.progress()
	if p >= 0.0:
		var bar := Rect2(rect.position + Vector2(2, -6), Vector2(TILE - 4, 4))
		draw_rect(bar, UiStyle.BG)
		draw_rect(Rect2(bar.position + Vector2.ONE, Vector2((bar.size.x - 2) * p, bar.size.y - 2)), Color("6fcf6a"))


func _draw_table(table: TableStation, rect: Rect2) -> void:
	draw_texture(Art.TABLE, rect.position)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(3, 10), "%d" % table.number,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("a8323a"))


func _draw_customer(customer: Customer) -> void:
	var seated := customer.state in [Customer.State.THINKING, Customer.State.CALLING, Customer.State.WAITING, Customer.State.EATING]
	var col := 3 if seated else (0 if customer.is_still() else 1 + int(Time.get_ticks_msec() / 150.0) % 2)
	var top_left := customer.pos - Vector2(Art.CUSTOMER_FRAME.x / 2.0, Art.CUSTOMER_FRAME.y - 6)
	draw_circle(customer.pos + Vector2(0, 5), 5.0, Color(0, 0, 0, 0.2))
	Art.frame(self, Art.CUSTOMER, Art.CUSTOMER_FRAME, col, 0, top_left)
	Art.frame(self, Art.CUSTOMER_TINT, Art.CUSTOMER_FRAME, col, 0, top_left, false, customer.color)
	var font := ThemeDB.fallback_font
	var head := customer.pos + Vector2(0, -16)
	match customer.state:
		Customer.State.THINKING:
			var dots := ".".repeat(1 + int(Time.get_ticks_msec() / 300.0) % 3)
			draw_string(font, head + Vector2(-12, -2), dots, HORIZONTAL_ALIGNMENT_CENTER, 24, 12, UiStyle.BG)
		Customer.State.CALLING:
			# Balão a saltar com "!": falta alguém ir anotar o pedido.
			var bubble_center := head + Vector2(0, -14 + roundf(sin(Time.get_ticks_msec() / 120.0)))
			Art.centered(self, Art.BUBBLE, bubble_center)
			draw_string(font, bubble_center + Vector2(-8, 4), "!", HORIZONTAL_ALIGNMENT_CENTER, 16, 14, Color("e8574d"))
			_draw_patience(customer, bubble_center)
		Customer.State.WAITING:
			# Balão com o pedido e a paciência.
			var bubble_center := head + Vector2(0, -14)
			Art.centered(self, Art.BUBBLE, bubble_center)
			var plate := Item.plate()
			plate.contents.assign(customer.recipe["needs"])
			ItemArt.draw_item(self, plate, bubble_center + Vector2(0, -1))
			_draw_patience(customer, bubble_center)
		Customer.State.LEAVING:
			if customer.angry:
				draw_string(font, head + Vector2(-12, -2), "!!", HORIZONTAL_ALIGNMENT_CENTER, 24, 12, Color("e8574d"))


func _draw_patience(customer: Customer, bubble_center: Vector2) -> void:
	var t := customer.patience / customer.max_patience
	var bar := Rect2((bubble_center + Vector2(-10, 13)).round(), Vector2(20, 3))
	draw_rect(bar.grow(1), UiStyle.BG)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)), Color("e8574d").lerp(Color("6fcf6a"), t))


func _draw_stove(stove: StoveStation, rect: Rect2) -> void:
	var center := rect.get_center() + Vector2(0, -3)
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(TILE - 4, TILE - 9)), Color("4a4a52"))
	# Chama quando está ao lume.
	if stove.state in [StoveStation.State.COOKING, StoveStation.State.READY]:
		var flicker := int(Time.get_ticks_msec() / 90.0) % 2
		draw_rect(Rect2(center + Vector2(-7, 5 - flicker), Vector2(14, 2 + flicker)), Color("e0703f"))
	Art.centered(self, Art.POT, center)
	match stove.state:
		StoveStation.State.FILLING, StoveStation.State.COOKING:
			for i in stove.tomatoes:
				ItemArt.draw_content(self, "tomato_chopped", center + Vector2(-3 + 6 * i, 0))
		StoveStation.State.READY:
			ItemArt.draw_content(self, "soup", center)
			# Alerta a piscar quando está quase a queimar.
			if stove.is_burning_soon() and int(Time.get_ticks_msec() / 200.0) % 2 == 0:
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, -2), "!",
					HORIZONTAL_ALIGNMENT_CENTER, TILE, 14, Color("e8574d"))
		StoveStation.State.BURNT:
			draw_circle(center, 6.0, Color("1e1a1a"))


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
