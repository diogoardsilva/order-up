class_name Chef
extends CharacterBody2D
## Chef provisório. Lê o seu InputSource e pede ações à Kitchen sobre a
## célula que tem à frente.

signal pause_requested
signal confirm_pressed

const SIZE := 16.0
const SPEED := 120.0
const ACCEL := 1000.0
const DASH_SPEED := 320.0
const DASH_TIME := 0.15
const DASH_COOLDOWN := 0.6

var source: InputSource
var kitchen: Kitchen
var color := Color.WHITE
var slot := 0
var held: Item
## Quando true (fim da ronda), o chef não se mexe nem interage.
var frozen := false

var _facing := Vector2.DOWN
var _dash_left := 0.0
var _dash_cooldown := 0.0
var _emote := 0.0


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE) * 0.8
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)


## A célula para onde o chef está virado (direção arredondada a 4 lados).
func target_cell() -> Vector2i:
	var dir := Vector2(signf(_facing.x), 0) if absf(_facing.x) > absf(_facing.y) else Vector2(0, signf(_facing.y))
	return kitchen.cell_at(position + dir * Kitchen.TILE * 0.75)


func _physics_process(delta: float) -> void:
	source.poll()
	if source.just_pressed(&"pause"):
		pause_requested.emit()
	if frozen:
		velocity = Vector2.ZERO
		if source.just_pressed(&"pick"):
			confirm_pressed.emit()
		queue_redraw()
		return

	var input := source.move
	if input != Vector2.ZERO:
		_facing = input.normalized()

	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	if source.just_pressed(&"dash") and _dash_cooldown == 0.0:
		_dash_left = DASH_TIME
		_dash_cooldown = DASH_COOLDOWN

	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _facing * DASH_SPEED
	else:
		velocity = velocity.move_toward(input * SPEED, ACCEL * delta)
	move_and_slide()

	if source.just_pressed(&"pick"):
		kitchen.interact(self, target_cell())
	if source.is_down(&"use") and held == null:
		kitchen.use(target_cell(), delta)
	if source.just_pressed(&"emote"):
		_emote = 0.8
	_emote = maxf(_emote - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	# Linha da folha: 0 = de frente, 1 = de costas, 2 = de lado (espelhado para a esquerda).
	var side := absf(_facing.x) > absf(_facing.y)
	var row := 2 if side else (1 if _facing.y < 0.0 else 0)
	var flip := side and _facing.x < 0.0
	var col := 0
	if velocity.length() > 10.0:
		col = 1 + int(Time.get_ticks_msec() / 120.0) % 2
	var top_left := Vector2(-Art.CHEF_FRAME.x / 2.0, -Art.CHEF_FRAME.y + 8)
	var hand := _facing.round() * 9 + Vector2(0, 2)

	draw_circle(Vector2(0, 7), 6.0, Color(0, 0, 0, 0.25))
	# De costas, o que leva na mão fica escondido atrás do corpo.
	if held and row == 1:
		ItemArt.draw_item(self, held, hand)
	Art.frame(self, Art.CHEF, Art.CHEF_FRAME, col, row, top_left, flip)
	Art.frame(self, Art.CHEF_TINT, Art.CHEF_FRAME, col, row, top_left, flip, color)
	if held and row != 1:
		ItemArt.draw_item(self, held, hand)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-10, top_left.y - 2), "P%d" % (slot + 1), HORIZONTAL_ALIGNMENT_CENTER, 20, 8, color)
	if _emote > 0.0:
		draw_string(font, Vector2(-10, top_left.y - 10), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 12, Color("f2c94c"))
	if not source.is_available():
		draw_string(font, Vector2(-30, 18), "comando desligado", HORIZONTAL_ALIGNMENT_CENTER, 60, 8, Color("e8574d"))
