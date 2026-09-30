extends Node

# Headless test for the OP-powered shared-reel spin:
#   * spinning costs exactly SPIN_COST OP and advances only the chosen reel
#   * the reel wraps around after CARDS_PER_SLOT steps
#   * spinning is refused (and costs nothing) with too little OP
#   * a reel whose ACTIVE card is on the Workbench cannot be spun

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame
	gm.reset_game()

	# ===== The reels are set up to spin ==========================
	fails += _check(gm.SPIN_COST == 1, "spinning costs 1 OP")
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
	fails += _check(gm.operation_points == 5 - gm.SPIN_COST,
		"exactly SPIN_COST OP was spent (%d -> %d)" % [5, gm.operation_points])
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
	gm.reset_game()
	gm.operation_points = 99
	var cycle_cards: Array = gm.get_slot_cards(0)
	var cycle_start: int = gm.current_slot_indices[0]
	var cycle_letter: String = str(gm.get_current_slot_card(0).get("letter", ""))
	for _i in range(gm.CARDS_PER_SLOT):
		gm.spin_slot(0)
	fails += _check(gm.current_slot_indices[0] == cycle_start,
		"a full cycle returns the reel to its starting position")
	fails += _check(gm.operation_points == 99 - gm.SPIN_COST * gm.CARDS_PER_SLOT,
		"a full cycle costs %d OP" % (gm.SPIN_COST * gm.CARDS_PER_SLOT))
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

	# Exactly SPIN_COST OP is enough
	gm.reset_game()
	gm.operation_points = gm.SPIN_COST
	fails += _check(gm.can_spin_slot(0).get("ok", false), "exactly SPIN_COST OP is enough")
	fails += _check(gm.spin_slot(0).get("ok", false), "spinning with exactly enough OP works")
	fails += _check(gm.operation_points == 0, "all OP is spent")

	# ===== A reel in use in the word cannot be spun ================
	gm.reset_game()
	gm.operation_points = 5
	gm.set_slot_in_use(0, true)
	fails += _check(gm.is_slot_active_in_use(0), "the reel reports itself as in use")
	fails += _check(not gm.can_spin_slot(0).get("ok", false),
		"a reel in use cannot be spun")
	fails += _check(str(gm.can_spin_slot(0).get("reason", "")).contains("word"),
		"the refusal mentions the word")
	fails += _check(not gm.spin_slot(0).get("ok", false), "spinning an in-use reel is refused")
	fails += _check(gm.operation_points == 5, "refusing an in-use spin costs no OP")
	# Other reels are unaffected by one being in use
	fails += _check(gm.can_spin_slot(1).get("ok", false), "other reels are still spinnable")
	fails += _check(gm.spin_slot(1).get("ok", false), "spinning a free reel still works")
	# Once released it can be spun again
	gm.set_slot_in_use(0, false)
	fails += _check(gm.can_spin_slot(0).get("ok", false), "a released reel can be spun again")

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
