extends Node
var failures: int = 0
var ability: Dictionary

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func setup(shield_value: int = 17, op: int = 10) -> void:
	GameManager.reset_game()
	GameManager.hand[0] = ability.duplicate()
	GameManager.shield = shield_value
	GameManager.operation_points = op
	GameManager.enemy_hp = 100
	GameManager.enemy_max_hp = 100
	GameManager.enemy_shield = 0

func _ready() -> void:
	for definition in GameManager.SPECIAL_CARD_DEFS:
		if definition.get("special_id", "") == "shield_burst":
			ability = definition.duplicate()
	check(not ability.is_empty(), "Card is available to reward/shop special pool")
	if ability.is_empty():
		get_tree().quit(1)
		return
	setup()
	GameManager.enemy_shield = 5
	GameManager.word_multiplier = 2
	GameManager.relic_shield_bonus = 10
	var result: Dictionary = GameManager.use_special_ability(0)
	check(result.get("valid", false) and result.get("shield_spent", 0) == 17, "Consumes exactly all 17 shield")
	check(GameManager.shield == 0, "Relic shield is consumed too, without immediate refund")
	check(GameManager.enemy_hp == 88 and GameManager.enemy_shield == 0, "17 attack absorbs 5 enemy shield and deals 12 HP")
	check(GameManager.total_damage == 17 and GameManager.word_multiplier == 2, "No word multiplier applied or consumed")
	check(GameManager.operation_points == 7 and GameManager.turn == 0, "Costs 3 OP and no turn")
	check(GameManager.graveyard.any(func(c: Dictionary) -> bool: return c.get("special_id", "") == "shield_burst"), "Used card enters graveyard")
	check(GameManager.hand[0] != null, "Replaces used card on nonlethal hit")
	setup(0)
	check(not GameManager.can_use_special_ability(ability), "UI disables ability without shield")
	var grave_before: int = GameManager.graveyard.size()
	result = GameManager.use_special_ability(0)
	check(not result["valid"] and GameManager.operation_points == 10 and GameManager.graveyard.size() == grave_before, "Zero shield spends neither OP nor card")
	setup(17, 2)
	result = GameManager.use_special_ability(0)
	check(not result["valid"] and GameManager.shield == 17 and GameManager.operation_points == 2 and GameManager.hand[0]["special_id"] == "shield_burst", "Insufficient OP leaves shield and card intact")
	setup(20)
	GameManager.enemy_hp = 5
	result = GameManager.use_special_ability(0)
	check(result.get("enemies_defeated_delta", 0) == 1 and GameManager.stage == 2, "Lethal hit advances stage once")
	check(GameManager.enemy_hp == GameManager.enemy_max_hp and GameManager.enemy_hp == 115, "Overkill does not carry into new enemy")
	check(GameManager.shield == 0 and GameManager.hand_redraw_pending, "Consumed shield stays zero and redraw awaits rewards")
	setup(20)
	GameManager.enemy_hp = 5
	var main = load("res://src/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await main._on_card_special_used({"type": "hand", "hand_index": 0})
	check(main.reward_dialog.visible and GameManager.pending_reward_choice, "UI offers rewards after ability kill")
	check(main.workbench_cards.is_empty() and not main._turn_resolving, "Clears old board references and releases UI")
	main.reward_dialog.hide()
	setup(20)
	GameManager.stage = 3
	GameManager.enemy_hp = 5
	main._refresh_ui()
	await main._on_card_special_used({"type": "hand", "hand_index": 0})
	check(main.shop_dialog.visible and GameManager.stage == 4, "Third-stage ability kill opens shop")
	print("SHIELD_BURST_FAILURES=%d" % failures)
	get_tree().quit(failures)
