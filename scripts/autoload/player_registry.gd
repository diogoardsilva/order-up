extends Node
## Jogadores da sessão atual (1-4). No M2 passa a incluir jogadores remotos.

signal players_changed

const MAX_PLAYERS := 4
const COLORS: Array[Color] = [Color("e8574d"), Color("4d9be8"), Color("f2c94c"), Color("6fcf6a")]

## Cada entrada: {"slot": int, "source": InputSource, "color": Color}
var players: Array[Dictionary] = []


func join(source: InputSource) -> bool:
	if players.size() >= MAX_PLAYERS or has_source(source):
		return false
	var slot := 0
	while get_player(slot):
		slot += 1
	players.append({"slot": slot, "source": source, "color": COLORS[slot]})
	players.sort_custom(func(a, b): return a["slot"] < b["slot"])
	players_changed.emit()
	return true


func leave(source: InputSource) -> void:
	players = players.filter(func(p): return p["source"] != source)
	players_changed.emit()


func has_source(source: InputSource) -> bool:
	return players.any(func(p): return p["source"] == source)


func get_player(slot: int) -> Dictionary:
	for p in players:
		if p["slot"] == slot:
			return p
	return {}
