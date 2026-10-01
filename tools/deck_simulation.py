#!/usr/bin/env python3
"""
Deck Simulation for Word Card Game
Optimizes deck composition for balanced gameplay
"""

import os
import random
import json
from collections import Counter, defaultdict
from typing import Dict, List, Tuple, Set
from dataclasses import dataclass
from enum import Enum

# Configuration
HAND_SIZE = 5
SIMULATION_ITERATIONS = 10
MIN_WORD_LENGTH = 3
MAX_WORD_LENGTH = 10

# Vowels
VOWELS = set('AEIOU')

# Rare letters
RARE_LETTERS = set('QXZ')

# Initial deck composition (100 cards)
INITIAL_DECK = {
    'A': 9, 'E': 12, 'I': 8, 'O': 7, 'U': 4,
    'B': 2, 'C': 4, 'D': 5, 'F': 2, 'G': 3, 'H': 5,
    'J': 1, 'K': 1, 'L': 5, 'M': 3, 'N': 6, 'P': 3,
    'Q': 1, 'R': 6, 'S': 7, 'T': 8, 'V': 2, 'W': 2,
    'X': 1, 'Y': 2, 'Z': 1
}

@dataclass
class SimulationMetrics:
    """Metrics from a simulation run"""
    playable_hand_rate: float  # % of hands with at least one 3+ letter word
    dead_hand_rate: float  # % of hands with no 3+ letter words
    avg_word_count: float  # average number of 3+ letter words per hand
    avg_longest_word: float  # average longest word length per hand
    vowel_distribution: Dict[int, float]  # % of hands with 0-5 vowels
    rare_letter_playable: Dict[str, float]  # % of hands with Q/X/Z that can form a word
    rare_letter_multi_rate: float  # % of hands with 2+ rare letters
    avg_vowel_count: float  # average vowels per hand

class SafetySystem:
    """Safety systems for preventing bad hands"""
    def __init__(self, vowel_protection=False, rare_letter_protection=False, dead_hand_protection=False):
        self.vowel_protection = vowel_protection
        self.rare_letter_protection = rare_letter_protection
        self.dead_hand_protection = dead_hand_protection

class DictionaryLoader:
    """Load and filter dictionary"""
    
    def __init__(self, dictionary_path: str):
        self.dictionary_path = dictionary_path
        self.words: Set[str] = set()
        self.word_index: Dict[str, Set[str]] = defaultdict(set)  # letter -> words containing it
        
    def load(self) -> Set[str]:
        """Load and filter dictionary"""
        print(f"Loading dictionary from {self.dictionary_path}...")
        
        valid_words = set()
        excluded_count = 0
        line_count = 0
        
        try:
            with open(self.dictionary_path, 'r', encoding='utf-8') as f:
                for line in f:
                    line_count += 1
                    if line_count % 50000 == 0:
                        print(f"  Processed {line_count} lines...")
                    
                    word = line.strip().upper()
                    
                    # Filter criteria
                    if len(word) < MIN_WORD_LENGTH or len(word) > MAX_WORD_LENGTH:
                        excluded_count += 1
                        continue
                    if '-' in word or "'" in word:
                        excluded_count += 1
                        continue
                    if any(c.isdigit() for c in word):
                        excluded_count += 1
                        continue
                    if not word.isalpha():
                        excluded_count += 1
                        continue
                    
                    valid_words.add(word)
        except FileNotFoundError:
            print(f"Dictionary file not found at {self.dictionary_path}")
            # Use fallback words
            fallback_words = [
                "THE", "BE", "TO", "OF", "AND", "A", "IN", "THAT", "HAVE", "I",
                "IT", "FOR", "NOT", "ON", "WITH", "HE", "AS", "YOU", "DO", "AT",
                "THIS", "BUT", "HIS", "BY", "FROM", "THEY", "WE", "SAY", "HER", "SHE",
                "OR", "AN", "WILL", "MY", "ONE", "ALL", "WOULD", "THERE", "THEIR", "WHAT",
                "SO", "UP", "OUT", "IF", "ABOUT", "WHO", "GET", "WHICH", "GO", "ME",
                "WHEN", "MAKE", "CAN", "LIKE", "TIME", "NO", "JUST", "HIM", "KNOW", "TAKE",
                "CAT", "DOG", "CAR", "BUS", "HAT", "BAT", "RAT", "MAT", "SAT", "PAT",
                "RED", "BLUE", "GREEN", "YELLOW", "GOLD", "GAME", "PLAY", "CARD", "HAND", "SLOT"
            ]
            for word in fallback_words:
                if MIN_WORD_LENGTH <= len(word) <= MAX_WORD_LENGTH:
                    valid_words.add(word)
        
        print(f"Loaded {len(valid_words)} valid words from {line_count} lines (excluded {excluded_count})")
        
        # Build letter index
        print("Building letter index...")
        for word in valid_words:
            for letter in set(word):
                self.word_index[letter].add(word)
        
        self.words = valid_words
        return valid_words
    
    def can_form_word(self, hand: List[str], allow_wildcard: bool = False) -> Tuple[bool, List[str]]:
        """Check if hand can form any valid word"""
        hand_letters = Counter(hand)
        possible_words = []
        
        for word in self.words:
            word_letters = Counter(word)
            
            # Check if hand has required letters
            can_form = True
            for letter, count in word_letters.items():
                if hand_letters[letter] < count:
                    if allow_wildcard and '?' in hand_letters:
                        # Use wildcard for missing letter
                        continue
                    can_form = False
                    break
            
            if can_form:
                possible_words.append(word)
        
        return len(possible_words) > 0, possible_words

class DeckSimulator:
    """Simulate deck compositions"""
    
    def __init__(self, dictionary: DictionaryLoader):
        self.dictionary = dictionary
        self.deck: Dict[str, int] = {}
    
    def create_deck(self, composition: Dict[str, int]) -> List[str]:
        """Create deck from composition"""
        deck = []
        for letter, count in composition.items():
            deck.extend([letter] * count)
        return deck
    
    def draw_hand(self, deck: List[str]) -> List[str]:
        """Draw a random hand from deck"""
        return random.sample(deck, HAND_SIZE)
    
    def count_vowels(self, hand: List[str]) -> int:
        """Count vowels in hand"""
        return sum(1 for card in hand if card in VOWELS)
    
    def count_rare_letters(self, hand: List[str]) -> int:
        """Count rare letters (Q, X, Z) in hand"""
        return sum(1 for card in hand if card in RARE_LETTERS)
    
    def simulate_hand(self, deck: List[str], safety_system: SafetySystem = None) -> Dict:
        """Simulate a single hand"""
        hand = self.draw_hand(deck)
        
        # Apply safety systems
        if safety_system and safety_system.vowel_protection:
            vowel_count = self.count_vowels(hand)
            if vowel_count == 0:
                # Replace one card with a vowel
                vowels_in_deck = [c for c in deck if c in VOWELS]
                if vowels_in_deck:
                    replacement = random.choice(vowels_in_deck)
                    hand[random.randint(0, HAND_SIZE-1)] = replacement
        
        can_play, possible_words = self.dictionary.can_form_word(hand)
        
        return {
            'hand': hand,
            'can_play': can_play,
            'word_count': len(possible_words),
            'longest_word': max(len(w) for w in possible_words) if possible_words else 0,
            'vowel_count': self.count_vowels(hand),
            'rare_count': self.count_rare_letters(hand),
            'has_q': 'Q' in hand,
            'has_x': 'X' in hand,
            'has_z': 'Z' in hand
        }
    
    def simulate_deck(self, composition: Dict[str, int], 
                      iterations: int = SIMULATION_ITERATIONS,
                      safety_system: SafetySystem = None) -> SimulationMetrics:
        """Run full simulation on a deck composition"""
        deck = self.create_deck(composition)
        
        results = []
        vowel_counts = Counter()
        rare_playable = {'Q': 0, 'X': 0, 'Z': 0}
        rare_letter_counts = Counter()
        
        for _ in range(iterations):
            result = self.simulate_hand(deck, safety_system)
            results.append(result)
            vowel_counts[result['vowel_count']] += 1
            rare_letter_counts[result['rare_count']] += 1
            
            if result['has_q'] and result['can_play']:
                rare_playable['Q'] += 1
            if result['has_x'] and result['can_play']:
                rare_playable['X'] += 1
            if result['has_z'] and result['can_play']:
                rare_playable['Z'] += 1
        
        # Calculate metrics
        playable_hands = sum(1 for r in results if r['can_play'])
        total_hands = len(results)
        
        playable_hand_rate = (playable_hands / total_hands) * 100
        dead_hand_rate = 100 - playable_hand_rate
        avg_word_count = sum(r['word_count'] for r in results) / total_hands
        avg_longest_word = sum(r['longest_word'] for r in results) / total_hands
        avg_vowel_count = sum(r['vowel_count'] for r in results) / total_hands
        
        # Vowel distribution
        vowel_distribution = {}
        for i in range(HAND_SIZE + 1):
            vowel_distribution[i] = (vowel_counts[i] / total_hands) * 100
        
        # Rare letter playable rate
        has_q = sum(1 for r in results if r['has_q'])
        has_x = sum(1 for r in results if r['has_x'])
        has_z = sum(1 for r in results if r['has_z'])
        
        rare_letter_playable_rate = {
            'Q': (rare_playable['Q'] / has_q * 100) if has_q > 0 else 0,
            'X': (rare_playable['X'] / has_x * 100) if has_x > 0 else 0,
            'Z': (rare_playable['Z'] / has_z * 100) if has_z > 0 else 0
        }
        
        # Multi rare letter rate
        rare_multi_rate = (rare_letter_counts[2] + rare_letter_counts[3]) / total_hands * 100
        
        return SimulationMetrics(
            playable_hand_rate=playable_hand_rate,
            dead_hand_rate=dead_hand_rate,
            avg_word_count=avg_word_count,
            avg_longest_word=avg_longest_word,
            vowel_distribution=vowel_distribution,
            rare_letter_playable=rare_letter_playable_rate,
            rare_letter_multi_rate=rare_multi_rate,
            avg_vowel_count=avg_vowel_count
        )

class DeckOptimizer:
    """Generate and compare deck configurations"""
    
    def __init__(self, dictionary: DictionaryLoader):
        self.dictionary = dictionary
        self.simulator = DeckSimulator(dictionary)
    
    def generate_candidate(self, name: str, composition: Dict[str, int]) -> Tuple[str, Dict[str, int], SimulationMetrics]:
        """Generate and test a candidate deck"""
        print(f"\nTesting candidate: {name}")
        metrics = self.simulator.simulate_deck(composition)
        return name, composition, metrics
    
    def generate_candidates(self) -> List[Tuple[str, Dict[str, int], SimulationMetrics]]:
        """Generate multiple candidate decks"""
        candidates = []
        
        # 1. BALANCED - Close to initial but optimized
        balanced = {
            'A': 10, 'E': 12, 'I': 8, 'O': 8, 'U': 5,
            'B': 2, 'C': 4, 'D': 5, 'F': 2, 'G': 3, 'H': 5,
            'J': 1, 'K': 1, 'L': 5, 'M': 3, 'N': 6, 'P': 3,
            'Q': 1, 'R': 6, 'S': 7, 'T': 8, 'V': 2, 'W': 2,
            'X': 1, 'Y': 2, 'Z': 1
        }
        candidates.append(self.generate_candidate("BALANCED", balanced))
        
        # 2. VOCABULARY - More vowels for word formation
        vocabulary = {
            'A': 11, 'E': 13, 'I': 9, 'O': 9, 'U': 6,
            'B': 2, 'C': 3, 'D': 4, 'F': 2, 'G': 2, 'H': 4,
            'J': 1, 'K': 1, 'L': 4, 'M': 2, 'N': 5, 'P': 3,
            'Q': 1, 'R': 5, 'S': 6, 'T': 7, 'V': 2, 'W': 2,
            'X': 1, 'Y': 2, 'Z': 1
        }
        candidates.append(self.generate_candidate("VOCABULARY", vocabulary))
        
        # 3. VOWEL_HEAVY - Very vowel-focused
        vowel_heavy = {
            'A': 12, 'E': 14, 'I': 10, 'O': 10, 'U': 8,
            'B': 1, 'C': 2, 'D': 3, 'F': 1, 'G': 2, 'H': 3,
            'J': 1, 'K': 1, 'L': 3, 'M': 2, 'N': 4, 'P': 2,
            'Q': 1, 'R': 4, 'S': 5, 'T': 5, 'V': 1, 'W': 1,
            'X': 1, 'Y': 1, 'Z': 1
        }
        candidates.append(self.generate_candidate("VOWEL_HEAVY", vowel_heavy))
        
        # 4. RARE_LETTER - More rare letters (but not too many)
        rare_letter = {
            'A': 9, 'E': 11, 'I': 7, 'O': 7, 'U': 4,
            'B': 2, 'C': 4, 'D': 5, 'F': 2, 'G': 3, 'H': 5,
            'J': 2, 'K': 2, 'L': 5, 'M': 3, 'N': 6, 'P': 3,
            'Q': 2, 'R': 6, 'S': 7, 'T': 8, 'V': 2, 'W': 2,
            'X': 2, 'Y': 2, 'Z': 2
        }
        candidates.append(self.generate_candidate("RARE_LETTER", rare_letter))
        
        # 5. HYBRID - Balanced with slight rare letter boost
        hybrid = {
            'A': 10, 'E': 12, 'I': 8, 'O': 8, 'U': 5,
            'B': 2, 'C': 4, 'D': 5, 'F': 2, 'G': 3, 'H': 5,
            'J': 1, 'K': 1, 'L': 5, 'M': 3, 'N': 6, 'P': 3,
            'Q': 1, 'R': 6, 'S': 7, 'T': 8, 'V': 2, 'W': 2,
            'X': 1, 'Y': 2, 'Z': 1
        }
        candidates.append(self.generate_candidate("HYBRID", hybrid))
        
        # 6. CONSONANT_BALANCED - Better consonant distribution
        consonant_balanced = {
            'A': 9, 'E': 11, 'I': 7, 'O': 7, 'U': 4,
            'B': 3, 'C': 4, 'D': 5, 'F': 2, 'G': 3, 'H': 5,
            'J': 1, 'K': 1, 'L': 6, 'M': 3, 'N': 7, 'P': 4,
            'Q': 1, 'R': 7, 'S': 7, 'T': 8, 'V': 2, 'W': 2,
            'X': 1, 'Y': 2, 'Z': 1
        }
        candidates.append(self.generate_candidate("CONSONANT_BALANCED", consonant_balanced))
        
        return candidates
    
    def compare_candidates(self, candidates: List[Tuple[str, Dict[str, int], SimulationMetrics]]) -> None:
        """Print comparison table"""
        print("\n" + "="*120)
        print("CANDIDATE COMPARISON")
        print("="*120)
        
        header = f"{'Name':<20} {'Playable%':<10} {'Dead%':<10} {'AvgWords':<10} {'AvgLongest':<12} {'Vowel0%':<10} {'Vowel4+%':<10} {'Rare2+%':<10}"
        print(header)
        print("-"*120)
        
        for name, composition, metrics in candidates:
            row = f"{name:<20} {metrics.playable_hand_rate:<10.2f} {metrics.dead_hand_rate:<10.2f} {metrics.avg_word_count:<10.2f} {metrics.avg_longest_word:<12.2f} {metrics.vowel_distribution[0]:<10.2f} {metrics.vowel_distribution[4] + metrics.vowel_distribution[5]:<10.2f} {metrics.rare_letter_multi_rate:<10.2f}"
            print(row)
        
        print("\n" + "="*120)
        print("VOWEL DISTRIBUTION DETAIL")
        print("="*120)
        
        for name, composition, metrics in candidates:
            print(f"\n{name}:")
            for i in range(HAND_SIZE + 1):
                print(f"  {i} vowels: {metrics.vowel_distribution[i]:.2f}%")
        
        print("\n" + "="*120)
        print("RARE LETTER PLAYABILITY")
        print("="*120)
        
        for name, composition, metrics in candidates:
            print(f"\n{name}:")
            for letter in ['Q', 'X', 'Z']:
                print(f"  {letter} playable when in hand: {metrics.rare_letter_playable[letter]:.2f}%")
    
    def select_best(self, candidates: List[Tuple[str, Dict[str, int], SimulationMetrics]]) -> Tuple[str, Dict[str, int]]:
        """Select best candidate based on criteria"""
        best_score = -1
        best_candidate = None
        
        for name, composition, metrics in candidates:
            # Scoring system
            score = 0
            
            # Playable hand rate (target: >95%)
            if metrics.playable_hand_rate >= 95:
                score += 100
            else:
                score += metrics.playable_hand_rate
            
            # Dead hand rate (target: <5%)
            if metrics.dead_hand_rate <= 5:
                score += 50
            else:
                score -= metrics.dead_hand_rate * 10
            
            # Vowel 0 rate (target: <5%)
            if metrics.vowel_distribution[0] <= 5:
                score += 30
            else:
                score -= metrics.vowel_distribution[0] * 5
            
            # Vowel 4+ rate (target: low but not zero)
            vowel_4plus = metrics.vowel_distribution[4] + metrics.vowel_distribution[5]
            if 5 <= vowel_4plus <= 15:
                score += 20
            elif vowel_4plus > 20:
                score -= 10
            
            # Average longest word (target: >=4)
            if metrics.avg_longest_word >= 4:
                score += 20
            else:
                score -= (4 - metrics.avg_longest_word) * 10
            
            # Rare letter multi rate (target: low)
            if metrics.rare_letter_multi_rate <= 5:
                score += 20
            else:
                score -= metrics.rare_letter_multi_rate * 5
            
            # Rare letter playability (target: >50%)
            avg_rare_playable = sum(metrics.rare_letter_playable.values()) / 3
            if avg_rare_playable >= 50:
                score += 30
            else:
                score -= (50 - avg_rare_playable)
            
            print(f"{name}: Score = {score}")
            
            if score > best_score:
                best_score = score
                best_candidate = (name, composition)
        
        return best_candidate

def generate_godot_deck(composition: Dict[str, int]) -> str:
    """Generate Godot-compatible deck data"""
    lines = []
    lines.append("# Optimized deck composition for Word Game")
    lines.append("# Total: 100 cards")
    lines.append("")
    
    for letter in sorted(composition.keys()):
        count = composition[letter]
        lines.append(f"{letter}: {count}")
    
    return "\n".join(lines)

def main():
    print("="*60)
    print("DECK SIMULATION FOR WORD CARD GAME")
    print("="*60)
    
    # Load dictionary. Both paths are resolved from the repo root so the script
    # behaves the same whichever directory it is run from.
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    dict_loader = DictionaryLoader(os.path.join(repo_root, "data", "dictionary.txt"))
    dict_loader.load()
    
    # Generate and test candidates
    optimizer = DeckOptimizer(dict_loader)
    candidates = optimizer.generate_candidates()
    
    # Compare candidates
    optimizer.compare_candidates(candidates)
    
    # Select best
    print("\n" + "="*120)
    print("SELECTING BEST CANDIDATE")
    print("="*120)
    best_name, best_composition = optimizer.select_best(candidates)
    
    print(f"\nSelected: {best_name}")
    print("\nFinal Deck Composition:")
    for letter in sorted(best_composition.keys()):
        print(f"  {letter} = {best_composition[letter]}")
    
    # Test with safety systems
    print("\n" + "="*120)
    print("TESTING WITH SAFETY SYSTEMS")
    print("="*120)
    
    safety_configs = [
        ("No Safety", SafetySystem(False, False, False)),
        ("Vowel Protection", SafetySystem(True, False, False)),
        ("Rare Letter Protection", SafetySystem(False, True, False)),
        ("Full Protection", SafetySystem(True, True, True))
    ]
    
    for config_name, safety_system in safety_configs:
        print(f"\n{config_name}:")
        metrics = optimizer.simulator.simulate_deck(best_composition, safety_system=safety_system)
        print(f"  Playable: {metrics.playable_hand_rate:.2f}%")
        print(f"  Dead Hand: {metrics.dead_hand_rate:.2f}%")
        print(f"  Vowel 0%: {metrics.vowel_distribution[0]:.2f}%")
    
    # Generate Godot output
    print("\n" + "="*120)
    print("GODOT COMPATIBLE OUTPUT")
    print("="*120)
    godot_output = generate_godot_deck(best_composition)
    print(godot_output)
    
    # Save to file. The deck is a GENERATED artefact of this tool, so it goes to
    # tools/ (git-ignored) rather than being committed each run.
    out_path = os.path.join(repo_root, "tools", "optimized_deck.txt")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(godot_output)
    print("\nSaved to %s" % out_path)

if __name__ == "__main__":
    main()
