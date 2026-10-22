"""Conservative Wiktionary supplementation, shortest words first, no LLM."""
import gzip
import html
import json
import re
from collections import defaultdict
from pathlib import Path

SOURCE = Path(__file__).resolve().parent / 'translation_sources'
JP = re.compile(r'[ぁ-んァ-ヶ一-龯]')
LABEL = {'n.': '名', 'v.': '動', 'adj.': '形', 'adv.': '副', 'interj.': '間', 'prep.': '前', 'conj.': '接', 'pron.': '代'}
TAGS = {'NNS': ('n.', '複数形'), 'VBD': ('v.', '過去形'), 'VBN': ('v.', '過去分詞'),
        'VBG': ('v.', '現在分詞'), 'VBZ': ('v.', '三人称単数現在'),
        'JJR': ('adj.', '比較級'), 'JJS': ('adj.', '最上級'),
        'RBR': ('adv.', '比較級'), 'RBS': ('adv.', '最上級')}
MARKED = re.compile(r'\b(?:obsolete|archaic|rare|dated|offensive|derogatory|vulgar|slur|historical|dialectal|surname|given name|initialism|acronym|abbreviation|genus|taxonomic)\b', re.I)


def plain(text):
    return html.unescape(re.sub('<[^>]+>', '', text)).strip()


def entries(japanese_frequency):
    result = {}
    rows = json.loads(gzip.decompress((SOURCE / 'short_dictionary.json.gz').read_bytes()))
    for word, entry in rows:
        senses = []
        for pos, block in re.findall(r'<div><i>([^<]+)</i>(.*?)</div>', entry):
            if pos not in LABEL:
                continue
            for sense in re.split(r'(?:<br/>)?<span style="color:#666666">\d+\.</span>', block)[1:]:
                match = re.search(r'<b>(.*?)</b> <span style="color:#666666">&mdash; (.*?)</span>', sense)
                if not match:
                    continue
                definition = plain(match[2])
                # WordNet senses have Japanese definitions; do not reverse or
                # infer meaning from their sometimes noisy synonym lists.
                if JP.search(definition) or not re.search('[A-Za-z]{3}', definition):
                    continue
                if MARKED.search(plain(sense.split('<br/>')[0])):
                    continue
                if re.match(r'(?:Alternative|Obsolete|Archaic|Misspelling|Plural|Past|Present|Comparative|Superlative|Inflection|Contraction|Clipping|Diminutive)\b', definition, re.I):
                    continue  # unresolved references cannot supply a meaning
                terms = [plain(t) for t in match[1].split(', ')]
                terms = [t for t in terms if JP.search(t) and not re.search(r'[A-Za-z{}<>+＝=／/]', t) and len(t) <= 45]
                if not terms:
                    continue
                # Preserve the bilingual editor's first equivalent: generic
                # high-frequency synonyms (e.g. ああ for geez) lose meaning.
                term = terms[0]
                if pos == 'v.' and re.fullmatch('[ァ-ヶー一-龯]+', term):
                    term += 'する'
                if (pos, term) not in senses:
                    senses.append((pos, term))
        if senses:
            result[word] = senses
    return result


def supplement(accepted, existing, frequency, japanese_frequency, inflections, limit=0):
    source = entries(japanese_frequency)
    config = json.loads((SOURCE / 'short_config.json').read_text(encoding='utf-8'))
    holds = config['hold_headwords']
    source = {w: v for w, v in source.items() if w not in holds}
    targets = sorted((w for w in accepted - set(existing)
                      if len(w) <= config['max_length'] and frequency[w] >= config['min_zipf'] and w not in holds),
                     key=lambda w: (len(w), -frequency[w], w))
    if limit:
        targets = targets[:limit]
    target_set = set(targets)
    candidates = defaultdict(list)
    # Inflection must be attested for the matching dictionary POS. Do not use
    # capitalized names, guessed suffix stripping, or foreign irregular plurals.
    for lemma, senses in source.items():
        if frequency.get(lemma, 0) < 2.5:
            continue
        for tag, forms in inflections(lemma).items():
            if tag not in TAGS:
                continue
            pos, label = TAGS[tag]
            selected = [(p, t) for p, t in senses if p == pos][:3]
            if not selected:
                continue
            for word in forms:
                if word != lemma and word in target_set and word not in source:
                    # Very uncommon foreign plurals (reis/lire/loca) can refer
                    # to a different sense than the common lemma: defer them.
                    if tag == 'NNS' and word not in (lemma + 's', lemma + 'es', lemma[:-1] + 'ies'):
                        continue
                    candidates[word].append((lemma, tag, label, selected))
    additions, provenance = {}, {}
    for word in targets:
        if word in source:
            selected = source[word][:3]
            additions[word] = '／'.join('（' + LABEL[p] + '）' + t for p, t in selected)
            provenance[word] = {'method': 'wiktionary_exact', 'source': 'short_dictionary', 'headword': word}
        elif word in candidates and len({c[0] for c in candidates[word]}) == 1:
            lemma, tag, label, selected = candidates[word][0]
            additions[word] = '／'.join('（' + LABEL[p] + '）' + t for p, t in selected) + f'（{lemma}の{label}）'
            provenance[word] = {'method': 'wiktionary_inflection', 'source': 'short_dictionary', 'headword': lemma, 'tag': tag}
        else:
            continue
        provenance[word]['url'] = 'https://en.wiktionary.org/wiki/' + provenance[word]['headword']
    return additions, provenance
