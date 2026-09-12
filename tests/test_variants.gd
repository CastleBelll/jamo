extends Node
## Headless checks for B2 variants (LIGHT/HEAVY/GUARD), 합성 (G6/B8), the 위험 pool
## snapshot (B5), and the HUD hover line (G10).

const RUN_GAME := preload("res://scenes/run/run_game.tscn")

var failures: Array[String] = []
var db: ContentDB
var game: Node
var run: RunController
var director: CombatDirector


func _ready() -> void:
	# Isolate persistence: never touch the real profile from a test (G14).
	Meta.saver.path = "user://test_variants.json"
	Meta.new_profile()
	RunLog.enabled = false  # tests never leave run logs behind unless they test the logger
	db = ContentDB.load_all()
	if not db.validate().is_empty():
		failures.append("content invalid")
	else:
		_check_variant_rolls()
		_check_variant_stats_and_guard()
		_check_compounds()
		_check_risk_pool()
		_check_hover()
	if game != null:
		game.free()
	for f in failures:
		printerr("FAIL: " + f)
	print("test_variants: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().paused = false
	Meta.saver.delete_all()
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _boot(seed: int = 3) -> void:
	if game != null:
		game.free()
	game = RUN_GAME.instantiate()
	game.run_seed = seed
	game.set_physics_process(false)
	add_child(game)
	run = game.get_node("RunController")
	director = game.get_node("CombatDirector")
	run.begin_combat()


func _wave(count: int, variant_chance: float) -> WaveData:
	var w := WaveData.new()
	w.enemy_count = count
	w.concurrent_max = 8
	w.spawn_interval = 0.001
	w.base_hp = 10.0
	w.travel_time = 14.0
	w.variant_chance = variant_chance
	return w


func _check_variant_rolls() -> void:
	_boot()
	director.start_wave(_wave(8, 0.0), 1)
	for i in 8:
		director.tick(0.001)
	for e in director.enemies:
		_expect(e.variant == JamoMonster.Variant.NORMAL, "0%% chance: every enemy NORMAL")
	# Statistical: 20% chance, 40/40/20 split, over many rolls on the variant stream.
	var counts := {"NORMAL": 0, "LIGHT": 0, "HEAVY": 0, "GUARD": 0}
	director.start_wave(_wave(8, 0.2), 42)
	for i in 20000:
		counts[JamoMonster.Variant.keys()[director._roll_variant()]] += 1
	var variants: int = counts["LIGHT"] + counts["HEAVY"] + counts["GUARD"]
	_expect(variants > 3600 and variants < 4400, "about 20%% variants (got %d)" % variants)
	_expect(absf(counts["LIGHT"] - counts["HEAVY"]) < 400 and counts["GUARD"] * 2 < counts["LIGHT"] + 300 and counts["GUARD"] * 2 > counts["LIGHT"] - 300, "40/40/20 split %s" % [counts])
	# Variant stream is independent of the spawn stream: same jamo sequence regardless of chance.
	director.start_wave(_wave(8, 0.0), 77)
	var jamo_a := []
	for i in 8:
		director.tick(0.001)
	for e in director.enemies:
		jamo_a.append(e.jamo)
	director.start_wave(_wave(8, 1.0), 77)
	var jamo_b := []
	for i in 8:
		director.tick(0.001)
	for e in director.enemies:
		jamo_b.append(e.jamo)
	_expect(jamo_a == jamo_b, "variant rolls do not disturb the spawn jamo stream")
	for e in director.enemies:
		_expect(e.variant != JamoMonster.Variant.NORMAL, "100%% chance: every enemy is a variant")
	# W1-4 have 0%, W6 has 10% (B2 rows).
	_expect(db.waves[4].variant_chance == 0.0 and db.waves[6].variant_chance == 0.1, "B2 variant chances")


func _check_variant_stats_and_guard() -> void:
	_boot()
	director.start_wave(_wave(6, 0.0), 2)
	for i in 6:
		director.tick(0.001)
	var light: JamoMonster = director.enemies[0]
	var heavy: JamoMonster = director.enemies[1]
	light.apply_variant(JamoMonster.Variant.LIGHT, db.balance)
	heavy.apply_variant(JamoMonster.Variant.HEAVY, db.balance)
	_expect(is_equal_approx(light.hp_max, 8.0) and is_equal_approx(light.speed(), light.base_speed * 1.25), "LIGHT: HP x0.8, speed x1.25")
	_expect(is_equal_approx(heavy.hp_max, 16.0) and is_equal_approx(heavy.speed(), heavy.base_speed * 0.8), "HEAVY: HP x1.6, speed x0.8")
	_expect(light.get_node("VisualPivot/VariantMark").text == "▲" and heavy.get_node("VisualPivot/VariantMark").text == "▣", "variant cues visible")
	# GUARD protects the foremost OTHER enemy of its lane, not itself, no stacking.
	var guard: JamoMonster = director.enemies[0]   # L_A
	var protected: JamoMonster = director.enemies[3]  # L_B, same lane 0
	_expect(guard.lane == protected.lane, "test setup: same lane")
	guard.apply_variant(JamoMonster.Variant.GUARD, db.balance)
	protected.progress = 300.0
	guard.progress = 100.0
	_expect(is_equal_approx(director.guard_multiplier(protected), 0.75), "lane front other takes 25%% less")
	_expect(is_equal_approx(director.guard_multiplier(guard), 1.0), "guard itself unprotected")
	var other_lane: JamoMonster = director.enemies[1]
	_expect(is_equal_approx(director.guard_multiplier(other_lane), 1.0), "other lanes unaffected")
	var hp := protected.hp
	director.attack_cooldown = 0.0
	director.pending_target = protected
	director.tick(0.0)
	_expect(is_equal_approx(hp - protected.hp, 0.75), "manual hit reduced to 0.75")
	var second_guard: JamoMonster = director.enemies[3]
	second_guard = director.enemies[0]
	_expect(is_equal_approx(director.guard_multiplier(protected), 0.75), "two guards would not stack")
	guard.alive = false
	director.enemies.erase(guard)
	_expect(is_equal_approx(director.guard_multiplier(protected), 1.0), "protection ends when the guard dies")
	_expect(director.guard_multiplier(director.enemies[0]) == 1.0, "guard multiplier never below 0.75 nor above 1")


func _check_compounds() -> void:
	_boot()
	var build := run.build
	build.add(&"W02")
	build.add(&"W16")
	_expect(build.compound_options(db).is_empty(), "불 R1 + 길 R1: 불길 needs 불 Rank 2")
	build.words[0]["rank"] = 2
	var opts := build.compound_options(db)
	_expect(opts.size() == 1 and opts[0].id == &"C01", "불 R2 + 길 R1 unlocks 불길")
	run.on_wave_cleared()
	run.finish_clear()
	var forge := run.start_forge()
	_expect(not forge.can_compound() and not forge.compound(&"C01"), "no 합성 before the restore step is closed (G6)")
	forge.skip_restore()
	_expect(forge.can_compound() and not forge.can_restore(), "복원 건너뛰기 closes the restore and opens 합성")
	var pv := forge.compound_preview(&"C01")
	_expect(pv["result"].id == &"C01" and pv["material_a_rank"] == 2 and pv["material_b_rank"] == 1, "preview shows lost materials and Ranks")
	_expect(forge.compound(&"C01"), "합성 applies")
	_expect(build.has(&"C01") and build.rank_of(&"C01") == 1 and not build.has(&"W02") and not build.has(&"W16"), "materials leave, 불길 enters at Rank 1")
	_expect(build.words.size() == 1, "two slots became one")
	_expect(not forge.compound(&"C02") and not forge.can_compound(), "one 합성 per 빌드 확정")
	_expect(not forge.restore(&"W01"), "no restore into the freed slot after 합성")
	_expect(forge.candidate_for(&"C01").is_empty(), "compound results are never direct Forge candidates")
	_expect(&"화염" in db.words["C01"].tags and &"방어" in db.words["C01"].tags, "불길 tags: 화염·방어")
	run.finish_forge()
	_expect(&"C01" in run.discovered, "compound result recorded as a discovery")
	# Synergy loss preview: 눈 R2 + 물 + 봄 keeps SY_GUARD (눈물 is 방어); 벽 + 물 + 눈 R2 -> 눈물 keeps 2 방어 too,
	# so check the drop with SY_ECON-free case: 물(방어) + 봄(방어) active, then 눈물 replaces 물 -> still 2 방어.
	var b2 := BuildState.new()
	b2.setup(db.balance)
	b2.add(&"W09")
	b2.words[0]["rank"] = 2
	b2.add(&"W10")
	b2.add(&"W18")
	var f2 := ForgeService.new()
	f2.start(run.deck, db, b2, run.word_pool(), 9, 0)
	f2.skip_restore()
	var pv2 := f2.compound_preview(&"C02")
	_expect(pv2["synergies_lost"].is_empty(), "눈물 keeps the 방어 tag: SY_GUARD stays on")
	_expect(f2.compound(&"C02") and CombatResolver.active_synergies(db, b2).size() == 1, "synergy recount after 합성")
	_expect(not b2.apply_compound(db, &"C02"), "result held: recipe unavailable")
	# Result max Rank 1: never a rank-up candidate.
	_expect(db.words["C02"].max_rank() == 1 and not b2.rank_up(&"C02", db.words["C02"].max_rank()), "compound result cannot rank up")
	# A failed Forge still pays the B3 failure heal/pity even when a 합성 happened.
	var run3 := RunController.new()
	run3.setup(db)
	run3.open_run_setup()
	run3.confirm_setup(&"starter_a")
	run3.build.add(&"W02")
	run3.build.words[0]["rank"] = 2
	run3.build.add(&"W16")
	run3.begin_combat()
	run3.on_wave_cleared()
	run3.finish_clear()
	var f3 := run3.start_forge()
	f3.pool = []
	f3.reroll()
	f3.reroll()
	_expect(f3.is_failed() and f3.can_compound(), "failed Forge: restore closed, 합성 available")
	_expect(f3.compound(&"C01"), "합성 in a failed Forge")
	run3.stability = 50.0
	run3.finish_forge()
	_expect(run3.stability == 58.0 and run3.forge_fail_bonus == 1, "failure heal and pity survive a 합성 (stability %s, bonus %d)" % [run3.stability, run3.forge_fail_bonus])
	_expect(&"C01" in run3.discovered, "compound discovery recorded on a failed Forge too")
	run3.free()
	# A max-Rank material the hand could craft: 합성 frees it, but the failure verdict stays.
	var run4 := RunController.new()
	run4.setup(db)
	run4.open_run_setup()
	run4.confirm_setup(&"starter_a")
	run4.build.add(&"W02")
	run4.build.words[0]["rank"] = 3
	run4.build.add(&"W16")
	run4.begin_combat()
	run4.on_wave_cleared()
	run4.finish_clear()
	var f4 := run4.start_forge()
	f4.pool = [db.words["W02"]]
	f4.hand = [{"id": 900, "jamo": "ㅂ"}, {"id": 901, "jamo": "ㅜ"}, {"id": 902, "jamo": "ㄹ"}]
	f4.draw = run4.deck.tokens.slice(0, 17)
	f4.discard = []
	f4.rerolls_left = 0
	_expect(f4.candidates().is_empty() and f4.is_failed(), "불 at max Rank: no candidate, Forge failed")
	_expect(f4.compound(&"C01"), "합성 불길 frees 불")
	_expect(not f4.candidates().is_empty(), "불 is craftable again after the 합성")
	_expect(f4.is_failed(), "failure verdict latched at the 합성 (B3 settlement stable)")
	run4.stability = 50.0
	run4.finish_forge()
	_expect(run4.stability == 58.0 and run4.forge_fail_bonus == 1, "latched failure still pays +8 and +1 reroll")
	run4.free()


func _check_risk_pool() -> void:
	_boot()
	var ids: Array = []
	for w in run.word_pool():
		ids.append(String(w.id))
	_expect(ids.size() == 19 and "W20" not in ids, "new profile: 19 words, 위험 locked")
	_expect(db.spawn_weights(false).size() == 17, "17 spawn jamo types before the unlock")
	Meta.mieum_purified = false
	run.on_boss_purified(&"B_SILENCE")
	_expect(not Meta.mieum_purified, "other bosses do not unlock 위험 words")
	run.on_boss_purified(&"B_MIEUM")
	_expect(Meta.mieum_purified and not run.risk_unlocked, "ㅁ purified: unlock recorded, current RUN pool unchanged")
	_expect(run.word_pool().size() == 19, "pool snapshot does not widen mid-RUN")
	run.abandon()
	run.retry_run()
	_expect(run.risk_unlocked, "next RUN reads the unlock from Meta")
	ids.clear()
	for w in run.word_pool():
		ids.append(String(w.id))
	_expect(ids.size() == 22 and "W22" in ids, "next RUN after the unlock: 22 words")
	run.begin_combat()
	_expect(director.risk_unlocked and db.spawn_weights(true).size() == 20, "spawn pool widens to 20 types")


func _check_hover() -> void:
	_boot()
	director.start_wave(_wave(2, 0.0), 4)
	director.tick(0.001)
	director.tick(0.001)
	var hud := game.get_node("HUD")
	var e: JamoMonster = director.enemies[0]
	e.apply_variant(JamoMonster.Variant.HEAVY, db.balance)
	hud.set_hover(e)
	_expect(hud.get_node("%HoverLabel").text == "%s  16.0/16.0  HEAVY" % e.jamo, "hover shows jamo, HP and variant (%s)" % hud.get_node("%HoverLabel").text)
	hud.set_hover(null)
	_expect(hud.get_node("%HoverLabel").text == "", "hover clears")
