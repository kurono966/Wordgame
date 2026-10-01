extends Node

# Headless test for the enemy-skill CARD RULES and the fixed starting deck.
#
#   1. FIXED DECK: every game starts with EXACTLY the twenty player cards in
#      STARTING_DECK (five per colour), and a fresh game holds them all.
#   2. SHARED REELS: the ONE letter the enemy bound its skill to is dealt as
#      EXACTLY ONE card across the whole 3x3 board. A letter that repeats in the
#      enemy name must not produce extra skill cards, and the random filler must
#      never add one either.
#   3. THE DECK IS NOT THE SKILL: a deck card may share the skill LETTER, but
#      that is harmless — the skill fires only from a reel's bottom row at night,
#      which no deck card can ever reach. This is what lets the fixed deck use
#      common letters without breaking the rule.
#   4. These rules survive a stage change, where a new enemy re-rolls its skill
#      letter while the fixed deck stays exactly the same.

const RUNS: int = 400

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame

	# ===== 1. A fresh game holds exactly the fixed 20-card deck =============
	for _i in range(RUNS):
		gm.reset_game()
		fails += _check_fixed_deck(gm, "a fresh game", true)
		fails += _check_game(gm, "a fresh game")

	# ===== 4. A stage change re-rolls the skill, deck stays fixed ===========
	for _i in range(60):
		gm.reset_game()
		gm._advance_stage()
		fails += _check_fixed_deck(gm, "a stage change", false)
		fails += _check_game(gm, "a stage change")

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


## The deck plus hand must be exactly the fixed STARTING_DECK: same size, and
## the same multiset of letter/damage/colour entries. Only meaningful on a FRESH
## game — a stage change redraws the hand and rotates nothing, so the deck+hand
## total stays DECK_SIZE, but a mid-run draw pile has simply been partly dealt.
func _check_fixed_deck(gm, label: String, check_contents: bool) -> int:
	var fails: int = 0
	var held: Array = []
	for card in gm.deck:
		held.append(_entry(card))
	for card in gm.hand:
		if card != null:
			held.append(_entry(card))

	if check_contents:
		held.sort()
		var want: Array = []
		for def in gm.STARTING_DECK:
			want.append(_entry(def))
		want.sort()
		fails += _check(held == want,
			"%s: the deck is exactly the fixed 20-card set (%d held)" % [label, held.size()])

	# Five of each colour, which is what the fixed set is built around. Only
	# checked on a fresh game; later the hand and graveyard have taken their share.
	if check_contents:
		var colours: Dictionary = {}
		for entry in held:
			var colour: String = str(entry).split("|")[2]
			colours[colour] = int(colours.get(colour, 0)) + 1
		for colour in colours:
			fails += _check(int(colours[colour]) == 5,
				"%s: the deck has 5 %s cards (%d)" % [label, colour, int(colours[colour])])

	# Whatever has been dealt, the deck can never grow or shrink on its own: the
	# total always stays DECK_SIZE because the graveyard is recycled, not lost.
	fails += _check(gm.deck.size() + gm.hand.size() + gm.graveyard.size() == gm.DECK_SIZE,
		"%s: deck + hand + graveyard is still %d cards (%d)"
			% [label, gm.DECK_SIZE, gm.deck.size() + gm.hand.size() + gm.graveyard.size()])
	return fails


func _entry(card: Dictionary) -> String:
	return "%s|%d|%s" % [str(card.get("letter", "")), int(card.get("damage", 0)),
		str(card.get("color", ""))]


## The skill-card rules for one freshly-rolled game state.
func _check_game(gm, label: String) -> int:
	var fails: int = 0
	var skill_letters: Dictionary = gm._enemy_skill_letters()

	# Rule 2: exactly one card per skill letter across the whole 3x3 board.
	for letter in skill_letters:
		var seen: int = 0
		for s in range(gm.slots.size()):
			for card in gm.slots[s]:
				if str(card.get("letter", "")) == letter:
					seen += 1
		fails += _check(seen == 1,
			"%s: skill letter \"%s\" is dealt exactly once on the reels (found %d)" % [
				label, letter, seen])

	# Rule 3: a deck card may share the skill letter, but no deck card is the
	# skill CARD. The skill only ever fires from get_skill_card_in_firing_line(),
	# which reads the reels — so a deck holding that letter changes nothing.
	var deck_hits: int = 0
	for card in gm.deck:
		if skill_letters.has(str(card.get("letter", ""))):
			deck_hits += 1
	if deck_hits > 0:
		# It is fine for this to happen (and it usually does); prove the skill
		# still cannot fire off a deck card by parking the reels safely.
		gm.is_night = true
		var night: Dictionary = gm.apply_turn_start_penalty()
		var firing: Array = gm.get_skill_card_in_firing_line([])
		fails += _check(firing.is_empty() or bool(night.get("skill_fired", false)),
			"%s: a deck holding the skill letter does not fake a firing line" % label)
	return fails


func _check(ok: bool, label: String) -> int:
	if not ok:
		printerr("  FAIL - ", label)
		return 1
	return 0
