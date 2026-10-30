class_name Item
extends RefCounted
## Algo que um chef pode segurar: um ingrediente ou um prato.

const PLATE := "plate"
## Quantos pratos vazios se levam de uma vez.
const MAX_STACK := 2

## "plate" ou o id do ingrediente cru, ex. "tomato".
var kind: String
var chopped := false
## Só para pratos: veio de uma mesa e tem de ser lavado.
var dirty := false
## Só para pratos: ids do que está em cima, ex. ["lettuce_chopped", "tomato_chopped"] ou ["soup"].
var contents: Array[String] = []
## Só para pratos vazios: quantos estão empilhados (1 ou 2).
var stack := 1


static func ingredient(p_kind: String) -> Item:
	var item := Item.new()
	item.kind = p_kind
	return item


static func plate() -> Item:
	return ingredient(PLATE)


## Para enviar pela rede: [kind, chopped, contents, dirty, stack] ou null.
static func serialize(item: Item) -> Variant:
	return null if item == null else [item.kind, item.chopped, item.contents, item.dirty, item.stack]


static func deserialize(data: Variant) -> Item:
	if data == null:
		return null
	var item := ingredient(data[0])
	item.chopped = data[1]
	item.contents.assign(data[2])
	item.dirty = data[3]
	item.stack = data[4]
	return item


func is_plate() -> bool:
	return kind == PLATE


## Pratos vazios iguais (os dois sujos ou os dois limpos) que cabem numa pilha.
func can_stack(other: Item) -> bool:
	return other != null and is_plate() and other.is_plate() and contents.is_empty() and other.contents.is_empty() \
		and dirty == other.dirty and stack + other.stack <= MAX_STACK


## Id de um ingrediente no estado atual, ex. "tomato" ou "tomato_chopped".
func content_id() -> String:
	return kind + ("_chopped" if chopped else "")


func can_chop() -> bool:
	return not is_plate() and not chopped and Recipes.CHOPPABLE.has(kind)


## Tenta pôr algo neste prato. Devolve true se coube.
func try_add(id: String) -> bool:
	if not is_plate() or dirty or stack > 1 or contents.any(func(c): return Recipes.SOLO.has(c)):
		return false
	if Recipes.SOLO.has(id):
		if not contents.is_empty():
			return false
	elif not Recipes.PLATEABLE.has(id) or contents.has(id) or contents.size() >= Recipes.PLATE_MAX:
		return false
	contents.append(id)
	return true
