class_name PlateStation
extends Station
## Pilha de pratos limpos. No M3 os pratos passam a voltar sujos das mesas.


func interact(held: Item) -> Item:
	return Item.plate() if held == null else held
