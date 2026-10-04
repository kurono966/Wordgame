extends SceneTree

# Boots the real Main scene and checks the shop as the player meets it: it opens
# INSTEAD of the reward on a 3rd stage clear, the reward is NOT offered there, and
# the buy / compress buttons drive the real GameManager calls.

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

	var vbox = main.get_node("Scroll/Center/VBox")
	var shop = main.get_node("ShopDialog")
	var reward = main.get_node("RewardDialog")
	var body = main.get_node("ShopDialog/DialogPanel/DialogVBox/Scroll/ShopBody")
	var subtitle = main.get_node("ShopDialog/DialogPanel/DialogVBox/Subtitle")

	fails += _check(not (shop as Control).visible, "the shop starts closed")

	# ---- Opening the shop directly ----
	gm.reset_game()
	gm.operation_points = 200
	main._open_shop_dialog()
	await process_frame
	fails += _check((shop as Control).visible, "the shop opens")
	fails += _check(not gm.has_pending_reward(),
		"no reward is pending while the shop is open")
	print("subtitle: '", (subtitle as Label).text, "'")
	fails += _check((subtitle as Label).text.contains("200 OP"),
		"the subtitle shows the OP balance")
	fails += _check((subtitle as Label).text.contains("deck:"),
		"the subtitle shows the deck size")

	# The body must contain the three stock rows plus the compression section.
	var buttons: int = _count_buttons(body)
	print("buttons in shop body: ", buttons)
	fails += _check(buttons >= gm.SHOP_STOCK + 3,
		"the stock and all three compress buttons are present (%d)" % buttons)

	# ---- Buying through the real UI ----
	var deck_before: int = gm.get_deck_size()
	main._on_shop_buy(0)
	await process_frame
	fails += _check(gm.get_deck_size() == deck_before + 1,
		"buying through the UI adds the card to the deck")
	fails += _check(gm.get_operation_points() == 200 - gm.SHOP_CARD_COST,
		"and charges the listed price")
	fails += _check((body as VBoxContainer).get_child_count() > 0,
		"the shop body still renders after a purchase")

	# ---- Compression through the real UI ----
	main._shop_compress_picks = ["deck:0", "deck:1"]
	var op_now: int = gm.get_operation_points()
	var deck_now: int = gm.get_deck_size()
	# Compression is one card at a time, so selecting two and pressing the single
	# COMPRESS button must be refused and change nothing.
	main._on_shop_compress()
	await process_frame
	fails += _check(gm.get_deck_size() == deck_now,
		"selecting two cards and pressing COMPRESS removes nothing")
	fails += _check(gm.get_operation_points() == op_now, "and spends nothing")
	fails += _check(gm.shop_compress_count == 0, "and consumes no allowance")

	# With exactly one card selected it goes through.
	var one_price: int = gm.shop_compress_cost()
	main._shop_compress_picks = ["deck:0"]
	main._on_shop_compress()
	await process_frame
	fails += _check(gm.get_deck_size() == deck_now - 1,
		"compressing one card through the UI removes 1 card")
	fails += _check(gm.get_operation_points() == op_now - one_price,
		"and charges the single-card price (%d OP)" % one_price)
	fails += _check(main._shop_compress_picks.is_empty(),
		"the selection is cleared afterwards")

	# ---- An EMPTY selection is refused for free ----
	main._shop_compress_picks = []
	op_now = gm.get_operation_points()
	deck_now = gm.get_deck_size()
	# The successful compression above already used one allowance; an empty
	# selection must not use another.
	var used_before: int = gm.shop_compress_count
	main._on_shop_compress()
	await process_frame
	fails += _check(gm.get_deck_size() == deck_now,
		"pressing COMPRESS with nothing ticked changes nothing")
	fails += _check(gm.get_operation_points() == op_now, "and spends nothing")
	fails += _check(gm.shop_compress_count == used_before,
		"and consumes no further allowance")

	# ---- Esc closes, and the hand is settled on the way out ----
	main._unhandled_key_input(_esc())
	await process_frame
	fails += _check(not (shop as Control).visible, "Esc closes the shop")
	fails += _check(not gm.shop_open, "and the shop state is shut")

	# ---- The 2nd compression in the same visit costs more ----
	gm.reset_game()
	gm.open_shop()
	gm.operation_points = 1000
	var first_cost: int = gm.shop_compress_cost()
	main._shop_compress_picks = ["deck:0"]
	main._on_shop_compress()
	await process_frame
	fails += _check(gm.shop_compress_count == 1, "the first compression counted")
	var second_cost: int = gm.shop_compress_cost()
	fails += _check(second_cost > first_cost,
		"the second compression costs more (%d > %d)" % [second_cost, first_cost])
	fails += _check(gm.shop_compress_multiplier() > 1,
		"and the repeat multiplier is applied (x%d)" % gm.shop_compress_multiplier())
	main._close_shop_dialog()

	gm.reset_game()
	gm.operation_points = 500
	# Drive real clears until the shop should open, checking each one.
	for stage: int in [1, 2, 3]:
		var expect_shop: bool = gm.is_shop_stage(stage)
		gm.set_enemy_name("DRAGON")
		gm.enemy_hp = 9999
		var result: Dictionary = gm.execute_assignment("DRAGON", _word("DRAGON"))
		await main._finalize(result, {})
		await process_frame
		var got_shop: bool = (shop as Control).visible
		var got_reward: bool = (reward as Control).visible
		print("cleared stage %d -> shop=%s reward=%s (expected shop=%s)" % [
			stage, got_shop, got_reward, expect_shop])
		fails += _check(got_shop == expect_shop,
			"clearing stage %d %s the shop" % [stage,
				"opens" if expect_shop else "does NOT open"])
		if expect_shop:
			fails += _check(not got_reward,
				"the reward choice is NOT offered on a shop stage")
		else:
			fails += _check(got_reward,
				"the normal reward choice is offered on stage %d" % stage)
		# Settle whichever screen is up before the next stage.
		if got_shop:
			main._close_shop_dialog()
		else:
			main.reward_dialog.visible = false
			main.burn_dialog.visible = false
		main._refresh_ui()
		await process_frame

	fails += _check(vbox.get_combined_minimum_size().y <= WINDOW_H,
		"the board still fits 800px (%.0f)" % vbox.get_combined_minimum_size().y)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	quit(fails)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	quit(fails)


func _count_buttons(node: Node) -> int:
	var n: int = 1 if node is Button else 0
	for child in node.get_children():
		n += _count_buttons(child)
	return n


func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	return e


## A zero-damage assignment for `word`, so the submit is a pure part destruction.
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