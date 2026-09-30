extends Node

# Headless test for the "IRON WILL" (max HP) reward.
# PLAYER_MAX_HP was a const, so the reward could only add +5 to the CURRENT HP
# and the ceiling never moved. That pushed player_hp ABOVE the ceiling, and every
# later heal (reward, GREEN trait, MINI HEAL) computes
#     mini(amount, MAX_HP - player_hp)   ->   a NEGATIVE amount
# so the next heal actually REMOVED HP. The max HP itself never went up.

# A small GREEN word: its heal used the same broken ceiling clamp.
const GREEN_WORD: Array = [
	{"type": "hand", "hand_index": 0, "char": "A", "card_letter": "A", "damage": 3, "color": "green"}
]

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame

	fails += _check_max_hp_actually_rises(gm)
	fails += _check_repeated_max_hp(gm)
	fails += _check_heal_never_drains_hp_after_max_hp(gm)
	fails += _check_green_trait_never_drains_hp_after_max_hp(gm)
	fails += _check_mini_heal_never_drains_hp_after_max_hp(gm)
	fails += _check_hp_never_exceeds_ceiling(gm)
	fails += _check_reset_restores_ceiling(gm)
	fails += _check_preview_agrees_with_ceiling(gm)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)

## Takes the "max_hp" reward `times` times, rolling until the option appears.
func _take_max_hp(gm: Node, times: int) -> int:
	var taken: int = 0
	for _n in range(times):
		for _try in range(40):
			gm.roll_rewards()
			var opts: Array = gm.get_reward_options()
			var pick: int = -1
			for i in range(opts.size()):
				if str(opts[i].get("type", "")) == "max_hp":
					pick = i
			if pick >= 0:
				var r: Dictionary = gm.choose_reward(pick)
				if r.get("ok", false):
					taken += 1
				break
	return taken

## Takes the first reward of `type`, or -1 if it is not offered.
func _take_reward(gm: Node, type: String) -> Dictionary:
	gm.roll_rewards()
	var opts: Array = gm.get_reward_options()
	for i in range(opts.size()):
		if str(opts[i].get("type", "")) == type:
			return gm.choose_reward(i)
	return {}

func _check_max_hp_actually_rises(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.player_hp = 20
	var before: int = gm.get_max_player_hp()
	var taken: int = _take_max_hp(gm, 1)
	fails += _check(taken == 1, "the max HP reward could be taken")
	fails += _check(gm.get_max_player_hp() > before,
		"max HP actually rises (%d -> %d)" % [before, gm.get_max_player_hp()])
	fails += _check(gm.player_hp <= gm.get_max_player_hp(),
		"current HP never exceeds the new ceiling (%d / %d)" % [gm.player_hp, gm.get_max_player_hp()])
	return fails

## The reported symptom: a heal right after the max HP reward DRAINED HP.
func _check_heal_never_drains_hp_after_max_hp(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.player_hp = 20
	_take_max_hp(gm, 1)
	var hp_before: int = gm.player_hp
	var heals: int = 0
	for _n in range(20):
		var r: Dictionary = _take_reward(gm, "heal")
		if r.get("ok", false):
			heals += 1
			fails += _check(gm.player_hp >= hp_before,
				"the heal reward never removes HP (%d -> %d)" % [hp_before, gm.player_hp])
			hp_before = gm.player_hp
	fails += _check(heals > 0, "the heal reward was exercised (%d times)" % heals)
	return fails

## The GREEN trait heal had the same negative-amount defect.
func _check_green_trait_never_drains_hp_after_max_hp(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.player_hp = 20
	gm.is_night = false
	_take_max_hp(gm, 1)
	var hp_before: int = gm.player_hp
	gm.execute_assignment("A", GREEN_WORD)
	fails += _check(gm.player_hp >= hp_before,
		"a GREEN word never removes HP (%d -> %d)" % [hp_before, gm.player_hp])
	fails += _check(gm.player_hp <= gm.get_max_player_hp(),
		"a GREEN word never pushes HP past the ceiling (%d / %d)" % [gm.player_hp, gm.get_max_player_hp()])
	return fails

## The MINI HEAL special shared the same clamp.
func _check_mini_heal_never_drains_hp_after_max_hp(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.player_hp = 20
	var a_def: Dictionary = {}
	for s in GameManager.SPECIAL_CARD_DEFS:
		if s.get("special_id") == "mini_heal":
			a_def = s.duplicate()
	_take_max_hp(gm, 1)
	# Fill HP right up to the raised ceiling: the worst case for the clamp.
	gm.player_hp = gm.get_max_player_hp()
	var hp_before: int = gm.player_hp
	gm.hand[0] = a_def
	gm.operation_points = 10
	var r: Dictionary = gm.use_special_ability(0)
	fails += _check(r.get("valid", false), "MINI HEAL activated at full HP")
	fails += _check(gm.player_hp == hp_before,
		"MINI HEAL at full HP changes nothing (%d -> %d)" % [hp_before, gm.player_hp])
	return fails

## No path may ever leave current HP above the ceiling.
func _check_hp_never_exceeds_ceiling(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.player_hp = 20
	_take_max_hp(gm, 4)
	var max_hp: int = gm.get_max_player_hp()
	# Hammer the player with damage, then heal: HP must stay within 0..ceiling.
	for _n in range(6):
		gm.player_hp = 1
		gm.shield = 0
		gm.is_night = true
		gm.apply_turn_start_penalty()
		fails += _check(gm.player_hp >= 0, "damage never drops HP below 0 (%d)" % gm.player_hp)
		gm.is_night = false
		gm.execute_assignment("A", GREEN_WORD)
		fails += _check(gm.player_hp <= max_hp,
			"HP stays within the ceiling after healing (%d / %d)" % [gm.player_hp, max_hp])
	return fails

func _check_reset_restores_ceiling(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.player_hp = 20
	_take_max_hp(gm, 2)
	var raised: int = gm.get_max_player_hp()
	fails += _check(raised > GameManager.PLAYER_MAX_HP,
		"the ceiling was raised before the reset (%d)" % raised)
	gm.reset_game()
	fails += _check(gm.get_max_player_hp() == GameManager.PLAYER_MAX_HP,
		"reset_game restores the base ceiling (%d)" % gm.get_max_player_hp())
	fails += _check(gm.player_hp == GameManager.PLAYER_MAX_HP,
		"reset_game refills HP to the base ceiling (%d)" % gm.player_hp)
	return fails

## The submit preview must respect the RAISED ceiling, not the original const.
func _check_preview_agrees_with_ceiling(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.is_night = false
	gm.shield = 0
	_take_max_hp(gm, 1)
	var max_hp: int = gm.get_max_player_hp()
	var plan: Dictionary = gm.predict_submit_outcome(GREEN_WORD, [])
	var hp_before: int = gm.player_hp
	# Mirror the real submit flow: the preview also covers the NIGHT penalty.
	gm.execute_assignment("A", GREEN_WORD)
	gm.apply_turn_start_penalty()
	fails += _check(int(plan.get("player_hp_after", -1)) == gm.player_hp,
		"preview HP %d == real HP %d" % [int(plan.get("player_hp_after", -1)), gm.player_hp])
	fails += _check(int(plan.get("player_hp_after", -1)) <= max_hp,
		"preview never exceeds the ceiling (%d / %d)" % [int(plan.get("player_hp_after", -1)), max_hp])
	fails += _check(int(plan.get("total_hp_lost", -1)) == maxi(hp_before - gm.player_hp, 0),
		"preview HP lost matches reality")
	return fails

func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1

func _check_repeated_max_hp(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.player_hp = 20
	var before: int = gm.get_max_player_hp()
	var taken: int = _take_max_hp(gm, 3)
	fails += _check(taken == 3, "the max HP reward stacks (took %d)" % taken)
	fails += _check(gm.get_max_player_hp() == before + 15,
		"three max HP rewards raise the ceiling by 15 (%d -> %d)" % [before, gm.get_max_player_hp()])
	return fails
