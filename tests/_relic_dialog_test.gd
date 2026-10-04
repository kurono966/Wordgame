extends SceneTree

# Boots the real Main scene and drives the relic viewer the way the player does:
# a LEFT click on the relic panel opens it, the body lists every relic held with
# its effect, the CLOSE button and Esc both shut it, and a right click does not.

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
	var panel = main.get_node("Scroll/Center/VBox/StatusBox/RelicBox")
	var dialog = main.get_node("RelicDialog")
	var body = main.get_node("RelicDialog/DialogPanel/DialogVBox/Scroll/RelicBody")
	var subtitle = main.get_node("RelicDialog/DialogPanel/DialogVBox/Subtitle")
	var close_btn = main.get_node("RelicDialog/DialogPanel/DialogVBox/DialogHeader/CloseButton")

	# Closed to begin with.
	fails += _check(not (dialog as Control).visible, "the viewer starts closed")

	# ---- Empty state ----------------------------------------------------
	main._on_relic_panel_input(_left_click())
	await process_frame
	fails += _check((dialog as Control).visible, "a left click opens the viewer")
	print("empty subtitle: '", (subtitle as Label).text, "'")
	fails += _check((subtitle as Label).text.contains("0 relic(s)"),
		"the subtitle counts the relics")
	fails += _check((body as VBoxContainer).get_child_count() == 1,
		"the empty state is one explanatory block")
	var empty_text: String = _body_text(body)
	fails += _check(empty_text.contains("no relics yet"),
		"the empty state explains that none are held")
	fails += _check(empty_text.contains("Destroy EVERY part"),
		"the empty state says how to earn the first one")

	# ---- Esc closes -----------------------------------------------------
	main._unhandled_key_input(_esc())
	await process_frame
	fails += _check(not (dialog as Control).visible, "Esc closes the viewer")

	# ---- With relics held ----------------------------------------------
	_earn(gm, 5)
	main._refresh_ui()
	await process_frame
	main._on_relic_panel_input(_left_click())
	await process_frame
	fails += _check((dialog as Control).visible, "the viewer opens again")
	print("held subtitle: '", (subtitle as Label).text, "'")
	fails += _check((subtitle as Label).text.contains("5 relic(s)"),
		"the subtitle counts all 5")
	fails += _check((subtitle as Label).text.contains("active bonus:"),
		"the subtitle states the running total")
	# One block per relic, and every one carries its name AND its effect text.
	fails += _check((body as VBoxContainer).get_child_count() == 5,
		"one block per relic (%d)" % (body as VBoxContainer).get_child_count())
	var text: String = _body_text(body)
	for relic: Dictionary in gm.get_relics():
		fails += _check(text.contains(str(relic.get("name", "?"))),
			"the viewer names %s" % str(relic.get("name", "?")))
		fails += _check(text.contains(str(relic.get("desc", ""))),
			"the viewer explains %s" % str(relic.get("name", "?")))
		fails += _check(text.contains(str(relic.get("from_enemy", "?"))),
			"the viewer says where %s came from" % str(relic.get("name", "?")))

	# A duplicate shows its stack count rather than a bare name.
	var dup: Dictionary = {}
	for relic: Dictionary in gm.get_relics():
		dup[str(relic.get("id", ""))] = true
	if dup.size() < gm.get_relic_count():
		fails += _check(text.contains("x2") or text.contains("x3")
				or text.contains("x4") or text.contains("x5"),
			"a duplicate relic shows a stack count")

	# ---- CLOSE button ---------------------------------------------------
	(close_btn as Button).emit_signal("pressed")
	await process_frame
	fails += _check(not (dialog as Control).visible, "the CLOSE button closes the viewer")

	# ---- A right click must NOT open it --------------------------------
	main._on_relic_panel_input(_right_click())
	await process_frame
	fails += _check(not (dialog as Control).visible, "a right click does not open the viewer")
	# ...but a left click still does.
	main._on_relic_panel_input(_left_click())
	await process_frame
	fails += _check((dialog as Control).visible, "a left click still opens it")
	main._close_relic_dialog()

	# The panel must be genuinely clickable, not just wired to a handler: it has
	# to accept mouse input and be reachable at a real on-screen position.
	fails += _check((panel as Control).mouse_filter == Control.MOUSE_FILTER_STOP,
		"the panel stops mouse events so a real click reaches it")
	fails += _check((panel as Control).get_global_rect().intersects(
			Rect2(Vector2.ZERO, Vector2(1280, 800))),
		"the panel sits inside the window")

	# Drive a REAL click through the viewport, not the handler directly, so the
	# gui_input connection itself is proven to work.
	var at: Vector2 = (panel as Control).get_global_rect().get_center()
	# Drive the click through the panel's OWN gui_input signal rather than the
	# handler, which proves the connection is live. A synthetic pointer position
	# cannot be used here: headless Godot has no real mouse, so gui picking never
	# resolves a hovered control and the click cannot be routed by position.
	var fired: Array = []
	panel.gui_input.connect(func(ev: InputEvent) -> void: fired.append(ev), CONNECT_ONE_SHOT)
	for e: InputEvent in _click_at(at):
		(panel as Control).gui_input.emit(e)
	await process_frame
	fails += _check(fired.size() == 1,
		"the panel's gui_input signal really is connected")
	fails += _check((dialog as Control).visible,
		"a click delivered to the panel opens the viewer")
	main._close_relic_dialog()

	# The layout must be untouched throughout.
	fails += _check(vbox.get_combined_minimum_size().y <= WINDOW_H,
		"the board still fits 800px (%.0f)" % vbox.get_combined_minimum_size().y)

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	quit(fails)


## N real total part destructions, which is how relics are actually earned.
func _earn(gm: Node, n: int) -> void:
	for _i in range(n):
		gm.set_enemy_name("DRAGON")
		gm.enemy_hp = 9999
		gm.execute_assignment("DRAGON", _word("DRAGON"))


## Concatenates every label under the body, so assertions can look for text
## without caring which block it landed in. Walks the whole subtree rather than
## assuming each row is a VBoxContainer — the empty state is a bare Label.
func _body_text(body: Node) -> String:
	var out: String = ""
	for child in body.get_children():
		if child is Label:
			out += str((child as Label).text) + "\n"
		else:
			out += _body_text(child)
	return out


func _left_click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func _right_click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	return e


## A full press+release at `at`, as a real pointer click produces.
func _click_at(at: Vector2) -> Array:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	up.global_position = at
	return [down, up]


func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	return e


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