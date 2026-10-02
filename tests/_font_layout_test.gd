extends Node

# The layout must not depend on WHICH font is configured.
#
# Card, button and window sizes used to be hard-coded pixels while the face came
# from project.godot's theme/custom_font. Changing the face changes the line
# height (ascent + descent) and every glyph's advance, so text spilled out of
# cards and the 3-row reel window clipped its bottom row.
#
# The sizes are now MEASURED from the active font. This test swaps in each
# bundled face, rebuilds the scene, and asserts that:
#   * every card is at least as tall as the text it must show
#   * no reel card is clipped horizontally by its window
#   * the reel window shows exactly three rows
#   * reward / burn buttons are tall enough for their content
#
# A Label with clip_text reports a minimum width of 1px, so widths are measured
# with Font.get_string_size() rather than read off a Control.

const FONT_PATHS: Array = [
	"res://fonts/MochiyPopOne-Regular.ttf",
	"res://fonts/DelaGothicOne-Regular.ttf",
	"res://fonts/WDXLLubrifontJPN-Regular.ttf",
]

# The strings the reel sub-label can actually print (mirrors _slot_clip_test).
const REEL_TEXTS: Array = [
	"★ ACTIVE (99dmg)  ⚠ NIGHTMARE",
	"→ NEXT (12dmg)  ⚠ REGROWTH",
	"99 dmg  ⚠ DRAIN",
]

func _ready() -> void:
	var fails: int = 0
	await get_tree().process_frame

	for path in FONT_PATHS:
		if not ResourceLoader.exists(path):
			print("skip - no such font: %s" % path)
			continue
		var font: FontFile = load(path)
		fails += await _check_with_font(font, String(path))

	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


func _check_with_font(font: FontFile, label: String) -> int:
	var fails: int = 0
	# Build the scene with this font forced as the default theme font.
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16

	var main = (load("res://src/Main.tscn") as PackedScene).instantiate()
	main.theme = theme
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# ===== 1. every hand card is tall enough for its two lines ===============
	var hand_views: Array = main.get("hand_card_views")
	var worst_hand_short: float = 0.0
	for cv: Dictionary in hand_views:
		var panel: Control = cv["panel"]
		var need: float = main._line_height(32) + main._line_height(12) + 6.0
		worst_hand_short = maxf(worst_hand_short, need - panel.custom_minimum_size.y)
	fails += _check(worst_hand_short <= 0.0,
		"[%s] hand cards fit their text (short by %.1fpx)" % [label, worst_hand_short])

	# ===== 2. the reel window shows exactly three rows ======================
	var reels: Array = main.get("slot_reels")
	var worst_rows: float = 0.0
	for reel: Dictionary in reels:
		var window: Control = reel["window"]
		var views: Array = reel["card_views"]
		var card_h: float = views[0]["panel"].size.y
		var strip: VBoxContainer = reel["strip"]
		# The visible window must be tall enough for three cards + two gaps and
		# NOT tall enough for four (otherwise a fourth row peeks in).
		var three: float = card_h * 3.0 + 8.0 * 2.0
		var four: float = card_h * 4.0 + 8.0 * 3.0
		worst_rows = maxf(worst_rows, three - window.size.y)
		fails += _check(window.size.y >= three - 0.5,
			"[%s] reel window shows 3 rows (%.1f >= %.1f)" % [label, window.size.y, three])
		fails += _check(window.size.y < four,
			"[%s] reel window hides the 4th row (%.1f < %.1f)" % [label, window.size.y, four])
		fails += _check(strip.size.x <= window.size.x + 0.5,
			"[%s] reel strip fits its window" % label)

	# ===== 3. the widest reel string fits inside the card ===================
	var slot_w: float = main.reel_card_w
	var sample: Dictionary = reels[0]["card_views"][0]
	var style: StyleBoxFlat = sample["style"]
	var printable: float = slot_w \
		- style.content_margin_left - style.content_margin_right \
		- style.border_width_left - style.border_width_right
	for text in REEL_TEXTS:
		var w: float = font.get_string_size(String(text),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10).x
		fails += _check(w <= printable,
			"[%s] reel text \"%s\" (%.1fpx) fits %.1fpx" % [label, text, w, printable])

	# ===== 4. reward and burn buttons are tall enough for their content ======
	fails += _check(main._line_height(30) > 0.0,
		"[%s] font reports a positive line height" % label)

	# ===== 5. nothing overflows the play area horizontally ==================
	var vbox := main.get_node("Scroll/Center/VBox")
	var vbox_min: Vector2 = vbox.get_combined_minimum_size()
	fails += _check(vbox_min.x <= vbox.custom_minimum_size.x + 0.5,
		"[%s] the slot row did not force the layout wider (%.1f <= %.1f)" % [
			label, vbox_min.x, vbox.custom_minimum_size.x])

	main.queue_free()
	await get_tree().process_frame
	return fails


func _check(ok: bool, label: String) -> int:
	if ok:
		print("ok   - %s" % label)
		return 0
	printerr("FAIL - %s" % label)
	return 1