extends Node

# Headless test for the enemy-part system: the enemy name is also read as a
# BODY, sliced into a few non-overlapping 2+ letter parts, and any part the
# player spells inside a submitted word is destroyed. Destroying EVERY part kills
# the enemy outright, whatever its HP, and pays a relic on top of the normal
# stage reward. A plain HP kill is untouched: no relic, no part destruction.
#
#     DRAGON -> DR / AG / ON        SLIME -> SL / IME
#     STONE  -> ST / ONE            CAT    -> CAT   (too short to cut)
#
# The submit flow reads the part matches BEFORE the damage resolves, because a
# word that brings the enemy to 0 HP is a plain kill and must not pay a relic.
# Nearly every case below is a real execute_assignment() submit, not a direct
# call into the part helpers, so that ordering is covered too.

const NAME: String = "DRAGON"

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame
	gm.reset_game()

	# ===== How the name is cut into parts ==============================
	fails += _check_parts_cut(gm)
	fails += _check_parts_tile_the_name(gm)

	# ===== TEST 1: DRIFT breaks DR only ================================
	fails += _check_test1_drift_breaks_dr(gm)
	# ===== TEST 2: DRIFT again changes nothing =========================
	fails += _check_test2_repeat_is_a_no_op(gm)
	# ===== TEST 3: AGENT breaks AG =====================================
	fails += _check_test3_agent_breaks_ag(gm)
	# ===== TEST 4: ONCE finishes the enemy off, HP and all =============
	fails += _check_test4_total_destruction(gm)
	# ===== TEST 5: HP 0 is a plain kill, no relic ======================
	fails += _check_test5_hp_kill_is_plain(gm)
	# ===== TEST 6: a match shorter than a part breaks nothing ==========
	fails += _check_test6_short_match_ignored(gm)
	# ===== TEST 7: letters apart never join up =========================
	fails += _check_test7_split_letters_ignored(gm)
	# ===== TEST 8: the next enemy starts whole =========================
	fails += _check_test8_new_enemy_is_fresh(gm)
	# ===== TEST 9: one word, several parts =============================
	fails += _check_test9_multi_part_word(gm)

	# ===== The preview must never promise a break the submit won't make =
	fails += _check_preview_matches_reality(gm)
	# ===== Enemy skills are untouched by part destruction ===============
	fails += _check_skills_unaffected(gm)
	# ===== The parts follow whichever enemy is on the board =============
	fails += _check_parts_follow_the_enemy(gm)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)

## The name is sliced left to right in 2-letter chunks, and a 1-letter tail is
## folded backwards so no part is ever a single letter.
func _check_parts_cut(gm: Node) -> int:
	var fails: int = 0
	fails += _check(_texts(gm.build_enemy_parts("DRAGON")) == ["DR", "AG", "ON"],
		"DRAGON is cut into DR / AG / ON")
	fails += _check(_texts(gm.build_enemy_parts("SLIME")) == ["SL", "IME"],
		"a 1-letter tail folds into the slice before it (SLIME -> SL / IME)")
	fails += _check(_texts(gm.build_enemy_parts("STONE")) == ["ST", "ONE"],
		"STONE is cut into ST / ONE")
	fails += _check(_texts(gm.build_enemy_parts("PHOENIX")) == ["PH", "OE", "NIX"],
		"PHOENIX is cut into PH / OE / NIX")
	fails += _check(_texts(gm.build_enemy_parts("CAT")) == ["CAT"],
		"a 3-letter name is a single part")
	# The whole point of slicing: never one part per substring, and never so
	# many that the player cannot hold the body in their head.
	fails += _check(gm.build_enemy_parts("DRAGON").size() == 3,
		"DRAGON has 3 parts, not one per substring (which would be 14)")
	fails += _check(gm.build_enemy_parts("PHOENIX").size() == 3,
		"PHOENIX has 3 parts, not 21")
	for n: String in ["CAT", "DRAGON", "BANSHEE", "PHOENIX", "XYZZY"]:
		var parts: Array = gm.build_enemy_parts(n)
		fails += _check(parts.size() >= 1 and parts.size() <= 4,
			"'%s' has a readable 1-4 parts (%d)" % [n, parts.size()])
	return fails


## Every part is 2+ letters and the parts tile the name exactly — which is what
## makes "no letter is ever consumed twice" true by construction.
func _check_parts_tile_the_name(gm: Node) -> int:
	var fails: int = 0
	for n: String in ["CAT", "DRIFT", "DRAGON", "BANSHEE", "PHOENIX", "MANTIS"]:
		var parts: Array = gm.build_enemy_parts(n)
		var joined: String = ""
		var min_len: int = 99
		for p: Dictionary in parts:
			var t: String = str(p.get("text", ""))
			joined += t
			min_len = mini(min_len, t.length())
		fails += _check(joined == n.to_upper(),
			"'%s' parts spell the whole name back (%s)" % [n, joined])
		fails += _check(min_len >= gm.PART_MIN_LEN,
			"'%s' has no part shorter than %d letters" % [n, gm.PART_MIN_LEN])
	return fails


## TEST 1 — DRIFT spells DR, so DR breaks and AG / ON are untouched.
func _check_test1_drift_breaks_dr(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_enemy_name(NAME)
	gm.enemy_hp = 9999
	var result: Dictionary = gm.execute_assignment("DRIFT", _word("DRIFT"))
	fails += _check(result.get("parts_broken", []) == ["DR"],
		"DRIFT breaks exactly one part, DR (got %s)" % str(result.get("parts_broken", [])))
	fails += _check(gm.is_part_broken("DR"), "DR is marked broken")
	fails += _check(not gm.is_part_broken("AG"), "AG survives DRIFT")
	fails += _check(not gm.is_part_broken("ON"), "ON survives DRIFT")
	fails += _check(int(result.get("enemies_defeated_delta", 0)) == 0,
		"breaking one part does not kill the enemy")
	return fails


## TEST 2 — the same word again must not re-break DR or count it twice.
func _check_test2_repeat_is_a_no_op(gm: Node) -> int:
	var fails: int = 0
	var before: int = gm.get_broken_part_count()
	var result: Dictionary = gm.execute_assignment("DRIFT", _word("DRIFT"))
	fails += _check(result.get("parts_broken", []).is_empty(),
		"a part already broken is never re-broken by the same word")
	fails += _check(gm.get_broken_part_count() == before,
		"the broken-part count did not move (%d -> %d)" % [before, gm.get_broken_part_count()])
	fails += _check(int(result.get("enemies_defeated_delta", 0)) == 0,
		"re-spelling a broken part does not kill the enemy")
	return fails


## TEST 3 — AGENT spells AG, so AG breaks and ON is still standing.
func _check_test3_agent_breaks_ag(gm: Node) -> int:
	var fails: int = 0
	var result: Dictionary = gm.execute_assignment("AGENT", _word("AGENT"))
	fails += _check(result.get("parts_broken", []) == ["AG"],
		"AGENT breaks exactly AG (got %s)" % str(result.get("parts_broken", [])))
	fails += _check(not gm.is_part_broken("ON"), "ON is still standing after AGENT")
	fails += _check(gm.get_broken_part_count() == 2,
		"two of three parts are down (%d)" % gm.get_broken_part_count())
	return fails

## TEST 4 — ONCE spells the last part: the enemy dies with HP to spare, and the
## relic is paid. The shared defeat path must have run too, so the stage moved
## on exactly as it does for a damage kill.
func _check_test4_total_destruction(gm: Node) -> int:
	var fails: int = 0
	var stage_before: int = gm.get_stage()
	var defeated_before: int = gm.get_enemies_defeated()
	var relics_before: int = gm.get_relic_count()
	gm.enemy_hp = 87          # deliberately NOT a lethal amount
	gm.enemy_max_hp = 100

	var result: Dictionary = gm.execute_assignment("ONCE", _word("ONCE"))

	fails += _check(bool(result.get("part_defeat", false)),
		"breaking the last part is a total destruction")
	fails += _check(int(result.get("enemies_defeated_delta", 0)) == 1,
		"the enemy is defeated by the part destruction")
	fails += _check(gm.get_enemies_defeated() == defeated_before + 1,
		"the defeat counter moved on")
	fails += _check(gm.get_stage() == stage_before + 1,
		"the stage advanced through the shared _advance_stage() path")
	fails += _check(int(result.get("enemy_hp_before", 0)) == 87,
		"the enemy was still standing on 87 / 100 HP when the last part fell")
	fails += _check(int(result.get("enemy_hp_at_part_defeat", 0)) == 87,
		"the word itself took no HP away — the parts did the killing")
	fails += _check(int(result.get("final_damage", -1)) == 0,
		"and the word dealt 0 damage, so the HP total was never what killed it")
	fails += _check(gm.get_relic_count() == relics_before + 1,
		"a total destruction pays exactly one relic")
	fails += _check(not result.get("relic", {}).is_empty(),
		"the result carries the granted relic for the UI to narrate")
	fails += _check(str(result.get("relic", {}).get("from_enemy", "")) == NAME,
		"the relic records which enemy it came from")
	# A part destruction ends the fight, so that turn's NIGHT self-damage is
	# waived exactly like a normal kill.
	fails += _check(bool(gm.stage_cleared_immune),
		"the NIGHT penalty is waived on the turn the enemy was torn apart")
	return fails


## TEST 5 — driving the HP to 0 stays a plain kill: no relic, no part
## destruction, even when the word also happens to spell every part.
func _check_test5_hp_kill_is_plain(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_enemy_name(NAME)
	var relics_before: int = gm.get_relic_count()
	var defeated_before: int = gm.get_enemies_defeated()
	gm.enemy_hp = 3
	gm.enemy_max_hp = 100

	# A huge word that spells DRAGON (so all three parts DO match) and one-shots
	# the HP. The damage route wins, exactly as the rules require.
	var result: Dictionary = gm.execute_assignment("DRAGON", _word("DRAGON", 500))

	fails += _check(int(result.get("enemies_defeated_delta", 0)) == 1,
		"a lethal word still defeats the enemy")
	fails += _check(not bool(result.get("part_defeat", false)),
		"a word that killed by HP is NOT a total destruction")
	fails += _check(gm.get_relic_count() == relics_before,
		"a plain HP kill pays no relic")
	fails += _check(gm.get_enemies_defeated() == defeated_before + 1,
		"the plain kill advanced the stage as usual")
	return fails


## TEST 6 — a match shorter than a whole part breaks nothing. DR is 2 letters,
## so a lone D is not a match, and a word must spell the part in full.
func _check_test6_short_match_ignored(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_enemy_name(NAME)
	gm.enemy_hp = 9999
	# "DOG" shares D, O and G with DRAGON, but never two of them side by side.
	var result: Dictionary = gm.execute_assignment("DOG", _word("DOG"))
	fails += _check(result.get("parts_broken", []).is_empty(),
		"a word sharing letters but never a whole part breaks nothing")
	fails += _check(gm.get_broken_part_count() == 0, "no part is down after DOG")
	fails += _check(gm.get_broken_part_count() < gm.all_parts_broken_count(),
		"the enemy is not considered destroyed")
	# The comparison is case-insensitive, exactly like the rest of the word
	# checks, so a lower-case name in the data would behave identically.
	fails += _check(gm.match_parts_in_word("drift") == ["DR"],
		"a lower-case word still matches a part")
	return fails

## TEST 7 — the letters of a part must be CONTIGUOUS in the word. DEAR has a D,
## an A and an R, but the D and the R are not adjacent, so no part of DRAGON is
## spelled. DRIFT, with the same letters side by side, does break DR.
func _check_test7_split_letters_ignored(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_enemy_name(NAME)
	gm.enemy_hp = 9999
	var result: Dictionary = gm.execute_assignment("DEAR", _word("DEAR"))
	fails += _check(result.get("parts_broken", []).is_empty(),
		"letters that are not adjacent never form a part")
	fails += _check(gm.get_broken_part_count() == 0, "no part is down after DEAR")
	# The mirror image: the SAME letters, adjacent, do break the part.
	var ok: Dictionary = gm.execute_assignment("DRIFT", _word("DRIFT"))
	fails += _check(ok.get("parts_broken", []) == ["DR"],
		"the same letters side by side DO break the part")
	return fails


## TEST 8 — the parts belong to one enemy. The next enemy must start whole, and
## a part broken on the old name must not follow the player.
func _check_test8_new_enemy_is_fresh(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_enemy_name(NAME)
	gm.enemy_hp = 9999
	gm.execute_assignment("DRIFT", _word("DRIFT"))   # DR broken
	fails += _check(gm.get_broken_part_count() == 1, "DR is broken on the first enemy")

	# Kill this one outright, which rolls a new name and a new body.
	gm.enemy_hp = 1
	var result: Dictionary = gm.execute_assignment("DRAGON", _word("DRAGON", 500))
	fails += _check(int(result.get("enemies_defeated_delta", 0)) == 1,
		"the first enemy was defeated")
	fails += _check(gm.get_broken_part_count() == 0,
		"the next enemy starts with every part intact (%d broken)" % gm.get_broken_part_count())
	fails += _check(not gm.all_parts_broken(),
		"the new enemy is not born destroyed")
	# The new name's own parts are what the board now shows.
	var expected: Array = _texts(gm.get_enemy_parts())
	fails += _check("".join(expected) == gm.get_enemy_name().to_upper(),
		"the new enemy's parts spell its new name (%s)" % gm.get_enemy_name())
	return fails


## TEST 9 — one word can break several parts at once. DRAGON spells all three of
## DR / AG / ON, so submitting the whole name tears the enemy apart in one go.
func _check_test9_multi_part_word(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_enemy_name(NAME)
	var stage_before: int = gm.get_stage()
	gm.enemy_hp = 9999

	var result: Dictionary = gm.execute_assignment("DRAGON", _word("DRAGON", 0))
	var broken: Array = result.get("parts_broken", [])
	fails += _check(broken.size() == 3,
		"DRAGON breaks all three parts in one word (got %d)" % broken.size())
	fails += _check(broken.has("DR") and broken.has("AG") and broken.has("ON"),
		"each of DR, AG and ON is reported exactly once (%s)" % str(broken))
	fails += _check(bool(result.get("part_defeat", false)),
		"breaking all three parts at once destroys the enemy")
	fails += _check(gm.get_stage() == stage_before + 1,
		"the enemy was defeated and the stage advanced")
	return fails

## The preview runs the same matcher as the submit, so it can neither promise a
## break that will not happen nor miss one that will.
func _check_preview_matches_reality(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_enemy_name(NAME)
	gm.enemy_hp = 9999

	# Preview of a word that breaks one part: it must not claim a defeat.
	var partial: Array = _word("DRIFT")
	var plan: Dictionary = gm.predict_submit_outcome(partial, [])
	fails += _check(plan.get("parts_broken", []) == ["DR"],
		"the preview reports the part the word breaks")
	fails += _check(not bool(plan.get("defeats_enemy", false)),
		"the preview does not claim a defeat for one part")
	# The submit agrees with it.
	var result: Dictionary = gm.execute_assignment("DRIFT", partial)
	fails += _check(plan.get("parts_broken", []) == result.get("parts_broken", []),
		"preview and submit break the same parts")

	# Preview of the last part: it MUST claim the defeat, even though the HP is
	# nowhere near 0 — the whole point of a total destruction. Two parts are down
	# first, so ONCE really is the word that finishes the job.
	var second: Array = _word("AGENT")
	gm.execute_assignment("AGENT", second)
	fails += _check(gm.get_broken_part_count() == 2,
		"two of three parts are down before the last word")
	var last: Array = _word("ONCE")
	var plan2: Dictionary = gm.predict_submit_outcome(last, [])
	fails += _check(plan2.get("parts_broken", []) == ["ON"],
		"the preview sees the final part in the word")
	fails += _check(bool(plan2.get("part_defeat", false)),
		"the preview foresees the total destruction")
	fails += _check(bool(plan2.get("defeats_enemy", false)),
		"the preview reports the enemy as defeated with HP to spare")
	fails += _check(int(plan2.get("enemy_hp_after", 0)) > 0,
		"and the enemy's HP really is still above 0 (%d)" % int(plan2.get("enemy_hp_after", 0)))
	# And the submit agrees.
	var last_result: Dictionary = gm.execute_assignment("ONCE", last)
	fails += _check(bool(last_result.get("part_defeat", false)),
		"the submit really does destroy the enemy the preview promised")
	fails += _check(int(last_result.get("enemy_hp_at_part_defeat", 0)) == 9999,
		"the enemy fell on 9999 HP — the HP total was never consulted")
	return fails


## Part destruction is a separate system: the enemy's skill card, its AEGIS
## shield and its hand limit must be untouched by it, and must still be wiped by
## the shared stage clear.
func _check_skills_unaffected(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_enemy_name(NAME)
	var skill_letter: String = ""
	if not gm.get_enemy_skills().is_empty():
		skill_letter = str(gm.get_enemy_skills()[0].get("letter", ""))
	gm.enemy_shield = 5
	gm.enemy_hp = 9999

	var result: Dictionary = gm.execute_assignment("DRIFT", _word("DRIFT"))
	fails += _check(result.get("parts_broken", []) == ["DR"],
		"breaking a part still works with an enemy skill present")
	fails += _check(gm.get_enemy_shield() == 5,
		"breaking a part does not touch the enemy's AEGIS shield (%d)" % gm.get_enemy_shield())
	fails += _check(gm.get_enemy_hp() > 0, "the enemy is still alive, skill and all")
	if skill_letter != "":
		fails += _check(str(gm.get_enemy_skills()[0].get("letter", "")) == skill_letter,
			"the enemy's skill card is unchanged by a part break")

	# Now tear the enemy apart: the shared stage clear must wipe the skill, the
	# shield and the hand limit, exactly as a damage kill does.
	for w: String in ["AGENT", "ONCE"]:
		gm.execute_assignment(w, _word(w))
	fails += _check(gm.get_enemy_shield() == 0,
		"a part destruction wipes the fallen enemy's shield like a normal kill")
	fails += _check(gm.get_hand_limit() == gm.HAND_SIZE,
		"a part destruction restores the hand limit like a normal kill")
	return fails


## The parts are always cut from whichever enemy is on the board, so a name
## swapped in by any route re-cuts them too.
func _check_parts_follow_the_enemy(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_enemy_name("STONE")
	fails += _check(_texts(gm.get_enemy_parts()) == ["ST", "ONE"],
		"switching the enemy re-cuts the parts (STONE -> ST / ONE)")
	gm.enemy_hp = 9999
	var result: Dictionary = gm.execute_assignment("STONE", _word("STONE", 0))
	fails += _check(result.get("parts_broken", []) == ["ST", "ONE"],
		"spelling a whole name breaks all of its own parts")
	fails += _check(bool(result.get("part_defeat", false)),
		"a name that spells its own parts destroys the enemy")
	return fails


## A ready-made assignment for `word` with `damage` on every card. The colours
## are irrelevant here (no RED in any of them), so damage is the only thing that
## matters; the "hand_index" values are never read back by these tests.
func _word(word: String, damage: int = 0) -> Array:
	var out: Array = []
	for i in range(word.length()):
		out.append({"type": "hand", "hand_index": i, "char": word[i],
			"card_letter": word[i], "is_wildcard": false,
			"damage": damage, "color": "green"})
	return out


func _texts(parts: Array) -> Array:
	var out: Array = []
	for p: Dictionary in parts:
		out.append(str(p.get("text", "")))
	return out


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
