extends Node

# Headless tests for the three board-quality-of-life features:
#
#   1. DECK VIEWER WHILE REWARDING — the reward dialog offers a button that opens
#      the deck viewer, and the viewer is a sibling overlay that draws ON TOP of
#      the reward dialog, so the reward is still there underneath when it closes.
#   2. PILE-BY-PILE INSPECTION — the viewer lists the draw pile, the hand and the
#      graveyard as three separately counted sections, with EVERY card drawn
#      individually so a player can see exactly what is left in the draw pile.
#   3. DRAG-AND-DROP INSERTION — dropping a card between two cards inserts it in
#      that gap instead of appending, and the insertion caret is only counted as a
#      hint, never as a card.

func _ready() -> void:
	var main = (load("res://src/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var fails: int = 0
	fails += _check_reward_deck_viewer(main)
	fails += _check_pile_sections(main)
	fails += await _check_insertion_index(main)
	fails += _check_insertion_places_card(main)
	fails += _check_caret_is_not_a_card(main)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## 1. The reward dialog can open the deck viewer, which renders above it.
func _check_reward_deck_viewer(main) -> int:
	var fails: int = 0
	var reward: Control = main.get_node("RewardDialog")
	var piles: Control = main.get_node("PilesDialog")
	var button: Button = main.get_node("RewardDialog/DialogPanel/DialogVBox/DeckButton")

	fails += _check(button != null, "the reward dialog has a deck button")
	fails += _check(reward.get_index() < piles.get_index(),
		"the deck viewer is drawn on top of the reward dialog")

	# Opening it from the reward leaves the reward standing underneath.
	reward.visible = true
	button.pressed.emit()
	fails += _check(piles.visible, "the deck viewer opens from the reward screen")
	fails += _check(reward.visible,
		"the reward dialog is still open behind the deck viewer")
	main._close_piles_dialog()
	fails += _check(not piles.visible, "closing the deck viewer hides it again")
	fails += _check(reward.visible,
		"the reward dialog survived the deck viewer being opened and closed")
	reward.visible = false
	return fails


## 2. Three separately counted sections, every card drawn.
func _check_pile_sections(main) -> int:
	var fails: int = 0
	var gm = GameManager
	gm.reset_game()
	gm.graveyard.clear()
	for letter in ["A", "B", "C"]:
		gm.graveyard.append({"letter": letter, "damage": 1, "color": "red"})
	var draw_count: int = gm.get_draw_pile_cards().size()
	var hand_count: int = 0
	for card in gm.get_hand():
		if card != null:
			hand_count += 1

	main._refresh_piles_dialog()
	var body: Node = main.get_node("PilesDialog/DialogPanel/DialogVBox/Scroll/PilesBody")
	var labels: Array[String] = []
	var card_buttons: int = 0
	for node in _flatten(body):
		if node is Label:
			labels.append((node as Label).text)
		if node is Button:
			card_buttons += 1

	var head_text: String = "\n".join(labels)
	fails += _check(head_text.contains("DRAW PILE"), "the viewer names the DRAW PILE")
	fails += _check(head_text.contains("HAND"), "the viewer names the HAND")
	fails += _check(head_text.contains("GRAVEYARD"), "the viewer names the GRAVEYARD")
	fails += _check(head_text.contains("DRAW PILE  (%d)" % draw_count),
		"the draw pile is counted correctly (%d)" % draw_count)
	fails += _check(head_text.contains("HAND  (%d)" % hand_count),
		"the hand is counted correctly (%d)" % hand_count)
	fails += _check(head_text.contains("GRAVEYARD  (%d)" % gm.get_graveyard().size()),
		"the graveyard is counted correctly (%d)" % gm.get_graveyard().size())

	# Every single card in every pile is drawn as its own entry.
	var expected: int = draw_count + hand_count + gm.get_graveyard().size()
	fails += _check(card_buttons == expected,
		"every card is shown individually (%d of %d)" % [card_buttons, expected])
	return fails


## 3a. The drop position maps onto the right gap.
func _check_insertion_index(main) -> int:
	var fails: int = 0
	var container: Control = main.get_node("Scroll/Center/VBox/WorkbenchPanel/WorkbenchContainer")
	main.workbench_cards = []
	main._refresh_workbench_ui()
	# Three cards laid out left to right by the HBox.
	for i in range(3):
		main.workbench_cards.append(_card("E", i))
	main._refresh_workbench_ui()
	await main.get_tree().process_frame

	var centres: Array[float] = []
	for k in container.get_children():
		if k is Control and k != main._workbench_caret:
			centres.append((k as Control).position.x + (k as Control).size.x * 0.5)
	fails += _check(centres.size() == 3, "three cards are laid out (%d)" % centres.size())
	if centres.size() != 3:
		return fails

	# Panel-local = container-local + the container's offset inside the panel.
	var off: Vector2 = container.position
	var before_first: int = main._workbench_insert_index(off + Vector2(centres[0] - 40.0, 0.0))
	var gap_one: int = main._workbench_insert_index(off + Vector2(centres[1] - 40.0, 0.0))
	var gap_two: int = main._workbench_insert_index(off + Vector2(centres[2] - 40.0, 0.0))
	var past_last: int = main._workbench_insert_index(off + Vector2(centres[2] + 400.0, 0.0))

	fails += _check(before_first == 0, "left of card 1 inserts at 0 (got %d)" % before_first)
	fails += _check(gap_one == 1, "between cards 1-2 inserts at 1 (got %d)" % gap_one)
	fails += _check(gap_two == 2, "between cards 2-3 inserts at 2 (got %d)" % gap_two)
	fails += _check(past_last == 3, "past the last card appends (got %d)" % past_last)
	return fails


## 3b. A drop actually inserts the card there instead of appending.
func _check_insertion_places_card(main) -> int:
	var fails: int = 0
	main.workbench_cards = []
	main._refresh_workbench_ui()
	for i in range(2):
		main.workbench_cards.append(_card("E", i))
	main._refresh_workbench_ui()

	# Two "E" cards are on the board; the dropped "Z" must land BETWEEN them, so
	# the word reads E-Z-E rather than E-E-Z.
	main.add_card_to_workbench(_card("Z", 99), 1)
	fails += _check(_letters(main) == "EZE",
		"a card dropped at gap 1 lands between the two (%s)" % _letters(main))

	# The default (click) path must still append.
	main.add_card_to_workbench(_card("Q", 98))
	fails += _check(_letters(main) == "EZEQ",
		"the click path still appends to the end (%s)" % _letters(main))

	# An out-of-range index falls back to appending rather than erroring.
	main.add_card_to_workbench(_card("Y", 97), 999)
	fails += _check(main.workbench_cards.size() == 5,
		"an out-of-range index appends safely (%d cards)" % main.workbench_cards.size())
	return fails


## 3c. The caret is a hint, never counted as a card by the drop maths.
func _check_caret_is_not_a_card(main) -> int:
	var fails: int = 0
	main.workbench_cards = []
	main._refresh_workbench_ui()
	for i in range(2):
		main.workbench_cards.append(_card("E", i))
	main._refresh_workbench_ui()

	main._show_workbench_caret(1)
	fails += _check(main._workbench_caret != null, "the caret exists")
	fails += _check(main._workbench_caret.visible, "the caret is visible while shown")
	main._hide_workbench_caret()
	fails += _check(not main._workbench_caret.visible, "the caret hides on demand")

	# With the caret present the insert index must still count 2 cards, not 3.
	var container: Control = main.get_node("Scroll/Center/VBox/WorkbenchPanel/WorkbenchContainer")
	main._show_workbench_caret(0)
	fails += _check(container.get_child_count() == 3,
		"the caret sits in the container alongside the 2 cards (%d children)"
			% container.get_child_count())
	var idx: int = main._workbench_insert_index(container.position + Vector2(9000, 0))
	fails += _check(idx == 2,
		"the caret is ignored when counting cards (index %d)" % idx)
	main._hide_workbench_caret()
	return fails


func _card(letter: String, damage: int) -> Dictionary:
	return {"type": "hand", "hand_index": damage, "char": letter, "card_letter": letter,
		"is_wildcard": false, "damage": damage, "color": "red"}


func _letters(main) -> String:
	# Workbench entries carry the printed character under "char" (a wildcard shows
	# the letter it is standing in for), with "card_letter" as the fallback.
	var out: String = ""
	for c in main.workbench_cards:
		out += str(c.get("char", c.get("card_letter", "?")))
	return out


## Depth-first list of every node under `node`.
func _flatten(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_flatten(child))
	return out


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
