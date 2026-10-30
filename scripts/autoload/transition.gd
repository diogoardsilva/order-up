extends CanvasLayer
## Mudança de ecrã com fade. Usar Transition.go("res://scenes/x.tscn").

var _rect := ColorRect.new()
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect.color = Color(0.1, 0.05, 0.06, 0.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func go(path: String) -> void:
	if _busy:
		return
	_busy = true
	var t := create_tween()
	t.tween_property(_rect, "color:a", 1.0, 0.22)
	await t.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	t = create_tween()
	t.tween_property(_rect, "color:a", 0.0, 0.3)
	_busy = false


func reload() -> void:
	go(get_tree().current_scene.scene_file_path)
