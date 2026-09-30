extends Node

# Headless test for the pre-submit damage preview.
#
# The critical property: the preview must account for the shared reels rotating
# as part of submitting, so it has to agree with what the game REALLY does
# (execute_assignment + apply_turn_start_penalty) in every phase/shield state.

# A fixed board: slot s = cards at reel positions 0,1,2.
#   slot 0: 4, 7, 9    slot 1: 3, 2, 1    slot 2: 5, 8, 6
const BOARD: Array = [
	[{"letter": "A", "damage": 4, "color": "red"},
	 {"letter": "B", "damage": 7, "color": "red"},
	 {"letter": "C", "damage": 9, "color": "red"}],
	[{"letter": "D", "damage": 3, "color": "red"},
	 {"letter": "E", "damage": 2, "color": "red"},
	 {"letter": "F", "damage": 1, "color": "red"}],
	[{"letter": "G", "damage": 5, "color": "red"},
	 {"letter": "H", "damage": 8, "color": "red"},
	 {"letter": "I", "damage": 6, "color": "red"}]
]

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame
	_setup(gm, false, 0, gm.PLAYER_MAX_HP)

	# ── Penalty helper: used slots must read one position further along ──────
	# Nothing rotates -> NEXT of (0,0,0) is (7, 2, 8) = 17
	fails += _check(gm.get_next_slot_penalty_with_multiplier([])["base_penalty"] == 17,
		"no rotation: NEXT total is 17")
	# Slot 0 rolls -> its NEXT becomes the card 2 steps out (9) -> (9, 2, 8) = 19
	fails += _check(gm.get_next_slot_penalty_with_multiplier([0])["base_penalty"] == 19,
		"slot 0 rotating: its NEXT advances to 9 (total 19)")
	# All slots roll -> (9, 1, 6) = 16
	fails += _check(gm.get_next_slot_penalty_with_multiplier([0, 1, 2])["base_penalty"] == 16,
		"all reels rotating: NEXT total is 16")

	# A word using slot 0: 'A' from the reel + hand 'T','S' (so the reel rolls)
	var uses_slot0: Array = [
		{"type": "slot", "index": 0, "char": "A", "card_letter": "A", "damage": 4, "color": "red"},
		{"type": "hand", "hand_index": 0, "char": "T", "card_letter": "T", "damage": 1, "color": "red"},
		{"type": "hand", "hand_index": 1, "char": "S", "card_letter": "S", "damage": 1, "color": "red"}
	]
	var hand_only: Array = [
		{"type": "hand", "hand_index": 0, "char": "C", "card_letter": "C", "damage": 1, "color": "red"},
		{"type": "hand", "hand_index": 1, "char": "A", "card_letter": "A", "damage": 1, "color": "red"},
		{"type": "hand", "hand_index": 2, "char": "T", "card_letter": "T", "damage": 1, "color": "red"}
	]

	# ── Preview must equal reality, in both phases and with/without shield ──
	fails += _check_preview_matches_reality(gm, uses_slot0, [0], false, 0, "DAY, no shield")
	fails += _check_preview_matches_reality(gm, uses_slot0, [0], false, 30, "DAY, 30 shield")
	fails += _check_preview_matches_reality(gm, uses_slot0, [0], false, 1000, "DAY, huge shield")
	# NIGHT start -> submitting flips to DAY, so no night penalty at all
	fails += _check_preview_matches_reality(gm, uses_slot0, [0], true, 0, "NIGHT start (flips to DAY)")
	# Using no slot: the reels stay put
	fails += _check_preview_matches_reality(gm, hand_only, [], false, 0, "no slot used, no rotation")

	# ── Lethal detection ────────────────────────────────────────────────────
	_setup(gm, false, 0, 4)
	var lethal_plan: Dictionary = gm.predict_submit_outcome([
		{"type": "hand", "hand_index": 0, "char": "A", "card_letter": "A", "damage": 1, "color": "red"},
		{"type": "hand", "hand_index": 1, "char": "T", "card_letter": "T", "damage": 1, "color": "red"}
	], [])
	fails += _check(bool(lethal_plan["lethal"]), "a submit that drops HP to 0 is flagged lethal")
	fails += _check(int(lethal_plan["player_hp_after"]) == 0, "lethal preview ends at 0 HP")

	# Damage is huge on this board (all RED -> the NIGHT penalty is x100), so
	# also check a survivable case where the player keeps all their HP.
	_setup(gm, false, 99999, gm.PLAYER_MAX_HP)
	var safe_plan: Dictionary = gm.predict_submit_outcome([
		{"type": "hand", "hand_index": 0, "char": "A", "card_letter": "A", "damage": 0, "color": "gold"},
		{"type": "hand", "hand_index": 1, "char": "T", "card_letter": "T", "damage": 0, "color": "gold"},
		{"type": "hand", "hand_index": 2, "char": "S", "card_letter": "S", "damage": 0, "color": "gold"}
	], [])
	fails += _check(int(safe_plan["total_hp_lost"]) == 0, "shield fully absorbs -> 0 HP lost")
	fails += _check(int(safe_plan["player_hp_after"]) == gm.PLAYER_MAX_HP, "fully absorbed keeps HP at max")
	fails += _check(not bool(safe_plan["lethal"]), "fully absorbed is not flagged lethal")
	# Comparing the BASE (pre-multiplier) total is the clearest way to show which
	# NEXT cards were read: unrevolved reels give 7+2+8, a rolled slot gives 9+2+8.
	fails += _check(int(safe_plan["night_base_penalty"]) == 17,
		"no slot used -> night penalty reads the un-rolled NEXT cards (7+2+8=17)")
	fails += _check(int(safe_plan["night_penalty"]) == 1700,
		"all-RED NEXT group applies the x100 night multiplier (17 x 100)")

	# The same word, but using a slot, must preview a DIFFERENT night penalty
	_setup(gm, false, 99999, gm.PLAYER_MAX_HP)
	var rolled_plan: Dictionary = gm.predict_submit_outcome([
		{"type": "slot", "index": 0, "char": "A", "card_letter": "A", "damage": 0, "color": "gold"},
		{"type": "hand", "hand_index": 1, "char": "T", "card_letter": "T", "damage": 0, "color": "gold"},
		{"type": "hand", "hand_index": 2, "char": "S", "card_letter": "S", "damage": 0, "color": "gold"}
	], [0])
	fails += _check(int(rolled_plan["night_base_penalty"]) == 19,
		"using slot 0 previews the ROTATED penalty (9+2+8=19), not 17")
	fails += _check(int(rolled_plan["night_penalty"]) == 1900,
		"rolled penalty carries through the multiplier (19 x 100)")
	var rolled_cards: Array = rolled_plan["night_next_cards"]
	fails += _check(str(rolled_cards[0]["letter"]) == "C" and bool(rolled_cards[0]["will_rotate"]),
		"slot 0's previewed NEXT card is the post-rotation card 'C'")
	fails += _check(not bool(rolled_cards[1]["will_rotate"]),
		"untouched slot 1 keeps its un-rolled NEXT card")

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)

func _setup(gm: Node, night: bool, shield: int, hp: int) -> void:
	gm.reset_game()
	gm.slots = BOARD.duplicate(true)
	gm.current_slot_indices = [0, 0, 0]
	gm.is_night = night
	gm.shield = shield
	gm.player_hp = hp
	# This suite is about reel rotation and the night multiplier, so the enemy's
	# random skill letters are cleared out: the words below spell A/T/S, and an
	# enemy that happened to bind one of those to NIGHTMARE would legitimately
	# change the numbers this file asserts. Enemy skills have their own suite
	# (_enemy_skill_test.gd).
	gm.enemy_skills = []
	gm.enemy_shield = 0
	gm.enemy_night_tax = 0
	gm.hand_limit = gm.HAND_SIZE

# Runs the preview, then actually performs the submit, and requires the HP the
# player ends up with to match the preview exactly.
func _check_preview_matches_reality(gm: Node, assignment: Array, used_slots: Array,
		start_night: bool, shield: int, label: String) -> int:
	_setup(gm, start_night, shield, gm.PLAYER_MAX_HP)
	var hp_before: int = gm.player_hp

	var plan: Dictionary = gm.predict_submit_outcome(assignment, used_slots)
	var predicted_hp: int = int(plan["player_hp_after"])
	var predicted_lost: int = int(plan["total_hp_lost"])

	# Now actually submit, for real.
	var word: String = ""
	for a in assignment:
		word += str(a["char"])
	gm.execute_assignment(word, assignment)
	gm.apply_turn_start_penalty()
	var real_hp: int = gm.player_hp
	var real_lost: int = hp_before - real_hp

	var fails: int = 0
	fails += _check(predicted_hp == real_hp,
		"%s: preview HP %d == real HP %d" % [label, predicted_hp, real_hp])
	fails += _check(predicted_lost == real_lost,
		"%s: preview loss %d == real loss %d" % [label, predicted_lost, real_lost])
	return fails

func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1

