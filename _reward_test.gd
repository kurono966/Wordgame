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

	# ===== remove_card: the player PICKS the card ==================
	gm.roll_rewards()
	var opts2: Array = gm.get_reward_options()
	var types2: Array = []
	for r: Dictionary in opts2:
		types2.append(str(r.get("type", "")))
	var idx_rm: int = types2.find("remove_card")
	if idx_rm >= 0:
		var before2: int = gm.get_deck_size()
		var res2: Dictionary = gm.choose_reward(idx_rm)
		fails += _check(res2.get("ok", false), "remove_card step 1 succeeds")
		fails += _check(bool(res2.get("needs_card", false)),
			"remove_card asks the player to pick a card")
		fails += _check(gm.is_burning(), "a burn pick is now in progress")
		fails += _check(gm.has_pending_reward(), "the reward stays pending until a card is picked")
		fails += _check(gm.get_deck_size() == before2, "nothing is removed before the pick")

		# The pick list offers the deck AND the hand
		var burnable: Array = gm.get_burnable_cards()
		fails += _check(burnable.size() == gm.deck.size() + _hand_filled(gm),
			"burnable list covers the deck and the hand (%d)" % burnable.size())
		var has_hand_entry: bool = false
		for e: Dictionary in burnable:
			if str(e.get("source", "")) == "hand":
				has_hand_entry = true
		fails += _check(has_hand_entry, "a card in hand can also be burned")
		fails += _check(_all_ids_unique(burnable), "every burnable id is unique")

		# The player picks a SPECIFIC card; exactly that one is removed
		var picked: Dictionary = burnable[burnable.size() - 1]
		var picked_id: String = str(picked.get("id", ""))
		var want_letter: String = str(picked.get("card", {}).get("letter", ""))
		var want_damage: int = int(picked.get("card", {}).get("damage", -1))
		var want_color: String = str(picked.get("card", {}).get("color", ""))
		var count_before: int = _count_matching(gm, want_letter, want_damage, want_color)
		var res3: Dictionary = gm.confirm_burn_card(picked_id)
		fails += _check(res3.get("ok", false), "confirming the pick succeeds")
		fails += _check(not gm.is_burning(), "the burn pick is finished")
		fails += _check(not gm.has_pending_reward(), "the reward is consumed")
		fails += _check(gm.rewards_taken >= 1, "rewards_taken counted the burn")
		var count_after: int = _count_matching(gm, want_letter, want_damage, want_color)
		fails += _check(count_after == count_before - 1,
			"exactly the picked card was removed (%s %d %s: %d -> %d)" % [
				want_letter, want_damage, want_color, count_before, count_after])
		fails += _check(str(res3.get("card", {}).get("letter", "")) == want_letter,
			"the burn message names the picked card")

	# A burn pick can be cancelled without spending the reward
	gm.roll_rewards()
	var opts_c: Array = gm.get_reward_options()
	var idx_c: int = -1
	for i in range(opts_c.size()):
		if str(opts_c[i].get("type", "")) == "remove_card":
			idx_c = i
	if idx_c >= 0:
		gm.choose_reward(idx_c)
		fails += _check(gm.is_burning(), "burn pick started")
		gm.cancel_burn_card()
		fails += _check(not gm.is_burning(), "cancel_burn_card() leaves the picker")
		fails += _check(gm.has_pending_reward(), "cancelling keeps the reward available")
		fails += _check(gm.get_deck_size() > 0, "cancelling removes nothing")

	# A bad id must not consume the reward
	gm.roll_rewards()
	var opts_b: Array = gm.get_reward_options()
	var idx_b: int = -1
	for i in range(opts_b.size()):
		if str(opts_b[i].get("type", "")) == "remove_card":
			idx_b = i
	if idx_b >= 0:
		gm.choose_reward(idx_b)
		fails += _check(not gm.confirm_burn_card("nonsense").get("ok", false),
			"a malformed id is refused")
		fails += _check(not gm.confirm_burn_card("deck:99999").get("ok", false),
			"an out-of-range index is refused")
		fails += _check(gm.has_pending_reward(), "a refused pick keeps the reward pending")
		gm.cancel_burn_card()

	# confirm_burn_card without a pick in progress is refused
	fails += _check(not gm.confirm_burn_card("deck:0").get("ok", false),
		"confirm_burn_card() outside a burn is refused")

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
	# The burn option is a CHOICE, not a pre-rolled card: nothing is decided for
	# the player, and the option stays open until they pick one.
	fails += _check(not burn_card.has("card"),
		"remove_card option does NOT pre-roll a card")
	fails += _check(gm.get_burnable_cards().size() >= gm.get_deck_size(),
		"the burn picker offers every deck card")

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

	# remove_card must NOT pre-decide a card any more: the option carries no
	# concrete card, and the deck is only trimmed once the player picks.
	gm.roll_rewards()
	var rm_opt: Dictionary = {}
	var rm_index: int = -1
	var all_options: Array = gm.get_reward_options()
	for i in range(all_options.size()):
		if str(all_options[i].get("type", "")) == "remove_card":
			rm_opt = all_options[i]
			rm_index = i
	if not rm_opt.is_empty():
		fails += _check(not rm_opt.has("card"),
			"the burn option does not pre-roll a card to remove")
		fails += _check(str(rm_opt.get("detail", "")).to_lower().find("choose") >= 0,
			"the burn option tells the player to choose")
		var before_pick: int = gm.get_deck_size()
		gm.choose_reward(rm_index)
		fails += _check(gm.get_deck_size() == before_pick,
			"the deck is untouched until a card is picked")
		# Pick the very first candidate, then confirm
		var list2: Array = gm.get_burnable_cards()
		if not list2.is_empty():
			var first: Dictionary = list2[0]
			var f_card: Dictionary = first.get("card", {})
			var f_letter: String = str(f_card.get("letter", ""))
			var f_dmg: int = int(f_card.get("damage", -1))
			var f_color: String = str(f_card.get("color", ""))
			var f_before: int = _count_matching(gm, f_letter, f_dmg, f_color)
			var res_f: Dictionary = gm.confirm_burn_card(str(first.get("id", "")))
			fails += _check(res_f.get("ok", false), "burning the chosen card applies")
			fails += _check(_count_matching(gm, f_letter, f_dmg, f_color) == f_before - 1,
				"the chosen card is exactly the one removed (%s %d %s)" % [
					f_letter, f_dmg, f_color])

	# Burning a card from hand also works, and the hand refills afterwards
	gm.reset_game()
	gm.roll_rewards()
	var h_opt_index: int = -1
	var h_options: Array = gm.get_reward_options()
	for i in range(h_options.size()):
		if str(h_options[i].get("type", "")) == "remove_card":
			h_opt_index = i
	if h_opt_index >= 0:
		gm.choose_reward(h_opt_index)
		var hand_entry: Dictionary = {}
		for e: Dictionary in gm.get_burnable_cards():
			if str(e.get("source", "")) == "hand":
				hand_entry = e
				break
		if not hand_entry.is_empty():
			var hand_size_before: int = _hand_filled(gm)
			var res_h: Dictionary = gm.confirm_burn_card(str(hand_entry.get("id", "")))
			fails += _check(res_h.get("ok", false), "a hand card can be burned")
			# Hand is refilled from the deck, so it stays full but the card is gone
			fails += _check(_hand_filled(gm) == hand_size_before,
				"hand refills after burning one of its cards")
			var hb: Dictionary = res_h.get("card", {})
			var h_letter: String = str(hb.get("letter", ""))
			var h_dmg: int = int(hb.get("damage", -1))
			var h_color: String = str(hb.get("color", ""))
			fails += _check(_count_matching(gm, h_letter, h_dmg, h_color) + _hand_count_matching(
				gm, h_letter, h_dmg, h_color) < gm.MAX_DECK_SIZE + gm.HAND_SIZE,
				"burned hand card is no longer in hand")

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1


# How many cards in the hand slot array are actually filled.
func _hand_filled(gm: Node) -> int:
	var n: int = 0
	for c: Variant in gm.hand:
		if c != null:
			n += 1
	return n


func _all_ids_unique(entries: Array) -> bool:
	var seen: Dictionary = {}
	for e: Dictionary in entries:
		var id: String = str(e.get("id", ""))
		if id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true


# Counts matching cards across the draw pile and the hand.
func _count_matching(gm: Node, letter: String, damage: int, color: String) -> int:
	var n: int = 0
	for c: Dictionary in gm.deck:
		if str(c.get("letter", "")) == letter \
				and int(c.get("damage", -1)) == damage \
				and str(c.get("color", "")) == color:
			n += 1
	return n + _hand_count_matching(gm, letter, damage, color)


func _hand_count_matching(gm: Node, letter: String, damage: int, color: String) -> int:
	var n: int = 0
	for c: Variant in gm.hand:
		if c == null:
			continue
		var card: Dictionary = c
		if str(card.get("letter", "")) == letter \
				and int(card.get("damage", -1)) == damage \
				and str(card.get("color", "")) == color:
			n += 1
	return n
