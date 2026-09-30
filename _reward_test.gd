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

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
