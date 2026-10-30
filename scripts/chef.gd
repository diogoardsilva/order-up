class_name Chef
extends CharacterBody2D
## Chef provisório (quadrado colorido). Cada botão tem um efeito visível para
## testarmos teclado e DS4 antes de existir cozinha a sério.

signal pause_requested

const SIZE := 14.0
const SPEED := 110.0
const ACCEL := 900.0
const DASH_SPEED := 300.0
const DASH_TIME := 0.15
const DASH_COOLDOWN := 0.6

var source: InputSource
var color := Color.WHITE
var slot := 0

var _facing := Vector2.DOWN
var _dash_left := 0.0
var _dash_cooldown := 0.0
var _flash := 0.0
var _emote := 0.0


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE)
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)


func _physics_process(delta: float) -> void:
	source.poll()
	if source.just_pressed(&"pause"):
		pause_requested.emit()

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
		_flash = 0.15
	if source.just_pressed(&"emote"):
		_emote = 0.8
	_flash = maxf(_flash - delta, 0.0)
	_emote = maxf(_emote - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var half := SIZE / 2.0
	draw_rect(Rect2(-half, -half + 2, SIZE, SIZE), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-half, -half, SIZE, SIZE), Color.WHITE if _flash > 0.0 else color)
	draw_rect(Rect2(_facing.round() * 5 - Vector2(2, 2), Vector2(4, 4)), UiStyle.BG)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-half, -half - 3), "P%d" % (slot + 1), HORIZONTAL_ALIGNMENT_CENTER, SIZE, 8, UiStyle.TEXT)
	if _emote > 0.0:
		draw_string(font, Vector2(-half, -half - 12), "!", HORIZONTAL_ALIGNMENT_CENTER, SIZE, 12, Color("f2c94c"))
	if source.is_down(&"use"):
		draw_string(font, Vector2(-half, half + 10), "...", HORIZONTAL_ALIGNMENT_CENTER, SIZE, 10, UiStyle.TEXT)
	if not source.is_available():
		draw_string(font, Vector2(-30, half + 10), "comando desligado", HORIZONTAL_ALIGNMENT_CENTER, 60, 8, Color("e8574d"))
