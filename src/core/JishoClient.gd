extends Node

# JishoClient.gd - Looks up a word in the Jisho API (jisho.org) and returns a
# Japanese headword (kanji + reading) with English definitions.
#
#   GET https://jisho.org/api/v1/search/words?keyword=<word>
#
# Behaviour notes:
#   * Every lookup is CACHED, so re-submitting the same word costs nothing.
#   * Only ONE request is in flight; a newer word supersedes an older answer.
#   * A FAILED lookup is cached too, so the UI never retries in a loop and the
#     game never blocks on the network.
#   * CORS: jisho.org sends NO Access-Control-Allow-Origin header, so this does
#     NOT work in a Web export (the browser blocks the request). It works in the
#     editor and in a desktop build. is_available() reports this up front so the
#     UI can say so instead of silently failing.
#
# Result dictionary from lookup():
#   { "word": String, "status": "ok"|"not_found"|"error"|"pending",
#     "kanji": String, "reading": String, "pos": String,
#     "definitions": Array[String], "common": bool, "jlpt": Array[String],
#     "reason": String }

const API_URL: String = "https://jisho.org/api/v1/search/words?keyword="
const MAX_DEFINITIONS: int = 4
const TIMEOUT_SECONDS: float = 8.0
## Words shorter than this are ignored (Jisho has no useful short entries).
const MIN_WORD_LENGTH: int = 2
## Minimum score an entry must reach to be shown. Equal to the "gloss minus an
## article" tier, so an entry is only shown when one of its definitions really
## is a translation of the searched word (see _score_entry).
const MIN_TRANSLATION_SCORE: int = 400

signal lookup_finished(word: String, result: Dictionary)

var _cache: Dictionary = {}          # String word -> Dictionary result
var _http: HTTPRequest = null
var _request_open: bool = false
## The word currently being fetched, so a stale answer can be discarded.
var _in_flight: String = ""


func _ready() -> void:
	# One shared HTTPRequest handles every lookup; it is a child of this node so
	# its request_completed signal is delivered back here.
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SECONDS
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


# Jisho is unusable from a Web export because the API sends no CORS headers.
func is_available() -> bool:
	return not OS.has_feature("web")


func clear_cache() -> void:
	_cache.clear()


func has_result(word: String) -> bool:
	return _cache.has(word.to_lower().strip_edges())


## Synchronous cache read; empty dictionary when nothing is known yet.
func peek(word: String) -> Dictionary:
	return _cache.get(word.to_lower().strip_edges(), {})


## Starts (or reuses) a lookup. Returns the cached result when one exists,
## otherwise a "pending" placeholder while the request runs.
func lookup(word: String) -> Dictionary:
	var key: String = word.to_lower().strip_edges()
	if key.length() < MIN_WORD_LENGTH:
		return _make_result(word, "not_found")

	# Always answer from the cache when we can: never hit the network twice.
	if _cache.has(key):
		return _cache[key]

	if not is_available():
		# No CORS on Web: fail fast with a clear reason instead of hanging.
		_cache[key] = _make_result(word, "error", "unavailable in Web export (CORS)")
		lookup_finished.emit(word, _cache[key])
		return _cache[key]

	if not _request_open:
		var err: int = _http.request(API_URL + key.uri_encode())
		if err != OK:
			_cache[key] = _make_result(word, "error", "request failed (%d)" % err)
			lookup_finished.emit(word, _cache[key])
			return _cache[key]
		_request_open = true

	# Only one request is in flight; a newer word supersedes the pending answer.
	_in_flight = key
	return _make_result(word, "pending")


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_open = false
	var key: String = _in_flight
	_in_flight = ""
	if key == "":
		return

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_cache[key] = _make_result(key, "error", "HTTP %d" % response_code)
	else:
		_parse_body(key, body)
	lookup_finished.emit(key, _cache[key])


## Parses a Jisho payload, stores the best match in the cache and returns it.
func _parse_body(key: String, body: PackedByteArray) -> Dictionary:
	var result: Dictionary = _parse_into_result(key, body)
	_cache[key] = result
	return result


## Pure parsing step (no cache side effects) so it can be unit tested directly.
func _parse_into_result(key: String, body: PackedByteArray) -> Dictionary:
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(json) != TYPE_DICTIONARY:
		return _make_result(key, "error", "bad response")

	var entries: Array = json.get("data", [])
	var best: Dictionary = _select_translation(key, entries)
	if best.is_empty():
		return _make_result(key, "not_found")

	return _entry_to_result(key, best)


## Chooses the entry that actually TRANSLATES the English word we searched for.
##
## Jisho's `search/words` is a full-text search over the English glosses, so it
## happily returns unrelated words ("goat" -> 山羊, but also 未 "the Ram; the
## Goat"). It does NOT guarantee the query itself is a translation of the entry.
## Picking the first `is_common` entry is therefore wrong: searching "goat" could
## return 五 "five" simply because that entry is a common word.
##
## Ranking, best first:
##   1. an English definition EXACTLY equal to the query (that is a real
##      translation) — among those, a common word wins
##   2. a definition that merely CONTAINS the query as a whole word
##   3. nothing matched -> no translation (the caller shows "no entry")
func _select_translation(query: String, entries: Array) -> Dictionary:
	var needle: String = query.to_lower().strip_edges()
	var best: Dictionary = {}
	var best_score: int = 0

	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var score: int = _score_entry(needle, entry)
		# Jisho returns results in relevance order, so an equal score keeps the
		# earlier (better-ranked) entry. Only a strictly better score replaces it.
		if score > best_score:
			best_score = score
			best = entry
	# Only a real translation is acceptable. The `is_common` bonus alone must not
	# qualify an entry, otherwise an unrelated common word would be shown.
	if best_score < MIN_TRANSLATION_SCORE:
		return {}
	return best


## Scores how well one Jisho entry translates `needle`. Higher is better, 0 means
## "this entry is not a translation of the word at all".
##
## The tiers matter, because a bare gloss ("goat" for the kanji word) must beat
## an article-prefixed one ("the Goat" for the zodiac sheep):
##   +1000  a definition EXACTLY equals the query
##    +400  the query equals the gloss minus a leading article ("the Goat")
##    +100  that same gloss is in the FIRST sense (the entry's main meaning)
##     +40  the headword is pure kanji: the bare dictionary form (五) rather
##          than a counter/compound (五つ) or a kana reading (ゴート)
##     +10  the headword mixes kanji (山羊)
##     +15  the entry is a common word
##      +4  the query only appears inside a longer gloss ("wild goat")
func _score_entry(needle: String, entry: Dictionary) -> int:
	if needle == "":
		return 0
	var score: int = 0
	var exact_first_sense: bool = false
	var exact_any_sense: bool = false
	var article_first_sense: bool = false
	var article_any_sense: bool = false
	var saw_partial: bool = false

	var senses: Array = entry.get("senses", [])
	for sense_index in range(senses.size()):
		var sense: Variant = senses[sense_index]
		if typeof(sense) != TYPE_DICTIONARY:
			continue
		# Jisho mixes real dictionary senses with scraped "Wikipedia definition"
		# entries. Those are article summaries, not translations, and they can
		# match spuriously (未 "Goat (zodiac)" would otherwise beat 山羊 "goat"),
		# so they are skipped entirely.
		if _is_wikipedia_sense(sense):
			continue
		for def: Variant in sense.get("english_definitions", []):
			var gloss: String = str(def).to_lower().strip_edges()
			if gloss == "":
				continue
			# "cat (esp. the domestic cat)" -> "cat"
			var head: String = gloss.split("(")[0].strip_edges()
			# Dictionaries list inflections together: Jisho returns
			# ["eggs", "egg", "spawn", "roe"] for 卵, so searching "egg" must
			# still count as an exact hit even though "eggs" comes first.
			if _same_lemma(head, needle):
				exact_any_sense = true
				if sense_index == 0:
					exact_first_sense = true
			elif _head_without_article(head) == needle or _same_lemma(_head_without_article(head), needle):
				# "the Goat" is a translation too, but a weaker one
				article_any_sense = true
				if sense_index == 0:
					article_first_sense = true
			elif _contains_word(head, needle):
				saw_partial = true

	if exact_any_sense:
		score += 1000
	if article_any_sense:
		score += 400
	# A gloss in the first sense is the entry's primary meaning
	if exact_first_sense or article_first_sense:
		score += 100
	if bool(entry.get("is_common", false)):
		score += 15
	# Prefer the bare word over a counter/compound form: for "five" that is the
	# single-kanji numeral rather than numeral+tsu ("five things") or numeral-1.
	# This matters because JMDict lists both and the compound is often ranked
	# first, so a pure-kanji headword is what the player expects. A kana-only
	# spelling (ゴート) is a reading/variant and gets the smaller bonus.
	var slug_here: String = str(entry.get("slug", ""))
	if _is_pure_kanji(slug_here):
		score += 40
	elif _has_kanji(slug_here):
		score += 10
	if saw_partial:
		score += 4
	return score


## True when every character is a CJK ideograph (U+4E00..U+9FFF), i.e. the
## headword is a single-kanji dictionary form rather than a compound/counter.
func _is_pure_kanji(text: String) -> bool:
	if text.is_empty():
		return false
	for i in range(text.length()):
		var code: int = text.unicode_at(i)
		if code < 0x4E00 or code > 0x9FFF:
			return false
	return true


## True when two English words are the same lemma, ignoring the regular
## plural/verb inflections dictionaries list side by side. Jisho returns
## ["eggs", "egg", "spawn", "roe"] for the word 卵, so searching either "egg"
## or "eggs" must select that entry; without this, the plural is listed first
## and the singular search finds no exact match.
func _same_lemma(a: String, b: String) -> bool:
	if a == b:
		return true
	return _base_form(a) == _base_form(b) and not _base_form(a).is_empty()


## Strips the regular English inflections: plural "-s"/"-es", third person
## "-s", progressive/gerund "-ing" and past "-ed" (with the usual doubling and
## silent-e restorations). Irregular forms are deliberately NOT handled, since
## guessing them would create false matches.
func _base_form(word: String) -> String:
	var w: String = word.to_lower().strip_edges()
	if w.length() < 3:
		return w
	if w.ends_with("ies"):
		return w.substr(0, w.length() - 3) + "y"
	if w.ends_with("es"):
		# "boxes" -> "box"; but "eggs" -> handled by the -s branch below
		return w.substr(0, w.length() - 2)
	if w.ends_with("s"):
		return w.substr(0, w.length() - 1)
	if w.ends_with("ing"):
		var stem: String = w.substr(0, w.length() - 3)
		if stem.length() >= 2 and stem[stem.length() - 1] == stem[stem.length() - 2]:
			stem = stem.substr(0, stem.length() - 1)  # "running" -> "runn"
		elif stem.ends_with("e"):
			return stem
		return stem + "e" if stem.ends_with("v") else stem
	return w


## True when the text contains at least one CJK ideograph (U+4E00..U+9FFF).
func _has_kanji(text: String) -> bool:
	for i in range(text.length()):
		var code: int = text.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


## True when `needle` appears in `text` as a standalone word (not a substring,
## so "cat" does not match "cattle" or "category").
func _contains_word(text: String, needle: String) -> bool:
	if needle == "":
		return false
	var index: int = text.find(needle)
	while index >= 0:
		var before: String = "" if index == 0 else text[index - 1]
		var after_index: int = index + needle.length()
		var after: String = "" if after_index >= text.length() else text[after_index]
		if not _is_word_char(before) and not _is_word_char(after):
			return true
		index = text.find(needle, index + 1)
	return false


func _is_word_char(c: String) -> bool:
	if c == "":
		return false
	var code: int = c.unicode_at(0)
	return (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


func _entry_to_result(word: String, entry: Dictionary) -> Dictionary:
	var kanji: String = str(entry.get("slug", ""))
	var reading: String = ""
	var japanese: Array = entry.get("japanese", [])
	if not japanese.is_empty() and typeof(japanese[0]) == TYPE_DICTIONARY:
		reading = str(japanese[0].get("reading", ""))

	# Collect the part of speech and the definitions from the sense that actually
	# matched the query, so the line reads as a translation of the searched word.
	# Without this, "goat" could show 山羊 alongside the glosses of an unrelated
	# sense ("the Ram; the Sheep (Chinese zodiac)").
	var senses: Array = entry.get("senses", [])
	var pos: String = ""
	var definitions: Array = []
	var needle: String = word.to_lower().strip_edges()

	for sense: Variant in senses:
		if typeof(sense) != TYPE_DICTIONARY:
			continue
		# Skip scraped Wikipedia "definitions": they are not translations
		if _is_wikipedia_sense(sense):
			continue
		var sense_defs: Array = sense.get("english_definitions", [])
		var matched: bool = false
		for def: Variant in sense_defs:
			var gloss: String = str(def).to_lower().strip_edges()
			var head: String = gloss.split("(")[0].strip_edges()
			if _same_lemma(_head_without_article(head), needle):
				matched = true
				break
		# The part of speech comes from the first matching sense
		if matched and pos == "":
			var pos_list: Array = sense.get("parts_of_speech", [])
			if not pos_list.is_empty():
				pos = str(pos_list[0])
		# Definitions come from that same sense, so they describe the translation.
		# An EXACT gloss is listed first, then inflections of the searched word
		# (searching "egg" should show "egg", not the plural "eggs"), and finally
		# the rest of the sense ("spawn", "roe") fills any remaining slots.
		if matched and definitions.is_empty():
			for def: Variant in sense_defs:
				var text: String = str(def)
				if text != "" and text.to_lower().strip_edges() == needle and not definitions.has(text):
					definitions.append(text)
			for def: Variant in sense_defs:
				var text: String = str(def)
				if text == "" or definitions.has(text):
					continue
				if _same_lemma(text.to_lower().split("(")[0].strip_edges(), needle):
					definitions.append(text)
			for def: Variant in sense_defs:
				var text: String = str(def)
				if text != "" and not definitions.has(text):
					definitions.append(text)
			if definitions.size() > MAX_DEFINITIONS:
				definitions.resize(MAX_DEFINITIONS)

	# No sense actually translates the word -> report it as untranslated rather
	# than showing an unrelated entry's glosses.
	if definitions.is_empty():
		return _make_result(word, "not_found")

	return _make_result(word, "ok", "", kanji, reading, pos, definitions,
		bool(entry.get("is_common", false)), entry.get("jlpt", []))


## "the Goat" -> "goat", "a cat" -> "cat"; other phrases are returned unchanged.
## The input is expected to be lower-cased already (the callers normalise it).
func _head_without_article(head: String) -> String:
	var words: Array = head.replace(".", " ").split(" ", false)
	if words.size() > 1 and str(words[0]) in ["the", "a", "an"]:
		words.remove_at(0)
		return " ".join(words)
	return head


## True for Jisho's scraped "Wikipedia definition" senses, which are article
## summaries rather than dictionary translations.
func _is_wikipedia_sense(sense: Dictionary) -> bool:
	for pos: Variant in sense.get("parts_of_speech", []):
		if str(pos).to_lower().contains("wikipedia"):
			return true
	return false


func _make_result(word: String, status: String, reason: String = "", kanji: String = "",
		reading: String = "", pos: String = "", definitions: Array = [],
		common: bool = false, jlpt: Array = []) -> Dictionary:
	return {
		"word": word.to_upper(),
		"status": status,
		"reason": reason,
		"kanji": kanji,
		"reading": reading,
		"pos": pos,
		"definitions": definitions,
		"common": common,
		"jlpt": jlpt
	}
