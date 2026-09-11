extends Node
## Headless checks for W10 침묵 (seal), W15 질주 ㅇ (lane markers), W20 탐욕 (shield/ring)
## per G8/B9, plus the W20 completion (G2).

const RUN_GAME := preload("res://scenes/run/run_game.tscn")

var failures: Array[String] = []
var db: ContentDB
var game: Node
var run: RunController
var director: CombatDirector


func _ready() -> void:
	# Isolate persistence: never touch the real profile from a test (G14).
	Meta.saver.path = "user://test_bosses_late.json"
	Meta.new_profile()
	db = ContentDB.load_all()
	if not db.validate().is_empty():
		failures.append("content invalid")
	else:
		_check_silence()
		_check_silence_rules()
		_check_ieung()
		_check_greed()
	if game != null:
		game.free()
	for f in failures:
		printerr("FAIL: " + f)
	print("test_bosses_late: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().paused = false
	Meta.saver.delete_all()
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## Boots run_game and walks to the COMBAT start of `wave` with the given held words.
func _boot(wave: int, words: Array = [], seed: int = 5) -> void:
	if game != null:
		game.free()
	game = RUN_GAME.instantiate()
	game.run_seed = seed
	game.set_physics_process(false)
	add_child(game)
	run = game.get_node("RunController")
	director = game.get_node("CombatDirector")
	for w in words:
		run.build.add(w[0])
		run.build.words[-1]["rank"] = w[1]
	for i in wave - 1:
		run.begin_combat()
		director.clear_enemies()
		run.on_wave_cleared()
		run.finish_clear()
		run.finish_forge()
	_expect(run.wave == wave, "walked to W%d (at %d)" % [wave, run.wave])
	run.begin_combat()


func _click(pos: Vector2) -> void:
	director.attack_cooldown = 0.0
	director.request_click(pos)
	director.tick(0.0)


func _tick_to(t: float) -> void:
	while director.clock < t:
		director.tick(minf(0.1, t - director.clock + 0.001))


func _live_pattern() -> PatternTarget:
	for p in director.pattern_targets:
		if not p.done:
			return p
	return null


func _check_silence() -> void:
	_boot(10, [[&"W01", 1], [&"W06", 1]])
	_expect(director.boss_data.id == &"B_SILENCE" and director.boss.hp == 220.0 and director.boss.global_position == Vector2(960, 260), "W10 spawns 침묵 HP 220 at the anchor")
	_expect(game.get_node("%PrepHint").text.begins_with("침묵 등장. 봉인선이"), "boss intro uses the data hint")
	_expect(director.remaining() == 1 + 8, "8 minions scheduled")
	_tick_to(6.0)
	var p := _live_pattern()
	_expect(p != null and p.global_position == Vector2(1260, 260) and p.required == 3 and p.seal, "seal pattern at t=6, marker (1260,260)")
	_expect(p.seal_word in [&"W01", &"W06"], "봉인선 targets a held non-risk word (%s)" % p.seal_word)
	_expect("봉인선" in p.get_node("CountLabel").text, "pattern shows the threatened word")
	var st := run.stability
	_tick_to(8.6)
	_expect(director.resolver.is_sealed(p.seal_word) and run.stability == st, "missed pattern seals the word for 4s, no damage")
	var e: JamoMonster = null
	_tick_to(8.7)
	for m in director.enemies:
		if not (m is Boss):
			e = m
	_expect(e != null and e.jamo != "" and e.hp == 5.0, "침묵 minions: B5 draw, W9 HP 5")
	if p.seal_word == &"W01":
		director.attack_cooldown = 0.0
		director.pending_target = director.boss
		var hp := director.boss.hp
		director.tick(0.0)
		_expect(is_equal_approx(hp - director.boss.hp, 1.0), "sealed 검 gives no bonus (dealt %s)" % (hp - director.boss.hp))
	else:
		_expect(director.resolver.effects_with(&"periodic").is_empty(), "sealed 활 stops its periodic hits")
	var slots := game.get_node("HUD").get_node("Root/BuildBar")
	var hud_text: String = slots.get_child(0).get_child(0).text + slots.get_child(1).get_child(0).text
	_expect("봉인 " in hud_text and "초" in hud_text, "HUD marks the sealed word with its remaining time (%s)" % hud_text.replace("\n", " "))
	_tick_to(12.7)
	_expect(not director.resolver.is_sealed(p.seal_word) and director.resolver.sealed_ids().is_empty(), "seal released after 4s")
	if p.seal_word == &"W06":
		var key: String = director.resolver.effects_with(&"periodic")[0]["key"]
		_expect(director.resolver.timers[key] > director.resolver.clock + 1.5, "released 활 restarts from a fresh period")
	_expect(director.boss_data.body_drop.is_empty() and director.boss_data.minion_gold == 1, "침묵 gives no body drop, minions 1G")


func _check_silence_rules() -> void:
	# Two sealable words: the previous target is never chosen twice in a row.
	_boot(10, [[&"W01", 1], [&"W08", 1]])
	_expect(CombatResolver.active_synergies(db, run.build).size() == 1, "검 + 칼: SY_WEAPON on")
	_tick_to(8.6)
	var first: StringName = director.resolver.last_sealed
	_expect(first != &"", "first seal landed")
	_expect(CombatResolver.active_synergies(db, run.build, director.resolver.sealed_ids()).is_empty(), "sealed word drops out of the synergy count")
	_expect(director.resolver.active_synergies(db, run.build).size() == 1 and director.resolver.active_effects().size() == 1, "only the unsealed word contributes effects")
	_tick_to(18.6)
	_expect(director.resolver.last_sealed != first, "second seal picks the other word (연속 동일 대상 금지)")
	# Only a 위험 word held: nothing sealable, the miss deals 10 instead.
	_boot(10, [[&"W20", 1]])
	_expect(director.resolver.sealable_words().is_empty(), "위험 words are never sealed")
	var st := run.stability
	_tick_to(8.6)
	_expect(director.resolver.sealed_ids().is_empty() and is_equal_approx(st - run.stability, 10.0 * 1.2), "no sealable word: 10 damage (x 욕심 taken)")
	_expect(_live_pattern() == null, "pattern consumed")
	# Phase 2: period 10 -> 8.
	_boot(10, [[&"W01", 1]])
	_tick_to(6.5)
	director.boss.take_damage(150.0)
	_expect(director.boss.phase2, "침묵 phase 2")
	_tick_to(16.5)
	_expect(_live_pattern() != null, "second pattern at 16 (period 10 from the first start)")
	_tick_to(24.5)
	_expect(_live_pattern() != null, "third pattern at 24 (period 8 in phase 2)")


func _check_ieung() -> void:
	_boot(15)
	_expect(director.boss_data.id == &"B_IEUNG" and director.boss.global_position == Vector2(1200, 260), "W15 boss sits at (1200,260)")
	_tick_to(5.1)
	var p := _live_pattern()
	_expect(p != null and p.global_position == Vector2(480, 260) and p.get_node("LanePreview").visible, "first marker on the left lane with a preview line")
	_expect(p.required == 3 and is_equal_approx(p.fail_damage, 16.0), "3 inputs, 16 damage on failure")
	var st := run.stability
	_tick_to(7.7)
	_expect(is_equal_approx(st - run.stability, 16.0), "missed rush: 16 damage")
	_tick_to(13.1)
	p = _live_pattern()
	_expect(p != null and p.global_position == Vector2(960, 260), "second marker on the centre lane")
	for i in 3:
		_click(Vector2(960, 260))
	_expect(p.done and p.hits == 3, "three inputs defuse the rush")
	_tick_to(21.1)
	p = _live_pattern()
	_expect(p != null and p.global_position == Vector2(1440, 260), "third marker on the right lane")
	director.boss.take_damage(120.0)
	_tick_to(29.1)
	p = _live_pattern()
	_expect(p != null and p.global_position == Vector2(480, 260) and p.required == 4, "rotation wraps to the left; phase 2 needs 4 inputs")
	var minions := 0
	for m in director.enemies:
		if not (m is Boss):
			minions += 1
			_expect(m.jamo == "ㅇ" and m.hp == 7.0, "질주 minions are ㅇ with W14 HP 7")
	_expect(minions > 0 and director.boss_data.minion_gold == 2, "minions present, 2G each")
	_expect(director.boss_data.body_drop == (["ㅇ", "ㅇ"] as Array[String]), "ㅇ x2 body drop")


func _check_greed() -> void:
	_boot(20, [[&"W02", 1]])
	var b := director.boss
	_expect(b.get_node("ShieldLabel").visible and b.get_node("ShieldBar").visible, "탐욕 shows a shield readout")
	_expect(director.boss_data.id == &"B_GREED" and b.hp == 380.0 and director.remaining() == 1 + 10, "W20 spawns 탐욕 HP 380 with 10 minions scheduled")
	_tick_to(6.1)
	var p := _live_pattern()
	_expect(p != null and p.global_position == Vector2(1260, 260) and p.required == 4 and is_equal_approx(p.duration, 3.0) and p.ring, "ring pattern at t=6: 4 inputs, 3s warning")
	# Shield: +3 per minion purify, absorbed before HP, capped at 24.
	_tick_to(8.2)
	var minion: JamoMonster = null
	for m in director.enemies:
		if not (m is Boss):
			minion = m
	_expect(minion != null and minion.hp == 9.0 and director.boss_data.minion_gold == 2, "탐욕 minions: W19 HP 9, 2G")
	minion.hp = 0.5
	_click(minion.global_position)
	_expect(is_equal_approx(b.shield, 3.0), "minion purify gives the boss +3 shield (got %s)" % b.shield)
	var hp := b.hp
	_click(Vector2(960, 260))
	_expect(is_equal_approx(b.shield, 2.0) and b.hp == hp, "shield absorbs the hit before HP")
	_expect(b.burn_active(director.resolver.clock), "a shield-absorbed manual hit still procs 불 (no hidden resistance)")
	_expect(b.get_node("ShieldLabel").text.begins_with("보호막 2 / 24"), "shield readout updates (%s)" % b.get_node("ShieldLabel").text)
	_expect(is_equal_approx(b.take_damage(5.0), 5.0) and is_equal_approx(b.shield, 0.0) and is_equal_approx(hp - b.hp, 3.0), "absorbed + HP damage counts as dealt")
	b.shield = 0.0
	b.hp = hp
	b.shield = 24.0
	b.add_shield(3.0, director.clock)
	_expect(b.shield == 24.0, "shield cap 24")
	# Ring defused: shield 0 and no gain for 4s; afterwards it accumulates again.
	_tick_to(16.1)
	p = _live_pattern()
	_expect(p != null, "second ring pattern at 16 (period 10)")
	for i in 4:
		_click(Vector2(1260, 260))
	_expect(p.done and b.shield == 0.0, "ring broken: shield cleared")
	b.update_readout(director.clock)
	_expect("고리 끊김" in b.get_node("ShieldLabel").text, "lockout countdown shown (%s)" % b.get_node("ShieldLabel").text)
	b.add_shield(3.0, director.clock)
	_expect(b.shield == 0.0, "no shield gain during the 4s lockout")
	b.add_shield(3.0, director.clock + 4.1)
	_expect(b.shield == 3.0, "shield gain resumes after the lockout")
	b.shield = 0.0
	var pattern_loss: float = run.damage_causes.get(&"pattern", 0.0)
	_tick_to(26.1)
	p = _live_pattern()
	_expect(p != null, "third ring pattern at 26")
	_tick_to(29.2)
	_expect(is_equal_approx(run.damage_causes.get(&"pattern", 0.0) - pattern_loss, 16.0), "missed ring: 16 pattern damage (minion reaches excluded)")
	# Boss purify at W20: 100G, run completed.
	var gold := run.gold_run
	b.hp = 0.5
	_click(Vector2(960, 260))
	_expect(not b.alive and is_equal_approx(run.gold_run - gold, 100.0), "탐욕 body pays 100G")
	_expect(run.phase == RunController.Phase.RESULT and run.end_reason == RunController.EndReason.COMPLETED and run.waves_cleared == 20, "W20 clear ends the RUN as completed")
	_expect(game.get_node("%ResultLabel").text.begins_with("첫 문서 복원 완료."), "completion result line")
	_expect(director.enemies.is_empty() and director.pattern_targets.is_empty(), "everything cleaned up")
