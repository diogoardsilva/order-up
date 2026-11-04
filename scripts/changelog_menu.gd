extends Control
## Novidades: o que mudou em cada versão, da mais recente para a mais antiga.
## Rola com a roda do rato, com cima/baixo ou com o analógico; a bola (ou o
## Esc, ou o botão "Voltar") fecha.

signal closed

const ENTRIES: Array = [
	["0.7.0", [
		"10 níveis em cada restaurante. Cada nível traz mais mesas e mais pratos.",
		"O restaurante cresce: a partir do 5.º nível o salão fica maior, e nos últimos há mesas de 6, 8 e 10 pessoas (e festas para as encher).",
		"10 pratos novos: bruschetta, salada com queijo, bife com batatas, pão com ovo, onigiri, nigiri de tamago, hambúrguer de cebola, cesto misto, polpette e salada de cogumelos.",
		"Os ajudantes também deslizam nos corredores compridos.",
		"Online: \"Criar sala\" ou \"Entrar numa sala\", com o código ou pela lista de amigos (botão Juntar).",
		"Online: no fim do nível qualquer jogador pode avançar, repetir ou voltar (já ninguém fica preso em \"à espera do host\").",
		"Online: se os dois PCs tiverem versões diferentes, o jogo diz quem tem de atualizar.",
		"O número da mesa aparece por cima do balão do pedido, como nos talões.",
		"Os bonecos andam mais suaves, sobretudo com o FPS acima de 60.",
	]],
	["0.6.2", [
		"Quando um grupo se vai embora sem comer, já dá para levantar o prato que ficou na mesa e deitá-lo fora.",
		"O nome de cada jogador aparece por cima do boneco.",
		"Os ajudantes cozinheiros fazem dose dupla quando há dois pedidos do mesmo prato.",
		"Botão Novidades no menu, com esta lista.",
	]],
	["0.6.1", [
		"Ao abrir, o jogo procura atualizações num ecrã próprio: descarrega, aplica e reinicia sozinho.",
		"Da primeira vez: boas-vindas para criar conta (ou entrar) e criar o boneco.",
	]],
	["0.6.0", [
		"Menus todos redesenhados. A bola volta sempre atrás e o Start só serve para começar.",
		"Todos os menus funcionam só com o rato.",
		"5 níveis em cada restaurante, cada um abre com 1 estrela no anterior.",
		"16 pratos novos: tosta, omelete, sopa de cogumelos, prego, pastel de nata, tempura, ramen, uramaki, cachorro, anéis de cebola, batatas com queijo, risotto, lasanha, pizza funghi e mais.",
		"Doses duplas: o dobro dos ingredientes na panela dá 2 pratos.",
		"Pegar em vários ingredientes de uma vez (4 pequenos ou 2 grandes) e cortar o molho todo na tábua.",
		"Pausa com a receita de cada prato do nível.",
	]],
	["0.5.6", [
		"Conta online: o boneco, as estrelas e os recordes sincronizam entre PCs.",
		"Atualizações automáticas.",
	]],
	["0.5.4", [
		"Contas online com utilizador e palavra-passe.",
		"Boneco personalizável e roupa por função.",
	]],
	["0.5.3", [
		"Ecrã sem barras pretas (16:10, 4:3) e tamanho da janela.",
		"Amigos online e mais conquistas, com o porquê no aviso.",
	]],
	["0.5.2", [
		"Cozinha maior, até 8 ajudantes, funções no lobby e bar com bebidas.",
		"Dificuldade (também personalizada), menu de pausa e mudar os comandos.",
		"Perfis com nome, quase 200 conquistas e salas online com código.",
		"Versões para Linux e macOS.",
	]],
	["0.5.1", [
		"Botões do comando certos em todo o lado, mais animações e sons.",
		"Modo Casa Aberta, sem fim até fecharem a porta.",
	]],
	["0.5.0", [
		"Definições de gráficos (Baixo a Ultra), painel de pedidos por prato e por mesa.",
		"Nomes dos ingredientes, passe com campainha e dois ajudantes.",
	]],
	["0.4.0", [
		"Cozinha com duas zonas, panelas que se tiram do fogão, atirar coisas e ajudante.",
	]],
]

var _scroll: ScrollContainer
var _back: Button


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.05, 0.9)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var col := VBoxContainer.new()
	col.position = Vector2(290, 26)
	col.custom_minimum_size.x = 700
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.add_child(UiStyle.label("Novidades", 52, UiStyle.TEXT, 10))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.paper_box())
	col.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(700, 500)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.custom_minimum_size.x = 660
	_scroll.add_child(list)
	for entry in ENTRIES:
		var title := UiStyle.label("Versão %s%s" % [entry[0], "  (esta)" if entry[0] == Updater.version() else ""], 30, UiStyle.INK_SOFT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(title)
		for line in entry[1]:
			var l := UiStyle.label("•  " + str(line), 21, UiStyle.INK)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 640
			list.add_child(l)
		var gap := Control.new()
		gap.custom_minimum_size.y = 8
		list.add_child(gap)
	_back = UiStyle.button("Voltar", func(): closed.emit(), 700)
	col.add_child(_back)


func focus_first() -> void:
	_scroll.scroll_vertical = 0
	_back.grab_focus()


func _process(delta: float) -> void:
	if not visible:
		return
	# Cima/baixo (ou o analógico) rola a lista.
	var dir := Input.get_axis("ui_up", "ui_down")
	if absf(dir) > 0.2:
		_scroll.scroll_vertical += int(dir * 700.0 * delta)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# O foco fica no Voltar: cima/baixo servem só para rolar.
	if event.is_action("ui_up") or event.is_action("ui_down"):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.play("ui_back")
		closed.emit()
