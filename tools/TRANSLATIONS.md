# Offline translation build

Install Python 3.10+ dependencies into the ignored build directory:

```powershell
python -m pip install --target tools/_translation_deps -r tools/translation_requirements.txt
python tools/expand_translations.py --sample 300
python tools/expand_translations.py
python tests/check_translation_build.py
```

After a test Web export to `tests/translation_web_build/index.html`, run
`python tests/check_translation_build.py --web-pack` to verify the actual PCK
directory, every payload checksum, the full translation JSON, every license
document, and exclusion of tools/tests from the shipped archive.

The sample is a dry run on the most frequent missing words, never a write.
Full builds use the immutable `translation_sources/baseline.json.gz` snapshot
(397,561 accepted words; 99,466 translations), not dictionary.txt, whose
vocabulary differs. Existing translations are preserved byte-for-byte as
strings; words and translation keys remain disjoint. The approved exclusions in
`filter_sources/applied_exclusions.txt` are subtracted from the baseline, leaving
377,293 accepted words; these 20,268 exclusions have no existing translations.
`--input` accepts a different JSON/gz baseline; `--output` selects a JSON output.
When adopting later hand edits, explicitly create a new baseline first.
The old build_word_json.py is a separate legacy vocabulary generator; do not
run it as part of translation expansion because it changes accepted names.

Sources are vendored to allow offline, reproducible builds. EJDict revision is
in `translation_sources/revision.txt`; JMdict is the official JMdict_e.gz
snapshot retrieved during this change. Every input's SHA-256 is included in
data/translation_coverage.json. Outputs contain no timestamps or random order.
Rebuilding uses Python dictionaries/XML streaming, never an LLM or an API.

Exact lowercase EJDict headwords win. Preserve source sense order, max three,
and whole definitions (omit definitions over 100 characters rather than
truncating them). Avoid rare/obsolete/offensive senses and bare cross-references.
Capitalized headwords are not lowercased into unrelated names/abbreviations.

JMdict is a Japanese-to-English resource, so reverse lookup is deliberately
limited: only whole lowercase English glosses, never substrings or stripped
parentheses. Respect sense spelling/reading restrictions; reject specialized,
marked, dialectal and context-dependent senses and explanatory glosses.
Prefer priority-marked entries and Japanese token frequency; retain at most
one written form per sense and three Japanese equivalents per English word.
This ranks candidates, not English sense frequency: reverse dictionaries cannot
fully resolve polysemy. Existing translations are never replaced by this path.

Inflections use LemmInflect's attested database with POS-specific Japanese
meanings where identifiable, or explicit source inflection references. No OOV
prediction or suffix stripping. Ambiguous lemmas are skipped; direct entries
win. Existing meanings can supply a lemma gloss when source coverage is absent.
Noun-only lemmas require noun-compatible glosses. Surface forms must already
belong to the accepted vocabulary. Inflected labels explain the lemma and form.

Coverage counts all accepted tokens in each English wordfreq Zipf band,
including names and abbreviations. Zero means absent from the frequency list,
not an estimated measured frequency. Presence of a translation measures
coverage, not accuracy. Existing translations are not re-audited or rewritten.

Refresh source snapshots with `python tools/fetch_translation_sources.py`.
By default EJDict uses the pinned revision; `--ejdict-revision master` opts into
upstream changes. JMdict refresh uses the official current file; rebuild and
review new hashes, coverage, provenance and sample translations afterwards.
Refresh monthly for distributed dictionary services as required by the EDRDG
statement. The game itself always uses its bundled snapshot offline.

## Short-word supplementation (2026-10-22)

`python tools/fetch_short_translations.py` pins the CC BY-SA 4.0 en-ja v1.2.0
release from DanielGregorini/koreader-dicts (English Wiktionary via Kaikki /
wiktextract, WordNet). The original lowercase entries are retained as compressed
HTML in `translation_sources/short_dictionary.json.gz`. The archive and subset
SHA-256 values are recorded in `short_manifest.json`; a changed upstream archive
is rejected. The subset and all notices are included in the source repository,
so normal regeneration needs no download. An expired certificate at Kaikki's
Japanese Wiktionary endpoint prevented using that source; HTTPS verification
was kept enabled. Experimental Japanese WordNet-only additions were rejected
because noisy synonyms and uncommon irregular plurals produced misleading
meanings. Those experimental additions are not shipped.

`short_translations.py` runs after the existing pipeline. It preserves all
101,957 preceding translations and fills only untranslated accepted words.
Configuration: `translation_sources/short_config.json` (currently <=8 letters,
wordfreq Zipf >=1.5, explicit review holds). Order is length ascending, English
frequency descending, then spelling. Run `expand_translations.py --sample 500`
for a dry run before the full build; the short pass samples the first 500
eligible missing words independently of the legacy frequency sample.

Only explicit Japanese equivalents alongside English definitions are selected.
The compilation's WordNet senses with Japanese definitions and English-only
definitions are excluded. Exact lowercase headwords and explicit POS are
required. Marked old/rare/offensive/dialectal senses, proper-name POS, unresolved
cross-references, unexplained abbreviation entries and noisy gloss syntax are
skipped. Keep the source editor's equivalent order, up to three meanings.
Dictionary-attested inflections require matching POS and an unambiguous lemma;
uncommon irregular foreign noun plurals are deferred. This is conservative
dictionary selection, not a claim that every source meaning has been audited.

`translation_coverage.json` records this pass separately (`short_pass`,
`before_short`, `added_short`) and retains baseline counts for reproducibility.
The result report is `tools/SHORT_TRANSLATION_REPORT.md`. Detailed provenance
identifies each source headword; `data/licenses/Wiktionary-attribution.txt`
bundles per-word contributor/history links for offline distributions. The
accepted set, approved exclusions, fallback dictionary and game logic do not
change. The filter audit/application checks allow translation-only additions,
while verifying the approved vocabulary hash and every previous translation.

Licensing and attribution: data/DICTIONARY_LICENSES.txt and data/licenses/.
Web export includes those documents and the translation JSON, and excludes
build dependencies and test/source data. No new network runtime is introduced.
