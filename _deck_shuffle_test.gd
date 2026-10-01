extends Node

# Headless test for draw-pile randomness.
#
# The starting deck is a FIXED SET of 20 cards, but its ORDER must be random:
#
#   1. THE STARTING DECK IS SHUFFLED — reset_game() shuffles before it deals the
#      opening hand. Drawing pops from the BACK of the deck, so without the
#      shuffle the same seven cards were the opening hand of every single game.
#   2. THE GRAVEYARD RECYCLE IS SHUFFLED — when the draw pile runs dry, the spent
#      pile is moved back and shuffled, so the second pass is random too.
#
# In both cases the SET of cards must be untouched: a shuffle reorders, it never
# adds, drops or duplicates a card.

const TRIALS: int = 20

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame

	fails += _check_opening_hand_varies(gm)
	fails += _check_deck_order_varies(gm)
	fails += _check_deck_set_is_fixed(gm)
	fails += _check_graveyard_recycle_is_random(gm)
	fails += _check_graveyard_recycle_keeps_the_set(gm)
	fails += _check_drawing_drains_then_recycles(gm)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## 1. A fresh game must not deal the same hand every time.
func _check_opening_hand_varies(gm: Node) -> int:
	var hands: Dictionary = {}
	for _t in range(TRIALS):
		gm.reset_game()
		hands[_order(gm.hand)] = true
	return _check(hands.size() >= 5,
		"the opening hand varies between games (%d distinct hands in %d games)"
			% [hands.size(), TRIALS])


## 2. The draw pile itself must not come out in a fixed order.
func _check_deck_order_varies(gm: Node) -> int:
	var orders: Dictionary = {}
	for _t in range(TRIALS):
		gm.reset_game()
		orders[_order(gm.deck)] = true
	return _check(orders.size() >= 5,
		"the starting deck order varies between games (%d distinct orders in %d games)"
			% [orders.size(), TRIALS])


## 3. Shuffling reorders only: the same 20 cards, every time.
func _check_deck_set_is_fixed(gm: Node) -> int:
	var expected: String = _key(_all_starting_cards(gm))
	for _t in range(TRIALS):
		gm.reset_game()
		var combined: Array = gm.deck.duplicate()
		combined.append_array(gm.hand)
		if _key(combined) != expected:
			return _check(false,
				"the 20 starting cards are identical every game (run %d differs)" % _t)
	return _check(true,
		"the starting deck is still the same fixed set of 20 cards")


## 4. Recycling the spent pile back into an empty draw pile must shuffle.
func _check_graveyard_recycle_is_random(gm: Node) -> int:
	var letters: Array = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
	var orders: Dictionary = {}
	for _t in range(TRIALS):
		gm.deck = []
		gm.graveyard = []
		for letter in letters:
			gm.graveyard.append({"letter": letter, "damage": 1, "color": "red"})
		gm._reshuffle_graveyard()
		orders[_order(gm.deck)] = true
	return _check(orders.size() >= 5,
		"recycling the graveyard shuffles it (%d distinct orders in %d recycles)"
			% [orders.size(), TRIALS])


## 5. And that recycle keeps every card exactly once.
func _check_graveyard_recycle_keeps_the_set(gm: Node) -> int:
	var letters: Array = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
	gm.deck = []
	gm.graveyard = []
	for letter in letters:
		gm.graveyard.append({"letter": letter, "damage": 1, "color": "red"})
	gm._reshuffle_graveyard()
	var fails: int = 0
	fails += _check(gm.graveyard.is_empty(), "the graveyard is emptied by the recycle")
	fails += _check(gm.deck.size() == letters.size(),
		"every card moved back into the draw pile (%d of %d)"
			% [gm.deck.size(), letters.size()])
	var seen: Dictionary = {}
	for card in gm.deck:
		seen[str(card.get("letter", ""))] = true
	fails += _check(seen.size() == letters.size(),
		"no card was lost or duplicated by the recycle (%d unique)" % seen.size())
	return fails


## 6. An empty pile with cards in the graveyard recycles instead of failing,
##    and a genuinely empty game still returns the fallback without crashing.
func _check_drawing_drains_then_recycles(gm: Node) -> int:
	var fails: int = 0
	var marker: Dictionary = {"letter": "Z", "damage": 99, "color": "red"}

	gm.deck = []
	gm.graveyard = [marker]
	var got: Dictionary = gm._draw_card()
	fails += _check(str(got.get("letter", "")) == "Z",
		"drawing from an empty pile recycles the graveyard")
	fails += _check(gm.graveyard.is_empty(), "the graveyard was consumed by the draw")

	gm.deck = []
	gm.graveyard = []
	var fallback: Dictionary = gm._draw_card()
	fails += _check(fallback.has("letter"),
		"a completely empty game still returns a usable fallback card")
	return fails


## Order-independent signature of a list of cards (a SET comparison).
func _key(cards: Array) -> String:
	var parts: Array = []
	for card in cards:
		if card == null:
			parts.append("-")
		else:
			parts.append("%s:%s" % [str(card.get("letter", "?")), str(card.get("color", "?"))])
	parts.sort()
	return "|".join(parts)


## Order-DEPENDENT signature: two lists differ as soon as one card swaps places.
func _order(cards: Array) -> String:
	var parts: Array = []
	for card in cards:
		if card == null:
			parts.append("-")
		else:
			parts.append("%s:%s" % [str(card.get("letter", "?")), str(card.get("color", "?"))])
	return "|".join(parts)


## The declared starting set, straight from the constant (not the live pile).
func _all_starting_cards(gm: Node) -> Array:
	var out: Array = []
	for card_def in GameManager.STARTING_DECK:
		out.append(card_def.duplicate())
	return out


func _hand_count(gm: Node) -> int:
	var n: int = 0
	for card in gm.hand:
		if card != null:
			n += 1
	return n


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1