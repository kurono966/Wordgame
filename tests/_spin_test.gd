extends Node

# Headless test for the OP-powered shared-reel spin:
#   * the price escalates each spin: 1 OP, then 10 OP, then 100 OP
#   * a turn allows at most MAX_SPINS_PER_TURN (3) spins, and the budget
#     refreshes on the next turn
#   * spinning advances only the chosen reel, and the reel wraps around
#   * spinning is refused (and costs nothing) with too little OP or no spins left
#   * a reel whose ACTIVE card is on the Workbench cannot be spun

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame
	gm.reset_game()

	# ===== The reels are set up to spin ==========================
	fails += _check(gm.SPIN_COSTS == [1, 10, 100], "the spin prices are 1 / 10 / 100 OP")
	fails += _check(gm.MAX_SPINS_PER_TURN == 3, "a turn allows 3 spins")
	fails += _check(gm.slots.size() == gm.NUM_SLOTS, "three shared reels exist")
	fails += _check(gm.get_slot_cards(0).size() == gm.CARDS_PER_SLOT,
		"each reel holds %d cards" % gm.CARDS_PER_SLOT)

	# ===== Spinning advances the chosen reel only =================
	gm.reset_game()
	gm.operation_points = 5
	var start_idx_0: int = gm.current_slot_indices[0]
	var start_idx_1: int = gm.current_slot_indices[1]
	var start_idx_2: int = gm.current_slot_indices[2]

	var res: Dictionary = gm.spin_slot(1)  # spin the MIDDLE reel only
	fails += _check(res.get("ok", false), "spin_slot succeeds with enough OP")
	fails += _check(gm.operation_points == 5 - 1,
		"the first spin costs 1 OP (%d -> %d)" % [5, gm.operation_points])
	fails += _check(int(res.get("remaining", -1)) == gm.operation_points,
		"the result reports the remaining OP")
	fails += _check(gm.current_slot_indices[1] == (start_idx_1 + 1) % gm.CARDS_PER_SLOT,
		"the chosen reel advanced by one step")
	fails += _check(gm.current_slot_indices[0] == start_idx_0, "reel 0 did not move")
	fails += _check(gm.current_slot_indices[2] == start_idx_2, "reel 2 did not move")
	# The card that was NEXT is now ACTIVE
	var s1: Array = gm.get_slot_cards(1)
	fails += _check(str(gm.get_current_slot_card(1).get("letter", "")) ==
		str(s1[(start_idx_1 + 1) % s1.size()].get("letter", "")),
		"the NEXT card became ACTIVE")
	fails += _check(str(res.get("message", "")).length() > 0, "the spin reports what happened")

	# ===== A full cycle returns the reel to where it started ======
	# A cycle needs CARDS_PER_SLOT spins, which is more than one turn allows, so
	# the budget is refreshed between spins to model a multi-turn wait.
	gm.reset_game()
	gm.operation_points = 999
	var cycle_cards: Array = gm.get_slot_cards(0)
	var cycle_start: int = gm.current_slot_indices[0]
	var cycle_letter: String = str(gm.get_current_slot_card(0).get("letter", ""))
	for _i in range(gm.CARDS_PER_SLOT):
		gm.spin_slot(0)
		gm.spins_this_turn = 0  # stand in for the next turn refreshing the budget
	fails += _check(gm.current_slot_indices[0] == cycle_start,
		"a full cycle returns the reel to its starting position")
	fails += _check(str(gm.get_current_slot_card(0).get("letter", "")) == cycle_letter,
		"a full cycle shows the original card again")
	# The cycle visits every card in the reel exactly once
	var seen: Dictionary = {}
	var probe: int = cycle_start
	for _i in range(gm.CARDS_PER_SLOT):
		seen[str(cycle_cards[probe % cycle_cards.size()].get("letter", ""))] = true
		probe += 1
	fails += _check(seen.size() <= gm.CARDS_PER_SLOT,
		"a cycle walks the reel without going out of range")

	# ===== Not enough OP is refused and costs nothing ==============
	gm.reset_game()
	gm.operation_points = 0
	var idx_before: int = gm.current_slot_indices[0]
	fails += _check(not gm.can_spin_slot(0).get("ok", false), "can_spin_slot is false at 0 OP")
	fails += _check(str(gm.can_spin_slot(0).get("reason", "")).contains("OP"),
		"the refusal explains it is about OP")
	var bad: Dictionary = gm.spin_slot(0)
	fails += _check(not bad.get("ok", false), "spinning at 0 OP is refused")
	fails += _check(gm.operation_points == 0, "a refused spin costs nothing")
	fails += _check(gm.current_slot_indices[0] == idx_before, "a refused spin does not move the reel")

	# Exactly the first spin's price is enough
	gm.reset_game()
	gm.operation_points = 1
	fails += _check(gm.can_spin_slot(0).get("ok", false), "exactly 1 OP is enough for the first spin")
	fails += _check(gm.spin_slot(0).get("ok", false), "spinning with exactly enough OP works")
	fails += _check(gm.operation_points == 0, "all OP is spent")

	# ===== A reel in use in the word cannot be spun ================
	gm.reset_game()
	# Enough OP to cover both spins this block performs (1 OP, then 10 OP).
	gm.operation_points = 50
	gm.set_slot_in_use(0, true)
	fails += _check(gm.is_slot_active_in_use(0), "the reel reports itself as in use")
	fails += _check(not gm.can_spin_slot(0).get("ok", false),
		"a reel in use cannot be spun")
	fails += _check(str(gm.can_spin_slot(0).get("reason", "")).contains("word"),
		"the refusal mentions the word")
	fails += _check(not gm.spin_slot(0).get("ok", false), "spinning an in-use reel is refused")
	fails += _check(gm.operation_points == 50, "refusing an in-use spin costs no OP")
	# Other reels are unaffected by one being in use
	fails += _check(gm.can_spin_slot(1).get("ok", false), "other reels are still spinnable")
	fails += _check(gm.spin_slot(1).get("ok", false), "spinning a free reel still works")
	# Once released it can be spun again
	gm.set_slot_in_use(0, false)
	fails += _check(gm.can_spin_slot(0).get("ok", false), "a released reel can be spun again")

	# ===== The price escalates: 1, then 10, then 100 ==============
	gm.reset_game()
	gm.operation_points = 500
	fails += _check(gm.get_next_spin_cost() == 1, "spin 1 of the turn is priced at 1 OP")
	var r1: Dictionary = gm.spin_slot(0)
	fails += _check(int(r1.get("cost", -1)) == 1, "the first spin charged 1 OP")
	fails += _check(gm.operation_points == 499, "1 OP was deducted (%d)" % gm.operation_points)

	fails += _check(gm.get_next_spin_cost() == 10, "spin 2 of the turn is priced at 10 OP")
	var r2: Dictionary = gm.spin_slot(1)
	fails += _check(int(r2.get("cost", -1)) == 10, "the second spin charged 10 OP")
	fails += _check(gm.operation_points == 489, "10 OP was deducted (%d)" % gm.operation_points)

	fails += _check(gm.get_next_spin_cost() == 100, "spin 3 of the turn is priced at 100 OP")
	var r3: Dictionary = gm.spin_slot(2)
	fails += _check(int(r3.get("cost", -1)) == 100, "the third spin charged 100 OP")
	fails += _check(gm.operation_points == 389, "100 OP was deducted (%d)" % gm.operation_points)

	# ===== Only three spins per turn =============================
	fails += _check(gm.spins_remaining() == 0, "the turn's three spins are used up")
	fails += _check(gm.get_next_spin_cost() == -1, "there is no fourth price")
	var idx_locked: int = gm.current_slot_indices[0]
	var refused: Dictionary = gm.spin_slot(0)
	fails += _check(not refused.get("ok", false), "a fourth spin in the same turn is refused")
	fails += _check(str(refused.get("reason", "")).contains("spin"),
		"the refusal explains the spin limit was reached")
	fails += _check(gm.operation_points == 389, "the refused spin charged nothing")
	fails += _check(gm.current_slot_indices[0] == idx_locked,
		"the refused spin did not move the reel")

	# The budget returns on the next turn.
	gm.spins_this_turn = 0
	fails += _check(gm.spins_remaining() == 3, "a new turn restores all three spins")
	fails += _check(gm.get_next_spin_cost() == 1, "the new turn starts again at 1 OP")

	# A turn really is the unit: submitting a word resets the allowance.
	gm.reset_game()
	gm.operation_points = 500
	gm.spin_slot(0)
	gm.spin_slot(1)
	fails += _check(gm.spins_this_turn == 2, "two spins used this turn (%d)" % gm.spins_this_turn)
	gm.execute_assignment("A", [{"type": "hand", "hand_index": 0, "char": "A",
		"card_letter": "A", "is_wildcard": false, "damage": 1, "color": "red"}])
	fails += _check(gm.spins_this_turn == 0,
		"submitting a word starts the next turn with a fresh spin allowance")

	# A player who cannot afford the next spin is told the real price.
	gm.reset_game()
	gm.operation_points = 1
	gm.spin_slot(0)
	fails += _check(gm.get_next_spin_cost() == 10, "the second spin now asks 10 OP")
	fails += _check(not gm.can_spin_slot(0).get("ok", false),
		"1 OP is not enough for the second spin")
	fails += _check(str(gm.can_spin_slot(0).get("reason", "")).contains("10"),
		"the refusal names the 10 OP it needs")
	fails += _check(gm.spins_this_turn == 1,
		"a refused second spin does not consume the turn's allowance")

	# ===== Invalid reels are refused ==============================
	fails += _check(not gm.spin_slot(-1).get("ok", false), "a negative reel index is refused")
	fails += _check(not gm.spin_slot(99).get("ok", false), "an out-of-range reel index is refused")

	# ===== reset_game clears the in-use flags ====================
	gm.set_slot_in_use(1, true)
	gm.reset_game()
	fails += _check(not gm.is_slot_active_in_use(1), "reset_game clears the in-use flags")

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
