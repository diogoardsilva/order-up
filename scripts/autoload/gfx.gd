extends Node
## Definições de gráficos. Cada opção tem vários níveis e há quatro predefinições
## (Baixo, Médio, Alto, Ultra). Tudo corre no renderizador Compatibility, por
## isso o Baixo continua leve para PCs fracos e o Ultra puxa pela placa gráfica
## com sombras dinâmicas, luz de fim de tarde, chão polido e pós-processamento.
## Guarda-se em user://save.cfg, na secção "graphics".

signal changed

const SAVE_PATH := "user://save.cfg"

## Opções: id -> [nome, nomes dos níveis]. A ordem é a do menu.
const OPTIONS := {
	"shadows": ["Sombras", ["Desligadas", "Simples", "Suaves", "Ultra"]],
	"lighting": ["Iluminação", ["Desligada", "Simples", "Ambiente", "Ultra"]],
	"textures": ["Texturas", ["Baixa", "Média", "Alta", "Ultra"]],
	"post": ["Pós-processamento", ["Desligado", "Cor e vinheta", "Ultra (bloom)"]],
	"particles": ["Partículas", ["Poucas", "Normais", "Muitas"]],
	"heat": ["Calor dos fogões", ["Desligado", "Ligado"]],
}
const PRESET_NAMES: Array[String] = ["Baixo", "Médio", "Alto", "Ultra"]
const PRESETS: Array[Dictionary] = [
	{"shadows": 0, "lighting": 0, "textures": 0, "post": 0, "particles": 0, "heat": 0},
	{"shadows": 1, "lighting": 1, "textures": 1, "post": 0, "particles": 1, "heat": 0},
	{"shadows": 2, "lighting": 2, "textures": 2, "post": 1, "particles": 1, "heat": 0},
	{"shadows": 3, "lighting": 3, "textures": 3, "post": 2, "particles": 2, "heat": 1},
]
const FPS_LIMITS: Array[int] = [0, 30, 60, 120, 144]

var shadows := 1
var lighting := 1
var textures := 1
var post := 0
var particles := 1
var heat := 0
var vsync := true
## Índice em FPS_LIMITS (0 = sem limite).
var fps_limit := 0
var show_fps := true


func _ready() -> void:
	var cfg := ConfigFile.new()
	var has_save := cfg.load(SAVE_PATH) == OK and cfg.has_section("graphics")
	if has_save:
		for id in OPTIONS:
			set(id, clampi(cfg.get_value("graphics", id, get(id)), 0, OPTIONS[id][1].size() - 1))
		vsync = cfg.get_value("graphics", "vsync", true)
		fps_limit = clampi(cfg.get_value("graphics", "fps_limit", 0), 0, FPS_LIMITS.size() - 1)
		show_fps = cfg.get_value("graphics", "show_fps", true)
	else:
		# Primeira vez: Médio em gráficas integradas ou desconhecidas, Alto nas outras.
		_load_preset(suggested_preset())
	_apply_display()


## Predefinição que se sugere para esta placa gráfica.
func suggested_preset() -> int:
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	for weak in ["intel", "llvmpipe", "microsoft basic", "swiftshader", "mali", "adreno", "vega 3", "vega 8", "radeon(tm) graphics"]:
		if gpu.contains(weak):
			return 1
	if gpu.is_empty():
		return 1
	return 2


func level_name(id: String) -> String:
	return OPTIONS[id][1][get(id)]


## Muda uma opção para o nível seguinte (dir = +1) ou anterior (-1).
func cycle(id: String, dir: int) -> void:
	set(id, posmod(get(id) + dir, OPTIONS[id][1].size()))
	_save()


## A predefinição que corresponde às opções atuais, ou -1 (personalizado).
func current_preset() -> int:
	for i in PRESETS.size():
		var ok := true
		for id in PRESETS[i]:
			if get(id) != PRESETS[i][id]:
				ok = false
		if ok:
			return i
	return -1


func preset_name() -> String:
	var p := current_preset()
	return PRESET_NAMES[p] if p >= 0 else "Personalizado"


func apply_preset(index: int) -> void:
	_load_preset(clampi(index, 0, PRESETS.size() - 1))
	_save()


func cycle_preset(dir: int) -> void:
	var p := current_preset()
	if p < 0:
		p = 1 if dir > 0 else 2
	apply_preset(posmod(p + dir, PRESETS.size()))


func set_vsync(on: bool) -> void:
	vsync = on
	_apply_display()
	_save()


func cycle_fps_limit(dir: int) -> void:
	fps_limit = posmod(fps_limit + dir, FPS_LIMITS.size())
	_apply_display()
	_save()


func set_show_fps(on: bool) -> void:
	show_fps = on
	_save()


func fps_limit_name() -> String:
	return "Sem limite" if FPS_LIMITS[fps_limit] == 0 else "%d" % FPS_LIMITS[fps_limit]


## Multiplicador de quantas partículas aparecem.
func particle_rate() -> float:
	return [0.35, 1.0, 2.0][particles]


func _load_preset(index: int) -> void:
	for id in PRESETS[index]:
		set(id, PRESETS[index][id])


func _apply_display() -> void:
	Engine.max_fps = FPS_LIMITS[fps_limit]
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	for id in OPTIONS:
		cfg.set_value("graphics", id, get(id))
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("graphics", "fps_limit", fps_limit)
	cfg.set_value("graphics", "show_fps", show_fps)
	cfg.save(SAVE_PATH)
	changed.emit()
