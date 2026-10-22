"""Fetch pinned, redistributable audit inputs. No extraction or game edits."""
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen

DEST = Path(__file__).resolve().parent / 'filter_sources'
URLS = {
    'scowl-release-2020.12.07.tar.gz': 'https://deb.debian.org/debian/pool/main/s/scowl/scowl_2020.12.07.orig.tar.gz',
    'wordnet.zip': 'https://raw.githubusercontent.com/nltk/nltk_data/gh-pages/packages/corpora/wordnet.zip',
}
EXPECTED = {
    'scowl-release-2020.12.07.tar.gz': '5587667caa20c4891390c2d42dbb4d5c4c3f41bee77af1457ece3ba23fb859cc',
    'wordnet.zip': 'cbda5ea6eef7f36a97a43d4a75f85e07fccbb4f23657d27b4ccbc93e2646ab59',
}


def main():
    DEST.mkdir(exist_ok=True)
    manifest = {}
    for name, url in URLS.items():
        path = DEST / name
        if not path.exists():
            with urlopen(Request(url, headers={'User-Agent': 'Wordgame-vocabulary-audit'}), timeout=90) as response:
                payload = response.read()
            assert hashlib.sha256(payload).hexdigest() == EXPECTED[name], 'unexpected source revision: ' + name
            path.write_bytes(payload)
        assert hashlib.sha256(path.read_bytes()).hexdigest() == EXPECTED[name], 'modified source: ' + name
        manifest[name] = {'url': url, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
        print(name, path.stat().st_size)
    (DEST / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
