"""Read-only vocabulary audit; outputs decisions, never a replacement dictionary."""
import argparse
import csv
import gzip
import hashlib
import itertools
import json
import random
import re
import sys
import tarfile
import zipfile
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/_translation_deps'))
from wordfreq import zipf_frequency
from lemminflect import getAllInflections

SOURCES = ROOT / 'tools/filter_sources'
TOKEN = re.compile(r'[a-z]+')


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_sources(config):
    scowl, proper, upper = {}, set(), set()
    with tarfile.open(SOURCES / 'scowl-release-2020.12.07.tar.gz') as archive:
        for member in archive.getmembers():
            if not member.isfile():
                continue
            name = member.name.split('/')[-1]
            if member.name == 'scowl-2020.12.07/Copyright':
                (SOURCES / 'SCOWL-Copyright.txt').write_bytes(archive.extractfile(member).read())
            if '/final/' not in member.name or '.' not in name:
                continue
            category, level = name.rsplit('.', 1)
            if not level.isdigit():
                continue
            match = re.fullmatch(r'(.+?)(?:_variant_(\d))?-(words|proper-names|upper|abbreviations|contractions)', category)
            if not match or match[1] not in config['scowl_regions']:
                continue
            if int(match[2] or 0) > config['scowl_max_variant']:
                continue
            for original in archive.extractfile(member).read().decode('iso-8859-1').splitlines():
                word = original.lower()
                if not TOKEN.fullmatch(word):
                    continue
                if match[3] == 'proper-names':
                    proper.add(word)
                elif match[3] in ('upper', 'abbreviations') or original != word:
                    upper.add(word)
                else:
                    scowl[word] = min(scowl.get(word, 999), int(level))
    wordnet, exceptions, sensitive = set(), defaultdict(set), set()
    with zipfile.ZipFile(SOURCES / 'wordnet.zip') as archive:
        (SOURCES / 'WordNet-LICENSE.txt').write_bytes(archive.read('wordnet/LICENSE'))
        for pos in ('noun', 'verb', 'adj', 'adv'):
            for line in archive.read('wordnet/index.' + pos).decode().splitlines():
                if line and not line.startswith(' '):
                    word = line.split()[0]
                    if TOKEN.fullmatch(word):
                        wordnet.add(word)
            for line in archive.read('wordnet/' + pos + '.exc').decode().splitlines():
                form, *lemmas = line.split()
                if TOKEN.fullmatch(form):
                    exceptions[form].update(w for w in lemmas if TOKEN.fullmatch(w))
            for line in archive.read('wordnet/data.' + pos).decode().splitlines():
                if not line or line.startswith(' ') or ' | ' not in line:
                    continue
                fields, gloss = line.split(' | ', 1)
                definition = gloss.split('; "', 1)[0]
                if re.search(r'offensive term|derogatory term|vulgar term|racial slur|ethnic slur', definition, re.I):
                    parts = fields.split()
                    for i in range(int(parts[3], 16)):
                        word = parts[4 + i * 2].lower()
                        if TOKEN.fullmatch(word):
                            sensitive.add(word)
    ejdict = set()
    for path in (ROOT / 'tools/translation_sources').glob('src_*.txt'):
        for line in path.read_text(encoding='utf-8-sig').splitlines():
            if '\t' in line:
                ejdict.update(w.strip() for w in line.split('\t', 1)[0].split(',') if TOKEN.fullmatch(w.strip()))
    assert len(scowl) > 100000 and len(wordnet) > 50000 and len(ejdict) > 20000, 'missing/incomplete sources'
    return scowl, proper, upper, wordnet, exceptions, sensitive, ejdict


def game_impact(groups, config):
    code = (ROOT / 'src/core/GameManager.gd').read_text(encoding='utf-8')
    minimum = int(re.search(r'const NAME_MIN_LEN: int = (\d+)', code)[1])
    maximum = int(re.search(r'const NAME_MAX_LEN: int = (\d+)', code)[1])
    card_code = code.split('const CARD_DEFS: Array = [', 1)[1].split('\n]', 1)[0]
    pool = re.findall(r'"letter":\s*"([A-Z*?]+)"', card_code)
    counts = Counter(letter.lower() for letter in pool if len(letter) == 1 and letter.isalpha())
    assert counts and sum(counts.values()) >= 70
    scenarios = {'current': set.union(*groups.values()),
                 'candidates_removed_preview': groups['accept'] | groups['hold'],
                 'accepted_only_preview': groups['accept']}
    result = {}
    rng = random.Random(config['simulation_seed'])
    # Seven literal letter cards sampled from the real pool, shared across
    # scenarios. Excludes wildcards and the nine shared-slot cards: a diagnostic,
    # not a simulation of overall game win rate.
    literal_pool = list(counts.elements())
    racks = [rng.sample(literal_pool, 7) for _ in range(config['simulation_samples'])]
    for name, words in scenarios.items():
        enemies = sorted(w for w in words if TOKEN.fullmatch(w) and minimum <= len(w) <= maximum)
        letters = Counter(''.join(enemies))
        signatures = {''.join(sorted(w)) for w in words if TOKEN.fullmatch(w) and 3 <= len(w) <= 7}
        playable = 0
        for rack in racks:
            found = False
            for length in range(3, 8):
                if any(''.join(sorted(part)) in signatures for part in itertools.combinations(rack, length)):
                    found = True
                    break
            playable += found
        shortages = sum(any(n > counts[ch] for ch, n in Counter(w).items()) for w in enemies)
        result[name] = {'words': len(words), 'translated': 0, 'enemy_candidates': len(enemies),
                        'mean_enemy_length': round(sum(map(len, enemies)) / len(enemies), 3) if enemies else 0,
                        'enemy_letter_percent': {ch: round(100 * letters[ch] / max(1, sum(letters.values())), 3) for ch in 'abcdefghijklmnopqrstuvwxyz'},
                        'enemy_name_pool_shortage_count': shortages,
                        'literal_7_card_playable_percent': round(100 * playable / len(racks), 2),
                        'missing_enemy_letters': [ch for ch in 'abcdefghijklmnopqrstuvwxyz' if not letters[ch]]}
    result['diagnostic'] = {'literal_card_counts': dict(sorted(counts.items())), 'samples': len(racks),
                            'note': 'No wildcards/shared slots/skills; pool shortages are handled by game filler, not a failure.'}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=ROOT / 'tools/word_filter_config.json')
    parser.add_argument('--input', type=Path, default=ROOT / 'data/word_dictionary.json')
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--limit', type=int, default=0, help='frequency-prioritized sample; never modifies game data')
    args = parser.parse_args()
    if args.output_dir is None:
        args.output_dir = ROOT / ('tools/word_filter_current_report' if (SOURCES / 'applied_filter.json').exists() else 'tools/word_filter_report')
    config = read_json(args.config)
    assert 0 < config['scowl_max_size'] <= 95 and config['candidate_max_zipf_exclusive'] < config['accept_zipf']
    path = args.input
    file_hash = digest(path)
    payload = gzip.decompress(path.read_bytes()) if path.suffix == '.gz' else path.read_bytes()
    original_hash = hashlib.sha256(payload).hexdigest()
    data = json.loads(payload)
    translations = data['translations']
    all_words = set(data['words']) | set(translations)
    assert not set(data['words']) & set(translations)
    for name, item in read_json(SOURCES / 'manifest.json').items():
        assert digest(SOURCES / name) == item['sha256'], 'source hash mismatch: ' + name
    scowl, proper, upper, wordnet, exceptions, sensitive, ejdict = load_sources(config)
    frequency = {w: zipf_frequency(w, 'en') for w in all_words | set(scowl) | wordnet | ejdict}
    votes = lambda w: int(w in scowl) + int(w in wordnet) + int(w in ejdict)
    strong = {w for w in set(scowl) | wordnet | ejdict | all_words if TOKEN.fullmatch(w)
              and (scowl.get(w, 999) <= config['scowl_max_size'] or frequency[w] >= config['accept_zipf']
                   or votes(w) >= config['minimum_dictionary_votes'])}
    morphology = {}
    for lemma in sorted(strong):
        for tag, forms in getAllInflections(lemma).items():
            if tag not in ('NNS', 'VBD', 'VBN', 'VBG', 'VBZ', 'JJR', 'JJS', 'RBR', 'RBS'):
                continue
            for form in forms:
                if form in all_words and form != lemma:
                    morphology.setdefault(form, lemma)
    for form, lemmas in sorted(exceptions.items()):
        trusted = sorted(lemmas & strong)
        if form in all_words and trusted:
            morphology.setdefault(form, trusted[0])
    sensitive |= {form for form, lemma in morphology.items() if lemma in sensitive}
    targets = sorted(all_words, key=lambda w: (-frequency[w], w))[:args.limit] if args.limit else sorted(all_words)
    groups = {name: set() for name in ('accept', 'hold', 'candidate')}
    reasons, examples, flags_count = Counter(), defaultdict(list), Counter()
    example_rng = random.Random(config['simulation_seed'])
    args.output_dir.mkdir(parents=True, exist_ok=True)
    manual = {k: set(config['manual_' + k]) for k in groups}
    assert not (manual['accept'] & manual['hold'] or manual['accept'] & manual['candidate'] or manual['hold'] & manual['candidate'])
    assert set.union(*manual.values()) <= all_words, 'manual override contains unknown words'
    with (args.output_dir / 'decisions.tsv').open('w', encoding='utf-8', newline='') as handle:
        writer = csv.writer(handle, delimiter='\t', lineterminator='\n')
        writer.writerow(['word', 'decision', 'reason', 'zipf', 'scowl_size', 'wordnet', 'ejdict', 'dictionary_votes', 'lemma', 'translated', 'review_flags'])
        for word in targets:
            f, count = frequency[word], votes(word)
            flags = []
            if word in proper: flags.append('proper_name_evidence')
            if word in upper: flags.append('uppercase_or_abbreviation_evidence')
            if word in sensitive: flags.append('potentially_offensive_sense')
            if not TOKEN.fullmatch(word): flags.append('non_ascii_or_nonletter')
            if len(word) > 18 and f < config['accept_zipf']: flags.append('long_rare_review')
            for flag in flags: flags_count[flag] += 1
            if word in manual['hold']: decision, reason = 'hold', 'manual_hold'
            elif word in manual['accept']: decision, reason = 'accept', 'manual_accept'
            elif word in sensitive: decision, reason = 'hold', 'potentially_offensive_review'
            elif scowl.get(word, 999) <= config['scowl_max_size']: decision, reason = 'accept', 'scowl_core'
            elif f >= config['accept_zipf']: decision, reason = 'accept', 'frequent'
            elif word in morphology: decision, reason = 'accept', 'attested_inflection'
            elif count >= config['minimum_dictionary_votes']: decision, reason = 'accept', 'multiple_dictionaries'
            elif word in manual['candidate']: decision, reason = 'candidate', 'manual_candidate'
            elif config['hold_existing_translations'] and word in translations: decision, reason = 'hold', 'existing_translation_review'
            elif count: decision, reason = 'hold', 'single_dictionary_review'
            elif f >= config['candidate_max_zipf_exclusive']: decision, reason = 'hold', 'low_frequency_review'
            elif flags and 'non_ascii_or_nonletter' in flags: decision, reason = 'hold', 'token_format_review'
            else: decision, reason = 'candidate', 'no_dictionary_extremely_low_frequency'
            groups[decision].add(word)
            reasons[decision + ':' + reason] += 1
            if len(examples[decision + ':' + reason]) < config['sample_limit']:
                examples[decision + ':' + reason].append(word)
            else:
                index = example_rng.randrange(reasons[decision + ':' + reason])
                if index < config['sample_limit']:
                    examples[decision + ':' + reason][index] = word
            writer.writerow([word, decision, reason, f, scowl.get(word, ''), int(word in wordnet), int(word in ejdict), count, morphology.get(word, ''), int(word in translations), ','.join(flags)])
    assert set.union(*groups.values()) == set(targets)
    assert sum(map(len, groups.values())) == len(targets)
    for name, words in groups.items():
        (args.output_dir / (name + '.txt')).write_text('\n'.join(sorted(words)) + '\n', encoding='utf-8')
    impact = game_impact(groups, config)
    for name, words in [('current', set(targets)), ('candidates_removed_preview', groups['accept'] | groups['hold']), ('accepted_only_preview', groups['accept'])]:
        impact[name]['translated'] = len(words & set(translations))
    source_paths = [SOURCES / n for n in read_json(SOURCES / 'manifest.json')]
    source_paths += sorted((ROOT / 'tools/translation_sources').glob('src_*.txt'))
    report = {'total_current_words': len(all_words), 'evaluated': len(targets), 'counts': {k: len(v) for k, v in groups.items()},
              'reasons': dict(sorted(reasons.items())), 'examples': dict(sorted(examples.items())), 'review_flags': dict(flags_count),
              'config': config, 'input_sha256': original_hash,
              'source_sha256': {p.relative_to(ROOT).as_posix(): digest(p) for p in source_paths},
              'source_versions': {'scowl': '2020.12.07', 'wordnet': '3.0 (NLTK mirror)', 'wordfreq': '3.1.1', 'lemminflect': '0.2.3'},
              'impact': impact, 'game_dictionary_modified': False}
    (args.output_dir / 'summary.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    text = ['# Vocabulary audit (no deletions)', '', f'Current: {len(all_words):,}; evaluated: {len(targets):,}.', '',
            '| Decision | Count |', '|---|---:|']
    text += [f'| {k} | {len(v):,} |' for k, v in groups.items()]
    text += ['', '## Reasons and representative examples', '']
    text += [f'- {k}: {n:,}; examples: {", ".join(examples[k])}' for k, n in sorted(reasons.items())]
    text += ['', '## Game impact (hypothetical previews)', '', '| Scenario | Words | Enemy names | Mean length | Literal 7-card playable % |', '|---|---:|---:|---:|---:|']
    text += [f'| {k} | {v["words"]:,} | {v["enemy_candidates"]:,} | {v["mean_enemy_length"]} | {v["literal_7_card_playable_percent"]} |' for k, v in impact.items() if k != 'diagnostic']
    text += ['', 'Card definitions are unchanged. This rack diagnostic excludes shared slots, skills and wildcards; it is not overall game difficulty.',
             'Detailed per-letter distributions and pool shortages are in summary.json.',
             'Name/abbreviation flags are review signals, not proof. Frequency/SCOWL acceptance does not certify age appropriateness.',
             'Candidates are proposals only. Absence from dictionaries does not prove a typo; uncertain or singly attested words are held.',
             'All game translations and vocabulary remain unchanged. See ../WORD_FILTER.md for licenses and methodology.', '']
    (args.output_dir / 'REPORT.md').write_text('\n'.join(text), encoding='utf-8')
    assert digest(path) == file_hash, 'input data unexpectedly changed'
    print(json.dumps({'current': len(all_words), 'evaluated': len(targets), **{k: len(v) for k, v in groups.items()}, 'game_dictionary_modified': False}))


if __name__ == '__main__':
    main()
