extends Node

# Headless test for the enemy-skill system (ONE skill card on the shared reels).
#   * every enemy gets exactly ENEMY_SKILL_COUNT skills, all bound to letters
#     that actually appear in its name
#   * THE HEADLINE RULE: the skill fires at NIGHT while its card sits in the
#     BOTTOM row of a reel. Spelling the letter does nothing; a DAY turn does
#     nothing; only the card's POSITION at night matters
#   * each skill does what it says (shield / hand limit / OP / night / heal /
#     player damage), and that damage runs through the same shield-then-HP
#     pipeline as every other hit on the player
#   * a stage clear ends the fight, so a defeated enemy never answers
#   * THE BIG ONE: clearing a stage wipes EVERY effect, so nothing leaks into the
#     next fight. HP already lost is deliberately left alone — that is damage the
#     player can heal back.
#   * the submit preview agrees with what really happens at night

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

	fails += _check_every_enemy_has_valid_skills(gm)
	fails += _check_safe_letter_wakes_nothing(gm)
	fails += _check_position_is_the_trigger(gm)
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


## A three-reel board where the skill card sits in EXACTLY one known spot, and
## every other card is an inert filler. `index` is the card's position inside
## that reel (0 = top, 1 = centre, 2 = bottom once the reel is parked).
## The cards are deliberately spread across different colours: the night
## multiplier is 10^(largest same-colour group - 1), so an all-red board would
## charge a 100x penalty and drown out whatever the test is actually measuring.
func _board_with_skill_at(letter: String, reel: int, index: int) -> Array:
	var colours: Array = ["red", "blue", "green"]
	var board: Array = []
	for s in range(3):
		var row_cards: Array = []
		for i in range(3):
			if s == reel and i == index:
				row_cards.append({"letter": letter, "damage": 1, "color": colours[i]})
			else:
				# Filler letters that can never be the skill, so a stray match is
				# impossible and the assertions stay unambiguous.
				row_cards.append({"letter": "V", "damage": 1, "color": colours[i]})
		board.append(row_cards)
	return board


## Parks the reels so the card sitting at `index` inside `reel` lands in display
## row `row` (0 = top, 1 = centre, 2 = bottom), without running a whole turn.
## The inverse of the display mapping used by _refresh_slots:
##   row 0 (top)    = index (cur + 2) % 3
##   row 1 (centre) = index cur
##   row 2 (bottom) = index (cur + 1) % 3
func _point_at_skill(gm: Node, reel: int, index: int, row: int) -> void:
	gm.current_slot_indices = [0, 0, 0]
	gm.current_slot_indices[reel] = (index - row + 1 + 6) % 3


func _check_every_enemy_has_valid_skills(gm: Node) -> int:
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
	# Arm a skill and park its card in the CENTRE row, then submit: the letter is
	# in the word, but the card is not in the firing line, so nothing may happen.
	_arm(gm, "B", "aegis", 10)
	gm.slots = _board_with_skill_at("B", 0, 0)
	_point_at_skill(gm, 0, 0, 1)  # centre row, not the bottom one
	gm.is_night = false
	gm.execute_assignment("A", _word("A", 5))
	fails += _check(gm.get_enemy_shield() == 0,
		"submitting alone fires nothing (%d shield)" % gm.get_enemy_shield())
	return fails


## THE HEADLINE RULE: the card's POSITION decides, not the letters in the word.
func _check_position_is_the_trigger(gm: Node) -> int:
	var fails: int = 0

	# BOTTOM row at NIGHT: fires, even though the word never touches the letter.
	# No execute_assignment here on purpose: submitting would rotate the reels and
	# move the card out of the firing line before night ever arrives.
	_setup(gm)
	_arm(gm, "B", "aegis", 10)
	gm.slots = _board_with_skill_at("B", 0, 0)
	_point_at_skill(gm, 0, 0, 2)  # bottom row = in the firing line
	gm.is_night = true
	var fired: Dictionary = gm.apply_turn_start_penalty()
	fails += _check(bool(fired.get("skill_fired", false)),
		"the skill fires at NIGHT with its card in the BOTTOM row")
	fails += _check(gm.get_enemy_shield() == 10,
		"AEGIS applied (10 shield, got %d)" % gm.get_enemy_shield())
	fails += _check(not str(fired.get("skill_log", [])[0] if (fired.get("skill_log", []) as Array).size() > 0 else "").is_empty(),
		"the night result narrates the skill")

	# BOTTOM row but DAY phase: does NOT fire.
	_setup(gm)
	_arm(gm, "B", "aegis", 10)
	gm.slots = _board_with_skill_at("B", 0, 0)
	_point_at_skill(gm, 0, 0, 2)
	gm.is_night = false
	var day: Dictionary = gm.apply_turn_start_penalty()
	fails += _check(not bool(day.get("skill_fired", true)),
		"the skill never fires during the DAY")

	# BOTTOM row at NIGHT, but the card is NOT the skill letter: silent.
	_setup(gm)
	_arm(gm, "B", "aegis", 10)
	gm.slots = _board_with_skill_at("B", 0, 0)
	_point_at_skill(gm, 1, 0, 2)  # a filler reel is in the firing line instead
	gm.is_night = true
	var wrong: Dictionary = gm.apply_turn_start_penalty()
	fails += _check(not bool(wrong.get("skill_fired", true)),
		"a filler card in the bottom row fires nothing")

	# Spelling the letter in a word does NOT wake the skill any more. The word
	# comes from the hand, so no reel rotates, and the card stays parked in the
	# top row while the submit flips the phase to NIGHT.
	_setup(gm)
	_arm(gm, "B", "aegis", 10)
	gm.slots = _board_with_skill_at("B", 0, 0)
	_point_at_skill(gm, 0, 0, 0)  # top row: safe
	gm.is_night = false
	gm.execute_assignment("B", _word("B", 1))
	fails += _check(gm.get_phase() == "NIGHT", "the submit turned the phase to NIGHT")
	var spelled: Dictionary = gm.apply_turn_start_penalty()
	fails += _check(not bool(spelled.get("skill_fired", true)),
		"spelling the skill letter while the card is SAFE fires nothing")

	# A "?" wildcard is never the skill letter, so it cannot hold the card.
	fails += _check(gm.get_enemy_skill_for_letter("?").is_empty(),
		"get_enemy_skill_for_letter('?') is empty")
	fails += _check(not gm.is_enemy_skill_letter("?"),
		"a wildcard is never a skill letter")
	return fails


## Every skill is exercised through the real trigger: the card parked in a
## bottom row, then NIGHT resolving.
## The night self-damage is suppressed here on purpose — these tests measure what
## the SKILL does, and the night penalty (which scales with board colours) would
## otherwise swamp the numbers.
func _fire_at_night(gm: Node, letter: String, skill_id: String, value: int) -> Dictionary:
	_arm(gm, letter, skill_id, value)
	gm.slots = _board_with_skill_at(letter, 0, 0)
	_point_at_skill(gm, 0, 0, 2)  # bottom row = firing line
	gm.is_night = true
	gm.night_penalty_immune = true
	return gm.apply_turn_start_penalty()


func _check_each_skill_does_its_job(gm: Node) -> int:
	var fails: int = 0

	# AEGIS — the enemy gains shield, and that shield really does eat damage.
	_setup(gm)
	_fire_at_night(gm, "B", "aegis", 8)
	fails += _check(gm.get_enemy_shield() == 8, "AEGIS raises 8 shield (%d)" % gm.get_enemy_shield())
	# Now prove the shield really is damage-first: bank 10, swing for 4.
	# The skill is disarmed first so only the absorption is being measured.
	gm.enemy_skills = []
	gm.is_night = false
	gm.enemy_shield = 10
	var hp_before: int = gm.get_enemy_hp()
	gm.execute_assignment("A", _word("A", 4))
	fails += _check(gm.get_enemy_hp() == hp_before,
		"the enemy shield absorbs a small hit before any HP is lost")
	fails += _check(gm.get_enemy_shield() == 6, "the shield is spent down (10 - 4 = 6)")

	# HAND DOWN — the hand shrinks, and never past the floor.
	_setup(gm)
	var hand_before: int = gm.hand.size()
	_fire_at_night(gm, "B", "hand_down", 1)
	fails += _check(gm.get_hand_limit() == gm.HAND_SIZE - 1,
		"HAND DOWN lowers the hand limit by 1 (%d)" % gm.get_hand_limit())
	fails += _check(gm.hand.size() <= gm.get_hand_limit(),
		"the hand itself was trimmed to the new limit (%d <= %d)" % [gm.hand.size(), gm.get_hand_limit()])
	fails += _check(hand_before == gm.HAND_SIZE, "the hand started full")
	# Over-stacking must stop at the floor instead of emptying the hand.
	_fire_at_night(gm, "B", "hand_down", 5)
	fails += _check(gm.get_hand_limit() == gm.ENEMY_MIN_HAND_LIMIT,
		"HAND DOWN never goes below %d cards (%d)" % [gm.ENEMY_MIN_HAND_LIMIT, gm.get_hand_limit()])
	fails += _check(gm.hand.size() <= gm.get_hand_limit(),
		"the hand still holds cards after over-stacking")

	# DRAIN — operation points are taken, and never below zero.
	_setup(gm)
	gm.operation_points = 10
	_fire_at_night(gm, "B", "drain", 4)
	fails += _check(gm.get_operation_points() == 6,
		"DRAIN takes 4 OP (10 -> %d)" % gm.get_operation_points())
	gm.operation_points = 1
	_fire_at_night(gm, "B", "drain", 4)
	fails += _check(gm.get_operation_points() == 0,
		"DRAIN never drives OP negative (%d)" % gm.get_operation_points())

	# NIGHTMARE — the night penalty base grows.
	_setup(gm)
	_arm(gm, "B", "nightmare", 6)
	gm.slots = _flat_board()
	gm.current_slot_indices = [0, 0, 0]
	var clean: int = gm.get_next_slot_penalty_with_multiplier([])["base_penalty"]
	# Put the card in the firing line on top of the flat board.
	gm.slots[0][2]["letter"] = "B"
	gm.is_night = true
	gm.apply_turn_start_penalty()
	var taxed: int = gm.get_next_slot_penalty_with_multiplier([])["base_penalty"]
	fails += _check(taxed == clean + 6,
		"NIGHTMARE adds 6 to the night base (%d -> %d)" % [clean, taxed])

	# REGROWTH — the enemy patches itself back up, capped at its max HP.
	_setup(gm, 20)
	gm.enemy_hp = 10
	_fire_at_night(gm, "B", "regrow", 5)
	fails += _check(gm.get_enemy_hp() == 15,
		"REGROWTH heals 5 off the damaged enemy (10 -> %d)" % gm.get_enemy_hp())
	gm.enemy_hp = gm.ENEMY_BASE_HP - 1
	_fire_at_night(gm, "B", "regrow", 5)
	fails += _check(gm.get_enemy_hp() == gm.ENEMY_BASE_HP,
		"REGROWTH never heals past the enemy's max HP (%d)" % gm.get_enemy_hp())

	# THORNS — the player takes damage, and BLUE shield soaks it first.
	_setup(gm)
	var php: int = gm.player_hp
	_fire_at_night(gm, "B", "thorns", 7)
	fails += _check(gm.player_hp == php - 7,
		"THORNS costs the player 7 HP (%d -> %d)" % [php, gm.player_hp])
	_setup(gm)
	gm.shield = 4
	php = gm.player_hp
	_fire_at_night(gm, "B", "thorns", 7)
	fails += _check(gm.player_hp == php - 3,
		"BLUE shield blocks part of THORNS (%d -> %d)" % [php, gm.player_hp])

	return fails


func _check_killing_blow_fires_no_skill(gm: Node) -> int:
	var fails: int = 0
	_setup(gm, 5)
	# Park the card in the firing line and resolve a NIGHT, so the only thing
	# stopping it is the stage clear. A defeated enemy must never answer.
	_arm(gm, "B", "thorns", 20)
	gm.slots = _board_with_skill_at("B", 0, 0)
	_point_at_skill(gm, 0, 0, 2)
	var php: int = gm.player_hp
	gm.operation_points = 10
	gm.is_night = true
	var res: Dictionary = gm.apply_turn_start_penalty()
	# A stage clear has NOT happened yet, so the skill legitimately fires here.
	fails += _check(bool(res.get("skill_fired", false)),
		"the skill fires when nothing was killed")

	# Now actually clear the stage, with the card waiting in the firing line.
	_setup(gm, 5)
	_arm(gm, "B", "thorns", 20)
	gm.slots = _board_with_skill_at("B", 0, 0)
	_point_at_skill(gm, 0, 0, 2)
	php = gm.player_hp
	gm.operation_points = 10
	var kill: Dictionary = gm.execute_assignment("A", BIG_WORD)
	fails += _check(int(kill.get("enemies_defeated_delta", 0)) == 1, "the enemy was defeated")
	var night: Dictionary = gm.apply_turn_start_penalty()
	fails += _check(not bool(night.get("skill_fired", true)),
		"a stage clear means the enemy never answers at night")
	fails += _check(gm.get_enemy_shield() == 0, "no shield is left on the NEW enemy")
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
## The forecast must describe the night exactly as a real night resolves.
func _check_preview_matches_reality(gm: Node) -> int:
	var fails: int = 0

	# THORNS with the card in the firing line: the forecast HP must equal the HP
	# the player really ends the turn with, skill and night damage included.
	_setup(gm)
	_arm(gm, "B", "thorns", 6)
	gm.slots = _board_with_skill_at("B", 0, 0)
	# The card is already in the bottom row and the word uses only hand cards,
	# so no reel rotates: the forecast and the real night see the same board.
	_point_at_skill(gm, 0, 0, 2)
	gm.is_night = false
	var plan: Dictionary = gm.predict_submit_outcome(_word("B", 5), [])
	fails += _check(bool(plan.get("enemy_skills_fire", false)),
		"the preview says the skill fires with the card in the bottom row")
	gm.execute_assignment("B", _word("B", 5))
	var night: Dictionary = gm.apply_turn_start_penalty()
	fails += _check(bool(night.get("skill_fired", false)),
		"and the real night really does fire it")
	fails += _check(int(plan.get("player_hp_after", -1)) == gm.player_hp,
		"THORNS preview HP %d == real HP %d" % [int(plan.get("player_hp_after", -1)), gm.player_hp])

	# The same card parked in the CENTRE row stays clear, and the forecast must
	# agree that nothing fires.
	_setup(gm)
	_arm(gm, "B", "aegis", 30)
	gm.slots = _board_with_skill_at("B", 0, 0)
	_point_at_skill(gm, 0, 0, 1)  # centre row
	gm.is_night = false
	var safe: Dictionary = gm.predict_submit_outcome(_word("B", 5), [])
	fails += _check(not bool(safe.get("enemy_skills_fire", true)),
		"preview: the card is safe while it sits in the centre row")
	gm.execute_assignment("B", _word("B", 5))
	var safe_night: Dictionary = gm.apply_turn_start_penalty()
	fails += _check(not bool(safe_night.get("skill_fired", true)),
		"and the real night agrees nothing fired")

	# A killing blow must be previewed as firing nothing.
	_setup(gm, 5)
	_arm(gm, "B", "thorns", 30)
	gm.slots = _board_with_skill_at("B", 0, 0)
	_point_at_skill(gm, 0, 0, 2)
	gm.is_night = false
	var kill_plan: Dictionary = gm.predict_submit_outcome(BIG_WORD, [])
	fails += _check(bool(kill_plan.get("defeats_enemy", false)), "preview sees the kill")
	fails += _check(not bool(kill_plan.get("enemy_skills_fire", true)),
		"preview: a killing blow fires no skill")
	return fails


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
