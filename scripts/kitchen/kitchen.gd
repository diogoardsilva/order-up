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
## Altura da parede do fundo, desenhada por cima da primeira fila.
const BACK_WALL := 22
## Decoração: [textura, posição em píxeis da cozinha].
const DECOR := [
	["shelf", Vector2(28, -16)], ["shelf", Vector2(196, -16)],
	["window", Vector2(315, 5)], ["window", Vector2(411, 5)],
	["plant", Vector2(268, -6)], ["plant", Vector2(460, -6)], ["plant", Vector2(268, 168)],
]
const BG := Color("2a1a1e")

var stations := {}  # Vector2i -> Station
var spawns := {}  # slot -> Vector2
var chefs: Array[Chef] = []
var orders: OrderManager
## Só o anfitrião faz as estações avançar (cozinhar, queimar).
var simulate := true
## Células assinaladas com uma seta (usado pelo tutorial).
var hint_cells: Array[Vector2i] = []
var particles := Particles.new()
# Para sons e animações: estado anterior de cada cliente e progresso das estações.
var _customer_seen := {}  # id -> [estado, momento da mudança]
var _station_progress := {}  # célula -> [progresso, tempo desde o último som]
var _time := 0.0
## Sem sons (o restaurante a funcionar por trás do menu).
var quiet := false

## Um efeito de texto (pontos, "Anotado!"). Online, o nível reenvia-o aos outros PCs.
signal fx(at: Vector2, text: String, color: Color, sparkle: bool)


func _init(p_orders: OrderManager) -> void:
	orders = p_orders
	orders.delivered.connect(func(points: int, at: Vector2):
		show_fx(at, "+%d" % points, Color("f2c94c"), true))
	orders.failed.connect(func(at: Vector2):
		show_fx(at, "-%d" % OrderManager.FAIL_PENALTY, Color("e8574d")))
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
		show_fx(cell_center(cell), "Anotado!", Color("f2c94c"))
	elif station:
		chef.held = station.interact(chef.held)


func show_fx(at: Vector2, text: String, color: Color, sparkle := false) -> void:
	if text.begins_with("+"):
		_sfx("ding")
		_sfx("coin", -4.0)
	elif text.begins_with("-"):
		_sfx("fail")
	else:
		_sfx("note")
	if sparkle:
		particles.sparkle(at)
	particles.text(at + Vector2(0, -20), text, color)
	fx.emit(at, text, color, sparkle)


func _sfx(name: String, volume_db := 0.0, spread := 0.06) -> void:
	if not quiet:
		Sfx.play(name, volume_db, spread)


func use(cell: Vector2i, delta: float) -> void:
	var station: Station = stations.get(cell)
	if station:
		station.use(delta)


func _process(delta: float) -> void:
	if simulate:
		for station: Station in stations.values():
			station.tick(delta)
	else:
		# Nos outros PCs os clientes deslizam até à última posição recebida.
		for customer in orders.customers:
			customer.pos = customer.pos.lerp(customer.net_pos, 0.3)
	_emit_ambient(delta)
	particles.update(delta)
	queue_redraw()


## Fumo, vapor e suor que saem das estações e dos clientes.
func _emit_ambient(delta: float) -> void:
	_time += delta
	var cooking := 0
	for station: Station in stations.values():
		# Sons de cortar e lavar enquanto o progresso avança (em todos os PCs).
		var p := station.progress()
		var last: Array = _station_progress.get(station.cell, [-1.0, 0.0])
		last[1] += delta
		if p > last[0] and p > 0.0:
			if station is BoardStation and last[1] > 0.16:
				_sfx("chop", -2.0, 0.15)
				last[1] = 0.0
			elif station is SinkStation and last[1] > 0.45:
				_sfx("wash", -4.0, 0.1)
				last[1] = 0.0
		last[0] = p
		_station_progress[station.cell] = last
		if station is StoveStation and (station as StoveStation).state in [StoveStation.State.COOKING, StoveStation.State.READY]:
			cooking += 1
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
	if not quiet:
		Sfx.set_sizzle(cooking / 2.0)
	for customer in orders.customers:
		if (customer.is_waiting() or customer.is_calling()) and customer.patience < customer.max_patience * 0.3 and randf() < delta * 3.0:
			particles.sweat(customer.pos + Vector2(6, -14))
		var seen: Array = _customer_seen.get(customer.id, [-1, 0.0])
		if seen[0] != customer.state:
			if customer.state == Customer.State.CALLING:
				_sfx("bell", -3.0)
			_customer_seen[customer.id] = [customer.state, _time]


func _draw() -> void:
	var cols := LAYOUT[0].length()
	draw_rect(Rect2(Vector2(-200, -200), pixel_size() + Vector2(400, 400)), BG)
	draw_rect(Rect2(Vector2(-3, -BACK_WALL - 3), pixel_size() + Vector2(6, BACK_WALL + 6)), Color("1a0f12"))
	for x in cols:
		var at := Vector2(x * TILE, -BACK_WALL)
		if x < DINING_FROM_X - 1:
			draw_texture(Art.BACKWALL_KITCHEN, at)
		else:
			draw_texture_rect_region(Art.WALL_TOP, Rect2(at, Vector2(TILE, BACK_WALL)), Rect2(0, 0, TILE, BACK_WALL))
	for y in LAYOUT.size():
		for x in cols:
			var tex := Art.WOOD if x >= DINING_FROM_X else Art.FLOOR
			var n := tex.get_width() / TILE
			draw_texture_rect_region(tex, Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE)),
				Rect2(Vector2(x % n, y % n) * TILE, Vector2(TILE, TILE)))
	# Sombra das bancadas no chão (luz de cima à esquerda).
	for station: Station in stations.values():
		var below := station.cell + Vector2i.DOWN
		if below.y < LAYOUT.size() and not stations.has(below):
			draw_rect(Rect2(Vector2(below) * TILE, Vector2(TILE, 4)), Color(0.2, 0.08, 0.05, 0.28))
		var right := station.cell + Vector2i.RIGHT
		if right.x < cols and not stations.has(right):
			draw_rect(Rect2(Vector2(right) * TILE, Vector2(3, TILE)), Color(0.2, 0.08, 0.05, 0.18))
	# Cadeiras primeiro, para os clientes sentados ficarem por cima.
	for table in tables():
		draw_texture(Art.CHAIR, Vector2(table.seat) * TILE)
	for station: Station in stations.values():
		_draw_station(station)
	for d in DECOR:
		draw_texture({"shelf": Art.SHELF, "window": Art.WINDOW, "plant": Art.PLANT}[d[0]], d[1])
	for chef in chefs:
		var cell := chef.target_cell()
		if stations.has(cell):
			draw_rect(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)).grow(-1), chef.color, false, 1.0)
	for customer in orders.customers:
		_draw_customer(customer)
		_draw_customer_end()
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
	elif station.cell.x >= DINING_FROM_X - 1 and station.get_script() == Station:
		_draw_wall(station.cell, rect)
	elif station is StoveStation:
		draw_texture(Art.STOVE, rect.position)
	elif not station is TrashStation:
		draw_texture(Art.COUNTER, rect.position)

	if station is CrateStation:
		draw_texture(Art.CRATE, rect.position + Vector2(0, -2))
		var id: String = Item.KIND_IDS[(station as CrateStation).ingredient]
		for offset in [Vector2(-4, -1), Vector2(4, -1), Vector2(0, -4)]:
			ItemArt.draw_content(self, id, center + Vector2(0, -3) + offset)
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


## Parede do salão: vista de frente quando há chão logo abaixo, senão só o topo.
func _draw_wall(cell: Vector2i, rect: Rect2) -> void:
	var below := cell + Vector2i.DOWN
	var front := below.y < LAYOUT.size() and not stations.has(below)
	draw_texture(Art.WALL_FRONT if front else Art.WALL_TOP, rect.position)


func _draw_table(table: TableStation, rect: Rect2) -> void:
	draw_texture(Art.TABLE, rect.position)
	draw_string(UiStyle.FONT, rect.position + Vector2(3, 10), "%d" % table.number,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("a02530"))


func _draw_customer(customer: Customer) -> void:
	var seated := customer.state in [Customer.State.THINKING, Customer.State.CALLING, Customer.State.WAITING, Customer.State.EATING]
	var walking := not seated and not customer.is_still()
	var col := 3 if seated else (1 + int(Time.get_ticks_msec() / 150.0) % 2 if walking else 0)
	var bob := -1.0 if walking and col == 1 else 0.0
	var top_left := customer.pos - Vector2(Art.CUSTOMER_FRAME.x / 2.0, Art.CUSTOMER_FRAME.y - 6 - bob)
	draw_circle(customer.pos + Vector2(0, 5), 5.0, Color(0, 0, 0, 0.2))
	Art.frame(self, Art.CUSTOMER, Art.CUSTOMER_FRAME, col, customer.look, top_left)
	Art.frame(self, Art.CUSTOMER_TINT, Art.CUSTOMER_FRAME, col, customer.look, top_left, false, customer.color)
	var font := UiStyle.FONT
	var head := customer.pos + Vector2(0, -16)
	# Os balões aparecem a crescer com um pequeno salto.
	var since: float = _time - _customer_seen.get(customer.id, [0, -10.0])[1]
	var pop := 1.0 if since > 0.3 else ease(since / 0.3, 0.4) * (1.0 + 0.25 * sin(since / 0.3 * PI))
	if customer.state in [Customer.State.CALLING, Customer.State.WAITING]:
		draw_set_transform(head + Vector2(0, -4), 0.0, Vector2(pop, pop))
		head = Vector2(0, 4)
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
		Customer.State.EATING:
			# Garfadas: corações pequenos de vez em quando.
			if int(since * 2.0) % 3 == 0:
				var h := (head + Vector2(-2, -6 - fmod(since * 6.0, 4.0))).round()
				for r in [Rect2(h, Vector2(2, 2)), Rect2(h + Vector2(3, 0), Vector2(2, 2)), Rect2(h + Vector2(0, 1), Vector2(5, 2)),
						Rect2(h + Vector2(1, 3), Vector2(3, 1)), Rect2(h + Vector2(2, 4), Vector2(1, 1))]:
					draw_rect(r, UiStyle.RED)
		Customer.State.LEAVING:
			if customer.angry:
				draw_string(font, head + Vector2(-12, -2), "!!", HORIZONTAL_ALIGNMENT_CENTER, 24, 12, Color("e8574d"))


func _draw_customer_end() -> void:
	draw_set_transform(Vector2.ZERO)


func _draw_patience(customer: Customer, bubble_center: Vector2) -> void:
	var t := customer.patience / customer.max_patience
	var bar := Rect2((bubble_center + Vector2(-10, 13)).round(), Vector2(20, 3))
	draw_rect(bar.grow(1), UiStyle.BG)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)), Color("e8574d").lerp(Color("6fcf6a"), t))


func _draw_stove(stove: StoveStation, rect: Rect2) -> void:
	var center := rect.get_center() + Vector2(0, -3)
	# Chamas à volta da panela quando está ao lume.
	if stove.state in [StoveStation.State.COOKING, StoveStation.State.READY]:
		var t := Time.get_ticks_msec() / 90
		for i in 5:
			var h := 2 + (t + i * 3) % 3
			var x := center.x - 8 + i * 4
			draw_rect(Rect2(Vector2(x, center.y + 7 - h), Vector2(2, h)), Color("f2a03a"))
			draw_rect(Rect2(Vector2(x, center.y + 7 - 1), Vector2(2, 1)), Color("e0503a"))
	Art.centered(self, Art.POT, center)
	match stove.state:
		StoveStation.State.FILLING, StoveStation.State.COOKING:
			for i in stove.tomatoes:
				ItemArt.draw_content(self, "tomato_chopped", center + Vector2(-3 + 6 * i, 0))
		StoveStation.State.READY:
			ItemArt.draw_content(self, "soup", center)
			# Alerta a piscar quando está quase a queimar.
			if stove.is_burning_soon() and int(Time.get_ticks_msec() / 200.0) % 2 == 0:
				draw_string(UiStyle.FONT, rect.position + Vector2(0, -2), "!",
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
