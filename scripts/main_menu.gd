extends Control
## Menu principal. Rato, teclado e comando navegam os botões.


func _ready() -> void:
	UiStyle.background(self)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	box.add_child(UiStyle.label("Order Up!", 40))
	box.add_child(UiStyle.label("v%s · protótipo M0" % ProjectSettings.get_setting("application/config/version"), 12, UiStyle.MUTED))

	var play := _button("Jogar (local)", _start)
	box.add_child(play)
	box.add_child(_button("Sair", func(): get_tree().quit()))
	play.grab_focus()

	var info := UiStyle.label("GPU: %s" % RenderingServer.get_video_adapter_name(), 10, UiStyle.MUTED)
	info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info.position.y -= 18
	add_child(info)


## Na primeira vez que se joga, o jogo começa pelo tutorial.
func _start() -> void:
	GameState.mode = GameState.Mode.PLAY if GameState.tutorial_done else GameState.Mode.TUTORIAL
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 24)
	b.pressed.connect(on_pressed)
	return b
