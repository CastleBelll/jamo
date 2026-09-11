extends Node
## Headless checks for the W5 boss loop (G8, B9), the result screen and 재도전 (G9/G2),
## and the 복 remove budget (B7).

const RUN_GAME := preload("res://scenes/run/run_game.tscn")

var failures: Array[String] = []
var db: ContentDB
var game: Node
var run: RunController
var director: CombatDirector


func _ready() -> void:
	db = ContentDB.load_all()
	if not db.validate().is_empty():
		failures.append("content invalid")
	else:
		_check_boss_wave_setup()
		_check_patterns()
		_check_minions_and_phase2()
		_check_boss_purify_and_reward()
		_check_result_and_retry()
		_check_bok_removes()
	if game != null:
		game.free()
	for f in failures:
		printerr("FAIL: " + f)
	print("test_boss: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().paused = false
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## Boots run_game and walks the RUN to the W5 COMBAT start with manual ticking.
func _boot_w5(seed: int = 5) -> void:
	if game != null:
		game.free()
	game = RUN_GAME.instantiate()
	game.run_seed = seed
	game.set_physics_process(false)
	add_child(game)
	run = game.get_node("RunController")
	director = game.get_node("CombatDirector")
	for i in 4:
		run.begin_combat()
		director.clear_enemies()
		run.on_wave_cleared()
		run.finish_clear()
		run.finish_forge()
	_expect(run.wave == 5 and run.is_boss_wave(), "walked to W5 prep")
	run.begin_combat()


func _click(pos: Vector2) -> void:
	director.attack_cooldown = 0.0
	director.request_click(pos)
	director.tick(0.0)


## Ticks in 0.1s steps until the wave clock has passed `t` (tiny overshoot on purpose).
func _tick_to(t: float) -> void:
	while director.clock < t:
		director.tick(minf(0.1, t - director.clock + 0.001))


func _check_boss_wave_setup() -> void:
	_boot_w5()
	_expect(director.boss != null and director.boss.alive and director.boss_data.id == &"B_MIEUM", "W5 spawns 거대한 ㅁ")
	_expect(director.boss.global_position == Vector2(960, 260), "boss at the B11 anchor")
	_expect(director.boss.hp == 90.0 and director.enemies.size() == 1, "boss HP 90, alone at start")
	_expect(director.remaining() == 3, "remaining = boss + 2 scheduled minions")
	_expect(game.get_node("HUD").get_node("%EnemiesLabel").text == "남은 적 3", "HUD counts the boss wave")
	_expect(game.get_node("%PrepHint").text.begins_with("거대한 ㅁ 등장"), "boss intro line before combat")
	var b := director.boss
	_expect(director.pick_target(Vector2(1130, 260)) == b, "capsule end (170px) hits")
	_expect(director.pick_target(Vector2(1160, 260)) == null, "beyond the capsule misses")
	_expect(director.pick_target(Vector2(960, 305)) == b and director.pick_target(Vector2(960, 320)) == null, "capsule radius 50 vertically")
	var hp := b.hp
	_click(Vector2(960, 260))
	_expect(is_equal_approx(hp - b.hp, 1.0), "boss takes manual damage")
	_expect(director.pattern_targets.is_empty(), "no pattern before t=5")
	# 돌 never applies to the boss (G7), and the boss never blocks a spawn slot.
	run.build.add(&"W05")
	run.build.words[-1]["rank"] = 3
	director.resolver.refresh()
	hp = b.hp
	_click(Vector2(960, 260))
	_expect(is_equal_approx(hp - b.hp, 1.0), "돌 R3 gives no bonus against the boss (dealt %s)" % (hp - b.hp))
	run.build.remove(&"W05")
	director.resolver.refresh()
	director.lane_rotation = 1
	director.sub_rotation = 0
	_expect(director._pick_slot() == 2, "lane C sub A is free even though the boss reports lane 1 / sub 0")


func _check_patterns() -> void:
	_boot_w5()
	_tick_to(5.0)
	_expect(director.pattern_targets.size() == 1, "pattern target appears at t=5")
	var p: PatternTarget = director.pattern_targets[0]
	_expect(p.global_position == Vector2(660, 260) and p.required == 3 and is_equal_approx(p.duration, 2.5), "B9 marker (660,260), 3 inputs, 2.5s warning")
	var hp := director.boss.hp
	_click(Vector2(660, 260))
	_expect(p.hits == 1 and director.boss.hp == hp, "click on the marker counts an input, not boss damage")
	director.request_click(Vector2(660, 260))
	director.tick(0.05)
	_expect(p.hits == 1, "marker inputs share the 0.25s cooldown")
	director.boss.take_damage(5.0)
	_expect(p.hits == 1, "boss damage never changes the count")
	_click(Vector2(660, 260))
	_expect(director.cycle_focus() == p, "Tab focuses the live 대응물 first")
	director.attack_cooldown = 0.0
	director.request_keyboard_attack()
	director.tick(0.0)
	_expect(p.done and p.hits == 3 and director.stats["patterns_defused"] == 1, "third input (Space) defuses the pattern")
	var st := run.stability
	_tick_to(8.0)
	_expect(run.stability == st and director.pattern_targets.is_empty(), "defused pattern deals no damage and is removed")
	_tick_to(13.0)
	_expect(director.pattern_targets.size() == 1, "second pattern at t=13 (period 8)")
	_tick_to(15.6)
	_expect(is_equal_approx(run.stability, st - 12.0), "missed pattern: 12 stability damage (stability %s)" % run.stability)
	_expect(run.damage_causes.get(&"pattern", 0.0) == 12.0 and director.stats["patterns_failed"] == 1, "pattern damage recorded by cause")


func _check_minions_and_phase2() -> void:
	_boot_w5()
	_tick_to(7.9)
	_expect(director.minion_count() == 0, "no minion before t=8")
	_tick_to(8.1)
	_expect(director.minion_count() == 1, "first minion at t=8")
	var m: JamoMonster = null
	for e in director.enemies:
		if not (e is Boss):
			m = e
	_expect(m != null and m.jamo == "ㅁ" and m.hp == 3.0, "minion is ㅁ with W4 HP 3")
	_expect(is_equal_approx(m.base_speed, m.path_length / 13.0), "minion travel time 13s")
	_expect(director.remaining() == 3, "remaining unchanged: boss + minion + 1 pending")
	_tick_to(16.1)
	_expect(director.minion_count() == 2 and director.pending_minions.is_empty(), "second minion at t=16, schedule done")
	var gold := run.gold_run
	m.hp = 0.5
	_click(m.global_position)
	_expect(is_equal_approx(run.gold_run - gold, 1.0), "minion pays 1G")
	# Phase 2: below 50% HP the NEXT pattern uses the 2.0s warning.
	_tick_to(21.5)
	_expect(director.pattern_targets.size() == 1 and is_equal_approx(director.pattern_targets[0].duration, 2.5), "pattern 3 still phase 1")
	director.boss.take_damage(50.0)
	_expect(director.boss.phase2, "boss enters phase 2 at 50%%")
	_tick_to(29.5)
	_expect(director.pattern_targets.size() == 1 and is_equal_approx(director.pattern_targets[0].duration, 2.0), "phase 2 pattern warns 2.0s")


func _check_boss_purify_and_reward() -> void:
	_boot_w5()
	_tick_to(13.5)
	_expect(director.minion_count() == 1 and director.pattern_targets.size() == 1, "minion and second pattern live at t=13.5")
	var gold := run.gold_run
	director.boss.hp = 0.5
	_click(Vector2(960, 260))
	_expect(not director.boss.alive, "boss purified")
	_expect(is_equal_approx(run.gold_run - gold, 30.0), "boss body pays 30G")
	_expect(director.enemies.is_empty() and director.pending_minions.is_empty() and director.pattern_targets.is_empty(), "minions, schedule and 대응물 removed on boss purify")
	_expect(run.drops.drops == (["ㅁ", "ㅁ"] as Array[String]), "guaranteed ㅁ x2 body drop (drops %s)" % [run.drops.drops])
	_expect(run.phase == RunController.Phase.CLEAR, "boss wave clears immediately")
	var reward := run.build_reward()
	_expect(reward.picks_left == 2 and reward.removes_left == 1, "boss reward: 2 picks + 1 remove")
	_expect(director.stats["purified"] == 1, "removed minions are not counted as purified")


func _check_result_and_retry() -> void:
	_boot_w5()
	run.pin_word(&"W08")
	run.build.add(&"W01")
	run.discovered.append(&"W01")
	run.add_gold(12.7)
	run.damage_stability(30.0, &"pattern")
	run.damage_stability(100.0, &"reach")
	_expect(run.phase == RunController.Phase.RESULT and run.end_reason == RunController.EndReason.FAILED, "run failed")
	var text: String = game.get_node("%ResultLabel").text
	_expect(text.begins_with("이번 페이지의 연결이 끊어졌다."), "S3 failure line first")
	_expect("도달 Wave 5 · 클리어 Wave 4" in text, "reached vs cleared wave (%s)" % text)
	_expect("적 도달 70.0, 보스 패턴 30.0" in text, "top loss causes ordered (%s)" % text)
	_expect("대표 빌드: 검 R1" in text and "신규 복원: 검" in text and "획득 Gold: 12 G" in text, "build, discoveries, integer gold")
	_expect("다음 목표: 칼에 부족한 자모 ㅋ 회수" in text, "one next goal from the pin (%s)" % text)
	_expect(not run.first_run, "first run over after the result")
	game.get_node("%RetryButton").pressed.emit()
	_expect(run.phase == RunController.Phase.WAVE_PREP and run.wave == 1 and run.stability == 100.0, "재도전 restarts at W1")
	_expect(game.get_node("%PrepHint").text == "", "retry shows no W1 guidance line (G2)")
	_expect(run.pinned_word == &"W08" and run.deck.size() == 20 and run.build.words.is_empty(), "pin kept, deck and build reset")
	run.on_wave_cleared()
	run.begin_combat()
	director.clear_enemies()
	run.on_wave_cleared()
	_expect(run.build_reward().allow_replace, "retry W1 allows 교체 (no tutorial rule)")
	run.finish_clear()
	var f := run.start_forge()
	var jamo := []
	for t in f.hand:
		jamo.append(t["jamo"])
	jamo.sort()
	var tut := ["ㄱ", "ㅓ", "ㅁ", "ㅂ", "ㅜ", "ㄹ", "ㅣ"]
	tut.sort()
	_expect(jamo != tut or f.rng.seed != 0, "retry does not force the tutorial hand")
	run.finish_forge()


func _check_bok_removes() -> void:
	var b := BuildState.new()
	b.setup(db.balance)
	b.add(&"W15")
	_expect(CombatResolver.extra_removes(db, b, 4) == 1 and CombatResolver.extra_removes(db, b, 3) == 0, "복 R1: remove on multiples of 4")
	b.words[0]["rank"] = 3
	_expect(CombatResolver.extra_removes(db, b, 6) == 1 and CombatResolver.extra_removes(db, b, 7) == 0, "복 R3: multiples of 2")
	var run2 := RunController.new()
	run2.setup(db)
	run2.open_run_setup()
	run2.confirm_setup(&"starter_a")
	run2.build.add(&"W15")
	run2.wave = 4
	run2.begin_combat()
	run2.on_wave_cleared()
	_expect(run2.build_reward().removes_left == 1, "W4 normal reward gets the 복 remove")
	run2.finish_clear()
	run2.finish_forge()
	run2.begin_combat()
	run2.on_wave_cleared()
	_expect(run2.build_reward().removes_left == 1, "W5 boss reward keeps its own single remove (no stacking)")
	run2.free()
