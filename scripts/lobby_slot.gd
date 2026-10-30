class_name LobbySlot
extends Control
## Cartão de um jogador no lobby: o chef escolhido em grande, a andar no sítio,
## com setas para trocar. Vazio, mostra uma silhueta à espera.

const CHEF_SCALE := 6.0

var index := 0
var _player := {}
var _time := 0.0
var _bump := 0.0
var _bump_dir := 0
var _join_pop := 0.0


func set_player(player: Dictionary) -> void:
	if player and not _player:
		_join_pop = 1.0
	elif player and _player and player.get("character") != _player.get("character"):
		_bump = 1.0
	_player = player
	queue_redraw()


func bump(dir: int) -> void:
	_bump_dir = dir
	_bump = 1.0


func _process(delta: float) -> void:
	_time += delta
	_bump = move_toward(_bump, 0.0, delta * 4.0)
	_join_pop = move_toward(_join_pop, 0.0, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var font := UiStyle.FONT
	var joined := not _player.is_empty()
	var color: Color = _player.get("color", UiStyle.MUTED)
	var pop := 1.0 + sin(_join_pop * PI) * 0.08
	draw_set_transform(size / 2.0, 0.0, Vector2(pop, pop))
	var rect := Rect2(-size / 2.0, size)
	draw_style_box(UiStyle.panel_box(), rect)
	# Fita com o número do jogador.
	var ribbon := Rect2(rect.position + Vector2(18, 16), Vector2(rect.size.x - 36, 40))
	draw_rect(ribbon, color if joined else Color("9c7b52"))
	draw_rect(Rect2(ribbon.position + Vector2(0, ribbon.size.y - 4), Vector2(ribbon.size.x, 4)), Color(0, 0, 0, 0.2))
	draw_string(font, ribbon.position + Vector2(0, 30), "Jogador %d" % (index + 1), HORIZONTAL_ALIGNMENT_CENTER, ribbon.size.x, 26, UiStyle.TEXT)

	var character: int = _player.get("character", index)
	var frame_px := Vector2(Art.CHEF_FRAME) * CHEF_SCALE
	var center := Vector2(0, -4)
	# Sombra e chef a andar no sítio, com um pulo ao trocar.
	draw_set_transform(size / 2.0 + center + Vector2(0, frame_px.y / 2.0 - 30), 0.0, Vector2(pop, pop))
	draw_circle(Vector2.ZERO, 34.0, Color(0, 0, 0, 0.18))
	var hop := -sin(_bump * PI) * 18.0
	var squash := sin(_bump * PI) * 0.12
	var col := 1 + int(_time / 0.18) % 2 if joined else 0
	var row := 0 if joined else 0
	var origin := size / 2.0 + center + Vector2(_bump_dir * _bump * 10.0, hop)
	draw_set_transform(origin + Vector2(0, frame_px.y / 2.0 - 30), 0.0, Vector2(CHEF_SCALE * (1.0 + squash), CHEF_SCALE * (1.0 - squash)) * pop)
	var tl := Vector2(-Art.CHEF_FRAME.x / 2.0, -Art.CHEF_FRAME.y + 5)
	var modulate := Color.WHITE if joined else Color(0.25, 0.15, 0.12, 0.55)
	Art.frame(self, Art.CHEFS[character], Art.CHEF_FRAME, col, row, tl, false, modulate)
	Art.frame(self, Art.CHEF_TINT, Art.CHEF_FRAME, col, row, tl, false, color * modulate if joined else modulate)
	draw_set_transform(size / 2.0, 0.0, Vector2(pop, pop))

	if joined:
		draw_string(font, Vector2(rect.position.x, 120), Art.CHEF_NAMES[character], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 34, UiStyle.INK)
		# Setas para trocar de personagem, a mexer-se ligeiramente.
		var wiggle := sin(_time * 4.0) * 3.0
		for dir in [-1, 1]:
			var push := 8.0 if _bump > 0.0 and _bump_dir == dir else 0.0
			var ax: float = dir * (rect.size.x / 2.0 - 34 + wiggle + push)
			draw_set_transform(size / 2.0 + Vector2(ax, -10) * pop, 0.0, Vector2(dir * 1.0, 1.0) * pop)
			draw_texture(Art.ARROW, -Art.ARROW.get_size() / 2.0)
		draw_set_transform(size / 2.0, 0.0, Vector2(pop, pop))
		var source: InputSource = _player["source"]
		var device := source.get_label() + ("" if source.is_available() else " (desligado)")
		draw_string(font, Vector2(rect.position.x, 168), device, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, UiStyle.INK_SOFT)
	else:
		var a := 0.5 + 0.5 * sin(_time * 3.0 + index)
		draw_string(font, Vector2(rect.position.x, 130), "Carrega em pegar", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 24, Color(UiStyle.INK, 0.4 + 0.6 * a))
		draw_string(font, Vector2(rect.position.x, 160), "para entrar", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 24, Color(UiStyle.INK, 0.4 + 0.6 * a))
	draw_set_transform(Vector2.ZERO)
