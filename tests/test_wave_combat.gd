extends Node

## Headless checks for the doc v0.4 Phase 1 wave rules, walked in the real
## main.tscn with the real spawner, monsters and 문장핵.
## Run: godot --headless --path . res://tests/test_wave_combat.tscn
##
##   1. Wave data comes from WaveData resources, Wave 1~5 are authored.
##   2. A monster that reaches the 문장핵 damages it.
##   3. Energy 0 does not end the wave, and a damage-over-time kill at energy
##      0 still pays gold into MetaState. Doc v0.4 section 7.1.
##   4. Wave Clear refills energy and advances RunState.current_wave.
##   4b. A suspended run remembers how much of the wave was resolved, and the
##      spawner skips that many on resume. Doc v0.4 section 44.
##   5. The 문장핵 reaching 0 HP is the only failure, and the gold the run
##      earned stays in MetaState. Doc v0.4 sections 14 and 35.

const RUN_SCENE := "res://scenes/main/main.tscn"
## Frames to wait for a simulated event before declaring the flow stuck.
const WAIT_FRAME_BUDGET := 4000
## The walk to the core takes seconds of game time; the clock is sped up so
## the whole file finishes in a reasonable wall time.
const TIME_SCALE := 4.0
## Wave 1 through Wave 5 have to be authored. Doc v0.4 section 48 Phase 1.
const AUTHORED_WAVES := 5

var _failures: int = 0
var _cleared_waves: Array[int] = []
var _failed_args: Array = []


func _ready() -> void:
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	Engine.time_scale = TIME_SCALE
	SignalBus.wave_cleared.connect(func(wave: int) -> void: _cleared_waves.append(wave))
	SignalBus.run_failed.connect(
		func(wave: int, kills: int, gold: float, is_record: bool) -> void:
			_failed_args = [wave, kills, gold, is_record]
	)

	await _run()

	Engine.time_scale = 1.0
	SaveManager.delete_save()
	if _failures == 0:
		print("OK - waves run on data, energy 0 ends nothing, the core is the only failure.")
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("  FAIL: %s" % message)


func _run() -> void:
	_test_wave_data()

	var main: Node = await _enter(RUN_SCENE)
	if main == null:
		return
	var spawner: SpawnManager = main.get_node("World/GameWorld/SpawnManager")
	var core: SentenceCore = main.get_node("World/GameWorld/SentenceCore")
	var hud: Control = main.get_node("UI/HUD")
	var result: Control = main.get_node("UI/RunResult")
	_check(core != null, "main.tscn carries a SentenceCore (doc v0.4 section 6.1)")
	_check(RunState.is_active and RunState.current_wave == 1, "opening the run scene starts Wave 1")
	_check(spawner.is_spawning(), "the WaveController handed Wave 1 to the spawner")
	_check(
		RunState.current_energy == 10 and RunState.get_max_energy() == 10,
		"a wave starts with Max Energy 10 (doc v0.4 section 7.1), got %d / %d"
			% [RunState.current_energy, RunState.get_max_energy()]
	)
	_check(
		hud.get_node("%EnergyLabel").text == "ENERGY 10 / 10",
		"the HUD reads ENERGY 10 / 10, got %s" % hud.get_node("%EnergyLabel").text
	)

	await _test_monster_reaches_core()
	if not RunState.is_active:
		return
	await _test_energy_zero_keeps_wave_and_dot_pays(spawner)
	if not RunState.is_active:
		return
	await _test_wave_clear_refills_energy(hud)
	if not RunState.is_active:
		return
	await _test_resume_spawns_only_the_rest(spawner)
	if not RunState.is_active:
		return
	await _test_core_is_the_only_failure(core, result)


# --- 1. wave data -----------------------------------------------------------

func _test_wave_data() -> void:
	print("-- wave data")
	var database: GameDatabase = MetaState.database
	_check(database.waves.size() >= AUTHORED_WAVES,
		"Wave 1~%d are authored in GameDatabase.waves, found %d"
			% [AUTHORED_WAVES, database.waves.size()])
	for n in range(1, AUTHORED_WAVES + 1):
		var wave: WaveData = database.find_wave(n)
		_check(wave != null and wave.wave_number == n, "find_wave(%d) returns Wave %d" % [n, n])
		if wave == null:
			continue
		_check(not wave.enemy_pool.is_empty(), "Wave %d has an enemy pool" % n)
		_check(wave.enemy_count > 0 and wave.max_alive > 0, "Wave %d spawns something" % n)
		_check(wave.wave_type == WaveData.WaveType.NORMAL, "Wave %d is NORMAL in Phase 1" % n)
	# Not one number of the Day curve: two consecutive waves differ on more
	# than HP alone. Doc v0.4 section 5.2.
	var w1: WaveData = database.find_wave(1)
	var w5: WaveData = database.find_wave(AUTHORED_WAVES)
	if w1 != null and w5 != null:
		_check(w5.enemy_count > w1.enemy_count, "later waves send more enemies")
		_check(w5.spawn_interval < w1.spawn_interval, "later waves spawn faster")
		_check(w5.max_alive > w1.max_alive, "later waves put more on the field at once")
		_check(w5.speed_multiplier > w1.speed_multiplier, "later waves move faster")
		_check(w5.special_spawn_rate > w1.special_spawn_rate, "later waves roll more specials")
	_check(database.find_wave(AUTHORED_WAVES + 40) == w5,
		"a wave past the authored ones replays the last authored wave")


# --- 2. approach ------------------------------------------------------------

func _test_monster_reaches_core() -> void:
	print("-- a monster walks to the 문장핵")
	var hp_before: float = RunState.core_hp
	var waited := 0
	while RunState.core_hp >= hp_before and waited < WAIT_FRAME_BUDGET:
		await get_tree().process_frame
		waited += 1
	_check(RunState.core_hp < hp_before,
		"a monster reached the core and damaged it (core %.0f -> %.0f after %d frames)"
			% [hp_before, RunState.core_hp, waited])
	_check(RunState.is_active, "one hit does not end the run")
	print("    core %.0f -> %.0f after %d frames" % [hp_before, RunState.core_hp, waited])


# --- 3. energy 0 ------------------------------------------------------------

func _test_energy_zero_keeps_wave_and_dot_pays(spawner: SpawnManager) -> void:
	print("-- energy 0 keeps the wave going, DoT still pays")
	while RunState.spend_click_energy():
		pass
	_check(RunState.current_energy == 0, "the energy was spent to 0")
	_check(not RunState.can_click(), "manual clicks are refused at energy 0")
	_check(RunState.is_active, "energy 0 must not end the run (doc v0.4 section 7.1)")
	_check(spawner.is_spawning(), "the spawner keeps the wave going at energy 0")

	var burn: WordEffectData = _burn_effect()
	_check(burn != null, "the word 불 still carries the burn effect")
	if burn == null:
		return
	# The monster furthest from the core, so the tick lands before it can reach
	# the core and leave unpaid.
	var monster: JamoMonster = await _await_alive_monster(spawner.objective)
	if monster == null:
		_check(false, "no monster spawned to burn")
		return
	var gold_before: float = MetaState.gold
	var kills_before: float = RunState.get_run_statistic("kills")
	var earned_before: float = RunState.get_run_statistic("gold_earned")
	# Waiting for a monster may have crossed a Wave Clear, which refills the
	# energy, so it is spent again here: the claim under test is "at energy 0".
	while RunState.spend_click_energy():
		pass
	_check(RunState.current_energy == 0, "the energy is 0 at the moment the burn lands")
	var wave_at_burn: int = RunState.current_wave
	# Burn ticks 1 per second and Wave 1~2 monsters have 1 HP, so the first
	# tick kills. Nothing is clicked: energy stays at 0 throughout.
	monster.apply_status_effect(burn)
	var waited := 0
	while is_instance_valid(monster) and monster.is_alive() and waited < WAIT_FRAME_BUDGET:
		await get_tree().process_frame
		waited += 1
	_check(not is_instance_valid(monster) or not monster.is_alive(),
		"the burn tick killed the monster with no click")
	_check(RunState.current_wave == wave_at_burn,
		"the DoT kill was measured inside one wave (%d -> %d)"
			% [wave_at_burn, RunState.current_wave])
	_check(RunState.current_energy == 0,
		"the energy is still 0 after the DoT kill, got %d" % RunState.current_energy)
	_check(MetaState.gold > gold_before,
		"the DoT kill at energy 0 paid gold into MetaState (%.2f -> %.2f)"
			% [gold_before, MetaState.gold])
	_check(RunState.get_run_statistic("kills") == kills_before + 1.0,
		"the DoT kill counted as a kill")
	_check(RunState.get_run_statistic("gold_earned") > earned_before,
		"the DoT kill counted toward the run's gold_earned")
	_check(RunState.is_active, "the run is still going after the DoT kill")
	print("    DoT kill: gold %.2f -> %.2f, kills %d" % [
		gold_before, MetaState.gold, int(RunState.get_run_statistic("kills")),
	])


func _burn_effect() -> WordEffectData:
	var word: WordData = MetaState.database.find_word(&"fire_001")
	if word == null:
		return null
	for effect: WordEffectData in word.base_effects:
		if effect != null and effect.effect_type == WordEffectData.EffectType.UNLOCK_BURN:
			return effect
	return null


# --- 4. wave clear ----------------------------------------------------------

func _test_wave_clear_refills_energy(hud: Control) -> void:
	print("-- wave clear refills the energy")
	var wave_before: int = RunState.current_wave
	# Everything that spawns is killed outright, without spending energy, so
	# the clear comes from the field emptying and not from the core absorbing
	# the wave.
	var waited := 0
	while RunState.current_wave == wave_before and waited < WAIT_FRAME_BUDGET:
		for node: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
			var monster := node as JamoMonster
			if monster != null and monster.is_alive():
				monster.take_click_damage(monster.max_hp)
		await get_tree().process_frame
		waited += 1
	_check(_cleared_waves.has(wave_before), "wave_cleared was emitted for Wave %d" % wave_before)
	_check(RunState.current_wave == wave_before + 1,
		"the run moved on to Wave %d, got %d" % [wave_before + 1, RunState.current_wave])
	_check(RunState.current_energy == RunState.get_max_energy(),
		"Wave Clear refilled the energy to max (doc v0.4 section 7.1), got %d / %d"
			% [RunState.current_energy, RunState.get_max_energy()])
	_check(hud.get_node("%WaveLabel").text == "WAVE %d" % (wave_before + 1),
		"the HUD reads the new wave, got %s" % hud.get_node("%WaveLabel").text)
	_check(SaveManager.has_run_save()
		and int(SaveManager.peek_run().get("current_wave", 0)) == wave_before + 1,
		"Wave Clear wrote the run out (doc v0.4 section 45)")
	print("    Wave %d -> %d after %d frames, energy %d / %d" % [
		wave_before, RunState.current_wave, waited,
		RunState.current_energy, RunState.get_max_energy(),
	])


# --- 4b. resume ---------------------------------------------------------------

## RUN 이어하기 brings back only the enemies the wave still owed: the count of
## resolved enemies rides along in the save and the spawner skips that many.
## Doc v0.4 section 44.
func _test_resume_spawns_only_the_rest(spawner: SpawnManager) -> void:
	print("-- a resumed wave spawns only what is left of it")
	var data: WaveData = RunState.get_current_wave_data()
	if data == null:
		_check(false, "the current wave has data")
		return
	# Kill one enemy outright so the wave is partly resolved, then suspend.
	var monster: JamoMonster = await _await_alive_monster(spawner.objective)
	if monster == null:
		_check(false, "no monster spawned to kill before the suspend")
		return
	var resolved_before: int = RunState.wave_resolved_count
	monster.take_click_damage(monster.max_hp)
	await get_tree().process_frame
	var resolved: int = RunState.wave_resolved_count
	_check(resolved == resolved_before + 1,
		"the kill counted toward the wave's resolved enemies (%d -> %d)"
			% [resolved_before, resolved])
	_check(resolved < data.enemy_count, "the wave is not finished yet, so a resume has work left")
	if resolved >= data.enemy_count:
		return

	SaveManager.save_run()
	_check(int(SaveManager.peek_run().get("wave_resolved_count", -1)) == resolved,
		"the suspended run carries wave_resolved_count = %d" % resolved)
	var wave: int = RunState.current_wave
	var energy: int = RunState.current_energy
	RunState.reset()
	_check(SaveManager.load_run(), "the suspended run loads back")
	_check(RunState.current_wave == wave and RunState.current_energy == energy,
		"the resumed run keeps its wave and energy (%d, %d)" % [wave, energy])
	_check(RunState.wave_resolved_count == resolved,
		"the resumed run remembers %d resolved enemies, got %d"
			% [resolved, RunState.wave_resolved_count])

	# What the WaveController does on a resumed run, on an emptied field.
	spawner.clear_field()
	spawner.configure_wave(data, RunState.wave_resolved_count)
	_check(int(spawner.get("_spawned")) == resolved,
		"the spawner skips the %d enemies already resolved, starts at %d"
			% [resolved, int(spawner.get("_spawned"))])
	_check(not spawner.is_wave_exhausted(), "the spawner still has the rest of the wave to send")
	print("    Wave %d resumed with %d / %d enemies already resolved, energy %d" % [
		wave, resolved, data.enemy_count, energy,
	])


# --- 5. failure -------------------------------------------------------------

func _test_core_is_the_only_failure(core: SentenceCore, result: Control) -> void:
	print("-- the 문장핵 is the only failure, the gold stays")
	while RunState.spend_click_energy():
		pass
	for _i in 20:
		await get_tree().process_frame
	_check(RunState.is_active, "energy 0 on a later wave still ends nothing")
	_check(not result.visible, "no result screen on energy 0")

	var gold_before: float = MetaState.gold
	var wave: int = RunState.current_wave
	_check(gold_before > 0.0, "the run has earned gold to keep")
	_failed_args = []
	core.take_hit(RunState.core_hp)
	_check(not RunState.is_active, "the core reaching 0 HP ends the run at once")
	_check(_failed_args.size() == 4 and int(_failed_args[0]) == wave,
		"run_failed reported Wave %d, got %s" % [wave, str(_failed_args)])
	_check(bool(_failed_args[3]) if _failed_args.size() == 4 else false,
		"the first run's reached wave is a new record")
	_check(MetaState.gold == gold_before,
		"the defeat took no gold back (doc v0.4 section 14): %.2f vs %.2f"
			% [MetaState.gold, gold_before])
	_check(MetaState.highest_wave == wave, "the reached wave is recorded in MetaState")

	var waited := 0
	while not result.visible and waited < WAIT_FRAME_BUDGET:
		await get_tree().process_frame
		waited += 1
	_check(result.visible, "the result screen appeared after the core fell")
	if not result.visible:
		return
	var subtitle: Label = result.get_node("Center/Panel/Box/SubtitleLabel")
	_check(subtitle.text.contains("문장핵"),
		"the result names the 문장핵 as the failure, got %s" % subtitle.text)
	_check(result.get_node("%ResultWaveLabel").text.contains(str(wave)),
		"the result reports the reached wave, got %s" % result.get_node("%ResultWaveLabel").text)
	_check(result.get_node("%ResultGoldLabel").text.contains("유지"),
		"the result says the gold is kept")
	_check(not SaveManager.has_run_save(), "the failed run is off the disk")
	_check(MetaState.gold == gold_before, "the gold is still there at the result screen")
	print("    result: %s | %s | %s" % [
		result.get_node("%ResultWaveLabel").text,
		result.get_node("%ResultKillsLabel").text,
		result.get_node("%ResultGoldLabel").text,
	])


# --- plumbing ---------------------------------------------------------------

## The living monster furthest from `far_from`, waiting for one to spawn.
func _await_alive_monster(far_from: Node3D) -> JamoMonster:
	var waited := 0
	while waited < WAIT_FRAME_BUDGET:
		var best: JamoMonster = null
		var best_distance := -1.0
		for node: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
			var monster := node as JamoMonster
			if monster == null or not monster.is_inside_tree() or not monster.is_alive():
				continue
			var distance := monster.global_position.distance_to(far_from.global_position)
			if distance > best_distance:
				best = monster
				best_distance = distance
		if best != null:
			return best
		await get_tree().process_frame
		waited += 1
	return null


## Loads a scene into the current-scene slot, the way the game's own
## change_scene_to_file() would. The test node stays off that slot.
func _enter(path: String) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_check(false, "could not load %s" % path)
		return null
	var scene: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	return scene
