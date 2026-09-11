extends Node

## QA P1 negative control for test_wave_combat block 3.
##
## test_wave_combat claims "a DoT kill at energy 0 pays gold". That claim is
## only meaningful if gold does NOT move on its own while energy is 0. This
## harness runs both arms:
##
##   control  - energy 0, no burn applied, wait: MetaState.gold must not move.
##   treated  - energy 0, burn applied to one monster: MetaState.gold must move.
##
## A tautological test would pass the treated arm even when the control arm
## also "passes" by gold drifting upward for unrelated reasons.
## Run: godot --headless --path . res://tests/qa_p1_negctl.tscn

const RUN_SCENE := "res://scenes/main/main.tscn"
const WAIT_FRAME_BUDGET := 4000
const CONTROL_FRAMES := 600
const TIME_SCALE := 4.0

var _failures: int = 0


func _ready() -> void:
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	Engine.time_scale = TIME_SCALE
	await _run()
	Engine.time_scale = 1.0
	if _failures == 0:
		print("OK - the DoT-at-energy-0 claim survives its negative control.")
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
	var main: Node = await _enter(RUN_SCENE)
	if main == null:
		return
	var spawner: SpawnManager = main.get_node("World/GameWorld/SpawnManager")
	_check(spawner != null and RunState.is_active, "the run scene opened into an active run")
	if spawner == null:
		return

	while RunState.spend_click_energy():
		pass
	_check(RunState.current_energy == 0, "energy was spent to 0")

	# --- control arm: no burn, nothing clicked --------------------------------
	var gold_before: float = MetaState.gold
	var kills_before: float = RunState.get_run_statistic("kills")
	for _i in CONTROL_FRAMES:
		await get_tree().process_frame
	_check(MetaState.gold == gold_before,
		"CONTROL: gold must not move with no burn and no click (%.2f -> %.2f)"
			% [gold_before, MetaState.gold])
	_check(RunState.get_run_statistic("kills") == kills_before,
		"CONTROL: kills must not move with no burn and no click (%.0f -> %.0f)"
			% [kills_before, RunState.get_run_statistic("kills")])
	_check(RunState.is_active, "CONTROL: the run is still alive at energy 0")
	print("    control: gold %.2f -> %.2f, kills %.0f -> %.0f over %d frames" % [
		gold_before, MetaState.gold, kills_before,
		RunState.get_run_statistic("kills"), CONTROL_FRAMES,
	])
	if not RunState.is_active:
		return

	# --- treated arm: one burn, still nothing clicked -------------------------
	var burn: WordEffectData = _burn_effect()
	_check(burn != null, "the word 불 carries a burn effect")
	if burn == null:
		return
	var monster: JamoMonster = await _await_alive_monster(spawner.objective)
	if monster == null:
		_check(false, "a monster was on the field to burn")
		return
	# The control wait may have let a Wave Clear refill the energy, so drain it
	# again: the treated arm has to burn while the energy really is 0.
	while RunState.spend_click_energy():
		pass
	var treated_gold: float = MetaState.gold
	var energy_at_burn: int = RunState.current_energy
	monster.apply_status_effect(burn)
	var waited := 0
	while is_instance_valid(monster) and monster.is_alive() and waited < WAIT_FRAME_BUDGET:
		await get_tree().process_frame
		waited += 1
	_check(MetaState.gold > treated_gold,
		"TREATED: the burn kill paid gold (%.2f -> %.2f)" % [treated_gold, MetaState.gold])
	_check(energy_at_burn == 0, "TREATED: the burn was applied while energy was 0")
	print("    treated: gold %.2f -> %.2f after %d frames, energy at burn %d" % [
		treated_gold, MetaState.gold, waited, energy_at_burn,
	])


func _burn_effect() -> WordEffectData:
	var word: WordData = MetaState.database.find_word(&"fire_001")
	if word == null:
		return null
	for effect: WordEffectData in word.base_effects:
		if effect != null and effect.effect_type == WordEffectData.EffectType.UNLOCK_BURN:
			return effect
	return null


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
