extends Node

# Headless smoke test: the main scene must build, and the UI-side special
# activation must spend the card's damage value as OP cost, and must refuse
# cleanly when the player cannot afford it.

func _ready() -> void:
	var fails: int = 0
	await get_tree().process_frame
	var main = (load("res://Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	fails += _check(main != null, "Main.tscn instantiates without script errors")
	if main == null:
		_finish(fails)
		return

	# The hand card label shows the card's damage value as its OP cost.
	# Inject known cards so both branches run regardless of the random deal.
	var big: Dictionary = {"letter": "Q", "damage": 10, "color": "red"}
	GameManager.hand[0] = big
	GameManager.hand[1] = {"letter": "E", "damage": 1, "color": "red"}
	GameManager.hand[2] = {"letter": "J", "damage": 8, "color": "green"}
	GameManager.operation_points = 10
	main._refresh_ui()
	await get_tree().process_frame

	var cost: int = GameManager.get_special_cost(big)
	var label: Label = main.hand_card_views[0]["sub"]
	fails += _check(cost == int(big["damage"]), "UI cost equals the card's damage value")
	fails += _check(str(label.text).contains("%d OP" % cost), "hand card shows the OP cost ('%s')" % label.text)
	fails += _check(str(main.hand_card_views[2]["sub"].text).contains("8 OP"), "8-damage card shows an 8 OP cost")

	# Afford it: the UI path must spend exactly the cost and discard the group
	var grave_before: int = GameManager.get_graveyard().size()
	await main._on_card_special_used({"type": "hand", "hand_index": 0})
	fails += _check(GameManager.get_operation_points() == 0, "UI activation spent the cost (%d OP -> 0)" % cost)
	fails += _check(GameManager.get_graveyard().size() > grave_before, "UI activation discarded cards")
	fails += _check(str(main.message_label.text).contains("spent %d OP" % cost), "UI reports the spent OP ('%s')" % main.message_label.text)

	# Refuse an unaffordable activation. Inject a known special card so this runs
	# regardless of what the redraw dealt.
	var forced: Dictionary = {"letter": "Q", "damage": 10, "color": "red"}
	GameManager.hand[0] = forced
	GameManager.operation_points = 0
	main._refresh_ui()
	await get_tree().process_frame
	fails += _check(str(main.hand_card_views[0]["sub"].text).contains("10 OP"), "unaffordable card still shows its 10 OP cost")
	var grave_before2: int = GameManager.get_graveyard().size()
	await main._on_card_special_used({"type": "hand", "hand_index": 0})
	fails += _check(GameManager.get_operation_points() == 0, "UI refusal spends no OP")
	fails += _check(GameManager.get_graveyard().size() == grave_before2, "UI refusal discards no cards")
	fails += _check(str(main.message_label.text).contains("Not enough OP"), "UI shows a 'Not enough OP' message ('%s')" % main.message_label.text)
	fails += _check(GameManager.hand[0] == forced, "UI refusal keeps the special card in hand")

	_finish(fails)

func _find_special(hand: Array) -> int:
	for i in range(hand.size()):
		if hand[i] != null and GameManager.has_special_ability(hand[i]):
			return i
	return -1

func _finish(fails: int) -> void:
	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)

func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
