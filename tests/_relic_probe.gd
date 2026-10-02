extends SceneTree

# Boots the real Main scene to check the always-on relic panel: it must render
# in the spare width beside the HP bars, survive a full part destruction, and
# the main layout must still fit the 800px window.

const WINDOW_H: int = 800
const WINDOW_W: int = 1280

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

	var vbox = main.get_node("Scroll/Center/VBox")
	var status = main.get_node("Scroll/Center/VBox/StatusBox")
	var panel = main.get_node("Scroll/Center/VBox/StatusBox/RelicBox")
	var title = main.get_node("Scroll/Center/VBox/StatusBox/RelicBox/RelicVBox/RelicTitleLabel")
	var list = main.get_node("Scroll/Center/VBox/StatusBox/RelicBox/RelicVBox/RelicListLabel")

	# Empty state.
	print("empty  title=", (title as Label).text, "  list='", (list as Label).text, "'")
	fails += _check((title as Label).text == "RELICS (0)", "the panel starts at 0 relics")
	fails += _check((list as Label).text.contains("none yet"),
		"the empty panel says how to earn one")

	# Vertical fit: the relic panel must not be the tallest thing in the strip,
	# so it costs the main VBox no height at all.
	var p_h: float = (panel as Control).get_combined_minimum_size().y
	var s_h: float = (status as Control).get_combined_minimum_size().y
	print("panel h=%.0f  status h=%.0f" % [p_h, s_h])
	fails += _check(p_h <= s_h, "the relic panel fits inside the status strip")
	fails += _check(vbox.get_combined_minimum_size().y <= WINDOW_H,
		"layout still fits 800px (%.0f)" % vbox.get_combined_minimum_size().y)

	# It sits BESIDE the HP bars, not below them: the strip is one row.
	fails += _check((status as Control).get_child_count() == 4,
		"the status strip is still a single row (panel + player + enemy + op)")

	# Now earn several relics through real total destructions.
	for i in range(4):
		gm.set_enemy_name("DRAGON")
		gm.enemy_hp = 9999
		gm.execute_assignment("DRAGON", _word("DRAGON"))
	main._refresh_ui()
	await process_frame
	print("after 4 kills  title=", (title as Label).text)
	print("  list='", (list as Label).text.replace("\n", " | "), "'")
	fails += _check((title as Label).text == "RELICS (4)",
		"the panel counts every relic (got %s)" % (title as Label).text)
	for relic: Dictionary in gm.get_relics():
		var nm: String = str(relic.get("name", "?"))
		fails += _check((list as Label).text.contains(nm),
			"the panel names %s" % nm)
	# Duplicates must be collapsed to a "x2" style line, not repeated.
	var shown_lines: Array = (list as Label).text.split("\n")
	fails += _check(shown_lines.size() <= gm.get_relic_count(),
		"duplicates collapse (%d lines for %d relics)" % [shown_lines.size(), gm.get_relic_count()])
	# The tooltip carries the detail the narrow panel cannot show.
	fails += _check((list as Label).tooltip_text.contains("Active total:"),
		"the tooltip states the running total")

	# A new relic appears the moment it is earned, via the acquire path.
	# _finalize() is async (it awaits between step messages), so the test must
	# await it — otherwise it is only part-way through when we look.
	gm.set_enemy_name("DRAGON")
	gm.enemy_hp = 9999
	var r: Dictionary = gm.execute_assignment("DRAGON", _word("DRAGON"))
	fails += _check(bool(r.get("part_defeat", false)), "the 5th kill is a part destruction")
	await main._finalize(r, {})
	await process_frame
	print("after acquire  title=", (title as Label).text)
	fails += _check((title as Label).text == "RELICS (5)",
		"acquiring a relic updates the panel immediately (%s)" % (title as Label).text)

	fails += _check(vbox.get_combined_minimum_size().y <= WINDOW_H,
		"layout still fits 800px at the end (%.0f)" % vbox.get_combined_minimum_size().y)
	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	quit(fails)


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