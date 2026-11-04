extends Node
## Proporção e resolução do ecrã. O jogo é desenhado para 1280x720 (16:9).
## Em "Encher o ecrã" a janela usa o espaço todo (16:10 do Legion Go, 4:3...):
## o jogo fica ao centro e o resto é fundo do restaurante, sem barras pretas.
## Em "16:9 com barras" fica como antes. Guarda-se em user://save.cfg ("display").

signal changed

const SAVE_PATH := "user://save.cfg"
const BASE := Vector2(1280, 720)
const BG := Color("1a0f12")
const ASPECTS: Array[String] = ["Encher o ecrã", "16:9 com barras"]
## Resoluções da janela (fora do ecrã inteiro). A primeira é automática.
const RESOLUTIONS: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1280, 800), Vector2i(1920, 1200), Vector2i(2560, 1600),
	Vector2i(1024, 768), Vector2i(1600, 1200)]

var aspect := 0
var resolution := 0
## Deslocamento do jogo dentro da janela (para ficar centrado).
var offset := Vector2.ZERO


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		aspect = clampi(cfg.get_value("display", "aspect", 0), 0, ASPECTS.size() - 1)
		resolution = clampi(cfg.get_value("display", "resolution", 0), 0, RESOLUTIONS.size() - 1)
	RenderingServer.set_default_clear_color(BG)
	get_tree().root.size_changed.connect(_relayout)
	get_tree().node_added.connect(_on_node_added)
	get_tree().scene_changed.connect(_relayout)
	_apply_aspect()
	apply_window_size()


func aspect_name() -> String:
	return ASPECTS[aspect]


func resolution_name() -> String:
	var r := RESOLUTIONS[resolution]
	if r == Vector2i.ZERO:
		return "Automática"
	return "%dx%d" % [r.x, r.y]


func cycle_aspect(dir: int) -> void:
	aspect = posmod(aspect + dir, ASPECTS.size())
	_apply_aspect()
	_save()


func cycle_resolution(dir: int) -> void:
	resolution = posmod(resolution + dir, RESOLUTIONS.size())
	apply_window_size()
	_save()


## Tamanho da janela quando não está em ecrã inteiro.
func window_size() -> Vector2i:
	var screen := DisplayServer.screen_get_size()
	var r := RESOLUTIONS[resolution]
	if r == Vector2i.ZERO:
		r = Vector2i(1280, 720)
		if screen.x >= 1920 and screen.y >= 1080:
			r = Vector2i(1600, 900)
		# Num ecrã 16:10 ou 4:3, a janela automática segue a proporção do ecrã.
		if screen.y > 0 and absf(float(screen.x) / screen.y - 16.0 / 9.0) > 0.05:
			r = Vector2i(roundi(r.y * float(screen.x) / screen.y), r.y)
	return Vector2i(mini(r.x, screen.x), mini(r.y, screen.y))


func apply_window_size() -> void:
	if DisplayServer.get_name() == "headless" or GameState.fullscreen:
		return
	var screen := DisplayServer.screen_get_size()
	var size := window_size()
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position((screen - size) / 2)


func _apply_aspect() -> void:
	var root := get_tree().root
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if aspect == 0 else Window.CONTENT_SCALE_ASPECT_KEEP
	_relayout.call_deferred()
	changed.emit()


## Centra o jogo na área visível: o ecrã normal e cada camada (menos as que
## têm de cobrir tudo, como o fade das transições e o pós-processamento).
func _relayout() -> void:
	var visible := get_tree().root.get_visible_rect().size
	offset = ((visible - BASE) / 2.0).floor() if aspect == 0 else Vector2.ZERO
	offset = offset.max(Vector2.ZERO)
	get_tree().root.canvas_transform = Transform2D(0.0, offset)
	_apply_tree(get_tree().root)


func _apply_tree(node: Node) -> void:
	_fit(node)
	for child in node.get_children():
		_apply_tree(child)


func _on_node_added(node: Node) -> void:
	_fit.call_deferred(node)


func _fit(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is CanvasLayer and not node.has_meta("full_screen"):
		(node as CanvasLayer).offset = offset
	# O ecrã atual (menu, lobby...) fica com 1280x720, para não esticar o desenho.
	if node is Control and node.get_parent() == get_tree().root and node == get_tree().current_scene:
		var c := node as Control
		c.set_anchors_preset(Control.PRESET_TOP_LEFT)
		c.position = Vector2.ZERO
		c.size = BASE
	# Os fundos dos menus cobrem a janela toda.
	if node is MenuBackground:
		var bg := node as Control
		bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bg.position = -offset
		bg.size = get_tree().root.get_visible_rect().size


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("display", "aspect", aspect)
	cfg.set_value("display", "resolution", resolution)
	cfg.save(SAVE_PATH)
	changed.emit()
