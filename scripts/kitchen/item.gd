class_name Item
extends RefCounted
## Algo que um chef pode segurar: um ingrediente, um prato (ou uma pilha de
## pratos vazios, ou dois pratos com comida) ou uma panela/frigideira.

const PLATE := "plate"
## Copo com uma bebida (serve-se como um prato).
const GLASS := "glass"
const COOKWARE := "cookware"
## Quantos pratos vazios se levam de uma vez.
const MAX_STACK := 4
## Estado da panela: vazia, a encher (ainda não é receita), a cozinhar, pronta, queimada.
enum Cook { EMPTY, FILLING, COOKING, READY, BURNT }
const COOK_TIME := 6.0
const BURN_TIME := 8.0
## Até 2 doses de uma vez: o dobro dos ingredientes dá 2 pratos.
const COOK_MAX := 6
const MAX_PORTIONS := 2
## Quantos ingredientes iguais se levam na mão: 4 dos pequenos, 2 dos grandes.
const BIG_INGREDIENTS: Array[String] = ["lettuce", "kale", "cod", "salmon", "steak", "dough", "pasta", "rice", "noodles"]

## "plate", "cookware" ou o id do ingrediente cru, ex. "tomato".
var kind: String
var chopped := false
## Só para pratos: veio de uma mesa e tem de ser lavado.
var dirty := false
## Pratos: ids do que está em cima, ex. ["lettuce_chopped", "tomato_chopped"].
## Panelas: os ingredientes lá dentro.
var contents: Array[String] = []
## Só para pratos vazios: quantos estão empilhados (1 a 4).
var stack := 1
## Só para ingredientes: quantos iguais (ex. 2 queijos). Ver max_count().
var count := 1
## Só para panelas prontas: quantos pratos ainda dá (1 ou 2).
var portions := 1
## Só para pratos com comida: um segundo prato levado na outra mão.
var second: Item
## Só para panelas.
var cook_state := Cook.EMPTY
var cook_timer := 0.0
var product := ""
## Desenho da panela vazia ("pot", "pan" ou "oven"); com comida vem da receita.
var tool := "pot"


static func ingredient(p_kind: String) -> Item:
	var item := Item.new()
	item.kind = p_kind
	return item


static func plate() -> Item:
	return ingredient(PLATE)


static func glass(drink: String) -> Item:
	var item := ingredient(GLASS)
	item.contents.assign([drink])
	return item


## O que se leva à mesa para esta receita (prato ou copo), já completo.
static func for_recipe(recipe: Dictionary) -> Item:
	if recipe.get("drink", false):
		return glass(recipe["needs"][0])
	var item := plate()
	item.contents.assign(recipe["needs"])
	return item


static func cookware(p_tool: String) -> Item:
	var item := ingredient(COOKWARE)
	item.tool = p_tool
	return item


## Para enviar pela rede (ou null).
static func serialize(item: Item) -> Variant:
	if item == null:
		return null
	return [item.kind, item.chopped, item.contents, item.dirty, item.stack, serialize(item.second),
		item.cook_state, item.cook_timer, item.product, item.tool, item.count, item.portions]


static func deserialize(data: Variant) -> Item:
	if data == null:
		return null
	var item := ingredient(data[0])
	item.chopped = data[1]
	item.contents.assign(data[2])
	item.dirty = data[3]
	item.stack = data[4]
	item.second = deserialize(data[5])
	item.cook_state = data[6]
	item.cook_timer = data[7]
	item.product = data[8]
	item.tool = data[9]
	if data.size() > 11:
		item.count = data[10]
		item.portions = data[11]
	return item


## Pratos e copos (os dois levam-se às mesas).
func is_plate() -> bool:
	return kind == PLATE or kind == GLASS


func is_glass() -> bool:
	return kind == GLASS


func is_cookware() -> bool:
	return kind == COOKWARE


func is_ingredient() -> bool:
	return not is_plate() and not is_cookware()


## Pratos vazios iguais (todos sujos ou todos limpos) que cabem numa pilha.
func can_stack(other: Item) -> bool:
	return other != null and kind == PLATE and other.kind == PLATE and contents.is_empty() and other.contents.is_empty() \
		and second == null and dirty == other.dirty and stack + other.stack <= MAX_STACK


## Dois pratos com comida levam-se ao mesmo tempo (um em cada mão).
func can_pair(other: Item) -> bool:
	return other != null and is_plate() and other.is_plate() and not contents.is_empty() and not other.contents.is_empty() \
		and second == null and other.second == null


## Id de um ingrediente no estado atual, ex. "tomato" ou "tomato_chopped".
func content_id() -> String:
	return kind + ("_chopped" if chopped else "")


## Quantos destes se levam de uma vez na mão.
func max_count() -> int:
	return 2 if BIG_INGREDIENTS.has(kind) else 4


## Junta outro ingrediente igual a este molho. Devolve true se coube todo.
func can_merge(other: Item) -> bool:
	return other != null and is_ingredient() and other.is_ingredient() and other.kind == kind \
		and other.chopped == chopped and count + other.count <= max_count()


## Tira um deste molho (ex. para pôr num prato). Devolve false se era o último.
func take_one() -> bool:
	count -= 1
	return count > 0


func can_chop() -> bool:
	return is_ingredient() and not chopped and Recipes.CHOPPABLE.has(kind)


## Tenta pôr algo neste prato. Devolve true se coube.
func try_add(id: String) -> bool:
	if kind != PLATE or dirty or stack > 1 or second != null or contents.any(func(c): return Recipes.SOLO.has(c)):
		return false
	if Recipes.SOLO.has(id):
		if not contents.is_empty():
			return false
	elif not Recipes.PLATEABLE.has(id) or contents.has(id) or contents.size() >= Recipes.PLATE_MAX:
		return false
	contents.append(id)
	return true


# --- Panelas -----------------------------------------------------------------

## Junta um ingrediente à panela, se ainda pode vir a ser uma receita
## (uma ou duas doses).
func cook_add(id: String) -> bool:
	if not is_cookware() or not cook_state in [Cook.EMPTY, Cook.FILLING, Cook.COOKING] or contents.size() >= COOK_MAX:
		return false
	var next := contents.duplicate()
	next.append(id)
	if not Recipes.cook_possible(next):
		return false
	contents.append(id)
	cook_timer = 0.0
	var cook := Recipes.cook_match(contents)
	if cook.is_empty():
		cook_state = Cook.FILLING
	else:
		cook_state = Cook.COOKING
		product = cook["out"]
		portions = cook.get("portions", 1)
	return true


## Põe na panela todos os que couberem de um molho de ingredientes. Devolve
## o que sobra na mão (ou null se foram todos).
func cook_add_all(held: Item) -> Item:
	while held != null and cook_add(held.content_id()):
		if not held.take_one():
			held = null
	return held


## Tempo a cozinhar: duas doses demoram um bocadinho mais.
func cook_time() -> float:
	return COOK_TIME * (1.0 + 0.4 * (portions - 1))


## Só coze em cima de um fogão.
func cook_tick(delta: float) -> void:
	if cook_state == Cook.COOKING:
		cook_timer += delta
		if cook_timer >= cook_time():
			cook_state = Cook.READY
			cook_timer = 0.0
	elif cook_state == Cook.READY:
		cook_timer += delta
		if cook_timer >= BURN_TIME:
			cook_state = Cook.BURNT


func cook_progress() -> float:
	return cook_timer / cook_time() if cook_state == Cook.COOKING else -1.0


func is_burning_soon() -> bool:
	return cook_state == Cook.READY and cook_timer > BURN_TIME * 0.5


## Serve o que está pronto para um prato. Devolve true se serviu.
func pour_into(plate_item: Item) -> bool:
	if is_cookware() and cook_state == Cook.READY and plate_item.try_add(product):
		# Com duas doses fica a outra na panela.
		portions -= 1
		if portions <= 0:
			empty_cookware()
		return true
	return false


func empty_cookware() -> void:
	contents.clear()
	cook_state = Cook.EMPTY
	cook_timer = 0.0
	product = ""
	portions = 1


## Desenho atual: panela, frigideira ou forno.
func cook_look() -> String:
	return Recipes.cook_tool(contents) if not contents.is_empty() else tool
