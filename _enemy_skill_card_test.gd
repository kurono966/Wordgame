extends Node

# Headless test for the enemy-skill CARD RULES:
#
#   1. SHARED REELS: the ONE letter the enemy bound its skill to is dealt as
#      EXACTLY ONE card across the whole 3x3 board (1 of 9). A letter that
#      repeats in the enemy name must not produce extra skill cards, and the
#      random filler must never add one either.
#   2. PLAYER DECK: no card carrying the skill letter may sit in the deck, the
#      hand or the graveyard — the graveyard counts because it is reshuffled
#      back into the deck when the deck runs dry.
#   3. The rules survive a stage change, where a brand new enemy re-rolls its
#      skill letter against a deck that was built for the previous enemy.
#   4. Reward cards are filtered too, since "add a card" writes into the deck.
#
# The rules are checked over MANY randomly rolled enemies, because the failure
# only shows up for names that repeat a letter (or for a skill letter that
# happens to be common in the pool).

const RUNS: int = 400

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame

	# ===== 1 + 2. A fresh game obeys both rules ==============================
	for _i in range(RUNS):
		gm.reset_game()
		fails += _check_game(gm, "a fresh game")

	# ===== 3. A stage change re-rolls skills against the old deck ============
	# Poison the deck with every letter so a new enemy is guaranteed to find
	# its own skill letters sitting in the player's piles.
	for _i in range(60):
		gm.reset_game()
		for letter in ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M"]:
			gm.deck.append({"letter": letter, "damage": 1, "color": "red"})
			gm.graveyard.append({"letter": letter, "damage": 1, "color": "blue"})
			gm.hand.append({"letter": letter, "damage": 1, "color": "green"})
		gm._advance_stage()
		fails += _check_game(gm, "a stage change")

	# ===== 4. Rewards never hand out a skill card ===========================
	for _i in range(RUNS):
		gm.reset_game()
		for _r in range(12):
			var card: Dictionary = gm._pick_reward_card()
			fails += _check(not gm.is_enemy_skill_letter(str(card.get("letter", ""))),
				"a reward card never carries a skill letter")
			var special: Dictionary = gm._pick_special_reward_card()
			fails += _check(not gm.is_enemy_skill_letter(str(special.get("letter", ""))),
				"a special reward card never carries a skill letter")

	# ===== Sanity: the reels still deal a full 3x3 board ====================
	gm.reset_game()
	var dealt: int = 0
	for s in range(gm.slots.size()):
		dealt += gm.slots[s].size()
	fails += _check(dealt == gm.NUM_SLOTS * gm.CARDS_PER_SLOT,
		"the reels still deal %d cards (%d)" % [gm.NUM_SLOTS * gm.CARDS_PER_SLOT, dealt])

	# ===== Sanity: the deck is still DECK_SIZE ==============================
	# reset_game() deals HAND_SIZE cards straight into hand, so the draw pile
	# holds the remainder. Together the two must still total DECK_SIZE.
	gm.reset_game()
	fails += _check(gm.deck.size() + gm.hand.size() == gm.DECK_SIZE,
		"deck + hand is still %d cards (%d + %d)" % [gm.DECK_SIZE, gm.deck.size(), gm.hand.size()])
	fails += _check(gm.hand.size() == gm.HAND_SIZE,
		"the hand is still %d cards (%d)" % [gm.HAND_SIZE, gm.hand.size()])

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## Both rules for one freshly-rolled game state.
func _check_game(gm, label: String) -> int:
	var fails: int = 0
	var skill_letters: Dictionary = gm._enemy_skill_letters()

	# Rule 1: exactly one card per skill letter across the whole 3x3 board.
	for letter in skill_letters:
		var seen: int = 0
		for s in range(gm.slots.size()):
			for card in gm.slots[s]:
				if str(card.get("letter", "")) == letter:
					seen += 1
		fails += _check(seen == 1,
			"%s: skill letter \"%s\" is dealt exactly once on the reels (found %d)" % [
				label, letter, seen])

	# Rule 2: nowhere in the player's own piles.
	for pile_name in ["deck", "hand", "graveyard"]:
		var pile: Array = gm.get(pile_name)
		for card in pile:
			if card == null:
				continue
			var letter: String = str(card.get("letter", ""))
			fails += _check(not skill_letters.has(letter),
				"%s: %s holds no skill letter (found \"%s\")" % [label, pile_name, letter])
	return fails


func _check(ok: bool, label: String) -> int:
	if not ok:
		printerr("  FAIL - ", label)
		return 1
	return 0
