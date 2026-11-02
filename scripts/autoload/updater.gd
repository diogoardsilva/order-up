extends Node
## Atualizações automáticas. O GitHub Actions publica cada versão nova no
## release "latest" do repositório (público): um version.json e o pacote do
## jogo (.pck) de cada sistema. O jogo vê se há uma build mais nova, descarrega
## o pacote em segundo plano para user://updates/ e, da próxima vez que abrir
## (ou ao carregar em "Reiniciar e atualizar"), carrega-o por cima do jogo
## antes de tudo o resto: este autoload é o primeiro da lista, e o pacote traz
## também as definições novas (update_settings.cfg, uma cópia do project.godot
## feita pelo CI). O executável não muda, por isso funciona igual no Windows,
## no Linux e no Mac. Se um pacote novo não arrancar bem, volta-se ao anterior.

signal changed

const BASE := "https://github.com/diogoardsilva/order-up/releases/download/latest/"
const DIR := "user://updates/"
const INFO := DIR + "game.json"
const TRY := DIR + "trying.json"
const CHECK_EVERY := 30.0 * 60.0

## "", "checking", "downloading", "ready", "latest", "error"
var state := ""
var progress := 0.0
var new_version := ""
var _http: HTTPRequest
var _timer := 0.0


## Build deste jogo (o CI escreve-a no project.godot; 0 = feito à mão).
func build() -> int:
	return int(ProjectSettings.get_setting("application/config/build", 0))


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "?"))


func platform() -> String:
	match OS.get_name():
		"Windows": return "windows"
		"macOS": return "macos"
		"Linux", "FreeBSD": return "linux"
	return ""


var _embedded_build := 0
var _from_update := false


## Corre antes de os outros autoloads serem criados: é aqui que se carrega a atualização.
func _init() -> void:
	_embedded_build = build()
	if OS.is_debug_build() or platform() == "":
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var info := _read(INFO)
	_clean_old(str(info.get("file", "")))
	var pack := DIR + str(info.get("file", ""))
	if info.is_empty() or int(info.get("build", 0)) <= _embedded_build or not FileAccess.file_exists(pack):
		return
	# Se esta build já arrancou mal uma vez, apaga-se e fica a do executável.
	var trying := _read(TRY)
	if int(trying.get("build", -1)) == int(info.get("build", 0)) and not trying.get("ok", false):
		DirAccess.remove_absolute(pack)
		DirAccess.remove_absolute(INFO)
		DirAccess.remove_absolute(TRY)
		return
	_write(TRY, {"build": info["build"], "ok": false})
	if not ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(pack), true):
		return
	_from_update = true
	_apply_settings()


## Passa as definições do pacote novo (versão, build, autoloads, comandos).
func _apply_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://update_settings.cfg") != OK:
		return
	for section in ["application", "autoload", "input"]:
		if not cfg.has_section(section):
			continue
		for key in cfg.get_section_keys(section):
			var name: String = section + "/" + key
			if section == "application" and not key.begins_with("config/"):
				continue
			ProjectSettings.set_setting(name, cfg.get_value(section, key))
	if cfg.has_section("input"):
		InputMap.load_from_project_settings()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.is_debug_build() or platform() == "":
		return
	print("Order Up! %s build %d%s" % [version(), build(), " (atualização)" if _from_update else ""])
	if _from_update:
		_add_new_autoloads.call_deferred()
		get_tree().create_timer(6.0).timeout.connect(_confirm_boot)
	_timer = CHECK_EVERY - 4.0


## Autoloads que só existem na versão nova (o motor só criou os antigos).
func _add_new_autoloads() -> void:
	for prop in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		if not key.begins_with("autoload/"):
			continue
		var name := key.trim_prefix("autoload/")
		if get_tree().root.has_node(NodePath(name)):
			continue
		var path := str(ProjectSettings.get_setting(key)).trim_prefix("*")
		var res = load(path)
		var node: Node = null
		if res is PackedScene:
			node = (res as PackedScene).instantiate()
		elif res is Script:
			node = Node.new()
			node.set_script(res)
		if node:
			node.name = name
			get_tree().root.add_child(node)


func _process(delta: float) -> void:
	if state == "downloading" and _http:
		var total := _http.get_body_size()
		if total > 0:
			progress = float(_http.get_downloaded_bytes()) / float(total)
			changed.emit()
	if OS.is_debug_build() or platform() == "" or state in ["checking", "downloading", "ready"]:
		return
	_timer += delta
	if _timer >= CHECK_EVERY:
		_timer = 0.0
		check()


func _downloaded_build() -> int:
	var info := _read(INFO)
	return int(info.get("build", 0)) if FileAccess.file_exists(DIR + str(info.get("file", "-"))) else 0


## Apaga pacotes antigos (os que já não são o atual).
func _clean_old(keep: String) -> void:
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".pck") or f.ends_with(".part"):
			if f != keep:
				DirAccess.remove_absolute(DIR + f)


## O pacote novo arrancou bem.
func _confirm_boot() -> void:
	var trying := _read(TRY)
	trying["ok"] = true
	_write(TRY, trying)


## Vê se há versão nova e, se houver, descarrega-a.
func check() -> void:
	if state in ["checking", "downloading"]:
		return
	state = "checking"
	changed.emit()
	var data = await _fetch(_base() + "version.json", "")
	if not data is PackedByteArray:
		state = "error"
		changed.emit()
		return
	var info = JSON.parse_string((data as PackedByteArray).get_string_from_utf8())
	var engine := "%d.%d" % [Engine.get_version_info()["major"], Engine.get_version_info()["minor"]]
	if not info is Dictionary or str(info.get("godot", "")) != engine:
		state = "error"
		changed.emit()
		return
	var remote := int(info.get("build", 0))
	var have := maxi(build(), _downloaded_build())
	if remote <= have:
		state = "ready" if have > build() else "latest"
		new_version = str(_read(INFO).get("version", "")) if have > build() else ""
		changed.emit()
		return
	var file: String = info.get("files", {}).get(platform(), "")
	var sha: String = info.get("sha256", {}).get(platform(), "")
	if file == "":
		state = "latest"
		changed.emit()
		return
	state = "downloading"
	progress = 0.0
	new_version = str(info.get("version", ""))
	changed.emit()
	# Cada build num ficheiro próprio: o que está a ser usado não se pode
	# substituir no Windows enquanto o jogo está aberto.
	var name := "game_%d.pck" % remote
	var tmp := DIR + name + ".part"
	var ok = await _fetch(_base() + file, tmp)
	if ok != true or (sha != "" and FileAccess.get_sha256(tmp) != sha):
		DirAccess.remove_absolute(tmp)
		state = "error"
		changed.emit()
		return
	DirAccess.remove_absolute(DIR + name)
	DirAccess.rename_absolute(tmp, DIR + name)
	_write(INFO, {"build": remote, "version": new_version, "file": name})
	DirAccess.remove_absolute(TRY)
	state = "ready"
	changed.emit()


## Fecha e volta a abrir o jogo, que ao arrancar carrega a atualização.
func restart_now() -> void:
	if state != "ready":
		return
	Profiles.save()
	if OS.create_process(OS.get_executable_path(), OS.get_cmdline_args()) > 0:
		get_tree().quit()


## Texto curto para o menu principal ("" quando não há nada a dizer).
func status_text() -> String:
	match state:
		"downloading":
			return "A descarregar a versão %s... %d%%" % [new_version, int(progress * 100.0)]
		"ready":
			return "A versão %s está pronta." % new_version
	return ""


## ORDERUP_UPDATE_URL serve para testar com um servidor local.
func _base() -> String:
	var env := OS.get_environment("ORDERUP_UPDATE_URL")
	return env if env != "" else BASE


func _fetch(url: String, to_file: String) -> Variant:
	_http = HTTPRequest.new()
	_http.timeout = 600.0 if to_file != "" else 15.0
	_http.max_redirects = 10
	if to_file != "":
		_http.download_file = to_file
	add_child(_http)
	if _http.request(url) != OK:
		_http.queue_free()
		_http = null
		return null
	var res: Array = await _http.request_completed
	_http.queue_free()
	_http = null
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return null
	return true if to_file != "" else res[3]


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
