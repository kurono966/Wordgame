extends Control

# Main.gd – UI controller: 3 Shared Slots (3 cards each, all fully visible, Center is ACTIVE)

@onready var slot_container        : HBoxContainer  = $Scroll/Center/VBox/SlotContainer
@onready var background            : TextureRect    = $Background
@onready var hand_container        : HBoxContainer  = $Scroll/Center/VBox/HandContainer
@onready var deck_grave_label      : Label          = $Scroll/Center/VBox/DeckGraveLabel
@onready var workbench_panel       : PanelContainer = $Scroll/Center/VBox/WorkbenchPanel
@onready var workbench_container   : HBoxContainer  = $Scroll/Center/VBox/WorkbenchPanel/WorkbenchContainer
@onready var clear_button          : Button         = $Scroll/Center/VBox/ControlRow/ClearButton
@onready var submit_button         : Button         = $Scroll/Center/VBox/ControlRow/SubmitButton
# ══════════════════════════════════════════════════════════════════════════════
# ── Gameplay timer (paused while the formulas dialog is open) ─────────────────
# ══════════════════════════════════════════════════════════════════════════════
var _turn_timer: SceneTreeTimer = null
var _turn_timer_left: float = 0.0
const TURN_SECONDS: float = 30.0

# Play a short sound when the timer runs low.
var _low_time_played: bool = false


@onready var formula_button        : Button         = $Scroll/Center/VBox/ControlRow/FormulaButton
@onready var formula_dialog        : Control        = $FormulaDialog
@onready var formula_panel         : PanelContainer = $FormulaDialog/DialogPanel
@onready var formula_label         : Label          = $FormulaDialog/DialogPanel/DialogVBox/FormulaLabel
@onready var formula_close_button  : Button         = $FormulaDialog/DialogPanel/DialogVBox/DialogHeader/CloseButton
@onready var piles_button          : Button         = $Scroll/Center/VBox/ControlRow/PilesButton
@onready var piles_dialog          : Control        = $PilesDialog
@onready var piles_panel           : PanelContainer = $PilesDialog/DialogPanel
@onready var piles_grid            : VBoxContainer  = $PilesDialog/DialogPanel/DialogVBox/Scroll/PilesBody
@onready var piles_subtitle_label  : Label          = $PilesDialog/DialogPanel/DialogVBox/Subtitle
@onready var piles_close_button    : Button         = $PilesDialog/DialogPanel/DialogVBox/DialogHeader/CloseButton
# Reward choice (offered after every enemy defeat)
@onready var reward_dialog         : Control        = $RewardDialog
@onready var reward_panel          : PanelContainer = $RewardDialog/DialogPanel
@onready var reward_title_label    : Label          = $RewardDialog/DialogPanel/DialogVBox/Title
@onready var reward_subtitle_label : Label          = $RewardDialog/DialogPanel/DialogVBox/Subtitle
@onready var reward_row            : HBoxContainer  = $RewardDialog/DialogPanel/DialogVBox/RewardRow
@onready var reward_deck_button     : Button         = $RewardDialog/DialogPanel/DialogVBox/DeckButton
# Deck-trimming picker (opened by the BURN A CARD reward)
@onready var burn_dialog           : Control        = $BurnDialog
@onready var burn_panel            : PanelContainer = $BurnDialog/DialogPanel
@onready var burn_subtitle_label   : Label          = $BurnDialog/DialogPanel/DialogVBox/Subtitle
@onready var burn_grid             : GridContainer  = $BurnDialog/DialogPanel/DialogVBox/Scroll/BurnGrid
@onready var burn_cancel_button    : Button         = $BurnDialog/DialogPanel/DialogVBox/ButtonRow/CancelButton
@onready var message_label         : Label          = $Scroll/Center/VBox/MessageLabel
@onready var preview_label         : Label          = $Scroll/Center/VBox/PreviewLabel
@onready var meaning_label         : Label          = $Scroll/Center/VBox/MeaningLabel
@onready var definition_label      : Label          = $Scroll/Center/VBox/DefinitionLabel
@onready var player_hp_label       : Label          = $Scroll/Center/VBox/StatusBox/PlayerHPBox/PlayerHPLabel
@onready var player_hp_bar         : ProgressBar    = $Scroll/Center/VBox/StatusBox/PlayerHPBox/PlayerHPBar
@onready var enemy_hp_label        : Label          = $Scroll/Center/VBox/StatusBox/EnemyHPBox/EnemyHPLabel
@onready var enemy_hp_bar          : ProgressBar    = $Scroll/Center/VBox/StatusBox/EnemyHPBox/EnemyHPBar
@onready var stats_label           : Label          = $Scroll/Center/VBox/StatsLabel
# Cached stats text without the enemy-skill "DANGER" suffix.
var _stats_line: String = ""
@onready var turn_label            : Label          = $Scroll/Center/VBox/HeaderBox/TurnLabel
# Operation points (YELLOW trait) — dedicated gauge next to the two HP bars
@onready var op_panel              : PanelContainer = $Scroll/Center/VBox/StatusBox/OPBox
@onready var op_title_label        : Label          = $Scroll/Center/VBox/StatusBox/OPBox/OPVBox/OPTitleLabel
@onready var op_value_label        : Label          = $Scroll/Center/VBox/StatusBox/OPBox/OPVBox/OPRow/OPValueLabel
@onready var op_moves_label        : Label          = $Scroll/Center/VBox/StatusBox/OPBox/OPVBox/OPRow/OPMovesLabel
@onready var op_bar                : ProgressBar    = $Scroll/Center/VBox/StatusBox/OPBox/OPVBox/OPBar
@onready var op_hint_label         : Label          = $Scroll/Center/VBox/StatusBox/OPBox/OPVBox/OPHintLabel
@onready var score_up_sound        : AudioStreamPlayer = $ScoreUpSound
@onready var score_down_sound      : AudioStreamPlayer = $ScoreDownSound
@onready var card_place_sound      : AudioStreamPlayer = $CardPlaceSound
@onready var card_draw_sound       : AudioStreamPlayer = $CardDrawSound
@onready var card_discard_sound    : AudioStreamPlayer = $CardDiscardSound
@onready var card_swap_sound       : AudioStreamPlayer = $CardSwapSound

# UI data caches
# slot_reels[s] = {"window": Control, "strip": VBoxContainer, "card_views": [prev, active, next, extra]}
var slot_reels: Array = []
# hand_card_views[hand_idx] = {"panel": PanelContainer, "letter": Label, "sub": Label, "style": StyleBoxFlat}
var hand_card_views: Array = []
var _hand_visual_keys: Array = []
var _animate_next_hand_refresh: bool = false
# Meta key set on a card panel that a discard animation has hidden completely.
# Hand panels are reused, so the next refresh uses this flag to guarantee the
# replacement card is made visible again.
const FADED_OUT_META := "faded_out"

# Workbench state
var workbench_cards: Array = []
## Gold marker showing which gap a dragged card would drop into. It is a child of
## the Workbench card container so the HBox lays it out inside the gap itself.
var _workbench_caret: ColorRect = null
var _workbench_caret_index: int = -1

# Last resolved word, kept so the FORMULAS panel can show its calculation
var last_word: String = ""
var last_result: Dictionary = {}
var last_penalty: Dictionary = {}

# Operation points (YELLOW trait). `_op_displayed` is the value currently shown
# on the gauge, so a later refresh can tell a gain from a spend and animate it.
var _op_displayed: int = 0
var _op_tween: Tween = null

# Word currently being looked up on Jisho, so a late answer for an abandoned
# word can be discarded instead of overwriting the current one.
var _looked_up_word: String = ""

# Card dimensions (all 3 cards are completely visible on screen)
# SLOT_CARD_W must fit the WIDEST sub-label a reel card can ever show, otherwise
# the label's minimum size pushes the card wider than the clipping window and
# `window.clip_contents` silently cuts the right edge off. The worst case is the
# ACTIVE row carrying a long skill tag, e.g. "★ ACTIVE (10dmg)  ⚠ HAND DOWN"
# (129px) plus the card's own 2x5 content margin and 2x2 border = 143px.
# 152px leaves headroom over that worst case. _slot_clip_test.gd measures the
# real text every run and fails if this is ever too narrow again.
const SLOT_CARD_W := 152.0
const SLOT_CARD_H := 58.0
const SLOT_SEP    := 8.0
const WINDOWED_SIZE := Vector2i(1280, 800)
# Exactly 3 cards + 2 gaps visible
const REEL_WINDOW_H := (SLOT_CARD_H * 3.0) + (SLOT_SEP * 2.0)

# Color Palette
const BG_CURRENT_SLOT := Color(0.25, 0.21, 0.08, 1.0)
const BORDER_CURRENT  := Color(0.98, 0.80, 0.22, 1.0) # Gold
const TXT_CURRENT     := Color(1.00, 0.94, 0.55, 1.0)

const BG_NEXT_SLOT    := Color(0.12, 0.22, 0.16, 1.0)
const BORDER_NEXT     := Color(0.35, 0.85, 0.55, 1.0) # Green
const TXT_NEXT        := Color(0.60, 1.00, 0.75, 1.0)

const BG_IDLE_SLOT    := Color(0.14, 0.16, 0.22, 0.8)
const BORDER_IDLE     := Color(0.24, 0.27, 0.35, 1.0)
const TXT_IDLE        := Color(0.55, 0.58, 0.68, 1.0)

const BG_HAND         := Color(0.14, 0.20, 0.28, 1.0)
const BORDER_HAND     := Color(0.35, 0.65, 0.95, 1.0) # Sky blue
const TXT_HAND        := Color(0.85, 0.93, 1.00, 1.0)

const TXT_WORKBENCH     := Color(1.0, 1.0, 1.0, 1.0)

const BG_EMPTY        := Color(0.12, 0.13, 0.17, 0.5)
const BORDER_EMPTY    := Color(0.20, 0.22, 0.28, 0.5)

# Submit-preview label colours (green = safe, yellow = you take damage,
# red = this submit would defeat you, grey = nothing to preview yet)
const PREVIEW_COLOR_IDLE    := Color(0.62, 0.68, 0.78, 1.0)
const PREVIEW_COLOR_SAFE    := Color(0.55, 0.95, 0.70, 1.0)
const PREVIEW_COLOR_HURT    := Color(1.00, 0.82, 0.35, 1.0)
const PREVIEW_COLOR_LETHAL  := Color(1.00, 0.38, 0.34, 1.0)
const PREVIEW_COLOR_INVALID := Color(1.00, 0.55, 0.45, 1.0)

# Word-meaning (Jisho) label colours
const MEANING_COLOR_JP    := Color(1.00, 0.93, 0.70, 1.0)  # kanji / reading
const MEANING_COLOR_DEF   := Color(0.80, 0.88, 0.98, 1.0)  # English definitions
const MEANING_COLOR_LOAD  := Color(0.62, 0.68, 0.78, 1.0)  # "looking up..."

# Reward-choice dialog colours
const REWARD_COLOR_TITLE  := Color(1.00, 0.88, 0.45, 1.0)
const REWARD_COLOR_ICON   := Color(0.70, 0.92, 1.00, 1.0)
const REWARD_COLOR_DETAIL := Color(0.80, 0.85, 0.95, 1.0)
const MEANING_COLOR_NONE  := Color(0.60, 0.64, 0.72, 1.0)  # not found / offline

# Operation points (OP) — gold gauge shown beside the HP bars
const OP_BAR_CAP      := 5   # how many moves the gauge can display before it caps
const OP_COLOR_ACTIVE := Color(1.0, 0.85, 0.38, 1.0)
const OP_COLOR_SUB    := Color(0.85, 0.72, 0.42, 1.0)
const OP_COLOR_EMPTY  := Color(0.60, 0.58, 0.52, 1.0)
const OP_COLOR_GAIN   := Color(1.0, 0.95, 0.65, 1.0)
const OP_COLOR_SPEND  := Color(1.0, 0.70, 0.35, 1.0)



# Card Colors
const COLOR_RED_BORDER   := Color("ff6978")
const COLOR_RED_BG       := Color("3b1628")
const COLOR_BLUE_BORDER  := Color("62a8ff")
const COLOR_BLUE_BG      := Color("132952")
const COLOR_GREEN_BORDER := Color("58d99b")
const COLOR_GREEN_BG     := Color("123b32")
const COLOR_YELLOW_BORDER:= Color("ffd35c")
const COLOR_YELLOW_BG    := Color("443517")
const COLOR_GOLD_BORDER  := Color("ffe08a")
const COLOR_GOLD_BG      := Color("4b3212")
# Warning orange, used for any card carrying one of the enemy's skill letters.
const ENEMY_SKILL_COLOR  := Color("ff7a3d")

# Phase Indicators
const COLOR_DAY   := Color(1.0, 0.9, 0.6, 1.0)  # Warm yellow for day
const COLOR_NIGHT := Color(0.6, 0.7, 1.0, 1.0)  # Cool blue for night

func get_card_color_constants(color_name: String) -> Dictionary:
	match color_name:
		"red":
			return {"border": COLOR_RED_BORDER, "bg": COLOR_RED_BG}
		"blue":
			return {"border": COLOR_BLUE_BORDER, "bg": COLOR_BLUE_BG}
		"green":
			return {"border": COLOR_GREEN_BORDER, "bg": COLOR_GREEN_BG}
		"yellow":
			return {"border": COLOR_YELLOW_BORDER, "bg": COLOR_YELLOW_BG}
		"gold":
			return {"border": COLOR_GOLD_BORDER, "bg": COLOR_GOLD_BG}
		_:
			return {"border": COLOR_RED_BORDER, "bg": COLOR_RED_BG}

# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	submit_button.pressed.connect(_on_submit_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	formula_button.pressed.connect(_on_formula_pressed)
	formula_close_button.pressed.connect(_close_formula_dialog)
	piles_button.pressed.connect(_on_piles_pressed)
	piles_close_button.pressed.connect(_close_piles_dialog)
	reward_deck_button.pressed.connect(_open_piles_dialog)

	_setup_workbench_drop_target()
	JishoClient.lookup_finished.connect(_on_jisho_lookup_finished)
	_build_slot_reels()
	_build_hand_cards()
	_setup_sound_effects()
	_style_global_ui()
	_style_hp_bars()
	_style_op_panel()
	_style_formula_panel()
	_style_piles_panel()
	_style_reward_panel()
	_style_burn_panel()
	burn_cancel_button.pressed.connect(_on_burn_cancel_pressed)
	_refresh_formula_panel()
	_refresh_ui()


func _process(_delta: float) -> void:
	# A drag that ends without a drop (released off the zone, or cancelled) never
	# reaches _drop_data, so the insertion caret would be left behind. Clear it as
	# soon as the viewport reports that nothing is being dragged any more.
	if _workbench_caret != null and _workbench_caret.visible \
			and not get_viewport().gui_is_dragging():
		_hide_workbench_caret()

# ──────────────────────────────────────────────────────────────────────────────
func _style_global_ui() -> void:
	# Procedural background: no image asset is required.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color("07101f"), Color("102844"), Color("1b1535")
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.56, 1.0])
	var background_texture := GradientTexture2D.new()
	background_texture.gradient = gradient
	background_texture.width = 1920
	background_texture.height = 1080
	background_texture.fill = GradientTexture2D.FILL_LINEAR
	background_texture.fill_from = Vector2(0.05, 0.0)
	background_texture.fill_to = Vector2(0.95, 1.0)
	background.texture = background_texture

	var title: Label = $Scroll/Center/VBox/HeaderBox/TitleLabel
	title.add_theme_color_override("font_color", Color("f8d77a"))
	title.add_theme_color_override("font_outline_color", Color("11182b"))
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_font_size_override("font_size", 24)
	turn_label.add_theme_color_override("font_outline_color", Color("0a1020"))
	turn_label.add_theme_constant_override("outline_size", 2)

	for section_label in [
		$Scroll/Center/VBox/SlotsSectionLabel,
		$Scroll/Center/VBox/HandSectionLabel,
		$Scroll/Center/VBox/WorkbenchSectionLabel
	]:
		section_label.add_theme_color_override("font_outline_color", Color("0a1020"))
		section_label.add_theme_constant_override("outline_size", 2)

	_style_button(submit_button, Color("ae6920"), Color("ffd36a"), Color("fff2c4"))
	_style_button(clear_button, Color("273650"), Color("7695c3"), Color("e6efff"))
	_style_button(formula_button, Color("243c71"), Color("7eacff"), Color("e4efff"))
	_style_button(piles_button, Color("3b2c67"), Color("a88cff"), Color("f0eaff"))
	_style_button(reward_deck_button, Color("243c71"), Color("7eacff"), Color("e4efff"))
	_style_button(formula_close_button, Color("283852"), Color("6685b0"), Color("e8f0ff"))
	_style_button(piles_close_button, Color("283852"), Color("6685b0"), Color("e8f0ff"))

	message_label.add_theme_color_override("font_outline_color", Color("07101f"))
	message_label.add_theme_constant_override("outline_size", 3)

	# Submit preview: outlined like the message label so it stays readable over
	# the procedural background, and recoloured per state in _refresh_submit_preview
	preview_label.add_theme_color_override("font_outline_color", Color("07101f"))
	preview_label.add_theme_constant_override("outline_size", 3)
	preview_label.add_theme_color_override("font_color", PREVIEW_COLOR_IDLE)

	# Word meaning (Jisho): outlined like the other status lines so it stays
	# readable over the procedural background
	# Word meaning (Jisho). NOTE: Godot 4's Label has NO BBCode support (only
	# RichTextLabel does), so the headword and the definitions are two separate
	# Labels in different colours rather than one [color=...] string.
	meaning_label.add_theme_color_override("font_outline_color", Color("07101f"))
	meaning_label.add_theme_constant_override("outline_size", 3)
	meaning_label.add_theme_color_override("font_color", MEANING_COLOR_NONE)

	definition_label.add_theme_color_override("font_outline_color", Color("07101f"))
	definition_label.add_theme_constant_override("outline_size", 3)
	definition_label.add_theme_color_override("font_color", MEANING_COLOR_DEF)

func _style_button(button: Button, base_color: Color, border_color: Color, text_color: Color) -> void:
	var normal := _make_button_style(base_color, border_color)
	var hover := _make_button_style(base_color.lightened(0.16), border_color.lightened(0.18))
	hover.shadow_color = border_color.darkened(0.35)
	hover.shadow_size = 10
	var pressed := _make_button_style(base_color.darkened(0.16), border_color.darkened(0.08))
	pressed.content_margin_top += 2.0
	var disabled := _make_button_style(Color("172031"), Color("33415b"))
	disabled.shadow_size = 0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", text_color.darkened(0.08))
	button.add_theme_color_override("font_disabled_color", Color("69758c"))
	button.add_theme_color_override("font_outline_color", Color("080d17"))
	button.add_theme_constant_override("outline_size", 1)

func _make_button_style(base_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = base_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	style.shadow_color = Color(0.0, 0.0, 0.05, 0.48)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style

# ──────────────────────────────────────────────────────────────────────────────
# ── Formula reference panel ──────────────────────────────────────────────────
# Shows every calculation used by the game (values read from GameManager) plus
# the breakdown of the word that was submitted last.
func _style_formula_panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.13, 0.19, 1.0)
	sb.border_color = Color(0.48, 0.64, 0.90, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0.0, 0.0, 0.04, 0.72)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 7)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	formula_panel.add_theme_stylebox_override("panel", sb)


	formula_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _on_formula_pressed() -> void:
	if formula_dialog.visible:
		_close_formula_dialog()
		return
	_refresh_formula_panel()
	formula_dialog.visible = true
	formula_close_button.grab_focus()

func _close_formula_dialog() -> void:
	formula_dialog.visible = false
	formula_button.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.keycode == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	# D opens the deck viewer while choosing a reward, so the player can weigh
	# "add this card" against what they already own without leaving the screen.
	if (event.is_pressed() and not event.is_echo() and event.keycode == KEY_D
			and reward_dialog.visible and not piles_dialog.visible):
		_open_piles_dialog()
		get_viewport().set_input_as_handled()
		return
	if not event.is_pressed() or event.keycode != KEY_ESCAPE:
		return
	if formula_dialog.visible:
		_close_formula_dialog()
		get_viewport().set_input_as_handled()
	elif piles_dialog.visible:
		_close_piles_dialog()
		get_viewport().set_input_as_handled()

func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		call_deferred("_restore_windowed_size")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _restore_windowed_size() -> void:
	DisplayServer.window_set_size(WINDOWED_SIZE)

# ── Deck and draw-pile reference dialog ─────────────────────────────────────
# The draw pile is grouped and alphabetically sorted so its actual draw order
# remains hidden even though its remaining card contents are visible.
func _style_piles_panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.13, 0.19, 1.0)
	sb.border_color = Color(0.42, 0.72, 0.98, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0.0, 0.0, 0.04, 0.72)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 7)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	piles_panel.add_theme_stylebox_override("panel", sb)

func _on_piles_pressed() -> void:
	if piles_dialog.visible:
		_close_piles_dialog()
		return
	_open_piles_dialog()


## Opens the deck viewer. It is a plain overlay, so the reward dialog stays open
## underneath it: the player can inspect their deck mid-reward and carry on
## picking when they close it again.
func _open_piles_dialog() -> void:
	_refresh_piles_dialog()
	piles_dialog.visible = true
	piles_close_button.grab_focus()


func _close_piles_dialog() -> void:
	piles_dialog.visible = false
	# Focus must go back to whatever opened the dialog, not always the board
	# button, or the keyboard would land on a control hidden behind the reward.
	if reward_dialog.visible:
		if reward_row.get_child_count() > 0:
			(reward_row.get_child(0) as Button).grab_focus()
		else:
			reward_deck_button.grab_focus()
	else:
		piles_button.grab_focus()


## Rebuilds the deck viewer as three clearly separated sections, so every card is
## individually visible: what is still in the DRAW PILE, what is in HAND right
## now, and what has been spent into the GRAVEYARD.
func _refresh_piles_dialog() -> void:
	for child in piles_grid.get_children():
		piles_grid.remove_child(child)
		child.queue_free()

	var draw_pile: Array = GameManager.get_draw_pile_cards()
	var hand: Array = []
	for card in GameManager.get_hand():
		if card != null:
			hand.append(card)
	var graveyard: Array = GameManager.get_graveyard()

	piles_subtitle_label.text = "%d in the draw pile   +   %d in hand   +   %d in the graveyard   =   %d cards" % [
		draw_pile.size(), hand.size(), graveyard.size(),
		draw_pile.size() + hand.size() + graveyard.size()]

	_add_piles_section("DRAW PILE  (%d)" % draw_pile.size(), draw_pile,
		"Every card you have not drawn yet, one by one. The draw order itself is "
		+ "hidden, so the pile is shown sorted by letter.")
	_add_piles_section("HAND  (%d)" % hand.size(), hand,
		"The cards you are holding right now.")
	_add_piles_section("GRAVEYARD  (%d)" % graveyard.size(), graveyard,
		"Spent cards. They are shuffled back into the draw pile when it runs dry.")


## One labelled block of cards in the deck viewer.
func _add_piles_section(title: String, cards: Array, hint: String) -> void:
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0, 1.0))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piles_grid.add_child(header)

	if cards.is_empty():
		var empty := Label.new()
		empty.text = "  (empty)"
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.8))
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piles_grid.add_child(empty)
		return

	# Sorted so the draw pile's contents can be read at a glance without
	# revealing the order the cards will actually be dealt in.
	var sorted_cards: Array = cards.duplicate()
	sorted_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a.get("letter", "")) == str(b.get("letter", "")):
			return int(a.get("damage", 0)) < int(b.get("damage", 0))
		return str(a.get("letter", "")) < str(b.get("letter", ""))
	)

	var grid := GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for card: Dictionary in sorted_cards:
		grid.add_child(_build_piles_card_button({"id": "deck_card", "card": card}))
	piles_grid.add_child(grid)

	var note := Label.new()
	note.text = "  " + hint
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.6, 0.66, 0.76, 0.75))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piles_grid.add_child(note)

func _format_card_counts(cards: Array) -> String:
	if cards.is_empty():
		return "  (empty)"
	var counts: Dictionary = {}
	for card in cards:
		if card == null:
			continue
		var entry := "%s  %s  %d DMG" % [
			str(card.get("letter", "?")),
			str(card.get("color", "red")).to_upper(),
			int(card.get("damage", 0))
		]
		counts[entry] = int(counts.get(entry, 0)) + 1
	var entries: Array = counts.keys()
	entries.sort()
	var lines: Array = []
	for entry in entries:
		lines.append("  %s  x%d" % [entry, counts[entry]])
	return "\n".join(lines)

## Builds a visual card button for the Piles dialog (similar to burn card button)
func _build_piles_card_button(entry: Dictionary) -> Button:
	var card: Dictionary = entry.get("card", {})
	var button := Button.new()
	button.custom_minimum_size = Vector2(78, 100)
	_style_burn_card_button(button, str(card.get("color", "red")))
	button.disabled = true  # Cards in piles are read-only

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4.0
	vbox.offset_top = 6.0
	vbox.offset_right = -4.0
	vbox.offset_bottom = -6.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(vbox)

	var consts: Dictionary = get_card_color_constants(str(card.get("color", "red")))
	var letter := Label.new()
	letter.text = str(card.get("letter", "?"))
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.add_theme_font_size_override("font_size", 30)
	letter.add_theme_color_override("font_color", consts["border"])
	letter.add_theme_color_override("font_outline_color", Color("080d17"))
	letter.add_theme_constant_override("outline_size", 2)
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(letter)

	var dmg := Label.new()
	dmg.text = "%d dmg" % int(card.get("damage", 0))
	dmg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg.add_theme_font_size_override("font_size", 12)
	dmg.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1.0))
	dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(dmg)
	return button

func _refresh_formula_panel() -> void:
	formula_label.text = _build_formula_text() + "\n" + _build_last_calc_text()

func _build_formula_text() -> String:
	var player_max: int = GameManager.get_max_player_hp()
	var enemy_base: int = GameManager.ENEMY_BASE_HP
	var enemy_growth: int = GameManager.ENEMY_HP_GROWTH
	var op: int = GameManager.get_operation_points()

	var lines: Array = [
		"[BASE]  Base = total damage of every card used in the word.",
		"        All color traits use this base (negative bases grant no traits).",
		"",
		"[ENEMY NAME]  base = card total x 2^(run - 1)",
		"  Spelling 2+ letters of the enemy's name back-to-back doubles EVERY card",
		"  in the word, and doubles again per extra letter: 2 letters x2, 3 x4, 4 x8.",
		"  Enemy is '%s' right now — run your letters off its name." % GameManager.enemy_name.to_upper(),
		"",
		"[RED — enemy damage]  final = base x RED multiplier",
		"  0 red: x1   |   1 red: x1.5   |   2 / 3 / 4 red: x2 / x4 / x8",
		"",
		"[BLUE — shield]  shield = base x 2^(blue - 1); no cap",
		"  1 / 2 / 3 / 4 blue: x1 / x2 / x4 / x8. Shield absorbs damage before HP.",
		"",
		"[GREEN — heal]  heal = base x 2^(green - 1), up to %d HP" % player_max,
		"  1 / 2 / 3 / 4 green: x1 / x2 / x4 / x8.",
		"",
		"[YELLOW — operation points]  OP earned = base x 2^(yellow - 1)",
		"  1 / 2 / 3 / 4 yellow: x1 / x2 / x4 / x8. OP keeps accumulating; damage never spends it.",
		"  Owned right now: %d OP  =  %d Workbench card move(s)  (gold gauge beside the HP bars)." % [op, op],
		"  Spend 1 OP to move a Workbench card one place left or right. This costs no turn.",
		"[CARD COST & SPECIAL ABILITIES]  paid in OP",
		"  ★ SPECIAL cards have unique active powers unlocked via stage rewards.",
		"    Activate by right-clicking or long-pressing the special card in hand.",
		"    Costs OP as specified on the card. Uses no turn.",
		"    With too few OP the activation is refused: no OP is lost.",
		"",
		"",
		"[NIGHT SELF-DAMAGE]  next-slot total x 10^(largest same-color group - 1)",
		"  2 / 3 / 4 matching colors: x10 / x100 / x1000. BLUE shield applies first.",
		"",
		_build_enemy_skill_text(),
		"[OTHER]  ?: 0 damage and matches any letter. Word order never changes.",
		"  Enemy HP: stage 1 = %d, then +%d per stage. Excess damage is lost." % [enemy_base, enemy_growth],
		"  %d turns clears the game; player HP 0 is defeat." % GameManager.MAX_TURNS
	]
	return "\n".join(lines)

## The enemy-skill section of the FORMULAS panel: the single skill card, what it
## does, where it stands right now, and what is running at this moment.
func _build_enemy_skill_text() -> String:
	var lines: Array = [
		"[ENEMY SKILL]  ONE card on the reels carries the enemy's skill.",
		"  It fires at NIGHT while that card sits in the BOTTOM row of a reel.",
		"  Spelling the letter does nothing — its POSITION is the trigger.",
		"  SPIN that reel (OP, and the price rises each spin) or use it in a",
		"  word to roll the card clear. Max 3 spins per turn (1 / 10 / 100 OP).",
		"  A stage clear lands first — a defeated enemy never fires back.",
		"  ALL of this is wiped the instant the stage is cleared."
	]
	for skill: Dictionary in GameManager.get_enemy_skills():
		lines.append("    [%s] %s (%d): %s" % [
			str(skill.get("letter", "")), str(skill.get("name", "")),
			int(skill.get("value", 0)), str(skill.get("desc", ""))])
	var active: Array = []
	if GameManager.get_enemy_shield() > 0:
		active.append("enemy shield %d" % GameManager.get_enemy_shield())
	if GameManager.get_enemy_night_tax() > 0:
		active.append("night tax +%d" % GameManager.get_enemy_night_tax())
	if GameManager.get_hand_limit() < GameManager.HAND_SIZE:
		active.append("hand limit %d/%d" % [GameManager.get_hand_limit(), GameManager.HAND_SIZE])
	if active.is_empty():
		lines.append("  Nothing active yet — no skill letter has been used.")
	else:
		lines.append("  ACTIVE NOW: %s" % ", ".join(active))
	return "\n".join(lines)


func _build_last_calc_text() -> String:
	var lines: Array = ["", "=== LAST WORD ==="]
	if last_result.is_empty():
		lines.append("  (submit a word and its calculation appears here)")
		return "\n".join(lines)

	var base: int = last_result.get("word_damage", 0)
	var mult: float = last_result.get("multiplier", 1.0)
	var red_bonus: int = last_result.get("red_bonus", 0)
	var final_dmg: int = last_result.get("final_damage", 0)

	if base > 0:
		lines.append("  %s : base %d x RED x%s = %d damage" % [
			last_word.to_upper(), base, String.num(mult, 2), final_dmg])
		if red_bonus > 0:
			lines.append("      (base %d + red bonus %d)" % [base, red_bonus])
		lines.append("      enemy HP %d -> %d" % [
			last_result.get("enemy_hp_before", 0), last_result.get("enemy_hp_after", 0)])
	elif base < 0:
		lines.append("  %s : base %d (negative word)" % [last_word.to_upper(), base])
		lines.append("      you take %d damage (shield blocked %d)" % [
			last_result.get("self_damage_taken", 0), last_result.get("self_damage_absorbed", 0)])
	else:
		lines.append("  %s : base 0 (wildcards only)" % last_word.to_upper())

	var shield_gained: int = last_result.get("shield_gained", 0)
	var heal_amount: int = last_result.get("heal_amount", 0)
	var op_gained: int = last_result.get("operation_points_gained", 0)
	var op_total: int = last_result.get("operation_points_after", 0)
	if shield_gained > 0 or heal_amount > 0:
		lines.append("      BLUE shield +%d (base x%d)   |   GREEN heal +%d (base x%d)" % [
			shield_gained, last_result.get("shield_mult", 0),
			heal_amount, last_result.get("heal_mult", 0)])
	if op_gained > 0:
		lines.append("      YELLOW: +%d OP (base %d x%d)  |  owned now: %d OP = %d card move(s)" % [
			op_gained, base, last_result.get("yellow_mult", 0), op_total, op_total])

	if not last_penalty.is_empty() and last_penalty.get("multiplier", 1) > 1:
		lines.append("  NIGHT: %d x color x%d = %d  (shield blocked %d, you lost %d)" % [
			last_penalty.get("base_damage", 0), last_penalty.get("multiplier", 1),
			last_penalty.get("requested_damage", 0), last_penalty.get("absorbed", 0),
			last_penalty.get("applied_damage", 0)])
	elif not last_penalty.is_empty() and last_penalty.get("requested_damage", 0) > 0:
		lines.append("  NIGHT: %d damage  (shield blocked %d, you lost %d)" % [
			last_penalty.get("requested_damage", 0), last_penalty.get("absorbed", 0),
			last_penalty.get("applied_damage", 0)])

	# The enemy skill card: what it did at night, and what it cost / granted.
	var skill_log: Array = last_penalty.get("skill_log", [])
	for line: String in skill_log:
		lines.append("      ! %s" % line)
	var shield_absorbed: int = last_result.get("enemy_shield_absorbed", 0)
	if shield_absorbed > 0:
		lines.append("      enemy shield absorbed %d (only %d reached its HP)" % [
			shield_absorbed, last_result.get("enemy_hp_damage", 0)])

	return "\n".join(lines)

# ── Sound Effects Setup ─────────────────────────────────────────────────────
func _setup_sound_effects() -> void:
	# Create simple beep sounds using AudioStreamWAV
	var up_wav := AudioStreamWAV.new()
	up_wav.format = AudioStreamWAV.FORMAT_16_BITS
	up_wav.mix_rate = 44100
	up_wav.stereo = true
	var up_data = PackedByteArray()
	for i in range(4410):  # 0.1 seconds
		var t = float(i) / 44100.0
		var freq = 440.0 + t * 440.0  # Ascending
		var sample = int(sin(t * freq * 2.0 * PI) * 16383.0)
		# Little-endian 16-bit stereo
		up_data.append(sample & 0xFF)
		up_data.append((sample >> 8) & 0xFF)
		up_data.append(sample & 0xFF)
		up_data.append((sample >> 8) & 0xFF)
	up_wav.data = up_data
	score_up_sound.stream = up_wav

	var down_wav := AudioStreamWAV.new()
	down_wav.format = AudioStreamWAV.FORMAT_16_BITS
	down_wav.mix_rate = 44100
	down_wav.stereo = true
	var down_data = PackedByteArray()
	for i in range(4410):  # 0.1 seconds
		var t = float(i) / 44100.0
		var freq = 880.0 - t * 440.0  # Descending
		var sample = int(sin(t * freq * 2.0 * PI) * 16383.0)
		# Little-endian 16-bit stereo
		down_data.append(sample & 0xFF)
		down_data.append((sample >> 8) & 0xFF)
		down_data.append(sample & 0xFF)
		down_data.append((sample >> 8) & 0xFF)
	down_wav.data = down_data
	score_down_sound.stream = down_wav

	card_place_sound.stream = _make_card_sfx([620.0, 830.0], 0.055, 0.34)
	card_draw_sound.stream = _make_card_sfx([520.0, 700.0, 880.0], 0.045, 0.27)
	card_discard_sound.stream = _make_card_sfx([440.0, 280.0], 0.075, 0.30)
	card_swap_sound.stream = _make_card_sfx([680.0, 540.0], 0.040, 0.24)

func _make_card_sfx(notes: Array, note_seconds: float, volume: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = true
	var data := PackedByteArray()
	var frames_per_note: int = int(wav.mix_rate * note_seconds)
	for note in notes:
		for i in range(frames_per_note):
			var t: float = float(i) / wav.mix_rate
			var fade: float = 1.0 - float(i) / frames_per_note
			var sample: int = int(sin(t * float(note) * TAU) * 32767.0 * volume * fade)
			data.append(sample & 0xFF)
			data.append((sample >> 8) & 0xFF)
			data.append(sample & 0xFF)
			data.append((sample >> 8) & 0xFF)
	wav.data = data
	return wav

func _play_score_up_sound() -> void:
	score_up_sound.play()

func _play_score_down_sound() -> void:
	score_down_sound.play()

func _play_card_place_sound() -> void:
	card_place_sound.play()

func _play_card_draw_sound() -> void:
	card_draw_sound.play()

func _play_card_discard_sound() -> void:
	card_discard_sound.play()

func _play_card_swap_sound() -> void:
	card_swap_sound.play()

# ── Card movement feedback ──────────────────────────────────────────────────
func _card_visual_key(card: Variant) -> String:
	if card == null:
		return ""
	# The special id is part of the key too, so spending a ★ SPECIAL and then
	# drawing a plain card that looks exactly the same still counts as a change.
	return "%s:%s:%s:%s" % [
		card.get("letter", "?"),
		card.get("color", "red"),
		card.get("damage", 0),
		card.get("special_id", "")
	]

func _animate_draw_panels(panels: Array) -> void:
	if panels.is_empty():
		return
	_play_card_draw_sound()
	for i in range(panels.size()):
		var panel: Control = panels[i]
		# This panel fades itself back in, so it is no longer "lost".
		if panel.has_meta(FADED_OUT_META):
			panel.remove_meta(FADED_OUT_META)
		panel.pivot_offset = panel.size / 2.0
		panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
		panel.scale = Vector2(0.78, 0.78)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "modulate", Color.WHITE, 0.16).set_delay(float(i) * 0.045)
		tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.22).set_delay(float(i) * 0.045)

func _animate_workbench_place() -> void:
	if workbench_container.get_child_count() == 0:
		return
	_play_card_place_sound()
	var panel := workbench_container.get_children().back() as Control
	if panel == null:
		return
	panel.pivot_offset = panel.size / 2.0
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.scale = Vector2(0.72, 0.72)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate", Color.WHITE, 0.16)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.22)
	var flash := create_tween()
	workbench_panel.modulate = Color(1.0, 0.88, 0.55, 1.0)
	flash.tween_property(workbench_panel, "modulate", Color.WHITE, 0.24)

func _animate_workbench_swap() -> void:
	_play_card_swap_sound()
	for panel in workbench_container.get_children():
		if panel is Control:
			var card_panel := panel as Control
			card_panel.pivot_offset = card_panel.size / 2.0
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.tween_property(card_panel, "scale", Vector2(1.08, 1.08), 0.09)
			tween.tween_property(card_panel, "scale", Vector2.ONE, 0.12)

func _animate_cards_discard(panels: Array) -> void:
	if panels.is_empty():
		return
	_play_card_discard_sound()
	var tween := create_tween()
	tween.set_parallel(true)
	for panel in panels:
		if panel is Control:
			var card_panel := panel as Control
			card_panel.pivot_offset = card_panel.size / 2.0
			# The card is faded out completely. Hand panels are reused for the
			# replacement card, so flag them: the next refresh must bring them
			# back even when the new card looks identical to the old one.
			card_panel.set_meta(FADED_OUT_META, true)
			tween.tween_property(card_panel, "modulate", Color(1.0, 0.4, 0.45, 0.0), 0.18)
			tween.tween_property(card_panel, "scale", Vector2(0.72, 0.72), 0.18)
	await tween.finished

## Un-hides any hand panel a discard animation left transparent. Normally the
## draw animation fades those panels back in, but it only runs for cards whose
## look CHANGED; without this a refill that dealt an identical card (which is
## exactly what happens when a ★ SPECIAL draws its own card back) would leave
## the panel invisible.
func _restore_faded_out_panels() -> void:
	for cv in hand_card_views:
		var panel: Control = cv["panel"]
		if not panel.has_meta(FADED_OUT_META):
			continue
		panel.remove_meta(FADED_OUT_META)
		panel.modulate = Color.WHITE
		panel.scale = Vector2.ONE

# ── HP visual effects ─────────────────────────────────────────────────────
func _style_hp_bars() -> void:
	_style_hp_bar(player_hp_bar, Color(0.25, 0.85, 0.45, 1.0))
	_style_hp_bar(enemy_hp_bar, Color(0.95, 0.35, 0.3, 1.0))

func _style_hp_bar(bar: ProgressBar, fill_color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(7)
	fill.content_margin_top = 2.0
	fill.content_margin_bottom = 2.0
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("0a1120")
	bg.border_color = fill_color.darkened(0.55)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(7)
	bg.shadow_color = Color(0.0, 0.0, 0.03, 0.5)
	bg.shadow_size = 4
	bg.shadow_offset = Vector2(0, 2)
	bar.add_theme_stylebox_override("background", bg)

# ── Operation points (OP) gauge ───────────────────────────────────────────────
# The YELLOW trait pays out operation points. They are a currency, not a score,
# so the gauge always spells out what the number buys: 1 OP = one Workbench card
# move. Hovering the panel explains where OP comes from and what it costs.
func _style_op_panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.10, 0.06, 0.92)
	sb.border_color = Color("f0cf7e")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0.0, 0.0, 0.04, 0.6)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	op_panel.add_theme_stylebox_override("panel", sb)

	# Move gauge (same look as the HP bars, but a slightly tighter radius)
	var fill := StyleBoxFlat.new()
	fill.bg_color = OP_COLOR_ACTIVE
	fill.set_corner_radius_all(5)
	fill.content_margin_top = 2.0
	fill.content_margin_bottom = 2.0
	op_bar.add_theme_stylebox_override("fill", fill)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("0a1120")
	bar_bg.border_color = OP_COLOR_ACTIVE.darkened(0.55)
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(5)
	bar_bg.shadow_color = Color(0.0, 0.0, 0.03, 0.5)
	bar_bg.shadow_size = 4
	bar_bg.shadow_offset = Vector2(0, 2)
	op_bar.add_theme_stylebox_override("background", bar_bg)

	op_title_label.add_theme_color_override("font_color", OP_COLOR_SUB)
	var info: String = "OPERATION POINTS (OP)\nEarned by submitting a word that uses YELLOW cards:\n    OP gained = base damage x 2^(yellow cards - 1)\nOP is never spent by taking damage and never resets.\n\nOP Uses:\n    1 OP = move one Workbench card one place left / right (uses no turn)\n    SPIN one shared reel (SPIN button): 1 OP, then 10 OP, then 100 OP\n    Max 3 spins per turn; the budget refreshes every turn\n    ★ SPECIAL = activate card's unique power (costs OP specified on card)\nThe bar fills up to %d moves." % OP_BAR_CAP
	op_panel.tooltip_text = info
	op_bar.tooltip_text = info
	for node: Label in [op_title_label, op_value_label, op_moves_label, op_hint_label]:
		node.tooltip_text = info
		node.mouse_filter = Control.MOUSE_FILTER_STOP

func _animate_enemy_hit() -> void:
	var tween := create_tween()
	var original_scale: Vector2 = enemy_hp_label.scale
	tween.parallel()
	tween.tween_property(enemy_hp_label, "scale", Vector2(1.12, 1.12), 0.12)
	tween.tween_property(enemy_hp_label, "modulate", Color(1.0, 0.45, 0.35, 1.0), 0.1)
	tween.chain().tween_property(enemy_hp_label, "scale", original_scale, 0.18)
	tween.tween_property(enemy_hp_label, "modulate", Color.WHITE, 0.2)

func _animate_player_hit() -> void:
	var tween := create_tween()
	var original_position: Vector2 = player_hp_label.position
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel()
	tween.tween_property(player_hp_label, "modulate", Color(1.0, 0.4, 0.4, 1.0), 0.1)
	for i in range(3):
		tween.tween_property(player_hp_label, "position:x", original_position.x + 5.0, 0.05)
		tween.tween_property(player_hp_label, "position:x", original_position.x - 5.0, 0.05)
	tween.chain().tween_property(player_hp_label, "position", original_position, 0.1)
	tween.tween_property(player_hp_label, "modulate", Color.WHITE, 0.2)

# Step-by-step HP bar animation (counts the displayed HP value up/down)
func _animate_enemy_hp(stage_shown: int, name_shown: String, from_hp: int, to_hp: int, max_hp: int, duration: float = 0.5) -> void:
	enemy_hp_bar.max_value = max_hp
	var label_prefix: String = "STAGE %d  %s" % [stage_shown, name_shown.to_upper()]
	enemy_hp_label.text = "%s  HP: %d / %d" % [label_prefix, from_hp, int(max_hp)]
	_animate_hp_value(enemy_hp_bar, from_hp, to_hp, duration, func(hp: int) -> void:
		enemy_hp_label.text = "%s  HP: %d / %d" % [label_prefix, hp, int(max_hp)]
	)

func _animate_player_hp(from_hp: int, to_hp: int, max_hp: int, duration: float = 0.5) -> void:
	player_hp_bar.max_value = max_hp
	player_hp_label.text = "PLAYER HP: %d / %d" % [from_hp, int(max_hp)]
	_animate_hp_value(player_hp_bar, from_hp, to_hp, duration, func(hp: int) -> void:
		player_hp_label.text = "PLAYER HP: %d / %d" % [hp, int(max_hp)]
	)

func _animate_hp_value(bar: ProgressBar, from_hp: int, to_hp: int, duration: float, on_step: Callable) -> void:
	var tween := create_tween()
	var steps: int = 20
	var step_duration: float = duration / steps
	bar.value = from_hp
	for i in range(steps + 1):
		var progress: float = float(i) / steps
		var hp: int = int(lerp(float(from_hp), float(to_hp), progress))
		tween.tween_callback(func() -> void:
			bar.value = hp
			on_step.call(hp)
		).set_delay(step_duration)

func _start_blinking_animation(panel: PanelContainer) -> void:
	# Kill any existing tween on this panel
	if panel.has_meta("blink_tween"):
		var old_tween = panel.get_meta("blink_tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()

	var tween := create_tween()
	tween.set_loops()
	tween.set_parallel(false)
	panel.set_meta("blink_tween", tween)

	# Blink red to warn about penalty
	tween.tween_property(panel, "modulate", Color(1.0, 0.4, 0.4, 1.0), 0.3)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.3)

func _stop_all_blinking_animations() -> void:
	for s in range(GameManager.NUM_SLOTS):
		var reel: Dictionary = slot_reels[s]
		var card_views: Array = reel["card_views"]
		for cv in card_views:
			var panel: PanelContainer = cv["panel"]
			if panel.has_meta("blink_tween"):
				var old_tween = panel.get_meta("blink_tween")
				if old_tween and old_tween.is_valid():
					old_tween.kill()
				panel.remove_meta("blink_tween")
			panel.modulate = Color.WHITE

# ── Workbench Drop Target ───────────────────────────────────────────────────
func _setup_workbench_drop_target() -> void:
	var wb_style := StyleBoxFlat.new()
	wb_style.bg_color = Color("101a2b")
	wb_style.border_color = Color("d8ad4b")
	wb_style.border_width_bottom = 2
	wb_style.border_width_top = 2
	wb_style.border_width_left = 2
	wb_style.border_width_right = 2
	wb_style.set_corner_radius_all(12)
	wb_style.shadow_color = Color(0.0, 0.0, 0.04, 0.55)
	wb_style.shadow_size = 10
	wb_style.shadow_offset = Vector2(0, 4)
	workbench_panel.add_theme_stylebox_override("panel", wb_style)

	workbench_panel.set_script(load("res://src/ui/WorkbenchDropZone.gd"))
	workbench_panel.card_dropped.connect(_on_workbench_card_dropped)
	workbench_panel.drop_hovered.connect(_on_workbench_drop_hovered)


## A card was dropped on the Workbench. It lands in whichever gap the player was
## aiming at, so a word can be built in any order instead of left to right.
func _on_workbench_card_dropped(card_data: Dictionary, at_position: Vector2) -> void:
	_hide_workbench_caret()
	add_card_to_workbench(card_data, _workbench_insert_index(at_position))


## Keeps a gold caret in the gap the card would drop into, so the insertion
## point is obvious while dragging.
func _on_workbench_drop_hovered(at_position: Vector2, valid: bool) -> void:
	if not valid:
		_hide_workbench_caret()
		return
	_show_workbench_caret(_workbench_insert_index(at_position))


## Which slot in `workbench_cards` a drop at `at_position` (panel-local) belongs
## in: the gap before the first card whose midpoint is to the right of the
## pointer, or the end of the word when the pointer is past the last card.
func _workbench_insert_index(at_position: Vector2) -> int:
	# The drop position is relative to the panel; the cards live in the inner
	# container, which is offset inside it.
	var local: Vector2 = at_position - workbench_container.position
	var cards: Array[Control] = []
	for child in workbench_container.get_children():
		# The caret is a UI hint, not a card, so it never counts.
		if child is Control and child != _workbench_caret:
			cards.append(child)
	for i in range(cards.size()):
		var centre: float = cards[i].position.x + cards[i].size.x * 0.5
		if local.x < centre:
			return i
	return cards.size()


## The insertion caret lives inside the card container so the HBox lays it out
## in the gap it marks. It is hidden whenever no card is being dragged.
func _show_workbench_caret(index: int) -> void:
	_ensure_workbench_caret()
	_workbench_caret_index = index
	# Translate the card index into a child index, since the caret itself is one.
	var target: int = 0
	var seen: int = 0
	for child in workbench_container.get_children():
		if child == _workbench_caret:
			continue
		if seen == index:
			break
		seen += 1
		target += 1
	workbench_container.move_child(_workbench_caret, mini(target, workbench_container.get_child_count() - 1))
	_workbench_caret.visible = true


func _hide_workbench_caret() -> void:
	_workbench_caret_index = -1
	if _workbench_caret != null:
		_workbench_caret.visible = false


func _ensure_workbench_caret() -> void:
	if _workbench_caret == null:
		_workbench_caret = ColorRect.new()
		_workbench_caret.color = Color(1.0, 0.85, 0.30, 0.95)
		_workbench_caret.custom_minimum_size = Vector2(5, 64)
		_workbench_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_workbench_caret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _workbench_caret.get_parent() != workbench_container:
		workbench_container.add_child(_workbench_caret)

# ── Card View Factory ────────────────────────────────────────────────────────
## `clip_text` keeps a card's minimum width pinned to its `custom_minimum_size`
## instead of letting a long label stretch it. Reel cards pass `true` because they
## live inside a fixed-size clipping window, so an overflowing label would be
## cut off at the edge; hand cards leave it off so their text can grow freely.
func _create_card_view(w: float, h: float, letter_size: int, sub_size: int, clip_text: bool = false) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(w, h)
	panel.clip_contents = false

	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.shadow_color = Color(0.0, 0.0, 0.03, 0.55)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 5.0
	sb.content_margin_right = 5.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	var lbl_letter := Label.new()
	lbl_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_letter.clip_text = clip_text
	lbl_letter.add_theme_font_size_override("font_size", letter_size)
	lbl_letter.add_theme_color_override("font_outline_color", Color("080d17"))
	lbl_letter.add_theme_constant_override("outline_size", 2)
	vbox.add_child(lbl_letter)

	var lbl_sub := Label.new()
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_sub.clip_text = clip_text
	lbl_sub.add_theme_font_size_override("font_size", sub_size)
	lbl_sub.add_theme_color_override("font_outline_color", Color("080d17"))
	lbl_sub.add_theme_constant_override("outline_size", 1)
	vbox.add_child(lbl_sub)

	return {
		"panel": panel,
		"style": sb,
		"letter": lbl_letter,
		"sub": lbl_sub
	}

# ── Build 3 Slot Reels with Clipping Window ─────────────────────────────────
## Each reel is a VBox: the scrolling card window plus a SPIN button underneath,
## so the player can advance that one reel for OP without touching the others.
func _build_slot_reels() -> void:
	slot_reels.clear()
	for s in range(GameManager.NUM_SLOTS):
		# Column wrapper holding the reel window and its SPIN button. The button is
		# deliberately slim so the reels still fit the 800px-tall window.
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 2)
		slot_container.add_child(column)

		# Window container: clips children to show exactly 3 card rows
		var window := Control.new()
		window.custom_minimum_size = Vector2(SLOT_CARD_W, REEL_WINDOW_H)
		window.clip_contents = true
		column.add_child(window)

		# Moving strip of cards inside window
		var strip := VBoxContainer.new()
		strip.custom_minimum_size = Vector2(SLOT_CARD_W, 0)
		strip.add_theme_constant_override("separation", int(SLOT_SEP))
		strip.position = Vector2(0, 0)
		window.add_child(strip)

		# Strip contains 4 cards:
		# Index 0: Row 0 (Top: 3rd card in cycle)
		# Index 1: Row 1 (Center: ACTIVE card)
		# Index 2: Row 2 (Bottom: NEXT card)
		# Index 3: Row 3 (Transition buffer card for smooth scroll)
		var card_views: Array = []
		for _i in range(4):
			# clip_text = true: these cards live inside a fixed-width clipping
			# window, so a long label must never stretch them past that window.
			var cv: Dictionary = _create_card_view(SLOT_CARD_W, SLOT_CARD_H, 24, 10, true)
			strip.add_child(cv["panel"])
			card_views.append(cv)

		# SPIN button: advances THIS reel by one step for OP
		var spin_btn := Button.new()
		spin_btn.custom_minimum_size = Vector2(SLOT_CARD_W, 20)
		var caption: Array = _spin_button_caption()
		spin_btn.text = str(caption[0])
		spin_btn.tooltip_text = str(caption[1])
		spin_btn.add_theme_font_size_override("font_size", 11)
		_style_spin_button(spin_btn)
		spin_btn.pressed.connect(_on_spin_pressed.bind(s))
		column.add_child(spin_btn)

		slot_reels.append({
			"window": window,
			"column": column,
			"spin_button": spin_btn,
			"strip": strip,
			"card_views": card_views
		})

		# Gap guide between slots
		if s < GameManager.NUM_SLOTS - 1:
			var gap_col := VBoxContainer.new()
			gap_col.alignment = BoxContainer.ALIGNMENT_CENTER
			gap_col.custom_minimum_size = Vector2(48, REEL_WINDOW_H)
			slot_container.add_child(gap_col)

			var gap_lbl := Label.new()
			gap_lbl.text = "· · ·\n[ INSERT ]\n· · ·"
			gap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gap_lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55, 0.8))
			gap_lbl.add_theme_font_size_override("font_size", 11)
			gap_col.add_child(gap_lbl)

# ── Build hand cards ─────────────────────────────────────────────────────────
func _build_hand_cards() -> void:
	hand_card_views.clear()
	for _i in range(GameManager.HAND_SIZE):
		var card_view: Dictionary = _create_card_view(96, 76, 32, 12)
		hand_container.add_child(card_view["panel"])
		hand_card_views.append(card_view)

func _is_card_in_workbench(card_data: Dictionary) -> bool:
	for c in workbench_cards:
		if c["type"] == card_data["type"]:
			if c["type"] == "slot" and c["index"] == card_data["index"]:
				return true
			elif c["type"] == "hand" and c["hand_index"] == card_data["hand_index"]:
				return true
	return false

# ── Refresh Hand and Deck/Graveyard ──────────────────────────────────────────
func _refresh_hand_and_deck() -> void:
	var current_hand: Array = GameManager.get_hand()
	var next_visual_keys: Array = []
	var drawn_panels: Array = []
	for i in range(hand_card_views.size()):
		var cv: Dictionary = hand_card_views[i]
		var sb: StyleBoxFlat = cv["style"]
		var panel: PanelContainer = cv["panel"]

		if i < current_hand.size() and current_hand[i] != null:
			var card: Dictionary = current_hand[i]
			next_visual_keys.append(_card_visual_key(card))
			if _animate_next_hand_refresh and i < _hand_visual_keys.size() and _hand_visual_keys[i] != next_visual_keys[i]:
				drawn_panels.append(panel)
			var is_wildcard: bool = card["letter"] == "?"
			var card_data: Dictionary = {
				"type": "hand",
				"hand_index": i,
				"char": card["letter"],  # For display purposes
				"card_letter": card["letter"],  # The actual letter on the card
				"damage": card["damage"],
				"is_wildcard": is_wildcard,
				"color": card.get("color", "red")
			}

			cv["letter"].text = card["letter"]

			# Apply card color styling
			var color_name: String = card.get("color", "red")
			var color_consts: Dictionary = get_card_color_constants(color_name)
			sb.border_color = color_consts["border"]
			sb.bg_color = color_consts["bg"]

			# Wildcard: gold letter for identification, but border keeps the card's color
			# so players can match wildcards with same-color cards for multipliers
			if is_wildcard:
				cv["letter"].add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))  # Gold

			# Player cards are never the skill card: the skill lives on ONE shared
			# reel card and fires only from a bottom row at night. Spelling a letter
			# here does nothing, so no ⚠ mark belongs on a hand card.
			panel.tooltip_text = ""

			if _is_card_in_workbench(card_data):
				cv["sub"].text = "IN USE"
				cv["letter"].add_theme_color_override("font_color", Color(0.5, 0.45, 0.25, 0.6))
				cv["sub"].add_theme_color_override("font_color", Color(0.5, 0.45, 0.25, 0.6))
				sb.bg_color = color_consts["bg"].lerp(Color(0, 0, 0, 0.4), 0.4)
				sb.border_color = color_consts["border"].lerp(Color(0, 0, 0, 0.4), 0.4)
				_detach_drag_source(panel)
			else:
				if GameManager.has_special_ability(card):
					var special_cost: int = GameManager.get_special_cost(card)
					var affordable: bool = GameManager.get_operation_points() >= special_cost
					var s_name: String = GameManager.get_special_name(card)
					cv["sub"].text = "%d dmg ★ %d OP" % [card["damage"], special_cost]
					panel.tooltip_text = "★ %s (%d OP): %s" % [
						s_name, special_cost, GameManager.get_special_desc(card)]
					if affordable:
						cv["sub"].add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
					else:
						# Too costly right now: dim it so the cost is still readable
						cv["sub"].add_theme_color_override("font_color", Color(0.62, 0.55, 0.45, 0.9))
				else:
					cv["sub"].text = "%d dmg" % card["damage"]
					cv["sub"].add_theme_color_override("font_color", Color.WHITE)
				cv["letter"].add_theme_color_override("font_color", Color.WHITE)
				_attach_drag_source(panel, card_data)
		else:
			next_visual_keys.append("")
			cv["letter"].text = "-"
			cv["letter"].add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 0.8))
			cv["sub"].text = ""
			sb.bg_color = BG_EMPTY
			sb.border_color = BORDER_EMPTY
			_detach_drag_source(panel)

	var grave: Array = GameManager.get_graveyard()
	deck_grave_label.text = "DRAW PILE: %d cards  |  GRAVEYARD: %d cards  |  Use CARD PILES to inspect" % [
		GameManager.get_deck_count(),
		grave.size()
	]
	_hand_visual_keys = next_visual_keys
	if _animate_next_hand_refresh:
		_animate_next_hand_refresh = false
		_animate_draw_panels(drawn_panels)
	# Safety net: any panel a discard animation hid must be visible again, even
	# when the draw animation above skipped it because the card looks the same.
	_restore_faded_out_panels()

# ── Setup content for a slot card row ───────────────────────────────────────
func _setup_slot_card(cv: Dictionary, card: Dictionary, role: String, slot_idx: int) -> void:
	var l_text: String = card["letter"]
	var pts: int = card["damage"]
	var is_wildcard: bool = l_text == "?"
	var sb: StyleBoxFlat = cv["style"]
	var panel: PanelContainer = cv["panel"]

	cv["letter"].text = l_text

	var card_data: Dictionary = {
		"type": "slot",
		"index": slot_idx,
		"char": l_text,  # For display purposes
		"card_letter": l_text,  # The actual letter on the card
		"damage": pts,
		"is_wildcard": is_wildcard,
		"color": card.get("color", "red")
	}

	# Apply card color styling
	var color_name: String = card.get("color", "red")
	var color_consts: Dictionary = get_card_color_constants(color_name)
	sb.border_color = color_consts["border"]
	sb.bg_color = color_consts["bg"]

	# Wildcard styling (overrides color)
	if is_wildcard:
		cv["letter"].add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))  # Gold
		sb.border_color = Color(1.0, 0.8, 0.2, 1.0)

	# A card carrying one of the enemy's skill letters gets a warning-orange
	# border and a ⚠ mark, so a dangerous letter is visible on the board BEFORE
	# it is ever played. Wildcards ("?") never carry a skill.
	var enemy_skill: Dictionary = GameManager.get_enemy_skill_for_letter(l_text)
	var has_skill: bool = not enemy_skill.is_empty()
	var skill_mark: String = ("  ⚠ %s" % str(enemy_skill.get("name", ""))) if has_skill else ""
	if has_skill:
		panel.tooltip_text = "⚠ This letter wakes the enemy's %s.\n%s" % [
			str(enemy_skill.get("name", "")), str(enemy_skill.get("desc", ""))]
	else:
		panel.tooltip_text = ""

	if role == "active":
		if _is_card_in_workbench(card_data):
			cv["sub"].text = "IN USE"
			cv["letter"].add_theme_color_override("font_color", Color(0.5, 0.45, 0.25, 0.6))
			cv["sub"].add_theme_color_override("font_color", Color(0.5, 0.45, 0.25, 0.6))
			sb.bg_color = color_consts["bg"].lerp(Color(0, 0, 0, 0.4), 0.4)
			sb.border_color = color_consts["border"].lerp(Color(0, 0, 0, 0.4), 0.4)
			_detach_drag_source(panel)
		else:
			cv["sub"].text = "★ ACTIVE (%ddmg)%s" % [pts, skill_mark]
			cv["letter"].add_theme_color_override("font_color", Color.WHITE)
			cv["sub"].add_theme_color_override("font_color", ENEMY_SKILL_COLOR if has_skill else Color.WHITE)
			if has_skill:
				sb.border_color = ENEMY_SKILL_COLOR
			_attach_drag_source(panel, card_data)
	elif role == "next":
		cv["sub"].text = "→ NEXT (%ddmg)%s" % [pts, skill_mark]
		cv["letter"].add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
		cv["sub"].add_theme_color_override("font_color", ENEMY_SKILL_COLOR if has_skill else Color(0.8, 0.8, 0.8, 1.0))
		sb.bg_color = color_consts["bg"].lerp(Color(0, 0, 0, 0.3), 0.3)
		sb.border_color = ENEMY_SKILL_COLOR.darkened(0.25) if has_skill else color_consts["border"].lerp(Color(0, 0, 0, 0.3), 0.3)
		_detach_drag_source(panel)
	else:
		cv["sub"].text = "%d dmg%s" % [pts, skill_mark]
		cv["letter"].add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		cv["sub"].add_theme_color_override("font_color", ENEMY_SKILL_COLOR if has_skill else Color(0.6, 0.6, 0.6, 1.0))
		sb.bg_color = color_consts["bg"].lerp(Color(0, 0, 0, 0.5), 0.5)
		sb.border_color = ENEMY_SKILL_COLOR.darkened(0.45) if has_skill else color_consts["border"].lerp(Color(0, 0, 0, 0.5), 0.5)
		_detach_drag_source(panel)

# ── Populate Slot Reels (All 3 Cards are Visible: Top, Center Active, Bottom) ─
func _refresh_slots() -> void:
	# Stop all blinking animations first
	_stop_all_blinking_animations()

	var is_day = GameManager.get_phase() == "DAY"

	var indices: Array = GameManager.current_slot_indices
	for s in range(GameManager.NUM_SLOTS):
		var reel: Dictionary = slot_reels[s]
		var strip: VBoxContainer = reel["strip"]
		strip.position = Vector2(0, 0) # Normal position: rows 0, 1, 2 all visible

		var s_cards: Array = GameManager.get_slot_cards(s)
		var total_c: int = GameManager.CARDS_PER_SLOT # 3 cards
		var cur_i: int = indices[s] % total_c
		var prev_i: int = (cur_i - 1 + total_c) % total_c
		var next_i: int = (cur_i + 1) % total_c

		var card_views: Array = reel["card_views"]
		# Row 0: Top (IDLE)
		_setup_slot_card(card_views[0], s_cards[prev_i], "idle", s)
		# Row 1: Center (ACTIVE)
		_setup_slot_card(card_views[1], s_cards[cur_i], "active", s)
		# Row 2: Bottom (NEXT)
		_setup_slot_card(card_views[2], s_cards[next_i], "next", s)
		# Row 3: Upcoming into view when animated
		_setup_slot_card(card_views[3], s_cards[prev_i], "idle", s)

		# Start blinking on NEXT card only during DAY phase
		if is_day:
			_start_blinking_animation(card_views[2]["panel"])

	_refresh_spin_buttons()


## Keeps the Workbench's "which reel is in use" flags in sync with the game, and
## reflects the current OP / in-use state on every SPIN button.
func _sync_slot_in_use() -> void:
	for s in range(GameManager.NUM_SLOTS):
		var s_cards: Array = GameManager.get_slot_cards(s)
		if s_cards.is_empty():
			GameManager.set_slot_in_use(s, false)
			continue
		var cur_i: int = GameManager.current_slot_indices[s] % s_cards.size()
		var active: Dictionary = s_cards[cur_i]
		GameManager.set_slot_in_use(s, _is_slot_in_workbench(s, str(active.get("letter", ""))))


## Whether reel `slot_idx`'s current ACTIVE card sits on the Workbench.
func _is_slot_in_workbench(slot_idx: int, _letter: String) -> bool:
	for c: Dictionary in workbench_cards:
		if str(c.get("type", "")) == "slot" and int(c.get("index", -1)) == slot_idx:
			return true
	return false


## Enables/disables each SPIN button and shows why when it is not available.
func _refresh_spin_buttons() -> void:
	_sync_slot_in_use()
	for s in range(GameManager.NUM_SLOTS):
		if s >= slot_reels.size():
			continue
		var btn: Button = slot_reels[s].get("spin_button", null)
		if btn == null:
			continue
		var check: Dictionary = GameManager.can_spin_slot(s)
		btn.disabled = not check.get("ok", false)
		var caption: Array = _spin_button_caption()
		btn.text = str(caption[0])
		if check.get("ok", false):
			btn.tooltip_text = str(caption[1])
		else:
			btn.tooltip_text = "Cannot spin: %s" % str(check.get("reason", ""))


## Caption + tooltip for a SPIN button. The price escalates each spin (1 / 10 /
## 100 OP) and the button says so, and once the turn's three spins are gone it
## reads NO SPINS rather than a price the player cannot pay.
func _spin_button_caption() -> Array:
	var cost: int = GameManager.get_next_spin_cost()
	if cost < 0:
		return ["NO SPINS",
			"All %d spins for this turn are used." % GameManager.MAX_SPINS_PER_TURN]
	var which: int = GameManager.spins_this_turn + 1
	return ["SPIN %d OP" % cost,
		"Advance this reel one step for %d OP (spin %d of %d this turn)." % [
			cost, which, GameManager.MAX_SPINS_PER_TURN]]


func _style_spin_button(btn: Button) -> void:
	_style_button(btn, Color("1e3350"), Color("5fa8d3"), Color("e6f4ff"))


## Spends OP to advance one shared reel by a single step, with the same scroll
## animation the end-of-turn rotation uses.
func _on_spin_pressed(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= slot_reels.size():
		return
	var result: Dictionary = GameManager.spin_slot(slot_idx)
	if not result.get("ok", false):
		message_label.text = str(result.get("reason", "Cannot spin this reel."))
		message_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3, 1.0))
		return

	_play_card_swap_sound()
	var step_dist: float = SLOT_CARD_H + SLOT_SEP
	var strip: VBoxContainer = slot_reels[slot_idx]["strip"]
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(strip, "position:y", -step_dist, 0.3)
	tween.tween_callback(func():
		_refresh_slots()
		_refresh_ui()
		_refresh_formula_panel()
	)

	_refresh_ui()
	message_label.text = str(result.get("message", ""))
	message_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0, 1.0))

# ── Slot Rotation Animation (Smooth reel roll upwards) ───────────────────────
func animate_slot_rotations(used_slots: Array, on_complete: Callable) -> void:
	if not used_slots.is_empty():
		_play_card_swap_sound()
	var step_dist: float = SLOT_CARD_H + SLOT_SEP # Scroll exactly 1 card distance
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	# Animate only used slots
	for s in used_slots:
		var reel: Dictionary = slot_reels[s]
		var strip: VBoxContainer = reel["strip"]
		# Scroll upward: Row 2 (Next) rolls smoothly into Row 1 (Center)
		tween.tween_property(strip, "position:y", -step_dist, 0.35)

	tween.chain().tween_callback(func():
		_refresh_slots()
		on_complete.call()
	)

# ── Drag Source Attachment Helper ───────────────────────────────────────────
func _attach_drag_source(panel: PanelContainer, card_data: Dictionary) -> void:
	panel.set_script(load("res://src/ui/DraggableCard.gd"))
	panel.card_data = card_data
	if not panel.clicked.is_connected(_on_card_clicked):
		panel.clicked.connect(_on_card_clicked)
	if not panel.special_used.is_connected(_on_card_special_used):
		panel.special_used.connect(_on_card_special_used)

func _detach_drag_source(panel: PanelContainer) -> void:
	if panel.has_signal("clicked") and panel.clicked.is_connected(_on_card_clicked):
		panel.clicked.disconnect(_on_card_clicked)
	if panel.has_signal("special_used") and panel.special_used.is_connected(_on_card_special_used):
		panel.special_used.disconnect(_on_card_special_used)
	panel.set_script(null)

func _on_card_clicked(card_data: Dictionary) -> void:
	add_card_to_workbench(card_data)

# ── Special Ability: cards with SPECIAL_MIN_DAMAGE or more, paid for in OP ─────
# The card's damage value is its cost; it is spent only when the activation
# actually succeeds (see GameManager.use_special_ability).
func _on_card_special_used(card_data: Dictionary) -> void:
	# Special abilities only work for cards in hand
	if card_data.get("type", "") != "hand":
		message_label.text = "Special ability only works on cards in hand."
		message_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3, 1.0))
		return

	var hand_index: int = card_data.get("hand_index", -1)
	var hand_arr: Array = GameManager.get_hand()
	if hand_index < 0 or hand_index >= hand_arr.size() or hand_arr[hand_index] == null:
		return

	var card: Dictionary = hand_arr[hand_index]
	if not GameManager.has_special_ability(card):
		message_label.text = "%s (%ddmg) has no special ability." % [
			card["letter"], card["damage"]
		]
		message_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3, 1.0))
		return

	# Refuse before touching any card when the player cannot afford it.
	var cost: int = GameManager.get_special_cost(card)
	if GameManager.get_operation_points() < cost:
		var deficit: int = GameManager.get_special_cost_deficit(card)
		_refresh_op_display("denied")
		_refresh_formula_panel()
		_show_step_message("Not enough OP: ★ SPECIAL [%s] costs %d OP — you need %d more. Submit a word with YELLOW cards to earn OP." % [
			GameManager.get_special_name(card), cost, deficit
		], Color(1.0, 0.8, 0.3, 1.0))
		return

	var discarded_panels: Array = []
	if hand_index >= 0 and hand_index < hand_card_views.size():
		discarded_panels.append(hand_card_views[hand_index]["panel"])

	var result: Dictionary = GameManager.use_special_ability(hand_index)
	if not result.get("valid", false):
		_refresh_op_display("denied")
		_show_step_message("★ SPECIAL failed: %s." % str(result.get("reason", "unknown")), Color(1.0, 0.8, 0.3, 1.0))
		return

	if not discarded_panels.is_empty():
		await _animate_cards_discard(discarded_panels)

	# Remove any workbench cards that were discarded by the effect
	var grave_tail: Array = GameManager.get_graveyard().slice(GameManager.get_graveyard().size() - result.get("drawn", 1))
	workbench_cards = workbench_cards.filter(func(c: Dictionary) -> bool:
		if c.get("type") != "hand":
			return true
		var hi: int = c.get("hand_index", -1)
		var cur_hand: Array = GameManager.get_hand()
		if hi >= 0 and hi < cur_hand.size() and cur_hand[hi] != null:
			return true
		for d in grave_tail:
			if d.get("letter") == c.get("card_letter") and d.get("damage") == c.get("damage") and d.get("color") == c.get("color"):
				return false
		return true
	)

	_play_score_up_sound()
	_animate_next_hand_refresh = true
	_refresh_op_display("spend")
	_refresh_ui()
	_refresh_formula_panel()
	_show_step_message("★ SPECIAL: spent %d OP! %s  [%d OP left]" % [
		result["cost"], result.get("message", ""), GameManager.get_operation_points()
	], Color(1.0, 0.85, 0.3, 1.0))

# ── Submit preview: what you will take when you press SUBMIT WORD ───────────
# Shows the incoming damage BEFORE submitting, so a risky word can be spotted
# while it is still being built. The shared reels rotate as part of submitting,
# so the NIGHT penalty is previewed from the cards that will be NEXT *after*
# that rotation (GameManager.predict_submit_outcome handles the ordering).
func _refresh_submit_preview() -> void:
	if workbench_cards.is_empty():
		preview_label.text = "Place cards on the Workbench to preview the damage you will take on SUBMIT."
		preview_label.add_theme_color_override("font_color", PREVIEW_COLOR_IDLE)
		_set_meaning_text("", MEANING_COLOR_NONE)
		_set_definition_text("", MEANING_COLOR_NONE)
		return

	# Resolve the same assignment SUBMIT would use, so the preview matches it
	var pattern_chars: Array = []
	for c in workbench_cards:
		pattern_chars.append(str(c.get("card_letter", c.get("letter", "?"))))
	var pattern: String = "".join(pattern_chars)

	var valid_assignments: Array = GameManager.find_valid_assignments(pattern)
	if valid_assignments.is_empty():
		preview_label.text = "X  '%s' IS NOT A WORD  —  SUBMIT will be rejected." % pattern.to_upper()
		preview_label.add_theme_color_override("font_color", PREVIEW_COLOR_INVALID)
		_set_meaning_text("", MEANING_COLOR_NONE)
		_set_definition_text("", MEANING_COLOR_NONE)
		return

	var chosen: Array = _pick_best_assignment(workbench_cards, valid_assignments)
	var word: String = ""
	for a in chosen:
		word += str(a["char"])
	if not GameManager.is_assignment_valid(word, chosen):
		preview_label.text = "X  INVALID SLOT ORDER  —  use slots left to right."
		preview_label.add_theme_color_override("font_color", PREVIEW_COLOR_INVALID)
		_set_meaning_text("", MEANING_COLOR_NONE)
		_set_definition_text("", MEANING_COLOR_NONE)
		return

	var used_slots: Array = []
	for a in chosen:
		if str(a.get("type", "")) == "slot":
			used_slots.append(int(a.get("index", -1)))

	var plan: Dictionary = GameManager.predict_submit_outcome(chosen, used_slots)
	preview_label.text = _build_preview_text(plan, word)
	preview_label.add_theme_color_override("font_color", _preview_color(plan))
	# Show what the word means while the player still has time to reconsider
	_refresh_word_meaning(word)


# ── Word meaning via the Jisho API ───────────────────────────────────────────
# Looks the current word up and renders "kanji (reading) — pos: definition…".
# The request is asynchronous, so this first paints a "looking up" placeholder
# and _on_jisho_lookup_finished() fills in the real text when it arrives.
func _refresh_word_meaning(word: String) -> void:
	_looked_up_word = word
	if word.strip_edges().length() < 2:
		_set_meaning_text("", MEANING_COLOR_NONE)
		_set_definition_text("", MEANING_COLOR_NONE)
		return

	# Bundled translation first: it is instant, offline, and the word is
	# guaranteed to be one the game accepts.
	var gloss: String = GameManager.get_word_translation(word)
	if gloss != "":
		_set_meaning_text(gloss, MEANING_COLOR_JP)
		_set_definition_text("", MEANING_COLOR_NONE)
		return

	# Cached answer (or an explicit "unavailable in Web export") resolves at once
	var cached: Dictionary = JishoClient.peek(word)
	if not cached.is_empty():
		_apply_meaning(cached)
		return

	if not JishoClient.is_available():
		_set_meaning_text("Word meanings: unavailable in the Web export (Jisho sends no CORS headers).", MEANING_COLOR_NONE)
		_set_definition_text("", MEANING_COLOR_NONE)
		return

	_set_meaning_text("Looking up '%s'..." % word.to_upper(), MEANING_COLOR_LOAD)
	_set_definition_text("", MEANING_COLOR_NONE)
	var result: Dictionary = JishoClient.lookup(word)
	# A cache hit (or a synchronous failure) can already carry the answer
	if str(result.get("status", "pending")) != "pending":
		_apply_meaning(result)


func _on_jisho_lookup_finished(word: String, _result: Dictionary) -> void:
	# Ignore an answer for a word the player has since changed
	if word.to_lower() != _looked_up_word.to_lower():
		return
	# A bundled translation always wins, so a late Jisho answer must not replace it
	if GameManager.get_word_translation(word) != "":
		return
	_apply_meaning(JishoClient.peek(word))


func _apply_meaning(result: Dictionary) -> void:
	match str(result.get("status", "")):
		"ok":
			# Two plain labels: the headword in gold, the definitions in pale blue.
			# Godot 4's Label cannot render BBCode, so colours come from the theme.
			_set_meaning_text(_build_meaning_text(result), MEANING_COLOR_JP)
			_set_definition_text("; ".join(result.get("definitions", [])), MEANING_COLOR_DEF)
		"not_found":
			_set_meaning_text("'%s' has no Jisho entry." % str(result.get("word", "")), MEANING_COLOR_NONE)
			_set_definition_text("", MEANING_COLOR_NONE)
		"error":
			_set_meaning_text("Meaning lookup failed (%s)." % str(result.get("reason", "error")), MEANING_COLOR_NONE)
			_set_definition_text("", MEANING_COLOR_NONE)
		_:
			_set_meaning_text("", MEANING_COLOR_NONE)
			_set_definition_text("", MEANING_COLOR_NONE)


func _build_meaning_text(result: Dictionary) -> String:
	var kanji: String = str(result.get("kanji", ""))
	var reading: String = str(result.get("reading", ""))
	var pos: String = str(result.get("pos", ""))

	var head: String = ""
	if kanji != "":
		head = kanji
		if reading != "":
			head += " (%s)" % reading
	if pos != "":
		head += ("  " if head != "" else "") + pos
	return head


func _set_meaning_text(text: String, color: Color) -> void:
	meaning_label.text = text
	meaning_label.add_theme_color_override("font_color", color)


## Definitions live on their own label so they can be a different colour from
## the headword without needing BBCode.
func _set_definition_text(text: String, color: Color) -> void:
	definition_label.text = text
	definition_label.add_theme_color_override("font_color", color)
	definition_label.visible = text.strip_edges() != ""


func _preview_color(plan: Dictionary) -> Color:
	if bool(plan.get("lethal", false)):
		return PREVIEW_COLOR_LETHAL
	var lost: int = int(plan.get("total_hp_lost", 0))
	if lost > 0:
		return PREVIEW_COLOR_HURT
	return PREVIEW_COLOR_SAFE


func _build_preview_text(plan: Dictionary, word: String) -> String:
	var parts: Array = ["ON SUBMIT  '%s'  ->" % word.to_upper()]

	# Spelling consecutive letters of the enemy's own name doubles every card.
	var name_mult: int = int(plan.get("name_multiplier", 1))
	if name_mult > 1:
		parts.append("NAME RUN x%d (%d letters of '%s' in a row)" % [
			name_mult, int(plan.get("name_run", 0)), GameManager.enemy_name.to_upper()])

	# Enemy side. The enemy's AEGIS shield eats the hit first, so both numbers are
	# shown: what you swung, and what actually reached its HP.
	var final_damage: int = int(plan.get("final_damage", 0))
	var enemy_shield: int = int(plan.get("enemy_shield_absorbed", 0))
	if final_damage > 0:
		if enemy_shield > 0:
			parts.append("ENEMY %d dmg (shield ate %d, %d lands)" % [
				final_damage, enemy_shield, int(plan.get("enemy_hp_damage", 0))])
		else:
			parts.append("ENEMY %d dmg" % final_damage)
	elif final_damage < 0:
		parts.append("YOUR WORD HITS YOU %d" % -final_damage)

	# Enemy skill: the card answers at NIGHT while it sits in a reel's bottom row.
	if bool(plan.get("enemy_skills_fire", false)):
		parts.append("ENEMY SKILL: %s" % str(plan.get("enemy_skill_log", [])[0]))
		var extra: Array = plan.get("enemy_skill_log", [])
		for i in range(1, extra.size()):
			parts.append(str(extra[i]))
	elif bool(plan.get("defeats_enemy", false)):
		parts.append("enemy dies first — no skill fires")

	# Traits the word grants
	if int(plan.get("shield_gained", 0)) > 0:
		parts.append("+ %d SHIELD" % int(plan["shield_gained"]))
	if int(plan.get("heal_amount", 0)) > 0:
		parts.append("+ %d HP" % int(plan["heal_amount"]))

	# Night penalty (already accounting for the reels rotating on submit)
	if bool(plan.get("next_is_night", false)):
		var night: int = int(plan.get("night_penalty", 0))
		var mult: int = int(plan.get("night_multiplier", 1))
		if night > 0:
			var rolls: Array = plan.get("night_next_cards", [])
			var turning: int = 0
			for c in rolls:
				if bool(c.get("will_rotate", false)):
					turning += 1
			var note: String = "  (%d x x%d, after %d reel%s roll)" % [
				int(plan.get("night_base_penalty", 0)), mult, turning,
				"" if turning == 1 else "s"
			]
			parts.append("NIGHT %d dmg%s" % [night, note])
		elif bool(plan.get("defeats_enemy", false)):
			parts.append("NIGHT 0 dmg  (enemy defeated)")
		else:
			parts.append("NIGHT 0 dmg")
	else:
		parts.append("no NIGHT penalty next turn")

	# Bottom line
	var absorbed: int = int(plan.get("total_absorbed", 0))
	var lost: int = int(plan.get("total_hp_lost", 0))
	var bottom: String = "YOU LOSE %d HP" % lost
	if absorbed > 0:
		bottom += "  (shield blocks %d)" % absorbed
	bottom += "   ->   HP %d" % int(plan.get("player_hp_after", 0))
	if bool(plan.get("lethal", false)):
		bottom += "   *** LETHAL: THIS SUBMIT DEFEATS YOU ***"
	parts.append(bottom)

	return "   |   ".join(parts)


# ── Workbench Management ────────────────────────────────────────────────────
func add_card_to_workbench(card_data: Dictionary, index: int = -1) -> void:
	if _is_card_in_workbench(card_data):
		return

	# index -1 appends (the click path); a drag supplies the gap it aimed at.
	if index < 0 or index > workbench_cards.size():
		workbench_cards.append(card_data)
	else:
		workbench_cards.insert(index, card_data)
	_refresh_workbench_ui()
	_refresh_slots()
	_refresh_hand_and_deck()
	# Keep the submit forecast in sync with the Workbench (adding a card can
	# change both the word and which shared reels will roll)
	_refresh_submit_preview()
	_animate_workbench_place()

func move_workbench_card(index: int, direction: int) -> bool:
	# Spend 1 operation point to swap a Workbench card with its neighbor.
	# The action does not consume a turn and only occurs while the player is
	# arranging a word (never during the submission animation).
	if direction != -1 and direction != 1:
		return false
	var target: int = index + direction
	if index < 0 or index >= workbench_cards.size():
		return false
	if target < 0 or target >= workbench_cards.size():
		return false
	if not GameManager.spend_operation_points(1):
		_refresh_op_display("denied")
		_show_step_message("Not enough OP: 1 OP moves a Workbench card one place. Submit a word with YELLOW cards to earn more.", Color(1.0, 0.8, 0.3, 1.0))
		return false

	var card: Dictionary = workbench_cards[index]
	workbench_cards.remove_at(index)
	workbench_cards.insert(target, card)
	_refresh_workbench_ui()
	_animate_workbench_swap()
	_refresh_op_display("spend")
	_refresh_formula_panel()
	# Reordering can change which assignment the word resolves to, so re-preview
	_refresh_submit_preview()
	_show_step_message("Moved card %d %s  —  spent 1 OP  (%d OP = %d move%s left)" % [
		index + 1,
		"left" if direction < 0 else "right",
		GameManager.get_operation_points(),
		GameManager.get_operation_points(),
		"" if GameManager.get_operation_points() == 1 else "s"
	], Color(1.0, 0.9, 0.35, 1.0))
	return true

func remove_card_from_workbench_at(idx: int) -> void:
	if idx >= 0 and idx < workbench_cards.size():
		var cards: Array = workbench_container.get_children()
		if idx < cards.size():
			await _animate_cards_discard([cards[idx]])
		workbench_cards.remove_at(idx)
		_refresh_workbench_ui()
		_refresh_slots()
		_refresh_hand_and_deck()
	# Removing a card changes the previewed word and the set of rolling reels
	_refresh_submit_preview()

func _refresh_workbench_ui() -> void:
	# Remember whether a drop is in progress: this rebuilds every child, which
	# would otherwise destroy the caret mid-drag.
	var caret_was_shown: bool = _workbench_caret != null and _workbench_caret.visible
	for ch in workbench_container.get_children():
		workbench_container.remove_child(ch)
		ch.queue_free()

	if workbench_cards.is_empty():
		var hint := Label.new()
		hint.text = "Drag cards here or click available cards to construct a word..."
		hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.7))
		hint.add_theme_font_size_override("font_size", 14)
		workbench_container.add_child(hint)
		if caret_was_shown:
			_show_workbench_caret(0)
		return

	for i in range(workbench_cards.size()):
		var c_data: Dictionary = workbench_cards[i]
		var cv: Dictionary = _create_card_view(80, 64, 26, 10)
		var panel: PanelContainer = cv["panel"]
		var sb: StyleBoxFlat = cv["style"]

		# Display the actual character (for wildcards, this is the matched letter)
		var display_char: String = c_data.get("char", c_data.get("card_letter", "?"))
		cv["letter"].text = display_char

		# Colour the card exactly like it is coloured in the hand and on the
		# shared reels, so the player can read the word's traits (RED damage
		# multiplier, BLUE shield, GREEN heal, YELLOW OP) at a glance.
		var color_consts: Dictionary = get_card_color_constants(str(c_data.get("color", "red")))
		sb.bg_color = color_consts["bg"]
		sb.border_color = color_consts["border"]

		cv["letter"].add_theme_color_override("font_color", TXT_WORKBENCH)
		if c_data.get("is_wildcard", false):
			# Gold letter marks the wildcard, but the border keeps the card's own
			# colour so wildcards can still match same-colour cards.
			cv["letter"].add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))

		var src_label: String = "Slot %d" % (c_data["index"] + 1) if c_data["type"] == "slot" else "Hand"
		cv["sub"].text = "%s (%ddmg)" % [src_label, c_data["damage"]]
		cv["sub"].add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.85))

		var captured_idx: int = i
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				remove_card_from_workbench_at(captured_idx)
		)

		workbench_container.add_child(panel)

	if caret_was_shown:
		_show_workbench_caret(mini(_workbench_caret_index, workbench_cards.size()))

func _refresh_ui() -> void:
	_refresh_slots()
	_refresh_hand_and_deck()
	_refresh_workbench_ui()
	_refresh_submit_preview()

	var phase: String = GameManager.get_phase()
	var phase_color: Color = COLOR_NIGHT if phase == "NIGHT" else COLOR_DAY

	turn_label.text = "Turn: %d / %d  |  %s" % [GameManager.get_turn(), GameManager.MAX_TURNS, phase]
	turn_label.add_theme_color_override("font_color", phase_color)

	# OP has its own gauge, so it is not repeated in the stats line. The enemy
	# skill display appends its "DANGER" suffix to this same label, so the plain
	# line is cached FIRST — _refresh_hp_display() writes the suffixed version.
	_stats_line = _build_stats_line()

	# _refresh_hp_display() rewrites stats_label, appending the "DANGER" suffix.
	_refresh_hp_display()

	# OP has its own gauge, so it is not repeated in the stats line
	_refresh_op_display()

	message_label.text = ""

# ── Player / Enemy HP display ────────────────────────────────────────────────
func _refresh_hp_display() -> void:
	# Player HP (negative damage & night self-damage reduce it)
	var p_hp: int = GameManager.get_player_hp()
	var p_max: int = GameManager.get_max_player_hp()
	player_hp_bar.max_value = p_max
	player_hp_bar.value = p_hp
	var p_text: String = "PLAYER HP: %d / %d" % [p_hp, p_max]
	if GameManager.get_shield() > 0:
		p_text += "  [SHIELD %d]" % GameManager.get_shield()
	if GameManager.get_phase() == "NIGHT":
		p_text += "   (!! you take %d)" % GameManager.get_next_slot_total_penalty()
	player_hp_label.text = p_text
	var p_ratio: float = float(p_hp) / float(maxi(p_max, 1))
	if p_ratio <= 0.25:
		player_hp_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3, 1.0))
	else:
		player_hp_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9, 1.0))

	# Enemy HP (positive damage reduces it)
	var e_hp: int = GameManager.get_enemy_hp()
	var e_max: int = GameManager.get_max_enemy_hp()
	enemy_hp_bar.max_value = e_max
	enemy_hp_bar.value = e_hp
	var e_text: String = "STAGE %d  %s  HP: %d / %d" % [
		GameManager.get_stage(), GameManager.get_enemy_name().to_upper(), e_hp, e_max]
	# AEGIS is shown right on the HP line so a player who wonders why a big word
	# did nothing can see the shield eating it.
	if GameManager.get_enemy_shield() > 0:
		e_text += "  [ENEMY SHIELD %d]" % GameManager.get_enemy_shield()
	enemy_hp_label.text = e_text
	enemy_hp_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.85, 1.0))
	_refresh_enemy_skill_display()

	# Center the pivot so hit-shake animations scale from the middle
	player_hp_label.pivot_offset = player_hp_label.size / 2.0
	enemy_hp_label.pivot_offset = enemy_hp_label.size / 2.0


# ── Enemy skills ─────────────────────────────────────────────────────────────
# Appends the current enemy's skill card to the stats line.
# This is deliberately NOT a row of its own: the VBox already fills the 800px
# window exactly, so any extra label would push the Workbench off screen. The
# full rules live in the tooltip and the FORMULAS panel.
func _refresh_enemy_skill_display() -> void:
	var skills: Array = GameManager.get_enemy_skills()
	if skills.is_empty():
		stats_label.tooltip_text = ""
		return

	var skill: Dictionary = skills[0]
	var letter: String = str(skill.get("letter", ""))
	var name_text: String = str(skill.get("name", "SKILL"))
	var parts: Array = []
	# Where the card stands right now, and whether it is in the firing line.
	var firing: Array = GameManager.get_skill_card_in_firing_line([])
	var where_text: String = "safe"
	for hit in firing:
		where_text = "slot %d BOTTOM" % (int(hit.get("slot", 0)) + 1)
	parts.append("[%s]%s — %s" % [letter, name_text, where_text])

	var tips: Array = [
		"ENEMY SKILL CARD — exactly ONE card on the shared reels carries it.",
		"  [%s] %s (%d) — %s" % [letter, name_text, int(skill.get("value", 0)), str(skill.get("desc", ""))],
		"",
		"IT FIRES AT NIGHT while that card sits in the BOTTOM row of a reel.",
		"Spelling the letter does nothing — its POSITION is the trigger.",
		"Use the SPIN buttons (3 per turn: 1 OP, then 10 OP, then 100 OP) or",
		"submit a word that uses that reel",
		"to roll the card out of the bottom row before night falls.",
		"A stage clear ends the fight, so a defeated enemy never fires.",
		"Every one of these is wiped the moment the stage is cleared.",
	]

	# Live state of the persistent effects, so the board never lies about them.
	var shield_now: int = GameManager.get_enemy_shield()
	if shield_now > 0:
		parts.append("shield %d" % shield_now)
	if GameManager.get_enemy_night_tax() > 0:
		parts.append("night +%d" % GameManager.get_enemy_night_tax())
	if GameManager.get_hand_limit() < GameManager.HAND_SIZE:
		parts.append("hand max %d" % GameManager.get_hand_limit())
	if shield_now > 0 or GameManager.get_enemy_night_tax() > 0 or GameManager.get_hand_limit() < GameManager.HAND_SIZE:
		tips.append("")
		tips.append("ACTIVE RIGHT NOW:")
		if shield_now > 0:
			tips.append("  Enemy shield: %d (soaks damage before its HP, gone when it dies)" % shield_now)
		if GameManager.get_enemy_night_tax() > 0:
			tips.append("  NIGHT tax: +%d added to the night base before the multiplier" % GameManager.get_enemy_night_tax())
		if GameManager.get_hand_limit() < GameManager.HAND_SIZE:
			tips.append("  Hand limit: %d of %d cards" % [GameManager.get_hand_limit(), GameManager.HAND_SIZE])

	stats_label.text = "%s  |  DANGER: %s" % [_stats_line, "  ".join(parts)]
	stats_label.tooltip_text = "\n".join(tips)


## The stats text without the danger suffix, kept so the skill display can be
## rewritten in place instead of rebuilding (and losing) the counters.
func _build_stats_line() -> String:
	return "STAGE %d  |  TOTAL DAMAGE: %d  |  DEFEATED: %d" % [
		GameManager.get_stage(), GameManager.get_total_damage(),
		GameManager.get_enemies_defeated()
	]

# ── Operation points (OP) display ─────────────────────────────────────────────
# Refreshes the whole gauge: amount, how many card moves it buys, the bar and
# the one-line explanation. `flash` forces a feedback animation ("gain",
# "spend" or "denied"); otherwise the change is detected from the previous
# value, so callers can simply call this after anything that may move OP.
func _refresh_op_display(flash: String = "") -> void:
	var op: int = GameManager.get_operation_points()
	var previous: int = _op_displayed
	_op_displayed = op

	op_value_label.text = "%d OP" % op
	if op == 1:
		op_moves_label.text = "= 1 MOVE"
	else:
		op_moves_label.text = "= %d MOVES" % op
	op_bar.max_value = OP_BAR_CAP
	op_bar.value = mini(op, OP_BAR_CAP)

	if op > 0:
		op_value_label.add_theme_color_override("font_color", OP_COLOR_ACTIVE)
		op_moves_label.add_theme_color_override("font_color", OP_COLOR_SUB)
		op_hint_label.text = "1 OP = move a card one place  |  ★ special = card cost"
		op_hint_label.add_theme_color_override("font_color", OP_COLOR_SUB)
	else:
		op_value_label.add_theme_color_override("font_color", OP_COLOR_EMPTY)
		op_moves_label.add_theme_color_override("font_color", OP_COLOR_EMPTY)
		op_hint_label.text = "Earn OP with a YELLOW card (★ specials cost OP too)"
		op_hint_label.add_theme_color_override("font_color", OP_COLOR_EMPTY)

	_animate_op_change(previous, op, flash)

# Pops the number and floats "+N OP" / "-N OP" over the gauge. Runs one frame
# later so the label has its final size and the pop scales from its centre.
func _animate_op_change(previous: int, current: int, flash: String) -> void:
	var gained: int = maxi(current - previous, 0)
	var spent: int = maxi(previous - current, 0)
	if flash == "gain":
		gained = maxi(gained, 1)
	elif flash == "spend":
		spent = maxi(spent, 1)
	elif flash == "denied":
		gained = 0
		spent = 0
	if gained == 0 and spent == 0 and flash != "denied":
		return

	await get_tree().process_frame
	if _op_tween != null and _op_tween.is_valid():
		_op_tween.kill()
	op_value_label.scale = Vector2.ONE
	op_value_label.pivot_offset = op_value_label.size / 2.0
	op_panel.modulate = Color.WHITE

	_op_tween = create_tween()
	if flash == "denied":
		_op_tween.tween_property(op_panel, "modulate", Color(1.0, 0.5, 0.45, 1.0), 0.1)
		_op_tween.tween_property(op_panel, "modulate", Color.WHITE, 0.35)
		return
	_op_tween.tween_property(op_value_label, "scale", Vector2(1.25, 1.25), 0.1)
	if gained > 0:
		_op_tween.tween_property(op_panel, "modulate", Color(1.25, 1.18, 0.90, 1.0), 0.08)
	else:
		_op_tween.tween_property(op_panel, "modulate", Color(0.82, 0.75, 0.70, 1.0), 0.08)
	_op_tween.tween_property(op_value_label, "scale", Vector2.ONE, 0.2)
	_op_tween.tween_property(op_panel, "modulate", Color.WHITE, 0.25)
	if gained > 0:
		_pop_op_float("+%d OP" % gained, OP_COLOR_GAIN)
	elif spent > 0:
		_pop_op_float("-%d OP" % spent, OP_COLOR_SPEND)

# Floating "+8 OP" text above the gauge. It is parented to the root Control
# (a plain Control, not a Container) so it can be positioned freely.
func _pop_op_float(text: String, color: Color) -> void:
	var floater := Label.new()
	floater.text = text
	floater.add_theme_font_size_override("font_size", 18)
	floater.add_theme_color_override("font_color", color)
	floater.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.08, 1.0))
	floater.add_theme_constant_override("outline_size", 5)
	floater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floater)

	await get_tree().process_frame
	var anchor: Vector2 = op_value_label.global_position - global_position
	floater.position = Vector2(
		anchor.x + (op_value_label.size.x - floater.size.x) * 0.5,
		anchor.y - 4.0
	)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(floater, "position:y", floater.position.y - 26.0, 0.8)
	tween.tween_property(floater, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(floater.queue_free)

# ──────────────────────────────────────────────────────────────────────────────
# ── Word Submission ──────────────────────────────────────────────────────────
func _on_clear_pressed() -> void:
	clear_button.disabled = true
	var placed_panels: Array = workbench_container.get_children()
	if not placed_panels.is_empty():
		await _animate_cards_discard(placed_panels)
	workbench_cards.clear()
	_refresh_ui()
	clear_button.disabled = false

# Identify a card by where it comes from: a shared slot reel or the player's hand.
func _source_key(card: Dictionary) -> String:
	if card.get("type", "") == "slot":
		return "slot:%d" % int(card.get("index", -1))
	return "hand:%d" % int(card.get("hand_index", -1))

# Pick the valid assignment that consumes the cards the player actually placed
# in the workbench (highest number of matching sources). Ties keep the earliest
# assignment, so the behaviour is unchanged when nothing matches.
func _pick_best_assignment(placed: Array, assignments: Array) -> Array:
	if assignments.is_empty():
		return []
	var best: Array = assignments[0]
	var best_score: int = -1
	for a in assignments:
		var score: int = 0
		for i in range(mini(placed.size(), a.size())):
			if _source_key(placed[i]) == _source_key(a[i]):
				score += 1
		if score > best_score:
			best_score = score
			best = a
	return best

func _on_submit_pressed() -> void:
	if workbench_cards.is_empty():
		message_label.text = "Workbench is empty! Place cards to form a word."
		message_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4, 1.0))
		return

	# Build pattern from current workbench cards
	var pattern_chars: Array = []
	for c in workbench_cards:
		var card_letter = c.get("card_letter", c.get("letter", "?"))
		pattern_chars.append(card_letter)
	var pattern: String = "".join(pattern_chars)

	# Find valid assignments for this pattern (handles wildcards)
	var valid_assignments: Array = GameManager.find_valid_assignments(pattern)
	if valid_assignments.is_empty():
		message_label.text = "X '%s' IS NOT VALID" % pattern.to_upper()
		message_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
		return

	# The Workbench order is player-chosen. OP moves may change the order, so
	# pick the valid assignment that preserves the cards' position and source
	# instead of rejecting a valid dictionary word with a rearranged Workbench.
	var final_workbench_cards: Array = _pick_best_assignment(workbench_cards, valid_assignments)
	var actual_chars: Array = []
	for a in final_workbench_cards:
		actual_chars.append(a["char"])
	var word: String = "".join(actual_chars)

	# Update workbench to show the actual matched word
	workbench_cards = final_workbench_cards
	_refresh_workbench_ui()

	# Check if assignment is valid
	if not GameManager.is_assignment_valid(word, final_workbench_cards):
		message_label.text = "X INVALID ORDER (Slots must be used in left-to-right order)"
		message_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
		# The Workbench was rewritten above, so bring the forecast back in sync
		_refresh_submit_preview()
		return

	submit_button.disabled = true
	clear_button.disabled = true

	var consumed_hand_panels: Array = []
	for source in final_workbench_cards:
		if source.get("type", "") == "hand":
			var hand_index: int = source.get("hand_index", -1)
			if hand_index >= 0 and hand_index < hand_card_views.size():
				consumed_hand_panels.append(hand_card_views[hand_index]["panel"])
	if not consumed_hand_panels.is_empty():
		await _animate_cards_discard(consumed_hand_panels)
	_animate_next_hand_refresh = true
	var result: Dictionary = GameManager.execute_assignment(word, final_workbench_cards)
	workbench_cards.clear()

	var finish_turn := func() -> void:
		# Apply the night self-damage before checking the turn limit.
		var penalty_result: Dictionary = GameManager.apply_turn_start_penalty()
		# Keep the resolved numbers so the FORMULAS panel can show the breakdown
		last_word = word
		last_result = result
		last_penalty = penalty_result
		_refresh_formula_panel()
		submit_button.disabled = false
		clear_button.disabled = false
		_finalize(result, penalty_result)

	if result.get("enemies_defeated_delta", 0) > 0:
		# Stage cleared: the hand AND all three shared reels were re-dealt.
		# Roll every reel so the shared cards (including the one that was just
		# used) visibly rotate out before the new enemy's cards appear.
		_refresh_hand_and_deck()
		animate_slot_rotations([0, 1, 2], finish_turn)
	else:
		# Show the refreshed hand immediately, before the rotation animation
		_refresh_hand_and_deck()
		animate_slot_rotations(result["used_slots"], finish_turn)

# ── Finalize confirmed word (step-by-step damage animation) ──────────────────
func _show_step_message(text: String, color: Color) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)

func _finalize(result: Dictionary, penalty_result: Dictionary) -> void:
	var word_damage: int = result["word_damage"]
	var final_damage: int = result["final_damage"]
	var multiplier: int = result.get("multiplier", 1)
	# RED trait: total enemy damage = base x RED multiplier. 1 red is the
	# exceptional x1.5; 2+ red use 2^(red-1). Applied exactly once.
	var group_damage: int = result.get("group_damage", int(round(word_damage * multiplier)))
	var red_bonus: int = result.get("red_bonus", group_damage - word_damage)

	# Enemy shown during this word (before any replacement spawned)
	var stage_before: int = GameManager.get_stage() - result.get("enemies_defeated_delta", 0)
	var name_before: String = result.get("enemy_name_before", GameManager.get_enemy_name())
	var disp_enemy_hp: int = result["enemy_hp_before"]
	var enemy_max_start: int = result["enemy_max_hp_before"]
	var disp_player_hp: int = result["player_hp_before"]
	var player_max: int = GameManager.get_max_player_hp()

	var total_dealt: int = 0
	var total_taken: int = 0

	# ── Step 1: Base word damage ──
	# AEGIS soaks the hit before the enemy loses any HP, so the two on-screen
	# chunks (base then RED bonus) are scaled down by whatever the shield ate.
	# With no shield this is exactly 1.0 and nothing changes.
	var enemy_shield_absorbed: int = result.get("enemy_shield_absorbed", 0)
	var base_dmg_shown: int = word_damage
	var red_dmg_shown: int = red_bonus
	if final_damage > 0 and enemy_shield_absorbed > 0:
		var hp_damage: int = maxi(final_damage - enemy_shield_absorbed, 0)
		var scale_factor: float = float(hp_damage) / float(maxi(final_damage, 1))
		base_dmg_shown = int(round(float(maxi(word_damage, 0)) * scale_factor))
		red_dmg_shown = maxi(hp_damage - base_dmg_shown, 0)

	if word_damage > 0:
		total_dealt += base_dmg_shown
		var target: int = maxi(disp_enemy_hp - base_dmg_shown, 0)
		_play_score_up_sound()
		_animate_enemy_hit()
		var shield_note: String = (
			"   ENEMY SHIELD absorbed %d first" % enemy_shield_absorbed) if enemy_shield_absorbed > 0 else ""
		_show_step_message("OK %s !   Enemy HP -%d%s" % [
			result["message"].replace("VALID: ", ""),
			base_dmg_shown,
			shield_note
		], Color(0.4, 1.0, 0.6, 1.0))
		_animate_enemy_hp(stage_before, name_before, disp_enemy_hp, target, enemy_max_start, 0.5)
		disp_enemy_hp = target
		await get_tree().create_timer(0.9).timeout
	elif word_damage < 0:
		var absorbed: int = result.get("self_damage_absorbed", 0)
		var self_damage: int = result.get("self_damage_taken", -word_damage)
		total_taken += self_damage
		var target: int = maxi(disp_player_hp - self_damage, 0)
		_play_score_down_sound()
		_animate_player_hit()
		var absorb_text: String = (" (shield blocked %d)" % absorbed) if absorbed > 0 else ""
		_show_step_message("X %s !   You take %d damage%s" % [
			result["message"].replace("VALID: ", ""),
			self_damage,
			absorb_text
		], Color(1.0, 0.4, 0.4, 1.0))
		_animate_player_hp(disp_player_hp, target, player_max, 0.5)
		disp_player_hp = target
		await get_tree().create_timer(0.9).timeout
	else:
		_show_step_message("OK %s !" % result["message"].replace("VALID: ", ""), Color(0.4, 1.0, 0.6, 1.0))

	# ── Step 2: RED synergy (the only red damage bonus) ──
	# Total enemy damage for the word = base x 2^(red cards - 1); the extra
	# damage over the base word value is shown here as a single bonus.
	if red_bonus > 0:
		total_dealt += red_dmg_shown
		var from_enemy_hp: int = disp_enemy_hp
		var target: int = maxi(disp_enemy_hp - red_dmg_shown, 0)
		_play_score_up_sound()
		_animate_enemy_hit()
		_show_step_message("RED bonus x%s: +%d damage to enemy" % [String.num(multiplier, 2), red_dmg_shown], Color(1.0, 0.5, 0.4, 1.0))
		_animate_enemy_hp(stage_before, name_before, from_enemy_hp, target, enemy_max_start, 0.5)
		disp_enemy_hp = target
		await get_tree().create_timer(0.9).timeout

	# ── Step 2b: (reserved) ──
	# The enemy skill used to fire here, on submit. It no longer does: the skill
	# is a CARD that answers at NIGHT while it sits in a reel's bottom row, so it
	# is narrated in Step 5 with the rest of the night resolution.

	# ── Step 3: BLUE shield, GREEN heal & YELLOW operation points ──
	# All three traits scale off the base total with the same stacking multiplier
	var shield_gained: int = result.get("shield_gained", 0)
	var shield_mult: int = result.get("shield_mult", 0)
	var heal_amount: int = result.get("heal_amount", 0)
	var heal_mult: int = result.get("heal_mult", 0)
	var op_gained: int = result.get("operation_points_gained", 0)
	var op_mult: int = result.get("yellow_mult", 0)
	if shield_gained > 0 or heal_amount > 0 or op_gained > 0:
		var trait_parts: Array = []
		if shield_gained > 0:
			trait_parts.append("BLUE +%d SHIELD (base %d x%d)" % [shield_gained, word_damage, shield_mult])
		if heal_amount > 0:
			trait_parts.append("GREEN +%d HP (base %d x%d)" % [heal_amount, word_damage, heal_mult])
		if op_gained > 0:
			trait_parts.append("YELLOW +%d OP (base %d x%d)  ->  %d owned" % [
				op_gained, word_damage, op_mult,
				result.get("operation_points_after", GameManager.get_operation_points())
			])
		var traits_color: Color = Color(0.4, 0.7, 1.0, 1.0)
		if op_gained > 0 and shield_gained == 0 and heal_amount == 0:
			traits_color = Color(1.0, 0.9, 0.35, 1.0) # Yellow
		elif heal_amount > 0 and shield_gained == 0:
			traits_color = Color(0.55, 0.95, 0.7, 1.0)
		_show_step_message(" / ".join(trait_parts), traits_color)
		if op_gained > 0:
			# Point the player at the gauge and pop it, so the gain is unmissable
			_refresh_op_display("gain")
		if heal_amount > 0:
			_play_score_up_sound()
			_animate_player_hp(disp_player_hp, disp_player_hp + heal_amount, player_max, 0.5)
			disp_player_hp += heal_amount
		await get_tree().create_timer(0.9).timeout

	# ── Step 4: Stage clear (next stage starts, hand reset) ──
	if result.get("enemies_defeated_delta", 0) > 0:
		_play_score_up_sound()
		# Spell the cleanup out loud: everything the fallen enemy granted went
		# with it. The "before" numbers come from the result, because the wipe
		# already happened inside GameManager by the time we get here.
		var wiped: Array = []
		if int(result.get("enemy_shield_before", 0)) > 0:
			wiped.append("its %d shield" % int(result.get("enemy_shield_before", 0)))
		if int(result.get("enemy_skill_night_tax", 0)) > 0:
			wiped.append("its +%d night tax" % int(result.get("enemy_skill_night_tax", 0)))
		if int(result.get("hand_limit_before", GameManager.HAND_SIZE)) < GameManager.HAND_SIZE:
			wiped.append("its hand limit of %d" % int(result.get("hand_limit_before", 0)))
		var wipe_text: String = ("   — %s all gone with it." % ", ".join(wiped)) if not wiped.is_empty() else ""
		_show_step_message("STAGE CLEAR! → STAGE %d — %s appears! Hand redrawn, reels rolled.%s" % [
			GameManager.get_stage(), GameManager.get_enemy_name().to_upper(), wipe_text],
			Color(1.0, 0.85, 0.3, 1.0))
		await get_tree().create_timer(1.2).timeout

	# ── Step 5: Night self-damage (negative damage hurts the player) ──
	var applied_damage: int = penalty_result.get("applied_damage", 0)
	var night_blocked: int = penalty_result.get("absorbed", 0)
	var stage_cleared: bool = penalty_result.get("stage_cleared", false)
	if applied_damage > 0:
		total_taken += applied_damage
		_play_score_down_sound()
		_animate_player_hit()
		var block_text: String = (" (shield blocked %d)" % night_blocked) if night_blocked > 0 else ""
		_show_step_message("NIGHT: You take %d damage%s!" % [applied_damage, block_text], Color(1.0, 0.4, 0.4, 1.0))
		_animate_player_hp(penalty_result["previous_player_hp"], penalty_result["player_hp"], player_max, 0.5)
		await get_tree().create_timer(0.9).timeout
	elif night_blocked > 0:
		_play_score_up_sound()
		_show_step_message("NIGHT: SHIELD blocked %d damage!" % night_blocked, Color(0.4, 0.7, 1.0, 1.0))
		await get_tree().create_timer(0.9).timeout
	elif stage_cleared:
		# Defeating the enemy ends the fight, so the turn costs nothing.
		_play_score_up_sound()
		_show_step_message("NIGHT: no damage — the enemy was defeated this turn!", Color(0.4, 1.0, 0.6, 1.0))
		await get_tree().create_timer(0.9).timeout

	# ── Step 5b: the enemy skill card answers ──
	# It fires when its card was in a reel's BOTTOM row as night resolved. The
	# log was built by GameManager, so the UI never re-derives the numbers. An
	# empty log is correct when the card was rolled out of the firing line, or
	# when the enemy died before it could answer.
	var night_skill_log: Array = penalty_result.get("skill_log", [])
	if not night_skill_log.is_empty():
		_play_score_down_sound()
		_animate_enemy_hit()
		_animate_player_hit()
		for line in night_skill_log:
			_show_step_message("ENEMY SKILL — %s" % str(line), ENEMY_SKILL_COLOR)
			await get_tree().create_timer(0.75).timeout
		# AEGIS / REGROWTH change the enemy, so let the board catch up with what
		# GameManager already applied.
		_refresh_ui()

	_refresh_ui()

	# ── Final summary ──
	if total_dealt > 0 or total_taken > 0:
		var summary: String = "Total → Dealt: %d  |  Taken: %d" % [total_dealt, total_taken]
		# Show the formula that produced this turn's enemy damage (FORMULAS panel has the details)
		if word_damage > 0 and multiplier > 1.0:
			summary += "   [%d x %s = %d]" % [word_damage, String.num(multiplier, 2), final_damage]
		_show_step_message(summary,
			Color(0.4, 1.0, 0.6, 1.0) if total_dealt >= total_taken else Color(1.0, 0.4, 0.4, 1.0))

	# ── Reward choice: offered after every enemy defeat ──
	# Placed after the night damage so the player is not interrupted mid-hit,
	# and skipped on a defeat or on the final turn (there would be no next fight).
	var cleared_enemy: bool = result.get("enemies_defeated_delta", 0) > 0
	var turn_limit_reached: bool = GameManager.get_turn() >= GameManager.MAX_TURNS
	var player_defeated: bool = GameManager.is_game_over() and GameManager.get_game_outcome() == "DEFEAT"
	if cleared_enemy and not turn_limit_reached and not player_defeated:
		_show_step_message("Enemy defeated! Choose your reward.", Color(1.0, 0.88, 0.45, 1.0))
		show_reward_choice()
	else:
		# No reward is coming, so the stage hand is drawn right away instead of
		# being left owed forever.
		GameManager.flush_pending_hand_redraw()
		_refresh_ui()

	# Defeat takes priority over the turn limit
	if GameManager.is_game_over() and GameManager.get_game_outcome() == "DEFEAT":
		reward_dialog.visible = false
		burn_dialog.visible = false
		_show_game_over()
		return

	if GameManager.get_turn() >= GameManager.MAX_TURNS:
		GameManager.game_over = true
		GameManager.game_outcome = "COMPLETE"
		_show_game_over()
		reward_dialog.visible = false
		burn_dialog.visible = false

# ── Reward choice (three options after every enemy defeat) ───────────────────
# Buttons are built in code so the option count and wording always match the
# rewards GameManager actually rolled.
func _style_reward_panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.13, 0.19, 1.0)
	sb.border_color = Color(0.98, 0.80, 0.22, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0.0, 0.0, 0.04, 0.72)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 7)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	reward_panel.add_theme_stylebox_override("panel", sb)
	reward_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))


## Shows the reward dialog with the options GameManager rolled. Blocks until the
## player picks one, then applies it and refreshes the UI.
## If a reward is already pending (we are coming back from the BURN A CARD
## picker), the SAME options are re-shown instead of being rolled again, so
## backing out of the deck picker never changes the deal on offer.
func show_reward_choice() -> void:
	var options: Array = GameManager.get_pending_reward_options()
	if options.is_empty():
		options = GameManager.roll_rewards()
	if options.is_empty():
		return
	reward_subtitle_label.text = "Pick one.  Deck size: %d" % GameManager.get_deck_size()
	for child in reward_row.get_children():
		child.queue_free()

	for i in range(options.size()):
		var reward: Dictionary = options[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 268)
		button.text = ""
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_reward_button(button)
		# Clicking passes its own index, so the handler is bound per button.
		button.pressed.connect(_on_reward_chosen.bind(i))
		reward_row.add_child(button)
		_style_reward_button_content(button, reward)

	reward_dialog.visible = true
	# Focus the first option so the dialog is keyboard-usable too.
	if reward_row.get_child_count() > 0:
		(reward_row.get_child(0) as Button).grab_focus()


## Paints the title / body text inside a reward button. Godot 4 Buttons do not
## render BBCode, so the label colours come from the theme, not markup.
## Deck rewards show the ACTUAL card that will be gained or burned, drawn with
## the same colour language as the cards on the table, so the player can weigh
## "take this card" against "thin the deck".
func _style_reward_button_content(button: Button, reward: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12.0
	box.offset_top = 12.0
	box.offset_right = -12.0
	box.offset_bottom = -12.0
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)

	var type: String = str(reward.get("type", ""))

	var title := Label.new()
	title.text = str(reward.get("title", "?"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", REWARD_COLOR_TITLE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	if reward.has("card"):
		box.add_child(_build_reward_card_view(reward.get("card", {}), type == "remove_card"))
	else:
		var icon := Label.new()
		icon.text = _reward_icon(type)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 30)
		icon.add_theme_color_override("font_color", REWARD_COLOR_ICON)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)

	var detail := Label.new()
	detail.text = str(reward.get("detail", ""))
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", REWARD_COLOR_DETAIL)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(detail)


## A miniature version of a game card: letter, damage, and the card's own colour.
## Burned cards are tinted red and struck through so the two deck rewards never
## look alike at a glance.
func _build_reward_card_view(card: Dictionary, is_burn: bool) -> Control:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(104, 128)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	var color_name: String = str(card.get("color", "red"))
	var consts: Dictionary = get_card_color_constants(color_name)
	sb.bg_color = consts["bg"]
	sb.border_color = consts["border"]
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var letter := Label.new()
	letter.text = str(card.get("letter", "?"))
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.add_theme_font_size_override("font_size", 46)
	letter.add_theme_color_override("font_color", consts["border"])
	letter.add_theme_color_override("font_outline_color", Color("080d17"))
	letter.add_theme_constant_override("outline_size", 2)
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(letter)

	var dmg := Label.new()
	dmg.text = "%d dmg" % int(card.get("damage", 0))
	dmg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg.add_theme_font_size_override("font_size", 14)
	dmg.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1.0))
	dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(dmg)

	if GameManager.has_special_ability(card):
		var sp_cost_lbl := Label.new()
		sp_cost_lbl.text = "★ %d OP" % GameManager.get_special_cost(card)
		sp_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sp_cost_lbl.add_theme_font_size_override("font_size", 12)
		sp_cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		sp_cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(sp_cost_lbl)

	if is_burn:
		# Strike the card through so "burn this" is unmistakable
		var strike := ColorRect.new()
		strike.color = Color(1.0, 0.35, 0.3, 0.95)
		strike.set_anchors_preset(Control.PRESET_CENTER)
		strike.anchor_left = 0.0
		strike.anchor_right = 1.0
		strike.anchor_top = 0.42
		strike.anchor_bottom = 0.5
		strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(strike)
	return center


func _reward_icon(type: String) -> String:
	match type:
		"add_card":    return "+"
		"remove_card": return "PICK"
		"heal":        return "HP"
		"shield":      return "SH"
		"op":          return "OP"
		"max_hp":      return "MAX"
		"draw":        return "DR"
		"wildcards":   return "???"
	return "?"


func _style_reward_button(button: Button) -> void:
	var normal := _make_button_style(Color("2a2233"), Color("f0cf7e"))
	var hover := _make_button_style(Color("3a2f47"), Color("ffe6a8"))
	hover.shadow_size = 12
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", _make_button_style(Color("1f1a28"), Color("d8b45f")))
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color.WHITE)


## Applies the chosen reward, closes the dialog and reports the result.
## "BURN A CARD" is two-step: this opens the card picker instead of resolving
## immediately, and _on_burn_card_picked() finishes the reward.
func _on_reward_chosen(index: int) -> void:
	var result: Dictionary = GameManager.choose_reward(index)
	if not result.get("ok", false):
		reward_dialog.visible = false
		_refresh_ui()
		return
	if bool(result.get("needs_card", false)):
		# Hide the three options and show the deck picker on top
		reward_dialog.visible = false
		_open_burn_picker()
		return
	reward_dialog.visible = false
	# The reward is settled, so the stage hand is finally drawn. For BURN A CARD
	# this is deferred to _on_burn_card_picked(), which owns the second step.
	GameManager.flush_pending_hand_redraw()
	_play_score_up_sound()
	_refresh_ui()
	_refresh_formula_panel()
	_show_step_message("REWARD: %s" % str(result.get("message", "")), Color(1.0, 0.88, 0.45, 1.0))


# ── Deck-trimming picker ─────────────────────────────────────────────────────
# Shows every card that can be removed (draw pile + hand) and removes the one
# the player clicks, giving them full control over which card leaves the deck.
func _style_burn_panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.13, 0.19, 1.0)
	sb.border_color = Color(0.95, 0.45, 0.40, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0.0, 0.0, 0.04, 0.72)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 7)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	burn_panel.add_theme_stylebox_override("panel", sb)
	$BurnDialog/DialogPanel/DialogVBox/Title.add_theme_color_override(
		"font_color", Color(1.0, 0.72, 0.65, 1.0))
	_style_button(burn_cancel_button, Color("3a2230"), Color("e08a80"), Color("ffecea"))


func _open_burn_picker() -> void:
	for child in burn_grid.get_children():
		child.queue_free()

	var candidates: Array = GameManager.get_burnable_cards()
	var by_source: Dictionary = {}
	for entry: Dictionary in candidates:
		var src: String = str(entry.get("source", ""))
		by_source[src] = int(by_source.get(src, 0)) + 1
	burn_subtitle_label.text = "Your whole deck — %s.  Click one to burn it." % ", ".join([
		"%d deck" % int(by_source.get("deck", 0)),
		"%d hand" % int(by_source.get("hand", 0)),
		"%d spent" % int(by_source.get("grave", 0)),
	])
	for entry: Dictionary in candidates:
		burn_grid.add_child(_build_burn_card_button(entry))

	burn_dialog.visible = true
	if burn_grid.get_child_count() > 0:
		(burn_grid.get_child(0) as Button).grab_focus()


## One clickable card in the picker, drawn in the card's own colour so it reads
## the same as the cards on the table.
func _build_burn_card_button(entry: Dictionary) -> Button:
	var card: Dictionary = entry.get("card", {})
	var card_id: String = str(entry.get("id", ""))
	var is_special: bool = GameManager.has_special_ability(card)
	var button := Button.new()
	# A special needs two extra lines (its name and its price), so the cell grows.
	button.custom_minimum_size = Vector2(78, 148 if is_special else 114)
	_style_burn_card_button(button, str(card.get("color", "red")))
	button.pressed.connect(_on_burn_card_picked.bind(card_id))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4.0
	vbox.offset_top = 6.0
	vbox.offset_right = -4.0
	vbox.offset_bottom = -6.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(vbox)

	var consts: Dictionary = get_card_color_constants(str(card.get("color", "red")))
	var letter := Label.new()
	letter.text = str(card.get("letter", "?"))
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.add_theme_font_size_override("font_size", 30)
	letter.add_theme_color_override("font_color", consts["border"])
	letter.add_theme_color_override("font_outline_color", Color("080d17"))
	letter.add_theme_constant_override("outline_size", 2)
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(letter)

	var special_cost: int = GameManager.get_special_cost(card)
	var dmg := Label.new()
	# Match the hand-card wording so a special reads the same way everywhere.
	if is_special:
		dmg.text = "%d dmg ★ %d OP" % [int(card.get("damage", 0)), special_cost]
		dmg.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	else:
		dmg.text = "%d dmg" % int(card.get("damage", 0))
		dmg.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1.0))
	dmg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg.add_theme_font_size_override("font_size", 12)
	dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(dmg)

	# Burning a special silently throws its whole power away, so the NAME of that
	# power is spelled out on the card instead of being left to memory.
	if is_special:
		var s_name := Label.new()
		s_name.text = "★ %s" % GameManager.get_special_name(card)
		s_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_name.clip_text = true
		s_name.add_theme_font_size_override("font_size", 10)
		s_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		s_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(s_name)

		# The cell is far too small for the full text, so the description goes in
		# the tooltip — which matters most here, where the card is about to be lost.
		button.tooltip_text = "★ %s (%d OP): %s\nBurn this card and the ability is gone for good." % [
			GameManager.get_special_name(card), special_cost,
			GameManager.get_special_desc(card)]

	# Tag which pile the card came from. Identical letters appear several times
	# in a deck, so this is what tells the player whether they are burning a card
	# still in the draw pile, one they are holding, or one already spent.
	var src_label := Label.new()
	src_label.text = _burn_source_tag(str(entry.get("source", "")))
	src_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	src_label.add_theme_font_size_override("font_size", 9)
	src_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.80, 1.0))
	src_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(src_label)
	return button


## Short badge naming the pile a burnable card is sitting in.
func _burn_source_tag(source: String) -> String:
	match source:
		"deck":  return "in deck"
		"hand":  return "in hand"
		"grave": return "spent"
	return ""


func _style_burn_card_button(button: Button, color_name: String) -> void:
	var consts: Dictionary = get_card_color_constants(color_name)
	var normal := _make_button_style(consts["bg"], consts["border"])
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _make_button_style(consts["bg"].lightened(0.18), consts["border"]))
	button.add_theme_stylebox_override("pressed", _make_button_style(consts["bg"].darkened(0.2), consts["border"]))
	button.add_theme_stylebox_override("focus", _make_button_style(consts["bg"].lightened(0.12), consts["border"]))


## Removes the clicked card and finishes the reward.
func _on_burn_card_picked(card_id: String) -> void:
	var result: Dictionary = GameManager.confirm_burn_card(card_id)
	burn_dialog.visible = false
	if not result.get("ok", false):
		# The card vanished under us; the reward is still pending, so re-offer it
		_show_step_message("That card is no longer there. Pick again.", Color(1.0, 0.7, 0.6, 1.0))
		_refresh_ui()
		show_reward_choice()
		return
	# The reward is settled, so the stage hand is finally drawn.
	GameManager.flush_pending_hand_redraw()
	_play_score_up_sound()
	_refresh_ui()
	_refresh_formula_panel()
	_show_step_message("REWARD: %s" % str(result.get("message", "")), Color(1.0, 0.88, 0.45, 1.0))


## Backs out of the picker without spending the reward.
func _on_burn_cancel_pressed() -> void:
	GameManager.cancel_burn_card()
	burn_dialog.visible = false
	show_reward_choice()


# ──────────────────────────────────────────────────────────────────────────────
# ── Game Over Screen ─────────────────────────────────────────────────────────
func _show_game_over() -> void:
	slot_container.visible   = false
	hand_container.visible   = false
	deck_grave_label.visible = false
	workbench_panel.visible  = false
	clear_button.visible     = false
	submit_button.visible    = false
	$Scroll/Center/VBox/SlotsSectionLabel.visible     = false
	$Scroll/Center/VBox/HandSectionLabel.visible      = false
	$Scroll/Center/VBox/WorkbenchSectionLabel.visible = false
	stats_label.visible                               = false
	op_panel.visible                                   = false
	preview_label.visible                              = false
	meaning_label.visible                              = false
	definition_label.visible                           = false
	burn_dialog.visible                               = false

	var outcome: String = GameManager.get_game_outcome()
	var title: String = "GAME OVER"
	var title_color: Color = BORDER_CURRENT
	if outcome == "DEFEAT":
		title = "DEFEAT"
		title_color = Color(1.0, 0.35, 0.3, 1.0)
	elif outcome == "COMPLETE":
		title = "COMPLETE!"
		title_color = Color(0.4, 1.0, 0.6, 1.0)

	message_label.text = "%s\n\nStage Reached: %d\nTotal Damage: %d\nEnemies Defeated: %d\nOperation Points: %d\nPlayer HP: %d / %d" % [
		title,
		GameManager.get_stage(),
		GameManager.get_total_damage(),
		GameManager.get_enemies_defeated(),
		GameManager.get_operation_points(),
		GameManager.get_player_hp(),
		GameManager.get_max_player_hp()
	]
	message_label.add_theme_font_size_override("font_size", 32)
	message_label.add_theme_color_override("font_color", title_color)
	message_label.custom_minimum_size = Vector2(400, 240)
