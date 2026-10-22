extends Node
var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func grant(id: String) -> void:
	var catalogue: Array = GameManager.get_relic_catalogue()
	for candidate in range(1000):
		seed(candidate)
		var index: int = randi() % catalogue.size()
		if catalogue[index]["id"] == id:
			seed(candidate)
			var received: Dictionary = GameManager.grant_relic("STONE", ["ST", "ONE"])
			check(received["id"] == id, "Grant uses actual relic acquisition path")
			return
	check(false, "Could not find seed for relic")

func click_extra(main: Control, index: int) -> void:
	var panel = main.hand_card_views[index]["panel"]
	check(panel.has_signal("clicked"), "Additional hand card has interactive script")
	panel.clicked.emit(panel.card_data)
	if main._wildcard_dialog.visible:
		main._choose_wildcard_letter("A")
	check(main.workbench_cards.size() == 1 and main.workbench_cards[0]["hand_index"] == index, "Additional card can be placed with correct source index")
	await main._on_clear_pressed()

func _ready() -> void:
	GameManager.reset_game()
	var main = load("res://src/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	check(main.hand_card_views.size() == 7, "Initial hand has seven views")
	grant("expanded_pocket")
	main._refresh_ui()
	check(GameManager.hand_limit == 8 and GameManager.hand.size() == 8, "Real pocket grant deals eighth card")
	check(main.hand_card_views.size() == 8 and main.hand_container.get_child_count() == 8, "Eighth card is actually rendered")
	check(main.deck_grave_label.text.contains("8枚"), "UI shows increased hand count and limit")
	await click_extra(main, 7)
	grant("opening_hand")
	GameManager._advance_stage()
	GameManager.flush_pending_hand_redraw()
	main._refresh_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	check(GameManager.hand_limit == 8 and GameManager.hand.size() == 10, "Opening draw stacks on pocket without changing standing limit")
	check(main.hand_card_views.size() == 10, "All ten opening cards are rendered")
	check(main.hand_container.get_parent().get_h_scroll_bar().visible, "Wide hands can scroll instead of disappearing off screen")
	await click_extra(main, 9)
	# Exercise real HAND DOWN rather than assigning the hand limit directly.
	GameManager.enemy_skills = [{"letter": "B", "id": "hand_down", "name": "HAND DOWN", "value": 2}]
	GameManager.slots = []
	for color in ["blue", "green", "yellow"]:
		GameManager.slots.append([{"letter": "A", "color": color, "damage": 1}, {"letter": "B" if color == "blue" else "A", "color": color, "damage": 1}, {"letter": "A", "color": color, "damage": 1}])
	GameManager.current_slot_indices = [0, 0, 0]
	GameManager.is_night = true
	GameManager.stage_cleared_immune = false
	GameManager.apply_turn_start_penalty()
	main._refresh_ui()
	check(GameManager.hand_limit == 6 and main.hand_card_views.size() == 6, "Enemy reduction also removes obsolete UI views")
	GameManager._advance_stage()
	GameManager.flush_pending_hand_redraw()
	main._refresh_ui()
	check(GameManager.hand_limit == 8 and main.hand_card_views.size() == 10, "Next stage restores relic hand and opening bonus")
	grant("expanded_pocket")
	main._refresh_ui()
	check(GameManager.hand_limit == 9 and main.hand_card_views.size() == GameManager.hand.size(), "Stacked pocket stays reflected in UI")
	GameManager.reset_game()
	main._refresh_ui()
	check(main.hand_card_views.size() == 7 and main.hand_container.get_child_count() == 7, "Retry removes old views and restores seven cards")
	check(GameManager.hand_limit == 7 and GameManager.get_relic_count() == 0, "Retry clears relic stats")
	print("RELIC_HAND_UI_FAILURES=%d" % failures)
	get_tree().quit(failures)
