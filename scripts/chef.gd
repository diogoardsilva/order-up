class_name Chef
extends CharacterBody2D
## Chef provisório. Um chef local lê o seu InputSource e mexe-se aqui; um chef
## de outro PC segue as posições que chegam pela rede. As interações são
## pedidas ao nível, que as executa (anfitrião) ou as envia ao anfitrião.

signal pause_requested
signal confirm_pressed
signal interact_requested
signal throw_requested

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
## Índice do personagem escolhido no lobby (Art.CHEFS).
var character := 0

var _dash_left := 0.0
var _dash_cooldown := 0.0
# Animação: velocidade vista no ecrã (também nos chefs remotos), "esmagar" ao
# pegar/largar, mão a seguir a direção com suavidade e o que tinha na mão.
var _last_pos := Vector2.ZERO
var _screen_speed := 0.0
var _squash := 0.0
var _hand := Vector2(0, 11)
var _held_key := ""
var _walk_time := 0.0


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
	_animate(delta)
	queue_redraw()


func _animate(delta: float) -> void:
	_screen_speed = lerpf(_screen_speed, position.distance_to(_last_pos) / maxf(delta, 0.001), 0.3)
	_last_pos = position
	if _screen_speed > 10.0:
		_walk_time += delta
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	_hand = _hand.lerp(facing.round() * 9 + Vector2(0, 2), minf(delta * 18.0, 1.0))
	# Som e "esmagar" quando o que tem na mão muda (funciona igual online).
	var key := "" if held == null else "%s%s%s%s%d" % [held.kind, held.chopped, held.contents, held.dirty, held.stack]
	if key != _held_key:
		if _held_key == "":
			Sfx.play("pickup")
		elif key == "":
			Sfx.play("drop")
		else:
			Sfx.play("plate")
		_squash = 1.0
		_held_key = key


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
		Sfx.play("dash")
		for i in 6:
			kitchen.particles.dust(position + Vector2(randf_range(-5, 5), 6), -facing)

	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = facing * DASH_SPEED
	else:
		velocity = velocity.move_toward(input * SPEED, ACCEL * delta)
	move_and_slide()

	use_down = source.is_down(&"use")
	if source.just_pressed(&"pick"):
		interact_requested.emit()
	if source.just_pressed(&"throw") and held != null and held.is_ingredient():
		throw_requested.emit()
	if source.just_pressed(&"emote"):
		emote_left = EMOTE_TIME


func _draw() -> void:
	# Linha da folha: 0 = de frente, 1 = de costas, 2 = de lado (espelhado para a esquerda).
	var side := absf(facing.x) > absf(facing.y)
	var row := 2 if side else (1 if facing.y < 0.0 else 0)
	var flip := side and facing.x < 0.0
	var moving := _screen_speed > 10.0
	var col := 1 + int(_walk_time / 0.12) % 2 if moving else 0
	var bob := -1.0 if moving and col == 1 else 0.0
	# Respira quando está parado.
	var breathe := 0.0 if moving else sin(Time.get_ticks_msec() / 400.0 + slot) * 0.03
	var top_left := Vector2(-Art.CHEF_FRAME.x / 2.0, -Art.CHEF_FRAME.y + 8 + bob)

	draw_circle(Vector2(0, 7), 6.0, Color(0, 0, 0, 0.25))
	# Esmaga e estica a partir dos pés.
	var sq := sin(_squash * PI) * 0.18
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0 + sq, 1.0 - sq + breathe))
	var tl := top_left - Vector2(0, 8)
	var hand := _hand + Vector2(0, bob) - Vector2(0, 8)
	# De costas, o que leva na mão fica escondido atrás do corpo.
	if held and row == 1:
		ItemArt.draw_item(self, held, hand)
	Art.frame(self, Art.CHEFS[character], Art.CHEF_FRAME, col, row, tl, flip)
	Art.frame(self, Art.CHEF_TINT, Art.CHEF_FRAME, col, row, tl, flip, color)
	if held and row != 1:
		ItemArt.draw_item(self, held, hand)
	draw_set_transform(Vector2.ZERO)

	var font := UiStyle.FONT
	# Marcador do jogador: um triângulo na cor dele.
	var tip := Vector2(0, top_left.y - 3 + sin(Time.get_ticks_msec() / 250.0) * 1.0).round()
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-3, -4), tip + Vector2(3, -4)]), color)
	if emote_left > 0.0:
		var pop := 1.0 + maxf(0.0, emote_left - EMOTE_TIME + 0.15) * 4.0
		draw_set_transform(Vector2(0, top_left.y - 10), 0.0, Vector2(pop, pop))
		draw_string(font, Vector2(-10, 0), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 14, UiStyle.GOLD)
		draw_set_transform(Vector2.ZERO)
	if is_local and not source.is_available():
		draw_string(font, Vector2(-40, 20), "comando desligado", HORIZONTAL_ALIGNMENT_CENTER, 80, 8, UiStyle.RED)
