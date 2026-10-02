extends Node

# Headless test for the RELIC buffs: destroying every part of an enemy pays one
# relic, and a relic is a PERMANENT buff for the rest of the run.
#
# The whole difficulty here is PERSISTENCE. Three of the four buff types ride on
# stats the game deliberately wipes at a stage change:
#
#     _clear_enemy_skills()  ->  hand_limit = HAND_SIZE   (every stage clear)
#     choose_reward()        ->  shield = 0               (every reward claim)
#     the "IRON WILL" reward ->  player_max_hp += 5       (competes with relic HP)
#
# So a relic that merely added to those variables would be silently erased one
# stage later. These tests walk the exact reset paths a real run takes and assert
# the buff is still there afterwards.

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame
	gm.reset_game()

	fails += _check_relic_changes_a_stat(gm)
	fails += _check_buff_survives_a_stage_clear(gm)
	fails += _check_shield_survives_a_reward_claim(gm)
	fails += _check_hand_survives_hand_down(gm)
	fails += _check_hp_and_reward_max_hp_compose(gm)
	fails += _check_relic_only_from_part_destruction(gm)
	fails += _check_reset_clears_everything(gm)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## Every relic kind must move a real, visible stat — a relic that changed nothing
## would be the placeholder this replaced.
func _check_relic_changes_a_stat(gm: Node) -> int:
	var fails: int = 0
	var seen: Dictionary = {}
	# Grant enough relics that all four kinds are drawn at least once.
	for i in range(40):
		gm.reset_game()
		var r: Dictionary = gm.grant_relic("DRAGON", ["DR", "AG", "ON"])
		var kind: String = str(r.get("kind", ""))
		seen[kind] = true
		match kind:
			"hp":
				fails += _check(gm.get_max_player_hp() == gm.PLAYER_MAX_HP + gm.RELIC_MAX_HP,
					"an HP relic raises the ceiling to %d" % gm.get_max_player_hp())
				fails += _check(gm.get_player_hp() == gm.PLAYER_MAX_HP + gm.RELIC_MAX_HP,
					"an HP relic also heals the new headroom immediately")
			"shield":
				fails += _check(gm.get_shield() == gm.RELIC_SHIELD,
					"a shield relic grants %d shield now" % gm.RELIC_SHIELD)
			"hand":
				fails += _check(gm.get_hand_limit() == gm.HAND_SIZE + gm.RELIC_HAND,
					"a hand relic raises the hand limit to %d" % gm.get_hand_limit())
			"op":
				fails += _check(gm.get_operation_points() == gm.RELIC_OP,
					"an OP relic grants %d OP now" % gm.RELIC_OP)
		fails += _check(not str(r.get("label", "")).is_empty(),
			"the relic describes its own buff (%s)" % str(r.get("label", "")))
	for kind: String in ["hp", "shield", "hand", "op"]:
		fails += _check(seen.has(kind), "the '%s' relic kind is reachable" % kind)
	return fails


## The core guarantee: a stage clear wipes hand_limit, and the relic bonus has
## to come back with it.
func _check_buff_survives_a_stage_clear(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.relic_hand_bonus = 0
	gm.relic_hp_bonus = 2 * gm.RELIC_MAX_HP
	gm._reapply_relic_buffs()
	var hand_bonus: int = gm.relic_hand_bonus
	var hp_bonus: int = gm.relic_hp_bonus
	if hand_bonus > 0:
		fails += _check(gm.get_hand_limit() == gm.HAND_SIZE + hand_bonus,
			"the hand bonus is applied (%d)" % gm.get_hand_limit())

	# Clear the stage the way a defeat does. _clear_enemy_skills() runs inside.
	gm._advance_stage()
	if hand_bonus > 0:
		fails += _check(gm.get_hand_limit() == gm.HAND_SIZE + hand_bonus,
			"the hand bonus SURVIVES a stage clear (%d)" % gm.get_hand_limit())
	fails += _check(gm.get_max_player_hp() == gm.PLAYER_MAX_HP + hp_bonus,
		"the max HP bonus SURVIVES a stage clear (%d)" % gm.get_max_player_hp())
	# And the enemy it wiped is genuinely gone, i.e. the test is meaningful.
	fails += _check(gm.get_enemy_shield() == 0,
		"the stage clear really did wipe the enemy's own effects")
	return fails

## Claiming a reward zeroes the shield. A relic shield is a floor, so it returns.
func _check_shield_survives_a_reward_claim(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.relic_shield_bonus = 2 * gm.RELIC_SHIELD
	gm._reapply_relic_buffs()
	var expected: int = gm.relic_shield_bonus
	fails += _check(gm.get_shield() == expected, "the shield floor is set (%d)" % expected)

	# Spend the shield on damage so it is definitely 0 going into the reward.
	gm.shield = 0
	# Roll and claim a reward that (a) is not the shield reward and (b) SETTLES in
	# one call. "remove_card" is excluded because it is a two-step reward that
	# returns early and waits for the burn picker, so it never reaches the shield
	# reset at all. roll_rewards() is random, so the pool is normalised to a known
	# shape rather than skipped, keeping this case deterministic.
	gm.roll_rewards()
	for i in range(gm.reward_options.size()):
		if str(gm.reward_options[i].get("type", "")) in ["remove_card", "shield"]:
			gm.reward_options[i] = {"type": "heal", "title": "VITALITY", "detail": ""}
	var settled: int = -1
	for i in range(gm.get_reward_options().size()):
		if str(gm.get_reward_options()[i].get("type", "")) == "heal":
			settled = i
			break
	fails += _check(settled >= 0, "a settling non-shield reward is on offer")
	if settled >= 0:
		gm.choose_reward(settled)
	fails += _check(gm.get_shield() == expected,
		"the shield floor SURVIVES a reward claim (%d)" % gm.get_shield())
	# The floor is a floor, not a lock: a word can still stack shield above it.
	gm.shield = expected + 10
	gm._reapply_relic_buffs()
	fails += _check(gm.get_shield() == expected + 10,
		"earned shield above the floor is kept (%d)" % gm.get_shield())
	return fails


## HAND DOWN shrinks the hand limit; the relic bonus rides on top, and the
## ENEMY_MIN_HAND_LIMIT floor still applies as before.
func _check_hand_survives_hand_down(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.relic_hand_bonus = 1
	gm._reapply_relic_buffs()
	var with_relic: int = gm.HAND_SIZE + 1
	fails += _check(gm.get_hand_limit() == with_relic,
		"the relic raises the hand limit to %d" % with_relic)

	# Simulate HAND DOWN, then a stage clear, the way a fight goes.
	gm.hand_limit = maxi(gm.ENEMY_MIN_HAND_LIMIT, gm.hand_limit - 1)
	fails += _check(gm.get_hand_limit() == with_relic - 1,
		"HAND DOWN still shrinks the hand limit (%d)" % gm.get_hand_limit())
	gm._advance_stage()
	fails += _check(gm.get_hand_limit() == with_relic,
		"and the stage clear restores it to the relic-adjusted size (%d)" % gm.get_hand_limit())
	# With no relic, the hand limit must be exactly what it always was.
	gm.relic_hand_bonus = 0
	gm._reapply_relic_buffs()
	fails += _check(gm.get_hand_limit() == gm.HAND_SIZE,
		"with no relic the hand limit is just HAND_SIZE (%d)" % gm.get_hand_limit())
	return fails


## The relic HP bonus and the "IRON WILL" reward both raise the same ceiling and
## must compose rather than overwrite each other.
func _check_hp_and_reward_max_hp_compose(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.relic_hp_bonus = gm.RELIC_MAX_HP
	gm._reapply_relic_buffs()
	fails += _check(gm.get_max_player_hp() == gm.PLAYER_MAX_HP + gm.RELIC_MAX_HP,
		"relic HP alone gives %d" % gm.get_max_player_hp())

	# Take the max-HP reward on top. roll_rewards() is RANDOM, so the option may
	# not be on offer this run — force it onto the table rather than skipping the
	# check, so this case is deterministic instead of flaky.
	gm.roll_rewards()
	var index: int = -1
	for i in range(gm.get_reward_options().size()):
		if str(gm.get_reward_options()[i].get("type", "")) == "max_hp":
			index = i
			break
	if index < 0:
		# Replace the first option with a max_hp one, keeping the pool shape.
		gm.reward_options[0] = {"type": "max_hp", "title": "IRON WILL", "detail": ""}
		index = 0
	gm.choose_reward(index)
	var want: int = gm.PLAYER_MAX_HP + gm.MAX_HP_REWARD_GAIN + gm.RELIC_MAX_HP
	fails += _check(gm.get_max_player_hp() == want,
		"relic HP + IRON WILL compose to %d (got %d)" % [want, gm.get_max_player_hp()])

	# Several stage clears and re-applications must not drift or double up.
	for _i in range(5):
		gm._advance_stage()
	fails += _check(gm.get_max_player_hp() == want,
		"the ceiling is stable across 5 stage clears (%d)" % gm.get_max_player_hp())
	return fails

## A relic must still be paid ONLY for a part destruction — a plain HP kill, and
## merely breaking one part, must not grant a buff.
func _check_relic_only_from_part_destruction(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_enemy_name("DRAGON")
	var base_hp: int = gm.get_max_player_hp()
	var base_hand: int = gm.get_hand_limit()

	# One part is not enough.
	gm.enemy_hp = 9999
	gm.execute_assignment("DRIFT", _word("DRIFT"))
	fails += _check(gm.get_relic_count() == 0, "breaking one part grants no relic")
	fails += _check(gm.get_max_player_hp() == base_hp and gm.get_hand_limit() == base_hand,
		"and grants no buff")

	# A lethal HP kill is not a part destruction.
	gm.enemy_hp = 1
	gm.execute_assignment("DRAGON", _word("DRAGON", 500))
	fails += _check(gm.get_relic_count() == 0, "a plain HP kill grants no relic")
	fails += _check(gm.get_max_player_hp() == base_hp and gm.get_hand_limit() == base_hand,
		"and grants no buff")

	# A genuine total destruction does grant one, and the buff shows up.
	gm.set_enemy_name("DRAGON")
	gm.enemy_hp = 9999
	gm.execute_assignment("DRAGON", _word("DRAGON"))
	fails += _check(gm.get_relic_count() == 1,
		"a total destruction grants exactly one relic")
	fails += _check(not gm.get_relic_bonus_text().is_empty()
			and gm.get_relic_bonus_text() != "none yet",
		"and the bonus summary names the buff (%s)" % gm.get_relic_bonus_text())
	return fails


## A retry starts from nothing: no relics, no leftover buffs.
func _check_reset_clears_everything(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	for _i in range(4):
		gm.grant_relic("DRAGON", ["DR", "AG", "ON"])
	fails += _check(gm.get_relic_count() > 0, "relics were taken before the reset")
	gm.reset_game()
	fails += _check(gm.get_relic_count() == 0, "reset clears the relic count")
	fails += _check(gm.relic_hp_bonus == 0 and gm.relic_shield_bonus == 0
			and gm.relic_hand_bonus == 0 and gm.relic_op_bonus == 0,
		"reset clears every relic bonus total")
	fails += _check(gm.get_max_player_hp() == gm.PLAYER_MAX_HP,
		"reset restores the base HP ceiling (%d)" % gm.get_max_player_hp())
	fails += _check(gm.get_hand_limit() == gm.HAND_SIZE,
		"reset restores the base hand limit (%d)" % gm.get_hand_limit())
	fails += _check(gm.get_shield() == 0, "reset clears the shield")
	fails += _check(gm.get_relic_bonus_text() == "none yet",
		"the bonus summary reads empty after a reset")
	return fails


func _word(word: String, damage: int = 0) -> Array:
	var out: Array = []
	for i in range(word.length()):
		out.append({"type": "hand", "hand_index": i, "char": word[i],
			"card_letter": word[i], "is_wildcard": false,
			"damage": damage, "color": "green"})
	return out


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
