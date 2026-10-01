extends Node

# Regression guard: the "CARD DRAW" reward must never come back.
#
# It used to be offered, and it did not work. Choosing it appended a card to the
# hand, but defeating an enemy sets hand_redraw_pending and the UI calls
# flush_pending_hand_redraw() immediately afterwards. That calls _reset_hand(),
# which discards EVERY card in hand -- including the one just added -- and then
# refills to the hand limit. The player therefore ended up with exactly the fresh
# hand a new stage hands out anyway, so the reward was a no-op that only shuffled
# one card into the graveyard. It was removed rather than fixed.
#
# This test keeps the removal honest: the type must not be rolled, and choose_reward
# must not accept it if something constructs the option by hand.

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame
	gm.reset_game()

	# ===== the reward is not offered ==============================
	for _attempt in range(200):
		gm.roll_rewards()
		for r: Dictionary in gm.get_reward_options():
			fails += _check(str(r.get("type", "")) != "draw",
				"CARD DRAW is not among the offered rewards")
			fails += _check(str(r.get("title", "")) != "CARD DRAW",
				"no option is titled CARD DRAW")
		if fails > 0:
			break
	fails += _check(fails == 0, "200 rolls never produced CARD DRAW")

	# ===== and it cannot be applied even if hand-built ============
	gm.reward_options = [{"type": "draw", "title": "CARD DRAW",
		"detail": "Draw a card into hand."}]
	gm.pending_reward_choice = true
	var hand_before: int = gm.hand.size()
	var res: Dictionary = gm.choose_reward(0)
	fails += _check(not res.get("ok", false),
		"choose_reward refuses a hand-built CARD DRAW option")
	fails += _check(gm.hand.size() == hand_before,
		"a refused CARD DRAW does not touch the hand (%d -> %d)"
		% [hand_before, gm.hand.size()])

	_finish(fails)


func _check(ok: bool, label: String) -> int:
	if ok:
		print("ok   - %s" % label)
		return 0
	print("FAIL - %s" % label)
	return 1


func _finish(fails: int) -> void:
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)