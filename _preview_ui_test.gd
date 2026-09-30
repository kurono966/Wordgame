extends Node

# Headless UI test for the pre-submit damage preview label.

func _ready() -> void:
	var fails: int = 0
	await get_tree().process_frame
	var main = (load("res://Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	fails += _check(main != null, "Main.tscn instantiates with the new preview label")
	if main == null:
		print("FAILURES=%d" % fails)
		get_tree().quit(fails)
		return

	# Idle state before anything is placed
	fails += _check(str(main.preview_label.text).contains("preview"),
		"idle preview prompts the player to place cards ('%s')" % main.preview_label.text)

	# Place a real slot card + hand cards and check the preview reflects them
	var hand: Array = GameManager.get_hand()
	GameManager.hand[0] = {"letter": hand[0]["letter"], "damage": 1, "color": "green"}
	GameManager.hand[1] = {"letter": "E", "damage": 1, "color": "blue"}
	# Slot 0's ACTIVE card
	var slot0: Dictionary = GameManager.get_current_slot_card(0)
	# Use the REAL add path (add_card_to_workbench), because that is what the
	# player does and where the preview previously failed to update.
	main.add_card_to_workbench({
		"type": "slot", "index": 0, "char": slot0["letter"],
		"card_letter": slot0["letter"], "damage": slot0["damage"],
		"color": slot0.get("color", "red"), "is_wildcard": slot0["letter"] == "?"
	})
	await get_tree().process_frame
	fails += _check(str(main.preview_label.text).contains("ON SUBMIT"),
		"add_card_to_workbench() updates the preview ('%s')" % str(main.preview_label.text).substr(0, 60))

	# Removing it must return to the idle prompt, again via the real path
	await main.remove_card_from_workbench_at(0)
	await get_tree().process_frame
	fails += _check(str(main.preview_label.text).contains("preview"),
		"remove_card_from_workbench_at() restores the idle prompt ('%s')" % str(main.preview_label.text).substr(0, 60))

	# Re-place it for the remaining checks
	main.add_card_to_workbench({
		"type": "slot", "index": 0, "char": slot0["letter"],
		"card_letter": slot0["letter"], "damage": slot0["damage"],
		"color": slot0.get("color", "red"), "is_wildcard": slot0["letter"] == "?"
	})
	main._refresh_ui()
	await get_tree().process_frame

	var text: String = str(main.preview_label.text)
	fails += _check(text.contains("ON SUBMIT"), "preview shows the ON SUBMIT header ('%s')" % text)
	fails += _check(text.contains("YOU LOSE") or text.contains("HP"),
		"preview shows the HP outcome")
	fails += _check(text.contains("NIGHT") or text.contains("no NIGHT"),
		"preview shows the night penalty state")

	# Colour must reflect danger: green when safe, red when lethal
	var safe_color: Color = main.preview_label.get_theme_color("font_color")
	GameManager.shield = 0
	GameManager.player_hp = 1
	GameManager.is_night = false
	main._refresh_ui()
	await get_tree().process_frame
	var lethal_text: String = str(main.preview_label.text)
	var lethal_color: Color = main.preview_label.get_theme_color("font_color")
	fails += _check(lethal_text.contains("YOU LOSE"), "1 HP player will lose HP")
	fails += _check(lethal_color == main.PREVIEW_COLOR_HURT or lethal_color == main.PREVIEW_COLOR_LETHAL,
		"dangerous preview is coloured red/orange")
	print("preview text sample: ", lethal_text)

	# The label must be laid out and visible in the real UI, not just have text
	fails += _check(main.preview_label.is_visible_in_tree(),
		"preview label is visible in the tree")
	var vbox := main.get_node("Scroll/Center/VBox") as VBoxContainer
	fails += _check(main.preview_label.get_parent() == vbox,
		"preview label sits in the main VBox (not orphaned)")
	fails += _check(main.preview_label.size.y > 0.0,
		"preview label has a non-zero height (%.1f)" % main.preview_label.size.y)
	fails += _check(vbox.get_combined_minimum_size().y > 0.0,
		"VBox has a real minimum height (%.1f)" % vbox.get_combined_minimum_size().y)
	print("label rect: ", main.preview_label.get_global_rect(),
		" vbox min: ", vbox.get_combined_minimum_size())

	# Headless runs at a 64x64 viewport, so force the real 1280x800 window size
	# to measure whether the label is actually ON screen for the player.
	var vp := main.get_viewport()
	vp.size = Vector2i(1280, 800)
	await get_tree().process_frame
	await get_tree().process_frame
	var rect: Rect2 = main.preview_label.get_global_rect()
	print("label rect @1280x800: ", rect, " viewport: ", vp.size)
	fails += _check(rect.position.y >= 0.0 and rect.position.y < 800.0,
		"preview label is on screen vertically (y=%.1f < 800)" % rect.position.y)
	fails += _check(rect.end.y <= 800.0,
		"preview label fits inside the 800px window (bottom=%.1f)" % rect.end.y)

	# Meaning label: exists, is laid out, and stays on screen
	fails += _check(main.meaning_label != null and main.meaning_label.get_parent() == vbox,
		"meaning label is wired into the main VBox")
	fails += _check(main.meaning_label.is_visible_in_tree(), "meaning label is visible in the tree")
	fails += _check(main.meaning_label.size.y > 0.0,
		"meaning label has a non-zero height (%.1f)" % main.meaning_label.size.y)
	var mrect: Rect2 = main.meaning_label.get_global_rect()
	print("meaning rect: ", mrect)
	fails += _check(mrect.position.y >= 0.0 and mrect.end.y <= 800.0,
		"meaning label is fully on screen (y=%.1f..%.1f)" % [mrect.position.y, mrect.end.y])

	# Idle state: no word, so both meaning lines must be empty
	fails += _check(str(main.meaning_label.text).strip_edges() == "",
		"headword line is empty with an empty Workbench")
	fails += _check(str(main.definition_label.text).strip_edges() == "",
		"definition line is empty with an empty Workbench")
	fails += _check(main.definition_label.get_parent() == vbox,
		"definition label is wired into the main VBox")
	var drect: Rect2 = main.definition_label.get_global_rect()
	fails += _check(drect.position.y >= 0.0 and drect.end.y <= 800.0,
		"definition label is fully on screen (y=%.1f..%.1f)" % [drect.position.y, drect.end.y])
	print("definition rect: ", drect)

	# A cached Jisho entry must render kanji + reading + definitions
	JishoClient.clear_cache()
	JishoClient._cache["cachedword"] = JishoClient._make_result(
		"cachedword", "ok", "", "\u732B", "neko", "Noun", ["cat", "feline"])
	main._refresh_word_meaning("CACHEDWORD")
	fails += _check(str(main.meaning_label.text).contains("\u732B"),
		"meaning shows the kanji ('%s')" % main.meaning_label.text)
	fails += _check(str(main.meaning_label.text).contains("neko"),
		"meaning shows the reading")
	fails += _check(str(main.definition_label.text).to_lower().contains("feline"),
		"definition label carries the definitions ('%s')" % main.definition_label.text)

	# The text must never contain raw markup. Godot 4's Label cannot parse
	# BBCode, so a leftover "[color=...]" is drawn as literal characters — this
	# is exactly the bug that showed up on screen.
	var head_text: String = str(main.meaning_label.text)
	var def_text: String = str(main.definition_label.text)
	fails += _check(not head_text.contains("[color") and not head_text.contains("[/"),
		"headword text has no raw BBCode ('%s')" % head_text)
	fails += _check(not def_text.contains("[color") and not def_text.contains("[/"),
		"definition text has no raw BBCode ('%s')" % def_text)
	fails += _check(head_text.contains("\u732B"), "headword text has the kanji")
	fails += _check(head_text.contains("neko"), "headword text has the reading")
	# The two are separate labels so each can carry its own colour
	fails += _check(main.definition_label != main.meaning_label,
		"definitions use a separate label from the headword")
	fails += _check(main.meaning_label.get_theme_color("font_color") == main.MEANING_COLOR_JP,
		"headword is tinted with the kanji colour")
	fails += _check(main.definition_label.get_theme_color("font_color") == main.MEANING_COLOR_DEF,
		"definitions are tinted with the definition colour")
	print("head: ", head_text, "  def: ", def_text)

	# A miss must say so instead of showing stale text
	JishoClient._cache["missword"] = JishoClient._make_result("missword", "not_found")
	main._refresh_word_meaning("MISSWORD")
	fails += _check(str(main.meaning_label.text).to_lower().contains("no jisho entry"),
		"a miss reports 'no Jisho entry' ('%s')" % main.meaning_label.text)

	# A short word must clear the line rather than fire a request
	main._refresh_word_meaning("A")
	fails += _check(str(main.meaning_label.text).strip_edges() == "",
		"a 1-letter word clears the meaning line")

	# Clearing the workbench must clear the meaning too
	main.workbench_cards.clear()
	main._refresh_ui()
	await get_tree().process_frame
	fails += _check(str(main.meaning_label.text).strip_edges() == "",
		"clearing the Workbench clears the headword line")
	fails += _check(str(main.definition_label.text).strip_edges() == "",
		"clearing the Workbench clears the definition line")

	# Reward dialog: hidden by default, and it builds one button per option
	fails += _check(main.reward_dialog != null, "reward dialog exists")
	fails += _check(not main.reward_dialog.visible, "reward dialog starts hidden")
	main.show_reward_choice()
	await get_tree().process_frame
	fails += _check(main.reward_dialog.visible, "show_reward_choice() opens the dialog")
	var offered: Array = GameManager.get_reward_options()
	fails += _check(main.reward_row.get_child_count() == offered.size(),
		"one button per option (%d vs %d)" % [main.reward_row.get_child_count(), offered.size()])
	fails += _check(main.reward_row.get_child_count() == 3, "exactly three buttons")
	# Each button must be on screen and have a visible label
	for i in range(main.reward_row.get_child_count()):
		var btn: Button = main.reward_row.get_child(i) as Button
		fails += _check(btn != null and btn.get_child_count() > 0,
			"button %d has its content labels" % i)
		fails += _check(btn.get_global_rect().size.y > 0.0,
			"button %d has a real size (%.0fx%.0f)" % [i, btn.get_global_rect().size.x, btn.get_global_rect().size.y])

	# "ADD A CARD" must render the CONCRETE card it rolled. "BURN A CARD" is the
	# opposite: the player picks the card, so the button must NOT name one.
	var add_letter: String = ""
	var add_damage: String = ""
	var add_index: int = -1
	var burn_index: int = -1
	for i in range(offered.size()):
		var reward: Dictionary = offered[i]
		var rtype: String = str(reward.get("type", ""))
		if rtype == "add_card" and reward.has("card"):
			add_index = i
			var expected_letter: String = str(reward["card"].get("letter", ""))
			var expected_damage: String = "%d dmg" % int(reward["card"].get("damage", 0))
			var btn2: Button = main.reward_row.get_child(i) as Button
			var labels: Array = _collect_label_texts(btn2)
			fails += _check(labels.has(expected_letter),
				"add reward %d shows the card letter '%s' (got %s)" % [i, expected_letter, str(labels)])
			fails += _check(labels.has(expected_damage),
				"add reward %d shows the damage '%s'" % [i, expected_damage])
			add_letter = expected_letter
			add_damage = expected_damage
		elif rtype == "remove_card":
			burn_index = i
			fails += _check(not reward.has("card"),
				"the burn option does not pre-decide a card")
			fails += _check(str(reward.get("detail", "")).contains("Choose"),
				"the burn option tells the player to choose")
	fails += _check(add_letter != "",
		"the add reward showed a concrete card (%s %s)" % [add_letter, add_damage])

	# Taking ADD A CARD applies immediately. The option order is shuffled, so the
	# add option is looked up rather than assumed to be first.
	if add_index >= 0:
		var deck_before: int = GameManager.get_deck_size()
		main._on_reward_chosen(add_index)
		await get_tree().process_frame
		fails += _check(not main.reward_dialog.visible, "choosing closes the dialog")
		fails += _check(not GameManager.has_pending_reward(), "choosing clears the pending flag")
		fails += _check(GameManager.rewards_taken == 1, "rewards_taken incremented via UI")
		fails += _check(not main.burn_dialog.visible, "the burn picker stays closed")
		fails += _check(GameManager.get_deck_size() == deck_before + 1,
			"add_card grew the deck via the UI (%d -> %d)" % [
				deck_before, GameManager.get_deck_size()])

	# Taking BURN A CARD opens the picker instead of applying. Re-roll first, since
	# taking the add reward above consumed the current choice.
	GameManager.roll_rewards()
	burn_index = _find_burn_option(GameManager)
	if burn_index >= 0:
		main.show_reward_choice()
		await get_tree().process_frame
		fails += _check(not main.burn_dialog.visible, "the burn picker starts hidden")
		var deck_before_burn: int = GameManager.get_deck_size()
		main._on_reward_chosen(_find_burn_option(GameManager))
		await get_tree().process_frame
		fails += _check(main.burn_dialog.visible, "choosing BURN opens the picker")
		fails += _check(not main.reward_dialog.visible, "the three options close")
		fails += _check(GameManager.has_pending_reward(), "the reward is still pending")
		fails += _check(GameManager.is_burning(), "the game is in a burn pick")
		fails += _check(GameManager.get_deck_size() == deck_before_burn,
			"nothing is removed before the player picks")
		# One picker button per burnable card, all with a real size
		var burnable: Array = GameManager.get_burnable_cards()
		fails += _check(main.burn_grid.get_child_count() == burnable.size(),
			"one picker button per burnable card (%d vs %d)" % [
				main.burn_grid.get_child_count(), burnable.size()])
		fails += _check(main.burn_grid.get_child_count() > 0, "the picker is not empty")
		for ci in range(mini(3, main.burn_grid.get_child_count())):
			var cbtn: Button = main.burn_grid.get_child(ci) as Button
			fails += _check(cbtn != null and cbtn.get_global_rect().size.y > 0.0,
				"picker card %d has a real size (%.0fx%.0f)" % [ci,
					cbtn.get_global_rect().size.x, cbtn.get_global_rect().size.y])
		# Clicking a card burns exactly that card
		if main.burn_grid.get_child_count() > 0 and not burnable.is_empty():
			var target_card: Dictionary = burnable[0].get("card", {})
			var t_letter: String = str(target_card.get("letter", ""))
			var t_dmg: int = int(target_card.get("damage", 0))
			var tbtn: Button = main.burn_grid.get_child(0) as Button
			fails += _check(_collect_label_texts(tbtn).has(t_letter),
				"the picker card shows its letter '%s'" % t_letter)
			fails += _check(_collect_label_texts(tbtn).has("%d dmg" % t_dmg),
				"the picker card shows its damage '%d dmg'" % t_dmg)
			var t_before: int = _count_cards(GameManager, t_letter, t_dmg, str(target_card.get("color", "")))
			var rewards_before: int = GameManager.rewards_taken
			main._on_burn_card_picked(str(burnable[0].get("id", "")))
			await get_tree().process_frame
			fails += _check(not main.burn_dialog.visible, "the picker closes after burning")
			fails += _check(not GameManager.has_pending_reward(), "the burn reward is consumed")
			fails += _check(GameManager.rewards_taken == rewards_before + 1,
				"rewards_taken counted the burn (%d -> %d)" % [
					rewards_before, GameManager.rewards_taken])
			var t_after: int = _count_cards(GameManager, t_letter, t_dmg, str(target_card.get("color", "")))
			fails += _check(t_after == t_before - 1,
				"exactly the clicked card was removed (%s: %d -> %d)" % [t_letter, t_before, t_after])

	# Cancelling the picker keeps the reward and returns to the three options
	GameManager.roll_rewards()
	main.show_reward_choice()
	await get_tree().process_frame
	var bi2: int = _find_burn_option(GameManager)
	if bi2 >= 0:
		main._on_reward_chosen(bi2)
		await get_tree().process_frame
		fails += _check(main.burn_dialog.visible, "picker reopened for the cancel test")
		main._on_burn_cancel_pressed()
		await get_tree().process_frame
		fails += _check(not main.burn_dialog.visible, "cancel closes the picker")
		fails += _check(not GameManager.is_burning(), "cancel leaves the burn pick")
		fails += _check(GameManager.has_pending_reward(), "cancel keeps the reward pending")
		fails += _check(main.reward_dialog.visible, "cancel returns to the three options")
		GameManager.cancel_burn_card()
	main.reward_dialog.visible = false

	# Clearing the workbench must return to the idle prompt
	main.workbench_cards.clear()
	main._refresh_ui()
	await get_tree().process_frame
	fails += _check(str(main.preview_label.text).contains("preview"),
		"clearing the workbench restores the idle prompt")

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)

func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1


## Gathers the text of every Label under a node, recursively.
func _collect_label_texts(node: Node) -> Array:
	var out: Array = []
	if node is Label:
		out.append(str((node as Label).text))
	for child in node.get_children():
		out.append_array(_collect_label_texts(child))
	return out


## Position of the "BURN A CARD" option in the current reward list, or -1.
func _find_burn_option(gm: Node) -> int:
	for i in range(gm.get_reward_options().size()):
		if str(gm.get_reward_options()[i].get("type", "")) == "remove_card":
			return i
	return -1


## Counts matching cards across the draw pile and the hand.
func _count_cards(gm: Node, letter: String, damage: int, color: String) -> int:
	var n: int = 0
	for c: Dictionary in gm.deck:
		if str(c.get("letter", "")) == letter \
				and int(c.get("damage", -1)) == damage \
				and str(c.get("color", "")) == color:
			n += 1
	for c: Variant in gm.hand:
		if c == null:
			continue
		var card: Dictionary = c
		if str(card.get("letter", "")) == letter \
				and int(card.get("damage", -1)) == damage \
				and str(card.get("color", "")) == color:
			n += 1
	return n
