extends Node2D
## Sala de teste do M0: os chefs andam numa cozinha vazia com paredes e uma
## ilha ao centro. Serve para testar comandos e FPS no PC mais fraco.

const VIEW := Vector2(640, 360)
const WALL := 16.0
const ISLAND := Rect2(256, 152, 128, 56)
const SPAWNS: Array[Vector2] = [Vector2(160, 120), Vector2(480, 120), Vector2(160, 250), Vector2(480, 250)]

var _hud: Label


func _ready() -> void:
	for rect in [
		Rect2(0, 0, VIEW.x, WALL), Rect2(0, VIEW.y - WALL, VIEW.x, WALL),
		Rect2(0, 0, WALL, VIEW.y), Rect2(VIEW.x - WALL, 0, WALL, VIEW.y), ISLAND,
	]:
		_add_wall(rect)

	for p in PlayerRegistry.players:
		var chef := Chef.new()
		chef.source = p["source"]
		chef.color = p["color"]
		chef.slot = p["slot"]
		chef.position = SPAWNS[p["slot"]]
		chef.pause_requested.connect(_back_to_lobby)
		add_child(chef)

	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(WALL + 4, 2)
	_hud.add_theme_font_size_override("font_size", 10)
	layer.add_child(_hud)


func _process(_delta: float) -> void:
	_hud.text = "FPS %d  ·  GPU %s  ·  Pausa para voltar ao lobby" % [
		Engine.get_frames_per_second(), RenderingServer.get_video_adapter_name()]


func _draw() -> void:
	var tile := 16
	for x in range(0, int(VIEW.x), tile):
		for y in range(0, int(VIEW.y), tile):
			var even := (x / tile + y / tile) % 2 == 0
			draw_rect(Rect2(x, y, tile, tile), Color("d9cfc1") if even else Color("cbbfae"))
	draw_rect(Rect2(0, 0, VIEW.x, WALL), Color("5a4a63"))
	draw_rect(Rect2(0, VIEW.y - WALL, VIEW.x, WALL), Color("5a4a63"))
	draw_rect(Rect2(0, 0, WALL, VIEW.y), Color("5a4a63"))
	draw_rect(Rect2(VIEW.x - WALL, 0, WALL, VIEW.y), Color("5a4a63"))
	draw_rect(ISLAND, Color("8c6a4f"))
	draw_rect(ISLAND.grow(-3), Color("a5815f"))


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _back_to_lobby() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
