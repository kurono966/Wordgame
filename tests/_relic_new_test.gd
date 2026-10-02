extends Node

# Headless test for the three relics added to the catalogue:
#
#   IRON CORE       shield at the start of each fight, once, not per turn
#   OPENING HAND    2 extra cards in the opening deal ONLY
#   EXPANDED POCKET hand limit +1, composing with the enemy skill HAND DOWN
#
# The two behaviours most likely to rot are checked hardest here:
#   - the battle-timing relics must NOT re-fire on a turn or a word submit
#   - OPENING HAND must never leak into the STANDING hand limit
#
# Relics are granted through grant_relic(), which now rolls at random, so every
# case that needs a specific relic sets the bonus total directly (the same thing
# grant_relic() does for that kind) and then exercises the real game paths.

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame

	fails += _check_catalogue(gm)
	fails += _check_iron_core(gm)
	fails += _check_opening_hand(gm)
	fails += _check_expanded_pocket(gm)
	fails += _check_hand_down_composes(gm)
	fails += _check_grant_flow_works(gm)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## The three requested relics must exist with the exact stated descriptions, and
## every row must be complete enough for the UI to render.
func _check_catalogue(gm: Node) -> int:
	var fails: int = 0
	var by_id: Dictionary = {}
	for def: Dictionary in gm.get_relic_catalogue():
		var id: String = str(def.get("id", ""))
		fails += _check(not id.is_empty(), "every catalogue row has an id")
		fails += _check(not str(def.get("name", "")).is_empty(),
			"'%s' has a name" % id)
		fails += _check(not str(def.get("desc", "")).is_empty(),
			"'%s' has a description" % id)
		fails += _check(int(def.get("amount", 0)) > 0, "'%s' has a positive amount" % id)
		by_id[id] = def
	fails += _check(by_id.has("iron_core"), "IRON CORE is in the catalogue")
	fails += _check(by_id.has("opening_hand"), "OPENING HAND is in the catalogue")
	fails += _check(by_id.has("expanded_pocket"), "EXPANDED POCKET is in the catalogue")
	fails += _check(str(by_id["iron_core"].get("desc", "")) == "戦闘開始時、シールド10を得る。",
		"IRON CORE reads '戦闘開始時、シールド10を得る。'")
	fails += _check(str(by_id["opening_hand"].get("desc", "")) == "戦闘開始時、最初の手札を2枚多く引く。",
		"OPENING HAND reads '戦闘開始時、最初の手札を2枚多く引く。'")
	fails += _check(str(by_id["expanded_pocket"].get("desc", "")) == "手札上限+1。",
		"EXPANDED POCKET reads '手札上限+1。'")
	fails += _check(int(by_id["iron_core"].get("amount", 0)) == 10,
		"IRON CORE is worth 10 shield")
	fails += _check(int(by_id["opening_hand"].get("amount", 0)) == 2,
		"OPENING HAND is worth 2 cards")
	fails += _check(int(by_id["expanded_pocket"].get("amount", 0)) == 1,
		"EXPANDED POCKET is worth +1")
	return fails

## IRON CORE — the spec: with the relic held, the fight opens with shield 10,
## and advancing turns must never top it back up to 10 again.
func _check_iron_core(gm: Node) -> int:
	var fails: int = 0

	# No relic -> no shield.
	gm.reset_game()
	fails += _check(gm.get_shield() == 0, "without IRON CORE a fresh game has no shield")

	# With the relic, the fight opens with exactly 10.
	gm.reset_game()
	gm.relic_shield_bonus = gm.RELIC_SHIELD
	gm._reapply_relic_buffs()
	gm._on_battle_start()
	fails += _check(gm.get_shield() == 10, "IRON CORE gives shield 10 as the fight opens (%d)" % gm.get_shield())

	# Advancing turns must NOT re-apply it. Every turn path is exercised: the
	# night penalty, a word submit, and another turn.
	gm.shield = 0
	gm.apply_turn_start_penalty()
	fails += _check(gm.get_shield() == 0,
		"a turn change does not re-grant IRON CORE's shield (%d)" % gm.get_shield())
	gm.set_enemy_name("DRAGON")
	gm.enemy_hp = 9999
	gm.execute_assignment("DRIFT", _word("DRIFT"))
	fails += _check(gm.get_shield() == 0,
		"a word submit does not re-grant IRON CORE's shield (%d)" % gm.get_shield())
	for _i in range(3):
		gm.apply_turn_start_penalty()
	fails += _check(gm.get_shield() == 0,
		"several turns later it is still not re-granted (%d)" % gm.get_shield())

	# It pays out again at the START of the next fight, and only there.
	gm.enemy_hp = 1
	gm.execute_assignment("DRAGON", _word("DRAGON", 500))
	gm.flush_pending_hand_redraw()
	fails += _check(gm.get_shield() == 10,
		"the next fight opens with shield 10 again (%d)" % gm.get_shield())

	# Two copies stack, matching the existing duplicate behaviour.
	gm.reset_game()
	gm.relic_shield_bonus = 2 * gm.RELIC_SHIELD
	gm._reapply_relic_buffs()
	gm._on_battle_start()
	fails += _check(gm.get_shield() == 20, "two IRON COREs give 20 shield (%d)" % gm.get_shield())
	return fails


## OPENING HAND — 9 cards instead of 7 on the opening deal, and NOT a standing
## +2 from turn 2 onward.
func _check_opening_hand(gm: Node) -> int:
	var fails: int = 0

	# Baseline: no relic, opening hand is the normal 7.
	gm.reset_game()
	fails += _check(gm.get_hand().size() == 7,
		"without OPENING HAND the opening hand is 7 (%d)" % gm.get_hand().size())

	# With the relic already held, the opening deal is 9. The bonus has to be set
	# BEFORE the hand is dealt, which is how it really works: you cannot take a
	# relic mid-deal. reset_game() is therefore re-run after seeding the total.
	gm.reset_game()
	gm.relic_opening_bonus = gm.RELIC_OPENING_HAND
	gm._reapply_relic_buffs()
	gm._reset_hand()
	fails += _check(gm.get_hand().size() == 9,
		"with OPENING HAND the opening hand is 9 (%d)" % gm.get_hand().size())

	# The extra cards must be REAL cards, not empty slots.
	var filled: int = 0
	for card: Variant in gm.get_hand():
		if card != null:
			filled += 1
	fails += _check(filled == 9, "all 9 opening cards are real cards (%d)" % filled)

	# The STANDING limit is untouched — this is the whole point of the relic.
	fails += _check(gm.get_hand_limit() == 7,
		"the hand limit is still 7, not 9 (%d)" % gm.get_hand_limit())
	fails += _check(gm.get_hand_limit() != gm.HAND_SIZE + gm.RELIC_OPENING_HAND,
		"OPENING HAND did not turn into a permanent +2 hand limit")

	# Turn 2 must not deal 2 more. A submit refills, so the hand shrinks back
	# toward the limit rather than growing.
	var size_before: int = gm.get_hand().size()
	gm.set_enemy_name("DRAGON")
	gm.enemy_hp = 9999
	gm.execute_assignment("DRIFT", _word("DRIFT"))
	fails += _check(gm.get_hand().size() <= size_before,
		"a later turn does not add 2 more cards (%d -> %d)" % [size_before, gm.get_hand().size()])
	fails += _check(gm.get_hand_limit() == 7,
		"the hand limit is still 7 on turn 2 (%d)" % gm.get_hand_limit())

	# The next fight's opening deal includes the bonus again — that is the rule.
	gm.enemy_hp = 1
	gm.execute_assignment("DRAGON", _word("DRAGON", 500))
	gm.flush_pending_hand_redraw()
	fails += _check(gm.get_hand().size() == 9,
		"the next fight also opens with 9 (%d)" % gm.get_hand().size())
	fails += _check(gm.get_hand_limit() == 7,
		"and the standing limit is still 7 (%d)" % gm.get_hand_limit())
	return fails

## EXPANDED POCKET — hand limit 8 instead of 7, held for the whole run.
func _check_expanded_pocket(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	fails += _check(gm.get_hand_limit() == 7, "without the relic the limit is 7 (%d)" % gm.get_hand_limit())

	gm.relic_hand_bonus = gm.RELIC_HAND
	gm._reapply_relic_buffs()
	fails += _check(gm.get_hand_limit() == 8, "with EXPANDED POCKET the limit is 8 (%d)" % gm.get_hand_limit())

	# It is a STANDING bonus, so it survives turns and stage changes.
	for _i in range(3):
		gm.apply_turn_start_penalty()
	fails += _check(gm.get_hand_limit() == 8, "turn changes keep it at 8 (%d)" % gm.get_hand_limit())
	for _i in range(3):
		gm._advance_stage()
	fails += _check(gm.get_hand_limit() == 8, "stage changes keep it at 8 (%d)" % gm.get_hand_limit())

	# A reward claim re-derives the limit too, and must not drop the bonus.
	gm.roll_rewards()
	for i in range(gm.reward_options.size()):
		if str(gm.reward_options[i].get("type", "")) in ["remove_card", "shield"]:
			gm.reward_options[i] = {"type": "heal", "title": "VITALITY", "detail": ""}
	for i in range(gm.get_reward_options().size()):
		if str(gm.get_reward_options()[i].get("type", "")) == "heal":
			gm.choose_reward(i)
			break
	fails += _check(gm.get_hand_limit() == 8, "claiming a reward keeps it at 8 (%d)" % gm.get_hand_limit())

	# Two copies really are +2.
	gm.relic_hand_bonus = 2 * gm.RELIC_HAND
	gm._reapply_relic_buffs()
	fails += _check(gm.get_hand_limit() == 9, "two EXPANDED POCKETs give 9 (%d)" % gm.get_hand_limit())
	return fails


## The spec's exact composition case:
##     base 7 + EXPANDED POCKET +1 + HAND DOWN -1 == 7
## i.e. the two effects must ADD, never overwrite one another.
func _check_hand_down_composes(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	fails += _check(gm.get_hand_limit() == 7, "baseline limit is 7")

	# EXPANDED POCKET alone.
	gm.relic_hand_bonus = gm.RELIC_HAND
	gm._reapply_relic_buffs()
	fails += _check(gm.get_hand_limit() == 8, "with EXPANDED POCKET alone it is 8")

	# HAND DOWN fires: it shrinks the live limit from 8, exactly as before.
	gm.hand_limit = maxi(gm.ENEMY_MIN_HAND_LIMIT, gm.hand_limit - 1)
	fails += _check(gm.get_hand_limit() == 7,
		"7 + EXPANDED POCKET + HAND DOWN == 7 (%d)" % gm.get_hand_limit())

	# A stage clear wipes the enemy effect but NOT the relic: back to 8.
	gm._advance_stage()
	fails += _check(gm.get_hand_limit() == 8,
		"the stage clear restores 8 and keeps the relic (%d)" % gm.get_hand_limit())

	# Without the relic the same enemy effect still lands on the plain base.
	gm.relic_hand_bonus = 0
	gm._reapply_relic_buffs()
	fails += _check(gm.get_hand_limit() == 7, "removing the relic returns to 7 (%d)" % gm.get_hand_limit())
	gm.hand_limit = maxi(gm.ENEMY_MIN_HAND_LIMIT, gm.hand_limit - 1)
	fails += _check(gm.get_hand_limit() == 6, "HAND DOWN alone still bites (7 -> 6) (%d)" % gm.get_hand_limit())
	return fails


## The relics must still be earned the way they were: a total part destruction,
## granted through the existing flow, picking from the catalogue at random.
func _check_grant_flow_works(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_enemy_name("DRAGON")
	gm.enemy_hp = 9999
	# One part is not a defeat.
	gm.execute_assignment("DRIFT", _word("DRIFT"))
	fails += _check(gm.get_relic_count() == 0, "breaking one part still grants no relic")

	# The full name destroys the enemy and pays exactly one relic, drawn from the
	# catalogue, with a description the UI can show.
	var result: Dictionary = gm.execute_assignment("DRAGON", _word("DRAGON"))
	fails += _check(bool(result.get("part_defeat", false)), "the total destruction still happens")
	fails += _check(gm.get_relic_count() == 1, "and pays exactly one relic (%d)" % gm.get_relic_count())
	var held: Array = gm.get_relics()
	if held.size() == 1:
		var r: Dictionary = held[0]
		var id: String = str(r.get("id", ""))
		fails += _check(id == "iron_core" or id == "opening_hand" or id == "expanded_pocket"
				or id == "vessel" or id == "insight",
			"the granted relic comes from the catalogue (%s)" % id)
		fails += _check(not str(r.get("desc", "")).is_empty(),
			"the granted relic carries its description")
		fails += _check(gm.get_relic_count_of(id) == 1, "get_relic_count_of finds it")
	# The bonus summary reflects it.
	fails += _check(gm.get_relic_bonus_text() != "none yet",
		"the summary names the new buff (%s)" % gm.get_relic_bonus_text())
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
