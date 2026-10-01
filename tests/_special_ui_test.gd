extends Node

# Headless smoke test: the main scene must build, and the UI-side special
# activation must spend the card's special cost in OP, and must refuse
# cleanly when the player cannot afford it.

func _ready() -> void:
	var fails: int = 0
	await get_tree().process_frame
	var main = (load("res://src/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	fails += _check(main != null, "Main.tscn instantiates cleanly")
	if main == null:
		_finish(fails)
		return

	# Find Q special card definition
	var q_card: Dictionary = {}
	for s in GameManager.SPECIAL_CARD_DEFS:
		if s.get("letter") == "Q":
			q_card = s.duplicate()
			break

	GameManager.hand[0] = q_card.duplicate()
	GameManager.hand[1] = {"letter": "E", "damage": 1, "color": "red"}
	GameManager.operation_points = 10
	main._refresh_ui()
	await get_tree().process_frame

	var cost: int = GameManager.get_special_cost(q_card)
	var label: Label = main.hand_card_views[0]["sub"]
	fails += _check(cost == 6, "Q special cost is 6 OP")
	fails += _check(str(label.text).contains("%d OP" % cost), "hand card shows '%d OP' in sub ('%s')" % [cost, label.text])

	# Afford it: UI path spends 6 OP and triggers Royal Summon (adds U to hand)
	await main._on_card_special_used({"type": "hand", "hand_index": 0})
	fails += _check(GameManager.get_operation_points() == 4, "UI activation spent 6 OP (10 -> 4)")
	fails += _check(str(main.message_label.text).contains("ROYAL SUMMON"), "UI reports ROYAL SUMMON ('%s')" % main.message_label.text)

	# Refuse an unaffordable activation
	var forced: Dictionary = q_card.duplicate()
	GameManager.hand[0] = forced
	GameManager.operation_points = 2
	main._refresh_ui()
	await get_tree().process_frame
	fails += _check(str(main.hand_card_views[0]["sub"].text).contains("6 OP"), "card still shows its 6 OP cost")
	await main._on_card_special_used({"type": "hand", "hand_index": 0})
	fails += _check(GameManager.get_operation_points() == 2, "UI refusal spends no OP")
	fails += _check(str(main.message_label.text).contains("Not enough OP"), "UI shows 'Not enough OP' ('%s')" % main.message_label.text)
	fails += _check(GameManager.hand[0] == forced, "UI refusal keeps the special card in hand")

	_finish(fails)

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
