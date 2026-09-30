extends Node

# Headless test for the post-defeat reward system:
#   * three distinct options are always offered
#   * "add card" grows the deck, "remove card" shrinks it
#   * deck size is clamped so the draw loop can never break
#   * a reward can only be taken once, and only when one is pending

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame
	gm.reset_game()

	# ===== Three options are offered =============================
	var options: Array = gm.roll_rewards()
	fails += _check(options.size() == 3, "exactly three options are offered (got %d)" % options.size())
	fails += _check(gm.has_pending_reward(), "a choice is pending after rolling")
	var titles: Array = []
	for r: Dictionary in options:
		fails += _check(r.has("type") and r.has("title") and r.has("detail"),
			"option has type/title/detail: %s" % str(r.get("type", "?")))
		titles.append(str(r.get("type", "")))
	fails += _check(titles.size() == 3, "three distinct option entries")
	# No duplicate types
	var unique: Dictionary = {}
	for t: String in titles:
		unique[t] = true
	fails += _check(unique.size() == titles.size(), "option types are distinct (%s)" % str(titles))

	# A deck change must be offered while the deck is at a normal size
	var has_deck_reward: bool = false
	for t: String in titles:
		if t == "add_card" or t == "remove_card":
			has_deck_reward = true
	fails += _check(has_deck_reward, "a deck-change option is offered")

	# ===== add_card grows the deck ===============================
	var idx_add: int = titles.find("add_card")
	if idx_add >= 0:
		var before: int = gm.get_deck_size()
		var res: Dictionary = gm.choose_reward(idx_add)
		fails += _check(res.get("ok", false), "add_card succeeds")
		fails += _check(gm.get_deck_size() == before + 1,
			"deck grew by 1 (%d -> %d)" % [before, gm.get_deck_size()])
		fails += _check(str(res.get("message", "")).length() > 0, "add_card reports what it added")
	fails += _check(not gm.has_pending_reward(), "no pending choice after taking one")
	fails += _check(gm.rewards_taken == 1, "rewards_taken incremented")

	# Taking twice is refused
	var twice: Dictionary = gm.choose_reward(0)
	fails += _check(not twice.get("ok", false), "a second reward cannot be taken")

	# ===== remove_card shrinks the deck ==========================
	gm.roll_rewards()
	var opts2: Array = gm.get_reward_options()
	var types2: Array = []
	for r: Dictionary in opts2:
		types2.append(str(r.get("type", "")))
	var idx_rm: int = types2.find("remove_card")
	if idx_rm >= 0:
		var before2: int = gm.get_deck_size()
		var res2: Dictionary = gm.choose_reward(idx_rm)
		fails += _check(res2.get("ok", false), "remove_card succeeds")
		fails += _check(gm.get_deck_size() == before2 - 1,
			"deck shrank by 1 (%d -> %d)" % [before2, gm.get_deck_size()])

	# ===== Deck size is clamped ==============================
	# At the maximum, "add_card" must not be offered
	gm.deck = []
	for i in range(gm.MAX_DECK_SIZE):
		gm.deck.append({"letter": "E", "damage": 1, "color": "red"})
	var max_opts: Array = gm.roll_rewards()
	var max_types: Array = []
	for r: Dictionary in max_opts:
		max_types.append(str(r.get("type", "")))
	fails += _check(not max_types.has("add_card"),
		"add_card is not offered at MAX_DECK_SIZE")
	fails += _check(max_types.has("remove_card"),
		"remove_card is still offered at MAX_DECK_SIZE")
	fails += _check(max_opts.size() == 3, "still three options at max deck")

	# At the minimum, "remove_card" must not be offered
	gm.deck = []
	for i in range(gm.MIN_DECK_SIZE):
		gm.deck.append({"letter": "E", "damage": 1, "color": "red"})
	var min_opts: Array = gm.roll_rewards()
	var min_types: Array = []
	for r: Dictionary in min_opts:
		min_types.append(str(r.get("type", "")))
	fails += _check(not min_types.has("remove_card"),
		"remove_card is not offered at MIN_DECK_SIZE")
	fails += _check(min_types.has("add_card"),
		"add_card is still offered at MIN_DECK_SIZE")
	fails += _check(min_opts.size() == 3, "still three options at min deck")

	# ===== Stat rewards apply ==============================
	gm.reset_game()
	gm.player_hp = 10
	gm.shield = 0
	gm.operation_points = 0
	for type: String in ["heal", "shield", "op"]:
		gm.roll_rewards()
		var opts3: Array = gm.get_reward_options()
		var pick: int = -1
		for i in range(opts3.size()):
			if str(opts3[i].get("type", "")) == type:
				pick = i
		if pick >= 0:
			var r3: Dictionary = gm.choose_reward(pick)
			fails += _check(r3.get("ok", false), "%s reward applies" % type)
			if type == "heal":
				fails += _check(gm.player_hp > 10, "heal raised HP (%d)" % gm.player_hp)
			elif type == "shield":
				fails += _check(gm.shield > 0, "shield reward granted shield (%d)" % gm.shield)
			elif type == "op":
				fails += _check(gm.operation_points > 0, "op reward granted OP (%d)" % gm.operation_points)

	# Invalid index is refused
	gm.roll_rewards()
	fails += _check(not gm.choose_reward(99).get("ok", false), "out-of-range index refused")
	fails += _check(not gm.choose_reward(-1).get("ok", false), "negative index refused")
	fails += _check(gm.has_pending_reward(), "a refused pick leaves the choice open")

	# reset_game clears reward state
	gm.reset_game()
	fails += _check(not gm.has_pending_reward(), "reset_game clears the pending choice")
	fails += _check(gm.rewards_taken == 0, "reset_game clears rewards_taken")

	# ===== The card you are SHOWN is the card you GET ==============
	# The reward rolls a concrete card up front so the choice is informed.
	gm.reset_game()
	gm.roll_rewards()
	var deck_opts: Array = gm.get_reward_options()
	var add_card: Dictionary = {}
	var burn_card: Dictionary = {}
	for r: Dictionary in deck_opts:
		if str(r.get("type", "")) == "add_card":
			add_card = r
		elif str(r.get("type", "")) == "remove_card":
			burn_card = r

	fails += _check(add_card.has("card"), "add_card option carries a concrete card")
	fails += _check(str(add_card.get("card", {}).get("letter", "")) != "",
		"shown add card has a letter ('%s')" % str(add_card.get("card", {}).get("letter", "")))
	fails += _check(burn_card.has("card"), "remove_card option carries a concrete card")
	if burn_card.has("card"):
		var bc: Dictionary = burn_card["card"]
		# The burned card must really exist in the deck right now
		var in_deck: bool = false
		for c: Dictionary in gm.deck:
			if str(c.get("letter", "")) == str(bc.get("letter", "")) \
					and int(c.get("damage", -1)) == int(bc.get("damage", -2)) \
					and str(c.get("color", "")) == str(bc.get("color", "")):
				in_deck = true
		fails += _check(in_deck, "the burn card shown really is in the deck")

	# Taking add_card must add EXACTLY the card that was displayed
	if add_card.has("card"):
		var expected: Dictionary = add_card["card"]
		var exp_letter: String = str(expected.get("letter", ""))
		var exp_dmg: int = int(expected.get("damage", 0))
		var exp_color: String = str(expected.get("color", ""))
		var before_add: int = gm.get_deck_size()
		var res_add: Dictionary = gm.choose_reward(gm.get_reward_options().find(add_card))
		fails += _check(res_add.get("ok", false), "add_card applies")
		fails += _check(gm.get_deck_size() == before_add + 1, "deck grew by 1")
		var granted: Dictionary = res_add.get("card", {})
		fails += _check(str(granted.get("letter", "")) == exp_letter
				and int(granted.get("damage", -1)) == exp_dmg
				and str(granted.get("color", "")) == exp_color,
			"granted card matches the one shown (%s %d %s)" % [exp_letter, exp_dmg, exp_color])
		# And it must really be in the deck now
		var now_in_deck: bool = false
		for c: Dictionary in gm.deck:
			if str(c.get("letter", "")) == exp_letter \
					and int(c.get("damage", -1)) == exp_dmg \
					and str(c.get("color", "")) == exp_color:
				now_in_deck = true
		fails += _check(now_in_deck, "the shown card really landed in the deck")

	# Taking remove_card must remove EXACTLY the card that was displayed
	# (re-roll first: the add_card above already consumed this choice)
	gm.roll_rewards()
	var rm_card: Dictionary = {}
	for r: Dictionary in gm.get_reward_options():
		if str(r.get("type", "")) == "remove_card":
			rm_card = r
	if rm_card.has("card"):
		var shown: Dictionary = rm_card["card"]
		var s_letter: String = str(shown.get("letter", ""))
		var s_dmg: int = int(shown.get("damage", 0))
		var s_color: String = str(shown.get("color", ""))
		var count_before: int = 0
		for c: Dictionary in gm.deck:
			if str(c.get("letter", "")) == s_letter \
					and int(c.get("damage", -1)) == s_dmg \
					and str(c.get("color", "")) == s_color:
				count_before += 1
		var idx_rm2: int = gm.get_reward_options().find(rm_card)
		var before_rm: int = gm.get_deck_size()
		var res_rm: Dictionary = gm.choose_reward(idx_rm2)
		fails += _check(res_rm.get("ok", false), "remove_card applies")
		fails += _check(gm.get_deck_size() == before_rm - 1, "deck shrank by 1")
		var count_after: int = 0
		for c: Dictionary in gm.deck:
			if str(c.get("letter", "")) == s_letter \
					and int(c.get("damage", -1)) == s_dmg \
					and str(c.get("color", "")) == s_color:
				count_after += 1
		fails += _check(count_after == count_before - 1,
			"exactly the shown card was removed (%d -> %d of %s %d %s)" % [
				count_before, count_after, s_letter, s_dmg, s_color])
		fails += _check(str(res_rm.get("card", {}).get("letter", "")) == s_letter,
			"the burn message names the card that was shown")

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
