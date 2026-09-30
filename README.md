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
- **Rewards**: after every enemy defeat you pick **1 of 3** rewards before the next fight. Deck rewards are always in the pool while the deck size allows, so you can grow or slim your deck between stages.

### Rewards (Enemy Defeat)
| Reward | Effect |
|---|---|
| **ADD A CARD** | Adds the **specific card shown** to your deck (no strike-through) |
| **BURN A CARD** | **You pick the card**: a picker opens with every card you hold — click one to remove it |
| **VITALITY** (HP) | Restore HP (25% of max, minimum 10) |
| **BARRIER** (SH) | Gain 8 shield |
| **INSIGHT** (OP) | Gain 5 operation points |
| **IRON WILL** (MAX) | Max HP +5 (heals the same amount) |
| **CARD DRAW** (DR) | Draw a card into hand |

- **ADD A CARD is rolled up front and shown face-up.** You are not picking freely from the card pool — you are offered one specific card
- The card you are shown is always the card you get. If identical copies exist, any of them counts
- **BURN A CARD is the opposite: nothing is decided for you.** Taking it opens a picker listing every card in your draw pile *and* your hand, each drawn in its own colour. Click the one you want gone and only that card is removed
- You can press **BACK TO REWARDS** in the picker to change your mind; the reward is not spent until you click a card
- Burned cards are gone for good. The graveyard is not offered, because those cards get shuffled back into the draw pile
- There are always **three** options, at least one of which is a deck change (add/remove) while the deck size allows
- The deck is clamped to **5-40 cards**; when the draw pile runs out the graveyard is shuffled back in, so the draw never breaks
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
- **Dictionary**: Only valid English words are accepted. The word list lives in **`word_dictionary.json`** (416,292 words) together with a Japanese gloss table. It is generated from `dictionary.txt` by `build_word_json.py`; if the JSON is missing or malformed the game falls back to reading `dictionary.txt` directly, so it always runs.

### How to Play
1. Click or drag cards from slots (marked with ★ ACTIVE) or your hand to the Workbench
2. Arrange cards to form a valid word
3. Click SUBMIT WORD to deal damage with your word
4. Used slots rotate to the next card
5. Used hand cards are discarded and replaced from the deck
6. Defeat the enemy (reduce its HP to 0) to clear the stage — the next stage starts, your hand is redrawn and all three shared reels roll to the new enemy's cards

### Submit Preview (damage forecast)
A line above the buttons shows, **while you are still building the word**, exactly what SUBMIT will cost you. It updates every time you add or remove a card on the Workbench.

- It resolves the same word assignment that SUBMIT would use, so the numbers always match the real result
- It shows the enemy damage, the BLUE shield / GREEN heal your word grants, the NIGHT penalty, and the final `HP you lose -> HP after`
- **The shared reels rotate as part of submitting**, so the NIGHT penalty is previewed from the cards that will be NEXT *after* that rotation. Using a slot can therefore change the forecast — the label notes how many reels roll
- Colour codes the risk: green = you take no damage, yellow = you lose HP, red = **this submit would defeat you (LETHAL)**
- It also flags a Workbench that is not a valid word, so you can see SUBMIT will be rejected

### Word Meanings (bundled glossary, then Jisho API)
While a valid word sits on the Workbench, a line above the damage forecast shows its **English → Japanese** translation.

The lookup happens in two steps:

1. **`word_dictionary.json`** — the bundled glossary. It is instant, needs no network, and works in every export (including Web). Only words that actually have a gloss are listed (no empty entries), and a word with no entry simply falls through to step 2.
2. **Jisho** (jisho.org) — used for everything the bundled glossary does not have. The request and its result ranking are described below.

> Currently the bundled glossary covers **252 words**: every common 3-letter-or-shorter word plus the sample set. So a short word (`CAT`, `AND`, `THE`…) is translated instantly and offline, while a longer word goes to Jisho. Adding more words means adding a line to `build_word_json.py` and re-running it — no code change.

> Jisho:
>
> ```
> GOAT   →   山羊 (やぎ)  Noun
>                 goat
> ```
>
> A bundled-glossary hit looks like this instead (no headword, no network):
>
> ```
> CAT    →   猫
> ```

- The headword is shown in gold and the English glosses in pale blue (two separate labels — Godot 4's `Label` cannot render BBCode, so no markup is used)
- Jisho's search is a **full-text search over English glosses**, so a raw lookup returns unrelated words too (searching "goat" also matches 未 "the Ram; the Goat", and the top hit is not always a translation at all). Entries are therefore scored so the word shown **actually translates the word you built**:
  - a gloss that equals the word, or equals it minus an article ("the Goat"), outranks everything else
  - scraped "Wikipedia definition" entries are ignored — they are article summaries, not translations
  - pure-kanji headwords are preferred over counter/compound forms (五 over 五つ) and kana readings (ゴート)
  - singular and plural both work: Jisho lists inflections together (`["eggs", "egg", "spawn", "roe"]` for 卵), so they are compared as the same lemma, and the exact form you searched is shown first
  - a word with no genuine translation is reported as untranslated instead of showing an unrelated entry
- Lookups are **cached**, so a word is only ever fetched once
- It updates as you change the word, and a late answer for an abandoned word is discarded instead of overwriting the current one
- Misses and network failures are reported inline and are also cached, so the game never stalls or retries in a loop
- **Web export limitation**: jisho.org sends no `Access-Control-Allow-Origin` header, so browsers block the request. The **bundled glossary still works** in a Web export (it is a local file), so short words are translated there; only the Jisho fallback is unavailable, and the line says so. Use a CORS proxy if you need the fallback in the browser.

### Slot Rotation
- Only slots that are used in your word will rotate: the ★ ACTIVE card you used is spent and the reel rolls so that its NEXT card becomes ACTIVE
- The card you place in the workbench is always the card that gets consumed — a shared card you used is never silently substituted by a hand card, so the reel you used is guaranteed to rotate
- When a stage is cleared, all three reels roll to reveal the shared cards of the new enemy

### Day/Night Phases
The game alternates between DAY and NIGHT phases each turn:

**DAY Phase**: No incoming damage
**NIGHT Phase**: At the start of the turn, you take damage equal to the total damage values of the NEXT cards in all slots

The turn on which you defeat an enemy is exempt: no NIGHT self-damage is applied that turn

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
- **⟳ SPIN a shared reel**: each of the three shared reels has its own **SPIN 1 OP** button underneath it. Pressing it advances **that one reel by a single step**, so the card showing as `→ NEXT` becomes the new `★ ACTIVE` card, and the reel scrolls with the same animation used at end of turn. The other two reels are left alone, so you can nudge a bad reel without giving up a good one. The OP are only spent when the spin actually happens.
  - A reel whose ACTIVE card is **already on your Workbench cannot be spun** — that would silently change the word you are building. Clear the card first (or the button stays greyed out with the reason in its tooltip).
  - Spinning costs no turn, and a full three-card cycle returns the reel to where it started — there is no way to shuffle for free.
  - OP comes from YELLOW word cards and the **INSIGHT** reward, so spending it on a spin is a real trade-off against using **SPECIAL**.

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
- `heal` = base x 2 ^ (green cards - 1) → 1 green = x1, 2 green = x2, 3 green = x4, 4 green = x8 (capped at your current max HP, 50 at the start of a game and raised by the IRON WILL reward)

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
- **The turn on which you defeat an enemy deals no damage**: the fight is over, so the NIGHT penalty of that turn is skipped (the submit preview shows `NIGHT 0 dmg (enemy defeated)`). This exemption applies to that turn only — the next turn is charged normally

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
- **OP gauge** (gold panel right of the HP bars): always shows the OP you own, how many card moves that buys ("= N MOVES"), and a bar; it pops and floats "+N OP" when you gain OP and "-N OP" when a special is paid for. Hover it for the full rule.

## Technical Details
- Built with Godot Engine
- Uses GDScript
- Dictionary-based word validation
- Tween animations for slot rotations
