extends Node
## Headless content check. Exit code 0 = PASS. See tests/README.md.

## B6 frequency table: first 19 words / all 22 words.
const FREQ_INITIAL := {"ㄱ": 5, "ㄴ": 4, "ㄷ": 3, "ㄹ": 7, "ㅁ": 5, "ㅂ": 6, "ㅅ": 2, "ㅇ": 2, "ㅊ": 1, "ㅋ": 1, "ㅎ": 1,
	"ㅏ": 4, "ㅓ": 1, "ㅕ": 1, "ㅗ": 6, "ㅜ": 5, "ㅣ": 3}
const FREQ_FULL := {"ㄱ": 9, "ㄴ": 4, "ㄷ": 3, "ㄹ": 7, "ㅁ": 6, "ㅂ": 6, "ㅅ": 3, "ㅇ": 4, "ㅈ": 1, "ㅊ": 1, "ㅋ": 1, "ㅍ": 1,
	"ㅎ": 1, "ㅏ": 5, "ㅓ": 1, "ㅕ": 1, "ㅗ": 8, "ㅛ": 1, "ㅜ": 6, "ㅣ": 5}
const WEIGHT_SUM_INITIAL := 91
const WEIGHT_SUM_FULL := 114
## B6: words each starter cannot craft before drops/replacements.
const UNCRAFTABLE := {"starter_a": ["W08", "W09"], "starter_b": ["W07"]}

var failures: Array[String] = []


func _ready() -> void:
	# Isolate persistence: never touch the real profile from a test (G14).
	Meta.saver.path = "user://test_content.json"
	Meta.new_profile()
	RunLog.enabled = false  # tests never leave run logs behind
	var db := ContentDB.load_all()
	failures.append_array(db.validate())
	if db.balance != null and failures.is_empty():
		_check_frequency(db)
		_check_decks(db)
		_check_tables(db)
	_check_hangul()
	for f in failures:
		printerr("FAIL: " + f)
	print("test_content: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	Meta.saver.delete_all()
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _check_frequency(db: ContentDB) -> void:
	for pair in [[false, FREQ_INITIAL, WEIGHT_SUM_INITIAL], [true, FREQ_FULL, WEIGHT_SUM_FULL]]:
		var weights: Dictionary = db.spawn_weights(pair[0])
		var expected: Dictionary = pair[1]
		var sum := 0
		for j in weights:
			sum += weights[j]
		_expect(weights.size() == expected.size(), "frequency(%s): %d jamo types, expected %d" % [pair[0], weights.size(), expected.size()])
		_expect(sum == pair[2], "frequency(%s): weight sum %d, expected %d" % [pair[0], sum, pair[2]])
		for j in expected:
			var want: int = expected[j] + db.balance.spawn_weight_bonus
			_expect(weights.get(j, -1) == want, "frequency(%s): %s weight %s, expected %d" % [pair[0], j, weights.get(j, -1), want])


func _craftable(word: WordData, counts: Dictionary) -> bool:
	var need := {}
	for j in word.required_jamo:
		need[j] = need.get(j, 0) + 1
	for j in need:
		if counts.get(j, 0) < need[j]:
			return false
	return true


func _check_decks(db: ContentDB) -> void:
	_expect(db.decks.size() == 2, "decks: expected starter_a and starter_b")
	for id in db.decks:
		var counts: Dictionary = db.decks[id].counts()
		var blocked: Array = UNCRAFTABLE.get(String(id), [])
		for w in db.base_words():
			if w.unlock != &"start":
				continue
			var ok := _craftable(w, counts)
			if String(w.id) in blocked:
				_expect(not ok, "deck %s: %s should NOT be craftable" % [id, w.id])
			else:
				_expect(ok, "deck %s: %s should be craftable" % [id, w.id])
	# Tutorial hand must be real Starter A tokens (G2/B3).
	var a_counts: Dictionary = db.decks["starter_a"].counts()
	var hand := {}
	for j in db.balance.tutorial_hand:
		hand[j] = hand.get(j, 0) + 1
	for j in hand:
		_expect(a_counts.get(j, 0) >= hand[j], "tutorial hand token %s missing from Starter A" % j)


func _check_tables(db: ContentDB) -> void:
	# Spot-check rows against B2/B7/B8/B9 so an edited .tres cannot drift silently.
	var w1: WaveData = db.waves[1]
	_expect(w1.enemy_count == 8 and w1.concurrent_max == 4 and w1.spawn_interval == 1.8 and w1.base_hp == 2.0, "B2 wave 1 row")
	var w19: WaveData = db.waves[19]
	_expect(w19.enemy_count == 24 and w19.base_hp == 9.0 and w19.variant_chance == 0.2, "B2 wave 19 row")
	var sword: WordData = db.words["W01"]
	_expect(sword.rank1[0].value == 0.30 and sword.rank3.size() == 2, "B7 검 ranks")
	var greed: WordData = db.words["W20"]
	_expect(greed.is_risk() and greed.unlock == &"after_mieum", "B7 욕심 risk/unlock")
	var runaway: WordData = db.words["W22"]
	_expect(runaway.requires_any_word.size() == 2 and runaway.requires_any_word.has(&"W06") and runaway.requires_any_word.has(&"W17"), "B7 폭주 requires 활/비")
	var c01: CompoundData = db.compounds["C01"]
	_expect(c01.material_a == &"W02" and c01.material_a_min_rank == 2 and c01.material_b == &"W16", "B8 불길 recipe")
	_expect(db.words["C01"].max_rank() == 1, "B8 compound max rank 1")
	var mieum: BossData = db.bosses["B_MIEUM"]
	_expect(mieum.hp == 90.0 and mieum.gold == 30 and mieum.body_drop.size() == 2, "B9 ㅁ row")
	var ieung: BossData = db.bosses["B_IEUNG"]
	_expect(ieung.boss_position == Vector2(1200, 260) and ieung.marker_positions.size() == 3, "B9 ㅇ layout")
	var greed_boss: BossData = db.bosses["B_GREED"]
	_expect(greed_boss.shield_per_minion == 3.0 and greed_boss.shield_cap == 24.0 and greed_boss.minion_schedule.size() == 5, "B9 탐욕 shield/minions")
	_expect(db.synergies.size() == 3 and db.research.size() == 3 and db.motion_profiles.size() == 6, "B8/B10/G11 counts")


func _check_hangul() -> void:
	_expect("".join(HangulJamo.decompose("활")) == "ㅎㅗㅏㄹ", "hangul: 활 splits ㅘ")
	_expect("".join(HangulJamo.decompose("욕심")) == "ㅇㅛㄱㅅㅣㅁ", "hangul: 욕심")
	_expect("".join(HangulJamo.decompose("비")) == "ㅂㅣ", "hangul: no tail")
	# Unsupported compounds stay intact so the validator rejects them.
	_expect("".join(HangulJamo.decompose("닭")) == "ㄷㅏㄺ", "hangul: ㄺ not split")
