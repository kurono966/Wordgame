extends SceneTree

# Boots the real Main scene and drives the part system through the UI layer, so
# the label, the step messages and the reward flow are exercised as the player
# would meet them — not just the GameManager helpers.

const WINDOW_H: int = 800

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	await process_frame
	var main = (load("res://src/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var gm = root.get_node("GameManager")
	var fails: int = 0

	# A real enemy from the dictionary, so the parts are cut the way they are in
	# an actual run rather than from a hand-picked name.
	gm.set_enemy_name("DRAGON")
	main._refresh_ui()
	await process_frame

	var label = main.get_node("Scroll/Center/VBox/StatusBox/EnemyHPBox/EnemyPartsLabel")
	print("initial text: ", (label as RichTextLabel).text)
	fails += _check((label as RichTextLabel).visible, "the parts strip is visible with an enemy on the board")
	fails += _check((label as RichTextLabel).text.count("color=") >= 4,
		"the strip renders all three parts (%s)" % (label as RichTextLabel).text)

	# Submit DRIFT through the real submit path, the way the button does.
	var r1: Dictionary = gm.execute_assignment("DRIFT", _word("DRIFT"))
	main._finalize(r1, {})
	main._refresh_ui()
	await process_frame
	print("after DRIFT:  ", (label as RichTextLabel).text)
	fails += _check((label as RichTextLabel).text.contains("[s]DR[/s]"),
		"DR is struck through on the enemy strip after DRIFT")
	fails += _check((label as RichTextLabel).text.contains("(2 / 3 intact)"),
		"the strip counts two parts left")

	# The last part: the UI must report a total destruction AND a relic.
	var r2: Dictionary = gm.execute_assignment("DRAGON", _word("DRAGON"))
	main._finalize(r2, {})
	main._refresh_ui()
	await process_frame
	fails += _check(bool(r2.get("part_defeat", false)), "the last part destroyed the enemy")
	fails += _check(gm.get_relic_count() == 1, "one relic was granted")
	fails += _check(gm.get_stage() == 2, "the stage advanced to 2")
	# A new enemy is on the board, so the strip must show a fresh, unbroken body.
	# The name is rolled at random, so the part count varies (1-4) — assert
	# against the model rather than against one hard-coded string.
	var next_parts: Array = gm.get_enemy_parts()
	print("next enemy:   ", (label as RichTextLabel).text, "  (", gm.get_enemy_name(), ")")
	fails += _check(gm.get_broken_part_count() == 0,
		"the next enemy starts with no part broken")
	fails += _check((label as RichTextLabel).text.contains("(%d / %d intact)" % [next_parts.size(), next_parts.size()]),
		"the strip shows the new enemy fully intact (%d parts)" % next_parts.size())
	fails += _check(not (label as RichTextLabel).text.contains("[s]"),
		"no part on the new enemy's strip is struck through")

	# The layout must still fit after all that.
	var vbox = main.get_node("Scroll/Center/VBox")
	fails += _check(vbox.get_combined_minimum_size().y <= WINDOW_H,
		"the layout still fits the 800px window (%.0fpx)" % vbox.get_combined_minimum_size().y)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	quit(fails)


func _word(word: String) -> Array:
	var out: Array = []
	for i in range(word.length()):
		out.append({"type": "hand", "hand_index": i, "char": word[i],
			"card_letter": word[i], "is_wildcard": false,
			"damage": 0, "color": "green"})
	return out


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1

