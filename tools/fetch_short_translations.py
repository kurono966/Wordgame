"""Pin a redistributable Wiktionary/WordNet compilation; retain source HTML.

The builder selects only Wiktionary senses with explicit Japanese equivalents
and English definitions. WordNet's Japanese-definition senses are not used.
"""
import gzip
import hashlib
import io
import json
import struct
import zipfile
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'tools/translation_sources'
URL = 'https://github.com/DanielGregorini/koreader-dicts/releases/download/v1.2.0/en-ja.zip'


def main():
    cache = ROOT / 'tools/_translation_deps/source_cache/en-ja-v1.2.0.zip'
    cache.parent.mkdir(parents=True, exist_ok=True)
    if not cache.exists():
        with urlopen(URL, timeout=120) as response:
            cache.write_bytes(response.read())
    payload = cache.read_bytes()
    manifest_path = DEST / 'short_manifest.json'
    pinned = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    digest = hashlib.sha256(payload).hexdigest()
    assert not pinned or digest == pinned['archive_sha256'], 'upstream archive changed'
    archive = zipfile.ZipFile(io.BytesIO(payload))
    index = archive.read('en-ja/en-ja.idx')
    data = gzip.decompress(archive.read('en-ja/en-ja.dict.dz'))
    rows, cursor = [], 0
    while cursor < len(index):
        end = index.index(b'\0', cursor)
        word = index[cursor:end].decode('utf-8')
        offset, size = struct.unpack('>II', index[end + 1:end + 9])
        cursor = end + 9
        if word.isascii() and word.isalpha() and word.islower():
            rows.append([word, data[offset:offset + size].decode('utf-8')])
    subset = gzip.compress(json.dumps(rows, ensure_ascii=False, separators=(',', ':')).encode(), mtime=0)
    (DEST / 'short_dictionary.json.gz').write_bytes(subset)
    for name in ('ATTRIBUTION', 'LICENSE', 'README.txt'):
        (DEST / ('ShortDictionary-' + name)).write_bytes(archive.read('en-ja/' + name))
    manifest = {'url': URL, 'archive_sha256': digest, 'subset_sha256': hashlib.sha256(subset).hexdigest(),
                'entries': len(rows), 'license': 'CC-BY-SA-4.0',
                'source': 'English Wiktionary contributors via Kaikki/wiktextract and DanielGregorini/koreader-dicts v1.2.0',
                'changes': 'Lowercase alphabetic headwords selected; original entry HTML retained.'}
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps({'entries': len(rows), 'compressed_bytes': len(subset)}))


if __name__ == '__main__':
    main()
