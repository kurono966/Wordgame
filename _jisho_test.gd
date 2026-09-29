extends Node

# Headless test for JishoClient: response parsing AND English -> Japanese
# translation selection.
#
# The payloads in jisho_*.json were captured from the real
# https://jisho.org/api/v1/search/words endpoint, so the parser is verified
# against genuine API responses. A live lookup is attempted too and is skipped
# automatically when there is no network.
#
# This file is deliberately pure ASCII: expected Japanese headwords are written
# as \uXXXX escapes so an editor/console encoding round-trip cannot corrupt it.

const PAYLOAD_KNOWLEDGE := "res://jisho_knowledge.json"
const PAYLOAD_EMPTY := "res://jisho_empty.json"
const PAYLOAD_GOAT := "res://jisho_goat.json"
const PAYLOAD_FIVE := "res://jisho_five.json"
const PAYLOAD_EGG := "res://jisho_egg.json"
const PAYLOAD_EGGS := "res://jisho_eggs.json"

const TAMAGO_KANJI := "\u5375"  # tamago (egg)

const CAT_KANJI := "\u732B"          # neko   (cat)
const YAGI_KANJI := "\u5C71\u7F8A"  # yagi   (goat)
const GO_KANJI := "\u4E94"            # go     (five)
const CHISHI_KANJI := "\u77E5\u8B58"  # chishi (knowledge)
const YAGI_READING := "\u3084\u304E"  # yaGI

func _ready() -> void:
	var client = load("res://JishoClient.gd").new()
	client.name = "JishoClientUnderTest"
	add_child(client)
	await get_tree().process_frame

	var fails: int = 0

	# ===== Field extraction ==============================================
	var know: Dictionary = client._parse_into_result("knowledge", _body(PAYLOAD_KNOWLEDGE))
	fails += _check(str(know.get("status", "")) == "ok", "real response parses to 'ok'")
	fails += _check(str(know.get("kanji", "")) == CHISHI_KANJI, "kanji is extracted")
	fails += _check(str(know.get("reading", "")) != "", "reading is extracted")
	fails += _check((know.get("definitions", []) as Array).size() > 0, "definitions are extracted")
	fails += _check((know.get("definitions", []) as Array).size() <= client.MAX_DEFINITIONS,
		"definitions are capped at MAX_DEFINITIONS")
	fails += _check(bool(know.get("common", false)) == true, "is_common is captured")
	fails += _check(str(know.get("word", "")) == "KNOWLEDGE", "word is upper-cased")
	fails += _check(str(know.get("kanji", "")) == CHISHI_KANJI, "'knowledge' -> CHISHI")
	print("knowledge -> ", JSON.stringify(know).substr(0, 240))

	# ===== English -> Japanese must pick a REAL translation ===============
	# Regression: searching "goat" used to display the numeral five with the
	# gloss "five; 5", because the old parser simply took the first is_common
	# entry. Jisho is a full-text search, so the chosen entry must actually
	# translate the queried word.
	var goat: Dictionary = client._parse_into_result("goat", _body(PAYLOAD_GOAT))
	fails += _check(str(goat.get("status", "")) == "ok", "'goat' parses to 'ok'")
	fails += _check(str(goat.get("kanji", "")) == YAGI_KANJI,
		"'goat' -> YAGI, not the numeral five (got '%s')" % str(goat.get("kanji", "")))
	fails += _check(str(goat.get("reading", "")) == YAGI_READING, "'goat' reading is yaGI")
	fails += _check(str(goat.get("kanji", "")) != GO_KANJI,
		"'goat' is never translated as the numeral five")
	var goat_joined: String = "; ".join(goat.get("definitions", [])).to_lower()
	fails += _check(goat_joined.contains("goat"),
		"'goat' definitions mention goat ('%s')" % goat_joined)
	fails += _check(not goat_joined.contains("zodiac") and not goat_joined.contains("sheep"),
		"'goat' does not show the Chinese-zodiac senses ('%s')" % goat_joined)
	fails += _check(not goat_joined.contains("five") and not goat_joined.contains("5"),
		"'goat' does not show the numeral five")
	print("goat -> ", JSON.stringify(goat).substr(0, 240))

	# "five" must resolve to the numeral itself, not a variant spelling
	var five: Dictionary = client._parse_into_result("five", _body(PAYLOAD_FIVE))
	fails += _check(str(five.get("status", "")) == "ok", "'five' parses to 'ok'")
	fails += _check(str(five.get("kanji", "")) == GO_KANJI,
		"'five' -> GO (got '%s')" % str(five.get("kanji", "")))
	fails += _check("; ".join(five.get("definitions", [])).to_lower().contains("five"),
		"'five' definitions mention five")
	print("five -> ", JSON.stringify(five).substr(0, 200))

	# ===== Singular / plural must both resolve ============================
	# Jisho returns ["eggs", "egg", "spawn", "roe"] for 卵, so the plural is
	# listed FIRST. Searching the singular used to find no exact match and the
	# line came out empty, while the plural worked.
	var egg: Dictionary = client._parse_into_result("egg", _body(PAYLOAD_EGG))
	fails += _check(str(egg.get("status", "")) == "ok", "'egg' parses to 'ok'")
	fails += _check(str(egg.get("kanji", "")) == TAMAGO_KANJI,
		"'egg' -> TAMAGO (got '%s')" % str(egg.get("kanji", "")))
	var egg_defs: Array = egg.get("definitions", [])
	fails += _check(egg_defs.size() > 0 and str(egg_defs[0]).to_lower() == "egg",
		"'egg' leads with its exact gloss, not the plural ('%s')" % "; ".join(egg_defs))
	print("egg -> ", JSON.stringify(egg).substr(0, 200))

	var eggs: Dictionary = client._parse_into_result("eggs", _body(PAYLOAD_EGGS))
	fails += _check(str(eggs.get("status", "")) == "ok", "'eggs' parses to 'ok'")
	fails += _check(str(eggs.get("kanji", "")) == TAMAGO_KANJI,
		"'eggs' -> TAMAGO (got '%s')" % str(eggs.get("kanji", "")))
	print("eggs -> ", JSON.stringify(eggs).substr(0, 200))

	# The lemma helper itself
	fails += _check(client._same_lemma("egg", "eggs") == true, "lemma: egg == eggs")
	fails += _check(client._same_lemma("eggs", "egg") == true, "lemma: eggs == egg")
	fails += _check(client._same_lemma("goat", "goats") == true, "lemma: goat == goats")
	fails += _check(client._same_lemma("baby", "babies") == true, "lemma: baby == babies")
	fails += _check(client._same_lemma("box", "boxes") == true, "lemma: box == boxes")
	fails += _check(client._same_lemma("cat", "cattle") == false, "lemma: cat != cattle")
	fails += _check(client._same_lemma("egg", "spawn") == false, "lemma: egg != spawn")
	# Short words are never stemmed: "a" and "as" are different words.
	fails += _check(client._same_lemma("a", "as") == false, "lemma: 'a' is not stemmed to 'as'")
	fails += _check(client._same_lemma("a", "a") == true, "lemma: identical short words match")

	# ===== Ranking helpers ===============================================
	# Whole-word matching: "cat" must not match "cattle" or "catalog"
	fails += _check(client._contains_word("cattle", "cat") == false, "'cat' !~ 'cattle'")
	fails += _check(client._contains_word("black cat", "cat") == true, "'cat' ~ 'black cat'")
	fails += _check(client._contains_word("cat", "cat") == true, "'cat' ~ 'cat'")
	fails += _check(client._contains_word("catalog", "cat") == false, "'cat' !~ 'catalog'")

	# Article handling (input is lower-cased by the callers)
	fails += _check(client._head_without_article("the goat") == "goat", "strips 'the'")
	fails += _check(client._head_without_article("a cat") == "cat", "strips 'a'")
	fails += _check(client._head_without_article("goat's milk") == "goat's milk",
		"leaves other phrases alone")

	# Wikipedia "definition" senses are not translations
	fails += _check(client._is_wikipedia_sense({"parts_of_speech": ["Wikipedia definition"]}) == true,
		"detects a Wikipedia sense")
	fails += _check(client._is_wikipedia_sense({"parts_of_speech": ["Noun"]}) == false,
		"a normal sense is not Wikipedia")

	# An unrelated common word must be rejected, not displayed
	var junk: Array = [{
		"slug": "AAA", "is_common": true,
		"japanese": [{"word": "AAA", "reading": "aaa"}],
		"senses": [{"english_definitions": ["unrelated"], "parts_of_speech": ["Noun"]}]
	}]
	fails += _check(client._select_translation("goat", junk).is_empty(),
		"an unrelated common word is rejected")

	# An exact gloss beats an article-prefixed one ("goat" over "the Goat")
	var tiers: Array = [
		{"slug": "ART", "is_common": true,
		 "japanese": [{"word": "A", "reading": "a"}],
		 "senses": [{"english_definitions": ["the Goat"], "parts_of_speech": ["Noun"]}]},
		{"slug": "EX", "is_common": false,
		 "japanese": [{"word": "E", "reading": "e"}],
		 "senses": [{"english_definitions": ["goat"], "parts_of_speech": ["Noun"]}]}
	]
	fails += _check(str(client._select_translation("goat", tiers).get("slug", "")) == "EX",
		"an exact gloss outranks an article-prefixed one")

	# ===== Error / edge cases ============================================
	var empty: Dictionary = client._parse_into_result("qqzzxx", _body(PAYLOAD_EMPTY))
	fails += _check(str(empty.get("status", "")) == "not_found", "empty response is not_found")
	fails += _check((empty.get("definitions", []) as Array).is_empty(), "no definitions when empty")

	var bad: Dictionary = client._parse_into_result("bad", PackedByteArray("not json".to_utf8_buffer()))
	fails += _check(str(bad.get("status", "")) == "error", "malformed JSON yields 'error'")
	fails += _check(str(bad.get("reason", "")) != "", "malformed JSON records a reason")

	fails += _check(str(client.lookup("A").get("status", "")) == "not_found",
		"1-letter word is not looked up")

	# ===== Caching ========================================================
	client.clear_cache()
	client._cache["cachedword"] = client._make_result("cachedword", "ok", "", CAT_KANJI, "neko", "Noun", ["cat"])
	fails += _check(client.has_result("CACHEDWORD"), "has_result is case-insensitive")
	var from_cache: Dictionary = client.lookup("CachedWord")
	fails += _check(str(from_cache.get("status", "")) == "ok", "cached word resolves without a request")
	fails += _check(str(from_cache.get("kanji", "")) == CAT_KANJI, "cached result keeps its kanji")

	fails += _check(client.is_available() == (not OS.has_feature("web")),
		"is_available() reflects the Web restriction")

	# ===== Live API (skipped when offline) ================================
	if client.is_available():
		client.clear_cache()
		client.lookup("cat")
		var waited: float = 0.0
		while client._request_open and waited < 12.0:
			await get_tree().create_timer(0.2).timeout
			waited += 0.2
		var live: Dictionary = client.peek("cat")
		if str(live.get("status", "")) == "ok":
			print("live -> ", JSON.stringify(live).substr(0, 200))
			fails += _check(str(live.get("kanji", "")) == CAT_KANJI, "live lookup returns the expected kanji")
			fails += _check((live.get("definitions", []) as Array).size() > 0,
				"live lookup returns definitions")
		else:
			print("live lookup skipped (status=", str(live.get("status", "?")),
				" reason=", str(live.get("reason", "?")), ")")

	print("FAILURES=%d" % fails)
	print("TEST_EXIT=%d" % fails)
	get_tree().quit(fails)

func _body(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	return file.get_buffer(file.get_length())

func _check(ok: bool, label: String) -> int:
	if ok:
		print("  ok   - ", label)
		return 0
	printerr("  FAIL - ", label)
	return 1
