class_name Glyphs
## Desenhos dos botões, iguais aos do comando ou do teclado de cada jogador:
## no DualShock os botões redondos com ✕ azul, ○ vermelho, □ rosa e △ verde;
## no Xbox as letras A/B/X/Y com as cores deles; no teclado uma tecla com o
## nome. Desenhado com primitivas, por isso fica nítido em qualquer tamanho.

const PS_COLORS := {"cross": Color("8fb6ea"), "circle": Color("ff6f6f"), "square": Color("eb94d6"), "triangle": Color("45d6ae")}
const PS_BUTTON := {&"pick": "cross", &"use": "square", &"dash": "circle", &"throw": "triangle", &"emote": "L1", &"pause": "OPTIONS"}
const XBOX_BUTTON := {&"pick": "A", &"use": "X", &"dash": "B", &"throw": "Y", &"emote": "LB", &"pause": "MENU"}
const XBOX_COLORS := {"A": Color("6cc24a"), "B": Color("e8574d"), "X": Color("4d8fe8"), "Y": Color("f2c94c")}
const BODY := Color("2b2631")
const BODY_LIGHT := Color("4a4352")
const BODY_DARK := Color("17141b")
const KEY_TOP := Color("fff8e6")
const KEY_SIDE := Color("c9a877")
const INK := Color("3b2027")
## Nomes de teclas que o Godot dá em inglês, em versão curta.
const KEY_SHORT := {"Period": ".", "Slash": "/", "Comma": ",", "Semicolon": ";", "Backspace": "Apagar", "Escape": "Esc",
	"Kp Enter": "Enter", "Ctrl": "Ctrl", "Up": "↑", "Down": "↓", "Left": "←", "Right": "→"}


## Que botão desenhar: {"kind": "ps"/"xbox"/"key"/"none", "id": ...}.
static func info(source: InputSource, action: StringName) -> Dictionary:
	if source is GamepadSource:
		var pad := source as GamepadSource
		if action == &"move":
			return {"kind": "stick", "id": ""}
		if pad.is_playstation():
			return {"kind": "ps", "id": PS_BUTTON.get(action, "")}
		return {"kind": "xbox", "id": XBOX_BUTTON.get(action, "")}
	if source is KeyboardSource:
		if action == &"move":
			return {"kind": "key", "id": "WASD" if (source as KeyboardSource).layout == 0 else "Setas"}
		var name: String = source.prompt(action)
		return {"kind": "key", "id": KEY_SHORT.get(name, name)}
	return {"kind": "none", "id": ""}


## Largura que o botão ocupa com esta altura.
static func width(source: InputSource, action: StringName, h: float) -> float:
	var i := info(source, action)
	match i["kind"]:
		"ps", "xbox":
			if String(i["id"]).length() > 1 and not PS_COLORS.has(i["id"]):
				return _text_w(i["id"], h * 0.5) + h * 0.6
			return h
		"stick":
			return h
		"key":
			return maxf(h, _text_w(i["id"], h * 0.55) + h * 0.55)
	return 0.0


## Desenha o botão com o lado esquerdo em `left` e o centro vertical em `left.y`.
## Devolve a largura usada. `pressed` afunda o botão (para animar).
static func draw(ci: CanvasItem, source: InputSource, action: StringName, left: Vector2, h: float, pressed := false) -> float:
	var i := info(source, action)
	var w := width(source, action, h)
	var c := left + Vector2(w / 2.0, 0)
	var sink := h * 0.08 if pressed else 0.0
	match i["kind"]:
		"ps":
			if PS_COLORS.has(i["id"]):
				_round_button(ci, c, h, sink)
				_ps_symbol(ci, c + Vector2(0, sink - h * 0.04), h * 0.26, i["id"])
			else:
				_pill(ci, c, w, h * 0.7, sink, i["id"], Color("d9d3e6"))
		"xbox":
			if XBOX_COLORS.has(i["id"]):
				_round_button(ci, c, h, sink)
				_text(ci, c + Vector2(0, sink - h * 0.04), i["id"], h * 0.52, XBOX_COLORS[i["id"]])
			else:
				_pill(ci, c, w, h * 0.7, sink, i["id"], Color("d9d3e6"))
		"stick":
			_round_button(ci, c, h, sink)
			ci.draw_circle(c + Vector2(0, -h * 0.05), h * 0.26, BODY_DARK)
			ci.draw_circle(c + Vector2(0, -h * 0.08), h * 0.2, BODY_LIGHT)
			ci.draw_arc(c + Vector2(0, -h * 0.08), h * 0.2, 0, TAU, 16, Color(1, 1, 1, 0.25), maxf(1.0, h * 0.04))
			# Setinhas nos quatro lados: mexer.
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var tip: Vector2 = c + Vector2(0, -h * 0.06) + d * h * 0.44
				var side := d.orthogonal() * h * 0.07
				ci.draw_colored_polygon(PackedVector2Array([tip, tip - d * h * 0.09 + side, tip - d * h * 0.09 - side]), Color("d9d3e6"))
		"key":
			_key(ci, Rect2(left - Vector2(0, h / 2.0), Vector2(w, h)), i["id"], sink)
	return w


static func _round_button(ci: CanvasItem, c: Vector2, h: float, sink: float) -> void:
	var r := h * 0.5
	ci.draw_circle(c + Vector2(0, h * 0.06), r, BODY_DARK)  # lado
	ci.draw_circle(c + Vector2(0, sink), r * 0.94, BODY)
	ci.draw_arc(c + Vector2(0, sink), r * 0.82, PI * 1.1, PI * 1.75, 10, Color(1, 1, 1, 0.16), maxf(1.0, h * 0.06))
	ci.draw_arc(c + Vector2(0, sink), r * 0.94, 0, TAU, 24, BODY_DARK, maxf(1.0, h * 0.05))


static func _ps_symbol(ci: CanvasItem, c: Vector2, s: float, id: String) -> void:
	var col: Color = PS_COLORS[id]
	var t := maxf(2.0, s * 0.42)
	match id:
		"cross":
			ci.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), col, t)
			ci.draw_line(c + Vector2(s, -s), c + Vector2(-s, s), col, t)
		"circle":
			ci.draw_arc(c, s * 1.02, 0, TAU, 20, col, t)
		"square":
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.92, Vector2(s, s) * 1.84), col, false, t)
		"triangle":
			var p := PackedVector2Array([c + Vector2(0, -s * 1.15), c + Vector2(s * 1.1, s * 0.8), c + Vector2(-s * 1.1, s * 0.8), c + Vector2(0, -s * 1.15)])
			ci.draw_polyline(p, col, t, false)


static func _pill(ci: CanvasItem, c: Vector2, w: float, h: float, sink: float, text: String, fg: Color) -> void:
	var r := Rect2(c - Vector2(w, h) / 2.0, Vector2(w, h))
	var side := StyleBoxFlat.new()
	side.bg_color = BODY_DARK
	side.set_corner_radius_all(int(h / 2.0))
	ci.draw_style_box(side, Rect2(r.position + Vector2(0, h * 0.12), r.size))
	var top := StyleBoxFlat.new()
	top.bg_color = BODY
	top.set_corner_radius_all(int(h / 2.0))
	top.border_color = BODY_LIGHT
	top.set_border_width_all(1)
	ci.draw_style_box(top, Rect2(r.position + Vector2(0, sink), r.size))
	_text(ci, c + Vector2(0, sink), text, h * 0.62, fg)


static func _key(ci: CanvasItem, r: Rect2, text: String, sink: float) -> void:
	var depth := r.size.y * 0.14
	var body := Rect2(r.position, r.size - Vector2(0, depth))
	ci.draw_rect(Rect2(r.position + Vector2(-1, -1), r.size + Vector2(2, 2)), INK)
	ci.draw_rect(Rect2(r.position + Vector2(0, depth * 0.5), r.size - Vector2(0, depth * 0.5)), KEY_SIDE)
	ci.draw_rect(Rect2(body.position + Vector2(0, sink), body.size), KEY_TOP)
	ci.draw_rect(Rect2(body.position + Vector2(0, sink), Vector2(body.size.x, maxf(1.0, depth * 0.35))), Color.WHITE)
	_text(ci, body.get_center() + Vector2(0, sink), text, r.size.y * 0.55, INK)


static func _text(ci: CanvasItem, c: Vector2, text: String, size: float, color: Color) -> void:
	var s := int(maxf(8.0, size))
	var w := _text_w(text, size)
	ci.draw_string(UiStyle.FONT, c + Vector2(-w / 2.0, s * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, color)


static func _text_w(text: String, size: float) -> float:
	return UiStyle.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(8.0, size))).x


## A fonte de input "principal" deste PC para as legendas dos menus: o
## primeiro comando ligado, ou o teclado.
static func primary_source() -> InputSource:
	for s in DeviceManager.all_sources():
		if s is GamepadSource:
			return s
	return DeviceManager.keyboard_sources[0]


## Desenha uma fila de legendas "[botão] texto" centrada em `center`. Cada item é
## [ação, texto]. Devolve a largura total.
static func draw_bar(ci: CanvasItem, source: InputSource, items: Array, center: Vector2, h: float, font_size: int, color: Color) -> float:
	var gap := h * 0.35
	var spacing := h * 1.1
	var total := 0.0
	for it in items:
		total += width(source, it[0], h) + gap + UiStyle.FONT.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	total += spacing * (items.size() - 1)
	var x := center.x - total / 2.0
	for it in items:
		x += draw(ci, source, it[0], Vector2(x, center.y), h) + gap
		UiStyle.shadow_text(ci, Vector2(x, center.y + font_size * 0.36), it[1], font_size, color)
		x += UiStyle.FONT.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing
	return total


## Texto com botões no meio, ex. "Carrega em {pick} para pegar". Faz quebra de
## linha dentro de `width`. Cada {ação} vira o botão desenhado de cada fonte em
## `sources` (separados por "/"). Devolve a altura usada.
static func draw_rich(ci: CanvasItem, sources: Array, text: String, top_left: Vector2, width: float, font_size: int, color: Color, line_gap := 1.35, dry := false) -> float:
	var h := font_size * 1.25
	var line_h := font_size * line_gap
	var space := UiStyle.FONT.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := 0.0
	var y := 0.0
	for paragraph in text.split("\n"):
		x = 0.0
		for word in paragraph.split(" ", false):
			var tokens := _tokens(word)
			var ww := 0.0
			for t in tokens:
				ww += _token_w(sources, t, h, font_size)
			if x > 0.0 and x + ww > width:
				x = 0.0
				y += line_h
			if not dry:
				var cx := top_left.x + x
				var cy := top_left.y + y + font_size * 0.62
				for t in tokens:
					if t.begins_with("{"):
						cx += _draw_sources(ci, sources, StringName(t.substr(1, t.length() - 2)), Vector2(cx, cy), h, color)
					else:
						ci.draw_string(UiStyle.FONT, Vector2(cx, cy + font_size * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
						cx += UiStyle.FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			x += ww + space
		y += line_h
	return y


static func _tokens(word: String) -> Array:
	var out := []
	var rest := word
	while true:
		var a := rest.find("{")
		var b := rest.find("}", a)
		if a < 0 or b < 0:
			break
		if a > 0:
			out.append(rest.substr(0, a))
		out.append(rest.substr(a, b - a + 1))
		rest = rest.substr(b + 1)
	if not rest.is_empty():
		out.append(rest)
	return out


static func _token_w(sources: Array, t: String, h: float, font_size: int) -> float:
	if t.begins_with("{"):
		return _sources_w(sources, StringName(t.substr(1, t.length() - 2)), h)
	return UiStyle.FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Os vários botões de uma ação (um por tipo de comando/tecla diferente).
static func _unique(sources: Array, action: StringName) -> Array:
	var seen := {}
	var out := []
	for s in sources:
		var key := str(info(s, action))
		if not seen.has(key):
			seen[key] = true
			out.append(s)
	return out


static func _sources_w(sources: Array, action: StringName, h: float) -> float:
	var w := 0.0
	var list := _unique(sources, action)
	for s in list:
		w += width(s, action, h) + 2.0
	return w + maxf(0, list.size() - 1) * h * 0.4


static func _draw_sources(ci: CanvasItem, sources: Array, action: StringName, left: Vector2, h: float, color := INK) -> float:
	var x := left.x + 1.0
	var list := _unique(sources, action)
	for i in list.size():
		if i > 0:
			ci.draw_string(UiStyle.FONT, Vector2(x, left.y + h * 0.3), "/", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.7), Color(color, 0.6))
			x += h * 0.4
		x += draw(ci, list[i], action, Vector2(x, left.y), h) + 1.0
	return x - left.x + 1.0
