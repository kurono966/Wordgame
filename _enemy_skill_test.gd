extends Node

# Headless test for the enemy-skill system (3 skill letters taken from the
# enemy's own name).
#   * every enemy gets exactly ENEMY_SKILL_COUNT skills, all bound to letters
#     that actually appear in its name
#   * a letter that is not a skill letter wakes nothing
#   * a WILDCARD can never stand in for a skill letter
#   * each skill does what it says (shield / hand limit / OP / night / heal /
#     player damage)
#   * a KILLING blow fires no skill at all
#   * THE BIG ONE: clearing a stage wipes EVERY effect, so nothing leaks into the
#     next fight. HP already lost is deliberately left alone 窶・that is damage the
#     player can heal back.
#   * the submit preview agrees with what really happens

# A 20-damage RED word: it grants no GREEN heal, so any HP the player has lost
# stays lost and the assertions about stage clears are not confounded by it.
# 1 red card = x1.5, so this deals 30 — enough to kill anything under that.
const BIG_WORD: Array = [
	{"type": "hand", "hand_index": 0, "char": "A", "card_letter": "A", "damage": 20, "color": "red"}
]

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame

	fails += _check_every_enemy_has_three_valid_skills(gm)
	fails += _check_safe_letter_wakes_nothing(gm)
	fails += _check_wildcard_never_wakes_a_skill(gm)
	fails += _check_each_skill_does_its_job(gm)
	fails += _check_killing_blow_fires_no_skill(gm)
	fails += _check_stage_clear_wipes_everything(gm)
	fails += _check_damage_taken_is_left_alone(gm)
	fails += _check_preview_matches_reality(gm)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## Forces one specific skill onto a specific letter, so each test can exercise
## exactly one rule instead of hoping the shuffle cooperates.
func _arm(gm: Node, letter: String, skill_id: String, value: int) -> void:
	gm.enemy_skills = [{
		"letter": letter, "id": skill_id, "name": skill_id.to_upper(),
		"icon": "?", "desc": "test", "value": value, "cooldown": 0,
	}]


## DAY phase, full player HP, no shields, and a roomy enemy that survives.
func _setup(gm: Node, enemy_hp: int = 30) -> void:
	gm.reset_game()
	gm.is_night = false
	gm.shield = 0
	gm.player_hp = gm.PLAYER_MAX_HP
	gm.operation_points = 0
	gm.enemy_shield = 0
	gm.enemy_night_tax = 0
	gm.hand_limit = gm.HAND_SIZE
	gm.enemy_max_hp = gm.ENEMY_BASE_HP
	gm.enemy_hp = enemy_hp


## A word made of `letter` only, big enough to hurt but not to kill.
func _word(letter: String, damage: int) -> Array:
	return [{"type": "hand", "hand_index": 0, "char": letter,
		"card_letter": letter, "damage": damage, "color": "green"}]


## A board whose three NEXT cards are all RED, so the night multiplier is x100
## and any NIGHTMARE tax is easy to see.
func _flat_board() -> Array:
	return [
		[{"letter": "A", "damage": 4, "color": "red"},
		 {"letter": "B", "damage": 7, "color": "red"},
		 {"letter": "C", "damage": 9, "color": "red"}],
		[{"letter": "D", "damage": 3, "color": "red"},
		 {"letter": "E", "damage": 2, "color": "red"},
		 {"letter": "F", "damage": 1, "color": "red"}],
		[{"letter": "G", "damage": 5, "color": "red"},
		 {"letter": "H", "damage": 8, "color": "red"},
		 {"letter": "I", "damage": 6, "color": "red"}],
	]


func _check_every_enemy_has_three_valid_skills(gm: Node) -> int:
	var fails: int = 0
	# Roll many enemies: every one must be well formed, not just the lucky ones.
	for _i in range(60):
		_setup(gm)
		var name_letters: String = gm.get_enemy_name().to_upper()
		var skills: Array = gm.get_enemy_skills()
		if skills.size() != gm.ENEMY_SKILL_COUNT:
			fails += _check(false, "enemy %s has %d skills, expected %d" % [
				name_letters, skills.size(), gm.ENEMY_SKILL_COUNT])
			continue
		for skill: Dictionary in skills:
			var letter: String = str(skill.get("letter", ""))
			fails += _check(letter.length() == 1 and name_letters.contains(letter),
				"skill letter '%s' really is a letter of '%s'" % [letter, name_letters])
			fails += _check(not str(skill.get("id", "")).is_empty(),
				"skill on '%s' has an id" % letter)
			fails += _check(int(skill.get("value", 0)) > 0,
				"skill on '%s' has a positive value" % letter)
		# A fresh enemy must never start the fight already handicapped.
		fails += _check(gm.get_hand_limit() == gm.HAND_SIZE,
			"a fresh enemy leaves the hand limit alone")
		fails += _check(gm.get_enemy_shield() == 0, "a fresh enemy has no shield")
	return fails


func _check_safe_letter_wakes_nothing(gm: Node) -> int:
	var fails: int = 0
	_setup(gm)
	# Bind a skill to a letter the word does NOT contain.
	_arm(gm, "B", "aegis", 10)
	gm.execute_assignment("A", _word("A", 5))
	fails += _check(gm.get_enemy_shield() == 0,
		"a word with no skill letter raises no enemy shield")
	return fails


func _check_wildcard_never_wakes_a_skill(gm: Node) -> int:
	var fails: int = 0
	_setup(gm)
	# The enemy guards "A". A wildcard standing in for an A must not trigger it:
	# the card has no letter of the enemy's own to give up.
	_arm(gm, "A", "aegis", 12)
	var wildcard: Array = [{"type": "hand", "hand_index": 0, "char": "A",
		"card_letter": "?", "damage": 5, "color": "green"}]
	gm.execute_assignment("A", wildcard)
	fails += _check(gm.get_enemy_shield() == 0,
		"a wildcard (?) never wakes the enemy's skill")
	fails += _check(gm.get_enemy_skill_for_letter("?").is_empty(),
		"get_enemy_skill_for_letter('?') is empty")
	return fails


func _check_each_skill_does_its_job(gm: Node) -> int:
	var fails: int = 0

	# AEGIS 窶・the enemy gains shield, and that shield really does eat damage.
	_setup(gm)
	_arm(gm, "A", "aegis", 8)
	gm.execute_assignment("A", _word("A", 5))
	fails += _check(gm.get_enemy_shield() == 8, "AEGIS raises 8 shield (%d)" % gm.get_enemy_shield())
	fails += _check(gm.get_enemy_hp() == gm.ENEMY_BASE_HP - 5,
		"AEGIS raised after the hit, so it does not block its own word")
	# Now prove the shield really is damage-first: bank 10, swing for 4.
	# The skill is disarmed first so only the absorption is being measured.
	gm.enemy_skills = []
	gm.enemy_shield = 10
	var hp_before: int = gm.get_enemy_hp()
	gm.execute_assignment("A", _word("A", 4))
	fails += _check(gm.get_enemy_hp() == hp_before,
		"the enemy shield absorbs a small hit before any HP is lost")
	fails += _check(gm.get_enemy_shield() == 6, "the shield is spent down (10 - 4 = 6)")

	# HAND DOWN 窶・the hand shrinks, and never past the floor.
	_setup(gm)
	_arm(gm, "A", "hand_down", 1)
	var hand_before: int = gm.hand.size()
	gm.execute_assignment("A", _word("A", 5))
	fails += _check(gm.get_hand_limit() == gm.HAND_SIZE - 1,
		"HAND DOWN lowers the hand limit by 1 (%d)" % gm.get_hand_limit())
	fails += _check(gm.hand.size() <= gm.get_hand_limit(),
		"the hand itself was trimmed to the new limit (%d <= %d)" % [gm.hand.size(), gm.get_hand_limit()])
	fails += _check(hand_before == gm.HAND_SIZE, "the hand started full")
	# Repeated use stacks, but stops at the floor instead of emptying the hand.
	_arm(gm, "A", "hand_down", 5)
	gm.execute_assignment("A", _word("A", 1))
	fails += _check(gm.get_hand_limit() == gm.ENEMY_MIN_HAND_LIMIT,
		"HAND DOWN never goes below %d cards (%d)" % [gm.ENEMY_MIN_HAND_LIMIT, gm.get_hand_limit()])
	fails += _check(gm.hand.size() <= gm.get_hand_limit(),
		"the hand still holds cards after over-stacking")

	# DRAIN 窶・operation points are taken, and never below zero.
	_setup(gm)
	_arm(gm, "A", "drain", 4)
	gm.operation_points = 10
	gm.execute_assignment("A", _word("A", 5))
	fails += _check(gm.get_operation_points() == 6,
		"DRAIN takes 4 OP (10 -> %d)" % gm.get_operation_points())
	gm.operation_points = 1
	gm.execute_assignment("A", _word("A", 1))
	fails += _check(gm.get_operation_points() == 0,
		"DRAIN never drives OP negative (%d)" % gm.get_operation_points())

	# NIGHTMARE 窶・the night penalty base grows.
	_setup(gm)
	_arm(gm, "A", "nightmare", 6)
	gm.slots = _flat_board()
	gm.current_slot_indices = [0, 0, 0]
	var clean: int = gm.get_next_slot_penalty_with_multiplier([])["base_penalty"]
	gm.execute_assignment("A", _word("A", 5))
	var taxed: int = gm.get_next_slot_penalty_with_multiplier([])["base_penalty"]
	fails += _check(taxed == clean + 6,
		"NIGHTMARE adds 6 to the night base (%d -> %d)" % [clean, taxed])

	# REGROWTH 窶・the enemy patches itself back up, capped at its max HP.
	_setup(gm, 20)
	_arm(gm, "A", "regrow", 5)
	gm.execute_assignment("A", _word("A", 10))
	fails += _check(gm.get_enemy_hp() == 15,
		"REGROWTH heals 5 after the hit (10 -> %d)" % gm.get_enemy_hp())
	gm.enemy_hp = gm.ENEMY_BASE_HP - 1
	gm.execute_assignment("A", _word("A", 1))
	fails += _check(gm.get_enemy_hp() == gm.ENEMY_BASE_HP,
		"REGROWTH never heals past the enemy's max HP (%d)" % gm.get_enemy_hp())

	# THORNS 窶・the player takes damage, and BLUE shield soaks it first.
	_setup(gm)
	_arm(gm, "A", "thorns", 7)
	var php: int = gm.player_hp
	gm.execute_assignment("A", _word("A", 5))
	fails += _check(gm.player_hp == php - 7,
		"THORNS costs the player 7 HP (%d -> %d)" % [php, gm.player_hp])
	_setup(gm)
	_arm(gm, "A", "thorns", 7)
	gm.shield = 4
	php = gm.player_hp
	gm.execute_assignment("A", _word("A", 5))
	fails += _check(gm.player_hp == php - 3,
		"BLUE shield blocks part of THORNS (%d -> %d)" % [php, gm.player_hp])

	return fails


func _check_killing_blow_fires_no_skill(gm: Node) -> int:
	var fails: int = 0
	_setup(gm, 5)
	# Arm EVERY skill at once; none of them may fire.
	gm.enemy_skills = [
		{"letter": "A", "id": "aegis", "name": "AEGIS", "icon": "?", "desc": "", "value": 20, "cooldown": 0},
		{"letter": "A", "id": "thorns", "name": "THORNS", "icon": "?", "desc": "", "value": 20, "cooldown": 0},
		{"letter": "A", "id": "regrow", "name": "REGROWTH", "icon": "?", "desc": "", "value": 20, "cooldown": 0},
		{"letter": "A", "id": "drain", "name": "DRAIN", "icon": "?", "desc": "", "value": 20, "cooldown": 0},
	]
	var php: int = gm.player_hp
	gm.operation_points = 10
	var res: Dictionary = gm.execute_assignment("A", BIG_WORD)
	fails += _check(int(res.get("enemies_defeated_delta", 0)) == 1, "the enemy was defeated")
	fails += _check((res.get("enemy_skill_log", []) as Array).is_empty(),
		"a killing blow fires no enemy skill")
	fails += _check(gm.get_enemy_shield() == 0, "no shield is left on the NEW enemy")
	fails += _check(gm.player_hp == php, "no skill damage on a killing blow")
	fails += _check(gm.get_operation_points() == 10, "no OP drained on a killing blow")
	fails += _check(gm.get_hand_limit() == gm.HAND_SIZE, "the hand limit is untouched")
	return fails


## The headline requirement: nothing an enemy granted may outlive that enemy.
func _check_stage_clear_wipes_everything(gm: Node) -> int:
	var fails: int = 0
	# The enemy must be one hit from death, so BIG_WORD actually clears the stage.
	_setup(gm, 5)
	# Poison the board with every persistent effect the enemy can hand out.
	gm.enemy_shield = 17
	gm.enemy_night_tax = 9
	gm.hand_limit = 4
	var stage_before: int = gm.stage

	var res: Dictionary = gm.execute_assignment("A", BIG_WORD)
	fails += _check(int(res.get("enemies_defeated_delta", 0)) == 1, "the stage was cleared")

	fails += _check(gm.get_enemy_shield() == 0,
		"the enemy shield is GONE after the stage clear (%d)" % gm.get_enemy_shield())
	fails += _check(gm.get_enemy_night_tax() == 0,
		"the night tax is GONE after the stage clear (%d)" % gm.get_enemy_night_tax())
	fails += _check(gm.get_hand_limit() == gm.HAND_SIZE,
		"the hand limit is RESTORED after the stage clear (%d)" % gm.get_hand_limit())
	fails += _check(gm.hand.size() == 7,
		"the hand is dealt back to full size (%d cards)" % gm.hand.size())
	fails += _check(gm.stage == stage_before + 1, "the game moved on to the next stage")

	# And the new enemy arrives clean, with its own fresh set of skills.
	fails += _check(gm.get_enemy_skills().size() == gm.ENEMY_SKILL_COUNT,
		"the next enemy brings its own %d skills" % gm.ENEMY_SKILL_COUNT)
	fails += _check(gm.get_enemy_hp() == gm.get_max_enemy_hp(),
		"the next enemy starts at full HP")

	# The night penalty must be a plain slot sum again: no tax left behind.
	var night: Dictionary = gm.get_next_slot_penalty_with_multiplier([])
	fails += _check(int(night.get("night_tax", -1)) == 0,
		"the night penalty carries no leftover tax (%d)" % int(night.get("night_tax", -1)))
	fails += _check(int(night.get("base_penalty", -1)) == int(night.get("slot_penalty", -2)),
		"night base == raw slot total again (%d vs %d)" % [
			int(night.get("base_penalty", -1)), int(night.get("slot_penalty", -2))])

	# reset_game() must clear them too, not just a stage advance.
	gm.enemy_shield = 12
	gm.enemy_night_tax = 5
	gm.hand_limit = 3
	gm.reset_game()
	fails += _check(gm.get_enemy_shield() == 0, "reset_game clears the enemy shield")
	fails += _check(gm.get_enemy_night_tax() == 0, "reset_game clears the night tax")
	fails += _check(gm.get_hand_limit() == gm.HAND_SIZE, "reset_game restores the hand limit")
	return fails


## Damage the player already took is NOT refunded 窶・that is the one thing that
## must survive the stage clear, because it is recoverable by healing.
func _check_damage_taken_is_left_alone(gm: Node) -> int:
	var fails: int = 0
	_setup(gm, 5)
	gm.shield = 0
	# Hammer the player on the way to the kill.
	gm.is_night = true
	gm.apply_turn_start_penalty()
	var hurt: int = gm.PLAYER_MAX_HP - gm.player_hp
	fails += _check(hurt > 0, "the player actually took damage first (%d)" % hurt)
	gm.is_night = false
	gm.enemy_hp = 5
	gm.execute_assignment("A", BIG_WORD)
	fails += _check(gm.player_hp < gm.PLAYER_MAX_HP,
		"the stage clear did NOT heal the player's wounds (%d / %d)" % [
			gm.player_hp, gm.PLAYER_MAX_HP])
	return fails
## The forecast must describe the enemy skills exactly as a real submit does.
func _check_preview_matches_reality(gm: Node) -> int:
	var fails: int = 0

	# THORNS: preview HP loss == the HP the player really ends the turn with.
	_setup(gm)
	_arm(gm, "A", "thorns", 6)
	gm.is_night = false
	var plan: Dictionary = gm.predict_submit_outcome(_word("A", 5), [])
	gm.execute_assignment("A", _word("A", 5))
	gm.apply_turn_start_penalty()
	fails += _check(int(plan.get("player_hp_after", -1)) == gm.player_hp,
		"THORNS preview HP %d == real HP %d" % [int(plan.get("player_hp_after", -1)), gm.player_hp])
	fails += _check(bool(plan.get("enemy_skills_fire", false)),
		"the preview says the skill fires")

	# AEGIS: the preview must show the shield eating part of the word.
	_setup(gm)
	_arm(gm, "A", "aegis", 30)
	gm.enemy_shield = 10
	var shield_plan: Dictionary = gm.predict_submit_outcome(_word("A", 8), [])
	fails += _check(int(shield_plan.get("enemy_shield_absorbed", -1)) == 8,
		"preview: the existing shield absorbs the whole hit (%d)" % int(shield_plan.get("enemy_shield_absorbed", -1)))
	fails += _check(int(shield_plan.get("enemy_hp_damage", -1)) == 0,
		"preview: no damage reaches the HP")
	fails += _check(int(shield_plan.get("enemy_shield_after", -1)) == 32,
		"preview: AEGIS then stacks on top (10 - 8 + 30 = %d)" % int(shield_plan.get("enemy_shield_after", -1)))

	# A killing blow must be previewed as firing nothing.
	_setup(gm, 5)
	_arm(gm, "A", "thorns", 30)
	var kill_plan: Dictionary = gm.predict_submit_outcome(BIG_WORD, [])
	fails += _check(bool(kill_plan.get("defeats_enemy", false)), "preview sees the kill")
	fails += _check(not bool(kill_plan.get("enemy_skills_fire", false)),
		"preview: a killing blow fires no skill")
	fails += _check(int(kill_plan.get("player_hp_after", -1)) == gm.PLAYER_MAX_HP,
		"preview: a killing blow costs no HP (%d)" % int(kill_plan.get("player_hp_after", -1)))
	return fails


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
