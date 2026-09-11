extends Node

## QA P1 re-verification of the two policy MEDIUMs: RUN 이어하기 and the retired
## upgrade track. Run in the real main.tscn with the real spawner.
##
##   1. resume arm - suspend a partly finished wave, load it back and count the
##      monsters that actually appear: only what the wave still owed.
##   2. farm arm - suspend and resume the same wave five times over, killing one
##      monster each round, and watch MetaState.gold. Under the shipped policy
##      the wave can pay out at most enemy_count kills no matter how often it is
##      suspended. The same loop is then replayed with the policy DEV rejected
##      (resume refills the energy and forgets the progress) to see whether the
##      farm it was rejected for is real.
##   3. defeat arm - a run that lost the 문장핵 leaves nothing to resume (§44).
##   4. shop arm - the retired monster_capacity track is neither listed nor
##      sellable, every other track still is, the resource is still in the
##      database, and a save that already has levels in it survives a load.
##
## Run: godot --headless --path . res://tests/qa_p1_resume_econ.tscn

const RUN_SCENE := "res://scenes/main/main.tscn"
const TIME_SCALE := 4.0
const WAIT_FRAME_BUDGET := 4000
## Suspend/resume rounds the farm arm plays against one wave.
const FARM_ROUNDS := 5

var _failures: int = 0


func _ready() -> void:
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	Engine.time_scale = TIME_SCALE
	await _run()
	Engine.time_scale = 1.0
	SaveManager.delete_save()
	if _failures == 0:
		print("OK - resume returns only what the wave owed, the farm is closed, the retired track is gone from the shop.")
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
	var main: Node = await _open_run()
	var spawner: SpawnManager = main.get_node("World/GameWorld/SpawnManager")
	RunState.core_max_hp = 999999.0
	RunState.core_hp = 999999.0

	await _resume_arm(main, spawner)
	await _farm_arm()
	await _defeat_arm()
	_shop_arm()


func _open_run() -> Node:
	var packed: PackedScene = load(RUN_SCENE) as PackedScene
	var main: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	await get_tree().process_frame
	await get_tree().process_frame
	return main


# --- 1. resume -------------------------------------------------------------

## Suspend mid wave, reload the whole scene the way RUN 이어하기 does, and count
## what comes back.
func _resume_arm(main: Node, _spawner: SpawnManager) -> void:
	print("-- resume: a suspended wave brings back only what it still owed")
	var data: WaveData = RunState.get_current_wave_data()
	if data == null:
		_check(false, "the current wave has data")
		return
	var killed := 0
	var guard := 0
	while killed < 3 and guard < WAIT_FRAME_BUDGET:
		for monster: JamoMonster in _alive_monsters():
			if killed >= 3:
				break
			RunState.spend_click_energy()
			monster.take_click_damage(monster.max_hp)
			killed += 1
		await get_tree().process_frame
		guard += 1
	var wave: int = RunState.current_wave
	var energy: int = RunState.current_energy
	_check(RunState.wave_resolved_count == killed,
		"the %d kills counted as resolved, got %d" % [killed, RunState.wave_resolved_count])

	SaveManager.save_run()
	_check(int(SaveManager.peek_run().get("wave_resolved_count", -1)) == killed,
		"the suspended run carries wave_resolved_count = %d" % killed)
	_check(not SaveManager.peek_meta().has("wave_resolved_count"),
		"wave_resolved_count is not in the meta block")

	# Leave the run scene entirely, then come back through load_run() + a fresh
	# main.tscn, which is exactly what the hub's RUN 이어하기 does.
	main.queue_free()
	await get_tree().process_frame
	RunState.reset()
	_check(SaveManager.load_run(), "the suspended run loads back")
	var resumed: Node = await _open_run()
	var resumed_spawner: SpawnManager = resumed.get_node("World/GameWorld/SpawnManager")
	RunState.core_max_hp = 999999.0
	RunState.core_hp = 999999.0
	_check(RunState.current_wave == wave, "the resumed run is still on Wave %d" % wave)
	_check(RunState.current_energy == energy,
		"the resumed run keeps the energy it was suspended with (%d), got %d"
			% [energy, RunState.current_energy])

	var seen: Dictionary = {}
	var frames := 0
	while not resumed_spawner.is_wave_exhausted() and frames < WAIT_FRAME_BUDGET:
		for monster: JamoMonster in _alive_monsters():
			seen[monster.get_instance_id()] = true
		await get_tree().process_frame
		frames += 1
	for monster: JamoMonster in _alive_monsters():
		seen[monster.get_instance_id()] = true
	_check(seen.size() == data.enemy_count - killed,
		"the resumed wave spawned the %d enemies it still owed, got %d"
			% [data.enemy_count - killed, seen.size()])
	print("    Wave %d: %d of %d resolved before the suspend, %d spawned after it, energy %d"
		% [wave, killed, data.enemy_count, seen.size(), RunState.current_energy])
	resumed.queue_free()
	await get_tree().process_frame


# --- 2. farming ------------------------------------------------------------

## Suspending and resuming over and over must not turn one wave into an endless
## supply of kills. The shipped policy is measured first, then the policy that
## was rejected, so the rejection can be judged on a number rather than on a
## worry.
func _farm_arm() -> void:
	print("-- farm: %d suspend/resume rounds under each policy" % FARM_ROUNDS)
	var shipped: Dictionary = await _farm_round_trip(false)
	var rejected: Dictionary = await _farm_round_trip(true)
	print("    shipped policy  : Wave 1 paid %d kills / %.2f gold from %d spawns (wave owes %d), %d of %d rounds before it had to move on, energy %d"
		% [shipped.kills, shipped.gold, shipped.spawned, shipped.enemy_count,
			shipped.rounds, FARM_ROUNDS, shipped.energy])
	print("    rejected policy : Wave 1 paid %d kills / %.2f gold from %d spawns (wave owes %d), %d of %d rounds still on Wave 1, energy %d"
		% [rejected.kills, rejected.gold, rejected.spawned, rejected.enemy_count,
			rejected.rounds, FARM_ROUNDS, rejected.energy])
	_check(int(shipped.spawned) <= int(shipped.enemy_count),
		"the shipped policy never spawns more than Wave 1 owes (%d > %d)"
			% [int(shipped.spawned), int(shipped.enemy_count)])
	_check(int(shipped.kills) <= int(shipped.enemy_count),
		"the shipped policy caps the kills one wave can pay for (%d > %d)"
			% [int(shipped.kills), int(shipped.enemy_count)])
	_check(int(shipped.energy) <= int(shipped.start_energy),
		"the shipped policy never hands energy back on a resume")
	_check(int(rejected.spawned) > int(rejected.enemy_count),
		"the rejected policy really does re-spawn a wave that was already resolved")
	_check(rejected.kills > shipped.kills,
		"the rejected policy really does pay more for the same Wave 1 (%d kills vs %d)"
			% [int(rejected.kills), int(shipped.kills)])
	_check(int(rejected.energy) == int(rejected.start_energy),
		"the rejected policy really does hand the energy back every resume")


## One policy played for FARM_ROUNDS suspend/resume rounds against a fresh run.
## `refill` reproduces the rejected policy from the test side: the resume forgets
## the wave's progress and tops the energy back up. No production code changes.
func _farm_round_trip(refill: bool) -> Dictionary:
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	var main: Node = await _open_run()
	var spawner: SpawnManager = main.get_node("World/GameWorld/SpawnManager")
	RunState.core_max_hp = 999999.0
	RunState.core_hp = 999999.0
	var data: WaveData = RunState.get_current_wave_data()
	var start_energy: int = RunState.current_energy
	var seen: Dictionary = {}
	var kills := 0

	# One short of the whole wave each round, so the wave never clears and both
	# policies are measured on the same Wave 1 rather than one of them moving on.
	var per_round: int = maxi(1, (data.enemy_count if data != null else 2) - 1)
	var wave: int = RunState.current_wave
	var rounds := 0
	for _round_index in FARM_ROUNDS:
		# Only Wave 1 is being measured. The shipped policy eventually has to
		# finish it and move on, which is the point: gold there costs progress.
		if RunState.current_wave != wave:
			break
		rounds += 1
		var guard := 0
		var killed_this_round := 0
		while killed_this_round < per_round and guard < WAIT_FRAME_BUDGET \
				and RunState.current_wave == wave:
			for monster: JamoMonster in _alive_monsters():
				if RunState.current_wave == wave:
					seen[monster.get_instance_id()] = true
				if killed_this_round >= per_round:
					break
				if not RunState.spend_click_energy():
					break
				monster.take_click_damage(monster.max_hp)
				kills += 1
				killed_this_round += 1
			if RunState.current_energy <= 0:
				break
			await get_tree().process_frame
			guard += 1
		SaveManager.save_run()
		main.queue_free()
		await get_tree().process_frame
		RunState.reset()
		SaveManager.load_run()
		if refill:
			RunState.wave_resolved_count = 0
			RunState.current_energy = RunState.get_max_energy()
		main = await _open_run()
		spawner = main.get_node("World/GameWorld/SpawnManager")
		RunState.core_max_hp = 999999.0
		RunState.core_hp = 999999.0
		if RunState.current_wave == wave:
			for monster: JamoMonster in _alive_monsters():
				seen[monster.get_instance_id()] = true

	# Let whatever Wave 1 still owed finish spawning so the counts are comparable.
	var frames := 0
	while not spawner.is_wave_exhausted() and frames < WAIT_FRAME_BUDGET \
			and RunState.current_wave == wave:
		for monster: JamoMonster in _alive_monsters():
			seen[monster.get_instance_id()] = true
		await get_tree().process_frame
		frames += 1
	if RunState.current_wave == wave:
		for monster: JamoMonster in _alive_monsters():
			seen[monster.get_instance_id()] = true
	var result := {
		"kills": kills,
		"gold": MetaState.gold,
		"spawned": seen.size(),
		"enemy_count": data.enemy_count if data != null else 0,
		"energy": RunState.current_energy,
		"start_energy": start_energy,
		"rounds": rounds,
	}
	main.queue_free()
	await get_tree().process_frame
	return result


# --- 3. defeat -------------------------------------------------------------

func _defeat_arm() -> void:
	print("-- defeat: a lost run leaves nothing to resume")
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	var main: Node = await _open_run()
	_check(RunState.is_active, "a run is under way")
	RunState.damage_core(RunState.core_hp)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not RunState.is_active, "the run ended when the 문장핵 fell")
	_check(not SaveManager.has_run_save(),
		"no suspended run is left after a defeat (doc v0.4 section 44)")
	_check(not SaveManager.load_run(), "RUN 이어하기 has nothing to load after a defeat")
	main.queue_free()
	await get_tree().process_frame


# --- 4. shop ---------------------------------------------------------------

func _shop_arm() -> void:
	print("-- shop: the retired track is hidden but not deleted")
	var retired: UpgradeData = MetaState.database.find_upgrade(&"monster_capacity")
	_check(retired != null, "monster_capacity is still in game_database.tres")
	if retired == null:
		return
	_check(retired.is_retired, "monster_capacity is marked retired")
	_check(not UpgradeManager.is_visible(retired), "the shop does not list monster_capacity")
	_check(retired.costs.size() > 0 and retired.values.size() > 0,
		"the retired track keeps its costs and values (%d / %d)"
			% [retired.costs.size(), retired.values.size()])

	MetaState.reset()
	MetaState.add_gold(100000.0)
	_check(not UpgradeManager.purchase(retired), "a retired track cannot be bought")
	_check(MetaState.get_upgrade_level(&"monster_capacity") == 0,
		"the refused purchase changed nothing")

	var listed := 0
	for upgrade: UpgradeData in MetaState.database.upgrades:
		if upgrade == null:
			continue
		if UpgradeManager.is_visible(upgrade):
			listed += 1
			_check(not upgrade.is_retired, "%s is listed and not retired" % upgrade.id)
		else:
			_check(upgrade.is_retired, "%s is hidden only because it is retired" % upgrade.id)
	_check(listed == MetaState.database.upgrades.size() - 1,
		"exactly one track is hidden, %d of %d listed"
			% [listed, MetaState.database.upgrades.size()])
	print("    %d of %d tracks listed" % [listed, MetaState.database.upgrades.size()])

	# A save written before the track was retired still carries levels in it.
	MetaState.set_upgrade_level(&"monster_capacity", 3)
	MetaState.set_upgrade_level(&"max_energy", 2)
	SaveManager.save_meta()
	MetaState.reset()
	_check(SaveManager.load_game(), "a save holding a retired track still loads")
	_check(MetaState.get_upgrade_level(&"monster_capacity") == 3,
		"the retired track's bought levels survive the load, got %d"
			% MetaState.get_upgrade_level(&"monster_capacity"))
	_check(MetaState.get_upgrade_level(&"max_energy") == 2,
		"a live track next to it is unaffected, got %d"
			% MetaState.get_upgrade_level(&"max_energy"))
	_check(MetaState.get_monster_capacity() > 0,
		"get_monster_capacity() still answers, got %d" % MetaState.get_monster_capacity())
	print("    a save with monster_capacity level 3 loads and keeps it")


# --- helpers ---------------------------------------------------------------

func _alive_monsters() -> Array[JamoMonster]:
	var result: Array[JamoMonster] = []
	for node: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
		var monster := node as JamoMonster
		if monster != null and monster.is_inside_tree() and monster.is_alive():
			result.append(monster)
	return result
