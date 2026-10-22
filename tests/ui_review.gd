extends Node

func _ready() -> void:
	GameManager.reset_game()
	GameManager.set_enemy_name("STONE")
	GameManager.hand[0] = {"letter": "?", "damage": 0, "color": "blue"}
	if OS.get_cmdline_user_args().has("--relic-hand"):
		GameManager.relic_hand_bonus = 1
		GameManager.relic_opening_bonus = 2
		GameManager._reapply_relic_buffs()
		GameManager._reset_hand()
	var main = load("res://src/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	for frame in range(8):
		await get_tree().process_frame
	assert(not main.get_node("Scroll/Center/VBox/GameOverButtonRow").visible, "Retry controls must stay hidden during play")
	var layout: VBoxContainer = main.get_node("Scroll/Center/VBox")
	assert(layout.get_global_rect().position.y >= 0 and layout.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y, "Gameplay controls must fit the viewport")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/ui_main.png")
	main.add_card_to_workbench({"type": "hand", "hand_index": 0, "letter": "?", "card_letter": "?", "char": "?", "damage": 0, "color": "blue"})
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/ui_wildcard.png")
	get_tree().quit()
