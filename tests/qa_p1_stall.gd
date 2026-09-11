extends Node

## QA P1 probe: does a wave always finish on its own once the energy is gone?
##
## The Wave 1~5 playthrough saw Wave 5 sit with one monster left and never
## reach Wave Clear. This walks Wave 5 with no clicks at all and reports what
## the survivors are doing - state, position, distance to the 문장핵 and the
## target they picked - so a softlock can be told apart from a slow walk.
##
## Run: godot --headless --path . res://tests/qa_p1_stall.tscn

const RUN_SCENE := "res://scenes/main/main.tscn"
const WAVE := 5
## Well past the walk time of a 10-monster wave at this clock.
const FRAME_BUDGET := 6000
const TIME_SCALE := 4.0
## true spends the energy the way a player does - real mouse events on the
## monsters - instead of draining RunState directly. The windowed playthrough
## only stalled on the clicked run, so this is the variable under test.
const CLICK_FIRST := true

var _cleared: Array[int] = []
## Set by either probe when it sees the freeze; the exit code reports it.
var _failed: bool = false


func _ready() -> void:
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	Engine.time_scale = TIME_SCALE
	SignalBus.wave_cleared.connect(func(wave: int) -> void: _cleared.append(wave))
	await _run()
	Engine.time_scale = 1.0
	get_tree().quit(1 if _failed else 0)


func _run() -> void:
	var packed: PackedScene = load(RUN_SCENE) as PackedScene
	var main: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	await get_tree().process_frame
	await get_tree().process_frame

	var spawner: SpawnManager = main.get_node("World/GameWorld/SpawnManager")
	var core: SentenceCore = main.get_node("World/GameWorld/SentenceCore")
	# Plenty of core HP so the probe measures the wave, not the fail rule.
	RunState.core_max_hp = 9999.0
	RunState.core_hp = 9999.0
	RunState.begin_wave(WAVE)
	await _repro_click_during_turn()
	if CLICK_FIRST:
		await _spend_energy_on_real_clicks(core)
	else:
		while RunState.spend_click_energy():
			pass
	print("-- Wave %d, energy %d, clicks %s"
		% [RunState.current_wave, RunState.current_energy, str(CLICK_FIRST)])

	var frames := 0
	while not _cleared.has(WAVE) and frames < FRAME_BUDGET:
		await get_tree().process_frame
		frames += 1
		if frames % 1500 == 0:
			_dump(spawner, core, frames)
	if _cleared.has(WAVE):
		print("OK - Wave %d cleared on its own after %d frames." % [WAVE, frames])
	else:
		_failed = true
		printerr("STALL - Wave %d never cleared in %d frames." % [WAVE, frames])
		_dump(spawner, core, frames)


func _dump(spawner: SpawnManager, core: SentenceCore, frames: int) -> void:
	print("    frame %d: spawning=%s alive=%d exhausted=%s core=%.0f"
		% [frames, str(spawner.is_spawning()), spawner.alive_count(),
			str(spawner.is_wave_exhausted()), RunState.core_hp])
	for node: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
		var monster := node as JamoMonster
		if monster == null or not monster.is_inside_tree():
			continue
		var extents: Vector2 = monster.get_walkable_half_extents()
		var goal: Vector3 = JamoMonster.clamp_point_to_arena(
			Vector3(core.global_position.x, monster.global_position.y, core.global_position.z),
			extents
		)
		# jamo_monster.gd: enum State { SPAWN 0, IDLE 1, WALK 2, TURN 3, DEAD 4 }.
		# A monster parked in TURN has no branch in _physics_process, so it zeroes
		# its velocity every frame and never moves again.
		print("      %s state=%s anim=%s" % [
			monster.monster_data.id, str(monster.get("_state")),
			str(monster.get_node("AnimationPlayer").current_animation),
		])
		print("      %s alive=%s hp=%.0f pos=(%.2f, %.2f) d_core=%.2f reach=%.2f"
			% [monster.monster_data.id, str(monster.is_alive()), monster.hp,
				monster.global_position.x, monster.global_position.z,
				_flat_distance(monster.global_position, core.global_position),
				core.reach_radius])
		print("        walkable=(%.2f, %.2f) clamped_goal=(%.2f, %.2f) goal_to_core=%.2f"
			% [extents.x, extents.y, goal.x, goal.z,
				_flat_distance(goal, core.global_position)])


## Deterministic repro of the freeze the windowed playthrough hit: a click that
## lands while the monster is in State.TURN and does not kill it.
##
## _begin_turn() plays "turn"; take_click_damage() plays "hit" over it, so the
## "turn" animation never reports animation_finished and _begin_walk() is never
## reached. _on_animation_finished("hit") then sees a state that is not WALK and
## only swaps the animation back to idle - _state stays TURN. _physics_process
## has no branch for TURN, so the monster never moves, never reaches the core
## and never dies. The wave can no longer be cleared.
func _repro_click_during_turn() -> void:
	print("-- repro: one non-lethal click delivered during State.TURN")
	var monster: JamoMonster = null
	var waited := 0
	while monster == null and waited < 2000:
		await get_tree().process_frame
		waited += 1
		for node: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
			var candidate := node as JamoMonster
			if candidate != null and candidate.is_alive() and candidate.hp > 1.0:
				monster = candidate
				break
	if monster == null:
		printerr("  could not find a monster with more than 1 HP")
		return
	# Put it in the state the player's click can interrupt, then click it once.
	monster.call("_begin_turn")
	await get_tree().process_frame
	print("    before: state=%s pos=(%.2f, %.2f) hp=%.0f"
		% [str(monster.get("_state")), monster.global_position.x,
			monster.global_position.z, monster.hp])
	monster.take_click_damage(1.0)
	var start: Vector3 = monster.global_position
	var moved := 0.0
	var alive := true
	var state: String = ""
	var anim: String = ""
	for _i in 600:
		await get_tree().process_frame
		# A monster that walks on reaches the core and is freed inside this
		# window; the last reading before that is what gets reported.
		if not is_instance_valid(monster) or not monster.is_alive():
			alive = false
			break
		moved = start.distance_to(monster.global_position)
		state = str(monster.get("_state"))
		anim = str(monster.get_node("AnimationPlayer").current_animation)
	print("    after 600 frames: state=%s anim=%s moved=%.4f m alive=%s"
		% [state, anim, moved, str(alive)])
	# Separation nudges a parked monster a few centimetres; real walking covers
	# metres in 600 frames.
	if moved < 0.5 and alive:
		_failed = true
		printerr("  FROZEN - the clicked monster never moved again.")
	else:
		print("    the clicked monster kept walking.")


## Spends the wave's energy with real mouse events aimed at the monster closest
## to the core, the way the windowed playthrough does.
func _spend_energy_on_real_clicks(core: Node3D) -> void:
	var attempts := 0
	while RunState.current_energy > 0 and attempts < 400:
		attempts += 1
		var target: JamoMonster = null
		var best := INF
		for node: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
			var monster := node as JamoMonster
			if monster == null or not monster.is_inside_tree() or not monster.is_alive():
				continue
			var distance: float = monster.global_position.distance_to(core.global_position)
			if distance < best:
				target = monster
				best = distance
		if target == null:
			await get_tree().process_frame
			continue
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera == null:
			print("    no camera, draining directly")
			while RunState.spend_click_energy():
				pass
			return
		var point: Vector2 = camera.unproject_position(target.global_position)
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = point
			event.global_position = point
			Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame
	print("    %d click attempts, energy %d" % [attempts, RunState.current_energy])


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
