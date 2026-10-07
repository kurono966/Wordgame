extends PanelContainer

# DraggableCard.gd - Click, hold, flick and drag-and-drop on card panels.
#
# Supports desktop and mobile touch gestures:
#   * Click / Tap: Quick press and release in place -> clicked(card_data) (drops to workbench)
#   * Drag & Drop: Drag downwards/sideways past threshold -> Godot drag to workbench/slots
#   * Hold (Long Press): Hold pointer still for SPECIAL_HOLD_TIME -> special_used(card_data)
#   * Flick / Swipe Up: Flick or drag upward by FLICK_UP_DISTANCE -> special_used(card_data)
#   * Right Click: Instant special activation (desktop right-click shortcut)

signal clicked(card_data: Dictionary)
signal special_used(card_data: Dictionary)

const SPECIAL_HOLD_TIME: float = 0.6   # Seconds to hold for special ability
const DRAG_START_DISTANCE: float = 10.0 # Pointer travel (px) that turns a press into standard drag
const FLICK_UP_DISTANCE: float = 28.0   # Upward travel (px) to activate special ability
const FLICK_VELOCITY_Y: float = -180.0  # Upward velocity (px/s) for quick flick

var card_data: Dictionary = {}
var _pressing: bool = false
var _press_time: float = 0.0
var _press_origin: Vector2 = Vector2.ZERO
var _current_pos: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _special_fired: bool = false
var _press_tween: Tween = null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_press(mb.position)
			else:
				_end_press(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_trigger_special()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin_press(st.position)
		else:
			_end_press(st.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_handle_motion(mm.position, mm.velocity)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_handle_motion(sd.position, sd.velocity)


func _process(delta: float) -> void:
	if _pressing and not _special_fired and not _dragging:
		_press_time += delta
		# Visual cue: slight scale-up during hold so player knows it is charging
		if is_inside_tree() and _press_time > 0.08:
			var t: float = clampf((_press_time - 0.08) / (SPECIAL_HOLD_TIME - 0.08), 0.0, 1.0)
			pivot_offset = size * 0.5
			scale = Vector2.ONE.lerp(Vector2(1.08, 1.08), t)
		if _press_time >= SPECIAL_HOLD_TIME:
			_trigger_special()


func _begin_press(at_position: Vector2) -> void:
	_pressing = true
	_press_time = 0.0
	_press_origin = at_position
	_current_pos = at_position
	_velocity = Vector2.ZERO
	_dragging = false
	_special_fired = false
	pivot_offset = size * 0.5


func _handle_motion(pos: Vector2, vel: Vector2) -> void:
	_current_pos = pos
	_velocity = vel
	if _pressing and not _dragging and not _special_fired:
		var delta_pos := pos - _press_origin
		# 1. Flick Up detection (upward swipe/flick for special ability)
		var is_upward: bool = delta_pos.y < 0.0 and abs(delta_pos.y) >= abs(delta_pos.x) * 0.5
		if is_upward:
			if delta_pos.y <= -FLICK_UP_DISTANCE or (delta_pos.y <= -14.0 and vel.y <= FLICK_VELOCITY_Y):
				_trigger_special()
				return

		# 2. Regular drag detection (moving sideways or downward towards workbench)
		if delta_pos.length() > DRAG_START_DISTANCE:
			_dragging = true
			_special_fired = true
			_reset_visual()


func _trigger_special() -> void:
	_special_fired = true
	_pressing = false
	_dragging = false
	if is_inside_tree():
		if _press_tween and _press_tween.is_valid():
			_press_tween.kill()
		pivot_offset = size * 0.5
		_press_tween = create_tween()
		_press_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)
		_press_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	special_used.emit(card_data)


func _reset_visual() -> void:
	if is_inside_tree():
		if _press_tween and _press_tween.is_valid():
			_press_tween.kill()
		_press_tween = create_tween()
		_press_tween.tween_property(self, "scale", Vector2.ONE, 0.1)


func _end_press(release_pos: Vector2 = Vector2.ZERO) -> void:
	if not _pressing:
		return
	_pressing = false
	_reset_visual()
	if _dragging or _special_fired:
		return

	# Check for quick flick released before distance threshold was reached in motion
	if release_pos != Vector2.ZERO:
		var delta_pos := release_pos - _press_origin
		var is_upward: bool = delta_pos.y < 0.0 and abs(delta_pos.y) >= abs(delta_pos.x) * 0.5
		if is_upward and (delta_pos.y <= -FLICK_UP_DISTANCE or _velocity.y <= FLICK_VELOCITY_Y or (delta_pos.y <= -14.0 and _press_time < 0.35)):
			_trigger_special()
			return

	clicked.emit(card_data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_pressing = false
		_dragging = false
		_reset_visual()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if card_data.is_empty():
		return null

	_dragging = true
	_special_fired = true
	_reset_visual()

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
