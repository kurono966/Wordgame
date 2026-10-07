extends Node

# Headless test for the card gesture model in DraggableCard.gd.
#
# Click, long-press and drag used to collide:
#   * `clicked` fired on mouse-PRESS, so touching a card placed it immediately and
#     a drag started from an already-placed card — the drop was then swallowed and
#     dragging appeared broken.
#   * A long press fired BOTH `special_used` and `clicked`.
#   * `_pressing` was never cleared on a lost pointer, so the special could re-fire.
#
# These checks drive the real script with synthetic input events.

func _ready() -> void:
	var fails: int = 0
	fails += _check_simple_click(main_free_card())
	fails += _check_click_needs_release(main_free_card())
	fails += _check_long_press_fires_special_only(main_free_card())
	fails += _check_drag_is_not_a_click(main_free_card())
	fails += _check_drag_data_disarms_click(main_free_card())
	fails += _check_drag_end_clears_press(main_free_card())
	fails += _check_right_click_fires_special(main_free_card())
	fails += _check_flick_up_fires_special(main_free_card())
	fails += _check_touch_events(main_free_card())

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)


## A fresh panel running the real DraggableCard script, plus its signal counters.
func main_free_card() -> Dictionary:
	var panel := PanelContainer.new()
	panel.set_script(load("res://src/ui/DraggableCard.gd"))
	panel.card_data = {"type": "hand", "hand_index": 0, "char": "E",
		"card_letter": "E", "damage": 1, "color": "red"}
	add_child(panel)
	var tally := {"clicks": 0, "specials": 0}
	panel.clicked.connect(func(_c): tally["clicks"] += 1)
	panel.special_used.connect(func(_c): tally["specials"] += 1)
	return {"panel": panel, "tally": tally}


func _press(panel, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	panel._gui_input(e)


func _release(panel, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = pos
	panel._gui_input(e)


func _move(panel, pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	panel._gui_input(e)


## A quick press and release in place is exactly one click.
func _check_simple_click(c: Dictionary) -> int:
	var panel = c["panel"]
	var t = c["tally"]
	_press(panel, Vector2(50, 50))
	_release(panel, Vector2(50, 50))
	return _check(t["clicks"] == 1 and t["specials"] == 0,
		"a quick press+release is one click and no special (%s)" % str(t))


## The press alone must NOT place the card: that was what broke dragging.
func _check_click_needs_release(c: Dictionary) -> int:
	var panel = c["panel"]
	var t = c["tally"]
	_press(panel, Vector2(50, 50))
	var after_press: int = t["clicks"]
	_release(panel, Vector2(50, 50))
	return _check(after_press == 0 and t["clicks"] == 1,
		"a press emits nothing until the button is released (press=%d, now=%d)"
			% [after_press, t["clicks"]])


## Holding fires the special exactly once, and is never also a click.
func _check_long_press_fires_special_only(c: Dictionary) -> int:
	var panel = c["panel"]
	var t = c["tally"]
	_press(panel, Vector2(50, 50))
	# Simulate holding past the threshold.
	panel._process(panel.SPECIAL_HOLD_TIME + 0.1)
	var fired_after_first: int = t["specials"]
	# Keep holding: it must not fire again.
	panel._process(panel.SPECIAL_HOLD_TIME)
	_release(panel, Vector2(50, 50))
	return _check(fired_after_first == 1 and t["specials"] == 1 and t["clicks"] == 0,
		"a hold fires the special once, never twice, and is not a click (%s)" % str(t))


## Moving the pointer past the threshold makes it a drag, not a click.
func _check_drag_is_not_a_click(c: Dictionary) -> int:
	var panel = c["panel"]
	var t = c["tally"]
	_press(panel, Vector2(50, 50))
	_move(panel, Vector2(50 + panel.DRAG_START_DISTANCE + 6.0, 50))
	# Holding while "dragging" must not trigger the special either.
	panel._process(panel.SPECIAL_HOLD_TIME + 0.1)
	_release(panel, Vector2(200, 50))
	return _check(t["clicks"] == 0 and t["specials"] == 0,
		"moving the pointer turns the gesture into a drag (no click, no special) (%s)" % str(t))


## Godot only calls _get_drag_data after ITS threshold, so reaching it must also
## disarm the click even if no motion event was delivered to us.
func _check_drag_data_disarms_click(c: Dictionary) -> int:
	var panel = c["panel"]
	var t = c["tally"]
	_press(panel, Vector2(50, 50))
	var data = panel._get_drag_data(Vector2(50, 50))
	_release(panel, Vector2(50, 50))
	return _check(data == panel.card_data and t["clicks"] == 0,
		"_get_drag_data returns the card and cancels the click (%s)" % str(t))


## Ending a drag clears the pending press, so no stray timer fires later.
func _check_drag_end_clears_press(c: Dictionary) -> int:
	var panel = c["panel"]
	var t = c["tally"]
	_press(panel, Vector2(50, 50))
	panel._notification(Control.NOTIFICATION_DRAG_END)
	# Time passing after the drag ended must not fire the special.
	panel._process(panel.SPECIAL_HOLD_TIME + 0.5)
	return _check(t["specials"] == 0,
		"a drag ending clears the press, so no special fires afterwards (%s)" % str(t))


func _check_right_click_fires_special(c: Dictionary) -> int:
	var panel = c["panel"]
	var t = c["tally"]
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	panel._gui_input(e)
	return _check(t["specials"] == 1 and t["clicks"] == 0,
		"a right click fires the special and is not a click (%s)" % str(t))


## Swiping upward past FLICK_UP_DISTANCE triggers the special immediately.
func _check_flick_up_fires_special(c: Dictionary) -> int:
	var panel = c["panel"]
	var t = c["tally"]
	_press(panel, Vector2(50, 50))
	_move(panel, Vector2(50, 50 - panel.FLICK_UP_DISTANCE - 4.0))
	_release(panel, Vector2(50, 50 - panel.FLICK_UP_DISTANCE - 4.0))
	return _check(t["specials"] == 1 and t["clicks"] == 0,
		"flicking upward fires the special and is not a click (%s)" % str(t))


## Screen touch and drag events behave identically to mouse on mobile.
func _check_touch_events(c: Dictionary) -> int:
	var panel = c["panel"]
	var t = c["tally"]
	var st_press := InputEventScreenTouch.new()
	st_press.pressed = true
	st_press.position = Vector2(50, 50)
	panel._gui_input(st_press)

	var sd := InputEventScreenDrag.new()
	sd.position = Vector2(50, 50 - panel.FLICK_UP_DISTANCE - 4.0)
	panel._gui_input(sd)

	var st_release := InputEventScreenTouch.new()
	st_release.pressed = false
	st_release.position = Vector2(50, 50 - panel.FLICK_UP_DISTANCE - 4.0)
	panel._gui_input(st_release)
	return _check(t["specials"] == 1 and t["clicks"] == 0,
		"screen touch and drag upward fires special (%s)" % str(t))


func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
