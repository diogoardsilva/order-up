class_name Chef
extends CharacterBody2D
## Chef provisório. Um chef local lê o seu InputSource e mexe-se aqui; um chef
## de outro PC segue as posições que chegam pela rede. As interações são
## pedidas ao nível, que as executa (anfitrião) ou as envia ao anfitrião.

signal pause_requested
signal confirm_pressed
signal interact_requested

const SIZE := 16.0
const SPEED := 120.0
const ACCEL := 1000.0
const DASH_SPEED := 320.0
const DASH_TIME := 0.15
const DASH_COOLDOWN := 0.6
const EMOTE_TIME := 0.8

var source: InputSource
var kitchen: Kitchen
var color := Color.WHITE
var slot := 0
var held: Item
## false para chefs controlados noutro PC.
var is_local := true
## Quando true (fim da ronda), o chef não se mexe nem interage.
var frozen := false
## "Usar" carregado neste frame (cortar). Vem da rede nos chefs remotos.
var use_down := false
var facing := Vector2.DOWN
var emote_left := 0.0
## Última posição recebida pela rede (chefs remotos).
var net_target := Vector2.ZERO

var _dash_left := 0.0
var _dash_cooldown := 0.0


func _ready() -> void:
	net_target = position
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE) * 0.8
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)


## A célula para onde o chef está virado (direção arredondada a 4 lados).
func target_cell() -> Vector2i:
	var dir := Vector2(signf(facing.x), 0) if absf(facing.x) > absf(facing.y) else Vector2(0, signf(facing.y))
	return kitchen.cell_at(position + dir * Kitchen.TILE * 0.75)


func _physics_process(delta: float) -> void:
	if is_local:
		_local_update(delta)
	else:
		# Segue a posição da rede com suavização; salta se estiver muito longe.
		position = net_target if position.distance_to(net_target) > Kitchen.TILE * 2 \
			else position.lerp(net_target, 0.35)
	emote_left = maxf(emote_left - delta, 0.0)
	queue_redraw()


func _local_update(delta: float) -> void:
	source.poll()
	if source.just_pressed(&"pause"):
		pause_requested.emit()
	if frozen:
		velocity = Vector2.ZERO
		use_down = false
		if source.just_pressed(&"pick"):
			confirm_pressed.emit()
		return

	var input := source.move
	if input != Vector2.ZERO:
		facing = input.normalized()

	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	if source.just_pressed(&"dash") and _dash_cooldown == 0.0:
		_dash_left = DASH_TIME
		_dash_cooldown = DASH_COOLDOWN

	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = facing * DASH_SPEED
	else:
		velocity = velocity.move_toward(input * SPEED, ACCEL * delta)
	move_and_slide()

	use_down = source.is_down(&"use")
	if source.just_pressed(&"pick"):
		interact_requested.emit()
	if source.just_pressed(&"emote"):
		emote_left = EMOTE_TIME


func _draw() -> void:
	var half := SIZE / 2.0
	draw_rect(Rect2(-half, -half + 3, SIZE, SIZE), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-half, -half, SIZE, SIZE), color)
	# Chapéu de chef.
	draw_rect(Rect2(-half + 2, -half - 5, SIZE - 4, 6), Color("f4f0e8"))
	draw_rect(Rect2(facing.round() * 4 - Vector2(2, 1), Vector2(4, 3)), UiStyle.BG)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-half, -half - 7), "P%d" % (slot + 1), HORIZONTAL_ALIGNMENT_CENTER, SIZE, 8, UiStyle.TEXT)
	if held:
		ItemArt.draw_item(self, held, facing.round() * 10)
	if emote_left > 0.0:
		draw_string(font, Vector2(-half, -half - 16), "!", HORIZONTAL_ALIGNMENT_CENTER, SIZE, 12, Color("f2c94c"))
	if is_local and not source.is_available():
		draw_string(font, Vector2(-30, half + 10), "comando desligado", HORIZONTAL_ALIGNMENT_CENTER, 60, 8, Color("e8574d"))
