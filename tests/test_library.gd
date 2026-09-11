extends Node
## Headless checks for the 마지막 서고 (G9/G10, B10, S5/S7): research rules, codex rows,
## starter deck rows, layers/badges, sentence stages, narrative lines and the screen wiring.

const LIBRARY := preload("res://scenes/hub/last_library.tscn")
const RUN_GAME := preload("res://scenes/run/run_game.tscn")

var failures: Array[String] = []
var db: ContentDB


func _ready() -> void:
	# Isolate persistence: never touch the real profile from a test (G14).
	Meta.saver.path = "user://test_library.json"
	Meta.new_profile()
	db = ContentDB.load_all()
	if not db.validate().is_empty():
		failures.append("content invalid: %s" % db.validate()[0])
	else:
		_check_research()
		_check_codex()
		_check_decks_and_pin()
		_check_layers_badges_sentence()
		_check_narrative_lines()
		_check_screen()
	for f in failures:
		printerr("FAIL: " + f)
	print("test_library: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().paused = false
	Meta.saver.delete_all()
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _row(id: String) -> Dictionary:
	for r in LibraryService.research_rows(db):
		if String(r["research"].id) == id:
			return r
	return {}


func _check_research() -> void:
	Meta.new_profile()
	var r1 := _row("R_SAFE_1")
	_expect(not r1["allowed"] or not r1["affordable"], "R_SAFE_1 needs 30G")
	_expect("Gold 부족" in r1["reason"], "reason names the missing Gold (%s)" % r1["reason"])
	_expect("W5 도달" in _row("R_DECK_B")["reason"] and "선행 연구" in _row("R_SAFE_2")["reason"], "conditions explained")
	Meta.gold = 100
	_expect(_row("R_SAFE_1")["allowed"] and _row("R_SAFE_1")["affordable"], "affordable now")
	_expect(_row("R_SAFE_1")["current"] == "최대 안정도 100" and _row("R_SAFE_1")["after"] == "최대 안정도 105", "current vs after")
	_expect(LibraryService.buy_research(db, &"R_SAFE_1") and Meta.gold == 70 and Meta.has_research(&"R_SAFE_1"), "purchase deducts and records")
	_expect(not LibraryService.buy_research(db, &"R_SAFE_1"), "no double purchase")
	_expect(not LibraryService.buy_research(db, &"R_SAFE_2"), "R_SAFE_2 blocked by W10 condition")
	Meta.best_reached = 10
	_expect(_row("R_SAFE_2")["allowed"] and not _row("R_SAFE_2")["affordable"], "R_SAFE_2 allowed at W10 but 90G needed")
	Meta.gold = 90
	_expect(LibraryService.buy_research(db, &"R_SAFE_2") and Meta.gold == 0 and is_equal_approx(Meta.stability_max(db), 110.0), "R_SAFE_2 -> 110")
	Meta.load_profile()
	_expect(Meta.has_research(&"R_SAFE_2"), "purchase saved immediately")
	_expect(not LibraryService.buy_research(db, &"R_DECK_B"), "R_DECK_B needs 45G")


func _check_codex() -> void:
	Meta.new_profile()
	var sword := LibraryService.codex_row(db, db.words["W01"])
	_expect(sword["unlocked"] and not sword["discovered"] and sword["tier"] == "" and sword["effects"].size() == 3, "검: unlocked, undiscovered, R1-R3 effects listed")
	_expect(sword["materials"] == "ㄱㅓㅁ" and sword["boss"] == "거대한 ㅁ", "materials and related boss")
	var greed := LibraryService.codex_row(db, db.words["W20"])
	_expect(not greed["unlocked"] and greed["condition"].begins_with("거대한 ㅁ"), "욕심: locked with the unlock condition shown")
	Meta.mieum_purified = true
	_expect(LibraryService.codex_row(db, db.words["W20"])["unlocked"], "욕심 unlocked after ㅁ")
	var c01 := LibraryService.codex_row(db, db.words["C01"])
	_expect(c01["unlocked"] and c01["effects"].size() == 1 and "불 Rank 2" in c01["condition"], "불길: recipe shown, single Rank")
	Meta.codex["W01"] = {"mastery": 3, "best_rank": 2, "first_at": "d"}
	sword = LibraryService.codex_row(db, db.words["W01"])
	_expect(sword["discovered"] and sword["tier"] == "II" and sword["best_rank"] == 2, "복원도 II at 3")
	_expect(LibraryService.mastery_tier(db, 1) == "I" and LibraryService.mastery_tier(db, 6) == "III" and LibraryService.mastery_tier(db, 0) == "", "tiers at 1/3/6")
	Meta.boss_records = {"B_SILENCE": 1}
	var silence := LibraryService.boss_row(db, db.bosses["B_SILENCE"])
	_expect(silence["purified"] == 1 and silence["after"].begins_with("침묵은") and silence["intro"] == "아무 말도 남기지 마라.", "boss row with S6 lines after the first purify")
	_expect(LibraryService.boss_row(db, db.bosses["B_GREED"])["after"] == "", "unpurified boss keeps its record line hidden")


func _check_decks_and_pin() -> void:
	Meta.new_profile()
	var a := LibraryService.deck_row(db, db.decks["starter_a"])
	_expect(a["size"] == 20 and a["unlocked"] and a["craftable"].size() == 17 and a["blocked"] == (["칼", "눈"] as Array[String]), "Starter A: 17 craftable, 칼/눈 blocked (%s)" % [a["blocked"]])
	var b := LibraryService.deck_row(db, db.decks["starter_b"])
	_expect(not b["unlocked"] and b["blocked"] == (["창"] as Array[String]), "Starter B locked, 창 blocked")
	Meta.research = ["R_DECK_B"]
	_expect(LibraryService.deck_row(db, db.decks["starter_b"])["unlocked"], "Starter B unlocked by research")
	var run := RunController.new()
	run.setup(db)
	Meta.pinned_word = "W02"
	run.open_run_setup()
	run.confirm_setup(&"starter_a")
	_expect(run.pinned_word == &"W02", "pin loaded from Meta at RUN start")
	run.pin_word(&"W03")
	_expect(Meta.pinned_word == "W03", "pin changes persist to Meta")
	run.free()


func _check_layers_badges_sentence() -> void:
	Meta.new_profile()
	var l := LibraryService.layers(db)
	_expect(not l["title_lamp"] and not l["spines"], "no layers on a new profile")
	for i in 6:
		Meta.codex["W%02d" % (i + 1)] = {"mastery": 1}
	Meta.codex["C01"] = {"mastery": 0}
	l = LibraryService.layers(db)
	_expect(l["title_lamp"] and l["spines"] and not l["lines"], "6 base words: title+lamp and spines; compounds do not count")
	_expect(LibraryService.base_discovered(db) == 6, "base_discovered excludes compounds")
	var b := LibraryService.badges(db)
	_expect(b["first_compound"] and not b["first_clear"] and not b["twelve_words"], "badges: 첫 합성 only")
	for i in range(6, 12):
		Meta.codex["W%02d" % (i + 1)] = {"mastery": 1}
	_expect(LibraryService.layers(db)["lines"] and LibraryService.badges(db)["twelve_words"], "12 base words: lines layer and badge")
	Meta.boss_records = {"B_SILENCE": 1, "B_GREED": 2}
	l = LibraryService.layers(db)
	_expect(l["handwriting"] and l["open_book"], "boss layers")
	_expect(LibraryService.sentence_stage() == 0 and LibraryService.sentence_text(db) == "「□□□ □□□ □□□□□.」", "stage 0 sentence")
	Meta.events = ["S_SILENCE"]
	_expect(LibraryService.sentence_text(db) == "「우리는 □□□ □□□□□.」", "stage 1 after 침묵")
	Meta.events = ["S_SILENCE", "S_GREED", "S_SLICE_END"]
	_expect(LibraryService.sentence_text(db) == "「우리는 서로를 □□□□□.」" and LibraryService.badges(db)["first_clear"], "stage 2 after 탐욕, 첫 완주 badge")
	_expect(LibraryService.event_lines(db)[0] == "틀린 말을 지우다, 다른 말까지 지웠다.", "event lines in unlock order")


func _check_narrative_lines() -> void:
	Meta.new_profile()
	var run := RunController.new()
	run.run_seed = 9
	run.setup(db)
	run.open_run_setup()
	run.confirm_setup(&"starter_a")
	run.begin_combat()
	run.on_boss_purified(&"B_MIEUM")
	_expect("S_M" in Meta.events and run.take_pending_line() == "이 교정 기호를, 나는 알고 있다.", "first ㅁ purify queues the S_M line once")
	_expect(run.take_pending_line() == "", "line shown only once")
	run.on_wave_cleared()
	run.finish_clear()
	var f := run.start_forge()
	f.pool = [db.words["W01"]]
	f.hand = [{"id": 900, "jamo": "ㄱ"}, {"id": 901, "jamo": "ㅓ"}, {"id": 902, "jamo": "ㅁ"}]
	f.draw = run.deck.tokens.slice(0, 17)
	f.discard = []
	f.restore(&"W01")
	run.finish_forge()
	_expect("S_WORD" in Meta.events and run.take_pending_line() == "읽어낸 뜻이 이 페이지의 법칙이 되었다.", "first restore ever queues S_WORD")
	run.free()


func _check_screen() -> void:
	Meta.new_profile()
	var lib := LIBRARY.instantiate()
	add_child(lib)
	_expect(lib.get_node("%Opening").visible and lib.get_node("%OpeningLine1").text == "글자들은 돌아갈 말을 잃었다.", "first RUN: opening shown with the S_OPEN line")
	lib.free()
	Meta.first_run_done = true
	Meta.gold = 50
	lib = LIBRARY.instantiate()
	add_child(lib)
	_expect(not lib.get_node("%Opening").visible and lib.get_node("%GoldLabel").text == "Gold 50", "hub after the first run")
	_expect(lib.get_node("%ResearchRows").get_child_count() == 3, "three research rows")
	lib._set_codex_tab("base")
	_expect(lib.get_node("%CodexRows").get_child_count() == 22, "22 base words listed")
	lib._set_codex_tab("compound")
	_expect(lib.get_node("%CodexRows").get_child_count() == 2, "2 compounds listed")
	lib._set_codex_tab("boss")
	_expect(lib.get_node("%CodexRows").get_child_count() == 4 and lib.get_node("%CodexDetail").text.begins_with("거대한 ㅁ (W5)"), "4 bosses, first detail")
	lib._open_setup()
	_expect(lib.get_node("%RunSetup").visible and lib.get_node("%DeckRows").get_child_count() == 2, "setup lists both starters")
	_expect(lib.get_node("%DeckRows").get_child(1).disabled, "Starter B disabled until researched")
	lib.free()
	# S_RETURN: first library visit after 침묵, recorded and shown once.
	Meta.events = ["S_SILENCE"]
	lib = LIBRARY.instantiate()
	add_child(lib)
	_expect("S_RETURN" in Meta.events and lib.get_node("%NoticeLabel").visible and lib.get_node("%NoticeLabel").text == "우리의 기록에는 서로 다른 목소리가 있었다.", "S_RETURN recorded on the library visit after 침묵")
	lib.free()
	lib = LIBRARY.instantiate()
	add_child(lib)
	_expect(not lib.get_node("%NoticeLabel").visible and Meta.events.count("S_RETURN") == 1, "S_RETURN shown once, recorded once")
	lib.free()
	Meta.codex["C01"] = {"mastery": 0, "best_rank": 1, "first_at": "d"}
	lib = LIBRARY.instantiate()
	add_child(lib)
	lib._set_codex_tab("compound")
	_expect("최초 발견 기록" in lib.get_node("%CodexDetail").text, "compound codex shows a discovery record, no 복원도")
	lib.free()
	Meta.events = ["S_SILENCE"]
	var game := RUN_GAME.instantiate()
	game.set_physics_process(false)
	add_child(game)
	_expect(game.get_node("CorruptedPage/LastSentence/Text").text == "「우리는 □□□ □□□□□.」", "page shows the current sentence stage")
	game.free()
