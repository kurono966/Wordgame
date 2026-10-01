

extends SceneTree

# Measures the real minimum size required by the current UI so the fixed
# viewport can be sized to avoid any scrolling.

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	await process_frame
	var main = (load("res://src/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var vbox = main.get_node("Scroll/Center/VBox")
	print("VBox min size: ", vbox.get_combined_minimum_size())
	print("Center min size: ", (main.get_node("Scroll/Center") as Control).get_combined_minimum_size())
	print("root viewport size: ", root.size)
	var rows: Array = []
	for child in vbox.get_children():
		if child is Control:
			rows.append("%s=%s" % [child.name, (child as Control).get_combined_minimum_size()])
	print("\n".join(rows))
	print("TEST_EXIT=0")
	quit(0)
