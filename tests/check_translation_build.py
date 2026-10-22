"""Full invariants plus small, meaningful translation regression samples."""
import gzip
import hashlib
import json
import sys
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import expand_translations as build


def main():
    baseline = json.loads(gzip.decompress((build.SOURCE / 'baseline.json.gz').read_bytes()))
    output = build.load(ROOT / 'data/word_dictionary.json')
    provenance = build.load(ROOT / 'data/translation_provenance.json')
    report = build.load(ROOT / 'data/translation_coverage.json')
    accepted = set(baseline['words']) | set(baseline['translations'])
    assert len(accepted) == 397561
    assert set(output['words']) | set(output['translations']) == accepted
    assert not set(output['words']) & set(output['translations'])
    assert all(output['translations'][w] == v for w, v in baseline['translations'].items())
    added = set(output['translations']) - set(baseline['translations'])
    assert added == set(provenance)
    assert report['added'] == len(added)
    assert sum(r['total'] for r in report['frequency_bands'].values()) == len(accepted)
    assert sum(r['after'] for r in report['frequency_bands'].values()) == len(output['translations'])
    for name, digest in report['source_sha256'].items():
        assert hashlib.sha256((build.SOURCE / name).read_bytes()).hexdigest() == digest, name
    for w in added:
        text = output['translations'][w]
        assert build.JP.search(text) and '\ufffd' not in text, w
        assert text.count('／') <= 2, w
    for word, expected in {'manga': '漫画', 'foreseen': '予知', 'peeking': 'のぞく',
                           'burritos': 'ブリトー', 'monies': '金', 'yanked': '引っ張る'}.items():
        assert expected in output['translations'][word], word
    for word in ('foreseen', 'peeking', 'yanked'):
        assert provenance[word]['method'] == 'attested_inflection', word
    assert 'zzzznotaword' not in accepted
    # Source case and context must not manufacture translations for names,
    # prefixes, and glosses whose short English text needs an explanation.
    for word in ('obama', 'william', 'lang', 'jun'):
        assert word not in added, word
    assert 'いっそうよい' not in output['translations'].get('bettor', '')
    assert build.senses('《古》古語 / 『日常語』 / =reference') == ['日常語']
    if '--web-pack' in sys.argv:
        check_pack(output)
    print(f'PASS: vocabulary {len(accepted)}, preserved {len(baseline["translations"])}, added {len(added)}; coverage, hashes, POS/inflection samples and exclusions')


def check_pack(expected):
    """Inspect the actual unencrypted Godot v3 PCK directory and payloads."""
    pack = (ROOT / 'tests/translation_web_build/index.pck').read_bytes()
    magic, version = struct.unpack_from('<II', pack)
    assert magic == 0x43504447 and version == 3
    base, cursor = struct.unpack_from('<QQ', pack, 24)
    count = struct.unpack_from('<I', pack, cursor)[0]
    cursor += 4
    files = {}
    for _ in range(count):
        length = struct.unpack_from('<I', pack, cursor)[0]
        cursor += 4
        path = pack[cursor:cursor + length].rstrip(b'\0').decode()
        cursor += length
        offset, size = struct.unpack_from('<QQ', pack, cursor)
        digest = pack[cursor + 16:cursor + 32]
        flags = struct.unpack_from('<I', pack, cursor + 32)[0]
        cursor += 36
        assert not flags & 1, 'encrypted file cannot be inspected'
        data = pack[base + offset:base + offset + size]
        assert hashlib.md5(data).digest() == digest, path
        files[path] = data
    assert json.loads(files['data/word_dictionary.json']) == expected
    for path in (ROOT / 'data/licenses').iterdir():
        assert files['data/licenses/' + path.name] == path.read_bytes(), path.name
    assert files['data/DICTIONARY_LICENSES.txt'] == (ROOT / 'data/DICTIONARY_LICENSES.txt').read_bytes()
    assert not any(p.startswith(('tools/', 'tests/')) for p in files)
    print('PASS: Web PCK payloads match dictionary and all license files; build dependencies excluded')


if __name__ == '__main__':
    main()
