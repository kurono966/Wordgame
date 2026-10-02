extends Node

# Headless regression test for the reel cards being cut off on the right.
#
# Every reel lives inside a `window` Control with `clip_contents = true` that is
# exactly SLOT_CARD_W wide. A card whose content is wider than that window is
# silently truncated on the right edge — the ACTIVE row carrying a long skill tag
# ("★ ACTIVE (12dmg)  ⚠ HAND DOWN") used to overflow by ~16px this way.
#
#   * no card on any reel may be wider than the window that clips it
#   * the widest sub-label the game can ever print must fit inside the card, so
#     the clip_text guard never actually has to truncate anything
#   * the reel strip must stay inside the window horizontally
#   * the whole slot row must still fit the 960px-wide play area

# The same strings _setup_slot_card() builds, for the worst case of every skill.
const SKILL_NAMES: Array = ["AEGIS", "HAND DOWN", "DRAIN", "NIGHTMARE", "REGROWTH"]
const DAMAGE_VALUES: Array = [1, 8, 9, 10, 12, 20, 99]

func _ready() -> void:
	var main = (load("res://src/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var fails: int = 0
	var reels: Array = main.get("slot_reels")
	# The reel width is measured from the active font at build time, so the test
	# asks the scene for it rather than assuming a constant.
	var slot_w: float = main.reel_card_w
	var vbox := main.get_node("Scroll/Center/VBox")

	# ===== 1. No card overflows the window that clips it =====================
	var worst_overflow: float = 0.0
	var worst_label: String = ""
	for s in range(reels.size()):
		var reel: Dictionary = reels[s]
		var window: Control = reel["window"]
		var card_views: Array = reel["card_views"]
		for i in range(card_views.size()):
			var panel: PanelContainer = card_views[i]["panel"]
			var overflow: float = panel.get_combined_minimum_size().x - window.size.x
			if overflow > worst_overflow:
				worst_overflow = overflow
				worst_label = "reel %d row %d (%s)" % [s, i, str(card_views[i]["sub"].text)]
			# The card must also be no wider than the window it is drawn in.
			fails += _check(panel.size.x <= window.size.x + 0.01,
				"reel %d row %d card (%.1f) fits its window (%.1f)" % [s, i, panel.size.x, window.size.x])
	fails += _check(worst_overflow <= 0.0,
		"no reel card overflows its clipping window (worst: %s by %.1fpx)" % [worst_label, worst_overflow])

	# ===== 2. The strip stays inside the window horizontally ==================
	for s in range(reels.size()):
		var reel: Dictionary = reels[s]
		var window: Control = reel["window"]
		var strip: VBoxContainer = reel["strip"]
		fails += _check(strip.get_combined_minimum_size().x <= window.size.x + 0.01,
			"reel %d strip (%.1f) fits its window (%.1f)" % [
				s, strip.get_combined_minimum_size().x, window.size.x])

	# ===== 3. The widest printable sub-label actually fits ====================
	# A label with clip_text = true reports a minimum width of 1px no matter how
	# long its text is, so measure the real string width against the space the
	# card actually offers instead.
	var probe := Label.new()
	probe.add_theme_font_size_override("font_size", 10)
	main.add_child(probe)
	await get_tree().process_frame

	var widest: float = 0.0
	var widest_text: String = ""
	for dmg in DAMAGE_VALUES:
		for skill_name in SKILL_NAMES:
			var mark: String = "  ⚠ %s" % skill_name
			for text in [
				"%d dmg%s" % [dmg, mark],
				"★ ACTIVE (%ddmg)%s" % [dmg, mark],
				"→ NEXT (%ddmg)%s" % [dmg, mark],
			]:
				probe.text = text
				var w: float = probe.get_combined_minimum_size().x
				if w > widest:
					widest = w
					widest_text = text

	# Subtract the card's own 2x5 content margin and 2x2 border to get the
	# printable width inside one reel card.
	var sample: Dictionary = reels[0]["card_views"][0]
	var style: StyleBoxFlat = sample["style"]
	var printable: float = slot_w \
		- style.content_margin_left - style.content_margin_right \
		- style.border_width_left - style.border_width_right
	fails += _check(widest <= printable,
		"widest sub-label (%.1fpx: \"%s\") fits the card's %.1fpx of room" % [widest, widest_text, printable])

	# ===== 4. The slot row still fits the play area ===========================
	var vbox_min: Vector2 = vbox.get_combined_minimum_size()
	fails += _check(vbox_min.x <= vbox.custom_minimum_size.x + 0.01,
		"the slot row did not force the layout wider (%.1f <= %.1f)" % [
			vbox_min.x, vbox.custom_minimum_size.x])

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
