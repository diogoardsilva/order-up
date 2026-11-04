class_name WelcomeFlow
extends Control
## Primeira vez que se abre o jogo: um cartão de boas-vindas que convida a
## criar conta ou a entrar (para o progresso ficar online) e depois o editor
## do boneco. Dá para saltar tudo com "Agora não" ou com a bola.

signal finished

var _card: Control
var _buttons: VBoxContainer
var _first: Button
var _friends: FriendsMenu
var _character: CharacterMenu
var _time := 0.0
var _closing := false


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.05, 0.9)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_card = Control.new()
	_card.position = Vector2(290, 90)
	_card.size = Vector2(700, 540)
	_card.pivot_offset = _card.size / 2.0
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.draw.connect(_draw_card)
	add_child(_card)

	_buttons = VBoxContainer.new()
	_buttons.position = Vector2(440, 450)
	_buttons.add_theme_constant_override("separation", 10)
	add_child(_buttons)
	if Online.enabled():
		_first = UiStyle.button("Criar conta ou entrar", _open_account, 400)
		_buttons.add_child(_first)
		_buttons.add_child(UiStyle.button("Agora não", _open_character, 400))
	else:
		_first = UiStyle.button("Criar o meu boneco", _open_character, 400)
		_buttons.add_child(_first)

	_friends = FriendsMenu.new()
	_friends.welcome = true
	_friends.hide()
	_friends.closed.connect(func():
		_friends.hide()
		_open_character())
	add_child(_friends)
	_character = CharacterMenu.new()
	_character.hide()
	_character.closed.connect(_finish)
	add_child(_character)

	_card.scale = Vector2(0.85, 0.85)
	_card.modulate.a = 0.0
	_buttons.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "modulate:a", 1.0, 0.25)
	t.tween_property(_buttons, "modulate:a", 1.0, 0.3).set_delay(0.25)
	Sfx.play("ui_confirm")
	# Já com conta (entrou noutra vez): vai direto ao boneco.
	if Online.logged_in():
		_open_character.call_deferred()
	else:
		_first.grab_focus.call_deferred()


func _open_account() -> void:
	Sfx.play("ui_confirm")
	_card.hide()
	_buttons.hide()
	_friends.show()
	_friends.focus_first()


func _open_character() -> void:
	Sfx.play("ui_confirm")
	_card.hide()
	_buttons.hide()
	_character.welcome = true
	_character.show()
	_character.focus_first()


func _finish() -> void:
	if _closing:
		return
	_closing = true
	GameState.mark_welcome_done()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(func():
		finished.emit()
		queue_free())


func _process(delta: float) -> void:
	_time += delta
	if _card.visible:
		_card.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _card.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.play("ui_back")
		_open_character()


func _draw_card() -> void:
	var ci := _card
	var w := _card.size.x
	ci.draw_style_box(UiStyle.paper_box(), Rect2(Vector2.ZERO, _card.size))
	UiStyle.shadow_text(ci, Vector2(0, 86), "Bem-vindo à cozinha!", 60, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER, w)
	# Três chefs a acenar, com o boneco do perfil ao meio.
	for i in 3:
		var look: Dictionary = Profiles.look(Profiles.active) if i == 1 else CharacterLook.preset(i + 3)
		var s := 4.0
		var bob := absf(sin(_time * 4.0 + i * 1.2)) * -6.0
		var at := Vector2(w / 2.0 + (i - 1) * 110.0 - 8 * s, 110 + bob)
		ci.draw_set_transform(at, 0.0, Vector2(s, s))
		CharacterLook.draw(ci, look, [3, 0, 1][i], 1 + int(_time / 0.25 + i) % 2, 0, Vector2.ZERO)
		ci.draw_set_transform(Vector2.ZERO)
	var lines: Array = [
		"Cria uma conta (ou entra na tua) para guardar as estrelas,",
		"as conquistas e o teu boneco online, em qualquer PC.",
		"Depois escolhe o aspeto do teu cozinheiro.",
	] if Online.enabled() else [
		"Antes de começar, escolhe o aspeto do teu cozinheiro.",
	]
	for i in lines.size():
		ci.draw_string(UiStyle.FONT, Vector2(0, 268 + i * 32), lines[i], HORIZONTAL_ALIGNMENT_CENTER, w, 26, UiStyle.INK)
