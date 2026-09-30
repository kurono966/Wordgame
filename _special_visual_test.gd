extends Node

# Headless regression test for the SPECIAL-activation visual bug:
#   Activating a ★ SPECIAL fades its hand panel out (alpha 0). The replacement
#   card is only faded back IN when the panel's visual key changes, so whenever
#   the drawn card looks identical to the discarded one the panel stayed at
#   alpha 0 / shrunk -> "the next draw's card is invisible".
#   Every hand panel must be fully visible after the refresh.

func _ready() -> void:
	var fails: int = 0
	await get_tree().process_frame
	var main = (load("res://Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	fails += await _check_all_specials(main)
	_finish(fails)

func _check_all_specials(main: Node) -> int:
	var fails: int = 0
	for def in GameManager.SPECIAL_CARD_DEFS:
		fails += await _check_one(main, def)
	return fails

func _check_one(main: Node, def: Dictionary) -> int:
	var fails: int = 0
	var label: String = str(def.get("special_id", "?"))

	GameManager.reset_game()
	GameManager.hand[0] = def.duplicate()
	GameManager.operation_points = 20
	main._refresh_ui()
	await get_tree().process_frame

	# The replacement card is forced to look IDENTICAL to the special card, the
	# worst case for the old visual-key diff.
	var res: Dictionary = GameManager.use_special_ability(0)
	if res.get("valid", false) and str(res.get("special_id", "")) != "":
		# _on_card_special_used consumes the card itself, so redo it properly.
		pass
	GameManager.reset_game()
	GameManager.hand[0] = def.duplicate()
	GameManager.operation_points = 20
	main._refresh_ui()
	await get_tree().process_frame

	# Pre-seed the draw pile so the refill matches the special card exactly.
	_force_next_draw_like(def)

	await main._on_card_special_used({"type": "hand", "hand_index": 0})
	await get_tree().create_timer(0.6).timeout

	var panel: Control = main.hand_card_views[0]["panel"]
	var lbl: Label = main.hand_card_views[0]["letter"]
	fails += _check(is_equal_approx(panel.modulate.a, 1.0),
		"[%s] hand panel 0 is fully opaque after the draw (alpha=%.2f)" % [label, panel.modulate.a])
	fails += _check(panel.modulate.r > 0.05 and panel.modulate.g > 0.05 and panel.modulate.b > 0.05,
		"[%s] hand panel 0 kept a neutral colour (%s)" % [label, str(panel.modulate)])
	fails += _check(panel.scale.is_equal_approx(Vector2.ONE),
		"[%s] hand panel 0 is back to full size (%s)" % [label, str(panel.scale)])
	fails += _check(str(lbl.text) != "-" and not str(lbl.text).is_empty(),
		"[%s] hand panel 0 shows a letter ('%s')" % [label, lbl.text])
	return fails

## Puts a card on top of the draw pile whose letter/colour/damage match `def`,
## so the refill after the special is visually identical to the used card.
func _force_next_draw_like(def: Dictionary) -> void:
	if str(def.get("special_id", "")) in ["royal_summon", "jack_in_the_box", "vowel_shift"]:
		# These replace the card with a fixed card, not a draw.
		return
	GameManager.deck.append({
		"letter": def.get("letter", "E"),
		"damage": def.get("damage", 1),
		"color": def.get("color", "red")
	})

func _finish(fails: int) -> void:
	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)

func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
