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

### Enemy Parts (break the name, not just the HP bar)

The enemy's name is also its **body**. It is sliced left to right into a few non-overlapping **parts** of 2+ letters, and spelling a part inside any word you submit **destroys that part**. Destroying **every** part kills the enemy outright — whatever HP it has left — and pays a **RELIC**.

- **How the name is cut**: 2-letter slices, with a 1-letter tail folded into the slice before it. `DRAGON → DR / AG / ON`, `SLIME → SL / IME`, `STONE → ST / ONE`, `PHOENIX → PH / OE / NIX`. This keeps an enemy to **1-4 readable parts** instead of one part per substring (a 6-letter name would otherwise expose 14)
- **Matching**: the part must appear in the submitted word **in full and in order**. `DR` breaks on `DRIFT` and on `DRAFT`, but **not** on `DEAR` (the D and R are apart) and **not** on a lone `D`. Case is ignored, exactly like the rest of the word checks
- **One word can break several parts**: submitting `DRAGON` breaks all three of `DR / AG / ON` at once
- **A broken part is never restored** by spelling the same letters again — the part stays down until that enemy dies
- **Total destruction ignores HP entirely**: an enemy on 87 / 100 HP falls just the same. This is a **second route to a defeat**, alongside "damage it to 0 HP"; both go through the same stage-clear, so the reels, the hand redraw and the enemy-skill wipe all behave identically
- **Only a total destruction pays a relic.** Killing an enemy by damage (HP to 0) is a plain kill and pays **no** relic — even if the same word happened to spell its parts
- **Parts never carry over.** The next enemy always arrives whole
- **Where to see it**: a `PARTS` strip under the enemy HP bar shows each part, with the destroyed ones struck through in red (`PARTS DR AG ON (2 / 3 intact)`). The submit preview flags a coming total destruction before you commit, and the **FORMULAS** panel has the full rules

> **Relics are permanent buffs.** A relic is earned only by a total part destruction, and lasts for the rest of the run. They are re-applied at every stage clear and every reward, so nothing is silently lost, and they stack with each other and with the stage rewards.

| Relic | Effect |
|---|---|
| **IRON CORE** | 戦闘開始時、シールド10を得る。 |
| **OPENING HAND** | 戦闘開始時、最初の手札を2枚多く引く。 |
| **EXPANDED POCKET** | 手札上限+1。 |
| **VESSEL** | 最大HP+6（同時にその分だけ回復）。 |
| **INSIGHT** | その場で4 OPを得る。 |

- **IRON CORE** pays out once as each fight opens — not on a turn change, and not on a word submit. It uses the normal player shield, so the words can stack more on top of it
- **OPENING HAND** adds 2 cards to the opening deal only. The standing hand limit is **not** raised: from turn 2 the hand behaves exactly as it always did, and the 2 bonus cards stay in hand as extra options
- **EXPANDED POCKET** is a standing +1. It composes with the enemy skill `HAND DOWN` rather than fighting it: base 7 + EXPANDED POCKET +1 = 8, and `HAND DOWN` then takes it to 7. A stage clear wipes the enemy effect but keeps the relic

The type is drawn at random from the catalogue each time, and duplicates stack. The **`RELICS` panel to the left of the HP bars is always on screen**, so you can check what you hold at any time — it lists every relic (collapsing a stack to `IRON CORE x2`) and hovering it shows each effect and which enemy it came from. The **FORMULAS** panel carries the same list in full, and the `RELIC OBTAINED!` message spells out what you just gained.

### Enemy Skills (one card out of the nine)
Every enemy is built out of the letters of its own name, and **one of those letters carries a skill**. That letter is dealt to the shared reels as **exactly one card out of the nine**, and **the skill fires at NIGHT while that card sits in the BOTTOM row of a reel**.

- **Spelling the letter does nothing — the POSITION is the trigger.** Use that letter in a word, or click the card: unless it is in the bottom row, nothing happens
- It fires **only at night**. A day turn never triggers it
- The card is listed under the HP bars (`STAGE … | DANGER: [B]AEGIS — slot 2 BOTTOM`, or `— safe`), and it is outlined in **orange with a ⚠ mark** while it is in the firing line, so you can always see whether tonight is dangerous
- **There is only one such card**, so the threat is always in exactly one known place. The other eight cards are safe
- **Getting it out of the bottom row is the player's job.** Press that reel's **SPIN button** (1 OP for the first spin of a turn, then 10 OP, then 100 OP — three spins per turn), or submit a word that uses that reel, and the reel rolls the card away. Do it before night falls
- **Your Deck**: Every game starts with the **same fixed 20-card deck** — five per colour, so the opening is always the same balanced spread. These are PLAYER cards: whatever letter the enemy binds its skill to, the skill card is a different card on the shared reels, so the deck is never affected. Note that **Q and X cannot be dealt as cards at all** (they are reward-only), so they are never chosen as the skill letter
- **A killing blow lands first.** If your word defeats the enemy, no skill fires — the fight ends before the enemy can answer
- **A `?` wildcard can never BE the skill card.** A wildcard is not the enemy's letter
- Skills get stronger every stage, and are capped so a deep run stays playable

| Skill | Effect |
|---|---|
| **AEGIS** | The enemy raises a shield that absorbs damage **before** its HP. Shown as `[ENEMY SHIELD n]` |
| **HAND DOWN** | Your hand holds fewer cards (never below 3). Extra cards go to the graveyard, so nothing is destroyed |
| **DRAIN** | The enemy drinks operation points (never below 0) |
| **NIGHTMARE** | Adds a flat amount to the NIGHT self-damage **base**, so the same-color multiplier still scales it |
| **REGROWTH** | The enemy repairs some of its own HP (never past its max) |

**Nothing survives a stage clear.** The moment an enemy dies, its shield, its night tax and its shrunken hand are all wiped and the hand is dealt back to full — the next enemy starts clean. The **only** thing that carries over is damage you have already taken, because that is HP you can heal back.

### Rewards (Enemy Defeat)
| Reward | Effect |
|---|---|
| **★ SPECIAL CARD** | Adds the **specific ★ special shown** to your deck, with its power and OP cost spelled out |
| **BURN A CARD** | **You pick the card**: a picker opens with every card you own — click one to remove it |
| **VITALITY** (HP) | Restore HP (25% of max, minimum 10) |
| **BARRIER** (SH) | Gain 8 shield |
| **INSIGHT** (OP) | Gain 5 operation points |
| **IRON WILL** (MAX) | Max HP +5 (heals the same amount) |
| **WILDCARDS** (???) | Add **3 wildcard (?) cards** to your deck |

- **The card reward only ever hands over a ★ SPECIAL.** A plain letter card would be filler that plays no differently from the fixed 20 you already have, so the real choice is *which power to take* rather than whether the roll happened to be interesting. The card is rolled up front and shown face-up, so the one you are offered is the one you get
- **WILDCARDS gives three "?" cards at 0 damage.** Each still carries a colour, so it counts toward that colour's multiplier; what it buys is flexibility, standing in for whichever letter you are missing
- **BURN A CARD is the opposite: nothing is decided for you.** Taking it opens a picker listing your whole deck — draw pile, hand *and* spent pile — each drawn in its own colour and tagged with the pile it came from. Click the one you want gone and only that card is removed
- A **★ special** in the picker spells out its power and its price, so you never burn one blind
- You can press **BACK TO REWARDS** in the picker to change your mind; the reward is not spent until you click a card, and the three options come back exactly as they were
- There are always **three** options, at least one of which is a deck change (add/remove) while the deck size allows
- The deck is clamped to **5-40 cards**; when the draw pile runs out the graveyard is shuffled back in, so the draw never breaks
- **Negative damage**: reduces your HP (never below 0). If your HP reaches 0, it's GAME OVER (DEFEAT).
- **Result**: after 10 turns the game ends (COMPLETE) and you are evaluated by stage reached, total damage dealt and enemies defeated.

## Game Rules

### Basic Setup
- **3 Slot Reels**: Each slot contains 3 cards that can be rotated
- **7 Hand Cards**: Cards you can use to fill in letters
- **Card Pool & Deck**: The pool holds 99 card types; each game starts from a **fixed 20-card deck** (see above) rather than a random draw. When the draw pile runs out, the graveyard is shuffled back into the deck.
- **Player HP**: 50 / **Enemy HP**: 30 for stage 1 (grows +15 per stage)
- **Stages**: Defeat the enemy to advance to the next stage; your hand and the shared slot reels are fully reset on each stage change
- **10 Turns**: Game ends after 10 turns
- **Enemy & Shared Cards**: Each enemy gets a random name from the dictionary (3-9 letters). The shared slot reels are built from that enemy's name letters (any shortage is filled by random draws) and are handled separately from your deck.
- **Dictionary**: Only valid English words are accepted. The word list lives in **`word_dictionary.json`** (416,292 words in total) together with a Japanese gloss table. It is generated from `dictionary.txt` by `build_word_json.py`; if the JSON is missing or malformed the game falls back to reading `dictionary.txt` directly, so it always runs.

### How to Play
1. Click or drag cards from slots (marked with ★ ACTIVE) or your hand to the Workbench
2. Arrange cards to form a valid word — **drag a card into the gap you want it in**, or click to append it
3. Click SUBMIT WORD to deal damage with your word
4. Used slots rotate to the next card
5. Used hand cards are discarded and replaced from the deck
6. Defeat the enemy (reduce its HP to 0) to clear the stage — the next stage starts, your hand is redrawn and all three shared reels roll to the new enemy's cards

### Your fixed 20-card deck
Every game starts with **exactly these twenty cards**, five per colour. They are **player cards**: whatever letter the enemy binds its skill to, the skill card is a *different* card on the shared reels, so your deck is never touched by it.

| Colour | Role | Cards |
|---|---|---|
| 🔴 **RED** | damage multiplier | A / T / E / M / S |
| 🔵 **BLUE** | shield | E / N / L / P / I |
| 🟢 **GREEN** | heal | A / R / D / G / O |
| 🟡 **YELLOW** | operation points | T / C / B / Y / E |

Rewards still add and burn cards from here on, so the deck is a starting point rather than a straitjacket.

### Inspecting your deck
- **CARD PILES** (bottom button) opens the deck viewer at any time during a fight
- It splits your cards into three separately counted sections — **DRAW PILE**, **HAND** and **GRAVEYARD** — and draws **every card individually**, so you can see exactly what is still waiting to be drawn
- The draw pile is listed sorted by letter so the contents are readable without revealing the order the cards will actually be dealt in
- **VIEW MY DECK** (or the **D** key) does the same from the reward screen, and the reward choices stay open behind it, so you can weigh "add this card" against what you already own

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

1. **`word_dictionary.json`** — the bundled glossary. It is instant, needs no network, and works in every export (including Web). Only words that actually have a gloss are listed (no empty entries), and a word with no entry simply falls through to step 2. A translated word is stored **only** under `translations`, never in `words`, so the two sections are disjoint; the game treats their union as the accepted word list.
2. **Jisho** (jisho.org) — used for everything the bundled glossary does not have. The request and its result ranking are described below.

> Currently the bundled glossary covers **98,813 words**, essentially the whole alphabetical list: the first 3000 entries carry real Japanese glosses where a settled rendering exists (`data/head3000.json`), and the rest of the list is covered too, so `CAT`, `AND`, `THE`, `ABBACY`, `ABANDONMENT`, `ACCUMULATE` and `ACETYLENE` are translated instantly and offline, while anything else goes to Jisho.
>
> Words with no settled Japanese rendering — the tail of this range is overwhelmingly chemical trivial names, Latin taxonomic names and place/person names — are tagged with their category instead of left blank, so you see e.g. `Achariaceae` → `科名（生物の分類群）` and `acetanilide` → `化学化合物`. Adding more words means adding a line to the source table and re-running `build_word_json.py` — no code change. That script **merges into** the existing `word_dictionary.json` rather than rebuilding it, so glosses already in the file are kept.

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
- **DISCARD & DRAW needs an empty Workbench.** It throws away a card *at random* — one you never picked — so it is refused while any card is on the Workbench, and the card is greyed out with the reason in its tooltip. Clear the board first. The refusal is free: no OP is spent and the card stays in hand. Every other special works with cards on the Workbench.
- **⟳ SPIN a shared reel**: each of the three shared reels has its own **SPIN** button underneath it. Pressing it advances **that one reel by a single step**, so the card showing as `→ NEXT` becomes the new `★ ACTIVE` card, and the reel scrolls with the same animation used at end of turn. The other two reels are left alone, so you can nudge a bad reel without giving up a good one. The OP are only spent when the spin actually happens.
- **Spinning is capped at 3 per turn, and the price climbs: 1 OP, then 10 OP, then 100 OP.** The button re-reads the price on every refresh and reads `NO SPINS` once the turn's allowance is gone. The reels are the player's only lever over which letters turn up, so the third spin costs far more than a normal turn earns — it is a real decision, not a routine action.
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
- **AEGIS**: the enemy's shield soaks the hit first; only the remainder lowers its HP. Whatever the word used that letter still raises the shield afterwards
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
- NIGHTMARE adds its value to that base before the multiplier is applied
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

## Project Layout

```
src/            game code
  Main.gd/.tscn   the scene and all of its UI wiring
  core/           GameManager.gd (rules, autoload), JishoClient.gd (autoload)
  ui/             DraggableCard.gd, WorkbenchDropZone.gd
data/           word_dictionary.json (runtime), dictionary.txt (fallback), head3000.json
tests/          every test; run a .tscn headless, see below
  fixtures/       canned Jisho API responses
tools/          build_word_json.py, deck_simulation.py (offline helpers)
fonts/          the bundled Japanese font
```

Run a test scene headless:

```
godot --headless --path . res://tests/_spin_test.tscn
```

Two older checks are `SceneTree` scripts rather than scenes, so they take `--script`:

```
godot --headless --path . --script res://tests/_special_cost_test.gd
```

## Technical Details
- Built with Godot Engine
- Uses GDScript
- Dictionary-based word validation
- Tween animations for slot rotations
