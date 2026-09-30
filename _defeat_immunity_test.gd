extends Node

# Headless test: the turn on which the enemy is defeated must cost the player
# NOTHING. The only damage a turn can deal is the NIGHT self-damage penalty, so
# a killing submit has to nullify it.
#   * killing submit on a DAY turn  -> 0 HP lost
#   * non-killing submit (control) -> the NIGHT penalty DOES land
#   * the immunity must not leak into a later turn
#   * the pre-submit preview must agree with what really happens

# A 20-damage GREEN word: it heals nothing at full HP and grants no shield, so
# the NIGHT penalty is the only thing that can reduce the player's HP.
const BIG_WORD: Array = [
	{"type": "hand", "hand_index": 0, "char": "A", "card_letter": "A", "damage": 20, "color": "green"}
]

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame

	fails += _check_control_penalty_lands(gm)
	fails += _check_kill_is_immune(gm)
	fails += _check_immunity_does_not_leak(gm)
	fails += _check_kill_with_zero_gravity(gm)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)

## Same word, but the enemy survives -> the NIGHT penalty must still be paid.
func _check_control_penalty_lands(gm: Node) -> int:
	var fails: int = 0
	_setup(gm, false, 30)
	var hp_before: int = gm.player_hp

	var plan: Dictionary = gm.predict_submit_outcome(BIG_WORD, [])
	var res: Dictionary = gm.execute_assignment("A", BIG_WORD)
	var pen: Dictionary = gm.apply_turn_start_penalty()

	fails += _check(int(res.get("enemies_defeated_delta", 0)) == 0, "control: the enemy survived")
	fails += _check(int(pen.get("requested_damage", 0)) > 0,
		"control: a NIGHT penalty was actually due (%d)" % int(pen.get("requested_damage", 0)))
	fails += _check(gm.player_hp < hp_before, "control: a non-killing submit still costs HP")
	fails += _check(int(plan.get("player_hp_after", -1)) == gm.player_hp,
		"control: preview HP %d == real HP %d" % [int(plan.get("player_hp_after", -1)), gm.player_hp])
	return fails

## The actual fix: a submit that defeats the enemy costs nothing.
func _check_kill_is_immune(gm: Node) -> int:
	var fails: int = 0
	_setup(gm, false, 5)
	var hp_before: int = gm.player_hp

	var plan: Dictionary = gm.predict_submit_outcome(BIG_WORD, [])
	var res: Dictionary = gm.execute_assignment("A", BIG_WORD)
	var pen: Dictionary = gm.apply_turn_start_penalty()

	fails += _check(int(res.get("enemies_defeated_delta", 0)) == 1, "the enemy was defeated")
	fails += _check(bool(pen.get("stage_cleared", false)),
		"the penalty result reports the stage clear")
	fails += _check(int(pen.get("requested_damage", 0)) == 0,
		"a killing submit requests no NIGHT damage (%d)" % int(pen.get("requested_damage", 0)))
	fails += _check(int(pen.get("applied_damage", -1)) == 0, "no damage is applied")
	fails += _check(gm.player_hp == hp_before,
		"the killing turn costs no HP (%d -> %d)" % [hp_before, gm.player_hp])
	fails += _check(int(plan.get("night_penalty", -1)) == 0,
		"preview: NIGHT damage is 0 on a killing submit")
	fails += _check(int(plan.get("total_hp_lost", -1)) == 0, "preview: 0 HP lost")
	fails += _check(int(plan.get("player_hp_after", -1)) == gm.player_hp,
		"preview HP %d == real HP %d" % [int(plan.get("player_hp_after", -1)), gm.player_hp])
	return fails

## The one-shot immunity must be consumed, not carried into the next turn.
func _check_immunity_does_not_leak(gm: Node) -> int:
	var fails: int = 0
	_setup(gm, false, 5)
	gm.execute_assignment("A", BIG_WORD)   # kill -> would set the immunity
	gm.apply_turn_start_penalty()         # consumes it
	fails += _check(not bool(gm.stage_cleared_immune),
		"the immunity is cleared once the turn's penalty resolved")

	# A later, non-killing turn must be charged normally again.
	_setup(gm, false, 30)
	var hp_before: int = gm.player_hp
	gm.execute_assignment("A", BIG_WORD)
	var pen: Dictionary = gm.apply_turn_start_penalty()
	fails += _check(int(pen.get("requested_damage", 0)) > 0,
		"the NEXT turn is charged again (%d)" % int(pen.get("requested_damage", 0)))
	fails += _check(gm.player_hp < hp_before, "the next turn costs HP again")
	return fails

## Zero Gravity and a stage clear stack; both are consumed exactly once.
func _check_kill_with_zero_gravity(gm: Node) -> int:
	var fails: int = 0
	_setup(gm, false, 5)
	var z_def: Dictionary = {}
	for s in GameManager.SPECIAL_CARD_DEFS:
		if s.get("special_id") == "zero_gravity":
			z_def = s.duplicate()
	GameManager.hand[0] = z_def
	GameManager.operation_points = 10
	var used: Dictionary = GameManager.use_special_ability(0)
	fails += _check(bool(used.get("valid", false)), "Zero Gravity activated first")

	var hp_before: int = gm.player_hp
	gm.execute_assignment("A", BIG_WORD)
	gm.apply_turn_start_penalty()
	fails += _check(gm.player_hp == hp_before, "a kill after Zero Gravity still costs no HP")
	fails += _check(not GameManager.night_penalty_immune,
		"Zero Gravity's immunity is also consumed")
	return fails

## DAY phase, enemy HP, no shield, full player HP.
func _setup(gm: Node, night: bool, enemy_hp: int) -> void:
	gm.reset_game()
	gm.is_night = night
	gm.enemy_hp = enemy_hp
	gm.enemy_max_hp = GameManager.ENEMY_BASE_HP
	gm.shield = 0
	gm.player_hp = GameManager.PLAYER_MAX_HP
	gm.hand[0] = {"letter": "A", "damage": 20, "color": "green"}

func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
