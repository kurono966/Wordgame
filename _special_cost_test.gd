extends SceneTree

# Headless check of the "damage value = OP cost" rule:
#   - get_card_cost / get_special_cost read the card's damage value
#   - a special costs exactly its damage value in OP
#   - a special is refused (no cards discarded, no OP lost) when OP are short

func _initialize() -> void:
	_run()

func _run() -> void:
	var gm = load("res://GameManager.gd").new()
	root.add_child(gm)
	await process_frame

	var fails: int = 0
	fails += _check(gm.get_card_cost({"letter": "E", "damage": 3, "color": "red"}) == 3, "cost of a 3-damage card is 3")
	fails += _check(gm.get_card_cost({"letter": "?", "damage": 0, "color": "red"}) == 0, "wildcard cost is 0")
	fails += _check(gm.get_card_cost(null) == 0, "null card cost is 0")

	var c8: Dictionary = {"letter": "J", "damage": 8, "color": "green"}
	var c10: Dictionary = {"letter": "Q", "damage": 10, "color": "red"}
	var c5: Dictionary = {"letter": "K", "damage": 5, "color": "blue"}
	fails += _check(gm.has_special_ability(c8) and gm.has_special_ability(c10), "8/10 damage cards have a special")
	fails += _check(not gm.has_special_ability(c5), "5 damage card has no special")
	fails += _check(gm.get_special_cost(c8) == 8, "8-damage special costs 8 OP")
	fails += _check(gm.get_special_cost(c10) == 10, "10-damage special costs 10 OP")
	fails += _check(gm.get_special_cost(c5) == 0, "non-special card costs 0 OP for a special")

	# Deterministic hand so the discard behaviour is observable
	gm.hand = [c8, {"letter": "E", "damage": 1, "color": "green"}, c5, {"letter": "A", "damage": 1, "color": "red"}]

	# 1) Too few OP -> refused, nothing changes
	gm.operation_points = 5
	gm.graveyard.clear()
	fails += _check(gm.get_special_cost_deficit(c8) == 3, "deficit of an 8-cost with 5 OP is 3")
	fails += _check(not gm.can_use_special_ability(c8), "cannot activate without enough OP")
	var denied: Dictionary = gm.use_special_ability(0)
	fails += _check(not denied.get("valid", false), "activation refused when short on OP")
	fails += _check(str(denied.get("reason", "")) == "Not enough OP", "refusal reason is 'Not enough OP'")
	fails += _check(gm.operation_points == 5, "refused activation spends no OP")
	fails += _check(gm.graveyard.is_empty(), "refused activation discards nothing")
	fails += _check(gm.hand[0] == c8, "refused activation keeps the special card in hand")

	# 2) Exactly enough OP -> succeeds and costs the damage value
	gm.operation_points = 8
	fails += _check(gm.can_use_special_ability(c8), "8 OP is enough for an 8-cost special")
	var ok: Dictionary = gm.use_special_ability(0)
	fails += _check(ok.get("valid", false), "activation succeeds with enough OP")
	fails += _check(int(ok.get("cost", 0)) == 8, "result reports a cost of 8")
	fails += _check(int(ok.get("operation_points_spent", 0)) == 8, "result reports 8 OP spent")
	fails += _check(gm.operation_points == 0, "8 OP are deducted by the 8-damage special")
	fails += _check(int(ok.get("drawn", 0)) == 2, "special + 1 same-color card are discarded (green group)")
	fails += _check(gm.hand[0] != null, "the spent hand slot is redrawn")
	fails += _check(gm.graveyard.size() == 2, "the special and its same-color card reached the graveyard")

	# 3) Wildcards / plain cards carry no special cost
	gm.operation_points = 100
	fails += _check(gm.get_special_cost({"letter": "?", "damage": 0, "color": "red"}) == 0, "wildcard has no special cost")

	# 4) OP still survive damage (cost is spent explicitly, never by damage)
	gm.operation_points = 7
	gm.shield = 0
	gm.player_hp = 50
	gm._take_self_damage(3)
	fails += _check(gm.operation_points == 7, "taking damage does not spend OP")

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	quit(fails)

func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
