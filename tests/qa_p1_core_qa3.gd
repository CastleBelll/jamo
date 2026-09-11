extends Node

## QA P1-QA-3: independent checks on the 문장핵 asset hookup, run in the real
## run scene. WINDOW MODE ONLY - it screenshots.
##
## Run: godot --path . res://tests/qa_p1_core_qa3.tscn
##
## This does not repeat qa_p1_core_asset. It covers the three things that probe
## leaves open:
##   A. repeated and interrupted hits - the shared GLB materials must survive
##      them, checked against a second, freshly loaded instance of the same GLB
##   B. reach geometry - how deep a monster gets into the book's footprint
##      before reach_radius 1.1 takes it off the field, front / side / back
##   C. a lock attempt of QA's own on the new core position: a non-lethal click
##      on every SPAWN and TURN entry, with the core pinned so the run cannot
##      end, through Wave 5 - the wave qa_p1_core_asset never asserts

const RUN_SCENE := "res://scenes/main/main.tscn"
const OUT_DIR := "res://tests/qa_artifacts/p1/core_qa3"
const HIT_ROUNDS := 8
const TARGET_WAVE := 5
const WAVE_FRAME_BUDGET := 20000
const PINNED_CORE_HP := 999999.0
## Colour distance under which two albedos count as the same colour.
const COLOUR_EPSILON := 0.001

var _failures: int = 0
var _cleared: Array[int] = []
var _stall_warnings: int = 0
var _clicks_by_state: Dictionary = {}
## monster -> the smallest horizontal distance to the core it ever reached.
var _closest_approach: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	SignalBus.wave_cleared.connect(func(wave: int) -> void: _cleared.append(wave))
	await _run()
	Engine.time_scale = 1.0
	if _failures == 0:
		print("OK - repeated hits leave the shared materials clean, the book's edge is the")
		print("     reach line, and a click on every SPAWN/TURN entry parks nothing to Wave %d." % TARGET_WAVE)
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _run() -> void:
	var main: Node = await _enter(RUN_SCENE)
	if main == null:
		return
	var core: SentenceCore = main.get_node("World/GameWorld/SentenceCore")
	var spawner: SpawnManager = main.get_node("World/GameWorld/SpawnManager")
	var pivot: Node3D = main.get_node("World/GameWorld/CameraRig/ShakePivot")
	_check(core != null and spawner != null and pivot != null,
		"the run scene carries a core, a spawner and a shake pivot")
	if core == null or spawner == null:
		return
	await _settle()
	await _check_repeated_hits(core, pivot)
	await _check_reach_geometry(core)
	await _check_lock_attempt()


## A. Eight hits, half of them interrupting the previous animation, then the
## verdict. A material_override that leaked into the GLB's own material would
## show up in a second instance loaded from the same (cached) resource.
func _check_repeated_hits(core: SentenceCore, pivot: Node3D) -> void:
	print("-- A. repeated and interrupted hits")
	var paper := core.visual_root.find_child("CorePaper", true, false) as MeshInstance3D
	var pages := core.visual_root.find_child("BookPages", true, false) as MeshInstance3D
	var ink := core.visual_root.find_child("CoreInk", true, false) as MeshInstance3D
	if paper == null or pages == null or ink == null:
		_check(false, "CorePaper / BookPages / CoreInk are all present")
		return
	var paper_material := paper.get_active_material(0) as StandardMaterial3D
	var pages_material := pages.get_active_material(0) as StandardMaterial3D
	var ink_material := ink.get_active_material(0) as StandardMaterial3D
	var paper_before: Color = paper_material.albedo_color
	var pages_before: Color = pages_material.albedo_color
	var ink_before: Color = ink_material.albedo_color
	print("    before: paper %s pages %s ink %s"
		% [str(paper_before), str(pages_before), str(ink_before)])
	_check(paper_material != pages_material,
		"CorePaper and BookPages do not already share one material resource")
	var surfaces_before := _surface_colours(core.visual_root)

	RunState.core_hp = PINNED_CORE_HP
	var animation: AnimationPlayer = core.get_node("AnimationPlayer")
	var flashes := 0
	var shake_moves := 0
	for round_index in HIT_ROUNDS:
		core.take_hit(1.0)
		await get_tree().process_frame
		await get_tree().process_frame
		if paper.material_override != null:
			flashes += 1
		if pivot.position != Vector3.ZERO:
			shake_moves += 1
		_check(pages.material_override == null and ink.material_override == null,
			"round %d: only CorePaper takes an override" % round_index)
		_check((pages.get_active_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(pages_before),
			"round %d: the page colour is unchanged while the paper flashes" % round_index)
		if round_index == 0:
			await _shoot("00_hit_flash_round0")
		# Odd rounds cut the animation off mid-flash; even rounds let it finish.
		if round_index % 2 == 1:
			continue
		var waited := 0
		while animation.is_playing() and waited < 180:
			await get_tree().process_frame
			waited += 1
	var waited_final := 0
	while animation.is_playing() and waited_final < 180:
		await get_tree().process_frame
		waited_final += 1
	await get_tree().process_frame
	print("    %d of %d hits raised a flash, %d moved the shake pivot" % [flashes, HIT_ROUNDS, shake_moves])
	_check(flashes == HIT_ROUNDS, "every hit raised the flash, got %d of %d" % [flashes, HIT_ROUNDS])
	_check(shake_moves == HIT_ROUNDS, "every hit moved the camera pivot, got %d of %d" % [shake_moves, HIT_ROUNDS])
	_check(paper.material_override == null,
		"the override is gone after %d hits, the last one interrupted" % HIT_ROUNDS)
	_check(core.visual_root.scale.is_equal_approx(Vector3.ONE)
		and core.visual_root.position.is_equal_approx(Vector3.ZERO),
		"VisualRoot is back at rest after %d hits" % HIT_ROUNDS)

	var paper_after: Color = (paper.get_active_material(0) as StandardMaterial3D).albedo_color
	var pages_after: Color = (pages.get_active_material(0) as StandardMaterial3D).albedo_color
	var ink_after: Color = (ink.get_active_material(0) as StandardMaterial3D).albedo_color
	print("    after:  paper %s pages %s ink %s"
		% [str(paper_after), str(pages_after), str(ink_after)])
	_check(_same_colour(paper_after, paper_before), "CorePaper is back on its own colour")
	_check(_same_colour(pages_after, pages_before), "BookPages never changed colour")
	_check(_same_colour(ink_after, ink_before), "CoreInk never changed colour")
	# Surface 0 of each part is not the whole story: the GLB packs 9 surfaces
	# into 6 materials, so one part's material also draws another part's second
	# surface. Compare every surface of every part.
	var surfaces_after := _surface_colours(core.visual_root)
	var drifted: Array[String] = []
	for key: String in surfaces_before:
		if not _same_colour(surfaces_after.get(key, Color.BLACK) as Color, surfaces_before[key] as Color):
			drifted.append("%s %s -> %s" % [key, str(surfaces_before[key]), str(surfaces_after.get(key))])
	print("    %d part surfaces compared, %d drifted" % [surfaces_before.size(), drifted.size()])
	_check(drifted.is_empty(), "no model surface changed colour: %s" % str(drifted))
	await _shoot("01_hit_recovered_after_%d" % HIT_ROUNDS)

	# The pollution test that matters: a second instance off the same cached GLB.
	var fresh: Node3D = (load("res://art/objective/sentence_core.glb") as PackedScene).instantiate()
	add_child(fresh)
	var fresh_paper := fresh.find_child("CorePaper", true, false) as MeshInstance3D
	var fresh_pages := fresh.find_child("BookPages", true, false) as MeshInstance3D
	var fresh_paper_colour: Color = (fresh_paper.get_active_material(0) as StandardMaterial3D).albedo_color
	var fresh_pages_colour: Color = (fresh_pages.get_active_material(0) as StandardMaterial3D).albedo_color
	print("    fresh instance of the same GLB: paper %s pages %s"
		% [str(fresh_paper_colour), str(fresh_pages_colour)])
	_check(_same_colour(fresh_paper_colour, paper_before),
		"a fresh instance of the GLB still has the original paper colour")
	_check(_same_colour(fresh_pages_colour, pages_before),
		"a fresh instance of the GLB still has the original page colour")
	_check(fresh_paper.material_override == null,
		"a fresh instance of the GLB carries no override")
	fresh.queue_free()



## B. Where reach_radius actually takes a monster off the field, relative to the
## book. Measures the closest approach of every monster of a wave and compares
## it with the book's own footprint on the same bearing.
func _check_reach_geometry(core: SentenceCore) -> void:
	print("-- B. reach geometry against the book's footprint")
	var bounds := _model_bounds(core)
	var half_width: float = bounds.size.x * 0.5
	var half_depth: float = bounds.size.z * 0.5
	print("    book footprint %.2f x %.2f m, reach_radius %.2f"
		% [bounds.size.x, bounds.size.z, core.reach_radius])
	RunState.core_hp = PINNED_CORE_HP
	_closest_approach.clear()
	# Watch a wave's worth of monsters walk in with no clicks at all, so every
	# one of them ends on reach_radius rather than on a kill.
	var frames := 0
	while frames < WAVE_FRAME_BUDGET and _closest_approach.size() < 12:
		for monster: JamoMonster in _alive_monsters():
			var offset: Vector3 = monster.global_position - core.global_position
			offset.y = 0.0
			var key: int = monster.get_instance_id()
			var previous: float = _closest_approach.get(key, INF) as float
			_closest_approach[key] = minf(previous, offset.length())
		await get_tree().process_frame
		frames += 1
	var worst_overlap := -INF
	var reached := 0
	var min_distance := INF
	for key: int in _closest_approach:
		var distance: float = _closest_approach[key]
		if distance > core.reach_radius + 0.05:
			continue
		reached += 1
		min_distance = minf(min_distance, distance)
		worst_overlap = maxf(worst_overlap, half_width - distance)
	print("    %d monster(s) got inside reach; closest centre %.2f m from the core"
		% [reached, min_distance])
	print("    worst centre overlap past the book's widest half extent %.2f m: %.2f m"
		% [half_width, worst_overlap])
	_check(reached > 0, "at least one monster reached the core during the sample")
	_check(min_distance >= half_depth,
		"no monster centre got past the book's near face (%.2f m), closest was %.2f m"
		% [half_depth, min_distance])
	_check(core.reach_radius >= half_width,
		"reach_radius %.2f still covers the book's widest half extent %.2f"
		% [core.reach_radius, half_width])
	_check(core.reach_radius <= half_width + 0.6,
		"reach_radius %.2f does not take monsters off the field far from the book (half width %.2f)"
		% [core.reach_radius, half_width])
	await _shoot("10_reach_field")


## C. QA's own lock attempt on the new core position: a non-lethal click on every
## SPAWN and TURN entry, the core pinned so only the monsters can end a wave.
func _check_lock_attempt() -> void:
	print("-- C. a non-lethal click on every SPAWN / TURN entry, Wave 1~%d" % TARGET_WAVE)
	RunState.core_hp = PINNED_CORE_HP
	_cleared.clear()
	_clicks_by_state.clear()
	var armed: Dictionary = {}
	var start_wave: int = RunState.current_wave
	var last_wave: int = start_wave
	var frames := 0
	var shot_waves: Dictionary = {}
	# Distance walked per monster, so a survivor at the end can be told apart
	# from a parked one: a lock means state stuck AND no movement.
	var travelled: Dictionary = {}
	var last_position: Dictionary = {}
	while RunState.is_active and frames < WAVE_FRAME_BUDGET \
			and _cleared.size() < TARGET_WAVE:
		RunState.core_hp = PINNED_CORE_HP
		for monster: JamoMonster in _alive_monsters():
			var moved_key: int = monster.get_instance_id()
			var here: Vector3 = monster.global_position
			if last_position.has(moved_key):
				travelled[moved_key] = float(travelled.get(moved_key, 0.0)) \
					+ here.distance_to(last_position[moved_key] as Vector3)
			last_position[moved_key] = here
		for monster: JamoMonster in _alive_monsters():
			var key: int = monster.get_instance_id()
			var state: JamoMonster.State = monster.get_state()
			var is_target: bool = state == JamoMonster.State.SPAWN or state == JamoMonster.State.TURN
			if not is_target or armed.get(key, -1) == state or monster.hp <= 1.0:
				continue
			armed[key] = state
			if monster.take_click_damage(1.0):
				var state_name: String = JamoMonster.State.keys()[state]
				_clicks_by_state[state_name] = int(_clicks_by_state.get(state_name, 0)) + 1
		if RunState.current_wave != last_wave:
			last_wave = RunState.current_wave
		if not shot_waves.has(last_wave) and last_wave <= TARGET_WAVE:
			shot_waves[last_wave] = true
			await _shoot("%02d_wave%d" % [20 + last_wave, last_wave])
		await get_tree().process_frame
		frames += 1
	print("    non-lethal clicks by state: %s" % str(_clicks_by_state))
	print("    waves cleared: %s in %d frames" % [str(_cleared), frames])
	var survivors: Array[JamoMonster] = _alive_monsters()
	print("    field at the end: %d alive" % survivors.size())
	var parked := 0
	for monster: JamoMonster in survivors:
		var walked: float = float(travelled.get(monster.get_instance_id(), 0.0))
		print("    survivor %s state=%s hp=%.0f walked %.2f m"
			% [monster.name, JamoMonster.State.keys()[monster.get_state()], monster.hp, walked])
		if walked < 0.5:
			parked += 1
	_check(parked == 0, "%d survivor(s) never moved - that is a lock" % parked)
	# Sections A and B already played part of the run, so the count starts at
	# whatever wave was live when the clicking began, not at Wave 1.
	for offset in TARGET_WAVE:
		var wave: int = start_wave + offset
		_check(_cleared.has(wave), "Wave %d cleared on its own, cleared %s" % [wave, str(_cleared)])
	_check(int(_clicks_by_state.get("TURN", 0)) > 0, "at least one click landed in TURN")
	_check(int(_clicks_by_state.get("SPAWN", 0)) > 0, "at least one click landed in SPAWN")
	_check(frames < WAVE_FRAME_BUDGET, "the run did not run out of frames waiting on a wave")
	await _shoot("30_after_wave%d" % TARGET_WAVE)


# --- plumbing ---------------------------------------------------------------

func _model_bounds(core: SentenceCore) -> AABB:
	var bounds := AABB()
	var first := true
	for node: Node in core.visual_root.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null:
			continue
		var world_bounds: AABB = part.global_transform * part.get_aabb()
		bounds = world_bounds if first else bounds.merge(world_bounds)
		first = false
	return bounds


## "<part>#<surface>" -> albedo, for every surface the model draws. Reads the
## mesh's own surface material, not the override, so a flash in progress does
## not show up here but a mutated shared resource does.
func _surface_colours(root: Node) -> Dictionary:
	var colours: Dictionary = {}
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null:
			continue
		for surface in part.mesh.get_surface_count():
			var material := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null:
				continue
			colours["%s#%d" % [part.name, surface]] = material.albedo_color
	return colours


func _alive_monsters() -> Array[JamoMonster]:
	var found: Array[JamoMonster] = []
	for node: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
		var monster := node as JamoMonster
		if monster != null and monster.is_inside_tree() and monster.is_alive():
			found.append(monster)
	return found


func _same_colour(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= COLOUR_EPSILON \
		and absf(a.g - b.g) <= COLOUR_EPSILON \
		and absf(a.b - b.b) <= COLOUR_EPSILON \
		and absf(a.a - b.a) <= COLOUR_EPSILON


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("  FAIL: %s" % message)


func _shoot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s.png" % [OUT_DIR, tag]
	get_viewport().get_texture().get_image().save_png(path)
	print("    shot: %s" % path)


func _settle() -> void:
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


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
