extends SceneTree

# Balance probe for the part system. Not a pass/fail test — it prints the shape
# of the data so the numbers can be judged. Run it after changing
# PART_CHUNK_LEN / PART_MIN_LEN to see what that does to a real run.

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var gm = root.get_node("GameManager")
	# Sample real enemy names the same way a run does.
	var names: Array = []
	while names.size() < 400:
		var n: String = gm._roll_enemy_name()
		if not names.has(n):
			names.append(n)

	var by_count: Dictionary = {}
	var by_len: Dictionary = {}
	var min_count: int = 99
	var max_count: int = 0
	for n: String in names:
		var parts: Array = gm.build_enemy_parts(n)
		by_count[parts.size()] = int(by_count.get(parts.size(), 0)) + 1
		var key: int = str(n).length()
		by_len[key] = int(by_len.get(key, 0)) + 1
		min_count = mini(min_count, parts.size())
		max_count = maxi(max_count, parts.size())
		# How many parts is a typical 4-letter word likely to hit? This is the
		# number that decides whether part destruction is a real alternative or
		# a free win.
		var hits: Array = gm.match_parts_in_word(n)
		by_count["selfhit_%d" % hits.size()] = int(by_count.get("selfhit_%d" % hits.size(), 0)) + 1

	print("Sampled %d distinct enemy names" % names.size())
	print("parts per enemy: min=%d max=%d" % [min_count, max_count])
	var keys: Array = by_count.keys()
	keys.sort()
	for k: Variant in keys:
		if k is int:
			print("  %d part(s): %d names" % [k, by_count[k]])
	print("name lengths:")
	var lk: Array = by_len.keys()
	lk.sort()
	for k: Variant in lk:
		print("  %d letters: %d names" % [k, by_len[k]])
	print("TEST_EXIT=0")
	quit(0)
