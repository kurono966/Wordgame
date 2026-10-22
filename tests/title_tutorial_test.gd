extends Node
var failures: int = 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func _ready() -> void:
	await get_tree().process_frame
	# Keep this harness alive while the real scenes change underneath it.
	get_tree().current_scene = null
	var title = load("res://src/Title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	check(title.find_child("StartButton", true, false) != null, "Title has normal play")
	check(title.find_child("TutorialButton", true, false) != null, "Title has tutorial")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/title_preview.png")
	title.queue_free()
	await get_tree().process_frame
	var tutorial = load("res://src/Tutorial.tscn").instantiate()
	add_child(tutorial)
	await get_tree().process_frame
	check(tutorial.lesson == 0 and not tutorial.solved, "Starts at first lesson")
	tutorial.advance()
	check(tutorial.lesson == 0, "Cannot skip an unfinished lesson")
	tutorial.choose_card(0)
	tutorial.choose_card(1)
	tutorial.choose_card(2)
	tutorial.submit_word()
	check(not tutorial.solved and tutorial.feedback != "", "Wrong order gives retry feedback")
	tutorial.clear_word()
	tutorial.choose_card(1)
	tutorial.choose_card(1)
	check(tutorial.selected.size() == 1, "Cannot reuse a card")
	tutorial.choose_card(2)
	tutorial.choose_card(0)
	tutorial.submit_word()
	check(tutorial.solved and tutorial.last_damage == 5, "CAT attacks with real mixed-color rules")
	tutorial.advance()
	check(tutorial.lesson == 1, "Advances to color lesson")
	tutorial.choose_card(1)
	tutorial.choose_card(2)
	tutorial.choose_card(0)
	tutorial.submit_word()
	check(tutorial.solved and GameManager.enemy_hp == 480, "Three red cards really deal 20 damage")
	tutorial.advance()
	check(GameManager.will_skill_fire_at_night(), "Danger card starts in bottom row")
	tutorial.resolve_night()
	check(not tutorial.solved and GameManager.enemy_shield == 6, "Unmoved danger fires actual AEGIS and permits retry")
	tutorial.prepare_lesson()
	check(GameManager.enemy_shield == 0, "Retry resets enemy effects")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/tutorial_preview.png")
	tutorial.spin_training_reel()
	check(GameManager.operation_points == 0, "SPIN spends one OP")
	check(not GameManager.will_skill_fire_at_night(), "SPIN moves danger off bottom")
	tutorial.resolve_night()
	check(tutorial.solved and GameManager.enemy_shield == 0, "Night succeeds without enemy skill")
	check(GameManager.player_hp < GameManager.player_max_hp, "Ordinary night damage is still demonstrated")
	tutorial.advance()
	check(tutorial.lesson == 3 and GameManager.enemy_max_hp == GameManager.ENEMY_BASE_HP, "Completion restores clean game state")
	tutorial.restart()
	check(tutorial.lesson == 0 and not tutorial.solved, "Tutorial can restart")
	tutorial.open_game()
	tutorial.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().current_scene.scene_file_path == "res://src/Main.tscn", "Completion starts normal game")
	check(GameManager.enemy_max_hp == GameManager.ENEMY_BASE_HP and GameManager.operation_points == 0, "Normal game receives no tutorial stats")
	check(GameManager.turn == 0 and GameManager.relics.is_empty(), "Normal run starts fresh")
	check(get_tree().current_scene.get_node("Scroll/Center/VBox/ControlRow/TitleButton") != null, "Normal game has title navigation")
	get_tree().current_scene._turn_resolving = true
	get_tree().current_scene._title_confirmation.confirmed.emit()
	await get_tree().process_frame
	check(get_tree().current_scene.scene_file_path == "res://src/Main.tscn", "Cannot leave during turn animation")
	get_tree().current_scene._turn_resolving = false
	get_tree().current_scene._title_confirmation.confirmed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().current_scene.scene_file_path == "res://src/Title.tscn", "Normal game returns to title")
	get_tree().current_scene.find_child("TutorialButton", true, false).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().current_scene.scene_file_path == "res://src/Tutorial.tscn", "Title opens tutorial")
	get_tree().current_scene.open_title()
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().current_scene.scene_file_path == "res://src/Title.tscn", "Tutorial can exit to title")
	get_tree().current_scene.open_game()
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().current_scene.scene_file_path == "res://src/Main.tscn", "Title starts normal play")
	print("TITLE_TUTORIAL_FAILURES=%d" % failures)
	get_tree().quit(failures)
