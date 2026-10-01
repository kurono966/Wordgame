extends Node

# Headless test for cards conjured by an ability.
#
# ROYAL SUMMON's 'U', JACK IN THE BOX's wildcard and VOWEL SHIFT's vowel are not
# drawn from the deck — they are made out of nothing. Recycling them into the
# graveyard would shuffle them back into the draw pile, so one ability
# activation would hand the player a permanent extra card. They are marked
# "ephemeral" and are DESTROYED on the way out instead.
#
# Every way a hand card can leave play must honour that: spending it in a word,
# a stage change that discards the hand, and DISCARD & DRAW picking one at
# random. Cards that really came from the deck are unaffected.

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame
	gm.reset_game()

	fails += _check_the_conjured_cards_are_marked(gm)
	fails += _check_using_one_destroys_it(gm)
	fails += _check_a_real_card_still_recycles(gm)
	fails += _check_stage_change_destroys_it(gm)
	fails += _check_discard_and_draw_destroys_it(gm)
	fails += _check_the_deck_never_grows(gm)
	fails += _check_burning_it_removes_it(gm)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## Each ability must hand out a card that is flagged ephemeral.
func _check_the_conjured_cards_are_marked(gm: Node) -> int:
	var fails: int = 0
	for ability in ["royal_summon", "jack_in_the_box", "vowel_shift"]:
		gm.reset_game()
		var idx: int = _grant(gm, ability)
		var conjured: Dictionary = gm.hand[idx]
		fails += _check(gm.is_ephemeral_card(conjured),
			"%s hands out an ephemeral card" % ability)
		fails += _check(_conjured_in(gm, gm.graveyard) == 0, "%s left no conjured card in the graveyard" % ability)
	return fails


## Spending the card in a word destroys it instead of recycling it.
func _check_using_one_destroys_it(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	var idx: int = _grant(gm, "royal_summon")
	var deck_before: int = gm.deck.size()
	var grave_before: int = gm.graveyard.size()

	gm.enemy_hp = 9999
	gm.execute_assignment(_letter_at(gm, idx), _spell(gm, idx))

	# The slot is refilled, so the check is that nothing conjured survived the
	# exit and the replacement came from the real draw pile.
	fails += _check(gm.graveyard.size() == grave_before,
		"the conjured card never reached the graveyard (%d -> %d)"
			% [grave_before, gm.graveyard.size()])
	fails += _check(_conjured_in(gm, gm.hand) == 0,
		"no conjured card is left in hand")
	var replacement: Dictionary = gm.hand[idx]
	fails += _check(replacement != null, "the slot was refilled")
	fails += _check(not gm.is_ephemeral_card(replacement),
		"the replacement is an ordinary deck card")
	fails += _check(gm.deck.size() == deck_before - 1,
		"the refill came out of the draw pile (%d -> %d)" % [deck_before, gm.deck.size()])
	return fails


## An ordinary deck card still cycles through the graveyard as before.
func _check_a_real_card_still_recycles(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.graveyard.clear()
	var idx: int = -1
	for i in range(gm.hand.size()):
		if gm.hand[i] != null and not gm.is_ephemeral_card(gm.hand[i]):
			idx = i
			break
	fails += _check(idx >= 0, "found a real card in hand")
	gm.enemy_hp = 9999
	gm.execute_assignment(_letter_at(gm, idx), _spell(gm, idx))
	fails += _check(gm.graveyard.size() == 1,
		"a real card still goes to the graveyard (%d)" % gm.graveyard.size())
	return fails


## A stage change discards the hand, and must not resurrect the conjured card.
func _check_stage_change_destroys_it(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.graveyard.clear()
	var idx: int = _grant(gm, "royal_summon")
	fails += _check(gm.is_ephemeral_card(gm.hand[idx]),
		"the card is ephemeral before the stage clear")
	gm.hand_redraw_pending = true
	gm.flush_pending_hand_redraw()
	fails += _check(_conjured_in(gm, gm.graveyard) == 0,
		"the conjured card did not survive into the new deck (%d conjured in graveyard)"
			% _conjured_in(gm, gm.graveyard))
	fails += _check(_conjured_in(gm, gm.hand) == 0,
		"no conjured card leaked into the fresh hand")
	return fails


## DISCARD & DRAW picks a random hand card to bin, and must respect the flag.
func _check_discard_and_draw_destroys_it(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.graveyard.clear()
	# Slot 0 holds DISCARD & DRAW. The ability discards one RANDOM other card, so
	# every other slot is emptied and the conjured card is the only candidate.
	gm.hand[1] = {"letter": "U", "damage": 1, "color": "red", "ephemeral": true}
	for i in range(gm.hand.size()):
		if i != 1:
			gm.hand[i] = null
	gm.hand[0] = _special("discard_draw")
	gm.operation_points = 99
	var result: Dictionary = gm.use_special_ability(0)
	fails += _check(bool(result.get("valid", false)), "DISCARD & DRAW ran")
	var leaked: int = _conjured_in(gm, gm.graveyard) + _conjured_in(gm, gm.deck) \
		+ _conjured_in(gm, gm.hand)
	fails += _check(leaked == 0,
		"the conjured card was destroyed, not recycled (%d survived)" % leaked)
	return fails


## The whole point: activating an ability must not permanently grow the deck.
func _check_the_deck_never_grows(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.operation_points = 999
	var total_before: int = _total_cards(gm)
	var idx: int = _grant(gm, "royal_summon")
	fails += _check(_total_cards(gm) == total_before + 1,
		"the ability adds exactly one card (%d -> %d)" % [total_before, _total_cards(gm)])

	gm.enemy_hp = 9999
	gm.execute_assignment(_letter_at(gm, idx), _spell(gm, idx))

	# A refill replaced it, so the total is back where it started.
	fails += _check(_total_cards(gm) == total_before,
		"using it leaves the card count unchanged (%d)" % _total_cards(gm))

	# And draining the whole pile must never turn up a conjured card.
	for _i in range(total_before + 5):
		gm._draw_card()
	var conjured: int = _conjured_in(gm, gm.deck) + _conjured_in(gm, gm.graveyard)
	fails += _check(conjured == 0,
		"no conjured card ever reappears in the deck (%d found)" % conjured)
	return fails


## Burning a conjured card removes it outright, which it already did.
func _check_burning_it_removes_it(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	var idx: int = _grant(gm, "royal_summon")
	gm.roll_rewards()
	gm.pending_burn_index = _burn_index(gm)
	var target: String = ""
	for entry in gm.get_burnable_cards():
		if str(entry.get("source", "")) == "hand" and gm.is_ephemeral_card(entry.get("card", {})):
			target = str(entry.get("id", ""))
			break
	var result: Dictionary = gm.confirm_burn_card(target)
	fails += _check(bool(result.get("ok", false)), "the conjured card can be burned")
	fails += _check(_conjured_in(gm, gm.hand) + _conjured_in(gm, gm.deck)
		+ _conjured_in(gm, gm.graveyard) == 0,
		"the burned conjured card exists nowhere")
	return fails


## How many of `cards` are ability-conjured.
func _conjured_in(gm: Node, cards: Array) -> int:
	var n: int = 0
	for card in cards:
		if gm.is_ephemeral_card(card):
			n += 1
	return n


## Puts the named special into hand and activates it; returns the slot index of
## whatever it left behind.
func _grant(gm: Node, special_id: String) -> int:
	gm.hand[0] = _special(special_id)
	gm.operation_points = 999
	gm.use_special_ability(0)
	return 0


## A fresh copy of the special card definition with the given id.
func _special(special_id: String) -> Dictionary:
	for card_def in GameManager.SPECIAL_CARD_DEFS:
		if str(card_def.get("special_id", "")) == special_id:
			return card_def.duplicate()
	return {}


## Builds the one-card assignment that spends whatever is in hand slot `idx`.
func _spell(gm: Node, idx: int) -> Array:
	var card: Dictionary = gm.hand[idx]
	return [{"type": "hand", "hand_index": idx, "char": _letter_at(gm, idx),
		"card_letter": _letter_at(gm, idx),
		"is_wildcard": bool(card.get("is_wildcard", false)),
		"damage": int(card.get("damage", 1)), "color": str(card.get("color", "red"))}]


## The printed character of hand slot `idx`.
func _letter_at(gm: Node, idx: int) -> String:
	return str(gm.hand[idx].get("letter", ""))


func _total_cards(gm: Node) -> int:
	var n: int = gm.deck.size() + gm.graveyard.size()
	for card in gm.hand:
		if card != null:
			n += 1
	return n


func _burn_index(gm: Node) -> int:
	for i in range(gm.reward_options.size()):
		if str(gm.reward_options[i].get("type", "")) == "remove_card":
			return i
	return -1


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1