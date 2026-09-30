extends SceneTree

# Headless check of the updated special ability & reward system:
#   - Initial deck NEVER contains special ability cards
#   - Special abilities have unique costs and effects
#   - Q (Royal Summon), Z (Zero Gravity), X (Cross Multiply), J (Jack in the box)
#   - Generic specials (Spark, Guard, Mini Heal, Cycle)
#   - Reward system provides special cards

func _initialize() -> void:
	_run()

func _run() -> void:
	var gm = load("res://GameManager.gd").new()
	root.add_child(gm)
	await process_frame

	var fails: int = 0

	# 1) Initial deck verification: ZERO special cards in initial deck
	var specials_in_initial_deck: int = 0
	for card in gm.deck:
		if gm.has_special_ability(card):
			specials_in_initial_deck += 1
	fails += _check(specials_in_initial_deck == 0, "initial deck contains zero special cards (%d found)" % specials_in_initial_deck)

	# 2) Special definition check
	var q_def: Dictionary = {}
	var z_def: Dictionary = {}
	var x_def: Dictionary = {}
	var j_def: Dictionary = {}
	var a_def: Dictionary = {}
	for s in gm.SPECIAL_CARD_DEFS:
		if s.get("letter") == "Q": q_def = s.duplicate()
		elif s.get("letter") == "Z": z_def = s.duplicate()
		elif s.get("letter") == "X": x_def = s.duplicate()
		elif s.get("letter") == "J": j_def = s.duplicate()
		elif s.get("special_id") == "mini_heal": a_def = s.duplicate()

	fails += _check(gm.has_special_ability(q_def), "Q card has special ability")
	fails += _check(gm.has_special_ability(z_def), "Z card has special ability")
	fails += _check(gm.has_special_ability(x_def), "X card has special ability")
	fails += _check(gm.has_special_ability(j_def), "J card has special ability")
	fails += _check(gm.get_special_cost(q_def) == 6, "Q special costs 6 OP")
	fails += _check(gm.get_special_cost(z_def) == 6, "Z special costs 6 OP")
	fails += _check(gm.get_special_cost(x_def) == 6, "X special costs 6 OP")
	fails += _check(gm.get_special_cost(j_def) == 5, "J special costs 5 OP")

	# Plain card has no special
	var plain_card: Dictionary = {"letter": "E", "damage": 1, "color": "red"}
	fails += _check(not gm.has_special_ability(plain_card), "plain card has no special")
	fails += _check(gm.get_special_cost(plain_card) == 0, "plain card costs 0 OP for special")

	# 3) Test OP deficit refusal
	gm.hand = [q_def.duplicate(), plain_card.duplicate()]
	gm.operation_points = 3
	fails += _check(gm.get_special_cost_deficit(q_def) == 3, "deficit of 6-cost with 3 OP is 3")
	fails += _check(not gm.can_use_special_ability(q_def), "cannot activate without enough OP")
	var denied: Dictionary = gm.use_special_ability(0)
	fails += _check(not denied.get("valid", false), "activation refused when short on OP")
	fails += _check(gm.operation_points == 3, "refused activation spends no OP")

	# 4) Test Q: Royal Summon (adds 'U' to hand)
	gm.operation_points = 10
	var hand_size_before: int = gm.hand.size()
	var q_res: Dictionary = gm.use_special_ability(0)
	fails += _check(q_res.get("valid", false), "Q special succeeded")
	fails += _check(gm.operation_points == 4, "10 - 6 = 4 OP left after Q special")
	var has_u: bool = false
	for c in gm.hand:
		if c != null and c.get("letter") == "U":
			has_u = true
			break
	fails += _check(has_u, "Royal Summon added 'U' card to hand")

	# 5) Test Z: Zero Gravity (gains 10 shield and nullifies night penalty)
	gm.shield = 0
	gm.hand[0] = z_def.duplicate()
	gm.operation_points = 10
	var z_res: Dictionary = gm.use_special_ability(0)
	fails += _check(z_res.get("valid", false), "Z special succeeded")
	fails += _check(gm.shield == 10, "Z special granted 10 shield")
	fails += _check(gm.night_penalty_immune, "night_penalty_immune is true")
	fails += _check(gm.get_next_slot_total_penalty() == 0, "night penalty preview is 0 during immunity")
	# Apply turn penalty during night
	gm.is_night = true
	var pen_res: Dictionary = gm.apply_turn_start_penalty()
	fails += _check(pen_res.get("requested_damage") == 0, "night penalty was nullified to 0 damage")
	fails += _check(not gm.night_penalty_immune, "night_penalty_immune reset after penalty applied")

	# 6) Test X: Cross Multiply (2x next word effects)
	gm.hand[0] = x_def.duplicate()
	gm.operation_points = 10
	var x_res: Dictionary = gm.use_special_ability(0)
	fails += _check(x_res.get("valid", false), "X special succeeded")
	fails += _check(gm.word_multiplier == 2, "word_multiplier set to 2")

	# 7) Test J: Jack in the box (transforms into wildcard '?')
	gm.hand[0] = j_def.duplicate()
	gm.operation_points = 10
	var j_res: Dictionary = gm.use_special_ability(0)
	fails += _check(j_res.get("valid", false), "J special succeeded")
	fails += _check(gm.hand[0].get("letter") == "?", "J transformed into '?'")
	fails += _check(gm.hand[0].get("is_wildcard") == true, "J has is_wildcard = true")

	# 8) Test Generic A: Mini Heal
	gm.player_hp = 30
	gm.hand[0] = a_def.duplicate()
	gm.operation_points = 5
	var a_res: Dictionary = gm.use_special_ability(0)
	fails += _check(a_res.get("valid", false), "Mini heal special succeeded")
	fails += _check(gm.player_hp == 34, "player HP restored from 30 to 34")

	# 9) Test reward system offers special cards
	var found_special_reward: bool = false
	for _attempt in range(20):
		var rewards: Array = gm.roll_rewards()
		for rew in rewards:
			if rew.has("card") and gm.has_special_ability(rew["card"]):
				found_special_reward = true
				break
		if found_special_reward:
			break
	fails += _check(found_special_reward, "special card offered via roll_rewards")

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	quit(fails)

func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
