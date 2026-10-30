class_name KeyboardSource
extends InputSource
## Esquema de teclado. Há dois para dois jogadores partilharem o mesmo teclado.
## Usa teclas físicas, por isso funciona igual em teclados PT e US.

const LAYOUTS := [
	{
		"label": "Teclado (WASD)",
		"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D,
		"pick": KEY_SPACE, "use": KEY_E, "dash": KEY_SHIFT, "emote": KEY_Q, "pause": KEY_ESCAPE,
	},
	{
		"label": "Teclado (setas)",
		"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
		"pick": KEY_ENTER, "use": KEY_PERIOD, "dash": KEY_SLASH, "emote": KEY_COMMA, "pause": KEY_BACKSPACE,
	},
]

const KEY_NAMES_PT := {"Space": "Espaço", "Escape": "Esc", "Up": "Cima", "Down": "Baixo", "Left": "Esquerda", "Right": "Direita"}

var layout: int


func _init(p_layout: int) -> void:
	layout = p_layout


func get_id() -> String:
	return "kb:%d" % layout


func get_label() -> String:
	return LAYOUTS[layout]["label"]


func prompt(action: StringName) -> String:
	var name := OS.get_keycode_string(LAYOUTS[layout][String(action)])
	return KEY_NAMES_PT.get(name, name)


func _key(name: String) -> bool:
	return Input.is_physical_key_pressed(LAYOUTS[layout][name])


func _read_move() -> Vector2:
	var v := Vector2(
		float(_key("right")) - float(_key("left")),
		float(_key("down")) - float(_key("up")))
	return v.normalized()


func _read_action(action: StringName) -> bool:
	return _key(String(action))
