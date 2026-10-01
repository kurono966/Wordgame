extends Node

# Headless tests for what the three-option reward offers:
#
#   1. "ADD A CARD" ONLY EVER HANDS OVER A ★ SPECIAL. A plain letter card would
#      be filler that plays no differently from the fixed 20 the player already
#      has, so the reward pool is specials only and the real choice is WHICH
#      power to take.
#   2. "WILDCARDS" IS ONE OF THE CHOICES and deals out 3 wildcard cards: "?" at
#      0 damage, in a real colour, each standing in for any letter.
#   3. That reward respects the deck ceiling instead of overfilling, and the
#      wildcards it hands over actually work as wildcards in a word.

const ROLLS: int = 60

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame
	gm.reset_game()

	fails += _check_add_card_is_always_special(gm)
	fails += _check_wildcards_is_offered(gm)
	fails += _check_wildcards_deals_three(gm)
	fails += _check_wildcards_respect_the_deck_ceiling(gm)
	fails += _check_wildcards_actually_work(gm)
	fails += _check_option_count_is_still_three(gm)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## Every rolled add_card must be a special, and no plain card may slip through.
func _check_add_card_is_always_special(gm: Node) -> int:
	var fails: int = 0
	var seen: int = 0
	var plain: int = 0
	var titled_ok: bool = true
	var detailed_ok: bool = true
	for _i in range(ROLLS):
		for reward in gm.roll_rewards():
			if str(reward.get("type", "")) != "add_card":
				continue
			seen += 1
			if not gm.has_special_ability(reward.get("card", {})):
				plain += 1
			if str(reward.get("title", "")) != "★ SPECIAL CARD":
				titled_ok = false
			if str(reward.get("detail", "")).length() <= 0:
				detailed_ok = false
			break  # one add_card per roll is enough
	fails += _check(seen > 0, "add_card was offered across the rolls (%d)" % seen)
	fails += _check(plain == 0,
		"no add_card reward was ever a plain card (%d plain in %d)" % [plain, seen])
	fails += _check(titled_ok, "every add_card option is titled ★ SPECIAL CARD")
	fails += _check(detailed_ok, "every add_card option explains its power")
	return fails


## WILDCARDS must actually turn up among the choices.
func _check_wildcards_is_offered(gm: Node) -> int:
	var found: int = 0
	var titled_ok: bool = true
	var detailed_ok: bool = true
	for _i in range(ROLLS):
		for reward in gm.roll_rewards():
			if str(reward.get("type", "")) != "wildcards":
				continue
			found += 1
			if str(reward.get("title", "")) != "WILDCARDS":
				titled_ok = false
			if not str(reward.get("detail", "")).contains("wildcard"):
				detailed_ok = false
			break
	var fails: int = 0
	fails += _check(found > 0, "WILDCARDS turned up within %d rolls (%d)" % [ROLLS, found])
	fails += _check(titled_ok, "the wildcard option is titled WILDCARDS")
	fails += _check(detailed_ok, "the wildcard option explains itself")
	return fails


## Rolls until the wanted option type turns up (or the cap runs out). The stat
## slot is one of three choices and there are six stat types, so a single roll
## usually does not contain it.
func _roll_until(gm: Node, type: String) -> Array:
	for _i in range(ROLLS * 4):
		var options: Array = gm.roll_rewards()
		if _index_of(options, type) >= 0:
			return options
	return []


## Taking it adds exactly three real wildcard cards.
func _check_wildcards_deals_three(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	var before: int = gm.deck.size()
	var pick: int = _index_of(_roll_until(gm, "wildcards"), "wildcards")
	fails += _check(pick >= 0, "WILDCARDS was on offer")

	var result: Dictionary = gm.choose_reward(pick)
	fails += _check(bool(result.get("ok", false)), "WILDCARDS could be taken")
	fails += _check(gm.deck.size() == before + GameManager.WILDCARD_REWARD_COUNT,
		"three wildcards were added (%d -> %d)" % [before, gm.deck.size()])

	# Count what the reward reports handing over, not the whole deck.
	var added: Array = result.get("cards", [])
	fails += _check(added.size() == GameManager.WILDCARD_REWARD_COUNT,
		"the reward reports %d cards (%d)" % [GameManager.WILDCARD_REWARD_COUNT, added.size()])
	var wild: int = 0
	var damage_ok: bool = true
	var colour_ok: bool = true
	for card in added:
		if str(card.get("letter", "")) != "?":
			continue
		wild += 1
		if int(card.get("damage", -1)) != 0:
			damage_ok = false
		if str(card.get("color", "")) not in ["red", "blue", "green", "yellow"]:
			colour_ok = false
	fails += _check(wild == GameManager.WILDCARD_REWARD_COUNT,
		"every card handed over is a wildcard (%d of %d)" % [wild, added.size()])
	fails += _check(damage_ok, "every wildcard deals 0 damage")
	fails += _check(colour_ok, "every wildcard carries a real colour")
	return fails


## It must stop at the ceiling instead of blowing past it.
func _check_wildcards_respect_the_deck_ceiling(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	while gm.deck.size() < GameManager.MAX_DECK_SIZE - 1:
		gm.deck.append({"letter": "A", "damage": 1, "color": "red"})
	var pick: int = _index_of(_roll_until(gm, "wildcards"), "wildcards")
	fails += _check(pick >= 0, "WILDCARDS is offered even near the ceiling")
	var result: Dictionary = gm.choose_reward(pick)
	fails += _check(gm.deck.size() == GameManager.MAX_DECK_SIZE,
		"the deck stopped exactly at the ceiling (%d of %d)"
			% [gm.deck.size(), GameManager.MAX_DECK_SIZE])
	# Only ONE slot was left, so only one wildcard may have landed.
	fails += _check((result.get("cards", []) as Array).size() == 1,
		"the reward reported the partial haul (%d)" % (result.get("cards", []) as Array).size())
	fails += _check(str(result.get("message", "")).contains("1 wildcard"),
		"the message says how many actually landed")

	# Completely full: the card-adding option is not offered at all.
	gm.deck.append({"letter": "A", "damage": 1, "color": "red"})
	gm.roll_rewards()
	var types: Array = []
	for reward in gm.get_reward_options():
		types.append(str(reward.get("type", "")))
	fails += _check(not types.has("add_card"), "add_card is not offered at MAX_DECK_SIZE")
	return fails


## A wildcard really does stand in for any letter.
func _check_wildcards_actually_work(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.hand[0] = {"letter": "?", "damage": 0, "color": "green", "is_wildcard": true}
	gm.hand[1] = {"letter": "E", "damage": 3, "color": "red"}
	# The wildcard spells "Z" even though the card itself prints "?".
	var assignment: Array = [
		{"type": "hand", "hand_index": 0, "char": "Z", "card_letter": "?", "is_wildcard": true,
			"damage": 0, "color": "green"},
		{"type": "hand", "hand_index": 1, "char": "E", "card_letter": "E", "is_wildcard": false,
			"damage": 3, "color": "red"}]
	fails += _check(gm.is_assignment_valid("ZE", assignment),
		"a wildcard satisfies a letter it does not print")
	return fails


## The dialog is still a three-way choice.
func _check_option_count_is_still_three(gm: Node) -> int:
	for _i in range(ROLLS):
		var options: Array = gm.roll_rewards()
		if options.size() != 3:
			return _check(false, "each roll offers three options (got %d)" % options.size())
	return _check(true, "every roll offers exactly three options")


func _index_of(options: Array, type: String) -> int:
	for i in range(options.size()):
		if str(options[i].get("type", "")) == type:
			return i
	return -1


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1