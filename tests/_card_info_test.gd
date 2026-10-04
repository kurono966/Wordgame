extends SceneTree

# Checks that a card's full readout is visible wherever the player chooses a
# card: the always-available deck viewer and the shop's compression picker. The
# point is that a ★ SPECIAL must never be reduced to a bare letter and a number
# in a place where you are deciding whether to throw the card away.

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

	# Give the player a known special so the assertions have something to find.
	var special: Dictionary = {}
	for s: Dictionary in gm.SPECIAL_CARD_DEFS:
		special = s.duplicate()
		break
	fails += _check(gm.has_special_ability(special), "the fixture special really is special")
	gm.reset_game()
	gm.deck.clear()
	gm.deck.append(special)
	gm.deck.append({"letter": "A", "damage": 1, "color": "green"})
	await process_frame

	# ---- the detail text ------------------------------------------------
	var detail: String = main._card_detail_text(special)
	print("detail:\n", detail)
	fails += _check(detail.contains(gm.get_special_name(special)),
		"the detail names the special")
	fails += _check(detail.contains(str(gm.get_special_cost(special))),
		"the detail gives its OP cost")
	fails += _check(detail.contains(gm.get_special_desc(special)),
		"the detail gives its description")
	var plain: String = main._card_detail_text({"letter": "A", "damage": 1, "color": "green"})
	fails += _check(not plain.contains("★"), "a plain card does not claim a special")
	fails += _check(plain.contains("No special"), "a plain card says so plainly")

	# ---- the deck viewer, which is always available ---------------------
	var piles = main.get_node("PilesDialog")
	fails += _check(not (piles as Control).visible, "the deck viewer starts closed")
	main._open_piles_dialog()
	await process_frame
	fails += _check((piles as Control).visible, "the deck viewer opens")
	var pile_tiles: Array = _find_tiles(piles, "Button")
	print("deck tiles: ", pile_tiles.size())
	fails += _check(pile_tiles.size() >= 2, "every deck card is shown")
	# The viewer lists the whole run (draw pile + hand + graveyard), so find the
	# tile for OUR special rather than assuming a position.
	var special_tile: Button = _tile_with(pile_tiles, gm.get_special_name(special))
	fails += _check(special_tile != null, "the deck viewer has a tile for the special")
	if special_tile != null:
		fails += _check((special_tile as Button).tooltip_text.contains(
				gm.get_special_desc(special)),
			"the deck viewer exposes the special's full description")
		fails += _check(_label_text_of(special_tile).contains(gm.get_special_name(special)),
			"the special name is printed ON the tile, not only in the tooltip")
		fails += _check(_vbox_height_ok(special_tile),
			"the tile is tall enough to show its special without clipping")

	# ---- it must be reachable AT ANY TIME, not only during a reward ------
	main._close_piles_dialog()
	fails += _check(not (piles as Control).visible, "the viewer closed")
	# No reward dialog is up: this is ordinary play. The D shortcut must work.
	var piles_button = main.get_node("Scroll/Center/VBox/ControlRow/PilesButton")
	fails += _check((piles_button as Button).visible,
		"the CARD PILES button is on screen during ordinary play")
	main._unhandled_key_input(_key(KEY_D))
	await process_frame
	fails += _check((piles as Control).visible,
		"pressing D opens the deck viewer mid-fight, with no reward up")
	main._unhandled_key_input(_key(KEY_ESCAPE))
	await process_frame
	fails += _check(not (piles as Control).visible, "Esc closes it again")

	# ---- the shop's compression picker ----------------------------------
	gm.open_shop()
	main._open_shop_dialog()
	await process_frame
	var shop = main.get_node("ShopDialog")
	var shop_tiles: Array = _find_tiles(shop, "Button")
	print("shop tiles: ", shop_tiles.size())
	fails += _check(shop_tiles.size() >= 2, "the shop lists the deck too")
	var shop_tile: Button = _tile_with(shop_tiles, gm.get_special_name(special))
	fails += _check(shop_tile != null, "the shop picker has a tile for the special")
	if shop_tile != null:
		fails += _check((shop_tile as Button).tooltip_text.contains(
				gm.get_special_desc(special)),
			"the shop picker exposes the special's full description")
		fails += _check(_label_text_of(shop_tile).contains(gm.get_special_name(special)),
			"the special name is printed ON the shop tile")
		fails += _check(_vbox_height_ok(shop_tile),
			"the shop tile is tall enough to show its special")

	# The grid must not overflow the dialog panel.
	var panel = shop.get_node("DialogPanel")
	fails += _check((panel as Control).get_combined_minimum_size().x <= 1000,
		"the shop dialog still fits the window")

	var vbox = main.get_node("Scroll/Center/VBox")
	fails += _check(vbox.get_combined_minimum_size().y <= WINDOW_H,
		"the board still fits 800px (%.0f)" % vbox.get_combined_minimum_size().y)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	quit(fails)


## Every Button of `kind` under `node`, recursively.
func _find_tiles(node: Node, kind: String) -> Array:
	var out: Array = []
	if node.is_class(kind):
		out.append(node)
	for child in node.get_children():
		out += _find_tiles(child, kind)
	return out


## A plain key press, for the shortcut checks.
func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


## The first tile whose own text or tooltip names `needle`, or null.
func _tile_with(tiles: Array, needle: String) -> Button:
	for t: Button in tiles:
		if _label_text_of(t).contains(needle):
			return t
		if (t as Button).tooltip_text.contains(needle):
			return t
	return null


## All the text inside a tile, so an assertion does not care which label it is.
func _label_text_of(tile: Node) -> String:
	var out: String = ""
	for child in tile.get_children():
		if child is Label:
			out += (child as Label).text + " "
		else:
			out += _label_text_of(child)
	return out


## The tile is tall enough to fit the labels it actually holds.
func _vbox_height_ok(tile: Node) -> bool:
	var need: float = 0.0
	for child in tile.get_children():
		if child is Label:
			need += (child as Label).get_combined_minimum_size().y
		else:
			need += (child as Control).get_combined_minimum_size().y
	return need <= (tile as Control).custom_minimum_size.y


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1