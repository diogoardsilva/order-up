class_name PromptBar
extends Control
## Fila de legendas com os botões desenhados como no comando (ou no teclado, se
## não houver comando ligado). Ex.: [✕] Entrar   [○] Sair.

## Cada item: [ação, texto]. A ação "move" desenha o analógico (ou WASD).
var items: Array = []
var button_height := 30.0
var font_size := 22
var color := UiStyle.TEXT


func _init(p_items: Array = []) -> void:
	items = p_items
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 40


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	Glyphs.draw_bar(self, Glyphs.primary_source(), items, size / 2.0, button_height, font_size, color)
