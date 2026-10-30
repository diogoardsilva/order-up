class_name Item
extends RefCounted
## Algo que um chef pode segurar: um ingrediente ou um prato.

enum Kind { TOMATO, LETTUCE, PLATE }

const KIND_IDS := ["tomato", "lettuce", "plate"]

var kind: Kind
var chopped := false
## Só para pratos: ids do que está em cima, ex. ["lettuce_chopped", "tomato_chopped"] ou ["soup"].
var contents: Array[String] = []


static func ingredient(p_kind: Kind) -> Item:
	var item := Item.new()
	item.kind = p_kind
	return item


static func plate() -> Item:
	return ingredient(Kind.PLATE)


func is_plate() -> bool:
	return kind == Kind.PLATE


## Id de um ingrediente no estado atual, ex. "tomato" ou "tomato_chopped".
func content_id() -> String:
	return KIND_IDS[kind] + ("_chopped" if chopped else "")


## Tenta pôr algo neste prato. Devolve true se coube.
func try_add(id: String) -> bool:
	if not is_plate() or contents.has("soup"):
		return false
	if id == "soup":
		if not contents.is_empty():
			return false
	elif not Recipes.PLATEABLE.has(id) or contents.has(id) or contents.size() >= 2:
		return false
	contents.append(id)
	return true
