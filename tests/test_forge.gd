extends Node
## Headless checks for ForgeService / BuildState (G4/G5/G6, B3) and the Forge screen flow.

const RUN_GAME := preload("res://scenes/run/run_game.tscn")

var failures: Array[String] = []
var db: ContentDB


func _ready() -> void:
	db = ContentDB.load_all()
	if not db.validate().is_empty():
		failures.append("content invalid")
	else:
		_check_shuffle_and_tokens()
		_check_lock_and_reroll()
		_check_candidates()
		_check_restore_transaction()
		_check_failure_pity()
		_check_tutorial_and_pin()
		_check_scene_flow()
	for f in failures:
		printerr("FAIL: " + f)
	print("test_forge: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().paused = false
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _pool() -> Array[WordData]:
	var out: Array[WordData] = []
	for w in db.base_words():
		if w.unlock == &"start":
			out.append(w)
	return out


func _forge(deck: DeckService, build: BuildState, seed: int, bonus: int = 0, tutorial: Array[String] = []) -> ForgeService:
	var f := ForgeService.new()
	f.start(deck, db, build, _pool(), seed, bonus, tutorial)
	return f


func _build() -> BuildState:
	var b := BuildState.new()
	b.setup(db.balance)
	return b


func _ids(tokens: Array[Dictionary]) -> Array:
	var out := []
	for t in tokens:
		out.append(t["id"])
	return out


func _hand_with(deck: DeckService, build: BuildState, jamo: Array[String]) -> ForgeService:
	# Puts real deck tokens of the given jamo into the hand (tutorial path), rest shuffled.
	return _forge(deck, build, 1, 0, jamo)


func _check_shuffle_and_tokens() -> void:
	var deck := DeckService.from_deck_data(db.decks["starter_a"], db.balance)
	var f := _forge(deck, _build(), 100)
	_expect(f.hand.size() == 7 and f.draw.size() == 13 and f.discard.is_empty(), "hand 7, draw 13")
	_expect(f.token_total() == deck.size(), "token count preserved at start")
	var overlap := false
	for id in _ids(f.hand):
		if id in _ids(f.draw):
			overlap = true
	_expect(not overlap, "no token in both hand and draw (non-replacement)")
	var g := _forge(deck, _build(), 101)
	_expect(_ids(f.hand) != _ids(g.hand), "different seed -> different full shuffle")
	var h := _forge(deck, _build(), 100)
	_expect(_ids(f.hand) == _ids(h.hand), "same seed -> same hand (save reproducible)")
	f.finish()
	_expect(deck.size() == 20 and f.hand.is_empty(), "finish returns every token to the deck")


func _check_lock_and_reroll() -> void:
	var deck := DeckService.from_deck_data(db.decks["starter_a"], db.balance)
	var f := _forge(deck, _build(), 5)
	var ids := _ids(f.hand)
	_expect(f.toggle_lock(ids[0]) and f.toggle_lock(ids[1]) and f.toggle_lock(ids[2]), "lock three")
	_expect(not f.toggle_lock(ids[3]) and f.locked.size() == 3, "fourth lock refused, existing locks kept")
	_expect(f.toggle_lock(ids[2]) and f.locked.size() == 2, "toggle unlocks")
	_expect(not f.toggle_lock(9999), "cannot lock a token outside the hand")
	_expect(f.reroll_slots() == 5 and f.can_reroll(), "reroll preview: 5 slots change")
	var before_draw := _ids(f.draw)
	_expect(f.reroll(), "first reroll")
	_expect(f.rerolls_left == 1 and f.hand.size() == 7, "rerolls 2 -> 1, hand still 7")
	_expect(_ids(f.hand)[0] == ids[0] and _ids(f.hand)[1] == ids[1], "locked tokens stay in place")
	_expect(f.discard.size() == 5 and f.draw.size() == 8, "unlocked tokens went to discard, 5 drawn")
	for id in _ids(f.hand):
		_expect(id not in before_draw or id not in _ids(f.discard), "no duplicate token ids")
	for id in _ids(f.hand).slice(2):
		_expect(id in before_draw, "new tokens came from the draw pile")
	_expect(f.token_total() == 20, "token count preserved after reroll")
	_expect(f.reroll(), "second reroll")
	_expect(not f.can_reroll() and not f.reroll(), "no third reroll")
	# Draw exhaustion: a 14-token deck reshuffles the discard into the draw pile.
	var small := DeckService.from_deck_data(db.decks["starter_a"], db.balance)
	while small.size() > 14:
		small.remove_token(small.tokens[0]["id"])
	var s := _forge(small, _build(), 8, 1)
	_expect(s.draw.size() == 7, "14-token deck: 7 in draw")
	s.reroll()
	_expect(s.draw.is_empty() and s.discard.size() == 7, "first reroll empties the draw pile")
	var discarded := _ids(s.discard)
	s.reroll()
	_expect(s.draw.size() == 0 and s.discard.size() == 7 and s.hand.size() == 7, "second reroll reshuffled the old discard into draw; outgoing hand becomes the new discard")
	for id in _ids(s.hand):
		_expect(id in discarded, "tokens returned only after the draw pile ran dry")
	for id in _ids(s.discard):
		_expect(id not in discarded, "the hand that was just rerolled is not in the reroll pool")
	_expect(s.token_total() == 14, "token count preserved after reshuffle")


func _check_candidates() -> void:
	var deck := DeckService.from_deck_data(db.decks["starter_a"], db.balance)
	var build := _build()
	var f := _hand_with(deck, build, ["ㄱ", "ㅓ", "ㅁ", "ㅎ", "ㅗ", "ㅏ", "ㄹ"])
	var ids: Array = []
	for c in f.candidates():
		ids.append(String(c["word"].id))
	_expect("W01" in ids, "검 (ㄱㅓㅁ) is a candidate %s" % [ids])
	_expect("W06" in ids, "활 needs ㅗ+ㅏ split (G5) %s" % [ids])
	_expect("W02" not in ids, "불 not craftable without ㅂㅜ")
	for c in f.candidates():
		_expect(c["kind"] == ForgeService.KIND_NEW and not c["needs_replace"], "empty build: every candidate is new")
	build.add(&"W01")
	build.words[0]["rank"] = 3
	_expect(f.candidate_for(&"W01").is_empty(), "max Rank held word excluded")
	build.words[0]["rank"] = 2
	_expect(f.candidate_for(&"W01")["kind"] == ForgeService.KIND_RANK_UP, "held below max -> rank_up")
	for id in [&"W03", &"W04", &"W05", &"W07", &"W08"]:
		build.add(id)
	_expect(build.is_full(), "six words fill the build")
	_expect(f.candidate_for(&"W06")["needs_replace"], "slot full: new word needs a replace but stays valid")
	# 폭주 requires 활 or 비 (B7) and 위험 words respect the risk cap.
	var pool2: Array[WordData] = [db.words["W22"], db.words["W20"], db.words["W06"]]
	var b2 := _build()
	for j in ["ㅍ", "ㅈ", "ㅛ", "ㄱ", "ㅅ", "ㅣ", "ㅁ"]:
		deck.add_token(j)
	var f3 := ForgeService.new()
	f3.start(deck, db, b2, pool2, 3, 0, ["ㅍ", "ㅗ", "ㄱ", "ㅈ", "ㅜ", "ㅇ", "ㅛ"] as Array[String])
	_expect(f3.hand_counts().get("ㅍ", 0) == 1 and f3.hand_counts().get("ㅈ", 0) == 1, "hand holds the added ㅍ/ㅈ")
	_expect(f3.candidate_for(&"W22").is_empty(), "폭주 needs 활 or 비 held")
	b2.add(&"W06")
	_expect(not f3.candidate_for(&"W22").is_empty(), "폭주 available once 활 is held")
	b2.add(&"W22")
	var f4 := ForgeService.new()
	f4.start(deck, db, b2, pool2, 3, 0, ["ㅇ", "ㅛ", "ㄱ", "ㅅ", "ㅣ", "ㅁ", "ㅜ"] as Array[String])
	var greed := f4.candidate_for(&"W20")
	_expect(not greed.is_empty() and greed["replace_risk"], "second 위험 word must replace the held one")
	_expect(not f4.restore(&"W20"), "risk restore without a swap target refused")
	_expect(not f4.restore(&"W20", &"W06"), "risk swap must target the 위험 word")
	_expect(f4.restore(&"W20", &"W22") and b2.has(&"W20") and not b2.has(&"W22"), "risk swap replaces 폭주 with 욕심")


func _check_restore_transaction() -> void:
	var deck := DeckService.from_deck_data(db.decks["starter_a"], db.balance)
	var build := _build()
	var f := _hand_with(deck, build, ["ㄱ", "ㅓ", "ㅁ", "ㅂ", "ㅜ", "ㄹ", "ㅣ"])
	_expect(not f.restore(&"W08"), "cannot restore a non-candidate")
	_expect(f.restore(&"W01"), "restore 검")
	_expect(build.has(&"W01") and build.rank_of(&"W01") == 1 and f.restored_word == &"W01", "new word at Rank 1")
	_expect(not f.can_restore() and not f.restore(&"W02"), "one restore per Forge")
	_expect(not f.can_reroll(), "no reroll after restoring")
	_expect(f.token_total() == 20, "hand tokens untouched by restore")
	var g := _hand_with(deck, build, ["ㄱ", "ㅓ", "ㅁ", "ㅂ", "ㅜ", "ㄹ", "ㅣ"])
	_expect(g.candidate_for(&"W01")["kind"] == ForgeService.KIND_RANK_UP, "next Forge: 검 is a rank-up")
	_expect(g.restore(&"W01") and build.rank_of(&"W01") == 2, "rank up to 2")
	for id in [&"W02", &"W03", &"W04", &"W05", &"W07"]:
		build.add(id)
	var h := _hand_with(deck, build, ["ㄴ", "ㅜ", "ㄴ", "ㄱ", "ㅣ", "ㄹ", "ㅎ"])
	_expect(h.candidate_for(&"W16")["needs_replace"], "길 needs a slot")
	_expect(not h.restore(&"W16"), "slot-full restore without a target refused")
	_expect(h.restore(&"W16", &"W03") and build.has(&"W16") and not build.has(&"W03"), "swap 독 for 길")
	_expect(build.rank_of(&"W16") == 1 and build.words.size() == 6, "replacement enters at Rank 1")
	var again := _hand_with(deck, build, ["ㄷ", "ㅗ", "ㄱ", "ㅏ", "ㅓ", "ㅜ", "ㅣ"])
	_expect(again.candidate_for(&"W03")["needs_replace"], "discarded 독 is a new (Rank 1) candidate again")


func _check_failure_pity() -> void:
	var run := RunController.new()
	run.run_seed = 21
	run.setup(db)
	run.open_run_setup()
	run.confirm_setup(&"starter_a")
	run.first_run = false
	run.begin_combat()
	run.on_wave_cleared()
	run.finish_clear()
	var f := run.start_forge()
	_expect(f != null and f.rerolls_left == 2, "base rerolls 2")
	# Force a failure: empty the pool so no candidate can ever appear.
	f.pool = []
	f.reroll()
	f.reroll()
	_expect(f.is_failed(), "no candidates after the last reroll = 복원 실패")
	run.stability = 50.0
	_expect(run.finish_forge() and run.phase == RunController.Phase.WAVE_PREP, "finish_forge advances")
	_expect(run.stability == 58.0 and run.forge_fail_bonus == 1, "failure: +8 stability, next Forge reroll +1")
	run.begin_combat()
	run.on_wave_cleared()
	run.finish_clear()
	var g := run.start_forge()
	_expect(g.rerolls_left == 3, "bonus reroll applied once")
	g.pool = []
	g.reroll()
	g.reroll()
	g.reroll()
	run.finish_forge()
	_expect(run.forge_fail_bonus == 1, "bonus capped at 1")
	run.begin_combat()
	run.on_wave_cleared()
	run.finish_clear()
	var h := run.start_forge()
	_expect(h.rerolls_left == 3, "still 3 rerolls")
	# Voluntary skip with a candidate: no pity, bonus unchanged; success resets it.
	h.pool = [db.words["W01"]]
	h.hand = [{"id": 900, "jamo": "ㄱ"}, {"id": 901, "jamo": "ㅓ"}, {"id": 902, "jamo": "ㅁ"}]
	h.draw = run.deck.tokens.slice(0, 17)
	h.discard = []
	_expect(h.is_voluntary_skip() and not h.is_failed(), "candidate present: skipping is voluntary")
	run.finish_forge()
	_expect(run.forge_fail_bonus == 1, "voluntary skip keeps the pending bonus but adds none")
	run.begin_combat()
	run.on_wave_cleared()
	run.finish_clear()
	var k := run.start_forge()
	k.pool = [db.words["W01"]]
	k.hand = [{"id": 900, "jamo": "ㄱ"}, {"id": 901, "jamo": "ㅓ"}, {"id": 902, "jamo": "ㅁ"}]
	k.draw = run.deck.tokens.slice(0, 17)
	k.discard = []
	_expect(k.restore(&"W01"), "restore succeeds")
	run.finish_forge()
	_expect(run.forge_fail_bonus == 0, "success resets the failure bonus")
	run.free()


func _check_tutorial_and_pin() -> void:
	var run := RunController.new()
	run.run_seed = 4
	run.setup(db)
	run.open_run_setup()
	run.confirm_setup(&"starter_a")
	run.begin_combat()
	run.on_wave_cleared()
	run.finish_clear()
	var f := run.start_forge()
	var jamo := []
	for t in f.hand:
		jamo.append(t["jamo"])
	jamo.sort()
	var want := ["ㄱ", "ㅓ", "ㅁ", "ㅂ", "ㅜ", "ㄹ", "ㅣ"]
	want.sort()
	_expect(jamo == want, "first Forge deals the B3 tutorial hand from real tokens %s" % [jamo])
	_expect(f.token_total() == 20, "tutorial hand keeps the token count")
	var ids: Array = []
	for c in f.candidates():
		ids.append(String(c["word"].id))
	for id in ["W01", "W02", "W10", "W16", "W17"]:
		_expect(id in ids, "tutorial candidate %s present %s" % [id, ids])
	run.pin_word(&"W08")
	var st := f.pin_status(&"W08")
	_expect(not st["possible"] and st["missing"] == {"ㅋ": 1}, "Starter A pin 칼: ㅋ 없음")
	_expect(run.pin_lacking() == (["ㅋ"] as Array[String]), "pinned lacking jamo feeds the spawn bonus")
	run.pin_word(&"W01")
	_expect(f.pin_status(&"W01")["possible"], "검 reachable with Starter A")
	run.finish_forge()
	_expect(run.pinned_word == &"W01", "pin persists after the Forge")
	run.free()


func _check_scene_flow() -> void:
	var game := RUN_GAME.instantiate()
	game.run_seed = 12
	game.set_physics_process(false)
	add_child(game)
	var run: RunController = game.get_node("RunController")
	var panel := game.get_node("%ForgePanel")
	run.begin_combat()
	run.on_wave_cleared()
	game.get_node("%ClearPanel").get_node("%FinishButton").pressed.emit()
	_expect(run.phase == RunController.Phase.FORGE and panel.visible and run.forge != null, "FORGE opens the panel with a live Forge")
	_expect(panel.get_node("%HandRow").get_child_count() == 7, "seven hand buttons")
	_expect(panel.get_node("%Candidates").get_child_count() >= 2, "tutorial hand lists candidates")
	panel._select(&"W01")
	panel.get_node("%RestoreButton").pressed.emit()
	_expect(run.build.has(&"W01"), "restore button adds 검 to the build")
	_expect(panel.get_node("%RerollButton").disabled, "no reroll after restoring")
	panel.get_node("%FinishButton").pressed.emit()
	_expect(run.phase == RunController.Phase.WAVE_PREP and run.wave == 2 and run.forge == null, "빌드 확정 -> W2 prep")
	_expect(run.deck.size() == 20, "deck intact after the Forge")
	game.queue_free()
