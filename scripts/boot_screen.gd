class_name BootScreen
extends Control
## Ecrã ao abrir o jogo: procura atualizações e, se houver, descarrega-a,
## aplica-a e reinicia o jogo sozinho. Sem internet (ou já na versão mais
## recente) passa ao menu. A bola, o Esc ou o botão "Saltar" deixam a
## atualização a descarregar por trás e vão já para o menu.

signal finished

const STEPS: Array[String] = ["Procurar atualizações", "Descarregar", "Aplicar", "Reiniciar"]
const CARD := Rect2(340, 130, 600, 440)
const CHECK_TIMEOUT := 10.0

## Passos já feitos e o passo a decorrer (-1: nenhum).
var _done := 0
var _active := 0
var _status := "A ver se há uma versão nova..."
var _progress := -1.0
var _time := 0.0
var _wait := 0.0
var _leaving := false
var _busy := false
var _frozen := false
var _skip: Button
var _card: Control


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.05, 0.95)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_card = Control.new()
	_card.position = CARD.position
	_card.size = CARD.size
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.draw.connect(_draw_card)
	add_child(_card)
	_skip = UiStyle.button("Saltar", _leave, 220, false)
	_skip.position = Vector2(530, 596)
	add_child(_skip)
	_card.scale = Vector2(0.9, 0.9)
	_card.pivot_offset = _card.size / 2.0
	_card.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "modulate:a", 1.0, 0.2)
	if not Updater.can_update():
		# No editor (e na CI) não há atualizações: só se mostra a versão.
		_done = 1
		_active = -1
		_status = "Versão %s de desenvolvimento." % Updater.version()
		_finish_after(1.0)
		return
	Updater.changed.connect(_on_updater)
	Updater.check_now()
	_on_updater()


## Para as capturas da CI: mostra um estado sem ir à internet.
func preview(state: String, progress := 0.0, version := "0.6.1") -> void:
	_frozen = true
	_skip.show()
	match state:
		"downloading":
			_done = 1
			_active = 1
			_progress = progress
			_status = "A descarregar a versão %s...  %d%%" % [version, int(progress * 100.0)]
	_card.queue_redraw()


func _on_updater() -> void:
	if _leaving or _busy:
		return
	match Updater.state:
		"checking":
			_done = 0
			_active = 0
			_progress = -1.0
			_status = "A ver se há uma versão nova..."
		"downloading":
			_done = 1
			_active = 1
			_progress = Updater.progress
			_status = "A descarregar a versão %s...  %d%%" % [Updater.new_version, int(Updater.progress * 100.0)]
		"ready":
			if Updater.can_auto_restart():
				_apply_and_restart()
			else:
				_done = 2
				_active = -1
				_progress = 1.0
				_status = "A versão %s está pronta: atualiza no menu." % Updater.new_version
				_finish_after(1.8)
		"latest":
			_done = 1
			_active = -1
			_progress = 1.0
			_status = "Já tens a versão mais recente (%s)." % Updater.version()
			_finish_after(1.0)
		"error":
			_done = 0
			_active = -1
			_progress = -1.0
			_status = "Não deu para ver se há atualizações. Joga-se na mesma!"
			_finish_after(1.8)
	_card.queue_redraw()


func _apply_and_restart() -> void:
	_busy = true
	_skip.hide()
	_done = 2
	_active = 2
	_progress = 1.0
	_status = "A preparar a versão %s..." % Updater.new_version
	_card.queue_redraw()
	Sfx.play("ui_confirm")
	await get_tree().create_timer(1.0, true).timeout
	_done = 3
	_active = 3
	_status = "A reiniciar o jogo..."
	_card.queue_redraw()
	await get_tree().create_timer(0.9, true).timeout
	if not Updater.restart_now():
		_busy = false
		_active = -1
		_status = "Fecha e volta a abrir o jogo para ficar com a versão nova."
		_skip.text = "Continuar"
		_skip.show()
		_card.queue_redraw()


func _finish_after(secs: float) -> void:
	_skip.hide()
	await get_tree().create_timer(secs, true).timeout
	_leave()


func _leave() -> void:
	if _leaving or _busy or _frozen:
		return
	_leaving = true
	Sfx.play("ui_confirm")
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		finished.emit()
		queue_free())


func _process(delta: float) -> void:
	_time += delta
	if Updater.state == "checking" and not _leaving:
		_wait += delta
		if _wait > CHECK_TIMEOUT:
			# A internet está lenta: continua por trás e vai-se jogando.
			_wait = -1000.0
			_status = "A internet está lenta: continua a ver por trás."
			_finish_after(1.2)
	_card.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel") or (_skip.visible and event.is_action_pressed("ui_accept")):
		_leave()


func _draw_card() -> void:
	var ci := _card
	var w := CARD.size.x
	ci.draw_style_box(UiStyle.paper_box(), Rect2(Vector2.ZERO, CARD.size))
	# Título com uma tampa de prato a saltar.
	var bob := absf(sin(_time * 3.0)) * -8.0
	_draw_cloche(ci, Vector2(w / 2.0, 70 + bob))
	UiStyle.shadow_text(ci, Vector2(0, 150), "Order Up!", 64, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER, w)
	ci.draw_string(UiStyle.FONT, Vector2(0, 178), "versão %s" % Updater.version(), HORIZONTAL_ALIGNMENT_CENTER, w, 20, UiStyle.INK_SOFT)
	# Os passos.
	for i in STEPS.size():
		var y := 214.0 + i * 36.0
		var c := Vector2(150, y)
		if i < _done and i != _active:
			ci.draw_circle(c, 12.0, UiStyle.GREEN)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-2, 5), c + Vector2(6, -5)]), Color.WHITE, 3.0)
		elif i == _active:
			ci.draw_circle(c, 12.0, Color(UiStyle.GOLD, 0.35))
			var a := _time * 7.0
			ci.draw_arc(c, 10.0, a, a + PI * 1.3, 16, UiStyle.INK_SOFT, 3.5)
		else:
			ci.draw_arc(c, 10.0, 0.0, TAU, 20, Color(UiStyle.INK, 0.25), 2.5)
		var col := UiStyle.INK if i <= _done or i == _active else Color(UiStyle.INK, 0.4)
		ci.draw_string(UiStyle.FONT, Vector2(176, y + 9), STEPS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
	# Barra.
	var bar := Rect2(50, 366, w - 100, 22)
	ci.draw_rect(bar, Color(UiStyle.INK, 0.85))
	var inner := bar.grow(-3)
	if _progress >= 0.0:
		ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(_progress, 0.0, 1.0), inner.size.y)), UiStyle.GOLD)
	else:
		# Sem percentagem: um bloco que vai e vem.
		var seg := inner.size.x * 0.25
		var x := (sin(_time * 2.6) * 0.5 + 0.5) * (inner.size.x - seg)
		ci.draw_rect(Rect2(inner.position + Vector2(x, 0), Vector2(seg, inner.size.y)), UiStyle.GOLD)
	ci.draw_string(UiStyle.FONT, Vector2(0, 420), _status, HORIZONTAL_ALIGNMENT_CENTER, w, 24, UiStyle.INK)


func _draw_cloche(ci: CanvasItem, at: Vector2) -> void:
	var dark := UiStyle.INK
	ci.draw_rect(Rect2(at + Vector2(-46, 18), Vector2(92, 8)), dark)
	ci.draw_rect(Rect2(at + Vector2(-42, 18), Vector2(84, 4)), Color("d9dde3"))
	var pts := PackedVector2Array()
	for k in 17:
		var ang := PI + PI * k / 16.0
		pts.append(at + Vector2(cos(ang) * 38.0, 18.0 + sin(ang) * 34.0))
	ci.draw_colored_polygon(pts, Color("c2c8d0"))
	ci.draw_polyline(pts, dark, 3.0)
	ci.draw_arc(at + Vector2(-8, 4), 18.0, PI * 1.15, PI * 1.45, 6, Color.WHITE, 3.0)
	ci.draw_circle(at + Vector2(0, -20), 6.0, dark)
	ci.draw_circle(at + Vector2(0, -20), 4.0, Color("c2c8d0"))
