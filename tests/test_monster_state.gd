extends Node

## Headless check that a click can never park a JamoMonster, walked in the
## real main.tscn with the real spawner and 문장핵.
## Run: godot --headless --path . res://tests/test_monster_state.tscn
##
##   1. treated arm - for each of SPAWN / IDLE / TURN / WALK a monster is put
##      in that state through its own transition and a non-lethal click lands
##      at once, then a second one during the hit reaction. Within the frame
##      budget it has to leave the state (WALK excepted) and cover ground.
##   2. control arm - the same probe against a monster whose TURN timer is
##      pinned to INF, the shape of the P1 bug: a transition owner that never
##      fires. The probe has to report that monster as frozen, or it could not
##      have caught the bug it exists for and the treated arm proves nothing.
##   3. chaos arm - Wave 5 played with a non-lethal click landing on a random
##      live monster every few frames, in whatever state it is in, with extra
##      SPAWN / TURN re-entries forced right before some of them. The wave has
##      to clear on its own afterwards.

const RUN_SCENE := "res://scenes/main/main.tscn"
## Wave 5 monsters have 3 HP, so a 1-damage click never kills the probe.
const WAVE := 5
const TIME_SCALE := 4.0
## Frames a probed monster gets to leave its state and start covering ground.
## Real walking crosses metres in this time; the P1 freeze is permanent.
const PROBE_FRAMES := 600
## Metres that count as walking. Separation nudges a parked monster a few cm.
const WALKED_DISTANCE := 0.5
## Frames between the second click and the first, inside the 0.18 s hit.
const SECOND_CLICK_DELAY := 4
const CHAOS_FRAMES := 900
const CHAOS_CLICK_EVERY := 3
const CHAOS_FORCE_EVERY := 30
const WAVE_FRAME_BUDGET := 6000
## Minimum distance to the core for a probe monster, so it cannot be resolved
## by arriving before the probe has seen it walk.
const MIN_PROBE_CORE_DISTANCE := 2.0

var _failures: int = 0
var _cleared: Array[int] = []


func _ready() -> void:
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	Engine.time_scale = TIME_SCALE
	SignalBus.wave_cleared.connect(func(wave: int) -> void: _cleared.append(wave))
	await _run()
	Engine.time_scale = 1.0
	SaveManager.delete_save()
	if _failures == 0:
		print("OK - no state parks a clicked monster, and the probe can tell a parked one.")
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
	var packed: PackedScene = load(RUN_SCENE) as PackedScene
	var main: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	await get_tree().process_frame
	await get_tree().process_frame

	var core: SentenceCore = main.get_node("World/GameWorld/SentenceCore")
	# Plenty of core HP: the run must not end while monsters walk through.
	RunState.core_max_hp = 9999.0
	RunState.core_hp = 9999.0
	RunState.begin_wave(WAVE)

	await _treated_arm(core)
	await _control_arm(core)
	await _chaos_arm(core)


# --- 1. treated: every state survives a click ------------------------------

func _treated_arm(core: Node3D) -> void:
	print("-- treated: a click during each state")
	for begin: StringName in [&"_begin_spawn", &"_begin_idle", &"_begin_turn", &"_begin_walk"]:
		var monster: JamoMonster = await _fresh_probe_monster(core)
		if monster == null:
			_check(false, "no monster with full HP available for %s" % begin)
			return
		var report: Dictionary = await _probe(monster, begin)
		print("    %s: left after %d frames, moved %.2f m, alive=%s" % [
			begin, report.left_after, report.moved, str(report.alive)
		])
		if not report.alive:
			_check(false, "%s: the probe monster died of two 1-damage clicks" % begin)
			continue
		_check(report.moved >= WALKED_DISTANCE,
			"%s: the clicked monster walked on (moved %.2f m in %d frames)"
				% [begin, report.moved, PROBE_FRAMES])
		if begin != &"_begin_walk":
			_check(report.left_after >= 0,
				"%s: the monster left the state it was clicked in" % begin)


# --- 2. control: the probe sees a parked monster ---------------------------

func _control_arm(core: Node3D) -> void:
	print("-- control: a TURN whose owner never fires must read as frozen")
	var monster: JamoMonster = await _fresh_probe_monster(core)
	if monster == null:
		_check(false, "no monster with full HP available for the control arm")
		return
	# _probe() enters TURN itself; pinning the timer right after mirrors the
	# P1 bug where the transition out of TURN was lost for good.
	var report: Dictionary = await _probe(
		monster, &"_begin_turn", func() -> void: monster.set("_state_timer", INF)
	)
	print("    pinned TURN: left after %d frames, moved %.2f m" % [
		report.left_after, report.moved
	])
	_check(report.left_after < 0 and report.moved < WALKED_DISTANCE,
		"negative control: the probe reports a monster with no way out of TURN as frozen")
	# Release it so the wave can still clear.
	if is_instance_valid(monster) and monster.is_alive():
		monster.set("_state_timer", 0.0)


# --- 3. chaos: clicks in every state, then the wave clears -----------------

func _chaos_arm(core: Node3D) -> void:
	print("-- chaos: random non-lethal clicks for %d frames, then Wave %d must clear"
		% [CHAOS_FRAMES, WAVE])
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5A5A
	var clicks := 0
	var forced := 0
	for frame in CHAOS_FRAMES:
		await get_tree().process_frame
		if frame % CHAOS_CLICK_EVERY != 0:
			continue
		var monsters: Array[JamoMonster] = _alive_monsters()
		if monsters.is_empty():
			continue
		var monster: JamoMonster = monsters[rng.randi_range(0, monsters.size() - 1)]
		if monster.hp <= 1.0:
			continue
		if frame % CHAOS_FORCE_EVERY == 0:
			# Re-enter the two one-shot states so the click lands inside them.
			monster.call(&"_begin_turn" if forced % 2 == 0 else &"_begin_spawn")
			forced += 1
		monster.take_click_damage(1.0)
		clicks += 1
	print("    %d clicks landed, %d of them on a forced SPAWN/TURN" % [clicks, forced])
	_check(clicks > 0, "the chaos arm actually delivered clicks")

	# Earlier arms may already have cleared Wave 5 and moved on (Wave 6+ replays
	# its data), so the wave under test is whichever one the clicks ended in.
	var wave: int = RunState.current_wave
	_check(not _cleared.has(wave), "the wave the chaos ended in is still open")
	var frames := 0
	while not _cleared.has(wave) and frames < WAVE_FRAME_BUDGET:
		await get_tree().process_frame
		frames += 1
	_check(_cleared.has(wave),
		"Wave %d cleared on its own after the chaos clicks (waited %d frames, %d still alive)"
			% [wave, frames, _alive_monsters().size()])
	if _cleared.has(wave):
		print("    Wave %d cleared after %d frames" % [wave, frames])
		return
	for monster: JamoMonster in _alive_monsters():
		printerr("    survivor %s state=%s hp=%.0f pos=(%.2f, %.2f) d_core=%.2f" % [
			monster.monster_data.id, JamoMonster.State.keys()[monster.get_state()],
			monster.hp, monster.global_position.x, monster.global_position.z,
			_flat_distance(monster.global_position, core.global_position),
		])


# --- helpers ---------------------------------------------------------------

## Enters `begin` on the monster, runs `after_enter`, then clicks it twice and
## watches. Reports the frame it left the entered state (-1 for never), how far
## it moved, and whether it is still alive. Ends early once it has both left
## and walked, so a healthy probe is quick and a frozen one uses the budget.
func _probe(monster: JamoMonster, begin: StringName, after_enter: Callable = Callable()) -> Dictionary:
	monster.call(begin)
	if after_enter.is_valid():
		after_enter.call()
	var entered: JamoMonster.State = monster.get_state()
	await get_tree().process_frame
	monster.take_click_damage(1.0)
	var start: Vector3 = monster.global_position
	var left_after := -1
	var moved := 0.0
	for frame in PROBE_FRAMES:
		await get_tree().process_frame
		if frame == SECOND_CLICK_DELAY:
			monster.take_click_damage(1.0)
		if not is_instance_valid(monster) or not monster.is_alive():
			return {"left_after": left_after, "moved": moved, "alive": false}
		if left_after < 0 and monster.get_state() != entered:
			left_after = frame
		moved = _flat_distance(start, monster.global_position)
		var left_or_walking: bool = left_after >= 0 or entered == JamoMonster.State.WALK
		if left_or_walking and moved >= WALKED_DISTANCE:
			break
	return {"left_after": left_after, "moved": moved, "alive": true}


## A live monster at full HP, far enough from the core to be watched walking.
func _fresh_probe_monster(core: Node3D) -> JamoMonster:
	var waited := 0
	while waited < WAVE_FRAME_BUDGET:
		for monster: JamoMonster in _alive_monsters():
			if monster.hp >= monster.max_hp and monster.hp > 2.0 \
					and _flat_distance(monster.global_position, core.global_position) \
						>= MIN_PROBE_CORE_DISTANCE:
				return monster
		await get_tree().process_frame
		waited += 1
	return null


func _alive_monsters() -> Array[JamoMonster]:
	var result: Array[JamoMonster] = []
	for node: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
		var monster := node as JamoMonster
		if monster != null and monster.is_inside_tree() and monster.is_alive():
			result.append(monster)
	return result


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
