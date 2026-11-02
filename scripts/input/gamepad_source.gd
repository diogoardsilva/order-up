class_name GamepadSource
extends InputSource
## Um comando ligado (DualShock 4, DualSense, Xbox...). O Godot usa SDL, que
## reconhece o DS4 por USB e Bluetooth sem DS4Windows: Cruz = A, Círculo = B,
## Quadrado = X, Triângulo = Y, L1 = LB, Options = Start.

const DEADZONE := 0.25
const BUTTONS := {
	&"pick": JOY_BUTTON_A,
	&"use": JOY_BUTTON_X,
	&"dash": JOY_BUTTON_B,
	&"throw": JOY_BUTTON_Y,
	&"emote": JOY_BUTTON_LEFT_SHOULDER,
	&"pause": JOY_BUTTON_START,
}
const PS_NAMES := {&"pick": "Cruz", &"use": "Quadrado", &"dash": "Círculo", &"throw": "Triângulo", &"emote": "L1", &"pause": "Options"}
const XBOX_NAMES := {&"pick": "A", &"use": "X", &"dash": "B", &"throw": "Y", &"emote": "LB", &"pause": "Menu"}

var device: int


func _init(p_device: int) -> void:
	device = p_device


func get_id() -> String:
	return "pad:%d" % device


func get_label() -> String:
	return Input.get_joy_name(device)


func is_playstation() -> bool:
	var n := Input.get_joy_name(device).to_lower()
	return n.contains("ps4") or n.contains("ps5") or n.contains("dualshock") \
		or n.contains("dualsense") or n.contains("playstation")


func prompt(action: StringName) -> String:
	return (PS_NAMES if is_playstation() else XBOX_NAMES)[action]


func is_available() -> bool:
	return device in Input.get_connected_joypads()


func _read_move() -> Vector2:
	var dpad := Vector2(
		float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT)),
		float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP)))
	if dpad != Vector2.ZERO:
		return dpad.normalized()
	var v := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
	var strength := minf(v.length(), 1.0)
	if strength < DEADZONE:
		return Vector2.ZERO
	return v.normalized() * inverse_lerp(DEADZONE, 1.0, strength)


func _read_action(action: StringName) -> bool:
	return Input.is_joy_button_pressed(device, BUTTONS[action])
