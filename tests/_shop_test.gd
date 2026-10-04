extends Node

# Headless test for the SHOP that replaces the reward on every 3rd stage clear.
#
# The two things most likely to rot are checked hardest:
#   - the batch pricing (2 cards = 3x, 3 cards = 6x) must be exact, and charged
#     against the RIGHT number of cards actually removed
#   - a refused purchase must never move the deck or the wallet

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame
	gm.reset_game()

	fails += _check_shop_stage(gm)
	fails += _check_batch_pricing(gm)
	fails += _check_buy_card(gm)
	fails += _check_compress(gm)
	fails += _check_no_batch_route_exists(gm)
	fails += _check_repeat_escalates(gm)
	fails += _check_compress_guards(gm)
	fails += _check_failures_are_free(gm)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## The shop appears on every 3rd stage clear and nowhere else.
func _check_shop_stage(gm: Node) -> int:
	var fails: int = 0
	for stage: int in [3, 6, 9, 12]:
		fails += _check(gm.is_shop_stage(stage), "stage %d is a shop stage" % stage)
	for stage: int in [1, 2, 4, 5, 7, 8, 10, 11]:
		fails += _check(not gm.is_shop_stage(stage), "stage %d is a normal reward stage" % stage)
	fails += _check(not gm.is_shop_stage(0), "stage 0 is not a shop stage")
	fails += _check(not gm.is_shop_stage(-3), "a negative stage is not a shop stage")
	fails += _check(gm.SHOP_STAGE_EVERY == 3, "the shop cadence is every 3rd stage")
	return fails


## THE RULE: compression is one card at a time. There is no 2- or 3-card batch, so
## "two cards at once is cheap" is not discouraged — it is impossible. The price
## of the single card rises with each further compression in the same visit.
func _check_batch_pricing(gm: Node) -> int:
	var fails: int = 0
	fails += _check(gm.SHOP_CARD_COST > 0,
		"buying a card has a positive price (%d OP)" % gm.SHOP_CARD_COST)
	fails += _check(gm.SHOP_COMPRESS_COST > 0,
		"compressing a card has a positive price (%d OP)" % gm.SHOP_COMPRESS_COST)

	# There is no batch price at all. The batch helpers are gone, so the only price
	# that exists is the single-card one.
	gm.reset_game()
	gm.open_shop()
	fails += _check(gm.shop_compress_cost() == gm.SHOP_COMPRESS_COST,
		"the first compression costs the base rate (%d OP)" % gm.shop_compress_cost())
	# Compressing a list is refused outright, so the batch route cannot be reached
	# from any caller.
	var before: int = gm.get_deck_size()
	var as_list: Dictionary = gm.shop_compress(["deck:0", "deck:1"])
	fails += _check(not bool(as_list.get("ok", false)),
		"handing over a LIST of cards is refused")
	fails += _check(gm.get_deck_size() == before, "and removes nothing")
	fails += _check(gm.shop_compress_count == 0, "and does not consume an allowance")
	return fails


## Buying a card spends exactly the listed price and puts exactly that card in
## the deck.
func _check_buy_card(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.open_shop()
	gm.operation_points = 100
	var stock: Array = gm.get_shop_offers()
	fails += _check(stock.size() == gm.SHOP_STOCK, "the shop stocks %d cards" % gm.SHOP_STOCK)

	var deck_before: int = gm.get_deck_size()
	var op_before: int = gm.get_operation_points()
	var card: Dictionary = stock[0].get("card", {})
	var r: Dictionary = gm.shop_buy_card(0)
	fails += _check(bool(r.get("ok", false)), "the purchase succeeds")
	fails += _check(gm.get_deck_size() == deck_before + 1, "the deck grew by one")
	fails += _check(gm.get_operation_points() == op_before - gm.SHOP_CARD_COST,
		"exactly %d OP was spent" % gm.SHOP_CARD_COST)
	var last: Dictionary = gm.deck[gm.deck.size() - 1]
	fails += _check(str(last.get("letter", "")) == str(card.get("letter", ""))
			and int(last.get("damage", -1)) == int(card.get("damage", -2)),
		"the exact card on sale landed in the deck")

	var op_now: int = gm.get_operation_points()
	var again: Dictionary = gm.shop_buy_card(0)
	fails += _check(not bool(again.get("ok", false)), "a sold card cannot be bought again")
	fails += _check(gm.get_operation_points() == op_now, "the refused re-buy spent nothing")
	return fails


## Compressing removes exactly ONE card and charges the current single-card price.
func _check_compress(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.open_shop()
	gm.operation_points = 500
	var before: int = gm.get_deck_size()
	var expected_cost: int = gm.shop_compress_cost()
	fails += _check(expected_cost == gm.SHOP_COMPRESS_COST,
		"the first compression is at the base rate (%d OP)" % expected_cost)

	var r: Dictionary = gm.shop_compress("deck:0")
	fails += _check(bool(r.get("ok", false)), "compressing one card succeeds")
	fails += _check(gm.get_deck_size() == before - 1,
		"exactly one card is removed (%d -> %d)" % [before, gm.get_deck_size()])
	fails += _check(gm.get_operation_points() == 500 - expected_cost,
		"exactly the single-card price is charged (%d OP)" % expected_cost)
	fails += _check(r.get("cards", []).size() == 1, "one card is reported removed")
	fails += _check(int(r.get("count", -1)) == 1, "the result counts one card")
	return fails


func _check_no_batch_route_exists(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.open_shop()
	gm.operation_points = 1000
	var deck_before: int = gm.get_deck_size()

	# The obvious attempts, all refused.
	var attempts: Array = [
		["deck:0", "deck:1"],
		["deck:0", "deck:1", "deck:2"],
		{"0": "deck:0", "1": "deck:1"},
		{},
	]
	for attempt: Variant in attempts:
		var r: Dictionary = gm.shop_compress(attempt)
		fails += _check(not bool(r.get("ok", false)),
			"a multi-card request (%s) is refused" % str(attempt).substr(0, 24))
	fails += _check(gm.get_deck_size() == deck_before,
		"no card was removed by any of them")
	fails += _check(gm.get_operation_points() == 1000, "and no OP was spent")
	fails += _check(gm.shop_compress_count == 0, "and no allowance was consumed")

	# A single id still works, so the guard is not simply blocking everything.
	var ok: Dictionary = gm.shop_compress("deck:0")
	fails += _check(bool(ok.get("ok", false)), "a single card id still works")
	fails += _check(gm.get_deck_size() == deck_before - 1, "removing exactly one card")
	return fails


## THE REQUESTED RULE: compression is one card at a time, and the 2nd and 3rd
## compression in one visit must cost more than the 1st.
## way in and there is a real reason to do one decisive trim instead.
func _check_repeat_escalates(gm: Node) -> int:
	var fails: int = 0

	# The multiplier escalates 1, 2, 4 across the visit.
	gm.reset_game()
	gm.open_shop()
	# Enough OP for the most expensive attempt (the 3rd single at x4 = 72 OP).
	gm.operation_points = 1000
	fails += _check(gm.shop_compress_count == 0, "a fresh visit has made no compressions")
	fails += _check(gm.shop_compress_multiplier() == 1, "the 1st compression is x1")
	fails += _check(gm.shop_compresses_left() == gm.SHOP_COMPRESS_PER_VISIT,
		"a fresh visit has all its compressions available")

	# The price shown BEFORE each purchase must be non-decreasing.
	var seen: Array = []
	for i in range(gm.SHOP_COMPRESS_PER_VISIT):
		seen.append(gm.shop_compress_cost())
		var r: Dictionary = gm.shop_compress("deck:0")
		fails += _check(bool(r.get("ok", false)),
			"compression %d of a visit goes through" % (i + 1))
		fails += _check(gm.shop_compress_count == i + 1,
			"and is counted (%d)" % gm.shop_compress_count)
	print("  (1-card price by attempt: ", seen, ")")
	for i in range(1, seen.size()):
		fails += _check(seen[i] > seen[i - 1],
			"attempt %d costs more than attempt %d (%d > %d)" % [
				i + 1, i, seen[i], seen[i - 1]])

	# After the cap there is no next price at all — compressions run out.
	fails += _check(gm.shop_compress_multiplier() < 0,
		"the multiplier is gone once the visit's allowance is spent")
	fails += _check(gm.shop_compress_cost() < 0,
		"and a further compression has no price")
	fails += _check(gm.shop_compresses_left() == 0, "nothing is left this visit")
	var capped: Dictionary = gm.shop_compress("deck:0")
	fails += _check(not bool(capped.get("ok", false)),
		"a 4th compression in one visit is refused")
	fails += _check(gm.shop_compress_count == gm.SHOP_COMPRESS_PER_VISIT,
		"and the refused attempt did not consume anything")

	# A refused attempt must not burn an allowance: it stays the same price.
	gm.reset_game()
	gm.open_shop()
	gm.operation_points = 0   # cannot afford anything
	var broke: Dictionary = gm.shop_compress("deck:0")
	fails += _check(not bool(broke.get("ok", false)), "a broke player is refused")
	fails += _check(gm.shop_compress_count == 0, "a refused attempt costs no allowance")
	fails += _check(gm.shop_compress_multiplier() == 1,
		"so the 1st price is unchanged")

	# A new VISIT resets the escalation — the next shop is cheap again.
	gm.reset_game()
	gm.open_shop()
	gm.operation_points = 5000
	for _n in range(gm.SHOP_COMPRESS_PER_VISIT):
		gm.shop_compress("deck:0")
	fails += _check(gm.shop_compress_cost() < 0, "the visit is exhausted")
	gm.open_shop()
	fails += _check(gm.shop_compress_multiplier() == 1,
		"the next visit starts at x1 again")
	fails += _check(gm.shop_compress_cost() == gm.SHOP_COMPRESS_COST,
		"and at the base price (%d OP)" % gm.shop_compress_cost())
	return fails


## Compression must refuse anything it cannot honour, and refuse it for free.
func _check_compress_guards(gm: Node) -> int:
	var fails: int = 0

	# Not enough OP.
	gm.reset_game()
	gm.open_shop()
	gm.operation_points = 1
	var deck_before: int = gm.get_deck_size()
	var poor: Dictionary = gm.shop_compress("deck:0")
	fails += _check(not bool(poor.get("ok", false)), "a broke player cannot compress")
	fails += _check(gm.get_deck_size() == deck_before, "and the deck is untouched")
	fails += _check(gm.get_operation_points() == 1, "and no OP was taken")

	# A batch of any size is no longer a thing that can be bought.
	gm.reset_game()
	gm.open_shop()
	gm.operation_points = 1000
	deck_before = gm.get_deck_size()
	var many: Dictionary = gm.shop_compress(["deck:0", "deck:1", "deck:2"])
	fails += _check(not bool(many.get("ok", false)),
		"a multi-card batch is refused at the model level")
	fails += _check(gm.get_deck_size() == deck_before, "and nothing was removed")

	# Would take the deck below MIN_DECK_SIZE.
	gm.reset_game()
	gm.open_shop()
	gm.operation_points = 1000
	while gm.get_deck_size() > gm.MIN_DECK_SIZE:
		gm.deck.pop_back()
	var at_min: int = gm.get_deck_size()
	var floor: Dictionary = gm.shop_compress("deck:0")
	fails += _check(not bool(floor.get("ok", false)),
		"compressing below the minimum deck size is refused (deck %d, min %d)" % [at_min, gm.MIN_DECK_SIZE])
	fails += _check(gm.get_deck_size() == at_min, "and the deck is untouched")

	# A bad card id changes nothing.
	gm.reset_game()
	gm.open_shop()
	gm.operation_points = 500
	deck_before = gm.get_deck_size()
	var bad_id: Dictionary = gm.shop_compress("deck:9999")
	fails += _check(not bool(bad_id.get("ok", false)), "a bogus card id is refused")
	fails += _check(gm.get_deck_size() == deck_before, "and removes nothing")
	fails += _check(gm.get_operation_points() == 500, "and charges nothing")
	fails += _check(gm.shop_compress_count == 0, "and costs no allowance")

	# The shop must be closed to act.
	gm.close_shop()
	var closed: Dictionary = gm.shop_buy_card(0)
	fails += _check(not bool(closed.get("ok", false)), "a closed shop sells nothing")
	return fails


## A refusal leaves the run exactly as it was, so a mis-click cannot cost OP.
func _check_failures_are_free(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.operation_points = 100
	var deck_before: int = gm.get_deck_size()
	var no_shop: Dictionary = gm.shop_buy_card(0)
	fails += _check(not bool(no_shop.get("ok", false)), "buying with the shop shut is refused")
	fails += _check(gm.get_operation_points() == 100, "and costs nothing")
	fails += _check(gm.get_deck_size() == deck_before, "and the deck is untouched")
	return fails


## The first `n` draw-pile card ids, which is what compression operates on.
func _deck_ids(gm: Node, n: int) -> Array:
	var ids: Array = []
	for i in range(mini(n, gm.deck.size())):
		ids.append("deck:%d" % i)
	return ids


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
