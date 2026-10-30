class_name Kitchen
extends Node2D
## A cozinha: grelha de estações construída a partir de um layout em texto.
## Os chefs pedem ações aqui (interact/use) em vez de mexerem nas estações
## diretamente; no M2 estes pedidos passam a ir por rede para o anfitrião.

const TILE := 24
## A planta está em Levels.LAYOUT (igual em todos os restaurantes).
const LAYOUT := Levels.LAYOUT

## Coluna a partir da qual começa o salão.
const DINING_FROM_X := 12
## Altura da parede do fundo, desenhada por cima da primeira fila.
const BACK_WALL := 22
## Decoração: [textura, posição em píxeis da cozinha]. "wall_deco" e "corner_deco"
## mudam com o tema do restaurante (janelas, azulejos, lanternas, néon...).
const DECOR := [
	["shelf", Vector2(28, -16)], ["shelf", Vector2(196, -16)],
	["wall_deco", Vector2(315, 5)], ["wall_deco", Vector2(411, 5)],
	["corner_deco", Vector2(268, -6)], ["corner_deco", Vector2(460, -6)], ["corner_deco", Vector2(268, 168)],
]
const BG := Color("2a1a1e")

var stations := {}  # Vector2i -> Station
var spawns := {}  # slot -> Vector2
var chefs: Array[Chef] = []
var register: RegisterStation
## O restaurante (ver Levels.ALL).
var level: Dictionary
## Células extra de estações que ocupam mais de uma (mesa de 4) -> célula principal.
var _alias := {}
## Ingredientes atirados no ar: {"item", "pos", "vel", "dist", "slot"}.
var thrown: Array[Dictionary] = []
var _lights: Node2D
var _light_tex: Texture2D
## Ingredientes caídos no chão: {"item", "pos"}.
var floor_items: Array[Dictionary] = []

const THROW_SPEED := 260.0
const THROW_RANGE := TILE * 5.0
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


func _init(p_orders: OrderManager, p_level: Dictionary = Levels.ALL[0]) -> void:
	orders = p_orders
	level = p_level
	orders.served.connect(func(at: Vector2):
		show_fx(at, "Servido!", Color("f2c94c")))
	orders.paid.connect(func(points: int, at: Vector2):
		show_fx(at, "+%d" % points, Color("f2c94c"), true))
	orders.failed.connect(func(at: Vector2):
		show_fx(at, "-%d" % OrderManager.FAIL_PENALTY, Color("e8574d")))
	for y in LAYOUT.size():
		for x in LAYOUT[y].length():
			var c := LAYOUT[y][x]
			var cell := Vector2i(x, y)
			if c.is_valid_int():
				spawns[c.to_int() - 1] = cell_center(cell)
			elif c == "n":
				# Metade de baixo da mesa de 4.
				var top: TableStation = stations[cell + Vector2i.UP]
				top.cells.append(cell)
				top.seats.append(cell + Vector2i.LEFT)
				top.seats.append(cell + Vector2i.RIGHT)
				_alias[cell] = top.cell
				_add_body(cell)
			elif c != ".":
				var station := _make_station(c)
				station.cell = cell
				stations[cell] = station
				_add_body(cell)
				if station is TableStation:
					(station as TableStation).cells = [cell]
					station.seats.assign([cell + Vector2i.LEFT, cell + Vector2i.RIGHT])
				if station is StoveStation:
					station.item = Item.cookware(level.get("stove", "pot"))
				if station is RegisterStation:
					(station as RegisterStation).orders = orders
					register = station
	_make_lights()
	var number := 1
	for table in tables():
		table.number = number
		number += 1


## Luzes por cima de tudo (soma de cor): candeeiros das mesas, janelas e o
## brilho dos fogões. Uma textura de gradiente feita em código, leve para PCs fracos.
func _make_lights() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_light_tex = tex
	_lights = Node2D.new()
	_lights.z_index = 50
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lights.material = mat
	_lights.draw.connect(_draw_lights)
	add_child(_lights)


func _draw_lights() -> void:
	var warm := Color(1.0, 0.72, 0.4)
	var flicker := 0.9 + 0.1 * sin(_time * 7.0) * sin(_time * 3.1)
	for table in tables():
		var center := (cell_center(table.cells[0]) + cell_center(table.cells.back())) / 2.0
		_light(center, 56.0, Color(warm, 0.22 * flicker))
	_light(cell_center(register.cell), 30.0, Color(warm, 0.14))
	# Raios de sol das janelas, em diagonal pelo chão do salão.
	for d in DECOR:
		if d[0] == "wall_deco":
			var p: Vector2 = d[1] + Vector2(2, 14)
			var ray := PackedVector2Array([p, p + Vector2(16, 0), p + Vector2(52, 96), p + Vector2(28, 96)])
			_lights.draw_colored_polygon(ray, Color(1.0, 0.95, 0.75, 0.07))
	# Brilho alaranjado dos fogões ao lume.
	for station: Station in stations.values():
		if station is StoveStation and (station as StoveStation).state in [StoveStation.State.COOKING, StoveStation.State.READY]:
			_light(cell_center(station.cell), 22.0, Color(1.0, 0.45, 0.15, 0.22 * flicker))


func _light(at: Vector2, radius: float, color: Color) -> void:
	_lights.draw_texture_rect(_light_tex, Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


## Candeeiro pendurado por cima de cada mesa (desenhado por cima dos clientes).
func _draw_lamp(center: Vector2) -> void:
	var top := (center + Vector2(0, -22)).round()
	draw_line(top + Vector2(0, -12), top, Color(0.15, 0.08, 0.06, 0.6), 1.0)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-5, 4), top + Vector2(5, 4), top + Vector2(3, 0), top + Vector2(-3, 0)]), Color("2f5a4a"))
	draw_rect(Rect2(top + Vector2(-2, 4), Vector2(4, 1)), Color("ffe6a0"))


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


## Estação numa célula (a mesa de 4 responde nas duas células).
func station_at(cell: Vector2i) -> Station:
	return stations.get(_alias.get(cell, cell))


## Caminho da porta até uma cadeira: pelo corredor da direita e pela fila livre
## por baixo da mesa.
func path_to_seat(table: TableStation, seat: Vector2i) -> Array[Vector2]:
	var door := _door()
	var corridor_x := door.x - 1
	var below: int = table.cells.back().y + 1
	return [cell_center(door), cell_center(Vector2i(corridor_x, door.y)),
		cell_center(Vector2i(corridor_x, below)), cell_center(Vector2i(seat.x, below)),
		cell_center(seat)]


## Da cadeira até à porta (o caminho de chegada ao contrário).
func path_from_seat(table: TableStation, seat: Vector2i) -> Array[Vector2]:
	var path := path_to_seat(table, seat)
	path.reverse()
	path.pop_front()
	return path


func _door() -> Vector2i:
	for station: Station in stations.values():
		if LAYOUT[station.cell.y][station.cell.x] == "E":
			return station.cell
	return Vector2i.ZERO


func register_center() -> Vector2:
	return cell_center(register.cell)


## Lugar na fila da caixa: o primeiro fica à direita do balcão, os outros no corredor.
func register_spot(index: int) -> Vector2:
	var corridor_x := _door().x - 1
	var r := register.cell
	var spots := [Vector2i(r.x + 1, r.y), Vector2i(corridor_x, r.y), Vector2i(corridor_x, r.y - 1), Vector2i(corridor_x, r.y + 1)]
	return cell_center(spots[mini(index, spots.size() - 1)])


## Da cadeira até ao lugar na fila da caixa, pela fila livre por baixo da mesa e pelo corredor.
func path_to_register(table: TableStation, seat: Vector2i, index: int) -> Array[Vector2]:
	var corridor_x := _door().x - 1
	var below: int = table.cells.back().y + 1
	return [cell_center(Vector2i(seat.x, below)), cell_center(Vector2i(corridor_x, below)),
		cell_center(Vector2i(corridor_x, register.cell.y)), register_spot(index)]


## Do lugar na fila até à porta.
func path_from_register(index: int) -> Array[Vector2]:
	var door := _door()
	var spot := register_spot(index)
	return [Vector2(cell_center(Vector2i(door.x - 1, 0)).x, spot.y),
		cell_center(Vector2i(door.x - 1, door.y)), cell_center(door)]


## Atirar o ingrediente que o chef tem na mão, na direção para onde está virado.
func throw_item(chef: Chef) -> void:
	if chef.held == null or not chef.held.is_ingredient():
		return
	var dir := Vector2(signf(chef.facing.x), 0) if absf(chef.facing.x) > absf(chef.facing.y) else Vector2(0, signf(chef.facing.y))
	thrown.append({"item": chef.held, "pos": chef.position + dir * 8.0, "vel": dir * THROW_SPEED, "dist": 0.0, "slot": chef.slot})
	chef.held = null
	_sfx("dash", -6.0, 0.2)


func _update_thrown(delta: float) -> void:
	for t in thrown.duplicate():
		var step: Vector2 = t["vel"] * delta
		t["pos"] += step
		t["dist"] += step.length()
		var pos: Vector2 = t["pos"]
		# Outro chef de mãos vazias apanha-o no ar.
		for chef in chefs:
			if chef.slot != t["slot"] and chef.held == null and not chef.frozen and chef.position.distance_to(pos) < 12.0:
				chef.held = t["item"]
				thrown.erase(t)
				break
		if not thrown.has(t):
			continue
		var station := station_at(cell_at(pos))
		if station:
			var wall: bool = station.cell.x >= DINING_FROM_X - 1 and station.get_script() == Station
			if not wall and not station is TableStation and station.catch(t["item"]):
				_sfx("drop", -4.0)
			else:
				floor_items.append({"item": t["item"], "pos": pos - (t["vel"] as Vector2).normalized() * 10.0})
			thrown.erase(t)
		elif t["dist"] >= THROW_RANGE:
			floor_items.append({"item": t["item"], "pos": pos})
			_sfx("drop", -6.0)
			thrown.erase(t)


## Ingrediente caído no chão perto de um ponto (ou -1).
func _floor_item_near(at: Vector2) -> int:
	var best := -1
	var best_d := 16.0
	for i in floor_items.size():
		var d: float = (floor_items[i]["pos"] as Vector2).distance_to(at)
		if d < best_d:
			best = i
			best_d = d
	return best


func serialize_loose() -> Array:
	return [thrown.map(func(t): return [Item.serialize(t["item"]), t["pos"], t["dist"]]),
		floor_items.map(func(f): return [Item.serialize(f["item"]), f["pos"]])]


func apply_loose(data: Array) -> void:
	thrown.clear()
	for t in data[0]:
		thrown.append({"item": Item.deserialize(t[0]), "pos": t[1], "vel": Vector2.ZERO, "dist": t[2], "slot": -1})
	floor_items.clear()
	for f in data[1]:
		floor_items.append({"item": Item.deserialize(f[0]), "pos": f[1]})


func interact(chef: Chef, cell: Vector2i) -> void:
	var station := station_at(cell)
	if station == null:
		# Apanhar do chão o que caiu.
		var i := _floor_item_near(chef.position + chef.facing.normalized() * 12.0)
		if i < 0:
			i = _floor_item_near(chef.position)
		if i >= 0:
			var item: Item = floor_items[i]["item"]
			if chef.held == null:
				chef.held = item
				floor_items.remove_at(i)
			elif chef.held.is_plate() and chef.held.try_add(item.content_id()):
				floor_items.remove_at(i)
			elif chef.held.is_cookware() and chef.held.cook_add(item.content_id()):
				floor_items.remove_at(i)
		return
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
	var station := station_at(cell)
	if station:
		station.use(delta)


func _process(delta: float) -> void:
	if simulate:
		for station: Station in stations.values():
			station.tick(delta)
		_update_thrown(delta)
	else:
		# Nos outros PCs os clientes deslizam até à última posição recebida.
		for customer in orders.customers:
			for m in customer.members:
				m.pos = m.pos.lerp(m.net_pos, 0.3)
	_emit_ambient(delta)
	particles.update(delta)
	queue_redraw()
	_lights.queue_redraw()


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
			elif station is RegisterStation and last[1] > 0.22:
				_sfx("ui_move", -4.0, 0.2)
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
		if (customer.is_waiting() or customer.is_calling() or customer.state == Customer.State.AT_REGISTER) and customer.patience < customer.max_patience * 0.3 and randf() < delta * 3.0:
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
			draw_texture_rect_region(Art.themed(_theme(), "wall_top"), Rect2(at, Vector2(TILE, BACK_WALL)), Rect2(0, 0, TILE, BACK_WALL))
	for y in LAYOUT.size():
		for x in cols:
			var tex := Art.themed(_theme(), "floor") if x >= DINING_FROM_X else Art.FLOOR
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
	var chair := Art.themed(_theme(), "chair")
	for table in tables():
		for seat in table.seats:
			# As cadeiras da esquerda ficam viradas para a direita.
			var flip := seat.x < table.cell.x
			var rect := Rect2(Vector2(seat) * TILE, Vector2(TILE, TILE))
			if flip:
				# Com largura negativa o Godot espelha dentro do mesmo retângulo.
				rect = Rect2(rect.position, Vector2(-TILE, TILE))
			draw_texture_rect(chair, rect, false)
	for station: Station in stations.values():
		_draw_station(station)
	for d in DECOR:
		draw_texture(Art.SHELF if d[0] == "shelf" else Art.themed(_theme(), d[0]), d[1])
	for chef in chefs:
		var cell := chef.target_cell()
		var target := station_at(cell)
		if target is TableStation:
			for c in (target as TableStation).cells:
				draw_rect(Rect2(Vector2(c) * TILE, Vector2(TILE, TILE)).grow(-1), chef.color, false, 1.0)
		elif target:
			draw_rect(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)).grow(-1), chef.color, false, 1.0)
	for f in floor_items:
		draw_circle(f["pos"] + Vector2(0, 4), 4.0, Color(0, 0, 0, 0.2))
		ItemArt.draw_item(self, f["item"], f["pos"])
	for t in thrown:
		# Voa num arco: a sombra fica no chão.
		var h := sin(clampf(t["dist"] / THROW_RANGE, 0.0, 1.0) * PI) * 10.0
		draw_circle(t["pos"] + Vector2(0, 4), 3.0, Color(0, 0, 0, 0.2))
		ItemArt.draw_item(self, t["item"], t["pos"] - Vector2(0, h))
	for table in tables():
		_draw_lamp((cell_center(table.cells[0]) + cell_center(table.cells.back())) / 2.0 + Vector2(0, -float(table.cells.size() - 1) * 12.0))
	for customer in orders.customers:
		_draw_customer(customer)
		_draw_customer_end()
	# Sombra suave da parede do fundo sobre o chão.
	for i in 4:
		draw_rect(Rect2(Vector2(0, i * 2), Vector2(pixel_size().x, 2)), Color(0.15, 0.05, 0.03, 0.12 - i * 0.03))
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
	elif station is RegisterStation:
		draw_texture(Art.REGISTER, rect.position)
	elif not station is TrashStation:
		draw_texture(Art.COUNTER, rect.position)

	if station is CrateStation:
		draw_texture(Art.CRATE, rect.position + Vector2(0, -2))
		var id: String = (station as CrateStation).ingredient
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
	draw_texture(Art.themed(_theme(), "wall_front" if front else "wall_top"), rect.position)


func _draw_table(table: TableStation, rect: Rect2) -> void:
	var big := table.capacity() > 2
	draw_texture(Art.themed(_theme(), "table_big" if big else "table"), rect.position)
	draw_string(UiStyle.FONT, rect.position + Vector2(3, 10), "%d" % table.number,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("a02530"))
	# Pratos espalhados pela mesa.
	var spots := [Vector2(-4, -2), Vector2(4, 2), Vector2(-4, 22), Vector2(4, 26)] if big else [Vector2(-4, -2), Vector2(4, 2)]
	for i in table.items.size():
		ItemArt.draw_item(self, table.items[i], rect.get_center() + Vector2(0, -3) + spots[i % spots.size()])


func _theme() -> String:
	return level.get("theme", "classic")


func _draw_customer(customer: Customer) -> void:
	var seated := customer.is_seated()
	for m in customer.members:
		if m.gone:
			continue
		var sitting := seated and m.is_still()
		var walking := not sitting and not m.is_still()
		var col := 3 if sitting else (1 + int(Time.get_ticks_msec() / 150.0) % 2 if walking else 0)
		var bob := -1.0 if walking and col == 1 else 0.0
		var top_left := m.pos - Vector2(Art.CUSTOMER_FRAME.x / 2.0, Art.CUSTOMER_FRAME.y - 6 - bob)
		# Quem está sentado à esquerda da mesa fica virado para a direita.
		var flip := sitting and m.seat.x < customer.table.cell.x
		draw_circle(m.pos + Vector2(0, 5), 5.0, Color(0, 0, 0, 0.2))
		Art.frame(self, Art.CUSTOMER, Art.CUSTOMER_FRAME, col, m.look, top_left, flip)
		Art.frame(self, Art.CUSTOMER_TINT, Art.CUSTOMER_FRAME, col, m.look, top_left, flip, m.color)
	var font := UiStyle.FONT
	# Os balões ficam por cima da mesa (ou de quem vai pagar, na caixa).
	var head := customer.pos + Vector2(0, -16)
	if seated:
		head = cell_center(customer.table.cell) + Vector2(0, -14)
	# Os balões aparecem a crescer com um pequeno salto.
	var since: float = _time - _customer_seen.get(customer.id, [0, -10.0])[1]
	var pop := 1.0 if since > 0.3 else ease(since / 0.3, 0.4) * (1.0 + 0.25 * sin(since / 0.3 * PI))
	if customer.state in [Customer.State.CALLING, Customer.State.WAITING, Customer.State.AT_REGISTER]:
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
			# Balão com os pratos que ainda faltam e a paciência.
			var missing := customer.missing()
			var bubble_center := head + Vector2(0, -14)
			var w := maxf(22.0, missing.size() * 18.0 + 4.0)
			_draw_bubble(bubble_center, w)
			for k in missing.size():
				var plate := Item.plate()
				plate.contents.assign(missing[k]["needs"])
				ItemArt.draw_item(self, plate, bubble_center + Vector2((k - (missing.size() - 1) / 2.0) * 18.0, -1))
			_draw_patience(customer, bubble_center)
		Customer.State.EATING:
			# Garfadas: corações pequenos de vez em quando.
			if int(since * 2.0) % 3 == 0:
				var h := (head + Vector2(-2, -6 - fmod(since * 6.0, 4.0))).round()
				for rr in [Rect2(h, Vector2(2, 2)), Rect2(h + Vector2(3, 0), Vector2(2, 2)), Rect2(h + Vector2(0, 1), Vector2(5, 2)),
						Rect2(h + Vector2(1, 3), Vector2(3, 1)), Rect2(h + Vector2(2, 4), Vector2(1, 1))]:
					draw_rect(rr, UiStyle.RED)
		Customer.State.AT_REGISTER:
			# Balão com uma moeda: está à espera de pagar.
			if customer.members[0].is_still():
				var bubble_center := head + Vector2(0, -14)
				Art.centered(self, Art.BUBBLE, bubble_center)
				draw_texture_rect(Art.COIN, Rect2(bubble_center - Vector2(6, 7), Vector2(12, 12)), false)
				_draw_patience(customer, bubble_center)
		Customer.State.LEAVING:
			if customer.angry:
				draw_string(font, head + Vector2(-12, -2), "!!", HORIZONTAL_ALIGNMENT_CENTER, 24, 12, Color("e8574d"))


## Balão de fala com a largura pedida (para vários pratos).
func _draw_bubble(center: Vector2, width: float) -> void:
	if width <= 24.0:
		Art.centered(self, Art.BUBBLE, center)
		return
	var rect := Rect2((center - Vector2(width / 2.0, 9)).round(), Vector2(width, 17))
	draw_rect(rect.grow(1), UiStyle.INK)
	draw_rect(rect, Color("fff8e6"))
	draw_rect(Rect2(rect.position + Vector2(0, 13), Vector2(width, 4)), Color("f6e6c4"))
	var tip := (center + Vector2(-2, 9)).round()
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-3, 0), tip + Vector2(4, 0), tip + Vector2(0, 4)]), Color("f6e6c4"))


func _draw_customer_end() -> void:
	draw_set_transform(Vector2.ZERO)


func _draw_patience(customer: Customer, bubble_center: Vector2) -> void:
	var t := customer.patience / customer.max_patience
	var bar := Rect2((bubble_center + Vector2(-10, 13)).round(), Vector2(20, 3))
	draw_rect(bar.grow(1), UiStyle.BG)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)), Color("e8574d").lerp(Color("6fcf6a"), t))


func _draw_stove(stove: StoveStation, rect: Rect2) -> void:
	var center := rect.get_center() + Vector2(0, -3)
	# Chamas à volta da panela quando está ao lume (a panela desenha-se como item).
	if stove.state in [StoveStation.State.COOKING, StoveStation.State.READY]:
		var t := Time.get_ticks_msec() / 90
		for i in 5:
			var h := 2 + (t + i * 3) % 3
			var x := center.x - 8 + i * 4
			draw_rect(Rect2(Vector2(x, center.y + 7 - h), Vector2(2, h)), Color("f2a03a"))
			draw_rect(Rect2(Vector2(x, center.y + 7 - 1), Vector2(2, 1)), Color("e0503a"))
	# Alerta a piscar quando está quase a queimar.
	if stove.is_burning_soon() and int(Time.get_ticks_msec() / 200.0) % 2 == 0:
		draw_string(UiStyle.FONT, rect.position + Vector2(0, -2), "!",
			HORIZONTAL_ALIGNMENT_CENTER, TILE, 14, Color("e8574d"))


func _make_station(c: String) -> Station:
	match c:
		"a", "b", "c", "d", "e":
			var crates: Array = level["crates"]
			var index := "abcde".find(c)
			return CrateStation.new(crates[index]) if index < crates.size() else Station.new()
		"N": return TableStation.new()
		"B": return BoardStation.new()
		"S": return StoveStation.new()
		"P": return PlateStation.new()
		"W": return SinkStation.new()
		"M": return TableStation.new()
		"X": return TrashStation.new()
		"R": return RegisterStation.new()
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
