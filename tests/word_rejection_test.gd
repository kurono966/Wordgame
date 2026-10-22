extends Node
var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func placed(kind: String, index: int, letter: String) -> Dictionary:
	var card: Dictionary = (GameManager.hand[index] if kind == "hand" else GameManager.get_current_slot_card(index)).duplicate()
	card["type"] = kind
	card["hand_index" if kind == "hand" else "index"] = index
	card["card_letter"] = card["letter"]
	card["char"] = letter
	return card

func _ready() -> void:
	GameManager.reset_game()
	GameManager.turn = 32
	GameManager.enemy_hp = 9999
	GameManager.enemy_max_hp = 9999
	GameManager.enemy_skills.clear()
	GameManager.hand = [{"letter": "T", "damage": 1, "color": "red"}, {"letter": "P", "damage": 3, "color": "blue"}]
	GameManager.slots = []
	for letter in ["A", "R", "V"]:
		GameManager.slots.append([{"letter": letter, "damage": 1, "color": "green"}, {"letter": "I", "damage": 1, "color": "blue"}, {"letter": "O", "damage": 1, "color": "yellow"}])
	GameManager.current_slot_indices = [0, 0, 0]
	var main = load("res://src/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	check(GameManager.dictionary.has("trap"), "TRAP remains in dictionary")
	main.workbench_cards = [placed("hand", 0, "T"), placed("slot", 1, "R"), placed("slot", 0, "A"), placed("hand", 1, "P")]
	main._refresh_ui()
	check(main._workbench_pattern() == "TRAP", "Reproduces screenshot cards")
	check(main.preview_label.text.contains("有効") and main.preview_label.text.contains("2 → 1"), "Known word reports reversed shared sources, not missing dictionary entry")
	check(main.meaning_label.text == GameManager.get_word_translation("trap") and main.meaning_label.text != "", "Meaning still shown for known word")
	await main._on_submit_pressed()
	check(GameManager.turn == 32 and main.message_label.text == main.preview_label.text, "Submission gives same reason without spending turn")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/ui_word_rejection.png")
	# Even a spare hand A must not silently replace the chosen shared A.
	GameManager.hand.append({"letter": "A", "damage": 1, "color": "red"})
	main._refresh_ui()
	check(not GameManager.find_valid_assignments("TRAP").is_empty(), "An alternative physical assignment exists")
	await main._on_submit_pressed()
	check(GameManager.turn == 32 and main._workbench_pattern() == "TRAP", "Cannot silently substitute different cards for reversed placement")
	main.workbench_cards = [placed("hand", 1, "P"), placed("slot", 0, "A"), placed("slot", 1, "R"), placed("hand", 0, "T")]
	main._refresh_ui()
	check(main._workbench_error("PART").is_empty(), "Same original cards can spell PART")
	await main._on_submit_pressed()
	await get_tree().create_timer(1.5).timeout
	check(GameManager.turn == 33 and main.last_word == "PART", "PART really submits")
	check(GameManager.current_slot_indices == [1, 1, 0], "Submitted shared cards really rotate")
	check(main._workbench_error("ZZZZ").contains("未収録"), "Unknown vocabulary has a distinct rejection")
	# TRAP itself is playable when its selected letters are all in hand.
	GameManager.hand = [{"letter": "T", "damage": 1, "color": "red"}, {"letter": "R", "damage": 1, "color": "blue"}, {"letter": "A", "damage": 1, "color": "green"}, {"letter": "P", "damage": 3, "color": "yellow"}]
	main.workbench_cards = [placed("hand", 0, "T"), placed("hand", 1, "R"), placed("hand", 2, "A"), placed("hand", 3, "P")]
	check(main._workbench_error("TRAP").is_empty() and not GameManager.find_valid_assignments("TRAP").is_empty(), "TRAP allowed with feasible hand cards")
	print("WORD_REJECTION_FAILURES=%d" % failures)
	get_tree().quit(failures)
