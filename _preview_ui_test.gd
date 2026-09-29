extends Node

# Headless UI test for the pre-submit damage preview label.

func _ready() -> void:
	var fails: int = 0
	await get_tree().process_frame
	var main = (load("res://Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	fails += _check(main != null, "Main.tscn instantiates with the new preview label")
	if main == null:
		print("FAILURES=%d" % fails)
		get_tree().quit(fails)
		return

	# Idle state before anything is placed
	fails += _check(str(main.preview_label.text).contains("preview"),
		"idle preview prompts the player to place cards ('%s')" % main.preview_label.text)

	# Place a real slot card + hand cards and check the preview reflects them
	var hand: Array = GameManager.get_hand()
	GameManager.hand[0] = {"letter": hand[0]["letter"], "damage": 1, "color": "green"}
	GameManager.hand[1] = {"letter": "E", "damage": 1, "color": "blue"}
	# Slot 0's ACTIVE card
	var slot0: Dictionary = GameManager.get_current_slot_card(0)
	# Use the REAL add path (add_card_to_workbench), because that is what the
	# player does and where the preview previously failed to update.
	main.add_card_to_workbench({
		"type": "slot", "index": 0, "char": slot0["letter"],
		"card_letter": slot0["letter"], "damage": slot0["damage"],
		"color": slot0.get("color", "red"), "is_wildcard": slot0["letter"] == "?"
	})
	await get_tree().process_frame
	fails += _check(str(main.preview_label.text).contains("ON SUBMIT"),
		"add_card_to_workbench() updates the preview ('%s')" % str(main.preview_label.text).substr(0, 60))

	# Removing it must return to the idle prompt, again via the real path
	await main.remove_card_from_workbench_at(0)
	await get_tree().process_frame
	fails += _check(str(main.preview_label.text).contains("preview"),
		"remove_card_from_workbench_at() restores the idle prompt ('%s')" % str(main.preview_label.text).substr(0, 60))

	# Re-place it for the remaining checks
	main.add_card_to_workbench({
		"type": "slot", "index": 0, "char": slot0["letter"],
		"card_letter": slot0["letter"], "damage": slot0["damage"],
		"color": slot0.get("color", "red"), "is_wildcard": slot0["letter"] == "?"
	})
	main._refresh_ui()
	await get_tree().process_frame

	var text: String = str(main.preview_label.text)
	fails += _check(text.contains("ON SUBMIT"), "preview shows the ON SUBMIT header ('%s')" % text)
	fails += _check(text.contains("YOU LOSE") or text.contains("HP"),
		"preview shows the HP outcome")
	fails += _check(text.contains("NIGHT") or text.contains("no NIGHT"),
		"preview shows the night penalty state")

	# Colour must reflect danger: green when safe, red when lethal
	var safe_color: Color = main.preview_label.get_theme_color("font_color")
	GameManager.shield = 0
	GameManager.player_hp = 1
	GameManager.is_night = false
	main._refresh_ui()
	await get_tree().process_frame
	var lethal_text: String = str(main.preview_label.text)
	var lethal_color: Color = main.preview_label.get_theme_color("font_color")
	fails += _check(lethal_text.contains("YOU LOSE"), "1 HP player will lose HP")
	fails += _check(lethal_color == main.PREVIEW_COLOR_HURT or lethal_color == main.PREVIEW_COLOR_LETHAL,
		"dangerous preview is coloured red/orange")
	print("preview text sample: ", lethal_text)

	# The label must be laid out and visible in the real UI, not just have text
	fails += _check(main.preview_label.is_visible_in_tree(),
		"preview label is visible in the tree")
	var vbox := main.get_node("Scroll/Center/VBox") as VBoxContainer
	fails += _check(main.preview_label.get_parent() == vbox,
		"preview label sits in the main VBox (not orphaned)")
	fails += _check(main.preview_label.size.y > 0.0,
		"preview label has a non-zero height (%.1f)" % main.preview_label.size.y)
	fails += _check(vbox.get_combined_minimum_size().y > 0.0,
		"VBox has a real minimum height (%.1f)" % vbox.get_combined_minimum_size().y)
	print("label rect: ", main.preview_label.get_global_rect(),
		" vbox min: ", vbox.get_combined_minimum_size())

	# Headless runs at a 64x64 viewport, so force the real 1280x800 window size
	# to measure whether the label is actually ON screen for the player.
	var vp := main.get_viewport()
	vp.size = Vector2i(1280, 800)
	await get_tree().process_frame
	await get_tree().process_frame
	var rect: Rect2 = main.preview_label.get_global_rect()
	print("label rect @1280x800: ", rect, " viewport: ", vp.size)
	fails += _check(rect.position.y >= 0.0 and rect.position.y < 800.0,
		"preview label is on screen vertically (y=%.1f < 800)" % rect.position.y)
	fails += _check(rect.end.y <= 800.0,
		"preview label fits inside the 800px window (bottom=%.1f)" % rect.end.y)

	# Clearing the workbench must return to the idle prompt
	main.workbench_cards.clear()
	main._refresh_ui()
	await get_tree().process_frame
	fails += _check(str(main.preview_label.text).contains("preview"),
		"clearing the workbench restores the idle prompt")

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)

func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
