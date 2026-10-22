#!/usr/bin/env python3
"""Explicit network refresh; normal translation builds are fully offline."""
import argparse
import concurrent.futures
import json
from pathlib import Path
from urllib.request import Request, urlopen

DEST = Path(__file__).resolve().parent / 'translation_sources'


def fetch(url):
    with urlopen(Request(url, headers={'User-Agent': 'Wordgame-dictionary-build'}), timeout=90) as response:
        return response.read()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ejdict-revision', default=(DEST / 'revision.txt').read_text().strip())
    args = parser.parse_args()
    revision = json.loads(fetch('https://api.github.com/repos/kujirahand/EJDict/commits/' + args.ejdict_revision))['sha']
    base = f'https://raw.githubusercontent.com/kujirahand/EJDict/{revision}/'
    urls = {f'src_{chr(c)}.txt': base + f'src/{chr(c)}.txt' for c in range(97, 123)}
    urls.update({'LICENSE': base + 'LICENSE', 'README.md': base + 'README.md',
                 'JMdict_e.gz': 'https://www.edrdg.org/pub/Nihongo/JMdict_e.gz',
                 'EDRDG-licence.html': 'https://www.edrdg.org/edrdg/licence.html',
                 'JMdict-documentation.html': 'https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project'})
    # Download everything before replacing any snapshot file.
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        downloaded = dict(zip(urls, pool.map(fetch, urls.values())))
    for name, content in downloaded.items():
        (DEST / name).write_bytes(content)
    (DEST / 'revision.txt').write_text(revision, encoding='utf-8')
    licenses = DEST.parents[1] / 'data/licenses'
    for name in ('EDRDG-licence.html', 'JMdict-documentation.html'):
        (licenses / name).write_bytes(downloaded[name])
    (licenses / 'EJDict-CC0.txt').write_bytes(downloaded['LICENSE'])
    print(f'Refreshed {len(downloaded)} source files; EJDict {revision}. Rebuild and review before release.')


if __name__ == '__main__':
    main()
