extends Node
## Testes da lógica do jogo (corre na CI: godot --headless res://tests/logic_test.tscn).
## Escreve "TEST FAIL: ..." por cada erro e "TESTS OK" / "TESTS FAILED" no fim.

var _fails := 0


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("TEST FAIL: ", what)


func _ready() -> void:
	_test_levels()
	_test_double_portions()
	_test_stacks()
	_test_kitchens()
	print("TESTS OK" if _fails == 0 else "TESTS FAILED (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## Os 25 níveis: caixas chegam para os pratos, há desenho para tudo.
func _test_levels() -> void:
	for i in Levels.ALL.size():
		for k in range(-1, Levels.STAGES):
			var level := Levels.build(i, k)
			var label := "%s/%d" % [level["restaurant"], k]
			_ok(level["crates"].size() <= Levels.CRATE_LETTERS.length(), label + ": demasiadas caixas")
			for dish in Levels.dishes(level):
				_ok(not dish.is_empty(), label + ": prato inexistente")
				for content in dish.get("needs", []):
					for raw in Recipes.raw_for(content):
						_ok(level["crates"].has(raw), "%s: falta a caixa de %s para %s" % [label, raw, dish["id"]])
						_ok(Art.food(raw) != null, "sem desenho: " + raw)
					if not Recipes.is_drink(content):
						_ok(Art.food(content) != null, "sem desenho: " + content)
						_ok(Recipes.PLATEABLE.has(content) or Recipes.SOLO.has(content), content + " não vai ao prato")
				# O prato tem de se conseguir montar.
				var plate := Item.plate()
				for content in dish["needs"]:
					if not Recipes.is_drink(content):
						_ok(plate.try_add(content), "%s: não cabe %s no prato" % [dish["id"], content])
				if not dish.get("drink", false):
					_ok(Recipes.match_plate(plate.contents).get("id", "") == dish["id"], dish["id"] + ": prato montado não bate certo")
			for raw in level["crates"]:
				_ok(Levels.INGREDIENT_NAMES.has(raw), "sem nome: " + raw)
			_ok(level.has("stars") and level["stars"].size() == 3, label + ": estrelas")


## O dobro dos ingredientes dá 2 doses, e cada prato leva uma.
func _test_double_portions() -> void:
	for cook in Recipes.COOK:
		var pot := Item.cookware(cook["tool"])
		for k in 2:
			for id in cook["in"]:
				_ok(pot.cook_add(id), "%s: não aceita %s (dose %d)" % [cook["out"], id, k + 1])
		_ok(pot.cook_state == Item.Cook.COOKING and pot.product == cook["out"], cook["out"] + ": não coze 2 doses (" + pot.product + ")")
		_ok(pot.portions == 2, cook["out"] + ": devia ter 2 doses")
		pot.cook_tick(100.0)
		_ok(pot.cook_state == Item.Cook.READY, cook["out"] + ": não ficou pronto")
		_ok(pot.pour_into(Item.plate()), cook["out"] + ": não serve o 1.º prato")
		_ok(pot.cook_state == Item.Cook.READY and pot.portions == 1, cook["out"] + ": devia sobrar 1 dose")
		_ok(pot.pour_into(Item.plate()), cook["out"] + ": não serve o 2.º prato")
		_ok(pot.cook_state == Item.Cook.EMPTY, cook["out"] + ": devia ficar vazia")
	# Uma dose continua a funcionar.
	var pot := Item.cookware("pot")
	pot.cook_add("tomato_chopped")
	pot.cook_add("tomato_chopped")
	_ok(pot.product == "soup" and pot.portions == 1, "sopa de 1 dose")
	_ok(not pot.cook_add("salmon"), "salmão não entra na sopa")


## Vários ingredientes na mão, a cortar e a pôr na panela.
func _test_stacks() -> void:
	var crate := CrateStation.new("cheese")
	var held := crate.interact(null)
	for n in 5:
		held = crate.interact(held)
	_ok(held.count == 4, "queijo: devia levar 4 (leva %d)" % held.count)
	var big := CrateStation.new("salmon")
	var fish := big.interact(null)
	fish = big.interact(fish)
	fish = big.interact(fish)
	_ok(fish.count == 2, "salmão: devia levar 2 (leva %d)" % fish.count)
	var board := BoardStation.new()
	_ok(board.interact(held) == null, "pousar os 4 queijos na tábua")
	for n in 60:
		board.use(0.1)
	_ok(board.item.chopped and board.item.count == 4, "cortar os 4 queijos de uma vez")
	var chopped := board.interact(null)
	# Um prato leva um de cada vez.
	var counter := Station.new()
	counter.interact(Item.plate())
	chopped = counter.interact(chopped)
	_ok(chopped != null and chopped.count == 3, "o prato leva 1 queijo e sobram 3")
	# A panela leva os que precisa (2 tomates = sopa) e sobra o resto.
	var tomatoes := Item.ingredient("tomato")
	tomatoes.chopped = true
	tomatoes.count = 3
	var stove := StoveStation.new()
	stove.item = Item.cookware("pot")
	var rest := stove.interact(tomatoes)
	_ok(rest == null and stove.item.contents.size() == 3, "3 tomates entram na panela (a caminho de 2 sopas)")
	# Juntar iguais pousados.
	var a := Item.ingredient("egg")
	var c2 := Station.new()
	c2.interact(Item.ingredient("egg"))
	a = c2.interact(a)
	_ok(a.count == 2 and c2.item == null, "juntar 2 ovos da bancada")
	var line := Item.deserialize(Item.serialize(a))
	_ok(line.count == 2, "a rede leva a quantidade")


## Cada nível monta uma cozinha com as caixas certas.
func _test_kitchens() -> void:
	for i in Levels.ALL.size():
		for k in Levels.STAGES:
			var level := Levels.build(i, k)
			var orders := OrderManager.new()
			var kitchen := Kitchen.new(orders, level)
			orders.kitchen = kitchen
			var crates := []
			for st in kitchen.stations.values():
				if st is CrateStation:
					crates.append(st.ingredient)
			for raw in level["crates"]:
				_ok(crates.has(raw), "%s/%d: caixa de %s não está na cozinha" % [level["restaurant"], k, raw])
			kitchen.free()
			orders.free()
