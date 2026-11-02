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
const FLOOR_SHADER := preload("res://assets/shaders/floor.gdshader")
const HEAT_SHADER := preload("res://assets/shaders/heat.gdshader")
## Cor dos tapetes debaixo das mesas grandes (texturas altas), por tema.
const RUG_COLORS := {
	"classic": Color("8e2f3a"), "portugal": Color("2f5a8e"), "japan": Color("6b7f3a"),
	"diner": Color("b8322f"), "italy": Color("2f6b45"),
}

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
## Camadas dos gráficos (ver Gfx): chão (por baixo de tudo), luz ambiente
## (multiplica), luzes (somam) e ar quente por cima dos fogões.
var _floor: Node2D
var _floor_mat: ShaderMaterial
var _ambient: Node2D
var _heat: Node2D
var _tint: CanvasModulate
## Mancha redonda e suave (sombras, brilhos).
var _blob_tex: Texture2D
## Luzes deste frame: {"pos", "radius", "color", "cast"} (cast = faz sombra nas pessoas).
var _light_list: Array[Dictionary] = []
## 0 = tarde, 1 = noite. O nível avança-o durante a ronda (só se nota na iluminação Ultra).
var evening := 0.35
## Ajudantes controlados pelo jogo (HelperAI), para não irem dois ao mesmo sítio.
var helpers: Array = []
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
var _station_seen := {}  # célula -> [o que lá está, momento da mudança]
var _bell_time := -10.0  # campainha do passe a abanar
var _register_time := -10.0  # gaveta da caixa aberta
var _door_time := -10.0  # porta a abrir
var _bar_count := 0
var _time := 0.0
## Sem sons (o restaurante a funcionar por trás do menu).
var quiet := false

## Um efeito de texto (pontos, "Anotado!"). Online, o nível reenvia-o aos outros PCs.
signal fx(at: Vector2, text: String, color: Color, sparkle: bool)
## Alguém carregou em pegar virado para a porta (modo Casa Aberta: abrir/fechar).
signal door_used(chef: Chef)
## No modo Casa Aberta a porta é um "botão" e não uma bancada.
var door_button := false


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
				if station is PassStation:
					(station as PassStation).plate_ready.connect(func(at: Vector2i):
						show_fx(cell_center(at), "Pronto!", Color("f2c94c"))
						_bell_time = _time)
	_make_layers()
	var number := 1
	for table in tables():
		table.number = number
		number += 1


## Camadas de gráficos: chão (desenhado uma vez, com shader no Ultra), luz
## ambiente (multiplica), luzes (somam) e ar quente dos fogões. O que se vê
## depende das opções em Gfx e muda logo que se mexe nelas.
func _make_layers() -> void:
	_light_tex = _radial(64, [Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_blob_tex = _radial(32, [Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	_floor = Node2D.new()
	_floor.z_index = -1
	_floor.draw.connect(_draw_floor)
	add_child(_floor)
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = FLOOR_SHADER
	_heat = Node2D.new()
	_heat.z_index = 40
	var heat_mat := ShaderMaterial.new()
	heat_mat.shader = HEAT_SHADER
	_heat.material = heat_mat
	_heat.draw.connect(_draw_heat)
	add_child(_heat)
	_ambient = Node2D.new()
	_ambient.z_index = 49
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_ambient.material = mul
	_ambient.draw.connect(func():
		# A cozinha tem luz branca de trabalho: escurece muito menos que o salão.
		var c := _ambient_color()
		var k := Rect2(Vector2(TILE, TILE), Vector2((DINING_FROM_X - 1) * TILE, pixel_size().y - 2 * TILE))
		var all := Rect2(Vector2(-400, -400), pixel_size() + Vector2(800, 800))
		_ambient.draw_rect(Rect2(all.position, Vector2(k.position.x - all.position.x, all.size.y)), c)
		_ambient.draw_rect(Rect2(Vector2(k.end.x, all.position.y), Vector2(all.end.x - k.end.x, all.size.y)), c)
		_ambient.draw_rect(Rect2(Vector2(k.position.x, all.position.y), Vector2(k.size.x, k.position.y - all.position.y)), c)
		_ambient.draw_rect(Rect2(Vector2(k.position.x, k.end.y), Vector2(k.size.x, all.end.y - k.end.y)), c)
		_ambient.draw_rect(k, c.lerp(Color(1, 1, 1), 0.6)))
	add_child(_ambient)
	_lights = Node2D.new()
	_lights.z_index = 50
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lights.material = mat
	_lights.draw.connect(_draw_lights)
	add_child(_lights)
	# Na iluminação simples, um tom quente por cima de tudo (como na 0.4).
	_tint = CanvasModulate.new()
	_tint.color = Color(0.93, 0.88, 0.84)
	add_child(_tint)
	Gfx.changed.connect(_apply_gfx)
	_apply_gfx()


func _apply_gfx() -> void:
	_floor.material = _floor_mat if Gfx.textures >= 3 else null
	_ambient.visible = Gfx.lighting >= 2
	_lights.visible = Gfx.lighting >= 1
	_tint.visible = Gfx.lighting == 1
	_heat.visible = Gfx.heat > 0
	particles.limit = 700 if Gfx.particles >= 2 else Particles.MAX
	_floor.queue_redraw()


static func _radial(size: int, colors: Array) -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0]) if colors.size() == 3 else PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray(colors)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex


## Cor da luz ambiente: fim de tarde dourado a passar a noite azulada (Ultra).
func _ambient_color() -> Color:
	var e := evening if Gfx.lighting >= 3 else 0.3
	return Color(0.9, 0.84, 0.78).lerp(Color(0.56, 0.55, 0.76), e)


## Recolhe as luzes deste frame (candeeiros, caixa, janelas, fogões, passe e cozinha).
func _collect_lights() -> void:
	_light_list.clear()
	var warm := Color(1.0, 0.72, 0.4)
	var flicker := 0.9 + 0.1 * sin(_time * 7.0) * sin(_time * 3.1)
	var rich := Gfx.lighting >= 2
	var night := evening if Gfx.lighting >= 3 else 0.3
	for table in tables():
		var center := (cell_center(table.cells[0]) + cell_center(table.cells.back())) / 2.0
		var energy := (0.22 if not rich else 0.3 + 0.16 * night) * flicker
		var radius := 56.0 if not rich else (66.0 if table.capacity() > 2 else 50.0)
		var lamp_center := (center + Vector2(0, -float(table.cells.size() - 1) * 12.0))
		_light_list.append({"pos": center + Vector2(lamp_sway(lamp_center) * 1.5, 0), "radius": radius, "color": Color(warm, energy), "cast": true})
	_light_list.append({"pos": cell_center(register.cell), "radius": 30.0 if not rich else 40.0, "color": Color(warm, 0.14 if not rich else 0.2), "cast": rich})
	if true:
		# Luzes do teto da cozinha, brancas e fortes, para se ver bem o que se cozinha.
		var white := Color(1.0, 0.95, 0.85)
		var w := (DINING_FROM_X - 1) * TILE
		var h := pixel_size().y
		for fx in [0.22, 0.5, 0.78]:
			for fy in [0.2, 0.5, 0.8]:
				var at := Vector2(TILE + w * fx, h * fy)
				_light_list.append({"pos": at, "radius": 80.0, "color": Color(white, (0.035 + 0.035 * night) if rich else 0.06), "cast": rich and fx == 0.5 and fy != 0.5})
	for station: Station in stations.values():
		if station is StoveStation and (station as StoveStation).state in [StoveStation.State.COOKING, StoveStation.State.READY]:
			_light_list.append({"pos": cell_center(station.cell), "radius": 22.0 if not rich else 34.0, "color": Color(1.0, 0.45, 0.15, (0.22 if not rich else 0.32) * flicker), "cast": rich})
		elif station is PassStation and station.item != null:
			# Lâmpada de calor do passe, avermelhada, quando há lá um prato.
			_light_list.append({"pos": cell_center(station.cell), "radius": 20.0 if not rich else 28.0, "color": Color(1.0, 0.4, 0.25, 0.22), "cast": false})


func _draw_lights() -> void:
	var rich := Gfx.lighting >= 2
	var night := evening if Gfx.lighting >= 3 else 0.3
	for l in _light_list:
		_light(l["pos"], l["radius"], l["color"])
		if Gfx.lighting >= 3:
			# Halo largo e fraco: a luz espalha-se pelo ar.
			var c: Color = l["color"]
			_light(l["pos"], l["radius"] * 1.8, Color(c, c.a * 0.1))
	# Raios de sol das janelas, em diagonal pelo chão do salão (desaparecem à noite).
	var sun := 1.0 - night if Gfx.lighting >= 3 else 1.0
	for d in DECOR:
		if d[0] == "wall_deco":
			var p: Vector2 = d[1] + Vector2(2, 14)
			if not rich:
				var ray := PackedVector2Array([p, p + Vector2(16, 0), p + Vector2(52, 96), p + Vector2(28, 96)])
				_lights.draw_colored_polygon(ray, Color(1.0, 0.95, 0.75, 0.07))
				continue
			# Várias camadas, mais largas e mais fracas, para os bordos ficarem suaves.
			var sway := sin(_time * 0.6 + p.x) * 2.0
			for k in 4:
				var g := k * 3.0
				var ray := PackedVector2Array([p + Vector2(-g * 0.3, 0), p + Vector2(16 + g * 0.3, 0),
					p + Vector2(56 + g + sway, 110), p + Vector2(26 - g + sway, 110)])
				_lights.draw_colored_polygon(ray, Color(1.0, 0.9, 0.65, 0.035 * sun))


func _light(at: Vector2, radius: float, color: Color) -> void:
	_lights.draw_texture_rect(_light_tex, Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


## Sombra de uma pessoa (chef ou cliente) aos pés. Com sombras Ultra, cada luz
## perto faz também uma sombra comprida para o lado oposto.
func draw_actor_shadow(ci: CanvasItem, at: Vector2, world: Vector2, radius := 6.0) -> void:
	match Gfx.shadows:
		0:
			return
		1:
			ci.draw_circle(at, radius, Color(0, 0, 0, 0.22))
			return
	_blob(ci, at, Vector2(radius * 2.8, radius * 1.6), 0.0, 0.42)
	if Gfx.shadows >= 3:
		var n := 0
		for l in _light_list:
			if not l["cast"]:
				continue
			var d: Vector2 = world - l["pos"]
			var reach: float = l["radius"] * 1.4
			var dist := d.length()
			if dist > reach or dist < 2.0:
				continue
			var k := 1.0 - dist / reach
			var length := 8.0 + 14.0 * (1.0 - k)
			var dir := d / dist
			var strength: float = clampf((l["color"] as Color).a * 1.6, 0.0, 1.0)
			_blob(ci, at + dir * length * 0.45, Vector2(length + radius, radius * 1.3), dir.angle(), 0.38 * k * strength + 0.06)
			n += 1
			if n >= 3:
				break
	ci.draw_set_transform(Vector2.ZERO)


func _blob(ci: CanvasItem, center: Vector2, size: Vector2, angle: float, alpha: float) -> void:
	ci.draw_set_transform(center, angle, size / 32.0)
	ci.draw_texture(_blob_tex, Vector2(-16, -16), Color(0, 0, 0, alpha))
	ci.draw_set_transform(Vector2.ZERO)


## Ar quente a tremer por cima dos fogões ao lume.
func _draw_heat() -> void:
	for station: Station in stations.values():
		if station is StoveStation and (station as StoveStation).state in [StoveStation.State.COOKING, StoveStation.State.READY]:
			var c := cell_center(station.cell)
			_heat.draw_texture_rect(_blob_tex, Rect2(c + Vector2(-14, -34), Vector2(28, 34)), false)


## Chão, parede do fundo, tapetes e sombras paradas. Só se redesenha quando
## mudam as opções de gráficos.
func _draw_floor() -> void:
	var ci := _floor
	var cols := LAYOUT[0].length()
	ci.draw_rect(Rect2(Vector2(-200, -200), pixel_size() + Vector2(400, 400)), BG)
	ci.draw_rect(Rect2(Vector2(-3, -BACK_WALL - 3), pixel_size() + Vector2(6, BACK_WALL + 6)), Color("1a0f12"))
	for x in cols:
		var at := Vector2(x * TILE, -BACK_WALL)
		if x < DINING_FROM_X - 1:
			ci.draw_texture(Art.BACKWALL_KITCHEN, at)
		else:
			ci.draw_texture_rect_region(Art.themed(_theme(), "wall_top"), Rect2(at, Vector2(TILE, BACK_WALL)), Rect2(0, 0, TILE, BACK_WALL))
	for y in LAYOUT.size():
		for x in cols:
			var tex := Art.themed(_theme(), "floor") if x >= DINING_FROM_X else Art.FLOOR
			var n := tex.get_width() / TILE
			ci.draw_texture_rect_region(tex, Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE)),
				Rect2(Vector2(x % n, y % n) * TILE, Vector2(TILE, TILE)))
	if Gfx.textures >= 2:
		_draw_floor_detail(ci)
	_draw_static_shadows(ci)


## Texturas altas: ladrilhos com tons ligeiramente diferentes, marcas de uso à
## frente das bancadas, cantos mais escuros e tapetes debaixo das mesas grandes.
func _draw_floor_detail(ci: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in LAYOUT.size():
		for x in LAYOUT[y].length():
			var cell := Vector2i(x, y)
			if stations.has(cell) or _alias.has(cell):
				continue
			var v := rng.randf_range(-1.0, 1.0)
			var shade := Color(1, 0.95, 0.85, 0.05 * v) if v > 0.0 else Color(0.25, 0.12, 0.05, -0.06 * v)
			ci.draw_rect(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)), shade)
			# Desgaste à frente das estações onde se trabalha.
			var up: Station = stations.get(cell + Vector2i.UP)
			var down: Station = stations.get(cell + Vector2i.DOWN)
			for s in [up, down]:
				if s is BoardStation or s is StoveStation or s is SinkStation or s is CrateStation:
					_blob(ci, cell_center(cell), Vector2(30, 22), 0.0, 0.06)
	# Tapetes debaixo das mesas grandes, com a cor do restaurante.
	var rug: Color = RUG_COLORS.get(_theme(), RUG_COLORS["classic"])
	for table in tables():
		if table.capacity() <= 2:
			continue
		var r := Rect2(Vector2(table.cells[0] + Vector2i.LEFT) * TILE + Vector2(4, -4), Vector2(TILE * 3 - 8, TILE * 2 + 8))
		ci.draw_rect(r.grow(1), Color(rug.darkened(0.55), 0.9))
		ci.draw_rect(r, rug)
		ci.draw_rect(r.grow(-3), rug.lightened(0.18), false, 1.0)
		ci.draw_rect(r.grow(-6), Color(rug.darkened(0.15), 0.8))
		for k in range(int(r.position.x) + 2, int(r.end.x) - 1, 3):
			ci.draw_rect(Rect2(Vector2(k, r.position.y - 2), Vector2(1, 2)), rug.lightened(0.3))
			ci.draw_rect(Rect2(Vector2(k, r.end.y), Vector2(1, 2)), rug.lightened(0.3))


func _draw_static_shadows(ci: CanvasItem) -> void:
	if Gfx.shadows == 0:
		return
	var cols := LAYOUT[0].length()
	var soft := Gfx.shadows >= 2
	var length := 4 if Gfx.shadows >= 3 else 3
	for station: Station in stations.values():
		var cells: Array[Vector2i] = [station.cell]
		for cell in cells:
			var below := cell + Vector2i.DOWN
			var right := cell + Vector2i.RIGHT
			var free_below := below.y < LAYOUT.size() and not stations.has(below) and not _alias.has(below)
			var free_right := right.x < cols and not stations.has(right) and not _alias.has(right)
			if not soft:
				if free_below:
					ci.draw_rect(Rect2(Vector2(below) * TILE, Vector2(TILE, 4)), Color(0.2, 0.08, 0.05, 0.28))
				if free_right:
					ci.draw_rect(Rect2(Vector2(right) * TILE, Vector2(3, TILE)), Color(0.2, 0.08, 0.05, 0.18))
				continue
			# Sombras suaves: faixas cada vez mais fracas (luz de cima à esquerda).
			for k in length:
				var a := 0.3 * (1.0 - float(k) / length)
				if free_below:
					ci.draw_rect(Rect2(Vector2(below) * TILE + Vector2(k * 0.5, k * 2), Vector2(TILE, 2)), Color(0.2, 0.08, 0.05, a))
				if free_right:
					ci.draw_rect(Rect2(Vector2(right) * TILE + Vector2(k * 2, k * 0.5), Vector2(2, TILE)), Color(0.2, 0.08, 0.05, a * 0.6))
	if soft:
		# Sombra de contacto debaixo das mesas e das cadeiras.
		for table in tables():
			var center := (cell_center(table.cells[0]) + cell_center(table.cells.back())) / 2.0
			_blob(ci, center + Vector2(2, 8), Vector2(34, 18 + 24 * (table.cells.size() - 1)), 0.0, 0.35)
			for seat in table.seats:
				_blob(ci, cell_center(seat) + Vector2(1, 8), Vector2(20, 9), 0.0, 0.3)
	# Sombra da parede do fundo sobre o chão.
	var rows := 8 if soft else 4
	for i in rows:
		ci.draw_rect(Rect2(Vector2(0, i * 2), Vector2(pixel_size().x, 2)), Color(0.15, 0.05, 0.03, (0.16 if soft else 0.12) * (1.0 - float(i) / rows)))


func _update_floor_shader() -> void:
	if _floor.material == null:
		return
	var pos := []
	var col := []
	for l in _light_list:
		if pos.size() >= 16:
			break
		var p: Vector2 = l["pos"]
		# O reflexo no chão polido aparece um pouco abaixo da luz.
		pos.append(Vector4(p.x, p.y + 14.0, l["radius"] * 0.9, 1.0))
		col.append(l["color"])
	while pos.size() < 16:
		pos.append(Vector4.ZERO)
		col.append(Color(0, 0, 0, 0))
	_floor_mat.set_shader_parameter("lights", pos)
	_floor_mat.set_shader_parameter("light_colors", col)
	_floor_mat.set_shader_parameter("light_count", mini(_light_list.size(), 16))
	_floor_mat.set_shader_parameter("floor_size", pixel_size())


## Candeeiro pendurado por cima de cada mesa (desenhado por cima dos clientes).
## Quanto o candeeiro desta mesa baloiça agora (Ultra: devagarinho, como se
## houvesse uma corrente de ar quando a porta abre).
func lamp_sway(center: Vector2) -> float:
	if Gfx.lighting < 3:
		return 0.0
	var door_push := maxf(0.0, 1.0 - (_time - _door_time) / 3.0)
	return sin(_time * 1.3 + center.y * 0.05) * (0.8 + door_push * 1.6)


func _draw_lamp(center: Vector2) -> void:
	var sway := lamp_sway(center)
	var hook := (center + Vector2(0, -34)).round()
	var top := (center + Vector2(sway, -22)).round()
	draw_line(hook, top, Color(0.15, 0.08, 0.06, 0.6), 1.0)
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


func door_cell() -> Vector2i:
	return _door()


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
	_sfx("throw", -2.0, 0.15)


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
				_sfx("catch", -2.0)
				particles.ring(pos, 10.0, Color(chef.color, 0.9))
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
	if door_button and station and cell == _door():
		door_used.emit(chef)
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
	elif text == "Pronto!":
		_sfx("bell")
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
	_collect_lights()
	_update_floor_shader()
	queue_redraw()
	_lights.queue_redraw()
	_ambient.queue_redraw()
	_heat.queue_redraw()


## Fumo, vapor e suor que saem das estações e dos clientes.
func _emit_ambient(delta: float) -> void:
	_time += delta
	var cooking := 0
	var pr := Gfx.particle_rate()
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
		_watch_station(station)
		if station is StoveStation and (station as StoveStation).state in [StoveStation.State.COOKING, StoveStation.State.READY]:
			cooking += 1
		var center := cell_center(station.cell)
		if station is StoveStation:
			var stove := station as StoveStation
			if stove.state == StoveStation.State.COOKING and randf() < delta * 6.0 * pr:
				particles.steam(center + Vector2(randf_range(-5, 5), -6))
			elif stove.state == StoveStation.State.READY and stove.is_burning_soon() and randf() < delta * 10.0 * pr:
				particles.smoke(center + Vector2(randf_range(-5, 5), -6), false)
			elif stove.state == StoveStation.State.BURNT and randf() < delta * 8.0 * pr:
				particles.smoke(center + Vector2(randf_range(-5, 5), -6), true)
			if Gfx.particles >= 2 and stove.state == StoveStation.State.COOKING and randf() < delta * 3.0:
				particles.ember(center + Vector2(randf_range(-7, 7), 2))
		elif station is BoardStation and station.progress() > 0.0 and randf() < delta * 12.0 * pr:
			particles.chop(center, station.item)
		elif station is SinkStation and station.progress() > 0.0 and randf() < delta * 10.0 * pr:
			particles.bubble(center + Vector2(randf_range(-7, 7), randf_range(-3, 3)))
	if not quiet:
		Sfx.set_sizzle(cooking / 2.0)
	for customer in orders.customers:
		if (customer.is_waiting() or customer.is_calling() or customer.state == Customer.State.AT_REGISTER) and customer.patience < customer.max_patience * 0.3 and randf() < delta * 3.0 * pr:
			particles.sweat(customer.pos + Vector2(6, -14))
		var seen: Array = _customer_seen.get(customer.id, [-1, 0.0])
		if seen[0] != customer.state:
			_customer_event(customer, seen[0])
			_customer_seen[customer.id] = [customer.state, _time]
	if Gfx.particles >= 2:
		# Pó a flutuar nos raios de sol e vapor dos pratos acabados de servir.
		for d in DECOR:
			if d[0] == "wall_deco" and randf() < delta * 1.5 * (1.0 - evening * 0.7):
				var p: Vector2 = d[1] + Vector2(randf_range(8, 46), randf_range(24, 110))
				particles.mote(p)
		for table in tables():
			if table.customer != null and table.customer.state in [Customer.State.WAITING, Customer.State.EATING]:
				for i in table.items.size():
					if randf() < delta * 1.2:
						particles.steam(cell_center(table.cell) + Vector2(randf_range(-6, 6), -6 + (i / 2) * 24))


## Cantos a pulsar à volta da estação para onde um chef está virado.
func _draw_brackets(r: Rect2, color: Color) -> void:
	var g := 1.0 + absf(sin(_time * 5.0)) * 1.5
	r = r.grow(g - 1.0)
	var l := 5.0
	var c := Color(color, 0.95)
	var dark := Color(UiStyle.INK, 0.6)
	for corner in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
			[Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		for pass_i in 2:
			var off := Vector2(0, 1) if pass_i == 0 else Vector2.ZERO
			var col := dark if pass_i == 0 else c
			draw_line(p + off, p + off + Vector2(d.x * l, 0), col, 2.0)
			draw_line(p + off, p + off + Vector2(0, d.y * l), col, 2.0)


## Sons e efeitos quando um grupo muda de fase (corre igual em todos os PCs,
## porque olha só para o estado que chega por rede).
func _customer_event(customer: Customer, before: int) -> void:
	var head := cell_center(customer.table.cell) + Vector2(0, -16)
	match customer.state:
		Customer.State.ARRIVING:
			if before == -1:
				_sfx("door", -6.0, 0.03)
				_door_time = _time
		Customer.State.CALLING:
			_sfx("bell", -3.0)
		Customer.State.WAITING:
			particles.ring(head, 14.0, Color("f2c94c"))
		Customer.State.EATING:
			_sfx("served", -3.0, 0.02)
			_sfx("happy", -8.0, 0.15)
			particles.hearts(head, 3 + customer.size())
			particles.ring(cell_center(customer.table.cell), 18.0, Color(1, 0.8, 0.9, 0.9), 0.5)
		Customer.State.LEAVING:
			if customer.angry:
				_sfx("angry", -2.0, 0.1)
				var at := customer.members[0].pos + Vector2(0, -22) if before == Customer.State.AT_REGISTER else head
				particles.storm(at)
			elif before == Customer.State.AT_REGISTER:
				_sfx("kaching", -2.0, 0.03)
				particles.coins(register_center() + Vector2(0, -8), 7)
				particles.ring(register_center(), 16.0, Color("f6c444"))
				_register_time = _time


## O que está numa estação, para se saber quando muda.
func _station_key(station: Station) -> String:
	var it := station.item
	var k := "" if it == null else "%s%s%s%d%d" % [it.kind, it.chopped, it.contents, it.cook_state, it.stack]
	if station is SinkStation:
		k += "s%d" % (station as SinkStation).dirty
	elif station is PlateStation:
		k += "p%d" % (station as PlateStation).count
	return k


## Pequenos efeitos quando o que está numa estação muda: o item que se pousa dá
## um pulo e uma onda, o que cai na panela salpica, a panela pronta abana a
## tampa e a queimada faz fumo.
func _watch_station(station: Station) -> void:
	var key := _station_key(station)
	var center := cell_center(station.cell) + Vector2(0, -3)
	if not _station_seen.has(station.cell):
		_station_seen[station.cell] = [key, -10.0, _cook_state(station)]
		return
	var seen: Array = _station_seen[station.cell]
	if seen[0] == key:
		return
	var before_state: int = seen[2]
	var state := _cook_state(station)
	var appeared: bool = String(seen[0]).is_empty() and station.item != null
	seen[0] = key
	seen[1] = _time
	seen[2] = state
	if appeared:
		particles.ring(center, 10.0, Color(1, 1, 1, 0.7), 0.3)
	if station is StoveStation:
		if state != before_state:
			if state == StoveStation.State.READY:
				_sfx("lid", -2.0)
				particles.ring(center, 14.0, Color("6fcf6a"))
			elif state == StoveStation.State.BURNT:
				_sfx("burn", -2.0)
				for i in 6:
					particles.smoke(center + Vector2(randf_range(-6, 6), -4), true)
		if station.item and station.item.is_cookware() and state in [StoveStation.State.FILLING, StoveStation.State.COOKING] and not appeared:
			_sfx("splash", -6.0, 0.15)
			particles.splash(center + Vector2(0, -3), Color("f2b07a"))
	elif station is SinkStation and (station as SinkStation).dirty > 0:
		particles.splash(center, Color("bfe3f2"))


func _cook_state(station: Station) -> int:
	return station.item.cook_state if station.item and station.item.is_cookware() else -1


## 0 → 1 → 0: o pulo de quando se pousa uma coisa numa estação.
func item_pop(cell: Vector2i) -> float:
	var age: float = _time - _station_seen.get(cell, ["", -10.0])[1]
	return 0.0 if age > 0.3 else sin(age / 0.3 * PI) * (1.0 - age / 0.3)


func _draw() -> void:
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
	if Gfx.textures >= 1:
		for d in DECOR:
			draw_texture(Art.SHELF if d[0] == "shelf" else Art.themed(_theme(), d[0]), d[1])
	for chef in chefs:
		var cell := chef.target_cell()
		var target := station_at(cell)
		if target is TableStation:
			var cells: Array[Vector2i] = (target as TableStation).cells
			var r := Rect2(Vector2(cells[0]) * TILE, Vector2(TILE, TILE * cells.size()))
			_draw_brackets(r, chef.color)
		elif target:
			_draw_brackets(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)), chef.color)
	for f in floor_items:
		draw_actor_shadow(self, f["pos"] + Vector2(0, 4), f["pos"], 4.0)
		ItemArt.draw_item(self, f["item"], f["pos"])
	for t in thrown:
		# Voa num arco: a sombra fica no chão.
		var h := sin(clampf(t["dist"] / THROW_RANGE, 0.0, 1.0) * PI) * 10.0
		draw_actor_shadow(self, t["pos"] + Vector2(0, 4), t["pos"], 3.0)
		# Roda no ar, com um rasto.
		var vel: Vector2 = t["vel"]
		if vel != Vector2.ZERO:
			for k in 3:
				var back: Vector2 = t["pos"] - vel.normalized() * (k + 1) * 4.0 - Vector2(0, h)
				draw_circle(back, 2.0 - k * 0.5, Color(1, 1, 1, 0.35 - k * 0.1))
		draw_set_transform(t["pos"] - Vector2(0, h), t["dist"] * 0.12, Vector2.ONE)
		ItemArt.draw_item(self, t["item"], Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
	for table in tables():
		_draw_lamp((cell_center(table.cells[0]) + cell_center(table.cells.back())) / 2.0 + Vector2(0, -float(table.cells.size() - 1) * 12.0))
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
		# A porta abre-se quando entra um grupo.
		var age := _time - _door_time
		var open := 0.0 if age > 1.4 else sin(clampf(age / 1.4, 0.0, 1.0) * PI)
		if open > 0.0:
			draw_rect(rect, Color("2a1a1e"))
			draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 3), Vector2(rect.size.x, 3)), Color(1, 0.85, 0.5, 0.5 * open))
		draw_texture_rect(Art.DOOR, Rect2(rect.position, Vector2(rect.size.x * (1.0 - open * 0.75), rect.size.y)), false)
	elif station.cell.x >= DINING_FROM_X - 1 and station.get_script() == Station:
		_draw_wall(station.cell, rect)
	elif station is StoveStation:
		draw_texture(Art.STOVE, rect.position)
	elif station is RegisterStation:
		draw_texture(Art.REGISTER, rect.position)
	elif station is PassStation:
		_draw_pass(station as PassStation, rect)
	elif station is BarStation:
		_draw_bar(station as BarStation, rect)
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
		# Pilha de pratos (até 5 à vista; o número diz quantos há).
		var count := (station as PlateStation).count
		for i in mini(count, 5):
			Art.centered(self, Art.PLATE, center - Vector2(0, i * 2))
		if count > 5:
			draw_string(UiStyle.FONT, rect.position + Vector2(1, 23), "%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiStyle.INK)
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
		var pop := item_pop(station.cell)
		if pop > 0.0:
			draw_set_transform(center + Vector2(0, -pop * 4.0), 0.0, Vector2(1.0 + pop * 0.3, 1.0 + pop * 0.3))
			ItemArt.draw_item(self, station.item, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO)
		elif station is StoveStation and (station as StoveStation).state == StoveStation.State.READY:
			# Tampa a abanar: a panela treme quando está pronta.
			ItemArt.draw_item(self, station.item, center + Vector2(roundf(sin(_time * 40.0) * 0.6), 0))
		else:
			ItemArt.draw_item(self, station.item, center)
	if station is RegisterStation:
		# Gaveta da caixa a abrir quando se cobra.
		var age := _time - _register_time
		if age < 0.9:
			var out := minf(age / 0.08, 1.0) * (1.0 - clampf((age - 0.6) / 0.3, 0.0, 1.0))
			var drawer := Rect2(rect.position + Vector2(4, 15 + out * 4.0), Vector2(16, 4))
			draw_rect(drawer.grow(1), UiStyle.INK)
			draw_rect(drawer, Color("c79a52"))
			draw_rect(Rect2(drawer.position + Vector2(2, 1), Vector2(12, 1)), Color("f6c444"))
	var p := station.progress()
	if p >= 0.0:
		var bar := Rect2(rect.position + Vector2(2, -6), Vector2(TILE - 4, 4))
		draw_rect(bar, UiStyle.BG)
		draw_rect(Rect2(bar.position + Vector2.ONE, Vector2((bar.size.x - 2) * p, bar.size.y - 2)), Color("6fcf6a"))


## Torneira do bar na parede: balcão de madeira, máquina de inox com a cor da
## bebida e um copo de exemplo quando está vazio.
func _draw_bar(bar: BarStation, rect: Rect2) -> void:
	_draw_wall(bar.cell, rect)
	var c: Color = Recipes.DRINK_COLORS.get(bar.drink, Color.WHITE)
	var body := Rect2(rect.position + Vector2(3, 1), Vector2(18, 18))
	draw_rect(body.grow(1), UiStyle.INK)
	draw_rect(body, Color("8d6a4a"))
	draw_rect(Rect2(body.position, Vector2(body.size.x, 3)), Color("b48a5e"))
	var machine := Rect2(rect.position + Vector2(6, -6), Vector2(12, 12))
	draw_rect(machine.grow(1), UiStyle.INK)
	draw_rect(machine, Color("b8bec8"))
	draw_rect(Rect2(machine.position + Vector2(2, 2), Vector2(8, 4)), c)
	draw_rect(Rect2(machine.position + Vector2(2, 2), Vector2(8, 1)), c.lightened(0.4))
	draw_rect(Rect2(machine.position + Vector2(5, 9), Vector2(2, 4)), Color("4a4352"))
	if bar.progress() > 0.0:
		# A cair um fio da bebida.
		draw_rect(Rect2(machine.position + Vector2(5.5, 13), Vector2(1, 3)), c)
	if bar.item == null:
		draw_rect(Rect2(rect.position + Vector2(9, 12), Vector2(6, 1)), Color(1, 1, 1, 0.25))


## Passe: bancada com tampo de inox, campainha no do meio e, quando lá está
## um prato pronto, o número da mesa que o pediu.
func _draw_pass(pass_station: PassStation, rect: Rect2) -> void:
	draw_texture(Art.COUNTER, rect.position)
	var top := Rect2(rect.position + Vector2(2, 2), Vector2(20, 13))
	draw_rect(top.grow(1), Color("4a3a40"))
	draw_rect(top, Color("b8bec8"))
	draw_rect(Rect2(top.position, Vector2(top.size.x, 2)), Color("e4e8ee"))
	draw_rect(Rect2(top.position + Vector2(0, top.size.y - 2), Vector2(top.size.x, 2)), Color("8a909c"))
	var c := pass_station.cell
	var middle: bool = c.y > 0 and c.y < LAYOUT.size() - 1 and LAYOUT[c.y - 1][c.x] == "H" and LAYOUT[c.y + 1][c.x] == "H"
	if middle and pass_station.item == null:
		# Campainha dourada.
		var b := rect.position + Vector2(12, 9)
		var ring_age := _time - _bell_time
		if ring_age < 0.6:
			b.x += roundf(sin(ring_age * 50.0) * 1.5 * (1.0 - ring_age / 0.6))
		draw_rect(Rect2(b + Vector2(-4, 2), Vector2(8, 2)), Color("3b2027"))
		draw_circle(b, 3.0, Color("f6c444"))
		draw_rect(Rect2(b + Vector2(-2, -2), Vector2(1, 1)), Color("fff3b0"))
		draw_rect(Rect2(b + Vector2(-1, -4), Vector2(2, 1)), Color("3b2027"))
	if pass_station.has_ready_plate():
		var number := table_wanting(pass_station.item)
		if number > 0:
			var float_y := roundf(sin(_time * 4.0) * 1.0) - item_pop(pass_station.cell) * 6.0
			var badge := Rect2((rect.get_center() + Vector2(-8, -22 + float_y)).round(), Vector2(16, 9))
			draw_rect(badge.grow(1), UiStyle.INK)
			draw_rect(badge, Color("a02530"))
			draw_string(UiStyle.FONT, badge.position + Vector2(0, 8), "M%d" % number, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 9, UiStyle.TEXT)


## Número da mesa que está à espera deste prato (o grupo há mais tempo à espera), ou 0.
func table_wanting(plate: Item) -> int:
	var best: Customer = null
	for customer in orders.customers:
		if customer.is_waiting() and customer.wants(plate) and (best == null or customer.patience < best.patience):
			best = customer
	return best.table.number if best else 0


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
	var spots := [Vector2(-4, -2), Vector2(4, 2), Vector2(-4, 22), Vector2(4, 26), Vector2(5, -6), Vector2(-5, 7), Vector2(5, 17), Vector2(-5, 30)] \
		if big else [Vector2(-4, -2), Vector2(4, 2), Vector2(5, -6), Vector2(-5, 6)]
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
		var wiggle := 0.0
		if sitting:
			var phase := _time + m.seat.x * 0.7 + m.seat.y * 1.3
			if customer.state == Customer.State.EATING:
				# A mastigar: abana a cabeça ao ritmo das garfadas.
				bob = -1.0 if fmod(phase * 3.0, 1.0) < 0.3 else 0.0
			elif customer.state in [Customer.State.CALLING, Customer.State.WAITING]:
				var t := customer.patience / customer.max_patience
				if t < 0.4:
					# Impaciente: bate o pé e mexe-se na cadeira.
					wiggle = roundf(sin(phase * (10.0 if t < 0.2 else 5.0)) * 0.8)
				elif fmod(phase, 4.0) < 0.15:
					bob = -1.0  # olha à volta de vez em quando
		var top_left := m.pos - Vector2(Art.CUSTOMER_FRAME.x / 2.0 - wiggle, Art.CUSTOMER_FRAME.y - 6 - bob)
		# Quem está sentado à esquerda da mesa fica virado para a direita.
		var flip := sitting and m.seat.x < customer.table.cell.x
		draw_actor_shadow(self, m.pos + Vector2(0, 5), m.pos, 5.0)
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
				var plate := Item.for_recipe(missing[k])
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
		"H": return PassStation.new()
		"D":
			var drinks: Array = level.get("drinks", ["water"])
			_bar_count += 1
			return BarStation.new(drinks[(_bar_count - 1) % drinks.size()])
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
