"""Apply the reviewed candidate snapshot with hash checks and lossless backups."""
import gzip
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'tools/word_filter_report'
BACKUP = ROOT / 'tools/filter_backups'
RECORD = ROOT / 'tools/filter_sources/applied_filter.json'
EXCLUSIONS = ROOT / 'tools/filter_sources/applied_exclusions.txt'


def sha(payload):
    return hashlib.sha256(payload).hexdigest()


def fallback_bytes(original, remaining):
    """Keep legacy line order, spelling and line endings while aligning its set."""
    result, seen = [], set()
    for line in original.splitlines(keepends=True):
        word = line.decode('utf-8').strip().lower()
        if word in remaining and word not in seen:
            result.append(line)
            seen.add(word)
    assert seen == remaining, 'JSON contains words absent from legacy fallback'
    return b''.join(result)


def main():
    source = ROOT / 'data/word_dictionary.json'
    legacy = ROOT / 'data/dictionary.txt'
    original = source.read_bytes()
    report = json.loads((REPORT / 'summary.json').read_text(encoding='utf-8'))
    candidate_bytes = (REPORT / 'candidate.txt').read_bytes()
    candidates = set(candidate_bytes.decode('utf-8').splitlines())
    if RECORD.exists():
        record = json.loads(RECORD.read_text(encoding='utf-8'))
        assert sha(candidate_bytes) == record['candidate_sha256']
        assert sha(original) == record['after_sha256'], 'dictionary changed since application'
        assert sha(legacy.read_bytes()) == record['legacy_after_sha256']
        print('Already applied; verified dictionary and fallback hashes.')
        return
    assert sha(original) == report['input_sha256'], 'audit is stale; do not apply'
    assert len(candidates) == report['counts']['candidate'] == 20268
    data = json.loads(original)
    accepted = set(data['words']) | set(data['translations'])
    assert candidates <= accepted and not candidates & set(data['translations'])
    remaining = accepted - candidates
    result = {'words': sorted(remaining - set(data['translations'])), 'translations': dict(sorted(data['translations'].items()))}
    payload = (json.dumps(result, ensure_ascii=False, indent='\t') + '\n').encode('utf-8')
    fallback = fallback_bytes(legacy.read_bytes(), remaining)
    BACKUP.mkdir(exist_ok=True)
    for path in (source, legacy, ROOT / 'data/translation_coverage.json'):
        target = BACKUP / (path.name + '.gz')
        assert not target.exists(), 'refusing to overwrite backup'
        target.write_bytes(gzip.compress(path.read_bytes(), mtime=0))
    EXCLUSIONS.write_bytes(candidate_bytes)
    source.write_bytes(payload)
    legacy.write_bytes(fallback)
    record = {'before': len(accepted), 'removed': len(candidates), 'after': len(remaining),
              'translations_preserved': len(data['translations']), 'before_sha256': sha(original),
              'after_sha256': sha(payload), 'legacy_after_sha256': sha(fallback),
              'candidate_sha256': sha(candidate_bytes),
              'accepted_set_sha256': sha('\n'.join(sorted(remaining)).encode('utf-8')),
              'backup_directory': 'tools/filter_backups',
              'note': 'JSON minus reviewed candidates; legacy fallback synchronized to the same accepted set.'}
    RECORD.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(record))


if __name__ == '__main__':
    main()
