extends Node
## Headless check of the G2 state machine and the screen skeleton. See tests/README.md.

const RUN_GAME := preload("res://scenes/run/run_game.tscn")
const PAGE := preload("res://scenes/run/corrupted_page.tscn")
## B11: sub paths start at lane x +/- 65, y 370 and meet at (lane x, 850).
const PATH_ENDPOINTS := {
	"L_A": [Vector2(415, 370), Vector2(480, 850)], "L_B": [Vector2(545, 370), Vector2(480, 850)],
	"C_A": [Vector2(895, 370), Vector2(960, 850)], "C_B": [Vector2(1025, 370), Vector2(960, 850)],
	"R_A": [Vector2(1375, 370), Vector2(1440, 850)], "R_B": [Vector2(1505, 370), Vector2(1440, 850)],
}

var failures: Array[String] = []
var phases: Array = []


func _ready() -> void:
	# Isolate persistence: never touch the real profile from a test (G14).
	Meta.saver.path = "user://test_run_controller.json"
	Meta.new_profile()
	RunLog.enabled = false  # tests never leave run logs behind
	var db := ContentDB.load_all()
	var errors := db.validate()
	if not errors.is_empty():
		failures.append("content invalid: %s" % errors[0])
	else:
		_check_happy_path(db)
		_check_double_fire_and_guards(db)
		_check_failure_and_abandon(db)
		_check_w20_completion(db)
		_check_page_layout()
		_check_run_game_scene()
	for f in failures:
		printerr("FAIL: " + f)
	print("test_run_controller: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().paused = false
	Meta.saver.delete_all()
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _make(db: ContentDB) -> RunController:
	var run := RunController.new()
	run.setup(db)
	phases.clear()
	run.phase_changed.connect(func(_from, to): phases.append(to))
	return run


func _check_happy_path(db: ContentDB) -> void:
	var run := _make(db)
	_expect(run.phase == RunController.Phase.LIBRARY, "starts in LIBRARY")
	_expect(run.open_run_setup(), "LIBRARY -> RUN_SETUP")
	_expect(not run.confirm_setup(&"nope"), "unknown deck rejected")
	_expect(run.confirm_setup(&"starter_a"), "RUN_SETUP -> WAVE_PREP")
	_expect(run.wave == 1 and run.stability == 100.0 and run.stability_max == 100.0, "W1 with full stability")
	_expect(run.begin_combat(), "WAVE_PREP -> COMBAT")
	run.damage_stability(10.0)
	_expect(run.stability == 90.0, "stability damage applies in COMBAT")
	_expect(run.on_wave_cleared(), "COMBAT -> CLEAR")
	_expect(run.stability == 94.0, "B1 clear heal +4 (got %s)" % run.stability)
	run.heal_stability(50.0)
	_expect(run.stability == 100.0, "heal clamps at max")
	_expect(run.finish_clear(), "CLEAR -> FORGE")
	_expect(run.confirm_build(), "FORGE -> WAVE_PREP")
	_expect(run.wave == 2, "wave advanced to 2")
	var expected := [RunController.Phase.RUN_SETUP, RunController.Phase.WAVE_PREP, RunController.Phase.COMBAT,
		RunController.Phase.CLEAR, RunController.Phase.FORGE, RunController.Phase.WAVE_PREP]
	_expect(phases == expected, "phase order %s" % [phases])
	run.free()


func _check_double_fire_and_guards(db: ContentDB) -> void:
	var run := _make(db)
	run.open_run_setup()
	run.confirm_setup(&"starter_a")
	_expect(not run.on_wave_cleared(), "clear ignored before combat")
	_expect(not run.finish_clear(), "finish_clear ignored in WAVE_PREP")
	_expect(not run.confirm_build(), "confirm_build ignored in WAVE_PREP")
	_expect(not run.return_to_library(), "return ignored outside RESULT")
	run.begin_combat()
	_expect(not run.begin_combat(), "second begin_combat ignored")
	run.on_wave_cleared()
	_expect(not run.on_wave_cleared(), "second clear ignored (single transition per button)")
	run.finish_clear()
	_expect(not run.finish_clear(), "second finish_clear ignored")
	run.confirm_build()
	_expect(not run.confirm_build(), "second confirm_build ignored")
	_expect(run.wave == 2, "double confirm did not skip a wave")
	run.damage_stability(999.0)
	_expect(run.stability == 100.0, "stability damage ignored outside COMBAT")
	run.free()


func _check_failure_and_abandon(db: ContentDB) -> void:
	var run := _make(db)
	_expect(not run.abandon(), "abandon ignored in LIBRARY")
	run.open_run_setup()
	run.confirm_setup(&"starter_b")
	run.begin_combat()
	var ended: Array = []
	run.run_ended.connect(func(reason): ended.append(reason))
	run.damage_stability(100.0)
	_expect(run.phase == RunController.Phase.RESULT and run.end_reason == RunController.EndReason.FAILED, "depletion -> RESULT failed")
	_expect(ended == [RunController.EndReason.FAILED], "run_ended fired once")
	_expect(not run.abandon(), "abandon ignored in RESULT")
	_expect(run.return_to_library(), "RESULT -> LIBRARY")
	run.open_run_setup()
	run.confirm_setup(&"starter_a")
	_expect(run.stability == 100.0 and run.wave == 1 and run.end_reason == RunController.EndReason.NONE, "new run resets state")
	run.begin_combat()
	run.on_wave_cleared()
	_expect(run.abandon(), "abandon allowed in CLEAR")
	_expect(run.end_reason == RunController.EndReason.ABANDONED, "abandon reason")
	run.free()


func _check_w20_completion(db: ContentDB) -> void:
	var run := _make(db)
	run.open_run_setup()
	run.confirm_setup(&"starter_a")
	for i in range(19):
		run.begin_combat()
		run.on_wave_cleared()
		run.finish_clear()
		run.confirm_build()
	_expect(run.wave == 20 and run.is_boss_wave(), "reached W20 boss prep (wave %d)" % run.wave)
	run.begin_combat()
	run.damage_stability(30.0)
	var before := run.stability
	_expect(run.on_wave_cleared(), "W20 clear accepted")
	_expect(run.phase == RunController.Phase.RESULT and run.end_reason == RunController.EndReason.COMPLETED, "W20 clear -> RESULT completed, no Forge")
	_expect(run.stability == before, "no clear heal after W20")
	_expect(not run.finish_clear() and not run.confirm_build(), "no CLEAR/FORGE after W20")
	run.free()


func _check_page_layout() -> void:
	var page := PAGE.instantiate()
	for child_name in ["Paper", "Overlays", "Paths", "Enemies", "BossAnchor", "LastSentence", "Effects"]:
		_expect(page.has_node(child_name), "corrupted_page has %s" % child_name)
	var paths := page.get_node("Paths")
	_expect(paths.get_child_count() == 6, "6 Path2D lanes")
	for name in PATH_ENDPOINTS:
		var p := paths.get_node_or_null(name) as Path2D
		if p == null or p.curve == null or p.curve.point_count != 2:
			failures.append("path %s missing or not 2 points" % name)
			continue
		_expect(p.curve.get_point_position(0) == PATH_ENDPOINTS[name][0], "%s start %s" % [name, p.curve.get_point_position(0)])
		_expect(p.curve.get_point_position(1) == PATH_ENDPOINTS[name][1], "%s end %s" % [name, p.curve.get_point_position(1)])
	_expect(page.get_node("BossAnchor").position == Vector2(960, 260), "BossAnchor at B11 boss center")
	var sentence_y: float = page.get_node("LastSentence").position.y
	_expect(sentence_y >= 880.0 and sentence_y <= 940.0, "LastSentence inside B11 y range")
	page.free()


func _check_run_game_scene() -> void:
	var game := RUN_GAME.instantiate()
	add_child(game)
	var run: RunController = game.get_node("RunController")
	_expect(run.phase == RunController.Phase.WAVE_PREP and run.wave == 1, "run_game boots into W1 prep")
	_expect(get_tree().paused, "combat clock paused outside COMBAT")
	var hud := game.get_node("HUD")
	_expect(hud.get_node("%WaveLabel").text == "W1", "HUD wave label")
	_expect(hud.get_node("%StabilityLabel").text.begins_with("안정도 100/"), "HUD stability label")
	_expect(game.get_node("%PrepPanel").visible and not game.get_node("%ResultPanel").visible, "prep panel shown")
	game.get_node("%StartWaveButton").pressed.emit()
	_expect(run.phase == RunController.Phase.COMBAT and not get_tree().paused, "start button -> COMBAT unpaused")
	run.damage_stability(8.0)
	_expect(hud.get_node("%StabilityLabel").text.begins_with("안정도 92/"), "HUD follows stability")
	run.on_wave_cleared()
	_expect(game.get_node("%ClearPanel").visible and get_tree().paused, "clear panel shown and paused")
	game.get_node("%ClearPanel").get_node("%FinishButton").pressed.emit()
	game.get_node("%ForgePanel").get_node("%FinishButton").pressed.emit()
	_expect(hud.get_node("%WaveLabel").text == "W2", "HUD wave 2 after build confirm")
	game.get_node("%StartWaveButton").pressed.emit()
	run.damage_stability(200.0)
	_expect(game.get_node("%ResultPanel").visible, "result panel on failure")
	_expect(game.get_node("%ResultLabel").text.begins_with("이번 페이지의 연결이 끊어졌다."), "S3 failure line")
	game.queue_free()
