extends PanelContainer

# DraggableCard.gd - Click, hold and drag-and-drop on card panels.
#
# The three gestures used to fight each other:
#   * `clicked` fired on mouse-PRESS, so simply touching a card dropped it on the
#     Workbench. A drag then started from an already-placed card, and the drop was
#     swallowed by _is_card_in_workbench(), which is why dragging did nothing.
#   * The long-press fired `special_used` while `clicked` had already fired, so a
#     hold did BOTH at once.
#   * Holding never released `_pressing`, so the special could re-fire later.
#
# Now: a click is only a click if the pointer barely moved and the button was
# released quickly. Real movement hands the gesture over to Godot's drag system,
# and a completed drag is never also treated as a click.

signal clicked(card_data: Dictionary)
signal special_used(card_data: Dictionary)

const SPECIAL_HOLD_TIME: float = 0.8   # Seconds to hold for special ability
## Pointer travel (px) that turns a press into a drag. Godot's own drag threshold
## is 10px, so anything past this is unambiguously a drag and not a click.
const DRAG_START_DISTANCE: float = 8.0

var card_data: Dictionary = {}
var _pressing: bool = false
var _press_time: float = 0.0
var _press_origin: Vector2 = Vector2.ZERO
## Set once the pointer has travelled far enough to be a drag. From then on the
## gesture belongs to the drag system, never to the click/hold handlers.
var _dragging: bool = false
var _special_fired: bool = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_press(mb.position)
			else:
				_end_press()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			special_used.emit(card_data)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pressing and not _dragging:
			if _press_origin.distance_to(mm.position) > DRAG_START_DISTANCE:
				# The player is dragging, so the press no longer owes a click.
				_dragging = true
				_special_fired = true


func _process(delta: float) -> void:
	if _pressing and not _special_fired and not _dragging:
		_press_time += delta
		if _press_time >= SPECIAL_HOLD_TIME:
			_special_fired = true
			special_used.emit(card_data)


func _begin_press(at_position: Vector2) -> void:
	_pressing = true
	_press_time = 0.0
	_press_origin = at_position
	_dragging = false
	_special_fired = false


func _end_press() -> void:
	if not _pressing:
		return
	_pressing = false
	# A drag, or a hold that already spent the gesture on the special, is not a
	# click. Emitting here is what used to double up with the hold.
	if _dragging or _special_fired:
		return
	clicked.emit(card_data)


func _notification(what: int) -> void:
	# Losing the pointer (window focus, mouse left the screen) must not leave a
	# press pending, or the special would fire on a timer with nobody holding.
	if what == NOTIFICATION_DRAG_END:
		_pressing = false
		_dragging = false


func _get_drag_data(_at_position: Vector2) -> Variant:
	if card_data.is_empty():
		return null

	# Godot only calls this once the drag threshold is passed, so reaching here
	# means the gesture is definitively a drag.
	_dragging = true
	_special_fired = true

	# Create drag preview widget
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(80, 64)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.25, 0.35, 0.9)
	sb.border_color = Color(0.9, 0.8, 0.3, 1.0)
	sb.border_width_bottom = 2
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.set_corner_radius_all(8)
	preview.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	preview.add_child(vbox)

	var lbl := Label.new()
	lbl.text = card_data.get("char", "")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	vbox.add_child(lbl)

	var sub := Label.new()
	# A card's damage number doubles as its OP cost when it has a special
	if GameManager.has_special_ability(card_data):
		sub.text = "%d dmg ★ %d OP" % [card_data.get("damage", 1), GameManager.get_special_cost(card_data)]
		sub.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	else:
		sub.text = "%d dmg" % card_data.get("damage", 1)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.8, 0.9, 1, 0.9))
	vbox.add_child(sub)

	set_drag_preview(preview)
	return card_data
