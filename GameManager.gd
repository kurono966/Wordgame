extends Node

# GameManager singleton  Ehandles game state and logic

const NUM_SLOTS: int = 3
const CARDS_PER_SLOT: int = 3
const HAND_SIZE: int = 7
const DECK_SIZE: int = 20   # Cards picked at random from the pool for each game
const MAX_TURNS: int = 10

# ── Enemy name settings ──
const ALPHA: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const NAME_MIN_LEN: int = 3
const NAME_MAX_LEN: int = 9      # <=9 so the whole name fits into the9 shared cards
const FALLBACK_ENEMY_NAMES: Array = ["DRAGON", "SLIME", "GOLEM", "WRAITH", "TROLL", "OGRE", "BANSHEE"]

# ── Color traits (triggered by the cards used in a valid word) ──
# Every trait scales off the BASE TOTAL (the sum of the damage of all cards
# used in the word) with the same stacking multiplier 2^(count - 1):
#   RED   -> damage dealt to the enemy = round(base x RED_MULT)
#            RED_MULT is exceptional: 0 red = x1, 1 red = x1.5,
#            2 red = x2, 3 = x4, 4 = x8 (2^(red - 1) for 2+)
#   BLUE  -> shield gained             = base x 2^(blue  - 1)   (no cap)
#   GREEN -> HP healed                 = base x 2^(green - 1)   (capped at max HP)
#   YELLOW -> operation points gained  = base x 2^(yellow - 1)  (accumulates,
#            and is the currency spent on Workbench moves and SPECIAL activations)
# Reference: 1 card = x1, 2 cards = x2, 3 = x4, 4 = x8 (0 cards = no trait,
# except RED which is x1.5 for exactly 1 card)

# ── HP & Damage settings ──
const PLAYER_MAX_HP: int = 50     # Player's maximum HP
const ENEMY_BASE_HP: int = 30     # HP of the first enemy
const ENEMY_HP_GROWTH: int = 15   # Max HP increase for each next enemy

# ── Card cost & special ability settings ──
# A card's DAMAGE NUMBER IS ALSO ITS COST: the printed damage value is the OP
# price paid to activate that card's special ability (8-damage card = 8 OP,
# 10-damage card = 10 OP).
const SPECIAL_MIN_DAMAGE: int = 8 # Cards of this damage or more carry a special

# CARD POOL: master definitions of every card type (A-Z, damage scaled by
# difficulty). Colors: red, blue, green, yellow.
# Pool total: 99 entries (90 letter cards + 9 wildcards).
# NOTE: the deck used during a game is separate — DECK_SIZE cards are picked
# at random from this pool in reset_game().
const CARD_DEFS: Array = [
	# ── 1 Damage: Common Vowels & Consonants (E, A, I, O, N, R, T, L, S, U) ──
	{"letter": "E", "damage": 1, "color": "red"}, {"letter": "E", "damage": 1, "color": "blue"}, {"letter": "E", "damage": 1, "color": "green"},
	{"letter": "E", "damage": 1, "color": "yellow"}, {"letter": "E", "damage": 1, "color": "red"}, {"letter": "E", "damage": 1, "color": "blue"},
	{"letter": "E", "damage": 1, "color": "green"}, {"letter": "E", "damage": 1, "color": "yellow"},
	{"letter": "A", "damage": 1, "color": "green"}, {"letter": "A", "damage": 1, "color": "yellow"}, {"letter": "A", "damage": 1, "color": "red"}, {"letter": "A", "damage": 1, "color": "blue"},
	{"letter": "A", "damage": 1, "color": "green"}, {"letter": "A", "damage": 1, "color": "yellow"},
	{"letter": "I", "damage": 1, "color": "green"}, {"letter": "I", "damage": 1, "color": "yellow"}, {"letter": "I", "damage": 1, "color": "red"}, {"letter": "I", "damage": 1, "color": "blue"},
	{"letter": "I", "damage": 1, "color": "green"},
	{"letter": "O", "damage": 1, "color": "green"}, {"letter": "O", "damage": 1, "color": "yellow"}, {"letter": "O", "damage": 1, "color": "red"}, {"letter": "O", "damage": 1, "color": "blue"},
	{"letter": "O", "damage": 1, "color": "green"},
	{"letter": "U", "damage": 1, "color": "green"}, {"letter": "U", "damage": 1, "color": "yellow"}, {"letter": "U", "damage": 1, "color": "red"}, {"letter": "U", "damage": 1, "color": "blue"},
	{"letter": "N", "damage": 1, "color": "green"}, {"letter": "N", "damage": 1, "color": "yellow"}, {"letter": "N", "damage": 1, "color": "red"},
	{"letter": "N", "damage": 1, "color": "blue"},
	{"letter": "R", "damage": 1, "color": "blue"}, {"letter": "R", "damage": 1, "color": "green"}, {"letter": "R", "damage": 1, "color": "yellow"},
	{"letter": "R", "damage": 1, "color": "blue"},
	{"letter": "T", "damage": 1, "color": "red"}, {"letter": "T", "damage": 1, "color": "blue"}, {"letter": "T", "damage": 1, "color": "green"}, {"letter": "T", "damage": 1, "color": "yellow"},
	{"letter": "T", "damage": 1, "color": "red"},
	{"letter": "L", "damage": 1, "color": "red"}, {"letter": "L", "damage": 1, "color": "blue"}, {"letter": "L", "damage": 1, "color": "green"},
	{"letter": "L", "damage": 1, "color": "blue"},
	{"letter": "S", "damage": 1, "color": "yellow"}, {"letter": "S", "damage": 1, "color": "red"}, {"letter": "S", "damage": 1, "color": "blue"},
	{"letter": "S", "damage": 1, "color": "yellow"}, {"letter": "S", "damage": 1, "color": "red"},

	# ── 2 Damage: Easy Consonants (D, G) ──
	{"letter": "D", "damage": 2, "color": "blue"}, {"letter": "D", "damage": 2, "color": "green"}, {"letter": "D", "damage": 2, "color": "yellow"},
	{"letter": "D", "damage": 2, "color": "blue"},
	{"letter": "G", "damage": 2, "color": "red"}, {"letter": "G", "damage": 2, "color": "blue"},
	{"letter": "G", "damage": 2, "color": "green"},

	# ── 3 Damage: Medium Consonants (B, C, M, P) ──
	{"letter": "B", "damage": 3, "color": "green"}, {"letter": "B", "damage": 3, "color": "yellow"},
	{"letter": "C", "damage": 3, "color": "red"}, {"letter": "C", "damage": 3, "color": "blue"},
	{"letter": "C", "damage": 3, "color": "green"}, {"letter": "C", "damage": 3, "color": "yellow"},
	{"letter": "M", "damage": 3, "color": "green"}, {"letter": "M", "damage": 3, "color": "yellow"},
	{"letter": "M", "damage": 3, "color": "red"},
	{"letter": "P", "damage": 3, "color": "red"}, {"letter": "P", "damage": 3, "color": "blue"},
	{"letter": "P", "damage": 3, "color": "green"},

	# ── 4 Damage: Semi-Difficult (F, H, V, W, Y) ──
	{"letter": "F", "damage": 4, "color": "green"}, {"letter": "F", "damage": 4, "color": "yellow"},
	{"letter": "H", "damage": 4, "color": "red"}, {"letter": "H", "damage": 4, "color": "blue"},
	{"letter": "H", "damage": 4, "color": "green"}, {"letter": "H", "damage": 4, "color": "yellow"},
	{"letter": "V", "damage": 4, "color": "green"}, {"letter": "V", "damage": 4, "color": "yellow"},
	{"letter": "W", "damage": 4, "color": "red"}, {"letter": "W", "damage": 4, "color": "blue"},
	{"letter": "Y", "damage": 4, "color": "green"}, {"letter": "Y", "damage": 4, "color": "yellow"},
	{"letter": "Y", "damage": 4, "color": "red"},

	# ── 5 Damage: Difficult (K) ──
	{"letter": "K", "damage": 5, "color": "red"}, {"letter": "K", "damage": 5, "color": "blue"},
	{"letter": "K", "damage": 5, "color": "green"},

	# ── 8 Damage: Very Difficult (J, X) ──
	{"letter": "J", "damage": 8, "color": "green"},
	{"letter": "J", "damage": 8, "color": "yellow"},
	{"letter": "X", "damage": 8, "color": "yellow"},

	# ── 10 Damage: Extreme (Q, Z) ──
	{"letter": "Q", "damage": 10, "color": "red"},
	{"letter": "Z", "damage": 10, "color": "blue"},

	# ── Wildcard (0 damage, can be any letter, has a color for multiplier matching) ──
	{"letter": "?", "damage": 0, "color": "red"},
	{"letter": "?", "damage": 0, "color": "blue"},
	{"letter": "?", "damage": 0, "color": "green"},
	{"letter": "?", "damage": 0, "color": "yellow"},
	{"letter": "?", "damage": 0, "color": "red"},
	{"letter": "?", "damage": 0, "color": "blue"},
	{"letter": "?", "damage": 0, "color": "green"},
	{"letter": "?", "damage": 0, "color": "yellow"},
	{"letter": "?", "damage": 0, "color": "red"}
]

var deck: Array = []        # Draw pile: DECK_SIZE cards randomly chosen from CARD_DEFS (the pool)
var graveyard: Array = []   # Discarded / spent cards
var slots: Array = []       # 3 slots, each an Array of 3 cards
var current_slot_indices: Array = [0, 0, 0] # Index of currently displayed card per slot
var hand: Array = []        # 7 cards (or null if empty)
var player_hp: int = PLAYER_MAX_HP     # Player HP (negative damage / night self-damage reduces it)
var shield: int = 0                    # BLUE shield: absorbs incoming damage before HP
var enemy_hp: int = ENEMY_BASE_HP      # Current enemy HP (positive damage reduces it)
var enemy_max_hp: int = ENEMY_BASE_HP  # Current enemy's max HP
var enemies_defeated: int = 0          # Enemies defeated so far
var stage: int = 1                     # Current stage (advances when an enemy is defeated)
var enemy_name: String = ""            # Current enemy's name (random word from the dictionary)
var total_damage: int = 0              # Total damage dealt to enemies (evaluation)
var turn: int = 0
var is_night: bool = false  # Phase: false = Day, true = Night
var game_over: bool = false
var game_outcome: String = ""  # "DEFEAT" when HP hits 0, "COMPLETE" at the turn limit
var dictionary: Dictionary = {}
var word_list: Array = []   # Candidate enemy names (A-Z only, NAME_MIN_LEN..NAME_MAX_LEN)
var operation_points: int = 0      # YELLOW trait: currency for Workbench card moves and special activations

# ── Rewards (chosen after every enemy defeat) ────────────────────────────────
# Three options are offered each time an enemy is defeated; the player picks
# one. "add_card" appends a card to the deck, "remove_card" burns one away, and
# the stat options change the player directly.
var reward_options: Array = []     # 3 reward dictionaries, empty when none pending
var rewards_taken: int = 0         # How many rewards the player has claimed
var pending_reward_choice: bool = false  # True while a choice is on screen
# Index into reward_options while the player is picking WHICH card to burn.
# -1 means no pick is in progress.
var pending_burn_index: int = -1

# Deck size limits, so "add card" / "remove card" can never break the draw loop.
const MIN_DECK_SIZE: int = 5
const MAX_DECK_SIZE: int = 40


# ─── Rewards ─────────────────────────────────────────────────────────────────
## Builds 3 distinct reward options for the player to choose from.
## Always offers at least one deck change (add or remove) plus stat options,
## so the deck is something the player actually shapes between fights.
func roll_rewards() -> Array:
	reward_options = []
	pending_reward_choice = true
	_build_deck_rewards()
	_build_stat_rewards()
	# Shuffle so the order differs each time, but keep it stable for the UI.
	reward_options.shuffle()
	return reward_options


## Adds one "gain this card" and one "burn a card" option when the deck size
## allows. The card you GAIN is rolled up front and shown face-up. The card you
## BURN is chosen by the player from their own deck, so nothing is decided for
## them: the trade is "take this card" vs "thin the deck how you like".
func _build_deck_rewards() -> void:
	if deck.size() < MAX_DECK_SIZE:
		reward_options.append({"type": "add_card", "title": "ADD A CARD",
			"detail": "Add this card to your deck.",
			"card": _pick_reward_card()})
	if deck.size() > MIN_DECK_SIZE:
		# No card is chosen here: the player picks one from the burn list.
		reward_options.append({"type": "remove_card", "title": "BURN A CARD",
			"detail": "Choose a card from your deck to remove."})


## Lists every card the player may burn, as stable pick entries.
## Includes the draw pile and the hand, so a card already in hand can be
## discarded too. Each entry carries the source and index so the UI can hand
## back a precise reference instead of guessing from letter/damage.
func get_burnable_cards() -> Array:
	var out: Array = []
	for i in range(deck.size()):
		out.append({"id": "deck:%d" % i, "source": "deck", "index": i,
			"card": deck[i].duplicate()})
	for i in range(hand.size()):
		if hand[i] != null:
			out.append({"id": "hand:%d" % i, "source": "hand", "index": i,
				"card": hand[i].duplicate()})
	# The graveyard is shuffled back into the deck when it runs dry, so burning a
	# card from there would not actually shrink the deck. Those are not offered.
	return out


## Finishes a "burn a card" reward by removing the card the player picked.
## `card_id` is one of the ids from get_burnable_cards(). Leaves the reward
## pending if the id is unknown, so a mis-click cannot consume the reward.
func confirm_burn_card(card_id: String) -> Dictionary:
	if not pending_reward_choice or pending_burn_index < 0:
		return {"ok": false, "reason": "no burn in progress"}
	var parts: PackedStringArray = card_id.split(":")
	if parts.size() != 2:
		return {"ok": false, "reason": "bad card id"}
	var source: String = parts[0]
	var idx: int = int(parts[1])

	var burned: Dictionary = {}
	if source == "deck":
		if idx < 0 or idx >= deck.size():
			return {"ok": false, "reason": "card no longer in deck"}
		burned = deck[idx]
		deck.remove_at(idx)
	elif source == "hand":
		if idx < 0 or idx >= hand.size() or hand[idx] == null:
			return {"ok": false, "reason": "card no longer in hand"}
		burned = hand[idx]
		hand[idx] = null
		_refill_hand()
	else:
		return {"ok": false, "reason": "unknown source"}

	pending_burn_index = -1
	pending_reward_choice = false
	reward_options = []
	rewards_taken += 1
	return {
		"ok": true,
		"type": "remove_card",
		"card": burned,
		"message": "Burned %s (%d dmg, %s) from your deck (now %d cards)." % [
			burned.get("letter", "?"), int(burned.get("damage", 0)),
			str(burned.get("color", "red")).to_upper(), deck.size()]
	}


## Abandons a burn pick so the three reward options come back.
func cancel_burn_card() -> void:
	pending_burn_index = -1


func is_burning() -> bool:
	return pending_burn_index >= 0


## Picks a random card from the master pool for the "add card" reward. It is
## not removed from the pool, so the same card can reward twice.
func _pick_reward_card() -> Dictionary:
	if CARD_DEFS.is_empty():
		return {"letter": "E", "damage": 1, "color": "red"}
	return CARD_DEFS[randi() % CARD_DEFS.size()].duplicate()


## Stat rewards, offered with weights that keep all three useful.
func _build_stat_rewards() -> void:
	var pool: Array = [
		{"type": "heal", "title": "VITALITY", "detail": "Restore HP."},
		{"type": "shield", "title": "BARRIER", "detail": "Gain shield."},
		{"type": "op", "title": "INSIGHT", "detail": "Gain operation points."},
		{"type": "max_hp", "title": "IRON WILL", "detail": "Raise max HP."},
		{"type": "draw", "title": "CARD DRAW", "detail": "Draw a card into hand."}
	]
	pool.shuffle()
	# Fill up to three options, but never duplicate a deck option already added.
	for reward: Dictionary in pool:
		if reward_options.size() >= 3:
			break
		reward_options.append(reward)


## Applies the reward the player chose. `index` is the position in reward_options.
##
## "remove_card" is a two-step reward: the first call opens the pick list (it
## returns {"ok": true, "needs_card": true} and keeps the choice pending), then
## the player picks a card and confirm_burn_card() finishes it.
func choose_reward(index: int) -> Dictionary:
	if not pending_reward_choice:
		return {"ok": false, "reason": "no pending choice"}
	if index < 0 or index >= reward_options.size():
		return {"ok": false, "reason": "invalid index"}
	var reward: Dictionary = reward_options[index]
	var result: Dictionary = {"ok": true, "type": reward.get("type", ""),
		"title": reward.get("title", ""), "message": ""}

	match str(reward.get("type", "")):
		"add_card":
			# Use the card that was rolled when the option was created, so the
			# player gets exactly the card they were shown.
			var card: Dictionary = reward.get("card", _pick_reward_card())
			deck.append(card.duplicate())
			result["card"] = card
			result["message"] = "Added %s (%d dmg, %s) to your deck (now %d cards)." % [
				card.get("letter", "?"), int(card.get("damage", 0)),
				str(card.get("color", "red")).to_upper(), deck.size()]
		"remove_card":
			# Wait for the player to pick which card to burn.
			pending_burn_index = index
			result["needs_card"] = true
			result["message"] = "Choose a card to burn from your deck."
			return result
		"heal":
			var amount: int = maxi(10, int(round(float(player_hp) * 0.25)))
			amount = mini(amount, PLAYER_MAX_HP - player_hp)
			player_hp += amount
			result["message"] = "Restored %d HP (now %d)." % [amount, player_hp]
		"shield":
			var gain: int = 8
			shield += gain
			result["message"] = "Gained %d shield (now %d)." % [gain, shield]
		"op":
			operation_points += 5
			result["message"] = "Gained 5 OP (now %d)." % operation_points
		"max_hp":
			player_hp += 5
			result["message"] = "Max HP is now %d." % PLAYER_MAX_HP
		"draw":
			var drawn: Dictionary = _draw_card()
			hand.append(drawn)
			result["message"] = "Drew %s (%d dmg) into your hand." % [
				drawn.get("letter", "?"), int(drawn.get("damage", 0))]

	pending_reward_choice = false
	reward_options = []
	rewards_taken += 1
	return result


func has_pending_reward() -> bool:
	return pending_reward_choice


func get_reward_options() -> Array:
	return reward_options


func get_deck_size() -> int:
	return deck.size()


# ─── Initialisation ──────────────────────────────────────────────────────────
func _ready() -> void:
	reset_game()
	_load_dictionary()

func reset_game() -> void:
	player_hp = PLAYER_MAX_HP
	shield = 0
	enemy_hp = ENEMY_BASE_HP
	operation_points = 0
	turn = 0

	enemy_max_hp = ENEMY_BASE_HP
	enemies_defeated = 0
	stage = 1
	total_damage = 0
	turn = 0
	is_night = false
	game_over = false
	game_outcome = ""
	graveyard.clear()
	deck.clear()
	slots.clear()
	hand.clear()
	current_slot_indices = [0, 0, 0]
	reward_options = []
	rewards_taken = 0
	pending_reward_choice = false
	pending_burn_index = -1
	slot_in_use = [false, false, false]

	# Build this game's deck: DECK_SIZE cards picked at random from the card pool
	var pool: Array = CARD_DEFS.duplicate()
	pool.shuffle()
	for i in range(DECK_SIZE):
		deck.append(pool[i].duplicate())

	# Roll this stage's enemy name and build the shared reels from its letters
	# (shared cards are separate from the player's deck)
	enemy_name = _roll_enemy_name()
	_build_shared_slots()

	# Deal 7 cards to hand from the player's deck
	for _h in range(HAND_SIZE):
		hand.append(_draw_card())

func _load_dictionary() -> void:
	var file = FileAccess.open("res://dictionary.txt", FileAccess.READ)
	if file == null:
		push_error("Dictionary not found at res://dictionary.txt")
		print("ERROR: Dictionary file not found. Using fallback dictionary.")
		# Fallback dictionary for web export if file not found
		_add_fallback_words()
		return
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line != "":
			dictionary[line.to_lower()] = true
			if _is_valid_enemy_name(line):
				word_list.append(line.to_upper())
	file.close()
	print("Dictionary loaded with ", dictionary.size(), " words (", word_list.size(), " enemy-name candidates)")

# ─── Enemy names ─────────────────────────────────────────────────────────────
# True when a dictionary word can be used as an enemy name: pure A-Z letters
# and short enough for the whole name to fit into the9 shared cards.
func _is_valid_enemy_name(word: String) -> bool:
	var w: String = word.strip_edges()
	if w.length() < NAME_MIN_LEN or w.length() > NAME_MAX_LEN:
		return false
	for i in range(w.length()):
		if ALPHA.find(w[i].to_upper()) < 0:
			return false
	return true

# Pick a random enemy name from the dictionary (falls back to a small built-in
# list when the dictionary is unavailable).
func _roll_enemy_name() -> String:
	if word_list.is_empty():
		return String(FALLBACK_ENEMY_NAMES.pick_random())
	return String(word_list.pick_random())

func _add_fallback_words() -> void:
	# Common English words as fallback for web export
	var fallback_words = [
		"the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
		"it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
		"this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
		"or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
		"so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
		"when", "make", "can", "like", "time", "no", "just", "him", "know", "take",
		"people", "into", "year", "your", "good", "some", "could", "them", "see", "other",
		"than", "then", "now", "look", "only", "come", "its", "over", "think", "also",
		"back", "after", "use", "two", "how", "our", "work", "first", "well", "way",
		"even", "new", "want", "because", "any", "these", "give", "day", "most", "us",
		"is", "are", "was", "were", "been", "has", "had", "did", "does", "done",
		"word", "game", "play", "card", "hand", "slot", "turn", "score", "point", "win",
		"red", "blue", "green", "yellow", "gold", "color", "wild", "match", "bonus", "penalty"
	]
	for word in fallback_words:
		dictionary[word] = true
	print("Fallback dictionary loaded with ", dictionary.size(), " words")

# ─── Card draw & recycle ─────────────────────────────────────────────────────
# Draws the top card of the deck. When the deck runs out, the graveyard is
# moved back into the deck and shuffled (deck & graveyard only ever hold this
# game's DECK_SIZE cards — never the full CARD_DEFS pool).
func _draw_card() -> Dictionary:
	if deck.is_empty():
		_reshuffle_graveyard()
	if deck.is_empty():
		return {"letter": "E", "damage": 1, "color": "red"} # Fallback safety
	return deck.pop_back()

# Move the graveyard back into the deck and shuffle it.
func _reshuffle_graveyard() -> void:
	deck = graveyard.duplicate()
	deck.shuffle()
	graveyard.clear()

func _refill_hand() -> void:
	for i in range(hand.size()):
		if hand[i] == null:
			hand[i] = _draw_card()

# ─── Card cost ─────────────────────────────────────────────────────────────────
# Every card carries a COST equal to its printed damage value. The cost is paid
# in operation points (OP), the currency earned by the YELLOW trait.
func get_card_cost(card: Variant) -> int:
	if typeof(card) != TYPE_DICTIONARY:
		return 0
	return maxi(int(card.get("damage", 0)), 0)

# OP needed to activate a card's special ability (the card's own damage value).
func get_special_cost(card: Variant) -> int:
	if not has_special_ability(card):
		return 0
	return get_card_cost(card)

# OP still missing before this card's special can be activated.
func get_special_cost_deficit(card: Variant) -> int:
	return maxi(get_special_cost(card) - operation_points, 0)

func can_use_special_ability(card: Variant) -> bool:
	return has_special_ability(card) and operation_points >= get_special_cost(card)

# ─── Special ability: cards with SPECIAL_MIN_DAMAGE or more ───────────────────
# Activate by long-press or right-click on the special card in hand. It COSTS the
# card's damage value in OP (see get_card_cost); the OP are only spent when the
# activation actually succeeds.
# Discards the special card AND all same-color cards in hand (including those
# just placed on the workbench), then draws replacement cards.
# Does not consume a turn.
func has_special_ability(card: Variant) -> bool:
	return typeof(card) == TYPE_DICTIONARY and int(card.get("damage", 0)) >= SPECIAL_MIN_DAMAGE

func use_special_ability(hand_index: int) -> Dictionary:
	var op_before: int = operation_points
	var result := {
		"valid": false, "discarded": [], "drawn": 0,
		"cost": 0, "operation_points_spent": 0,
		"operation_points_before": op_before,
		"operation_points_after": operation_points,
		"reason": ""
	}
	if hand_index < 0 or hand_index >= hand.size():
		result["reason"] = "No card in hand"
		return result
	var special_card: Dictionary = hand[hand_index]
	if not has_special_ability(special_card):
		result["reason"] = "No special ability"
		return result

	# The card's damage value is its cost, paid in OP
	var cost: int = get_special_cost(special_card)
	result["cost"] = cost
	if operation_points < cost:
		result["reason"] = "Not enough OP"
		return result
	operation_points -= cost
	result["operation_points_spent"] = cost
	result["operation_points_after"] = operation_points

	var target_color: String = special_card.get("color", "red")
	var discarded: Array = []

	# Discard the special card itself
	graveyard.append(hand[hand_index])
	discarded.append(special_card)
	hand[hand_index] = null

	# Discard all other same-color cards in hand
	for i in range(hand.size()):
		if hand[i] != null and hand[i].get("color", "red") == target_color:
			graveyard.append(hand[i])
			discarded.append(hand[i])
			hand[i] = null

	# Draw replacements for all emptied slots
	_refill_hand()

	result["valid"] = true
	result["discarded"] = discarded
	result["color"] = target_color
	result["drawn"] = discarded.size()
	return result

# ─── Slot helpers ────────────────────────────────────────────────────────────
func get_slot_cards(slot_idx: int) -> Array:
	if slot_idx < slots.size():
		return slots[slot_idx]
	return []

func get_current_slot_card(slot_idx: int) -> Dictionary:
	var s_cards: Array = slots[slot_idx]
	var cur_i: int = current_slot_indices[slot_idx] % s_cards.size()
	return s_cards[cur_i]

func get_current_slot_chars() -> Array:
	var chars: Array = []
	for s in range(NUM_SLOTS):
		chars.append(get_current_slot_card(s)["letter"].to_upper())
	return chars

func get_current_slot_total_damage() -> int:
	var total: int = 0
	for s in range(NUM_SLOTS):
		total += get_current_slot_card(s)["damage"]
	return total

# Penalty preview for the NIGHT phase, computed from the NEXT card of every
# slot. `rotating_slots` lists the slots the pending submission will consume:
# those reels roll BEFORE the penalty is resolved, so their NEXT card sits one
# step further along than an untouched slot's. Passing an empty array gives the
# current (already-rolled) state, which is what the live game applies.
func get_next_slot_penalty_with_multiplier(rotating_slots: Array = []) -> Dictionary:
	var total: int = 0
	var next_cards: Array = []
	for s in range(NUM_SLOTS):
		var s_cards: Array = slots[s]
		var cur_i: int = current_slot_indices[s] % s_cards.size()
		var rolls: bool = rotating_slots.has(s)
		# An unused slot advances by 1 (NEXT of the current reel position); a used
		# slot first rolls, so its NEXT card is 2 steps from where it stands now.
		var next_i: int = (cur_i + (2 if rolls else 1)) % s_cards.size()
		var next_card: Dictionary = s_cards[next_i].duplicate()
		next_card["type"] = "slot"
		next_card["index"] = s
		next_card["will_rotate"] = rolls
		next_cards.append(next_card)
		total += next_card["damage"]

	var multiplier: int = calculate_penalty_color_multiplier(next_cards)
	return {
		"base_penalty": total,
		"multiplier": multiplier,
		"final_penalty": total * multiplier,
		"next_cards": next_cards
	}

func rotate_slots(used_slots: Array) -> void:
	# Rotate only the slots that were used (the card on the ACTIVE row moves out
	# and the NEXT card becomes ACTIVE)
	for s in used_slots:
		if int(s) < 0 or int(s) >= current_slot_indices.size():
			continue
		current_slot_indices[s] = (current_slot_indices[s] + 1) % CARDS_PER_SLOT


# ─── OP ability: spin a shared reel ──────────────────────────────────────────
# SPIN_COST OP advances ONE shared reel by one step, so the card that was showing
# as NEXT becomes ACTIVE. Each reel is spun independently, so a player can nudge
# one bad reel and leave the others alone.
const SPIN_COST: int = 1

# Which reels currently have their ACTIVE card on the Workbench. The UI owns the
# Workbench, so it reports this back here.
var slot_in_use: Array = []


## What spinning reel `slot_idx` right now would do, without doing it.
## Used by the UI to label the buttons and to grey them out when spinning is
## not allowed, so the rules are never hidden from the player.
func can_spin_slot(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= slots.size():
		return {"ok": false, "reason": "No such reel"}
	if slot_idx >= current_slot_indices.size():
		return {"ok": false, "reason": "Reel is not ready"}
	if operation_points < SPIN_COST:
		return {"ok": false, "reason": "Not enough OP"}
	# Spinning a reel whose ACTIVE card is already part of the word being built
	# would silently change the word, so it is refused. The player must remove
	# the card from the Workbench first.
	if is_slot_active_in_use(slot_idx):
		return {"ok": false, "reason": "That card is in your word"}
	return {"ok": true, "reason": ""}


## Whether the reel's ACTIVE card is currently placed on the Workbench. The UI
## owns the Workbench, so it reports this back to the game logic.
func set_slot_in_use(slot_idx: int, in_use: bool) -> void:
	while slot_in_use.size() < slots.size():
		slot_in_use.append(false)
	if slot_idx >= 0 and slot_idx < slot_in_use.size():
		slot_in_use[slot_idx] = in_use


func is_slot_active_in_use(slot_idx: int) -> bool:
	return slot_idx >= 0 and slot_idx < slot_in_use.size() and slot_in_use[slot_idx]


## Spends OP to advance one reel by a single step. Returns what happened so the
## UI can report it. The OP are only spent when the spin actually happens, so a
## refused spin never costs anything.
func spin_slot(slot_idx: int) -> Dictionary:
	var check: Dictionary = can_spin_slot(slot_idx)
	if not check.get("ok", false):
		return {"ok": false, "reason": check.get("reason", "Cannot spin")}

	var spend: Dictionary = try_spend_operation_points(SPIN_COST)
	if not spend.get("valid", false):
		return {"ok": false, "reason": spend.get("reason", "Not enough OP")}

	var s_cards: Array = slots[slot_idx]
	var cur_i: int = current_slot_indices[slot_idx] % s_cards.size()
	var next_i: int = (cur_i + 1) % s_cards.size()
	current_slot_indices[slot_idx] = next_i

	var shown: Dictionary = s_cards[next_i]
	return {
		"ok": true,
		"slot": slot_idx,
		"card": shown,
		"remaining": spend.get("remaining", operation_points),
		"message": "Spun reel %d for %d OP — now showing %s (%d dmg, %s). %d OP left." % [
			slot_idx + 1, SPIN_COST, shown.get("letter", "?"),
			int(shown.get("damage", 0)),
			str(shown.get("color", "red")).to_upper(),
			int(spend.get("remaining", operation_points))]
	}

# Calculate the word-damage color multiplier. RED is exceptional:
# 0 red = x1, 1 red = x1.5 (exception), 2+ red = 2^(n-1)
# (2 red = 2x, 3 red = 4x, 4 red = 8x, etc.). Blue/green/yellow same-color
# groups do NOT multiply damage — those colors grant their traits instead.
func calculate_color_multiplier(assignment: Array) -> float:
	var red_count: int = int(count_colors_in_assignment(assignment).get("red", 0))
	return red_damage_multiplier(red_count)

# Stacking multiplier shared by BLUE/GREEN/YELLOW traits:
# 0 cards -> 0 (trait inactive), 1 -> x1, 2 -> x2, 3 -> x4, 4 -> x8
func color_trait_multiplier(card_count: int) -> int:
	if card_count <= 0:
		return 0
	return int(pow(2, card_count - 1))

# RED's word-damage multiplier follows the exceptional rule:
# 0 red -> x1, exactly 1 red -> x1.5, 2+ red -> 2^(n-1)
func red_damage_multiplier(red_count: int) -> float:
	if red_count <= 0:
		return 1.0
	if red_count == 1:
		return 1.5
	return pow(2, red_count - 1)

# Calculate penalty color multiplier for night phase self-damage (2+ same color = 10x, 3 = 100x, 4 = 1000x, etc.)
# Note: Word damage bonuses still use calculate_color_multiplier(); only night self-damage uses this steeper multiplier.
func calculate_penalty_color_multiplier(assignment: Array) -> int:
	var color_counts: Dictionary = {}
	for src in assignment:
		var color: String = src.get("color", "red")
		if color_counts.has(color):
			color_counts[color] += 1
		else:
			color_counts[color] = 1

	var max_count: int = 0
	for color in color_counts:
		if color_counts[color] > max_count:
			max_count = color_counts[color]

	# Penalty multiplier: 2 cards = 10x, 3 cards = 100x, 4 cards = 1000x, etc. (10^(n-1))
	if max_count < 2:
		return 1
	return int(pow(10, max_count - 1))

# ─── Word Subsequence Search & Validation ────────────────────────────────────
# Validates words with strict left-to-right slot ordering, filled with hand cards.
func find_valid_assignments(word: String) -> Array:
	var result: Array = []
	if word == "":
		return result

	var word_lower = word.to_lower()

	# If word contains wildcard "?", search for matching dictionary words
	if "?" in word_lower:
		for dict_word in dictionary.keys():
			if _matches_pattern(dict_word, word_lower):
				var chars: Array = dict_word.to_upper().split("")
				var slot_chars: Array = get_current_slot_chars()
				_search_slot_subsequences(chars, slot_chars, 0, 0, {}, result)
		return result

	# Otherwise, check if exact word exists in dictionary
	if not dictionary.has(word_lower):
		return result

	var chars: Array = word.to_upper().split("")
	var slot_chars: Array = get_current_slot_chars()

	_search_slot_subsequences(chars, slot_chars, 0, 0, {}, result)
	return result

func _matches_pattern(dict_word: String, pattern: String) -> bool:
	if dict_word.length() != pattern.length():
		return false
	for i in range(dict_word.length()):
		var p_char = pattern[i]
		if p_char != "?" and p_char != dict_word[i]:
			return false
	return true

func _search_slot_subsequences(chars: Array, slot_chars: Array, word_idx: int, min_slot_idx: int, current_slot_map: Dictionary, results: Array) -> void:
	# Try matching remaining letters with available hand cards
	var hand_assignments: Array = []
	_assign_hand_cards(chars, current_slot_map, 0, [], hand_assignments)
	for h_assign in hand_assignments:
		var full_assign: Array = []
		for i in range(chars.size()):
			if current_slot_map.has(i):
				var s_idx: int = current_slot_map[i]
				var card: Dictionary = get_current_slot_card(s_idx)
				var is_wildcard: bool = card["letter"] == "?"
				full_assign.append({
					"type": "slot",
					"index": s_idx,
					"char": chars[i],  # The actual character this position represents
					"card_letter": card["letter"],  # The actual letter on the card
					"is_wildcard": is_wildcard,
					"damage": card["damage"],
					"color": card.get("color", "red")
				})
			else:
				var h_idx: int = h_assign[i]
				var card: Dictionary = hand[h_idx]
				var is_wildcard: bool = card["letter"] == "?"
				full_assign.append({
					"type": "hand",
					"hand_index": h_idx,
					"char": chars[i],  # The actual character this position represents
					"card_letter": card["letter"],  # The actual letter on the card
					"is_wildcard": is_wildcard,
					"damage": card["damage"],
					"color": card.get("color", "red")
				})
		results.append(full_assign)

	# Branch: include more slots in strictly increasing index order
	for w in range(word_idx, chars.size()):
		for s in range(min_slot_idx, slot_chars.size()):
			# Wildcard "?" matches any character
			if chars[w] == slot_chars[s] or slot_chars[s] == "?":
				current_slot_map[w] = s
				_search_slot_subsequences(chars, slot_chars, w + 1, s + 1, current_slot_map, results)
				current_slot_map.erase(w)

func _assign_hand_cards(chars: Array, slot_map: Dictionary, char_idx: int, used_hand_indices: Array, results: Array) -> void:
	if char_idx >= chars.size():
		var mapping: Dictionary = {}
		for u in used_hand_indices:
			mapping[u["char_idx"]] = u["hand_idx"]
		results.append(mapping)
		return

	if slot_map.has(char_idx):
		_assign_hand_cards(chars, slot_map, char_idx + 1, used_hand_indices, results)
		return

	var target_char: String = chars[char_idx]
	var already_used_h: Array = []
	for u in used_hand_indices:
		already_used_h.append(u["hand_idx"])

	for h in range(hand.size()):
		# Wildcard "?" matches any character
		if hand[h] != null and (hand[h]["letter"] == target_char or hand[h]["letter"] == "?") and h not in already_used_h:
			used_hand_indices.append({"char_idx": char_idx, "hand_idx": h})
			_assign_hand_cards(chars, slot_map, char_idx + 1, used_hand_indices, results)
			used_hand_indices.pop_back()

# Feasibility check
func validate_word(word: String) -> Dictionary:
	var result := {"valid": false, "message": "INVALID", "assignment": []}
	var valid_assignments: Array = find_valid_assignments(word)
	if valid_assignments.size() > 0:
		result["valid"] = true
		result["message"] = "VALID: %s" % word.to_upper()
		result["assignment"] = valid_assignments[0]
		result["all_assignments"] = valid_assignments
	return result

func is_assignment_valid(word: String, assignment: Array) -> bool:
	if assignment.size() != word.length():
		return false
	var chars: Array = word.to_upper().split("")
	var slot_chars: Array = get_current_slot_chars()
	var used_hand: Array = []
	var last_slot_idx: int = -1

	for i in range(assignment.size()):
		var src = assignment[i]
		if src == null:
			return false
		var ch: String = chars[i]
		if src["type"] == "hand":
			var hi: int = src["hand_index"]
			var card_letter: String = src.get("card_letter", hand[hi]["letter"])
			# Wildcard "?" matches any character
			if hi in used_hand or hand[hi] == null:
				return false
			# If card is wildcard, it matches any character
			if card_letter != "?" and card_letter != ch:
				return false
			used_hand.append(hi)
		elif src["type"] == "slot":
			var si: int = src["index"]
			var card_letter: String = src.get("card_letter", slot_chars[si])
			# Wildcard "?" matches any character
			if si <= last_slot_idx or si >= slot_chars.size():
				return false
			# If card is wildcard, it matches any character
			if card_letter != "?" and card_letter != ch:
				return false
			last_slot_idx = si
	return true

# ─── Execute confirmed assignment ────────────────────────────────────────────
func execute_assignment(word: String, assignment: Array) -> Dictionary:
	var used_hand_indices: Array = []
	var used_slot_indices: Array = []
	var base_damage: int = 0

	for src in assignment:
		base_damage += src.get("damage", 0)
		if src["type"] == "hand":
			used_hand_indices.append(src["hand_index"])
		else:
			used_slot_indices.append(src["index"])

	var enemy_hp_before: int = enemy_hp
	var enemy_max_hp_before: int = enemy_max_hp
	var player_hp_before: int = player_hp
	var defeated_before: int = enemies_defeated
	var enemy_name_before: String = enemy_name
	# ─── Accessors ───────────────────────────────────────────────────────────────
	var multiplier: float = calculate_color_multiplier(assignment)
	var color_counts: Dictionary = count_colors_in_assignment(assignment)
	# RED trait (attack multiplier), applied EXACTLY ONCE:
	#   0 red = x1 (no effect), exactly 1 red = x1.5 (exception),
	#   2+ red = base x 2^(red - 1). The multiplier is NOT stacked with
	# any further per-card bonus.
	var group_damage: int = int(round(base_damage * multiplier))
	var final_damage: int = group_damage

	for hi in used_hand_indices:
		graveyard.append(hand[hi])
		hand[hi] = null
	_refill_hand()
	rotate_slots(used_slot_indices)

	# Color traits resolve BEFORE the damage exchange. Every trait is based on the
	# BASE TOTAL with the same stacking multiplier 2^(count - 1):
	#   BLUE  -> shield = base x 2^(blue - 1)   (no cap)
	#   GREEN -> heal   = base x 2^(green - 1)  (capped at max HP)
	#   YELLOW is reserved for a future trait
	var blue_count: int = int(color_counts.get("blue", 0))
	var green_count: int = int(color_counts.get("green", 0))
	var yellow_count: int = int(color_counts.get("yellow", 0))
	# A negative word deals no trait value, so traits scale off the positive base
	var trait_base: int = maxi(base_damage, 0)
	var shield_before: int = shield
	var shield_mult: int = color_trait_multiplier(blue_count)
	var shield_gained: int = trait_base * shield_mult
	shield += shield_gained
	var heal_mult: int = color_trait_multiplier(green_count)
	var heal_amount: int = mini(trait_base * heal_mult, PLAYER_MAX_HP - player_hp)
	player_hp += heal_amount
	# YELLOW: earn operation points (same base-scaled stacking). Points accumulate
	# and can be spent to move a card on the Workbench.
	var operation_points_before: int = operation_points
	var yellow_mult: int = color_trait_multiplier(yellow_count)
	var operation_points_gained: int = trait_base * yellow_mult
	operation_points += operation_points_gained
	var player_hp_after_traits: int = player_hp

	# Positive damage is dealt to the enemy, negative damage hurts the player
	# (the BLUE shield absorbs incoming damage first)
	var damage_result: Dictionary = _apply_damage(final_damage)

	turn += 1
	is_night = not is_night

	return {
		"message": "VALID: %s" % word.to_upper(),
		"word_damage": base_damage,
		"multiplier": multiplier,
		"group_damage": group_damage,
		"red_bonus": group_damage - base_damage,
		"shield_before": shield_before,
		"shield_gained": shield_gained,
		"shield_mult": shield_mult,
		"heal_amount": heal_amount,
		"heal_mult": heal_mult,
		"operation_points_before": operation_points_before,
		"operation_points_gained": operation_points_gained,
		"operation_points_after": operation_points,
		"yellow_mult": yellow_mult,
		"player_hp_after_traits": player_hp_after_traits,
		"self_damage_absorbed": damage_result.get("absorbed", 0),
		"self_damage_taken": damage_result.get("taken", 0),
		"final_damage": final_damage,
		"enemy_hp_before": enemy_hp_before,
		"enemy_hp_after": enemy_hp,
		"enemy_max_hp_before": enemy_max_hp_before,
		"enemy_max_hp_after": enemy_max_hp,
		"player_hp_before": player_hp_before,
		"player_hp_after": player_hp,
		"enemies_defeated_delta": enemies_defeated - defeated_before,
		"used_hand": used_hand_indices,
		"used_slots": used_slot_indices,
		"turn": turn,
		"stage": stage,
		"enemy_name_before": enemy_name_before,
		"phase": get_phase(),
		"game_over": game_over,
		"game_outcome": game_outcome
	}


# Spend operation points to perform a player action. Actions never consume a
# turn; invalid actions are rejected without spending points.
func spend_operation_points(amount: int) -> bool:
	if amount <= 0:
		return false
	if operation_points < amount:
		return false
	operation_points -= amount
	return true

# ─── Damage resolution ───────────────────────────────────────────────────────
# Positive damage hits the current enemy. When an enemy's HP reaches 0 the
# stage is cleared (stronger enemy + fresh hand). Any excess damage is LOST —
# it does NOT carry over to the next stage's enemy.
# Negative damage hits the player instead: the BLUE shield absorbs first, then
# HP (never below 0). Returns {absorbed, taken}.
func _apply_damage(amount: int) -> Dictionary:
	if amount > 0:
		total_damage += amount
		enemy_hp -= amount
		if enemy_hp <= 0:
			_advance_stage()
		return {"absorbed": 0, "taken": 0}
	elif amount < 0:
		return _take_self_damage(-amount)
	return {"absorbed": 0, "taken": 0}

# Applies damage to the player: shield absorbs first, then HP (HP >= 0).
func _take_self_damage(amount: int) -> Dictionary:
	var absorbed: int = mini(shield, amount)
	shield -= absorbed
	var taken: int = amount - absorbed
	player_hp = maxi(player_hp - taken, 0)
	_check_player_defeat()
	return {"absorbed": absorbed, "taken": taken}

# Count how many cards of each color are used in the word.
func count_colors_in_assignment(assignment: Array) -> Dictionary:
	var counts: Dictionary = {"red": 0, "blue": 0, "green": 0, "yellow": 0}
	for src in assignment:
		var c: String = src.get("color", "red")
		counts[c] = counts.get(c, 0) + 1
	return counts

# ─── Stage progression ────────────────────────────────────────────────────────
# Defeating an enemy advances to the next stage: a stronger enemy with a NEW
# random name appears, the player's hand is redrawn and the shared reels are
# rebuilt from the new enemy's name letters.
# Any excess damage that killed the enemy is lost (no carry-over).
func _advance_stage() -> void:
	enemies_defeated += 1
	stage += 1
	enemy_max_hp += ENEMY_HP_GROWTH
	enemy_hp = enemy_max_hp
	enemy_name = _roll_enemy_name()
	_reset_hand()
	_build_shared_slots()

# Discard the whole hand and draw a fresh hand from the deck.
func _reset_hand() -> void:
	for i in range(hand.size()):
		if hand[i] != null:
			graveyard.append(hand[i])
			hand[i] = null
	while hand.size() < HAND_SIZE:
		hand.append(null)
	_refill_hand()

# Rebuild the shared slot reels (3x3) from the current enemy's name letters,
# in SHUFFLED order (the name's sequence is randomized across the9 positions),
# then rewind the reels to the top. The shared cards come from their own copy
# of the card pool — they are NOT part of the player's deck, and cards spent
# here never enter the player's graveyard.
# Cards the name cannot cover (or pool shortages) are drawn at random from
# the shared pool.
func _build_shared_slots() -> void:
	var pool: Array = []
	for def in CARD_DEFS:
		pool.append(def.duplicate())

	# The enemy name's letters (their positions are shuffled below)
	var name_letters: Array = []
	for ch in enemy_name.to_upper():
		if ALPHA.find(ch) >= 0:
			name_letters.append(ch)

	var cards: Array = []
	# 1) Use the enemy name's letters first
	while cards.size() < NUM_SLOTS * CARDS_PER_SLOT and not name_letters.is_empty():
		var wanted: String = name_letters.pop_front()
		var found_idx: int = _find_random_letter_index(pool, wanted)
		if found_idx >= 0:
			cards.append(pool[found_idx])
			pool.remove_at(found_idx)
		# If the shared pool has no copy left, the letter is simply skipped

	# 2) Fill the rest with random draws from the shared pool
	while cards.size() < NUM_SLOTS * CARDS_PER_SLOT and not pool.is_empty():
		var random_idx: int = randi() % pool.size()
		cards.append(pool[random_idx])
		pool.remove_at(random_idx)

	# Safety: never deal fewer than NUM_SLOTS * CARDS_PER_SLOT cards
	while cards.size() < NUM_SLOTS * CARDS_PER_SLOT:
		cards.append({"letter": "?", "damage": 0, "color": "gold"})

	# Shuffle so the shared cards are NOT dealt in the enemy name's order
	cards.shuffle()

	slots.clear()
	current_slot_indices = []
	var pos: int = 0
	for s in range(NUM_SLOTS):
		var slot_cards: Array = []
		for _c in range(CARDS_PER_SLOT):
			slot_cards.append(cards[pos])
			pos += 1
		slots.append(slot_cards)
		current_slot_indices.append(0)

# Pick a random pool entry with the given letter (any color), or -1 if none.
func _find_random_letter_index(pool: Array, letter: String) -> int:
	var matches: Array = []
	for i in range(pool.size()):
		if pool[i].get("letter", "") == letter:
			matches.append(i)
	if matches.is_empty():
		return -1
	return matches[randi() % matches.size()]

func _check_player_defeat() -> void:
	if player_hp <= 0 and not game_over:
		game_over = true
		game_outcome = "DEFEAT"

# ─── Accessors ───────────────────────────────────────────────────────────────
func get_hand() -> Array:
	return hand

func get_graveyard() -> Array:
	return graveyard

# The draw pile is intentionally exposed as an unordered collection for UI
# summaries. Callers must not infer the next draw from its array order.
func get_draw_pile_cards() -> Array:
	return deck.duplicate()

func get_deck_count() -> int:
	return deck.size()

func get_player_hp() -> int:
	return player_hp

func get_shield() -> int:
	return shield

func get_max_player_hp() -> int:
	return PLAYER_MAX_HP

func get_enemy_hp() -> int:
	return enemy_hp

func get_max_enemy_hp() -> int:
	return enemy_max_hp

func get_stage() -> int:
	return stage

func get_enemy_name() -> String:
	return enemy_name

func get_enemy_index() -> int:
	return stage

func get_enemies_defeated() -> int:
	return enemies_defeated

func get_total_damage() -> int:
	return total_damage

func get_operation_points() -> int:
	return operation_points

# Whether a card's special can be activated right now (enough OP for its cost).
func can_activate_special(card: Variant) -> bool:
	return can_use_special_ability(card)

# OP price of a card's special ability (the card's damage value, 0 if none).
func get_special_cost_for(card: Variant) -> int:
	return get_special_cost(card)

# Spend operation points. Returns the remaining balance so the UI can reject
# an action cleanly without mutating the balance.
func try_spend_operation_points(cost: int = 1) -> Dictionary:
	if cost < 0:
		return {"valid": false, "remaining": operation_points, "reason": "Invalid cost"}
	if operation_points < cost:
		return {"valid": false, "remaining": operation_points, "reason": "Not enough OP"}
	operation_points -= cost
	return {"valid": true, "remaining": operation_points, "reason": ""}

func is_game_over() -> bool:
	return game_over

func get_game_outcome() -> String:
	return game_outcome

# ─── Submit preview ───────────────────────────────────────────────────────────
# Predicts EVERYTHING the player will take when submitting `assignment`, without
# mutating any state. It mirrors the real resolution order exactly:
#   1. BLUE shield and GREEN heal from the word are granted first
#   2. negative word damage hits the player (BLUE shield absorbs it)
#   3. the turn counter advances and the phase flips
#   4. if the new phase is NIGHT, the slot penalty lands (BLUE shield absorbs it)
# Slots listed in `used_slots` roll in step 3, so step 4 reads their NEXT card
# one position further along — see get_next_slot_penalty_with_multiplier().
func predict_submit_outcome(assignment: Array, used_slots: Array) -> Dictionary:
	var base_damage: int = 0
	for src in assignment:
		base_damage += int(src.get("damage", 0))

	var multiplier: float = calculate_color_multiplier(assignment)
	var color_counts: Dictionary = count_colors_in_assignment(assignment)
	var final_damage: int = int(round(float(base_damage) * multiplier))

	# 1) Traits resolve before the damage exchange (positive base only)
	var trait_base: int = maxi(base_damage, 0)
	var shield_gained: int = trait_base * color_trait_multiplier(int(color_counts.get("blue", 0)))
	var heal_mult: int = color_trait_multiplier(int(color_counts.get("green", 0)))
	var heal_amount: int = mini(trait_base * heal_mult, PLAYER_MAX_HP - player_hp)
	var shield_pool: int = shield + shield_gained
	var hp_pool: int = player_hp + heal_amount

	# 2) Negative word damage hurts the player; the shield absorbs it first
	var word_self_damage: int = maxi(-final_damage, 0)
	var word_absorbed: int = mini(shield_pool, word_self_damage)
	shield_pool -= word_absorbed
	hp_pool = maxi(hp_pool - (word_self_damage - word_absorbed), 0)

	# 3) The turn advances and the phase flips
	var next_is_night: bool = not is_night

	# 4) On the new NIGHT phase the slot penalty lands (used slots already rolled)
	var penalty: Dictionary = get_next_slot_penalty_with_multiplier(used_slots if next_is_night else [])
	var night_penalty: int = penalty["final_penalty"] if next_is_night else 0
	var night_absorbed: int = mini(shield_pool, night_penalty)
	shield_pool -= night_absorbed
	hp_pool = maxi(hp_pool - (night_penalty - night_absorbed), 0)

	var hp_lost: int = maxi((player_hp + heal_amount) - hp_pool, 0)
	return {
		"base_damage": base_damage,
		"multiplier": multiplier,
		"final_damage": final_damage,
		"color_counts": color_counts,
		"shield_gained": shield_gained,
		"heal_amount": heal_amount,
		"word_self_damage": word_self_damage,
		"word_absorbed": word_absorbed,
		"next_is_night": next_is_night,
		"night_base_penalty": penalty["base_penalty"],
		"night_multiplier": penalty["multiplier"],
		"night_penalty": night_penalty,
		"night_absorbed": night_absorbed,
		"night_next_cards": penalty["next_cards"],
		"total_absorbed": word_absorbed + night_absorbed,
		"total_hp_lost": hp_lost,
		"player_hp_after": hp_pool,
		"lethal": hp_pool <= 0 and (player_hp + heal_amount) > 0
	}

func get_turn() -> int:
	return turn

func get_phase() -> String:
	return "NIGHT" if is_night else "DAY"

func get_next_slot_total_penalty() -> int:
	return get_next_slot_penalty_with_multiplier()["final_penalty"]

func apply_turn_start_penalty() -> Dictionary:
	if not is_night:
		return {
			"base_damage": 0,
			"multiplier": 1,
			"requested_damage": 0,
			"absorbed": 0,
			"applied_damage": 0,
			"previous_player_hp": player_hp,
			"player_hp": player_hp
		}

	var penalty: Dictionary = get_next_slot_penalty_with_multiplier()
	var requested_damage: int = penalty["final_penalty"]
	var previous_player_hp: int = player_hp
	# Night self-damage: the BLUE shield absorbs first, then HP
	var damage_result: Dictionary = _take_self_damage(requested_damage)
	return {
		"base_damage": penalty["base_penalty"],
		"multiplier": penalty["multiplier"],
		"requested_damage": requested_damage,
		"absorbed": damage_result["absorbed"],
		"applied_damage": previous_player_hp - player_hp,
		"previous_player_hp": previous_player_hp,
		"player_hp": player_hp
	}
