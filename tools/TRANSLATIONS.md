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
strings; words and translation keys remain disjoint and their union identical.
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

Licensing and attribution: data/DICTIONARY_LICENSES.txt and data/licenses/.
Web export includes those documents and the translation JSON, and excludes
build dependencies and test/source data. No new network runtime is introduced.
