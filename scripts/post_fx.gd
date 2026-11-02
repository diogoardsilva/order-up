class_name PostFX
extends CanvasLayer
## Pós-processamento por cima do mundo e por baixo da interface: cor, vinheta
## e, no Ultra, bloom. Fica invisível com "Pós-processamento: Desligado".

const SHADER := preload("res://assets/shaders/post.gdshader")

var _rect: ColorRect


func _init(p_layer := 1) -> void:
	layer = p_layer


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_rect.material = mat
	add_child(_rect)
	Gfx.changed.connect(_apply)
	_apply()


func _apply() -> void:
	visible = Gfx.post > 0
	var mat := _rect.material as ShaderMaterial
	var ultra := Gfx.post >= 2
	mat.set_shader_parameter("bloom", 0.7 if ultra else 0.0)
	mat.set_shader_parameter("aberration", 0.004 if ultra else 0.0)
	mat.set_shader_parameter("saturation", 1.14 if ultra else 1.08)
	mat.set_shader_parameter("contrast", 1.08 if ultra else 1.05)
