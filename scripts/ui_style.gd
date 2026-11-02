class_name UiStyle
## Estilo da interface: fonte pixel, molduras de madeira e papel creme, a
## condizer com a arte do jogo. A UI é desenhada a 1280x720.

const FONT := preload("res://assets/fonts/Jersey15.ttf")
const PANEL_TEX := preload("res://assets/sprites/ui_panel.png")
const PAPER_TEX := preload("res://assets/sprites/ui_paper.png")
const BUTTON_TEX := preload("res://assets/sprites/ui_button.png")
const BUTTON_FOCUS_TEX := preload("res://assets/sprites/ui_button_focus.png")
const BUTTON_PRESSED_TEX := preload("res://assets/sprites/ui_button_pressed.png")

const BG := Color("2a1a1e")
const PANEL := Color("3d2a2e")
## Tinta escura (texto sobre papel) e papel.
const INK := Color("3b2027")
const INK_SOFT := Color("94532a")
const PAPER := Color("f6e6c4")
const TEXT := Color("fff8e6")
const MUTED := Color("c9a877")
const GOLD := Color("f6c444")
const RED := Color("e8574d")
const GREEN := Color("6fcf6a")

static var _theme: Theme


static func box(tex: Texture2D, margin: int, content: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(content)
	return sb


static func panel_box() -> StyleBoxTexture:
	return box(PANEL_TEX, 12, 22)


static func paper_box() -> StyleBoxTexture:
	return box(PAPER_TEX, 6, 10)


## Tema partilhado por todos os ecrãs com Controls.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 24
	t.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		var tex: Texture2D = {"normal": BUTTON_TEX, "hover": BUTTON_FOCUS_TEX, "focus": BUTTON_FOCUS_TEX,
			"pressed": BUTTON_PRESSED_TEX, "disabled": BUTTON_TEX}[state]
		var sb := box(tex, 8, 10)
		sb.content_margin_top = 6
		sb.content_margin_bottom = 12
		t.set_stylebox(state, "Button", sb)
	t.set_font_size("font_size", "Button", 28)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_stylebox("panel", "PanelContainer", panel_box())
	var edit := paper_box()
	edit.content_margin_left = 14
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", paper_box())
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_SOFT)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_font_size("font_size", "LineEdit", 26)
	_theme = t
	return t


static func label(text: String, size := 24, color := TEXT, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Botão de madeira que cresce ao ganhar foco e faz som.
static func button(text: String, on_pressed: Callable, width := 380.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 60)
	b.focus_entered.connect(func():
		Sfx.play("ui_move")
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.focus_exited.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	b.mouse_entered.connect(func(): b.grab_focus())
	b.pressed.connect(func():
		Sfx.play("ui_confirm")
		on_pressed.call())
	return b


## Texto com sombra, desenhado num CanvasItem qualquer.
static func shadow_text(ci: CanvasItem, at: Vector2, text: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	ci.draw_string(FONT, at + Vector2(2, 2), text, align, width, size, INK)
	ci.draw_string(FONT, at, text, align, width, size, color)


static func background(parent: Control) -> void:
	var bg := MenuBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
