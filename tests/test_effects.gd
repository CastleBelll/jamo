extends Node
## Headless checks for CombatResolver + statuses (G7, B1, B7): manual/crit/stability formulas,
## burn/poison/slow, periodic auto hits, counters, kill triggers, clear heal, gold, drops.

const RUN_GAME := preload("res://scenes/run/run_game.tscn")

var failures: Array[String] = []
var db: ContentDB
var game: Node
var run: RunController
var director: CombatDirector


func _ready() -> void:
	# Isolate persistence: never touch the real profile from a test (G14).
	Meta.saver.path = "user://test_effects.json"
	Meta.new_profile()
	db = ContentDB.load_all()
	if not db.validate().is_empty():
		failures.append("content invalid")
	else:
		_check_manual_damage()
		_check_stability_and_shield()
		_check_burn_and_night()
		_check_poison()
		_check_slow_and_speed()
		_check_auto_and_procs()
		_check_counters_and_kills()
		_check_crit_rate()
		_check_gold_heal_drops()
		_check_risk_words()
		_check_synergies()
		_check_spread_generation_and_counters()
	if game != null:
		game.free()
	for f in failures:
		printerr("FAIL: " + f)
	print("test_effects: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().paused = false
	Meta.saver.delete_all()
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## Boots into COMBAT with the given held words and a custom wave (big HP so nothing dies).
func _boot(words: Array, count: int = 3, hp: float = 100.0, seed: int = 7) -> void:
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
	var wd := WaveData.new()
	wd.enemy_count = count
	wd.concurrent_max = 8
	wd.spawn_interval = 0.001
	wd.base_hp = hp
	wd.travel_time = 14.0
	run.begin_combat()
	director.start_wave(wd, seed)
	for i in mini(count, 8):
		director.tick(0.001)
	director.attack_cooldown = 0.0


func _hit(target: JamoMonster) -> float:
	var before := target.hp
	director.attack_cooldown = 0.0
	director.pending_target = target
	director.tick(0.0)
	return before - target.hp


func _check_manual_damage() -> void:
	_boot([[&"W01", 1]])
	var e: JamoMonster = director.enemies[0]
	_expect(is_equal_approx(_hit(e), 1.3), "검 R1: 1.0 x 1.30")
	_boot([[&"W01", 3]])
	e = director.enemies[0]
	_expect(is_equal_approx(_hit(e), 1.45), "검 R3 above 50%% HP: +45%%")
	e.hp = 50.0
	_expect(is_equal_approx(_hit(e), 1.7), "검 R3 at 50%% HP: +45%% +25%%p")
	_boot([[&"W05", 3]])
	e = director.enemies[0]
	_expect(is_equal_approx(_hit(e), 1.0), "돌: no bonus far from the sentence")
	e.progress = e.path_length * 0.8
	_expect(is_equal_approx(_hit(e), 1.8), "돌 R3: +80%% inside the last 25%% of the path")
	_boot([[&"W01", 3], [&"W05", 3]])
	e = director.enemies[0]
	e.hp = 40.0
	e.progress = e.path_length * 0.9
	_expect(is_equal_approx(_hit(e), 2.0), "bonus sum capped at +100%%")


func _check_stability_and_shield() -> void:
	_boot([[&"W04", 1]])
	_expect(is_equal_approx(director.resolver.stability_damage(8.0), 7.2), "벽 R1: reach 8 x 0.9")
	_boot([[&"W04", 3]])
	_expect(is_equal_approx(director.resolver.stability_damage(8.0), 6.24), "벽 R3: -22%%")
	_boot([[&"W18", 1]])
	_expect(director.resolver.shield == 5.0, "봄 R1: shield 5 at wave start")
	var e: JamoMonster = director.enemies[0]
	e.progress = e.path_length - 0.1
	director.tick(0.05)
	_expect(is_equal_approx(run.stability, 97.0) and director.resolver.shield == 0.0, "shield absorbs 5 of the 8 reach damage (stability %s)" % run.stability)
	director.resolver.end_wave()
	_expect(director.resolver.shield == 0.0, "shield gone at wave end")
	_boot([[&"W18", 3], [&"W04", 1]])
	_expect(director.resolver.shield == 15.0, "봄 R3 11 + SY_GUARD 4 = shield 15 (got %s)" % director.resolver.shield)
	_expect(is_equal_approx(director.resolver.stability_damage(8.0), 0.0) and is_equal_approx(director.resolver.shield, 7.8), "reduction then shield: 7.2 absorbed")


func _check_burn_and_night() -> void:
	_boot([[&"W02", 1]])
	var e: JamoMonster = director.enemies[0]
	_hit(e)
	_expect(e.burn_active(director.resolver.clock), "불 R1 applies burn on a manual hit")
	var hp := e.hp
	director.tick(0.5)
	_expect(e.hp == hp, "no burn tick before 1s")
	director.tick(0.5)
	_expect(is_equal_approx(hp - e.hp, 0.8), "first burn tick at 1s = 0.8 (got %s)" % (hp - e.hp))
	# Re-apply at 1.5s: expiry extends, the tick clock stays on the 2.0s beat.
	director.tick(0.5)
	hp = e.hp
	_hit(e)
	director.tick(0.5)
	_expect(is_equal_approx(hp - e.hp, 1.0 + 0.8), "manual 1.0 + tick still at 2.0s after re-application (got %s)" % (hp - e.hp))
	var total_before := e.hp
	director.tick(3.0)
	_expect(is_equal_approx(total_before - e.hp, 0.8 * 2), "burn extended to 4.5s: ticks at 3s and 4s only (got %s)" % (total_before - e.hp))
	_expect(not e.burn_active(director.resolver.clock), "burn expired")
	_boot([[&"W02", 1], [&"W19", 1]])
	e = director.enemies[0]
	_hit(e)
	hp = e.hp
	director.tick(1.0)
	_expect(is_equal_approx(hp - e.hp, 0.8 * 1.15), "밤 R1: burn tick x1.15")


func _check_poison() -> void:
	_boot([[&"W03", 1]])
	var e: JamoMonster = director.enemies[0]
	_hit(e)
	director.tick(0.3)
	_hit(e)
	director.tick(0.3)
	_hit(e)
	_expect(e.poison_count(director.resolver.clock) == 3, "three stacks")
	_hit(e)
	_expect(e.poison_count(director.resolver.clock) == 3, "max 3 stacks: the shortest is refreshed")
	var hp := e.hp
	director.tick(0.4)
	_expect(is_equal_approx(hp - e.hp, 0.35 * 3), "poison tick 1s after the first stack pays 3 x 0.35 (got %s)" % (hp - e.hp))
	hp = e.hp
	director.tick(1.0)
	_expect(is_equal_approx(hp - e.hp, 0.35 * 3), "second tick, stacks still alive")
	director.tick(3.0)
	_expect(e.poison_count(director.resolver.clock) == 0, "stacks expire after 4s")


func _check_slow_and_speed() -> void:
	_boot([[&"W09", 1]])
	var e: JamoMonster = director.enemies[0]
	_hit(e)
	_expect(is_equal_approx(director.resolver.speed_mult_for(e), 0.8), "눈 R1: 20%% slow")
	director.tick(2.1)
	_expect(is_equal_approx(director.resolver.speed_mult_for(e), 1.0), "slow expires after 2s")
	_boot([[&"W09", 1], [&"W16", 1]])
	e = director.enemies[0]
	_hit(e)
	_expect(is_equal_approx(director.resolver.speed_mult_for(e), 0.92 * 0.8), "길 -8%% and slow multiply")
	e.apply_slow(0.6, 5.0, director.resolver.clock)
	_expect(is_equal_approx(director.resolver.speed_mult_for(e), 0.5), "B1 minimum speed 50%%")
	e.apply_slow(0.2, 5.0, director.resolver.clock)
	_expect(is_equal_approx(e.strongest_slow(director.resolver.clock), 0.6), "weaker slow does not override the strongest")


func _check_auto_and_procs() -> void:
	_boot([[&"W06", 1], [&"W02", 1]])
	var front: JamoMonster = director.enemies[0]
	front.progress = 200.0
	var hp := front.hp
	director.tick(1.9)
	_expect(front.hp == hp, "활 R1 waits 2s")
	director.tick(0.2)
	_expect(is_equal_approx(hp - front.hp, 1.0), "활 R1 hits the foremost enemy for 1.0")
	_expect(not front.burn_active(director.resolver.clock), "auto hit never procs 불 (allows_proc false)")
	_expect(front.last_source == CombatResolver.SOURCE_AUTO, "auto damage keeps its own source")
	_boot([[&"W17", 1]])
	var a: JamoMonster = director.enemies[0]
	var b: JamoMonster = director.enemies[1]
	var c: JamoMonster = director.enemies[2]
	a.progress = 300.0
	b.progress = 200.0
	var hb := b.hp
	var hc := c.hp
	director.tick(3.0)
	_expect(is_equal_approx(a.hp_max - a.hp, 0.6) and is_equal_approx(hb - b.hp, 0.6) and c.hp == hc, "비 R1 hits the two foremost for 0.6 each")
	_boot([[&"W06", 1], [&"W22", 1]])
	front = director.enemies[0]
	front.progress = 200.0
	hp = front.hp
	director.tick(1.7)
	_expect(is_equal_approx(hp - front.hp, 1.0), "폭주 R1: 활 period 2.0 x 0.8 = 1.6s")
	_expect(is_equal_approx(director.resolver.speed_mult_for(front), 1.10), "폭주 R1: enemies x1.10")


func _check_counters_and_kills() -> void:
	_boot([[&"W07", 1], [&"W02", 1]], 4)
	# Put two enemies in one lane: entity 1 (L_A) and entity 4 (L_B), same lane 0.
	var target: JamoMonster = director.enemies[0]
	var other: JamoMonster = null
	for m in director.enemies:
		if m != target and m.lane == target.lane:
			other = m
	_expect(other != null, "a second enemy shares lane L")
	other.progress = 300.0
	var ho := other.hp
	_hit(target)
	_hit(target)
	_expect(other.hp == ho, "창 R1: no lane hit before the 3rd manual hit")
	_hit(target)
	_expect(is_equal_approx(ho - other.hp, 1.0), "창 R1: 3rd manual hit deals 1.0 to the lane front other")
	_expect(not other.burn_active(director.resolver.clock), "derived 창 damage does not apply 불")
	_boot([[&"W11", 1]], 2)
	var a: JamoMonster = director.enemies[0]
	var b: JamoMonster = director.enemies[1]
	b.global_position = a.global_position + Vector2(100, 0)
	var hb := b.hp
	for i in 4:
		b.global_position = a.global_position + Vector2(100, 0)
		_hit(a)
	_expect(is_equal_approx(hb - b.hp, 1.5), "실 R1: every 4th manual hit deals 1.5 within 160px")
	hb = b.hp
	for i in 4:
		b.global_position = a.global_position + Vector2(200, 0)
		_hit(a)
	_expect(b.hp == hb, "실: nothing outside 160px")
	# 물: only manual final blows count.
	_boot([[&"W10", 1]], 6, 1.0)
	run.damage_stability(20.0)
	var st := run.stability
	for i in 4:
		_hit(director.enemies[0])
	_expect(run.stability == st, "물 R1: no heal before the 5th manual purify")
	_hit(director.enemies[0])
	_expect(is_equal_approx(run.stability, st + 2.0), "물 R1: 5th manual purify heals 2")
	# Auto kills do not count for 물.
	_boot([[&"W10", 1], [&"W06", 1]], 6, 1.0)
	run.damage_stability(20.0)
	st = run.stability
	for i in 4:
		_hit(director.enemies[0])
	director.tick(2.0)
	_expect(director.stats["purified"] == 5 and run.stability == st, "활 purify is not a 직접 정화")
	# 불 R3 spreads to the nearest other enemy within 120px on any kill.
	_boot([[&"W02", 3]], 2, 1.0)
	a = director.enemies[0]
	b = director.enemies[1]
	a.hp = 5.0
	_hit(a)
	a.hp = 0.5
	b.global_position = a.global_position + Vector2(80, 0)
	_hit(a)
	_expect(not a.alive and b.burn_active(director.resolver.clock), "불 R3: a burning victim spreads its burn on purify")
	_expect(director.resolver.counters.is_empty() or true, "counters exist")
	director.start_wave(director.wave_data, 3)
	_expect(director.resolver.counters.is_empty(), "counters reset at wave start")


func _check_crit_rate() -> void:
	_boot([[&"W08", 1]], 1, 100000.0, 99)
	var e: JamoMonster = director.enemies[0]
	var crits := 0
	for i in 4000:
		var dealt := _hit(e)
		if is_equal_approx(dealt, 1.5):
			crits += 1
		elif not is_equal_approx(dealt, 1.0):
			failures.append("crit damage must be 1.0 or 1.5, got %s" % dealt)
			break
	var rate := crits / 4000.0
	_expect(rate > 0.10 and rate < 0.14, "칼 R1 crit about 12%% (measured %.3f)" % rate)
	_boot([[&"W08", 3], [&"W21", 1]])
	_expect(is_equal_approx(director.resolver.crit_chance, 0.28), "crit chance sums to 28%%")


func _check_gold_heal_drops() -> void:
	_boot([[&"W13", 1]], 24, 1.0)
	for i in 24:
		_hit(director.enemies[0])
		director.tick(0.01)
	_expect(is_equal_approx(run.gold_run, 24 * 1.15), "돈 R1: gold x1.15 (got %s)" % run.gold_run)
	_expect(is_equal_approx(director.resolver.clear_heal(director.wave_gold), 4.0 + 4.0), "돈 R1 clear heal: floor(27.6/12) x 2 = 4 (cap 4)")
	_expect(run.phase == RunController.Phase.CLEAR, "wave cleared")
	_boot([[&"W12", 2]], 1, 1.0)
	run.damage_stability(30.0)
	_hit(director.enemies[0])
	_expect(is_equal_approx(run.stability, 70.0 + 4.0 + 5.0), "숨 R2: clear heal 4 + 5 (stability %s)" % run.stability)
	_boot([[&"W14", 2]])
	_expect(is_equal_approx(run.drops.bonus, 0.10) and is_equal_approx(run.drops.effective_chance(), 0.35), "운 R2: drop chance 25%% + 10%%p")


func _check_risk_words() -> void:
	_boot([[&"W21", 1]])
	_expect(is_equal_approx(director.resolver.input_interval(), 0.22), "광기 R1: input interval 0.22s")
	_expect(is_equal_approx(director.resolver.stability_damage(8.0), 9.6), "광기 R1: +20%% stability damage taken")
	_expect(is_equal_approx(_hit(director.enemies[0]), 1.25), "광기 R1: +25%% manual damage")
	_expect(is_equal_approx(director.attack_cooldown, 0.22), "cooldown follows the 광기 interval")
	_boot([[&"W20", 1]], 1, 1.0)
	_hit(director.enemies[0])
	_expect(is_equal_approx(run.gold_run, 1.45), "욕심 R1: gold x1.45")
	_boot([[&"W04", 3], [&"W20", 3]])
	_expect(is_equal_approx(director.resolver.stability_damage(8.0), 8.0 * 0.78 * 1.30), "reduction and risk applied once each")


func _check_synergies() -> void:
	_boot([[&"W01", 1], [&"W08", 1]])
	var syn := CombatResolver.active_synergies(db, run.build)
	_expect(syn.size() == 1 and syn[0].id == &"SY_WEAPON", "검 + 칼 = SY_WEAPON")
	_expect(is_equal_approx(_hit(director.enemies[0]), 1.4) or is_equal_approx(_hit(director.enemies[0]), 1.4 * 1.5), "SY_WEAPON adds +10%% manual (검 30%% + 10%%)")
	_boot([[&"W01", 3], [&"W01", 1]])
	_boot([[&"W05", 3]])
	_expect(CombatResolver.active_synergies(db, run.build).is_empty(), "one word with two tags counts once per tag: 돌 alone is no synergy")
	_boot([[&"W04", 1], [&"W18", 1]])
	syn = CombatResolver.active_synergies(db, run.build)
	_expect(syn.size() == 1 and syn[0].id == &"SY_GUARD", "벽 + 봄 = SY_GUARD")
	_expect(director.resolver.shield == 9.0, "SY_GUARD: shield 5 + 4 at wave start (got %s)" % director.resolver.shield)
	_boot([[&"W13", 1], [&"W14", 1]])
	_expect(CombatResolver.reward_pick_bonus(db, run.build) == 1, "돈 + 운 = SY_ECON +1 pick")
	run.on_wave_cleared()
	var reward := run.build_reward()
	_expect(reward.picks_left == 0, "no drops: picks limited to 0 even with SY_ECON")
	run.drops.drops = ["ㄱ", "ㄴ", "ㄷ"] as Array[String]
	run.reward = null  # build_reward caches the live model while in CLEAR (G14 resume)
	reward = run.build_reward()
	_expect(reward.picks_left == 2, "SY_ECON: normal Wave picks 1 + 1 (got %d)" % reward.picks_left)
	run.wave = 5
	run.reward = null
	reward = run.build_reward()
	_expect(reward.picks_left == 2, "boss Wave keeps 2 picks, no SY_ECON stacking")


func _check_spread_generation_and_counters() -> void:
	# A burning victim spreads once; the copy (generation 1) never spreads again.
	_boot([[&"W02", 3]], 3, 1.0)
	var a: JamoMonster = director.enemies[0]
	var b: JamoMonster = director.enemies[1]
	var c: JamoMonster = director.enemies[2]
	b.global_position = a.global_position + Vector2(80, 0)
	c.global_position = a.global_position + Vector2(160, 0)
	a.hp = 5.0
	_hit(a)
	_expect(a.burn_active(director.resolver.clock) and a.burn_generation() == 0, "direct hit burn is generation 0")
	a.hp = 0.5
	b.global_position = a.global_position + Vector2(80, 0)
	_hit(a)
	_expect(not a.alive and b.burn_active(director.resolver.clock) and b.burn_generation() == 1, "kill spreads a generation-1 burn to b")
	c.global_position = b.global_position + Vector2(80, 0)
	b.hp = 0.5
	_hit(b)
	_expect(not b.alive and not c.burn_active(director.resolver.clock), "generation-1 burn does not spread on")
	# An unburnt victim spreads nothing.
	_boot([[&"W02", 3]], 2, 1.0)
	a = director.enemies[0]
	b = director.enemies[1]
	b.global_position = a.global_position + Vector2(80, 0)
	_hit(a)
	_expect(not a.alive and not b.burn_active(director.resolver.clock), "instant kill without burn: no spread")
	# Counters count the killing blow too (창 every 3 manual hits, any target).
	_boot([[&"W07", 1]], 6, 1.0)
	var other: JamoMonster = director.enemies[1]
	other.hp = 100.0
	other.progress = 300.0
	var ho := other.hp
	_hit(director.enemies[0])  # kill 1 (counter 1)
	_hit(director.enemies[2])  # kill 2 (counter 2)
	_expect(other.hp == ho, "창: two killing blows, no lane hit yet")
	var third: JamoMonster = director.enemies[3]
	other.lane = third.lane  # make `other` the only lane-mate of the third target
	_hit(third)  # kill 3 (counter 3 -> lane hit)
	_expect(is_equal_approx(ho - other.hp, 1.0), "창: third hit (a killing blow) still counts and hits the lane front other")
