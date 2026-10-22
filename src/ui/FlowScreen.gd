extends Control
## Shared presentation and navigation for the title and guided practice.
const INK := Color("e7edf8")
const MUTED := Color("a6b6ce")
const ACCENT := Color("73e0c1")
const BODY_FONT = preload("res://fonts/MochiyPopOne-Regular.ttf")
var content: VBoxContainer

func build_screen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("172c43"), Color("080e1c")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.ONE
	backdrop.texture = texture
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	center.add_child(content)
	resized.connect(_fit_content)
	_fit_content()

func _fit_content() -> void:
	if is_instance_valid(content):
		content.custom_minimum_size.x = minf(860.0, maxf(240.0, size.x - 64.0))

func caption(parent: Node, value: String, font_size: int = 18, tint: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	if font_size <= 24:
		label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_color_override("font_color", tint)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func action(parent: Node, value: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_font_override("font", BODY_FONT)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("244c4d") if primary else Color("1b2b40")
	normal.border_color = ACCENT if primary else Color("425671")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("35546b")
	button.add_theme_stylebox_override("hover", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("ffcf7f")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(10)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func panel(parent: Node) -> VBoxContainer:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111e30")
	style.border_color = Color("334963")
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	frame.add_theme_stylebox_override("panel", style)
	parent.add_child(frame)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	frame.add_child(body)
	return body

func open_game() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://src/Main.tscn")

func open_title() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://src/Title.tscn")
