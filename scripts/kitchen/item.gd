class_name Item
extends RefCounted
## Algo que um chef pode segurar: um ingrediente ou um prato.

enum Kind { TOMATO, LETTUCE, PLATE }

const KIND_IDS := ["tomato", "lettuce", "plate"]

var kind: Kind
var chopped := false
## Só para pratos: veio de uma mesa e tem de ser lavado.
var dirty := false
## Só para pratos: ids do que está em cima, ex. ["lettuce_chopped", "tomato_chopped"] ou ["soup"].
var contents: Array[String] = []


static func ingredient(p_kind: Kind) -> Item:
	var item := Item.new()
	item.kind = p_kind
	return item


static func plate() -> Item:
	return ingredient(Kind.PLATE)


## Para enviar pela rede: [kind, chopped, contents, dirty] ou null.
static func serialize(item: Item) -> Variant:
	return null if item == null else [item.kind, item.chopped, item.contents, item.dirty]


static func deserialize(data: Variant) -> Item:
	if data == null:
		return null
	var item := ingredient(data[0])
	item.chopped = data[1]
	item.contents.assign(data[2])
	item.dirty = data[3]
	return item


func is_plate() -> bool:
	return kind == Kind.PLATE


## Id de um ingrediente no estado atual, ex. "tomato" ou "tomato_chopped".
func content_id() -> String:
	return KIND_IDS[kind] + ("_chopped" if chopped else "")


## Tenta pôr algo neste prato. Devolve true se coube.
func try_add(id: String) -> bool:
	if not is_plate() or dirty or contents.has("soup"):
		return false
	if id == "soup":
		if not contents.is_empty():
			return false
	elif not Recipes.PLATEABLE.has(id) or contents.has(id) or contents.size() >= 2:
		return false
	contents.append(id)
	return true
