extends PanelContainer

# DraggableCard.gd - Enables drag-and-drop & click interactions on card panels

signal clicked(card_data: Dictionary)
signal special_used(card_data: Dictionary)

const SPECIAL_HOLD_TIME: float = 0.8  # Seconds to hold for special ability

var card_data: Dictionary = {}
var _drag_preview: Control = null
var _pressing: bool = false
var _press_time: float = 0.0
var _special_fired: bool = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Reset hold tracking on new press
			_pressing = true
			_press_time = 0.0
			_special_fired = false
			clicked.emit(card_data)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_pressing = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			special_used.emit(card_data)

func _process(delta: float) -> void:
	if _pressing and not _special_fired:
		_press_time += delta
		if _press_time >= SPECIAL_HOLD_TIME:
			_special_fired = true
			special_used.emit(card_data)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if card_data.is_empty():
		return null

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
	sub.text = "%d dmg" % card_data.get("damage", 1)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.8, 0.9, 1, 0.9))
	vbox.add_child(sub)

	set_drag_preview(preview)
	return card_data
