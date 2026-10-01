#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds data/word_dictionary.json from data/dictionary.txt.

The game needs TWO different things from its word list, and they have very
different shapes, so one flat JSON holds both:

  * "words"       - every valid word, lower-cased and sorted. The game checks
                    membership here, so it must be COMPLETE (it replaces
                    dictionary.txt for word validation).
  * "translations"- word -> Japanese gloss, for the words that have one. Only
                    short words are translated for now; every longer word is
                    present with an EMPTY string so the schema is stable and
                    later additions need no code change.

Why not translate everything? The 4+ letter space is ~411k entries and would
be unreliable to machine-generate, so it is deliberately left blank.

Run:  python build_word_json.py
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
# The word data lives in data/, one level up from tools/.
DATA_DIR = os.path.join(os.path.dirname(HERE), "data")
DICT_TXT = os.path.join(DATA_DIR, "dictionary.txt")
OUT_JSON = os.path.join(DATA_DIR, "word_dictionary.json")

# The 10 words supplied with the request. They are longer than 3 letters, so
# they are the explicit exception to the "short words only" rule below.
SAMPLE_TRANSLATIONS = {
    "aardvark": "ツチブタ",
    "abacus": "そろばん",
    "abandon": "捨てる・放棄する",
    "abase": "卑しめる",
    "abash": "恥じさせる",
    "abate": "弱める・和らげる",
    "abbreviation": "略語・省略",
    "abdomen": "腹部",
    "abduct": "誘拐する",
    "ability": "能力",
}

# Translations for the FIRST 2000 entries of the alphabetical word list, as
# requested. That head is overwhelmingly abbreviations (aaa, aam), place
# names (aachen, abbeville) and French/Neo-Latin derivatives (abacinate,
# abbacy), so words with no settled Japanese rendering are tagged with
# their category instead of being left blank. The table lives in
# data/head2000.json so this generator stays readable.
HEAD_2000_PATH = os.path.join(DATA_DIR, "head2000.json")


def _load_head_2000():
    if not os.path.exists(HEAD_2000_PATH):
        return {}
    with open(HEAD_2000_PATH, "r", encoding="utf-8") as handle:
        return json.load(handle)


# Japanese glosses for the short words (3 letters or fewer). Kept as a separate
# table so the sample words above stay readable.
SHORT_TRANSLATIONS = {
    # ── 1 letter ──
    "a": "一つ・一件・任意の一",
    "i": "私",
    "o": "おお・呼びかけ",
    "y": "はいはい・（理由）何で",
    # ── 2 letters ──
    "ad": "広告",
    "ah": "ああ・啊（感嘆）",
    "am": "である・午前",
    "an": "一つの・（英語）新聞論説",
    "as": "として・〜のように",
    "at": "〜で・〜的地方（〜に）",
    "be": "である・存在する",
    "by": "〜によって・〜のそばに",
    "do": "する・（助動詞）",
    "go": "行く",
    "he": "彼・彼ら",
    "hi": "やあ・こんにちは",
    "if": "もし・〜ならば",
    "in": "〜の中に・〜で",
    "is": "である・〜です",
    "it": "それ・それは",
    "me": "私・〜に（目的格）",
    "my": "私の",
    "no": "いいえ・〜ではない",
    "of": "〜の・〜の由来",
    "on": "〜の上に・〜について",
    "or": "または・〜である",
    "ox": "雄牛・去勢した雄牛",
    "to": "〜へ・〜に",
    "up": "上に・立ち上がる",
    "us": "私たち・（略）アメリカ",
    "we": "私たちは",
    # ── 3 letters ──
    "ace": "エース・一等内容",
    "act": "する・行為・幕",
    "add": "加える・足す・追加する",
    "age": "年齢・時代・老いる",
    "aid": "助け・支援する",
    "aim": "目指す・目的・狙う",
    "air": "空気・空・旅立ち",
    "all": "すべて・全ての",
    "and": "そして・〜と",
    "ant": "アリ・（気長に）",
    "any": "どんな・少しでも",
    "ape": "類人猿・〜のまねをする",
    "arc": "円弧・弧・物語の流れ",
    "are": "である・〜は",
    "arm": "腕・武器・力",
    "art": "芸術・美術・技術",
    "ask": "尋ねる・頼む",
    "ate": "〜を食べた（eat の過去形）",
    "bad": "悪い・不良の",
    "bag": "かばん・袋",
    "bar": "バー・棒・酒場",
    "bat": "コウモリ・バット",
    "bed": "ベッド・寝床",
    "bee": "ミツバチ",
    "big": "大きい・巨大な",
    "bit": "少し・ビット",
    "box": "箱・ボックス",
    "boy": "少年・男の子",
    "bus": "バス",
    "but": "しかし・〜だけ",
    "buy": "買う・購入",
    "can": "できる・缶",
    "cap": "帽子・キャップ",
    "car": "車・自動車",
    "cat": "猫",
    "cow": "牛・牝牛",
    "cup": "カップ・茶杯",
    "cut": "切る・カット",
    "day": "日・昼",
    "die": "死ぬ・ダイス",
    "dog": "犬",
    "dry": "乾いた・干す",
    "ear": "耳",
    "eat": "食べる",
    "egg": "卵・玉子",
    "end": "終える・終わり",
    "era": "時代・年代",
    "eye": "目",
    "far": "遠い",
    "fat": "太った・脂肪",
    "few": "少しの・わずかの",
    "fly": "飛ぶ・はえ",
    "for": "〜のために・〜のために",
    "fox": "キツネ",
    "fun": "楽しい・娯楽",
    "gas": "ガス・ガソリン",
    "get": "得る・〜になる",
    "god": "神",
    "got": "〜た（have/get の過去分詞）",
    "gun": "銃",
    "guy": "男・家伙",
    "gym": "ジム・体育館",
    "had": "〜た（have の過去形）",
    "ham": "ハム",
    "has": "持つ・have の3人称",
    "hat": "帽子",
    "hey": "やあ・（hey）",
    "him": "彼を・〜に（目的格）",
    "his": "彼の・〜の彼",
    "hot": "熱い",
    "hub": "ハブ・中心",
    "ice": "氷・アイス",
    "ink": "インク・墨",
    "inn": "宿・旅館",
    "its": "その・〜のそれ",
    "jam": "ジャム・詰まる",
    "jar": "壺・瓶",
    "jaw": "あご・顎",
    "jet": "ジェット機",
    "job": "仕事",
    "joy": "喜び",
    "key": "鍵・重要な",
    "kid": "子供",
    "kin": "親族・血族",
    "kit": "キット・工具",
    "lab": "研究所・実験室",
    "lad": "若者・青年",
    "law": "法律・法則",
    "lay": "横たえる・置く",
    "leg": "脚・腿",
    "let": "させる",
    "lid": "ふた・まぶた",
    "lie": "横たわる・嘘をつく",
    "lip": "唇・縁口",
    "log": "丸太・記録",
    "lot": "多く・束",
    "low": "低い",
    "mad": "狂った・怒った",
    "man": "男・人間",
    "map": "地図・写す",
    "mat": "マット・むしろ",
    "may": "かもしれない・5月",
    "men": "男たち",
    "met": "会った・（出会った）",
    "mix": "混ぜる・ミックス",
    "mob": "群衆",
    "mud": "泥",
    "mug": "マグカップ・不遇の人物",
    "net": "ネット・網・正味で",
    "new": "新しい",
    "nod": "うなずく・同意する",
    "not": "〜ない",
    "now": "今・現在",
    "nut": "ナッツ・木の実",
    "oar": "櫂",
    "odd": "奇妙な・奇数の",
    "off": "オフの・〜して",
    "oil": "油・オイル",
    "old": "古い・年上の",
    "one": "一・一つ",
    "out": "外へ",
    "owl": "フクロウ",
    "own": "自分の・持つ",
    "pad": "パッド・詰め物",
    "pan": "パン・平らな鍋",
    "par": "標準・パー・同等の",
    "pat": "なでる・（軽く叩く）",
    "paw": "足",
    "pay": "支払う・給料",
    "peg": "ペグ・（木栓）",
    "pen": "ペン",
    "pet": "ペット・飼う",
    "pie": "パイ",
    "pig": "豚",
    "pin": "ピン・留め針",
    "pit": "穴",
    "pod": "豆莢・ポッド",
    "pot": "ポット",
    "pub": "パブ・酒場",
    "rag": "ぼろ布",
    "ram": "雄羊・ラム",
    "rat": "ネズミ",
    "raw": "生の・未加工の",
    "ray": "光線・レイ",
    "red": "赤い",
    "rib": "肋骨・リブ",
    "rid": "取り除く",
    "rim": "縁・リム",
    "rob": "強盗する",
    "rod": "ロッド",
    "rot": "腐る",
    "row": "列・口論",
    "rub": "こする・摩擦",
    "rug": "ラグ・敷物",
    "run": "走る・経営する",
    "sad": "悲しい",
    "sat": "座った（sit の過去形）",
    "saw": "見た（see の過去形）・鋸",
    "say": "言う",
    "sea": "海",
    "see": "見る・分かる",
    "set": "セット・集合",
    "sex": "性・セックス",
    "she": "彼女",
    "shy": "内気な",
    "sin": "罪",
    "sir": "先生",
    "sit": "座る",
    "six": "六",
    "sky": "空",
    "son": "息子",
    "spy": "スパイ",
    "sun": "太陽",
    "sup": "夕食",
    "tax": "税・タクシー",
    "tea": "茶・紅茶",
    "ten": "十",
    "the": "その・（冠詞）",
    "tie": "ネクタイ・結ぶ",
    "tin": "錫・錫の器",
    "tip": "チップ・先端",
    "toe": "つま先",
    "top": "トップ・頂上",
    "toy": "おもちゃ",
    "try": "試みる",
    "tub": "浴槽",
    "two": "二",
    "use": "使う・用途",
    "van": "バン",
    "via": "経由",
    "war": "戦争",
    "was": "だった（be の過去形）",
    "wax": "ろうそく",
    "way": "道・方法",
    "web": "ウェブ",
    "wet": "濡れた",
    "who": "誰",
    "why": "なぜ",
    "win": "勝つ",
    "wit": "機知・機智",
    "woe": "悲しみ",
    "won": "勝った（win の過去形）",
    "woo": "求愛する・woo（ woo ）",
    "wow": "感嘆・Wow（驚嘆）",
    "yak": "ヤク（Yak）",
    "yam": "ヤム（イモ）",
    "yes": "はい",
    "yet": "まだ",
    "you": "あなた",
    "zip": "ジップ・Zip（ジップ）",
    "zoo": "動物園・Zoo（動物園）",
}


def main() -> None:
    words = set()
    with open(DICT_TXT, "r", encoding="utf-8") as handle:
        for line in handle:
            word = line.strip()
            if word:
                words.add(word.lower())

    # A translation is only kept when the word really exists in the dictionary,
    # so the table can never advertise a word the game would reject.
    table = dict(SAMPLE_TRANSLATIONS)
    table.update(SHORT_TRANSLATIONS)
    head_2000 = _load_head_2000()
    # Sample words win over the head-300 table if the same word is in both.
    for word, gloss in head_2000.items():
        table.setdefault(word, gloss)
    translations = {w: t for w, t in table.items() if w in words}

    # A word that has a translation is stored ONLY in "translations" (that is
    # what the translation is for), so remove it from "words" to keep the two
    # sections disjoint. The game treats the union as the accepted word list.
    translated = set(translations)
    words = words - translated

    sorted_words = sorted(words)
    sorted_translations = dict(sorted(translations.items()))

    # Hand-formatted rather than json.dump: one word (and one gloss) per line so
    # the file stays readable and diffable in an editor. The game only parses it,
    # so the extra whitespace is irrelevant to it.
    out = []
    out.append("{")
    out.append('\t"words": [')
    for i, word in enumerate(sorted_words):
        tail = "," if i < len(sorted_words) - 1 else ""
        out.append('\t\t"%s"%s' % (word, tail))
    out.append("\t],")
    out.append('\t"translations": {')
    items = list(sorted_translations.items())
    for i, (word, gloss) in enumerate(items):
        tail = "," if i < len(items) - 1 else ""
        out.append('\t\t"%s": "%s"%s' % (word, gloss, tail))
    out.append("\t}")
    out.append("}")
    text = "\n".join(out) + "\n"

    with open(OUT_JSON, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)

    # Fail loudly rather than shipping a file the game cannot parse.
    check = json.loads(text)
    assert len(check["words"]) == len(sorted_words)
    assert len(check["translations"]) == len(sorted_translations)

    size_mb = os.path.getsize(OUT_JSON) / (1024 * 1024)
    print("words: %d" % len(sorted_words))
    print("translations: %d" % len(sorted_translations))
    print("dropped (not in dictionary): %d" % (len(table) - len(sorted_translations)))
    print("lines: %d" % (len(out) + 1))
    print("written: %s (%.2f MB)" % (os.path.basename(OUT_JSON), size_mb))


if __name__ == "__main__":
    main()
