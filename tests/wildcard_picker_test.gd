extends Node
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func source(index: int) -> Dictionary:
	var card: Dictionary = GameManager.hand[index].duplicate()
	card["type"] = "hand"
	card["hand_index"] = index
	card["card_letter"] = card["letter"]
	card["char"] = card["letter"]
	card["is_wildcard"] = card["letter"] == "?"
	return card

func _ready() -> void:
	GameManager.reset_game()
	GameManager.hand = [{"letter": "C", "damage": 3, "color": "red"}, {"letter": "?", "damage": 0, "color": "blue"}, {"letter": "T", "damage": 1, "color": "green"}, {"letter": "?", "damage": 0, "color": "yellow"}]
	GameManager.slots = []
	for letter in ["?", "J", "K"]:
		GameManager.slots.append([{"letter": letter, "damage": 0, "color": "green"}, {"letter": "J", "damage": 1, "color": "yellow"}, {"letter": "K", "damage": 1, "color": "red"}])
	GameManager.current_slot_indices = [0, 0, 0]
	GameManager.enemy_skills.clear()
	GameManager.set_enemy_name("STONE")
	GameManager.enemy_hp = 500
	GameManager.enemy_max_hp = 500
	var main = load("res://src/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.add_card_to_workbench(source(0))
	main.add_card_to_workbench(source(1))
	check(main._wildcard_dialog.visible and main.workbench_cards.size() == 1, "Wildcard waits for explicit choice")
	main._cancel_wildcard_choice()
	check(main.workbench_cards.size() == 1 and GameManager.hand[1]["letter"] == "?", "Cancel neither places nor consumes card")
	main.add_card_to_workbench(source(1))
	main._choose_wildcard_letter("a")
	main.add_card_to_workbench(source(2))
	check(main._workbench_pattern() == "CAT", "Player chooses exact letter")
	check(main.workbench_cards[1]["card_letter"] == "?" and main.workbench_cards[1]["damage"] == 0 and main.workbench_cards[1]["color"] == "blue", "Physical wildcard retains damage and color")
	check(main.meaning_label.text == GameManager.get_word_translation("cat"), "Meaning preview matches chosen CAT")
	main._open_wildcard_picker(main.workbench_cards[1], -1, 1)
	main._choose_wildcard_letter("Z")
	check(main._workbench_pattern() == "CZT" and main.preview_label.text.contains("NOT A WORD"), "Invalid choice is not silently replaced by a valid word")
	await main._on_submit_pressed()
	check(GameManager.turn == 0 and main._workbench_pattern() == "CZT", "Invalid choice rejected without turn or automatic substitution")
	main._open_wildcard_picker(main.workbench_cards[1], -1, 1)
	main._cancel_wildcard_choice()
	check(main._workbench_pattern() == "CZT", "Cancel edit preserves previous choice")
	main._open_wildcard_picker(main.workbench_cards[1], -1, 1)
	main._choose_wildcard_letter("A")
	await main._on_submit_pressed()
	await get_tree().create_timer(3.0).timeout
	check(GameManager.turn == 1 and main.last_word == "CAT", "Actual submission uses player-selected CAT")
	check(GameManager.graveyard.any(func(c: Dictionary) -> bool: return c["letter"] == "?"), "Spent card stays a wildcard for future draws")
	# A drag-inserted shared wildcard keeps the requested insertion point.
	main.workbench_cards.clear()
	main._turn_resolving = false
	GameManager.hand = [{"letter": "C", "damage": 3, "color": "red"}]
	main.add_card_to_workbench(source(0))
	var slot := {"type": "slot", "index": 0, "letter": "?", "card_letter": "?", "char": "?", "damage": 0, "color": "green"}
	main.add_card_to_workbench(slot, 0)
	main._choose_wildcard_letter("Q")
	check(main._workbench_pattern().begins_with("Q") and main.workbench_cards[0]["type"] == "slot", "Shared wildcard drag preserves chosen letter and insertion gap")
	# Multiple wildcards have independent choices; keyboard D must not open deck.
	main.workbench_cards.clear()
	GameManager.hand = [{"letter": "?", "damage": 0, "color": "blue"}, {"letter": "?", "damage": 0, "color": "yellow"}]
	main.add_card_to_workbench(source(0))
	main._choose_wildcard_letter("A")
	main.add_card_to_workbench(source(1))
	var key := InputEventKey.new()
	key.keycode = KEY_D
	key.pressed = true
	main._wildcard_dialog.window_input.emit(key)
	check(main._workbench_pattern() == "AD", "Keyboard selection and independent wildcard choices")
	check(not main.piles_dialog.visible, "Letter D does not trigger deck shortcut")
	print("WILDCARD_PICKER_FAILURES=%d" % failures)
	get_tree().quit(failures)
