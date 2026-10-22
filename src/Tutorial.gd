extends "res://src/ui/FlowScreen.gd"
## A deterministic, untimed practice board using the live combat rules.
var lesson: int = 0
var selected: Array[int] = []
var solved: bool = false
var night_attempted: bool = false
var feedback: String = ""
var last_damage: int = 0
var lesson_body: VBoxContainer
const COLOR_LABELS := {"red": "赤", "blue": "青", "green": "緑", "yellow": "黄"}
const COLOR_TINTS := {"red": Color("ff929c"), "blue": Color("9bc5ff"), "green": Color("8be6bf"), "yellow": Color("ffdb87")}

func _ready() -> void:
	build_screen()
	caption(content, "FIRST WORDS", 15, ACCENT)
	caption(content, "体験チュートリアル", 32)
	lesson_body = panel(content)
	action(content, "タイトルへ戻る", open_title)
	prepare_lesson()

func card(letter: String, color: String) -> Dictionary:
	for definition in GameManager.CARD_DEFS:
		if definition["letter"] == letter and definition["color"] == color:
			return definition.duplicate()
	push_error("Tutorial card is missing: %s / %s" % [letter, color])
	return {}

func prepare_lesson() -> void:
	GameManager.reset_game()
	if lesson < 3:
		GameManager.set_enemy_name("STONE")
		GameManager.enemy_hp = 500
		GameManager.enemy_max_hp = 500
		GameManager.enemy_skills.clear()
		GameManager.operation_points = 1
	selected.clear()
	solved = false
	night_attempted = false
	feedback = ""
	if lesson < 2:
		GameManager.hand = [card("T", "yellow" if lesson == 0 else "red"), card("C", "blue" if lesson == 0 else "red"), card("A", "green" if lesson == 0 else "red")]
	elif lesson == 2:
		GameManager.slots = [
			[card("A", "blue"), card("C", "red"), card("T", "green")],
			[card("E", "red"), card("I", "blue"), card("O", "green")],
			[card("N", "green"), card("R", "yellow"), card("S", "blue")]]
		GameManager.current_slot_indices = [0, 0, 0]
		GameManager.enemy_skills = [{"id": "aegis", "name": "AEGIS", "letter": "C", "value": 6}]
	render_lesson()

func render_lesson() -> void:
	for child in lesson_body.get_children():
		lesson_body.remove_child(child)
		child.queue_free()
	if lesson >= 3:
		caption(lesson_body, "LESSON COMPLETE", 18, ACCENT)
		caption(lesson_body, "準備ができました！", 30)
		caption(lesson_body, "単語を作る → 色を活かす → 夜の下段を確認する。\n通常プレイでは共有札と手札を組み合わせ、部位破壊や報酬も楽しめます。", 18)
		action(lesson_body, "新しく通常プレイをはじめる", open_game, true).grab_focus()
		action(lesson_body, "もう一度練習する", restart)
		return
	caption(lesson_body, "LESSON %02d / 03  •  時間制限なし" % (lesson + 1), 15, ACCENT)
	if lesson < 2:
		render_word_lesson()
	else:
		render_night_lesson()
	if not feedback.is_empty():
		caption(lesson_body, feedback, 18, ACCENT if solved else Color("ffdb87"))
	if solved:
		action(lesson_body, "次のレッスンへ" if lesson < 2 else "練習を完了する", advance, true).grab_focus()

func render_word_lesson() -> void:
	caption(lesson_body, "文字をつないで攻撃しよう" if lesson == 0 else "同じ単語で、赤の効果を比べよう", 24)
	caption(lesson_body, "C → A → T の順にカードを選び、「単語を提出」を押してください。" if lesson == 0 else "今度は赤3枚で CAT を作ります。赤の枚数が増えると攻撃の倍率が上がります。", 17, MUTED)
	if not solved:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		lesson_body.add_child(row)
		for i in range(GameManager.hand.size()):
			var data: Dictionary = GameManager.hand[i]
			var button := action(row, "%s\n%s / 攻撃 %d" % [data["letter"], COLOR_LABELS[data["color"]], data["damage"]], choose_card.bind(i))
			button.custom_minimum_size = Vector2(130, 86)
			button.add_theme_color_override("font_color", COLOR_TINTS[data["color"]])
			button.disabled = selected.has(i)
		caption(lesson_body, "作成中： %s" % (current_word() if not selected.is_empty() else "_ _ _"), 26)
		var buttons := HBoxContainer.new()
		lesson_body.add_child(buttons)
		action(buttons, "選び直す", clear_word)
		var submit := action(buttons, "単語を提出", submit_word, true)
		submit.disabled = selected.size() != 3
	else:
		caption(lesson_body, "CAT  /  %s" % GameManager.get_word_translation("cat"), 26)

func current_word() -> String:
	var value := ""
	for index in selected:
		value += str(GameManager.hand[index]["letter"])
	return value

func choose_card(index: int) -> void:
	if solved or lesson >= 2 or selected.has(index):
		return
	selected.append(index)
	feedback = ""
	render_lesson()

func clear_word() -> void:
	selected.clear()
	feedback = ""
	render_lesson()

func submit_word() -> void:
	if solved or lesson >= 2 or selected.size() != 3:
		return
	var word := current_word()
	if word != "CAT":
		feedback = "この練習では CAT を作ります。「選び直す」で何度でも試せます。"
		render_lesson()
		return
	var assignment: Array = []
	for index in selected:
		var source: Dictionary = GameManager.hand[index].duplicate()
		source["type"] = "hand"
		source["hand_index"] = index
		assignment.append(source)
	if not GameManager.dictionary.has(word.to_lower()) or not GameManager.is_assignment_valid(word, assignment):
		feedback = "カードの並びを確認してください。"
		render_lesson()
		return
	var result: Dictionary = GameManager.execute_assignment(word, assignment)
	var damage: int = int(result.get("group_damage", result.get("final_damage", 0)))
	solved = true
	if lesson == 0:
		last_damage = damage
		feedback = "成功！ CAT で %d ダメージ。日本語の意味も確認できます。\n次は同じ単語を赤いカードで作ってみましょう。" % damage
	else:
		feedback = "赤3枚の攻撃倍率は ×%s。%d → %d ダメージになりました！\n青はシールド、緑は回復、黄は操作ポイント（OP）に役立ちます。" % [str(GameManager.red_damage_multiplier(3)), last_damage, damage]
	render_lesson()

func render_night_lesson() -> void:
	caption(lesson_body, "夜の前に、危険カードを退避しよう", 24)
	caption(lesson_body, "敵スキルは、その文字の共有札が「下段」にある夜に発動します。\nいまは C が危険。SPIN（1 OP）で左のリールを1段進めてください。", 17, MUTED)
	var rows := ["上段", "中段：使える札", "下段：夜の判定"]
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	lesson_body.add_child(grid)
	for heading: String in ["位置", "左リール", "中央リール", "右リール"]:
		caption(grid, heading, 14, MUTED)
	for offset in [-1, 0, 1]:
		caption(grid, rows[offset + 1], 16, Color("ffdb87") if offset == 1 else MUTED)
		for slot in range(3):
			var cards: Array = GameManager.slots[slot]
			var index: int = posmod(GameManager.current_slot_indices[slot] + offset, cards.size())
			var letter: String = str(cards[index]["letter"])
			var tile := caption(grid, "[C ★]" if letter == "C" else "[ %s ]" % letter, 23, Color("ffdb87") if letter == "C" else INK)
			tile.custom_minimum_size.x = 110
	var danger := GameManager.will_skill_fire_at_night()
	caption(lesson_body, "OP：%d   /   Cの敵スキル：%s" % [GameManager.operation_points, "発動する！" if danger else "安全"], 19, Color("ff929c") if danger else ACCENT)
	if not night_attempted:
		var spin := action(lesson_body, "左のリールを SPIN（1 OP）", spin_training_reel, true)
		spin.disabled = GameManager.operation_points < 1
		action(lesson_body, "夜を迎えて結果を確かめる", resolve_night)
	elif not solved:
		action(lesson_body, "もう一度このレッスンを試す", prepare_lesson, true)

func spin_training_reel() -> void:
	if lesson != 2 or night_attempted:
		return
	var result: Dictionary = GameManager.spin_slot(0)
	if result.get("ok", false):
		feedback = "C が下段から中段へ移りました。「夜を迎える」で結果を確認しましょう。"
	render_lesson()

func resolve_night() -> void:
	if lesson != 2 or night_attempted:
		return
	night_attempted = true
	GameManager.is_night = true
	var result: Dictionary = GameManager.apply_turn_start_penalty()
	solved = not bool(result.get("skill_fired", false))
	feedback = "敵スキルを回避できました！\n夜の通常ダメージ %d は別の効果です。下段の色と攻撃値にも注意しましょう。" % int(result.get("applied_damage", 0)) if solved else "C が下段に残ったため、敵にシールドが付きました。\n何度でも練習できます。次は SPIN で C を退避しましょう。"
	render_lesson()

func advance() -> void:
	if not solved:
		return
	lesson += 1
	prepare_lesson()

func restart() -> void:
	lesson = 0
	last_damage = 0
	prepare_lesson()
