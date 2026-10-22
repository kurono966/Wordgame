"""Audit invariants, inflection regressions, configurable overrides, determinism."""
import csv
import gzip
import hashlib
import json
import subprocess
import sys
import tarfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'tools/word_filter_report'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    source = ROOT / 'data/word_dictionary.json'
    data = json.loads(source.read_text(encoding='utf-8'))
    original_hash = sha(source)
    audit_input = source
    applied = ROOT / 'tools/filter_sources/applied_filter.json'
    if applied.exists():
        record = json.loads(applied.read_text(encoding='utf-8'))
        audit_input = ROOT / 'tools/filter_backups/word_dictionary.json.gz'
        before = gzip.decompress(audit_input.read_bytes())
        baseline = json.loads(before)
        removed = set((ROOT / 'tools/filter_sources/applied_exclusions.txt').read_text(encoding='utf-8').splitlines())
        assert len(removed) == record['removed'] == 20268
        assert all(data['translations'].get(w) == value for w, value in baseline['translations'].items())
        assert set(data['words']) | set(data['translations']) == (set(baseline['words']) | set(baseline['translations'])) - removed
        current_words = set(data['words']) | set(data['translations'])
        assert hashlib.sha256('\n'.join(sorted(current_words)).encode()).hexdigest() == record['accepted_set_sha256']
        assert {w.strip().lower() for w in (ROOT / 'data/dictionary.txt').read_text(encoding='utf-8').splitlines()} == current_words
        data = baseline
    words = set(data['words']) | set(data['translations'])
    report = json.loads((REPORT / 'summary.json').read_text(encoding='utf-8'))
    assert report['input_sha256'] == (hashlib.sha256(before).hexdigest() if applied.exists() else original_hash)
    assert report['evaluated'] == report['total_current_words'] == len(words)
    decisions, reasons, counts = {}, Counter(), Counter()
    with (REPORT / 'decisions.tsv').open(encoding='utf-8') as handle:
        for row in csv.DictReader(handle, delimiter='\t'):
            word, choice = row['word'], row['decision']
            assert word not in decisions
            decisions[word] = choice
            counts[choice] += 1
            reasons[choice + ':' + row['reason']] += 1
            if choice == 'candidate':
                assert float(row['zipf']) < report['config']['candidate_max_zipf_exclusive']
                assert row['dictionary_votes'] == '0' and row['translated'] == '0'
                assert not row['lemma'] and not row['scowl_size']
            if 'potentially_offensive_sense' in row['review_flags']:
                assert choice == 'hold'
    assert set(decisions) == words
    assert counts == report['counts'] and reasons == report['reasons']
    for group in counts:
        listed = (REPORT / (group + '.txt')).read_text(encoding='utf-8').splitlines()
        assert len(listed) == counts[group] == len(set(listed))
        assert all(decisions[w] == group for w in listed)
    for word in ('children', 'mice', 'geese', 'went', 'gone', 'running', 'walked', 'better', 'best', 'applied', 'apply'):
        assert decisions[word] == 'accept', word
    assert report['impact']['current']['enemy_candidates'] == 226217
    preview = report['impact']['candidates_removed_preview']
    assert preview['words'] == len(words) - counts['candidate']
    assert preview['translated'] == len(data['translations'])
    assert not preview['missing_enemy_letters']
    for path, value in report['source_sha256'].items():
        assert sha(ROOT / path) == value, path
    snapshot = {p.name: sha(p) for p in REPORT.iterdir() if p.is_file()}
    subprocess.run([sys.executable, str(ROOT / 'tools/audit_word_dictionary.py'), '--input', str(audit_input), '--output-dir', str(REPORT)], check=True, stdout=subprocess.DEVNULL)
    assert snapshot == {p.name: sha(p) for p in REPORT.iterdir() if p.is_file()}, 'non-deterministic report'
    with tarfile.open(ROOT / 'tools/filter_sources/scowl-release-2020.12.07.tar.gz') as archive:
        assert (ROOT / 'tools/filter_sources/SCOWL-Copyright.txt').read_bytes() == archive.extractfile('scowl-2020.12.07/Copyright').read()
    temporary = ROOT / 'tools/_filter_sample/override_check'
    temporary.mkdir(parents=True, exist_ok=True)
    config = dict(report['config'], manual_hold=['the'], simulation_samples=20)
    config_path = temporary / 'config.json'
    config_path.write_text(json.dumps(config), encoding='utf-8')
    subprocess.run([sys.executable, str(ROOT / 'tools/audit_word_dictionary.py'), '--config', str(config_path),
                    '--input', str(audit_input), '--limit', '20', '--output-dir', str(temporary)], check=True, stdout=subprocess.DEVNULL)
    with (temporary / 'decisions.tsv').open(encoding='utf-8') as handle:
        rows = {r['word']: r for r in csv.DictReader(handle, delimiter='\t')}
    assert rows['the']['decision'] == 'hold' and rows['the']['reason'] == 'manual_hold'
    assert sha(source) == original_hash, 'game dictionary was modified'
    print(f'PASS: {len(words)} decisions; disjoint/complete groups, candidate safeguards, inflections, translations, game diagnostics, source hashes, byte-identical rebuild, config override; game data unchanged')


if __name__ == '__main__':
    main()
