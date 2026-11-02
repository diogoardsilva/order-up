extends Node
## Perfis com nome, cada um com as suas estatísticas e conquistas. Ficam em
## user://profiles.cfg, neste PC. No lobby cada jogador deste PC escolhe o perfil
## (ou joga como convidado); o que acontece na ronda conta para os perfis dos
## jogadores deste PC. Quando se ganha uma conquista aparece um aviso em cima.

signal changed
signal unlocked(profile_name: String, achievement: Dictionary)
## Guardou-se depois de mudar o progresso (a conta online envia-o).
signal saved

const SAVE_PATH := "user://profiles.cfg"
const GUEST := -1

## Cada perfil: {"name", "stats": {}, "unlocked": {id: unix time}, "look": {} (CharacterLook),
## "online": {"user", "token", "code"} (conta online, ver Online)}
var profiles: Array[Dictionary] = []
## Perfil por defeito do primeiro jogador deste PC.
var active := 0
## Fonte de input local (id) -> índice do perfil escolhido no lobby.
var by_source := {}
## Perfis que estão a jogar a ronda atual (deste PC).
var playing: Array[int] = []
## Estatísticas só desta ronda (para as conquistas "numa só ronda").
var round_stats := {}
var _dirty := false
var _save_time := 0.0
var _toast: Toast


func _ready() -> void:
	_load()
	if profiles.is_empty():
		var name := OS.get_environment("USERNAME")
		if name.is_empty():
			name = OS.get_environment("USER")
		create(name.capitalize() if not name.is_empty() else "Chef", false)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_toast = Toast.new()
	layer.add_child(_toast)
	unlocked.connect(_toast.push)
	Controls.changed.connect(func(): add_all("remap", 1))
	Gfx.changed.connect(func():
		if Gfx.current_preset() == 3:
			add_all("ultra", 1))


func _process(delta: float) -> void:
	if _dirty:
		_save_time += delta
		if _save_time > 3.0:
			save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if _dirty:
			save()


# --- Perfis ------------------------------------------------------------------

func create(name: String, select := true) -> int:
	var clean := name.strip_edges().left(16)
	if clean.is_empty():
		clean = "Chef %d" % (profiles.size() + 1)
	profiles.append({"name": clean, "stats": {}, "unlocked": {}, "look": CharacterLook.random()})
	var index := profiles.size() - 1
	if select:
		active = index
	_add(index, "profile", 1)
	save()
	return index


func rename(index: int, name: String) -> void:
	if index >= 0 and index < profiles.size() and not name.strip_edges().is_empty():
		profiles[index]["name"] = name.strip_edges().left(16)
		save()


func remove(index: int) -> void:
	if index < 0 or index >= profiles.size() or profiles.size() <= 1:
		return
	profiles.remove_at(index)
	active = clampi(active if active < index else active - 1, 0, profiles.size() - 1)
	by_source.clear()
	save()


func profile_name(index: int) -> String:
	return profiles[index]["name"] if index >= 0 and index < profiles.size() else "Convidado"


## Perfil de um jogador deste PC (pela fonte de input).
func for_source(source_id: String) -> int:
	if by_source.has(source_id):
		return by_source[source_id]
	# O primeiro jogador usa o perfil ativo; os outros, um que ainda ninguém tenha.
	var used: Array = by_source.values()
	var index := active if not used.has(active) else GUEST
	if index == GUEST:
		for i in profiles.size():
			if not used.has(i):
				index = i
				break
	by_source[source_id] = index
	return index


func cycle_source(source_id: String, dir: int) -> int:
	var index: int = for_source(source_id)
	var used: Array = []
	for k in by_source:
		if k != source_id:
			used.append(by_source[k])
	# Convidado (-1) e os perfis livres, por ordem.
	for i in profiles.size() + 1:
		index = posmod(index + 1 + dir, profiles.size() + 1) - 1
		if index == GUEST or not used.has(index):
			break
	by_source[source_id] = index
	changed.emit()
	return index


func forget_source(source_id: String) -> void:
	by_source.erase(source_id)


# --- Estatísticas e conquistas -------------------------------------------------

## Começa uma ronda com os perfis destes jogadores (índices; os convidados não contam).
func start_round(indices: Array) -> void:
	playing.clear()
	for i in indices:
		if i >= 0 and i < profiles.size() and not playing.has(i):
			playing.append(i)
	round_stats.clear()
	var hour := Time.get_time_dict_from_system()["hour"] as int
	if hour < 5:
		add("night", 1)


func end_round() -> void:
	for key in round_stats:
		best(key + "_round_best", round_stats[key])
	round_stats.clear()
	playing.clear()
	save()


## Soma `amount` à estatística de todos os perfis que estão a jogar.
func add(stat: String, amount := 1) -> void:
	if amount == 0:
		return
	round_stats[stat] = round_stats.get(stat, 0) + amount
	for i in playing:
		_add(i, stat, amount)


## Guarda o máximo (para estatísticas "_best").
func best(stat: String, value: int) -> void:
	for i in playing:
		var s: Dictionary = profiles[i]["stats"]
		if value > int(s.get(stat, 0)):
			s[stat] = value
			_check(i, stat)
			_dirty = true


## Como add, mas para o perfil ativo mesmo fora de uma ronda (definições).
func add_all(stat: String, amount: int) -> void:
	if playing.is_empty():
		if active < profiles.size():
			var s: Dictionary = profiles[active]["stats"]
			s[stat] = maxi(int(s.get(stat, 0)), amount)
			_check(active, stat)
			_dirty = true
	else:
		for i in playing:
			var s: Dictionary = profiles[i]["stats"]
			s[stat] = maxi(int(s.get(stat, 0)), amount)
			_check(i, stat)
		_dirty = true


## Soma a um perfil só (ex.: o papel que esse jogador escolheu).
func add_to(index: int, stat: String, amount: int) -> void:
	if index >= 0 and index < profiles.size():
		_add(index, stat, amount)


func _add(index: int, stat: String, amount: int) -> void:
	var s: Dictionary = profiles[index]["stats"]
	s[stat] = int(s.get(stat, 0)) + amount
	_check(index, stat)
	_dirty = true


func _check(index: int, stat: String) -> void:
	var p: Dictionary = profiles[index]
	var value := int(p["stats"].get(stat, 0))
	for a in AchievementList.all():
		if a["stat"] == stat and value >= a["goal"] and not p["unlocked"].has(a["id"]):
			p["unlocked"][a["id"]] = int(Time.get_unix_time_from_system())
			unlocked.emit(p["name"], a)
			_check_meta(index)


## Conquistas que dependem de outras (todos os restaurantes com 3 estrelas...).
func _check_meta(index: int) -> void:
	var s: Dictionary = profiles[index]["stats"]
	var s3 := 0
	var hard := 0
	for level in Levels.ALL:
		if int(s.get("lv_%s_stars_best" % level["id"], 0)) >= 3:
			s3 += 1
		if int(s.get("lv_%s_hard3" % level["id"], 0)) >= 1:
			hard += 1
	if s3 > int(s.get("levels_s3", 0)) or hard > int(s.get("levels_hard3", 0)):
		s["levels_s3"] = s3
		s["levels_hard3"] = hard
		_check(index, "levels_s3")
		_check(index, "levels_hard3")


func unlocked_count(index: int) -> int:
	if index < 0 or index >= profiles.size():
		return 0
	# Só contam as que ainda existem (a lista foi encurtada na 0.5.3).
	return AchievementList.all().filter(func(a): return profiles[index]["unlocked"].has(a["id"])).size()


func is_unlocked(index: int, id: String) -> bool:
	return index >= 0 and index < profiles.size() and profiles[index]["unlocked"].has(id)


## Progresso (0..1) de uma conquista para um perfil.
func progress(index: int, a: Dictionary) -> float:
	if index < 0 or index >= profiles.size():
		return 0.0
	return clampf(float(profiles[index]["stats"].get(a["stat"], 0)) / float(a["goal"]), 0.0, 1.0)


# --- Guardar -------------------------------------------------------------------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var count: int = cfg.get_value("meta", "count", 0)
	for i in count:
		var section := "p%d" % i
		profiles.append({"name": cfg.get_value(section, "name", "Chef"),
			"stats": cfg.get_value(section, "stats", {}), "unlocked": cfg.get_value(section, "unlocked", {}),
			"look": CharacterLook.clean(cfg.get_value(section, "look", CharacterLook.preset(i))),
			"online": cfg.get_value(section, "online", {})})
	active = clampi(cfg.get_value("meta", "active", 0), 0, maxi(profiles.size() - 1, 0))


## O boneco de um perfil (o dos convidados é um dos predefinidos).
func look(index: int, fallback := 0) -> Dictionary:
	if index >= 0 and index < profiles.size():
		return profiles[index].get("look", CharacterLook.preset(index))
	return CharacterLook.preset(fallback)


func set_look(index: int, value: Dictionary) -> void:
	if index >= 0 and index < profiles.size():
		profiles[index]["look"] = CharacterLook.clean(value)
		save()


func save(progress_changed := true) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "count", profiles.size())
	cfg.set_value("meta", "active", active)
	for i in profiles.size():
		var section := "p%d" % i
		cfg.set_value(section, "name", profiles[i]["name"])
		cfg.set_value(section, "stats", profiles[i]["stats"])
		cfg.set_value(section, "unlocked", profiles[i]["unlocked"])
		cfg.set_value(section, "look", profiles[i].get("look", {}))
		cfg.set_value(section, "online", profiles[i].get("online", {}))
	cfg.save(SAVE_PATH)
	_dirty = false
	_save_time = 0.0
	changed.emit()
	if progress_changed:
		saved.emit()
