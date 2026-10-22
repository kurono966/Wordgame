#!/usr/bin/env python3
"""Conservative, offline EJDict expansion. See tools/TRANSLATIONS.md.

Never rebuild the accepted vocabulary from dictionary.txt: the shipped JSON
is authoritative. No LLM, substring translation, or guessed suffix stripping.
"""
import argparse
import hashlib
import gzip
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/_translation_deps'))
from wordfreq import zipf_frequency, get_frequency_dict
from lemminflect import getAllInflections

SOURCE = ROOT / 'tools/translation_sources'
JP = re.compile(r'[ぁ-んァ-ヶ一-龯]')
WORD = re.compile(r'[a-z]+')
LABELS = {'NNS': '複数形', 'VBD': '過去形', 'VBN': '過去分詞',
          'VBG': '現在分詞', 'VBZ': '三人称単数現在',
          'JJR': '比較級', 'JJS': '最上級', 'RBR': '比較級', 'RBS': '最上級'}
JA_FREQUENCY = get_frequency_dict('ja')


def japanese_frequency(word):
    # Exact tokens only; avoid tokenization assigning a rare compound the
    # frequency of its individual characters. No MeCab build dependency.
    freq = JA_FREQUENCY.get(word, 0)
    return max(0, math.log10(freq) + 9) if freq else 0


def load(path):
    if path.suffix == '.gz':
        return json.loads(gzip.decompress(path.read_bytes()).decode('utf-8'))
    return json.loads(path.read_text(encoding='utf-8'))


def save(path, obj):
    path.write_text(json.dumps(obj, ensure_ascii=False, indent='\t') + '\n', encoding='utf-8')


def senses(raw):
    """Keep source sense order; remove typography and usage syntax, not clauses."""
    result = []
    for part in raw.split(' / '):
        # Do not promote rare/offensive/obsolete senses or bare cross-references.
        if re.search(r'《[^》]*(?:古|まれ|廃|差別|卑)[^》]*》', part):
            continue
        part = re.sub(r'《[^》]*》', '', part)
        part = re.sub(r'[『』]', '', part).strip()
        if not JP.search(part) or part.startswith('='):
            continue
        # Preserve whole definitions; a truncated sentence can change meaning.
        if len(part) > 100:
            continue
        if part and part not in result:
            result.append(part)
        if len(result) == 3:
            break
    return result


def read_dictionary():
    entries = {}
    for path in sorted(SOURCE.glob('src_*.txt')):
        for line in path.read_text(encoding='utf-8-sig').splitlines():
            if '\t' not in line:
                continue
            head, raw = line.split('\t', 1)
            for word in head.split(','):
                word = word.strip()
                # Capitalization is meaningful: exclude names and acronyms.
                if not WORD.fullmatch(word):
                    continue
                glosses = senses(raw)
                if glosses:
                    entries.setdefault(word, (glosses, raw))
    return entries


def jmdict_entries(accepted):
    """Reverse only complete glosses. Respect written/reading sense restrictions.

    A frequent English word alone does not make a Japanese synonym its main
    translation; common-entry priority and Japanese frequency rank candidates.
    """
    candidates = {}
    with gzip.open(SOURCE / 'JMdict_e.gz', 'rb') as handle:
        for _, entry in ET.iterparse(handle, events=('end',)):
            if entry.tag != 'entry':
                continue
            forms = []
            readings = entry.findall('r_ele')
            for ke in entry.findall('k_ele'):
                word = ke.findtext('keb')
                if ke.findall('ke_inf'):
                    continue  # irregular/obsolete/rare orthography
                matching = [r for r in readings if not r.findall('re_restr') or word in [x.text for x in r.findall('re_restr')]]
                if not matching:
                    continue
                priority = bool(ke.findall('ke_pri')) or any(r.findall('re_pri') for r in matching)
                forms.append((word, priority, {r.findtext('reb') for r in matching}))
            if not forms:
                for relem in readings:
                    if relem.findall('re_inf'):
                        continue
                    word = relem.findtext('reb')
                    forms.append((word, bool(relem.findall('re_pri')), {word}))
            inherited_pos = []
            for sense in entry.findall('sense'):
                inherited_pos = [p.text for p in sense.findall('pos')] or inherited_pos
                # Technical fields and marked usage are deliberately omitted.
                if (sense.findall('field') or sense.findall('misc') or sense.findall('dial')
                        or sense.findall('s_inf') or sense.findall('lsource')
                        or any(g.get('g_type') for g in sense.findall('gloss'))):
                    continue
                if not inherited_pos or any('unclassified' in p or 'proper noun' in p for p in inherited_pos):
                    continue
                english = [g.text for g in sense.findall('gloss')
                           if g.get('{http://www.w3.org/XML/1998/namespace}lang', 'eng') == 'eng'
                           and not g.get('g_type')]
                heads = [w for w in english if w in accepted and WORD.fullmatch(w)]
                if not heads:
                    continue
                restricted_k = {s.text for s in sense.findall('stagk')}
                restricted_r = {s.text for s in sense.findall('stagr')}
                available = [(w, pri) for w, pri, rs in forms
                             if (not restricted_k or w in restricted_k)
                             and (not restricted_r or restricted_r & rs)]
                if not available:
                    continue
                # One written form per sense; do not fill three slots with
                # alternative spellings of the same Japanese word.
                jp, common = max(available, key=lambda x: (x[1], japanese_frequency(x[0]), -len(x[0])))
                if not JP.search(jp):
                    continue
                score = (int(common), japanese_frequency(jp))
                for word in heads:
                    candidates.setdefault(word, []).append((score, jp, inherited_pos[:], entry.findtext('ent_seq')))
            entry.clear()
    result, metadata = {}, {}
    for word, options in candidates.items():
        ranked = sorted(options, key=lambda o: (o[0], -len(o[1])), reverse=True)
        selected = []
        seen = set()
        for score, jp, pos, seq in ranked:
            if jp in seen:
                continue
            # Rare Japanese equivalents are too risky without an English
            # dictionary sense ranking. Leave such words for future sources.
            if not score[0] and score[1] < 3:
                continue
            seen.add(jp)
            selected.append((jp, pos, seq))
            if len(selected) == 3:
                break
        if selected:
            result[word] = ([s[0] for s in selected], '')
            metadata[word] = {'method': 'jmdict_exact_gloss', 'entries': [s[2] for s in selected],
                              'pos': [s[1] for s in selected]}
    return result, metadata


def band(value):
    if value >= 5: return '5+ (very common)'
    if value >= 4: return '4-5 (common)'
    if value >= 3: return '3-4'
    if value >= 2: return '2-3'
    if value > 0: return '0-2'
    return '0 (unlisted)'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sample', type=int, default=0, help='dry run on N most frequent untranslated words')
    parser.add_argument('--input', type=Path, default=SOURCE / 'baseline.json.gz')
    parser.add_argument('--output', type=Path, default=ROOT / 'data/word_dictionary.json')
    args = parser.parse_args()
    data = load(args.input)
    previous = data['translations']
    accepted = set(data['words']) | set(previous)
    assert not set(data['words']) & set(previous)
    frequency = {w: zipf_frequency(w, 'en') for w in accepted}
    targets = sorted(accepted - set(previous), key=lambda w: (-frequency[w], w))
    if args.sample:
        targets = targets[:args.sample]
    targets = set(targets)
    entries = read_dictionary()
    jentries, jmetadata = jmdict_entries(accepted)
    additions, provenance = {}, {}
    # Explicit English headword meanings always win over inflection inheritance.
    # Morphological-only entries are resolved below, rather than displaying an
    # English reference with no Japanese meaning.
    references = re.compile(r'^([a-z]+)\s*の(複数形|過去形|過去・過去分詞|過去分詞|現在分詞)[。. ]*$')
    for word in sorted(targets):
        if word not in entries:
            continue
        glosses, raw = entries[word]
        comparative = re.search(r'\(([a-z]+)\s*の(?:比較級|最上級)', glosses[0])
        if comparative and word not in {f for fs in getAllInflections(comparative[1]).values() for f in fs}:
            continue  # inconsistent source headword/reference, e.g. a typo
        ref = references.fullmatch(raw)
        if ref:
            lemma, label = ref.groups()
            if lemma in entries and not references.fullmatch(entries[lemma][1]):
                additions[word] = entries[lemma][0][0] + f'（{lemma}の{label}）'
                provenance[word] = {'method': 'explicit_inflection', 'lemma': lemma}
        elif not re.search(r'^[a-z]+の.*(?:複数|過去|分詞)', raw):
            # An English phrase plus "contraction of" is not a Japanese
            # meaning. Resolve single-headword references from source data;
            # leave unresolved references empty instead of displaying jargon.
            if re.match(r'^[A-Za-z ,().=\x27-]+の', raw):
                simple = re.fullmatch(r'([a-z]+)\s*の(.+)', raw)
                if not simple or simple[1] not in entries:
                    continue
                base_gloss = entries[simple[1]][0][0]
                if re.match(r'^[A-Za-z ,().=\x27-]+の', base_gloss):
                    continue
                glosses = [base_gloss + 'の' + simple[2]]
            additions[word] = '／'.join(glosses)
            provenance[word] = {'method': 'exact'}

    for word in sorted(targets - set(additions)):
        if word in jentries:
            additions[word] = '／'.join(jentries[word][0])
            provenance[word] = jmetadata[word]

    candidates = {}
    morphology_entries = dict(jentries)
    morphology_entries.update(entries)
    # Reuse the preserved Japanese meanings too. Inflection is licensed by an
    # attested English POS/form pair, never by suffix heuristics alone.
    for lemma, gloss in previous.items():
        if WORD.fullmatch(lemma) and not re.search(r'人名|地名|略語|属名|科名|の(?:複数形|過去形|現在分詞)', gloss):
            morphology_entries.setdefault(lemma, (re.split(r'[／・]', gloss)[:3], ''))
    for lemma, (glosses, raw) in sorted(morphology_entries.items()):
        if references.fullmatch(raw):
            continue
        inflections = getAllInflections(lemma)
        for tag, forms in inflections.items():
            if tag not in LABELS:
                continue
            # POS comes from the attested inflection dictionary, not a guessed
            # suffix. Choose matching EJDict senses where labels permit it.
            if tag.startswith('NN'):
                selected = [g for g in glosses if re.search(r'〈[CU]〉|\{名\}', g)]
            elif tag.startswith('VB'):
                selected = [g for g in glosses if re.search(r'\{動\}|[うくぐすつぬぶむる]$', g)]
            else:
                selected = [g for g in glosses if re.search(r'\{形\}|\{副\}|[いな]$', g)]
            # Uncertain POS: leave untranslated rather than attach a noun gloss
            # to a verb form. Explicit reference entries above remain usable.
            if not selected:
                # JMdict supplies explicit POS even for bare noun headwords.
                meta = jmetadata.get(lemma, {}) if lemma not in entries else {}
                pos_word = 'noun' if tag.startswith('NN') else 'verb' if tag.startswith('VB') else 'adjectiv' if tag.startswith('JJ') else 'adverb'
                selected = [g for g, ps in zip(glosses, meta.get('pos', [])) if any(pos_word in p for p in ps)]
                if not selected and lemma not in entries and lemma not in jentries and tag == 'NNS':
                    # A single-POS noun can use its existing bare Japanese noun.
                    if not any(t.startswith(('VB', 'JJ', 'RB')) for t in inflections):
                        selected = [g for g in glosses if JP.search(g) and not re.search(r'[うくぐすつぬぶむるいな]$', g)]
                if not selected:
                    continue
            for form in forms:
                if form in targets and form not in additions and form != lemma:
                    candidates.setdefault(form, []).append((lemma, tag, selected))
    ambiguous = 0
    for word, options in sorted(candidates.items()):
        lemmas = {x[0] for x in options}
        if len(lemmas) > 1:
            ambiguous += 1
            continue
        lemma, tag, selected = options[0]
        labels = list(dict.fromkeys(LABELS[t] for _, t, _ in options))
        additions[word] = '／'.join(selected[:3]) + f'（{lemma}の{"・".join(labels)}）'
        provenance[word] = {'method': 'attested_inflection', 'lemma': lemma, 'tags': [t for _, t, _ in options],
                            'source': 'ejdict' if lemma in entries else 'jmdict' if lemma in jentries else 'existing'}

    merged = dict(previous, **additions)
    result = {'words': sorted(accepted - set(merged)), 'translations': dict(sorted(merged.items()))}
    assert set(result['words']) | set(merged) == accepted
    assert not set(result['words']) & set(merged)
    assert all(merged[w] == value for w, value in previous.items())
    assert all(JP.search(v) and '\ufffd' not in v for v in additions.values())
    rows = {}
    for w in sorted(accepted):
        row = rows.setdefault(band(frequency[w]), {'total': 0, 'before': 0, 'after': 0})
        row['total'] += 1
        row['before'] += w in previous
        row['after'] += w in merged
    for row in rows.values():
        row['coverage_percent'] = round(row['after'] / row['total'] * 100, 2)
    report = {'accepted': len(accepted), 'before': len(previous), 'added': len(additions),
              'after': len(merged), 'sample': args.sample, 'ambiguous_inflections_skipped': ambiguous,
              'methods': dict(Counter(p['method'] for p in provenance.values())), 'frequency_bands': rows,
              'ejdict_revision': (SOURCE / 'revision.txt').read_text().strip(),
              'source_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(SOURCE.iterdir()) if p.is_file()}}
    if not args.sample:
        save(args.output, result)
        save(ROOT / 'data/translation_provenance.json', provenance)
        save(ROOT / 'data/translation_coverage.json', report)
    print(json.dumps({k: v for k, v in report.items() if k != 'source_sha256'}, ensure_ascii=True))


if __name__ == '__main__':
    main()
