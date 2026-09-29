# Word Game

A strategic word-building game where you construct words from slot cards and hand cards to deal damage to enemies while protecting your own HP.

## Game Overview

Build valid English words using cards from your slots and hand. Each card has a letter and a damage value. Positive damage is dealt to the enemy; negative damage (night penalties) is dealt back to you as self-damage. Defeat as many enemies as you can within 10 turns while managing your HP, slot rotations and phase damage.

## HP & Enemies

- **Player HP**: 50 (shown with a green HP bar)
- **Enemy**: Enemies appear one at a time (shown with a red HP bar). The first enemy has 30 HP.
- **Enemy name**: chosen at random from the game dictionary (pure letters, 3-9 long).
- **Shared cards**: the 3 slot reels are built from the letters of the current enemy's name (the 9 positions are shuffled randomly); any remaining cards are drawn at random from the shared card pool. Shared cards are separate from your 20-card deck — they never enter your deck or graveyard.
- **Positive damage**: reduces the current enemy's HP. When an enemy's HP reaches 0 the stage is cleared and the next stage begins — any excess damage is wasted and does NOT carry over to the next enemy.
- **Stages**: Each stage has one enemy. Clearing a stage spawns a stronger enemy (+15 max HP) and **resets your cards**: all 7 hand cards are discarded and redrawn, and the shared slot reels are rebuilt from the new enemy's name (all three reels roll to the newly dealt cards).
- **Negative damage**: reduces your HP (never below 0). If your HP reaches 0, it's GAME OVER (DEFEAT).
- **Result**: after 10 turns the game ends (COMPLETE) and you are evaluated by stage reached, total damage dealt and enemies defeated.

## Game Rules

### Basic Setup
- **3 Slot Reels**: Each slot contains 3 cards that can be rotated
- **7 Hand Cards**: Cards you can use to fill in letters
- **Card Pool & Deck**: The pool holds 99 card types; each game builds a 20-card deck chosen at random from the pool. When the draw pile runs out, the graveyard is shuffled back into the deck.
- **Player HP**: 50 / **Enemy HP**: 30 for stage 1 (grows +15 per stage)
- **Stages**: Defeat the enemy to advance to the next stage; your hand and the shared slot reels are fully reset on each stage change
- **10 Turns**: Game ends after 10 turns
- **Enemy & Shared Cards**: Each enemy gets a random name from the dictionary (3-9 letters). The shared slot reels are built from that enemy's name letters (any shortage is filled by random draws) and are handled separately from your deck.
- **Dictionary**: Only valid English words are accepted

### How to Play
1. Click or drag cards from slots (marked with ★ ACTIVE) or your hand to the Workbench
2. Arrange cards to form a valid word
3. Click SUBMIT WORD to deal damage with your word
4. Used slots rotate to the next card
5. Used hand cards are discarded and replaced from the deck
6. Defeat the enemy (reduce its HP to 0) to clear the stage — the next stage starts, your hand is redrawn and all three shared reels roll to the new enemy's cards

### Slot Rotation
- Only slots that are used in your word will rotate: the ★ ACTIVE card you used is spent and the reel rolls so that its NEXT card becomes ACTIVE
- The card you place in the workbench is always the card that gets consumed — a shared card you used is never silently substituted by a hand card, so the reel you used is guaranteed to rotate
- When a stage is cleared, all three reels roll to reveal the shared cards of the new enemy

### Day/Night Phases
The game alternates between DAY and NIGHT phases each turn:

**DAY Phase**: No incoming damage
**NIGHT Phase**: At the start of the turn, you take damage equal to the total damage values of the NEXT cards in all slots

### Card Colors & Multipliers
Each card has a color attribute (Red, Blue, Green, Yellow, or Gold for wildcards). The damage multiplier applies ONLY to red cards used together in the same word:

- **2 red cards**: 2x multiplier
- **3 red cards**: 4x multiplier
- **4 red cards**: 8x multiplier
- Formula: 2^(n-1) where n is the number of red cards

Blue/green/yellow same-color groups do not multiply damage — those colors grant their traits instead (see Color Traits).

The word multiplier applies to:
- Damage dealt by your word

Night phase self-damage uses a steeper color multiplier:
- **2 matching colors**: 10x damage
- **3 matching colors**: 100x damage
- Formula: 10^(n-1) where n is the number of same-color next cards

### Color Traits
Cards of each color grant a trait when used in a valid word (shared slot cards count too):

- **RED — Attack multiplier**: damage to the enemy scales off the base total: `base x 2^(red - 1)` (1 red = x1, 2 = x2, 3 = x4, 4 = x8).
- **BLUE — Shield**: shield gained scales off the base total: `base x 2^(blue - 1)` (no cap). Shield absorbs incoming damage (night self-damage, negative word damage) before HP is lost.
- **GREEN — Heal**: HP healed scales off the base total: `base x 2^(green - 1)` (up to your max HP).
- **YELLOW — Operation points (OP)**: OP gained scales off the base total: `base x 2^(yellow - 1)` (1 yellow = x1, 2 = x2, 3 = x4, 4 = x8). OP is a currency, not a score: it is never spent by damage and never resets, and **1 OP moves one Workbench card one place left or right** (costs no turn).
- **★ SPECIAL (cards with 8+ damage)**: activated by long-pressing or right-clicking the card in hand. It costs **the card's own damage value in OP** (an 8-damage card costs 8 OP, a 10-damage card costs 10 OP), then discards that card and every same-color card in hand and redraws (no turn used). With too few OP the activation is refused.

All traits use the **positive base total** (a negative word grants no trait value), and every trait is applied once.

### Wildcard Cards
- **"?" cards** can represent any letter
- They deal 0 damage but can help complete difficult words
- The pool contains 9 wildcards; how many end up in your random 20-card deck changes every game
- Each wildcard has a color (Red, Blue, Green, or Yellow) like normal cards
- Match a wildcard's color with other same-color cards to increase the multiplier
- The letter is displayed in gold for identification; the border shows its color

### Damage Values
- Each letter deals damage based on rarity:
  - 1 damage: E, A, I, O, N, R, T, L, S, U (common)
  - 2 damage: D, G
  - 3 damage: B, C, M, P
  - 4 damage: F, H, V, W, Y
  - 5 damage: K
  - 8 damage: J, X
  - 10 damage: Q, Z
  - 0 damage: ? (wildcard)

### Calculation Formulas
Press the **FORMULAS** button in the game to open the formula panel — it lists every calculation below with the live values from the game code, plus the breakdown of the word you submitted last.

**Damage dealt to the enemy (positive damage)**
- `base` = sum of the damage of every card placed in the word (the base total)
- `RED multiplier` = 2 ^ (red cards - 1) → 1 red = x1, 2 red = x2, 3 red = x4, 4 red = x8
- `final damage` = base x RED multiplier. Blue/green/yellow groups never multiply damage.
- Excess damage beyond the enemy's remaining HP is wasted (never carried over).

**BLUE shield (player)**
- `shield` = base x 2 ^ (blue cards - 1) → 1 blue = x1, 2 blue = x2, 3 blue = x4, 4 blue = x8 (no cap)
- `blocked` = min(shield, incoming damage); the shield absorbs night self-damage and negative word damage before HP is lost

**GREEN heal (player)**
- `heal` = base x 2 ^ (green cards - 1) → 1 green = x1, 2 green = x2, 3 green = x4, 4 green = x8 (capped at your max HP, 50)

**YELLOW operation points (player)**
- `OP` = base x 2 ^ (yellow cards - 1) → 1 yellow = x1, 2 = x2, 3 = x4, 4 = x8
- 1 OP = one Workbench card move (one place left or right). OP accumulates and survives damage

**CARD COST — the damage number IS the cost (paid in OP)**
- Every card's `cost` = its printed damage value
- `★ SPECIAL` (cards with 8+ damage) costs that damage value in OP: an 8-damage card costs 8 OP, a 10-damage card costs 10 OP
- Activating a special discards that card and every same-color card in hand, then redraws — no turn is used
- With too few OP the activation is refused: no card is spent and no OP is lost

**NIGHT self-damage**
- `penalty` = (sum of the NEXT card damage of all 3 slots) x 10 ^ (same-color cards - 1) → 2 same color = x10, 3 = x100, 4 = x1000
- The BLUE shield absorbs it first, then HP

**Other**
- Negative words grant no trait value (traits use the positive base total)
- YELLOW: grants OP (see above) / WILDCARD "?": 0 damage, matches any letter, keeps its own color
- Enemy HP: stage 1 = 30, +15 max HP per stage / Defeat at player HP 0, COMPLETE after 10 turns

### Winning Strategy Tips
1. **Plan ahead**: Look at the NEXT cards in slots to anticipate incoming self-damage (see NIGHT self-damage in Calculation Formulas)
2. **Color matching**: Try to use cards of the same color for multipliers
3. **Manage slots**: Consider which slots to use (used slots will rotate to their next card)
4. **Wildcards**: Save wildcards for difficult letter combinations
5. **Watch your HP**: Take too much self-damage during the NIGHT phase and you are defeated
6. **Stage resets**: Hand and slot reels are re-dealt when you clear a stage — spend key cards before the finishing blow

## Controls
- **Click card**: Add to workbench
- **Drag card**: Drag and drop to workbench
- **Click workbench card**: Remove from workbench
- **Long-press or right-click a ★ card in hand**: pay its damage value in OP to activate its special ability
- **CLEAR**: Remove all cards from workbench
- **SUBMIT WORD**: Submit your word for scoring
- **FORMULAS**: Show/hide the calculation formulas and the breakdown of your last word
- **OP gauge** (gold panel right of the HP bars): always shows the OP you own, how many card moves that buys ("= N MOVES"), and a bar; it pops and floats "+N OP" when you gain OP. Hover it for the full rule.

## Technical Details
- Built with Godot Engine
- Uses GDScript
- Dictionary-based word validation
- Tween animations for slot rotations
