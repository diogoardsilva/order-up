class_name UiStyle
## Cores e helpers partilhados pela UI provisória (até termos a arte final).

const BG := Color("2b2233")
const PANEL := Color("3d3248")
const TEXT := Color("f4f0e8")
const MUTED := Color("a89fb3")


static func label(text: String, size := 16, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
