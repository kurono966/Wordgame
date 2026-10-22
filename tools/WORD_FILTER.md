# 単語辞書の監査と承認済み候補の適用

ユーザーの適用指示により、監査時397,561語から削除候補20,268語を除外し、
現在は377,293語。翻訳101,957件はすべて保持。保留244,561語も保持。
監査レポート `word_filter_report` は適用前の判断記録として固定する。
適用後の監査の既定出力は `word_filter_current_report` に分ける。

```powershell
python -m pip install --target tools/_translation_deps -r tools/translation_requirements.txt
python tools/fetch_filter_sources.py
python tools/audit_word_dictionary.py --limit 500 --output-dir tools/_filter_sample
python tools/audit_word_dictionary.py
python tests/check_word_filter_audit.py
```

結果は `tools/word_filter_report/REPORT.md`、集計・影響評価は `summary.json`、
全語の理由・頻度・収録辞書・活用元・調査フラグは `decisions.tsv` に出力する。
`accept.txt` / `hold.txt` / `candidate.txt` は分類一覧であり、ゲームの入力には使わない。
監査スクリプト自体はゲームデータを変更しない。
対象は現行JSONの `words` と `translations` のキーの和集合。

`python tools/apply_word_filter.py` は承認済み候補のハッシュ・監査入力の一致を
確認して適用する。適用済みなら一致確認のみを行う。適用記録と除外一覧は
`filter_sources/applied_filter.json`、`filter_sources/applied_exclusions.txt`。
`data/dictionary.txt` もJSONの有効語集合と一致させ、フォールバック時の再混入を防ぐ。
敵名生成ロジックとカード定義は変更しない。

元のJSON、テキスト辞書、翻訳カバー率は `filter_backups/*.gz` に無損失保存。
復元する際は対応するファイルをgzip展開して元のdata配下へ戻し、
`applied_exclusions.txt` と `applied_filter.json` の適用状態も解除する。
通常の翻訳再生成は除外一覧を維持し、削除語を再追加しない。

閾値、英語の地域・綴り変種、サンプル数、乱数シード、手動判断一覧は
`word_filter_config.json` で変更できる。`--config`、`--output-dir` で別条件を比較可能。

判断順序：手動保留・採用 → 不適切な用法の調査保留 → SCOWL 70以下 →
Zipf 3以上 → 裏付けのある原形からの活用形 → 複数辞書 → 手動削除候補 →
既存訳ありを保留 → 辞書1件を保留 → Zipf 1以上を保留 → 形式不明を保留 →
辞書0件かつZipf 1未満を削除候補。
手動削除候補でも、一般語・活用形の保護が優先する。

辞書票はSCOWL（全サイズの通常語）、WordNet、既存EJDictの3系列。
SCOWL 70以下の判定には通常の小文字語のみを使い、proper-names/upperは
別途調査フラグにする。英米加豪、British -ise/-ize、variant 1までを含める。
WordNetの多語表現は文字を結合せず対象外とする。
wordfreqは頻度証拠であり、独立した辞書1票には数えない。
複数辞書も完全に独立した編纂ではないため、「票数」は正しさの証明ではない。

活用形はLemmInflectの実在する品詞別変化とWordNet例外表を照合する。
頻度・SCOWL・複数辞書で原形の裏付けがある場合に保護する。
未知語の接尾辞推測・ニューラル生成は使わず、新しい有効語も追加しない。
固有名詞・略語・長い低頻度語のフラグは断定ではない。
WordNetの不適切用法の定義を要調査として保留する（例文中の語は除く）。
網羅的な差別語検査・誤字判定・人手の意味審査は実施していない。
高頻度の人名・略語も指定された原則に従って採用され得るため、調査フラグを残す。

影響比較は現状、削除候補のみ除外した仮想集合、採用語のみの仮想集合。
敵名は実装のA–Z・3〜9文字条件で候補数・平均長・文字分布を比較する。
文字プール不足のある敵名も数えるが、実装は不足分をランダム補充するため
直ちに不具合とはしない。Q/Xが通常プールにない点も反映している。
カード診断は実装のCARD_DEFSから抽出した通常文字カードを7枚ずつ抽出し、
3〜7文字の単語を作れる割合を同じ2,000手・固定シードで比較する。
ワイルドカード・共有スロット・スキル・報酬を含む全ゲームの難度評価ではない。
適用後のゲームでは候補20,268語を無効語として扱う。その他の判定仕様は同じ。

## 出典と再配布条件

- SCOWL 2020.12.07、Kevin Atkinson / Alan Bealeほか。
  https://wordlist.aspell.net/ / https://github.com/en-wl/wordlist/tree/rel-2020.12.07
  サイズ別finalリストを備えた固定版をDebianの原版アーカイブから取得。
  新しいESDB版ではなく、この版に対する評価である。新語の未収録もあり得る。
  `filter_sources/SCOWL-Copyright.txt` に集成物と各構成データの許諾全文を保持。
  利用・改変・商用再配布が可能。著作権・許諾・免責の保持、改変の明示、
  推薦と誤認させないこと等、構成データの条件を再配布時にも保持する。
- WordNet 3.0、Copyright 2006 Princeton University。
  https://wordnet.princeton.edu/license-and-commercial-use
  https://github.com/nltk/nltk_data （Princeton配布先の証明書エラーのためNLTKミラーを使用）
  `filter_sources/WordNet-LICENSE.txt`。無償・商用の利用、改変、再配布が可能。
  内部改変・再配布にも著作権・条件・免責全文を保持し、大学名による推薦を示唆しない。
- wordfreq 3.1.1、Robyn Speer。データはCC BY-SA 4.0、コードはApache 2.0。
  本監査の頻度付き分類・集計レポートはCC BY-SA 4.0で提供する。
  出典と改変方法は本文、元データ群（SUBTLEX: Marc Brysbaertほか、
  OpenSubtitles等）の帰属は `../data/licenses/wordfreq-NOTICE.md` に保持。
  https://github.com/rspeer/wordfreq / https://creativecommons.org/licenses/by-sa/4.0/
- EJDict (CC0)、kujirahand。翻訳補完時に取得した固定版を再利用。
  LemmInflect 0.2.3 (MIT)、Brad Jascob。活用形の照合のみ。
  既存の `../data/DICTIONARY_LICENSES.txt` と `../data/licenses/` を参照。

全入力アーカイブはSHA-256で固定・検査し、レポートにも入力辞書・参照データの
ハッシュを記録する。取得後はネット接続なしで再実行できる。
監査ファイルは `.gdignore` のあるtools配下に置き、ゲームには同梱しない。
今後結果をゲームへ適用・再配布する場合は、この帰属・許諾文書も保持する。
