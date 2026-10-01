extends Node

# Headless test for the enemy-name bonus: spelling two or more CONSECUTIVE
# letters of the enemy's own name doubles every card in the word, once more for
# each extra letter of the run.
#
# The rule is the word's LONGEST COMMON SUBSTRING with the enemy name. Against
# "dragon" that gives exactly the three cases asked for:
#
#     "drag" -> run 4 -> x8     (the whole word is in the name)
#     "gone" -> run 3 -> x4     ("gon"; the trailing 'e' is not in the name)
#     "one"  -> run 2 -> x2     ("on"; the trailing 'e' is not in the name)
#
# Only the length of the run matters, and the bonus applies to EVERY card in the
# word — including the letters that are not part of the run.

const NAME: String = "dragon"

func _ready() -> void:
	var gm = GameManager
	var fails: int = 0
	await get_tree().process_frame
	gm.reset_game()
	gm.enemy_name = NAME

	# ===== The three cases from the request =========================
	fails += _check(gm.name_consecutive_run("DRAG") == 4, "'drag' runs 4 letters of dragon")
	fails += _check(gm.name_consecutive_multiplier("DRAG") == 8, "'drag' is x8")

	fails += _check(gm.name_consecutive_run("GONE") == 3, "'gone' runs 3 letters of dragon")
	fails += _check(gm.name_consecutive_multiplier("GONE") == 4, "'gone' is x4")

	fails += _check(gm.name_consecutive_run("ONE") == 2, "'one' runs 2 letters of dragon")
	fails += _check(gm.name_consecutive_multiplier("ONE") == 2, "'one' is x2")

	# ===== Runs that do not qualify ================================
	fails += _check(gm.name_consecutive_run("DOG") == 1,
		"'dog' has no back-to-back run (d, o, g are separate in dragon)")
	fails += _check(gm.name_consecutive_multiplier("DOG") == 1, "'dog' gets no bonus")

	fails += _check(gm.name_consecutive_run("Z") == 0, "a letter absent from the name runs 0")
	fails += _check(gm.name_consecutive_multiplier("Z") == 1, "a single unmatched letter gets no bonus")

	# A run in the MIDDLE of the name counts like one at the start or the end.
	fails += _check(gm.name_consecutive_run("RAGON") == 5, "'ragon' runs the whole name")
	fails += _check(gm.name_consecutive_multiplier("RAGON") == 16, "a 5-letter run is x16")
	fails += _check(gm.name_consecutive_multiplier("DRAGON") == 32, "the whole name spelled is x32")

	# The run must be CONTIGUOUS in the name, not merely present in it: "dna" uses
	# three letters that are all in "dragon", but never two of them side by side.
	fails += _check(gm.name_consecutive_run("DNA") == 1,
		"'dna' shares three letters but never two consecutively")
	fails += _check(gm.name_consecutive_multiplier("DNA") == 1,
		"'dna' earns nothing despite matching three letters")

	# The bonus is case-insensitive, since cards carry upper-case letters.
	fails += _check(gm.name_consecutive_multiplier("drag") == 8, "the run check ignores case")

	fails += _check_multiplies_the_whole_word(gm)
	fails += _check_scales_every_colour_trait(gm)
	fails += _check_preview_matches_reality(gm)
	fails += _check_follows_the_current_enemy(gm)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## The 'e' in "gone" is not part of the run, but its damage is scaled anyway.
func _check_multiplies_the_whole_word(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.enemy_name = NAME
	var word: Array = [
		_card("G", 4, "green"), _card("O", 8, "green"),
		_card("N", 10, "blue"), _card("E", 3, "yellow")]
	var raw: int = 4 + 8 + 10 + 3  # 25

	var result: Dictionary = gm.execute_assignment("GONE", word)
	fails += _check(int(result.get("name_run", -1)) == 3, "the submit reports a run of 3")
	fails += _check(int(result.get("name_multiplier", -1)) == 4, "the submit reports x4")
	# No RED in the word, so the colour multiplier is x1 and the total is just the
	# scaled base: 25 x 4 = 100.
	fails += _check(int(result.get("word_damage", -1)) == raw * 4,
		"all four cards were multiplied (%d -> %d)" % [raw, int(result.get("word_damage", -1))])
	fails += _check(int(result.get("final_damage", -1)) == raw * 4,
		"the damage actually dealt is the scaled total (%d)" % int(result.get("final_damage", -1)))
	return fails


## The bonus rides on the same base the colour traits use, so they scale too.
func _check_scales_every_colour_trait(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.enemy_name = NAME
	gm.player_max_hp = 500   # raised so the heal cap cannot mask the bonus
	gm.player_hp = 1
	gm.shield = 0
	# Two GREEN cards (8 each): base 16, x2 from the "GO" run -> 32, then GREEN
	# x2^(2-1) = x2 -> 64 healed.
	var word: Array = [_card("G", 8, "green"), _card("O", 8, "green")]
	var result: Dictionary = gm.execute_assignment("GO", word)
	fails += _check(int(result.get("name_multiplier", -1)) == 2, "'go' is a 2-letter run, x2")
	fails += _check(int(result.get("heal_amount", -1)) == 64,
		"the GREEN heal is scaled by the name bonus too (%d)" % int(result.get("heal_amount", -1)))
	return fails


## The submit preview must quote the same number the submit delivers.
func _check_preview_matches_reality(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.enemy_name = NAME
	var word: Array = [
		_card("D", 6, "green"), _card("R", 4, "green"),
		_card("A", 3, "green"), _card("G", 5, "green")]
	gm.enemy_hp = 9999
	var plan: Dictionary = gm.predict_submit_outcome(word, [])
	fails += _check(int(plan.get("name_multiplier", -1)) == 8, "the preview applies the x8 name bonus")
	fails += _check(int(plan.get("name_run", -1)) == 4, "the preview reports the run length")

	var result: Dictionary = gm.execute_assignment("DRAG", word)
	fails += _check(int(plan.get("final_damage", -1)) == int(result.get("final_damage", -2)),
		"preview damage %d == real damage %d" % [
			int(plan.get("final_damage", -1)), int(result.get("final_damage", -2))])
	return fails


## The bonus tracks whichever enemy is on the board, not a fixed name.
func _check_follows_the_current_enemy(gm: Node) -> int:
	var fails: int = 0
	gm.reset_game()
	gm.enemy_name = "stone"
	fails += _check(gm.name_consecutive_multiplier("ONE") == 4, "'one' runs all 3 letters of 'stone'")
	fails += _check(gm.name_consecutive_multiplier("TONE") == 8, "'tone' runs 4 letters of 'stone'")
	fails += _check(gm.name_consecutive_multiplier("TONES") == 8,
		"'tones' is not in 'stone' either, so it still only runs 4")

	gm.enemy_name = "XYZQ"
	fails += _check(gm.name_consecutive_multiplier("DRAG") == 1,
		"'drag' earns nothing against an unrelated name")
	return fails


func _card(letter: String, damage: int, color: String) -> Dictionary:
	return {"type": "hand", "hand_index": 0, "char": letter, "card_letter": letter,
		"is_wildcard": false, "damage": damage, "color": color}


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1