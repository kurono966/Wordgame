extends Node

# Smoke test: plays a whole run through GameManager the way Main.gd does, with
# every enemy skill armed, and asserts the invariants that must hold no matter
# what the shuffle hands out.
#   * the preview NEVER mutates state
#   * a preview always agrees with the submit it describes
#   * after any stage clear, no effect of the dead enemy survives

const BIG_WORD: Array = [
	{"type": "hand", "hand_index": 0, "char": "A", "card_letter": "A", "damage": 20, "color": "red"}
]

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame

	fails += _check_previews_never_mutate(gm)
	fails += _check_preview_matches_submit_every_time(gm)
	fails += _check_full_run_stays_clean(gm)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## The forecast is read constantly while a word is being built. If it mutated
## anything, the board would drift under the player's hands.
func _check_previews_never_mutate(gm: Node) -> int:
	var fails: int = 0
	for _i in range(25):
		gm.reset_game()
		var hp: int = gm.player_hp
		var shield: int = gm.shield
		var op: int = gm.operation_points
		var enemy_hp: int = gm.enemy_hp
		var enemy_shield: int = gm.get_enemy_shield()
		var night_tax: int = gm.get_enemy_night_tax()
		var hand_limit: int = gm.get_hand_limit()
		var stage: int = gm.stage
		var hand_size: int = gm.hand.size()
		var skills: int = gm.get_enemy_skills().size()

		gm.predict_submit_outcome(BIG_WORD, [])

		var same: bool = (
			gm.player_hp == hp
			and gm.shield == shield
			and gm.operation_points == op
			and gm.enemy_hp == enemy_hp
			and gm.get_enemy_shield() == enemy_shield
			and gm.get_enemy_night_tax() == night_tax
			and gm.get_hand_limit() == hand_limit
			and gm.stage == stage
			and gm.hand.size() == hand_size
			and gm.get_enemy_skills().size() == skills
		)
		fails += _check(same, "preview left the board untouched (enemy %s)" % gm.get_enemy_name())
	return fails


## The forecast and the real submit must agree, whatever the enemy rolls.
func _check_preview_matches_submit_every_time(gm: Node) -> int:
	var fails: int = 0
	var checked: int = 0
	var saw_skill_fire: int = 0
	for _i in range(40):
		gm.reset_game()
		gm.is_night = false
		gm.shield = 0
		gm.player_hp = gm.PLAYER_MAX_HP
		gm.enemy_max_hp = gm.ENEMY_BASE_HP
		# A big, healthy enemy so BIG_WORD (30 damage) does NOT kill it and the
		# skills actually get their chance to fire.
		gm.enemy_hp = 200
		var enemy: String = gm.get_enemy_name()

		var plan: Dictionary = gm.predict_submit_outcome(BIG_WORD, [])
		var predicted_hp: int = int(plan.get("player_hp_after", -1))
		var predicted_shield: int = int(plan.get("enemy_shield_after", -1))
		var predicted_skills: bool = bool(plan.get("enemy_skills_fire", false))
		if predicted_skills:
			saw_skill_fire += 1

		var res: Dictionary = gm.execute_assignment("A", BIG_WORD)
		# The skill answers at NIGHT, so the submit's own log is always empty and
		# the real answer is whatever the night resolution reports.
		var night: Dictionary = gm.apply_turn_start_penalty()
		checked += 1

		if int(res.get("enemies_defeated_delta", 0)) == 0:
			# The enemy lived, so the night really did resolve, and the preview
			# must have said so, and the numbers must match to the digit.
			fails += _check(predicted_hp == gm.player_hp,
				"preview HP %d == real HP %d (%s)" % [predicted_hp, gm.player_hp, enemy])
			fails += _check(predicted_shield == gm.get_enemy_shield(),
				"preview enemy shield %d == real %d (%s)" % [
					predicted_shield, gm.get_enemy_shield(), enemy])
			fails += _check(predicted_skills == bool(night.get("skill_fired", false)),
				"preview skill-fire flag matches reality (%s)" % enemy)
			fails += _check(bool(night.get("skill_fired", false)) ==
					((night.get("skill_log", []) as Array).size() > 0),
				"a night that fires the skill always narrates it (%s)" % enemy)
		else:
			# A clear must have taken every trace of the old enemy with it.
			fails += _check(gm.get_enemy_shield() == 0,
				"no enemy shield survives a clear (%s)" % enemy)
			fails += _check(gm.get_enemy_night_tax() == 0,
				"no night tax survives a clear (%s)" % enemy)
			fails += _check(gm.get_hand_limit() == gm.HAND_SIZE,
				"the hand limit is restored by a clear (%s)" % enemy)

	fails += _check(checked == 40, "every run was exercised (%d)" % checked)
	fails += _check(saw_skill_fire > 0,
		"at least one non-lethal word woke a skill (%d times)" % saw_skill_fire)
	return fails

## Plays on and on, killing enemies, and re-checks the post-clear invariants
## after every single stage transition.
func _check_full_run_stays_clean(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	var cleared: int = 0
	for _t in range(30):
		gm.is_night = false
		gm.player_hp = gm.PLAYER_MAX_HP
		gm.enemy_max_hp = gm.ENEMY_BASE_HP
		gm.enemy_hp = 5   # one hit from death, so the stage always clears
		var res: Dictionary = gm.execute_assignment("A", BIG_WORD)
		if int(res.get("enemies_defeated_delta", 0)) == 0:
			continue
		cleared += 1
		var where: String = "stage %d" % gm.stage
		fails += _check(gm.get_enemy_shield() == 0, "%s: no enemy shield" % where)
		fails += _check(gm.get_enemy_night_tax() == 0, "%s: no night tax" % where)
		fails += _check(gm.get_hand_limit() == gm.HAND_SIZE, "%s: hand limit restored" % where)
		fails += _check(gm.hand.size() == gm.HAND_SIZE, "%s: hand dealt in full" % where)
		fails += _check(gm.get_enemy_skills().size() == gm.ENEMY_SKILL_COUNT,
			"%s: the new enemy brings its own skills" % where)
		fails += _check(gm.get_enemy_hp() == gm.get_max_enemy_hp(), "%s: new enemy at full HP" % where)
		# Every skill letter must belong to the enemy actually on screen.
		var name_letters: String = gm.get_enemy_name().to_upper()
		for skill: Dictionary in gm.get_enemy_skills():
			fails += _check(name_letters.contains(str(skill.get("letter", ""))),
				"%s: skill letter '%s' belongs to '%s'" % [
					where, str(skill.get("letter", "")), name_letters])
	fails += _check(cleared == 30, "all 30 stage clears happened (%d)" % cleared)
	fails += _check(gm.stage == 31, "the stage counter advanced once per kill (%d)" % gm.stage)
	fails += _check(gm.get_enemies_defeated() == 30,
		"the kill counter matches (%d)" % gm.get_enemies_defeated())
	return fails


func _check(ok: bool, label: String) -> int:
	if ok:
		return 0
	printerr("  FAIL - ", label)
	return 1

