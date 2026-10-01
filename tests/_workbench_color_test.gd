extends Node

# Headless test that the Workbench (the word-building area) colours its cards
# exactly like the hand and the shared reels do, so a word's traits — RED damage
# multiplier, BLUE shield, GREEN heal, YELLOW OP — can be read straight off the
# cards the player has assembled.
#
#   * every Workbench card takes its border AND background from its own colour
#   * all four colours resolve to their real values, not one shared default
#   * a wildcard keeps its own colour (only its LETTER turns gold), so it can
#     still be matched against same-colour cards for the multiplier
#   * cards from BOTH sources (hand and shared reel) are coloured

const COLOURS: Array = ["red", "blue", "green", "yellow"]

func _ready() -> void:
	var main = (load("res://src/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var fails: int = 0

	# ===== Each colour reaches the panel, from either source =================
	for source: String in ["hand", "slot"]:
		for colour: String in COLOURS:
			fails += _check_card(main, source, colour, false)
			fails += _check_card(main, source, colour, true)  # wildcard keeps its colour

	# ===== The four colours are genuinely distinguishable from each other ====
	var backgrounds: Array = []
	for colour: String in COLOURS:
		main.workbench_cards = [_card("hand", colour, false)]
		main._refresh_workbench_ui()
		var style := _style_of(main)
		backgrounds.append(style.bg_color if style != null else Color.TRANSPARENT)
	var unique: int = 0
	for i in range(backgrounds.size()):
		if not backgrounds[i] in backgrounds.slice(0, i):
			unique += 1
	fails += _check(unique == COLOURS.size(),
		"all four colours render differently (%d of %d unique)" % [unique, COLOURS.size()])

	# ===== Several cards keep their own colours side by side =================
	main.workbench_cards = [
		_card("hand", "red", false),
		_card("hand", "blue", false),
		_card("slot", "green", false),
		_card("slot", "yellow", false),
	]
	main._refresh_workbench_ui()
	var container := main.get_node("Scroll/Center/VBox/WorkbenchPanel/WorkbenchContainer")
	fails += _check(container.get_child_count() == 4,
		"four Workbench cards are drawn (%d)" % container.get_child_count())
	var i: int = 0
	for child in container.get_children():
		if child is PanelContainer:
			var sb: StyleBoxFlat = child.get_theme_stylebox("panel")
			var want: Dictionary = main.get_card_color_constants(COLOURS[i])
			fails += _check(sb != null and sb.border_color == want["border"],
				"card %d on the Workbench is the %s colour" % [i, COLOURS[i]])
			i += 1

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## Places one synthetic card on the Workbench, refreshes, and asserts the panel
## picked up that colour's border and background.
func _check_card(main, source: String, colour: String, wildcard: bool) -> int:
	main.workbench_cards = [_card(source, colour, wildcard)]
	main._refresh_workbench_ui()

	var label: String = "%s %s%s" % [source, colour, (" wildcard" if wildcard else "")]
	var style := _style_of(main)
	if style == null:
		return _check(false, "%s: the Workbench drew no card" % label)

	var fails: int = 0
	var consts: Dictionary = main.get_card_color_constants(colour)
	fails += _check(style.border_color == consts["border"],
		"%s: border uses the %s colour" % [label, colour])
	fails += _check(style.bg_color == consts["bg"],
		"%s: background uses the %s colour" % [label, colour])
	return fails


## A card entry shaped exactly like the ones the hand and the reels hand over.
func _card(source: String, colour: String, wildcard: bool) -> Dictionary:
	if source == "slot":
		return {"type": "slot", "index": 0, "char": "E", "card_letter": "E",
			"is_wildcard": wildcard, "damage": 2, "color": colour}
	return {"type": "hand", "hand_index": 0, "char": "E", "card_letter": "E",
		"is_wildcard": wildcard, "damage": 2, "color": colour}


## The StyleBoxFlat of the single card currently drawn on the Workbench.
func _style_of(main) -> StyleBoxFlat:
	var container: Node = main.get_node("Scroll/Center/VBox/WorkbenchPanel/WorkbenchContainer")
	for child in container.get_children():
		if child is PanelContainer:
			var sb: StyleBoxFlat = child.get_theme_stylebox("panel")
			if sb != null:
				return sb
	return null


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
