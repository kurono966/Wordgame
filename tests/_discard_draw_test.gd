extends Node

# Headless test for DISCARD & DRAW's Workbench requirement.
#
# The ability bins a RANDOM card the player never chose, so it is only allowed
# with nothing on the Workbench — firing mid-word would silently wreck a build
# for no gain.
#
# Covered here:
#   * refused while the Workbench has cards, BEFORE any OP is spent
#   * allowed once the Workbench is clear
#   * the refusal names the reason and the card stays in hand
#   * every OTHER ability still works with cards on the Workbench
#   * can_use_special_ability dims it in the UI the same way

const SPECIAL_ID: String = "discard_draw"

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame
	gm.reset_game()

	fails += _check_refused_with_cards_on_the_workbench(gm)
	fails += _check_allowed_with_a_clear_workbench(gm)
	fails += _check_refusal_is_free(gm)
	fails += _check_card_survives_a_refusal(gm)
	fails += _check_other_abilities_are_unaffected(gm)
	fails += _check_ui_visibility_matches(gm)
	fails += _check_reset_game_clears_the_flag(gm)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## The headline rule: cards on the Workbench block it.
func _check_refused_with_cards_on_the_workbench(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_workbench_empty(false)
	gm.hand[0] = _special()
	gm.operation_points = 99
	var result: Dictionary = gm.use_special_ability(0)
	fails += _check(not result.get("valid", false),
		"DISCARD & DRAW is refused with cards on the Workbench")
	fails += _check(str(result.get("reason", "")).contains("Workbench"),
		"the refusal says the Workbench is the problem (%s)" % str(result.get("reason", "")))
	return fails


## Clear board, so it goes through.
func _check_allowed_with_a_clear_workbench(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_workbench_empty(true)
	gm.hand[0] = _special()
	gm.operation_points = 99
	var result: Dictionary = gm.use_special_ability(0)
	fails += _check(bool(result.get("valid", false)),
		"DISCARD & DRAW fires on a clear Workbench")
	fails += _check(str(result.get("reason", "")) == "",
		"no refusal reason on the happy path")
	return fails


## A refusal must cost nothing — not OP, and not the card either.
func _check_refusal_is_free(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_workbench_empty(false)
	gm.hand[0] = _special()
	gm.operation_points = 40
	var op_before: int = gm.operation_points
	var grave_before: int = gm.graveyard.size()
	var result: Dictionary = gm.use_special_ability(0)
	fails += _check(gm.operation_points == op_before,
		"a refused activation spends no OP (%d -> %d)" % [op_before, gm.operation_points])
	fails += _check(int(result.get("operation_points_spent", -1)) == 0,
		"the result reports nothing spent")
	fails += _check(gm.graveyard.size() == grave_before,
		"a refused activation discards nothing")
	return fails


## And the D card is still sitting in hand afterwards.
func _check_card_survives_a_refusal(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_workbench_empty(false)
	gm.hand[0] = _special()
	gm.operation_points = 99
	gm.use_special_ability(0)
	fails += _check(gm.hand[0] != null, "the card stays in hand after a refusal")
	fails += _check(gm.has_special_ability(gm.hand[0]),
		"and it is still the same special, ready to use later")
	return fails


## The restriction is specific to this one ability.
func _check_other_abilities_are_unaffected(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.set_workbench_empty(false)   # Workbench deliberately NOT clear
	gm.operation_points = 999
	for card_def in GameManager.SPECIAL_CARD_DEFS:
		var s_id: String = str(card_def.get("special_id", ""))
		if s_id == "" or s_id == SPECIAL_ID:
			continue
		gm.hand[0] = card_def.duplicate()
		var result: Dictionary = gm.use_special_ability(0)
		fails += _check(bool(result.get("valid", false)),
			"%s still works with cards on the Workbench" % s_id)
	return fails


## The UI dims the card the same way it dims an unaffordable one.
func _check_ui_visibility_matches(gm: Node) -> int:
	var fails: int = 0
	var card: Dictionary = _special()
	gm.reset_game()
	gm.operation_points = 99
	gm.set_workbench_empty(true)
	fails += _check(gm.can_use_special_ability(card),
		"available on a clear Workbench")
	gm.set_workbench_empty(false)
	fails += _check(not gm.can_use_special_ability(card),
		"dimmed by the UI when the Workbench has cards")
	fails += _check(not gm.special_ability_blocker(card).is_empty(),
		"the UI is given a reason to show")

	# An unaffordable card is still blocked, and so is a plain card with no blocker.
	gm.operation_points = 0
	gm.set_workbench_empty(true)
	fails += _check(not gm.can_use_special_ability(card),
		"still blocked when the OP is short")
	fails += _check(gm.special_ability_blocker({"letter": "A"}).is_empty(),
		"a plain card has no Workbench blocker")
	return fails


## A new game starts with a clear board, so the ability is usable again.
func _check_reset_game_clears_the_flag(gm: Node) -> int:
	gm.set_workbench_empty(false)
	gm.reset_game()
	return _check(gm.workbench_empty, "reset_game leaves the Workbench clear")


func _special() -> Dictionary:
	for card_def in GameManager.SPECIAL_CARD_DEFS:
		if str(card_def.get("special_id", "")) == SPECIAL_ID:
			return card_def.duplicate()
	return {}


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1