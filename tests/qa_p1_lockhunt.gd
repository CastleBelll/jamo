extends Node

## QA P1 re-verification: try hard to park a monster with a click.
##
## The P1 CRITICAL was a click that landed in State.TURN and left the monster
## standing for good. The fix moves SPAWN / IDLE / TURN onto _state_timer.
## This attacks that claim in the real main.tscn, with the real WaveController
## driving the waves - nothing here calls begin_wave() or advances a wave.
##
##   1. overlap arm - a click on the same frame as a DoT death, a click on a
##      monster already playing "death", and a click on every frame of one
##      monster's whole walk into the 문장핵.
##   2. hammer arm - the run plays from Wave 1 up. Every time a monster ENTERS
##      SPAWN, IDLE or TURN it takes a non-lethal click, plus a second one on
##      the next frame so that one lands inside the hit reaction. A monster on
##      its last hit point is never clicked, so a click can never be the thing
##      that resolves the wave: the wave has to clear by monsters walking
##      through on their own. Spreading the clicks over state ENTRIES rather
##      than every frame is what gets the scarce non-lethal budget of a 2~3 HP
##      monster onto TURN and IDLE instead of burning it all on SPAWN.
##   3. every wave_cleared must arrive on an empty field, and no wave may miss
##      its frame budget.
##
## Run: godot --headless --path . res://tests/qa_p1_lockhunt.tscn

const RUN_SCENE := "res://scenes/main/main.tscn"
const TIME_SCALE := 4.0
## Waves the run has to get through. 6..8 replay Wave 5 data (3 HP), which is
## where the most non-lethal clicks per monster are available.
const LAST_WAVE := 8
const FRAME_BUDGET := 24000
## Frames one wave may take before the run counts as stalled.
const WAVE_FRAME_BUDGET := 4000

var _failures: int = 0
var _cleared: Array[int] = []
## wave -> monsters still standing when wave_cleared arrived.
var _alive_at_clear: Dictionary = {}
var _clicks_by_state: Dictionary = {}
var _nonlethal: int = 0
var _spawner: SpawnManager = null
## monster -> the state its last click was delivered in, so each state entry is
## clicked once instead of every frame.
var _last_click_state: Dictionary = {}


func _ready() -> void:
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	Engine.time_scale = TIME_SCALE
	SignalBus.wave_cleared.connect(_on_wave_cleared)
	await _run()
	Engine.time_scale = 1.0
	SaveManager.delete_save()
	print("    non-lethal clicks by state: %s (total %d)"
		% [str(_clicks_by_state), _nonlethal])
	if _failures == 0:
		print("OK - no click in any state parked a monster; every wave cleared itself.")
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _on_wave_cleared(wave: int) -> void:
	_cleared.append(wave)
	_alive_at_clear[wave] = _spawner.alive_count() if _spawner != null else -1


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

	_spawner = main.get_node("World/GameWorld/SpawnManager")
	var core: SentenceCore = main.get_node("World/GameWorld/SentenceCore")
	# Every monster is meant to leak here, so the core is put out of reach of
	# the fail rule; the fail rule itself is covered by test_wave_combat.
	RunState.core_max_hp = 999999.0
	RunState.core_hp = 999999.0

	await _overlap_arm(core)
	await _hammer_arm(core)


# --- 1. overlaps -----------------------------------------------------------

func _overlap_arm(core: SentenceCore) -> void:
	print("-- overlap: clicks colliding with a DoT death, a death animation, an arrival")
	var burn: WordEffectData = _burn_effect()
	_check(burn != null, "the word 불 still carries the burn effect")

	var victim: JamoMonster = await _await_monster()
	if victim != null and burn != null:
		victim.hp = 1.0
		victim.apply_status_effect(burn)
		var guard := 0
		while is_instance_valid(victim) and victim.is_alive() and guard < 2000:
			victim.take_click_damage(0.0)
			await get_tree().process_frame
			guard += 1
		_check(not is_instance_valid(victim) or not victim.is_alive(),
			"the burn still killed the monster that was being clicked every frame")

	var dying: JamoMonster = await _await_monster()
	if dying != null:
		dying.take_click_damage(dying.hp)
		await get_tree().process_frame
		_check(not dying.take_click_damage(1.0),
			"a click on a monster playing its death animation is refused")

	var walker: JamoMonster = await _await_monster()
	if walker != null:
		var start: Vector3 = walker.global_position
		var frames := 0
		while is_instance_valid(walker) and walker.is_alive() and frames < 3000:
			walker.take_click_damage(0.0)
			await get_tree().process_frame
			frames += 1
		_check(frames < 3000,
			"the monster clicked on every frame of its walk still resolved (%d frames)" % frames)
		print("    a monster clicked on all %d frames of its walk still left the field (%.2f m)"
			% [frames, _flat_distance(start, core.global_position)])


# --- 2. hammer -------------------------------------------------------------

func _hammer_arm(core: SentenceCore) -> void:
	print("-- hammer: a non-lethal click on every SPAWN / IDLE / TURN entry, up to Wave %d"
		% LAST_WAVE)
	var pending: Array[JamoMonster] = []
	var frames := 0
	var last_clear_frame := 0
	var reported: Array[int] = []
	while not _cleared.has(LAST_WAVE) and frames < FRAME_BUDGET:
		for monster: JamoMonster in pending:
			# Lands inside the 0.18 s hit reaction the previous click started.
			_click(monster)
		pending.clear()
		for monster: JamoMonster in _alive_monsters():
			var state: JamoMonster.State = monster.get_state()
			if state == JamoMonster.State.WALK:
				_last_click_state.erase(monster)
				continue
			if _last_click_state.get(monster, -1) == state:
				continue
			# A 2~3 HP monster affords one or two non-lethal clicks in its whole
			# life, and it meets SPAWN then IDLE before it ever reaches TURN -
			# the state the P1 bug lived in. Spending clicks in arrival order
			# would leave TURN almost untouched, so each monster is assigned one
			# state to wait for and the field covers all three.
			if state != _assigned_state(monster):
				continue
			if _click(monster):
				_last_click_state[monster] = state
				pending.append(monster)
		for monster: JamoMonster in _alive_monsters():
			# An arrival and a click colliding on the same frame.
			if _flat_distance(monster.global_position, core.global_position) \
					<= core.reach_radius + 0.3:
				monster.take_click_damage(0.0)
		await get_tree().process_frame
		frames += 1
		for wave: int in _cleared:
			if reported.has(wave):
				continue
			reported.append(wave)
			print("    Wave %d cleared after %d frames, %d alive at the clear"
				% [wave, frames - last_clear_frame, int(_alive_at_clear.get(wave, -1))])
			_check(frames - last_clear_frame < WAVE_FRAME_BUDGET,
				"Wave %d cleared inside its frame budget" % wave)
			_check(int(_alive_at_clear.get(wave, -1)) == 0,
				"Wave %d was declared clear on an empty field, got %d alive"
					% [wave, int(_alive_at_clear.get(wave, -1))])
			last_clear_frame = frames

	_check(_cleared.has(LAST_WAVE),
		"the run reached Wave Clear %d under the click hammer (%d frames, %d alive)"
			% [LAST_WAVE, frames, _alive_monsters().size()])
	if _cleared.has(LAST_WAVE):
		return
	for monster: JamoMonster in _alive_monsters():
		printerr("    survivor %s state=%s hp=%.0f pos=(%.2f, %.2f) d_core=%.2f" % [
			monster.monster_data.id, JamoMonster.State.keys()[monster.get_state()],
			monster.hp, monster.global_position.x, monster.global_position.z,
			_flat_distance(monster.global_position, core.global_position),
		])


## The one state this monster saves its non-lethal clicks for. Half the field
## waits for TURN, because that is where the P1 freeze was found.
func _assigned_state(monster: JamoMonster) -> JamoMonster.State:
	match monster.get_instance_id() % 4:
		0:
			return JamoMonster.State.SPAWN
		1:
			return JamoMonster.State.IDLE
		_:
			return JamoMonster.State.TURN


## One non-lethal click, recorded by the state it landed in. A monster on its
## last hit point is left alone so a click can never resolve the wave.
func _click(monster: JamoMonster) -> bool:
	if not is_instance_valid(monster) or not monster.is_alive() or monster.hp <= 1.0:
		return false
	var key: String = JamoMonster.State.keys()[monster.get_state()]
	_clicks_by_state[key] = int(_clicks_by_state.get(key, 0)) + 1
	_nonlethal += 1
	return monster.take_click_damage(1.0)


func _burn_effect() -> WordEffectData:
	var word: WordData = MetaState.database.find_word(&"fire_001")
	if word == null:
		return null
	for effect: WordEffectData in word.base_effects:
		if effect != null and effect.effect_type == WordEffectData.EffectType.UNLOCK_BURN:
			return effect
	return null


# --- helpers ---------------------------------------------------------------

func _await_monster() -> JamoMonster:
	var waited := 0
	while waited < WAVE_FRAME_BUDGET:
		var monsters: Array[JamoMonster] = _alive_monsters()
		if not monsters.is_empty():
			return monsters[0]
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
