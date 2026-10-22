extends "res://src/ui/FlowScreen.gd"

func _ready() -> void:
	build_screen()
	caption(content, "SPELL • STRATEGY • SURVIVE", 15, ACCENT)
	caption(content, "WORDGAME", 64)
	caption(content, "ことばを組み、夜を切り抜ける。", 24, MUTED)
	var body := panel(content)
	caption(body, "英単語 × カード × 昼と夜", 23)
	caption(body, "文字をつないで敵を攻撃。色をそろえて効果を伸ばし、\n夜はスロットの位置を読んで危険を避けよう。", 18, MUTED)
	var start := action(body, "通常プレイをはじめる", open_game, true)
	start.name = "StartButton"
	var practice := action(body, "はじめての方へ：体験チュートリアル", func() -> void:
		get_tree().change_scene_to_file("res://src/Tutorial.tscn"))
	practice.name = "TutorialButton"
	caption(body, "約2分 / 3つのレッスン / 時間制限なし", 15, MUTED)
	caption(content, "クリック・タップで操作   |   Tab で選択 / Enter で決定", 14, MUTED)
	start.grab_focus()
