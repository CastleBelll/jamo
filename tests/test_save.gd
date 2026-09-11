extends Node
## Headless checks for G14 persistence: atomic profile writes with backup recovery, Meta
## round trip, RUN snapshot/resume (Forge hand + RNG), the pre-combat checkpoint, settlement
## dedupe, research max stability, and the library 이어하기 flow.

const RUN_GAME := preload("res://scenes/run/run_game.tscn")
const LIBRARY := preload("res://scenes/hub/last_library.tscn")

var failures: Array[String] = []
var db: ContentDB


func _ready() -> void:
	# Isolate persistence: never touch the real profile from a test (G14).
	Meta.saver.path = "user://test_save.json"
	Meta.new_profile()
	db = ContentDB.load_all()
	if not db.validate().is_empty():
		failures.append("content invalid")
	else:
		_check_save_manager()
		_check_meta_round_trip()
		_check_snapshot_resume()
		_check_checkpoint_and_settlement()
		_check_research_and_library()
		_check_scene_resume()
	for f in failures:
		printerr("FAIL: " + f)
	print("test_save: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().paused = false
	Meta.saver.delete_all()
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _check_save_manager() -> void:
	var s := SaveManager.new()
	s.path = "user://test_save_manager.json"
	s.delete_all()
	_expect(not s.exists() and s.load()["source"] == "none" and not s.load()["corrupt"], "fresh: nothing to load, not corrupt")
	_expect(s.save({"meta": {"gold": 1}, "run": {}}), "first save")
	_expect(FileAccess.file_exists(s.path) and not FileAccess.file_exists(s.temp_path()), "temp file swapped in, none left behind")
	var loaded := s.load()
	_expect(loaded["source"] == "main" and int(loaded["profile"]["meta"]["gold"]) == 1 and int(loaded["profile"]["save_version"]) == SaveManager.SAVE_VERSION, "main file loads with version")
	_expect(s.save({"meta": {"gold": 2}, "run": {}}) and FileAccess.file_exists(s.backup_path()), "second save keeps the previous file as backup")
	_write_raw(s.path, "{ not json")
	loaded = s.load()
	_expect(loaded["source"] == "backup" and loaded["corrupt"] and int(loaded["profile"]["meta"]["gold"]) == 1, "corrupt main -> backup recovered and reported")
	_write_raw(s.backup_path(), "[]")
	loaded = s.load()
	_expect(loaded["source"] == "none" and loaded["corrupt"] and loaded["profile"].is_empty(), "both corrupt -> empty profile, corrupt flag (no silent wipe)")
	_expect(FileAccess.file_exists(s.path), "corrupt files are kept, not deleted")
	s.delete_all()
	_expect(not s.exists(), "delete_all removes main, backup and temp")


func _check_meta_round_trip() -> void:
	Meta.gold = 77
	Meta.research = ["R_SAFE_1"]
	Meta.codex = {"W01": {"mastery": 2, "best_rank": 3, "first_at": "x"}}
	Meta.boss_records = {"B_MIEUM": 1}
	Meta.best_reached = 7
	Meta.best_cleared = 6
	Meta.events = ["S_WORD"]
	Meta.settled_results = ["r1:3"]
	Meta.mieum_purified = true
	Meta.first_run_done = true
	Meta.run = {"wave": 3}
	_expect(Meta.save(), "meta save")
	var d := Meta.to_dict()
	Meta.from_dict({})
	Meta.run = {}
	_expect(Meta.gold == 0 and Meta.codex.is_empty() and not Meta.mieum_purified, "from_dict({}) resets")
	Meta.load_profile()
	_expect(Meta.gold == 77 and Meta.research == ["R_SAFE_1"] and int(Meta.codex["W01"]["mastery"]) == 2 and Meta.best_reached == 7, "meta round trip through disk")
	_expect(Meta.mieum_purified and Meta.first_run_done and Meta.events == ["S_WORD"] and Meta.settled_results == ["r1:3"], "flags and lists round trip")
	_expect(int(Meta.run["wave"]) == 3 and Meta.has_run(), "suspended run round trips")
	_expect(Meta.to_dict().keys() == d.keys(), "to_dict keeps the same keys after a disk round trip")
	Meta.new_profile()
	_expect(Meta.gold == 0 and not Meta.has_run() and Meta.load_source == "none", "new_profile wipes everything")


func _check_snapshot_resume() -> void:
	Meta.new_profile()
	Meta.first_run_done = true
	var run := RunController.new()
	run.run_seed = 31
	run.setup(db)
	run.open_run_setup()
	run.confirm_setup(&"starter_a")
	run.pin_word(&"W02")
	run.build.add(&"W01")
	for i in 2:
		run.begin_combat()
		run.drops.pity_misses = 0
		run.on_purified("ㄱ")
		run.on_wave_cleared()
		run.finish_clear()
		run.finish_forge()
	run.begin_combat()
	run.damage_stability(15.0)
	run.on_purified("ㅁ")
	run.add_gold(5.5)
	run.on_wave_cleared()
	run.finish_clear()
	var forge := run.start_forge()
	forge.toggle_lock(forge.hand[0]["id"])
	forge.reroll()
	var snap := run.snapshot()
	_expect(int(snap["phase"]) == RunController.Phase.FORGE and int(snap["wave"]) == 3, "snapshot taken in W3 FORGE")
	var text := JSON.stringify(snap)
	var back = JSON.parse_string(text)
	var run2 := RunController.new()
	run2.setup(db)
	run2.load_snapshot(back)
	_expect(run2.phase == RunController.Phase.FORGE and run2.wave == 3, "resume lands in the same phase and wave")
	_expect(is_equal_approx(run2.stability, run.stability) and is_equal_approx(run2.gold_run, 5.5) and run2.pinned_word == &"W02", "stability, gold, pin restored")
	_expect(run2.deck.size() == run.deck.size() and run2.deck.jamo_list() == run.deck.jamo_list(), "deck tokens restored")
	_expect(run2.build.has(&"W01") and run2.build.rank_of(&"W01") == 1, "build restored")
	_expect(run2.drops.drops == run.drops.drops, "temp drops restored (%s)" % [run2.drops.drops])
	var f2 := run2.forge
	_expect(f2 != null and f2.hand.size() == forge.hand.size() and f2.locked == forge.locked and f2.rerolls_left == 1, "Forge hand, lock and reroll count restored")
	var ids_a := []
	for t in forge.hand:
		ids_a.append(t["id"])
	var ids_b := []
	for t in f2.hand:
		ids_b.append(t["id"])
	_expect(ids_a == ids_b, "same hand token ids")
	forge.reroll()
	f2.reroll()
	ids_a.clear()
	ids_b.clear()
	for t in forge.hand:
		ids_a.append(t["id"])
	for t in f2.hand:
		ids_b.append(t["id"])
	_expect(ids_a == ids_b, "same RNG: the next reroll is identical after resume")
	_expect(f2.token_total() == run2.deck.size(), "token invariant after resume")
	run.free()
	run2.free()


func _check_checkpoint_and_settlement() -> void:
	Meta.new_profile()
	var game := RUN_GAME.instantiate()
	game.run_seed = 44
	game.set_physics_process(false)
	add_child(game)
	var run: RunController = game.get_node("RunController")
	var director: CombatDirector = game.get_node("CombatDirector")
	_expect(Meta.has_run() and int(Meta.run["phase"]) == RunController.Phase.WAVE_PREP and int(Meta.run["wave"]) == 1, "W1 prep checkpoint saved")
	run.begin_combat()
	director.tick(0.0)
	run.damage_stability(20.0)
	run.add_gold(3.0)
	_expect(int(Meta.run["wave"]) == 1 and float(Meta.run["stability"]) == 100.0 and float(Meta.run["gold_run"]) == 0.0, "no save during combat: checkpoint keeps the pre-combat state")
	# Simulate quitting mid-combat and coming back.
	var saved := Meta.run.duplicate(true)
	game.free()
	Meta.run = saved
	Meta.resume_pending = true
	var game2 := RUN_GAME.instantiate()
	game2.set_physics_process(false)
	add_child(game2)
	var run2: RunController = game2.get_node("RunController")
	_expect(run2.phase == RunController.Phase.WAVE_PREP and run2.wave == 1 and run2.stability == 100.0 and run2.gold_run == 0.0, "resume restarts the Wave from its start (G14)")
	_expect(not Meta.resume_pending, "resume flag consumed")
	# Settlement: pay once, records once.
	run2.begin_combat()
	run2.discovered.append(&"W01")
	run2.build.add(&"W01")
	run2.add_gold(12.7)
	run2.on_boss_purified(&"B_MIEUM")
	run2.damage_stability(200.0)
	_expect(run2.phase == RunController.Phase.RESULT, "run ended")
	_expect(Meta.gold == 12 and Meta.best_reached == 1 and not Meta.has_run(), "settled: integer Gold, best reached, suspended run cleared")
	_expect(int(Meta.codex["W01"]["mastery"]) == 1 and int(Meta.boss_records["B_MIEUM"]) == 1, "codex 복원도 +1 and boss record")
	_expect("S_WORD" in Meta.events and "S_M" in Meta.events and "S_SLICE_END" not in Meta.events, "S5 events recorded")
	var settled := Meta.settled_results.size()
	run2.settle()
	_expect(Meta.gold == 12 and Meta.settled_results.size() == settled, "same result id never pays twice")
	Meta.load_profile()
	_expect(Meta.gold == 12 and int(Meta.codex["W01"]["mastery"]) == 1, "settlement persisted to disk")
	game2.queue_free()


func _check_research_and_library() -> void:
	Meta.new_profile()
	Meta.research = ["R_SAFE_1"]
	_expect(is_equal_approx(Meta.stability_max(db), 105.0), "R_SAFE_1: max stability 105")
	Meta.research = ["R_SAFE_1", "R_SAFE_2"]
	_expect(is_equal_approx(Meta.stability_max(db), 110.0), "R_SAFE_2: 110 (cap)")
	var run := RunController.new()
	run.setup(db)
	run.open_run_setup()
	run.confirm_setup(&"starter_a")
	_expect(run.stability_max == 110.0 and run.stability == 110.0, "new run starts at the researched max")
	run.free()
	_expect(not Meta.deck_unlocked(db.decks["starter_b"]) , "Starter B locked without R_DECK_B")
	Meta.research.append("R_DECK_B")
	_expect(Meta.deck_unlocked(db.decks["starter_b"]), "Starter B unlocked by research")
	Meta.run = {}
	var lib := LIBRARY.instantiate()
	add_child(lib)
	_expect(not lib.get_node("%ContinueButton").visible and lib.get_node("%RunButton").text == "RUN", "no suspended run: plain RUN")
	lib.free()
	Meta.run = {"wave": 4, "phase": RunController.Phase.WAVE_PREP}
	Meta.gold = 40
	lib = LIBRARY.instantiate()
	add_child(lib)
	_expect(lib.get_node("%ContinueButton").visible and lib.get_node("%RunButton").text.begins_with("새 RUN") and lib.get_node("%GoldLabel").text == "Gold 40", "suspended run: 이어하기 shown, Gold from Meta")
	lib.free()
	Meta.corrupt = true
	Meta.load_source = "none"
	lib = LIBRARY.instantiate()
	add_child(lib)
	_expect(lib.get_node("%CorruptLabel").visible and lib.get_node("%NewProfileButton").visible, "corrupt profile: notice and consent button")
	lib.free()
	Meta.corrupt = false


## Resume through the real screens: FORGE keeps the dealt hand, CLEAR keeps consumed picks,
## the seed is re-synced, and 64-bit RNG state survives JSON.
func _check_scene_resume() -> void:
	Meta.new_profile()
	Meta.first_run_done = true
	var game := RUN_GAME.instantiate()
	game.run_seed = 52
	game.set_physics_process(false)
	add_child(game)
	var run: RunController = game.get_node("RunController")
	var director: CombatDirector = game.get_node("CombatDirector")
	run.begin_combat()
	run.drops.pity_misses = 0
	run.on_purified("ㄱ")
	run.on_purified("ㄴ")
	director.clear_enemies()
	run.on_wave_cleared()
	var panel := game.get_node("%ClearPanel")
	panel.get_node("%AddButton").pressed.emit()
	_expect(run.reward.picks_left == 0 and run.reward.candidates.size() == 1 and run.deck.size() == 21, "one pick consumed")
	_expect(not Meta.run.is_empty() and int(Meta.run["phase"]) == RunController.Phase.CLEAR and Meta.run["reward"]["picks_left"] == 0, "pick saved atomically")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Meta.run))
	game.free()
	Meta.run = saved
	Meta.resume_pending = true
	var game2 := RUN_GAME.instantiate()
	game2.set_physics_process(false)
	add_child(game2)
	var run2: RunController = game2.get_node("RunController")
	_expect(run2.phase == RunController.Phase.CLEAR and game2.get_node("%ClearPanel").visible, "resumed into CLEAR with the panel open")
	_expect(run2.reward.picks_left == 0 and run2.reward.candidates.size() == 1 and run2.deck.size() == 21, "consumed pick stays consumed after resume (no refund)")
	_expect(game2.run_seed == 52 and run2.run_seed == 52, "run_game seed re-synced from the snapshot")
	game2.get_node("%ClearPanel").get_node("%FinishButton").pressed.emit()
	_expect(run2.phase == RunController.Phase.FORGE and run2.forge != null, "into FORGE")
	var forge := run2.forge
	forge.toggle_lock(forge.hand[0]["id"])
	game2.get_node("%ForgePanel")._on_reroll()
	var hand_ids := []
	for t in forge.hand:
		hand_ids.append(t["id"])
	var state_before: int = forge.rng.state
	_expect(int(Meta.run["phase"]) == RunController.Phase.FORGE and Meta.run["forge"]["rerolls_left"] == 1, "reroll saved")
	saved = JSON.parse_string(JSON.stringify(Meta.run))
	game2.free()
	Meta.run = saved
	Meta.resume_pending = true
	var game3 := RUN_GAME.instantiate()
	game3.set_physics_process(false)
	add_child(game3)
	var run3: RunController = game3.get_node("RunController")
	var f3 := run3.forge
	_expect(run3.phase == RunController.Phase.FORGE and f3 != null and game3.get_node("%ForgePanel").forge == f3, "the panel reopens the restored Forge, not a new deal")
	var ids3 := []
	for t in f3.hand:
		ids3.append(t["id"])
	_expect(ids3 == hand_ids and f3.locked == forge.locked and f3.rerolls_left == 1 and f3.restores_left == 1, "same hand/lock/reroll after resume")
	_expect(f3.rng.state == state_before, "64-bit RNG state survives the JSON round trip")
	_expect(game3.get_node("%ForgePanel").get_node("%HandRow").get_child_count() == 7, "panel shows the restored hand")
	f3.restore(&"W01") if not f3.candidate_for(&"W01").is_empty() else f3.skip_restore()
	saved = JSON.parse_string(JSON.stringify(run3.snapshot()))
	var run4 := RunController.new()
	run4.setup(db)
	run4.load_snapshot(saved)
	_expect(run4.forge.restores_left == 0 and run4.forge.restored_word == f3.restored_word, "restore state persists (no second restore after resume)")
	run4.free()
	game3.queue_free()
