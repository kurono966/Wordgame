extends Node

# Headless tests for the BURN A CARD flow around an enemy defeat:
#
#   1. THE WHOLE DECK IS OFFERED — the picker lists every card the player owns:
#      the draw pile, the hand AND the graveyard. Before, only the cards left in
#      the draw pile and the hand were shown, so cards parked in the spent pile
#      were invisible and could not be burned.
#   2. THE HAND IS REDRAWN AFTER THE REWARD — defeating an enemy no longer throws
#      the hand away and deals a new one on the spot. The cards the player was
#      holding survive until the reward has been taken, so the burn picker offers
#      the real cards rather than a surprise fresh hand.
#   3. BACKING OUT KEEPS THE REWARD — returning from the deck picker re-shows the
#      exact same three options instead of rolling a new set.

func _ready() -> void:
	var main = (load("res://Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var fails: int = 0
	fails += _check_hand_is_kept_through_the_reward(main)
	fails += _check_picker_lists_the_whole_deck(main)
	fails += _check_cancel_keeps_the_same_reward(main)
	fails += _check_burn_from_every_pile(main)
	fails += await _check_ui_rewards_then_redraws(main)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## Plays the killing word, so the game is sitting at the reward screen.
func _kill_enemy() -> Array:
	var gm = GameManager
	gm.reset_game()
	var before: Array = _hand_letters(gm)
	gm.enemy_hp = 1
	gm.execute_assignment("A", [{"type": "hand", "hand_index": 0, "char": "A",
		"card_letter": "A", "is_wildcard": false, "damage": 20, "color": "red"}])
	return before


## 1. The hand the player was holding is still on the board at reward time.
func _check_hand_is_kept_through_the_reward(main) -> int:
	var fails: int = 0
	var gm = GameManager
	var before: Array = _kill_enemy()

	fails += _check(gm.hand_redraw_pending,
		"defeating an enemy owes a hand redraw instead of doing it immediately")

	# Only the card that was actually played may have changed; the rest must still
	# be the cards the player finished the fight holding.
	var kept: int = 0
	for i in range(before.size()):
		if _letter_at(gm, i) == before[i]:
			kept += 1
	fails += _check(kept >= before.size() - 1,
		"the hand survived the kill (%d of %d cards kept)" % [kept, before.size()])

	# Now put the reward on screen for real, and re-check: the cards the burn
	# picker will offer are the ones the player was holding.
	main.show_reward_choice()
	fails += _check(gm.pending_reward_choice, "a reward is pending at reward time")

	var still_there: int = 0
	for i in range(before.size()):
		if _letter_at(gm, i) == before[i]:
			still_there += 1
	fails += _check(still_there >= before.size() - 1,
		"the reward screen still shows the kept hand (%d of %d)" % [still_there, before.size()])
	fails += _check(gm.hand_redraw_pending,
		"the redraw is still owed while the reward is on screen")
	main.reward_dialog.visible = false
	return fails


## 2. The picker offers every card the player owns, across all three piles.
func _check_picker_lists_the_whole_deck(main) -> int:
	var fails: int = 0
	var gm = GameManager
	_kill_enemy()

	var candidates: Array = gm.get_burnable_cards()
	var owned: int = gm.deck.size() + _hand_count(gm) + gm.graveyard.size()
	fails += _check(candidates.size() == owned,
		"the picker lists every card the player owns (%d of %d)"
			% [candidates.size(), owned])

	var seen: Dictionary = {}
	for entry in candidates:
		seen[str(entry.get("source", ""))] = true
	fails += _check(seen.has("deck"), "the draw pile is offered")
	fails += _check(seen.has("hand"), "the hand is offered")
	fails += _check(seen.has("grave"), "the spent pile is offered")

	# The subtitle must break the total down, so the player can see it is the
	# whole deck rather than only the draw pile.
	main._open_burn_picker()
	var subtitle: String = (main.get_node("BurnDialog/DialogPanel/DialogVBox/Subtitle")
		as Label).text
	fails += _check(subtitle.contains("%d deck" % gm.deck.size()),
		"the subtitle counts the draw pile (%s)" % subtitle)
	fails += _check(subtitle.contains("%d hand" % _hand_count(gm)),
		"the subtitle counts the hand")
	fails += _check(subtitle.contains("%d spent" % gm.graveyard.size()),
		"the subtitle counts the spent pile")

	# Every card is drawn, and each is tagged with the pile it came from.
	var grid: Node = main.get_node("BurnDialog/DialogPanel/DialogVBox/Scroll/BurnGrid")
	var buttons: int = 0
	var tags: Dictionary = {}
	for node in _flatten(grid):
		if node is Button:
			buttons += 1
		elif node is Label and str((node as Label).text) in ["in deck", "in hand", "spent"]:
			tags[(node as Label).text] = true
	fails += _check(buttons == candidates.size(),
		"every burnable card is drawn as a button (%d of %d)" % [buttons, candidates.size()])
	fails += _check(tags.size() > 0, "cards are tagged with the pile they came from")
	main.burn_dialog.visible = false
	return fails

## 3. Backing out of the picker keeps the reward exactly as it was.
func _check_cancel_keeps_the_same_reward(main) -> int:
	var fails: int = 0
	var gm = GameManager
	_kill_enemy()
	gm.roll_rewards()

	var first: Array = _reward_titles(gm)
	main._on_burn_cancel_pressed()
	var again: Array = _reward_titles(gm)

	fails += _check(not main.burn_dialog.visible, "cancelling closes the deck picker")
	fails += _check(first.size() > 0, "a reward was on offer (%d options)" % first.size())
	fails += _check(first == again,
		"the same reward is still on offer after cancelling (%s then %s)"
			% [", ".join(first), ", ".join(again)])
	fails += _check(gm.pending_reward_choice,
		"the reward is still pending after cancelling")
	main.reward_dialog.visible = false
	return fails


## 4. A card can be burned out of any pile, and the deck really shrinks.
func _check_burn_from_every_pile(main) -> int:
	var fails: int = 0
	for source in ["deck", "hand", "grave"]:
		var gm = GameManager
		_kill_enemy()
		gm.roll_rewards()
		gm.pending_burn_index = _index_of(gm, "BURN A CARD")
		var target: String = ""
		for entry in gm.get_burnable_cards():
			if str(entry.get("source", "")) == source:
				target = str(entry.get("id", ""))
				break
		fails += _check(target != "", "a %s card can be targeted" % source)

		var total_before: int = gm.deck.size() + _hand_count(gm) + gm.graveyard.size()
		var result: Dictionary = gm.confirm_burn_card(target)
		var total_after: int = gm.deck.size() + _hand_count(gm) + gm.graveyard.size()
		fails += _check(bool(result.get("ok", false)), "burning a %s card works" % source)
		fails += _check(total_after == total_before - 1,
			"burning a %s card really removes it (%d -> %d)"
				% [source, total_before, total_after])
		fails += _check(not gm.pending_reward_choice,
			"burning a %s card settles the reward" % source)

		# And a stale id must not burn anything.
		gm.roll_rewards()
		gm.pending_burn_index = _index_of(gm, "BURN A CARD")
		var bad: Dictionary = gm.confirm_burn_card("%s:9999" % source)
		fails += _check(not bad.get("ok", false),
			"a stale %s id is rejected" % source)
	return fails


## 5. Through the real UI: the reward is offered first, the redraw lands after.
func _check_ui_rewards_then_redraws(main) -> int:
	var fails: int = 0
	var gm = GameManager
	_kill_enemy()

	main.show_reward_choice()
	fails += _check(main.reward_dialog.visible, "the reward dialog is showing")
	fails += _check(gm.hand_redraw_pending,
		"the new hand has NOT been dealt while the reward is on screen")

	# Pick a reward that resolves in one click (not the two-step burn).
	var pick: int = 0
	for i in range(gm.reward_options.size()):
		if str(gm.reward_options[i].get("type", "")) != "remove_card":
			pick = i
			break
	main._on_reward_chosen(pick)

	fails += _check(not main.reward_dialog.visible, "the reward dialog closed")
	fails += _check(not gm.hand_redraw_pending, "the owed redraw was flushed")
	fails += _check(_hand_count(gm) == gm.hand_limit,
		"the hand is full for the new stage (%d of %d)" % [_hand_count(gm), gm.hand_limit])
	return fails


func _hand_letters(gm) -> Array:
	var out: Array = []
	for i in range(gm.hand.size()):
		out.append(_letter_at(gm, i))
	return out


func _letter_at(gm, i: int) -> String:
	if i < gm.hand.size() and gm.hand[i] != null:
		return str(gm.hand[i].get("letter", "?"))
	return ""


func _hand_count(gm) -> int:
	var n: int = 0
	for card in gm.hand:
		if card != null:
			n += 1
	return n


func _reward_titles(gm) -> Array:
	var out: Array = []
	for opt in gm.get_pending_reward_options():
		out.append(str(opt.get("title", "")))
	return out


func _index_of(gm, title: String) -> int:
	for i in range(gm.reward_options.size()):
		if str(gm.reward_options[i].get("title", "")) == title:
			return i
	return -1


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