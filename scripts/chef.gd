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
	var half := SIZE / 2.0
	draw_rect(Rect2(-half, -half + 3, SIZE, SIZE), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-half, -half, SIZE, SIZE), color)
	# Chapéu de chef.
	draw_rect(Rect2(-half + 2, -half - 5, SIZE - 4, 6), Color("f4f0e8"))
	draw_rect(Rect2(_facing.round() * 4 - Vector2(2, 1), Vector2(4, 3)), UiStyle.BG)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-half, -half - 7), "P%d" % (slot + 1), HORIZONTAL_ALIGNMENT_CENTER, SIZE, 8, UiStyle.TEXT)
	if held:
		ItemArt.draw_item(self, held, _facing.round() * 10)
	if _emote > 0.0:
		draw_string(font, Vector2(-half, -half - 16), "!", HORIZONTAL_ALIGNMENT_CENTER, SIZE, 12, Color("f2c94c"))
	if not source.is_available():
		draw_string(font, Vector2(-30, half + 10), "comando desligado", HORIZONTAL_ALIGNMENT_CENTER, 60, 8, Color("e8574d"))
