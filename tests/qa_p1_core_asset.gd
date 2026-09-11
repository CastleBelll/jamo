extends Node

## QA P1 core asset: the 문장핵 model from art/objective in the real run scene.
## WINDOW MODE ONLY - it screenshots and measures frame rate.
##
## Run: godot --path . res://tests/qa_p1_core_asset.tscn
##
## What it checks:
##   1. the seven model parts are live under VisualRoot and the book sits inside
##      the paper slab
##   2. a hit flashes CorePaper through material_override, clears it again, and
##      leaves VisualRoot at rest; the camera shake still fires; the shared page
##      material is untouched
##   3. Wave 1~5 played with real clicks, a screenshot per wave and one on the
##      first core hit, every wave clearing on its own
##   4. 20 monsters on the field with the model drawn at 60 FPS

const RUN_SCENE := "res://scenes/main/main.tscn"
const OUT_DIR := "res://tests/qa_artifacts/p1/core_asset"
const TARGET_WAVE := 5
const WAVE_FRAME_BUDGET := 4000
const FPS_FIELD := 20
const FPS_SAMPLE_FRAMES := 300
const MISS_BUDGET := 40
const PLAY_TIME_SCALE := 3.0
## Half width / half depth of the 12 x 7.5 m paper sheet, the arena rectangle
## |x| <= 6, |z| <= 3.75. Must match arena.tscn PaperTop.
const SLAB_HALF_EXTENTS := Vector2(6.0, 3.75)
const PARTS := ["Binding", "BookPages", "BindingThread", "SentenceInk", "CorePaper", "CoreInk", "Seal"]

var _failures: int = 0
var _wave_log: Array[Dictionary] = []
var _cleared: Array[int] = []
var _core_hit_pending: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	SaveManager.delete_save()
	MetaState.reset()
	RunState.reset()
	SignalBus.wave_cleared.connect(func(wave: int) -> void: _cleared.append(wave))
	SignalBus.core_hp_changed.connect(func(_c: float, _m: float) -> void: _core_hit_pending = true)
	await _run()
	Engine.time_scale = 1.0
	_print_table()
	if _failures == 0:
		print("OK - the 문장핵 model is in play, flashes on a hit, and Wave 1~%d clear around it." % TARGET_WAVE)
		get_tree().quit(0)
	else:
		printerr("FAILED - %d check(s) failed." % _failures)
		get_tree().quit(1)


func _run() -> void:
	var main: Node = await _enter(RUN_SCENE)
	if main == null:
		return
	var spawner: SpawnManager = main.get_node("World/GameWorld/SpawnManager")
	var core: SentenceCore = main.get_node("World/GameWorld/SentenceCore")
	var pivot: Node3D = main.get_node("World/GameWorld/CameraRig/ShakePivot")
	_check(core != null and spawner != null, "the run scene carries a SentenceCore and a spawner")
	await _settle()
	_check_model(core)
	await _shoot("00_core_idle")
	await _check_hit(core, pivot)

	Engine.time_scale = PLAY_TIME_SCALE
	for _pass in TARGET_WAVE + 4:
		if not RunState.is_active:
			break
		await _play_one_wave(spawner)
	Engine.time_scale = 1.0
	_check(_reached_wave() >= TARGET_WAVE,
		"Wave %d was reached by playing, got %d" % [TARGET_WAVE, _reached_wave()])
	for wave in range(1, TARGET_WAVE):
		_check(_cleared.has(wave), "Wave %d cleared on its own, cleared %s" % [wave, str(_cleared)])
	_check(not RunState.is_active, "the run ended inside the budget (the core is the only failure)")
	# The probe is about the field and the model, so the result card from the
	# defeat above (shown after main.gd's settle delay) is hidden for its shot.
	var result: Control = main.get_node("UI/RunResult")
	var waited := 0
	while not result.visible and waited < 2000:
		await get_tree().process_frame
		waited += 1
	_check(result.visible, "the result screen appeared after the core fell")
	result.visible = false
	await _measure_frame_rate(spawner)


## 1. The parts the asset README names, all under visual_root, and the book's
## footprint inside the paper rectangle. The old Pillar/Cap primitives are gone.
func _check_model(core: SentenceCore) -> void:
	print("-- model under VisualRoot")
	_check(core.visual_root.find_child("Pillar", true, false) == null
		and core.visual_root.find_child("Cap", true, false) == null,
		"the stand-in primitives are gone")
	var bounds := AABB()
	var first := true
	for part_name: String in PARTS:
		var part := core.visual_root.find_child(part_name, true, false) as MeshInstance3D
		_check(part != null and part.mesh != null, "part %s is a MeshInstance3D with a mesh" % part_name)
		if part == null or part.mesh == null:
			continue
		var world_bounds: AABB = part.global_transform * part.get_aabb()
		bounds = world_bounds if first else bounds.merge(world_bounds)
		first = false
	print("    world bounds: pos=%s size=%s" % [str(bounds.position), str(bounds.size)])
	var worst := 0.0
	for corner_x: float in [bounds.position.x, bounds.end.x]:
		for corner_z: float in [bounds.position.z, bounds.end.z]:
			worst = maxf(worst, JamoMonster.arena_spill(
				Vector3(corner_x, 0.0, corner_z), SLAB_HALF_EXTENTS
			))
	print("    footprint corner spill max %.2f of 1.00 (half extents %s)"
		% [worst, str(SLAB_HALF_EXTENTS)])
	_check(worst <= 1.0, "the book's footprint stays on the paper sheet")
	_check(bounds.size.y > 1.0, "the model stands taller than a monster, got %.2f m" % bounds.size.y)
	var half_width: float = bounds.size.x * 0.5
	print("    reach_radius %.2f vs half width %.2f, half depth %.2f"
		% [core.reach_radius, half_width, bounds.size.z * 0.5])
	_check(core.reach_radius >= half_width,
		"reach_radius covers the book's widest half extent (%.2f)" % half_width)


## 2. One hit through the real take_hit path: the flash is a material_override
## on CorePaper only, cleared by the end of the animation, VisualRoot back at
## rest, camera pivot moved by the shake, shared page material untouched.
func _check_hit(core: SentenceCore, pivot: Node3D) -> void:
	print("-- one hit on the core")
	var paper := core.visual_root.find_child("CorePaper", true, false) as MeshInstance3D
	var pages := core.visual_root.find_child("BookPages", true, false) as MeshInstance3D
	var paper_original: Material = paper.get_active_material(0)
	var pages_original: Material = pages.get_active_material(0)
	var pages_color: Color = (pages_original as StandardMaterial3D).albedo_color
	var paper_color: Color = (paper_original as StandardMaterial3D).albedo_color
	var hp_before: float = RunState.core_hp
	_check(paper.material_override == null, "CorePaper carries no override before the hit")

	core.take_hit(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var flash: Material = paper.material_override
	_check(flash != null and flash != paper_original, "the hit put a material_override on CorePaper")
	_check(paper.get_active_material(0) == flash, "the override is what CorePaper draws during the hit")
	if flash is StandardMaterial3D:
		var flash_color: Color = (flash as StandardMaterial3D).albedo_color
		print("    flash albedo %s vs paper %s" % [str(flash_color), str(paper_color)])
		_check(flash_color.r - flash_color.g > 0.3, "the flash colour is visibly different from the paper")
	_check(pages.get_active_material(0) == pages_original
		and (pages_original as StandardMaterial3D).albedo_color == pages_color,
		"the shared page material is untouched by the flash")
	var shook: bool = pivot.position != Vector3.ZERO
	_check(shook, "the camera pivot moved during the hit shake")
	_check(RunState.core_hp == hp_before - 1.0,
		"the hit cost 1 core HP (%.0f -> %.0f)" % [hp_before, RunState.core_hp])
	await _shoot("01_core_hit_flash")

	var waited := 0
	var animation: AnimationPlayer = core.get_node("AnimationPlayer")
	while animation.is_playing() and waited < 120:
		await get_tree().process_frame
		waited += 1
	await get_tree().process_frame
	_check(paper.material_override == null, "the override is cleared once the hit animation ends")
	_check(paper.get_active_material(0) == paper_original, "CorePaper is back on its own material")
	_check(core.visual_root.scale.is_equal_approx(Vector3.ONE)
		and core.visual_root.position.is_equal_approx(Vector3.ZERO),
		"VisualRoot is back at rest after the squash")
	await _shoot("02_core_hit_recovered")


## 3. Plays the current wave: every point of energy on real clicks, then
## watches the rest resolve with no input. The first core hit of a wave gets a
## screenshot while the flash is still up.
func _play_one_wave(spawner: SpawnManager) -> void:
	var wave: int = RunState.current_wave
	var core_before: float = RunState.core_hp
	var kills_before: float = RunState.get_run_statistic("kills")
	var clicks := 0
	var frames := 0
	var misses := 0
	var hit_shot_taken := false
	_core_hit_pending = false
	await _settle()
	await _shoot("%02d_wave%d_start" % [wave * 10, wave])
	while RunState.is_active and RunState.current_wave == wave \
			and RunState.current_energy > 0 and frames < WAVE_FRAME_BUDGET \
			and misses < MISS_BUDGET:
		var monster: JamoMonster = _closest_alive_to_core(spawner.objective)
		if monster == null:
			await get_tree().process_frame
			frames += 1
			continue
		if await _click_monster(monster):
			clicks += 1
			misses = 0
		else:
			misses += 1
		frames += 2
	_check(misses < MISS_BUDGET,
		"Wave %d: %d clicks in a row missed a monster that was on screen" % [wave, misses])
	while RunState.is_active and RunState.current_wave == wave and frames < WAVE_FRAME_BUDGET:
		if _core_hit_pending and not hit_shot_taken:
			hit_shot_taken = true
			await _shoot("%02d_wave%d_core_hit" % [wave * 10 + 5, wave])
		await get_tree().process_frame
		frames += 1
	_wave_log.append({
		"wave": wave,
		"clicks": clicks,
		"kills": int(RunState.get_run_statistic("kills") - kills_before),
		"core_lost": core_before - RunState.core_hp,
		"core_left": RunState.core_hp,
		"cleared": _cleared.has(wave),
	})


## One real click, delivered where the monster is drawn on screen.
func _click_monster(monster: JamoMonster) -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		_check(false, "the arena has no current Camera3D to click through")
		return false
	var before: int = RunState.current_energy
	var point: Vector2 = camera.unproject_position(monster.global_position)
	_warp_to(point)
	await get_tree().process_frame
	_click_at(point)
	await get_tree().process_frame
	await get_tree().process_frame
	return RunState.current_energy < before


## 4. Frame rate with a full field and the model drawn. Doc v0.4 section 36
## asks for 20 monsters at 60 FPS. Same probe as qa_p1_play.
func _measure_frame_rate(spawner: SpawnManager) -> void:
	print("-- frame rate on a full field with the model")
	Engine.time_scale = 1.0
	RunState.start_run()
	await get_tree().process_frame
	spawner.objective = null
	var wave := WaveData.new()
	wave.wave_number = 1
	for scene: PackedScene in MetaState.database.find_wave(TARGET_WAVE).enemy_pool:
		wave.enemy_pool.append(scene)
	wave.enemy_count = 500
	wave.max_alive = FPS_FIELD
	wave.spawn_interval = 0.05
	wave.hp_multiplier = 60.0
	spawner.configure_wave(wave)
	var frames := 0
	while spawner.alive_count() < FPS_FIELD and frames < WAVE_FRAME_BUDGET:
		await get_tree().process_frame
		frames += 1
	_check(spawner.alive_count() >= FPS_FIELD,
		"the field filled to %d monsters, got %d" % [FPS_FIELD, spawner.alive_count()])
	for _i in 60:
		await get_tree().process_frame
	var samples: Array[float] = []
	for _i in FPS_SAMPLE_FRAMES:
		await get_tree().process_frame
		samples.append(Engine.get_frames_per_second())
	samples.sort()
	var total := 0.0
	for value: float in samples:
		total += value
	var average: float = total / samples.size()
	var low_index: int = maxi(0, int(samples.size() * 0.01))
	await _shoot("95_full_field_%d" % spawner.alive_count())
	print("    %d alive: avg %.1f FPS, min %.1f, low 1 pct %.1f"
		% [spawner.alive_count(), average, samples[0], samples[low_index]])
	_check(average >= 60.0,
		"20 monsters and the model hold 60 FPS (doc v0.4 section 36), average was %.1f" % average)
	spawner.stop()
	spawner.clear_field()


# --- plumbing ---------------------------------------------------------------

func _reached_wave() -> int:
	var highest := 1
	for entry: Dictionary in _wave_log:
		highest = maxi(highest, int(entry["wave"]))
	return highest


func _closest_alive_to_core(core: Node3D) -> JamoMonster:
	var best: JamoMonster = null
	var best_distance := INF
	for node: Node in get_tree().get_nodes_in_group(&"jamo_monster"):
		var monster := node as JamoMonster
		if monster == null or not monster.is_inside_tree() or not monster.is_alive():
			continue
		var distance: float = monster.global_position.distance_to(core.global_position)
		if distance < best_distance:
			best = monster
			best_distance = distance
	return best


func _print_table() -> void:
	print("-- wave log")
	print("    wave | clicks | kills | core lost | core left | cleared")
	for entry: Dictionary in _wave_log:
		print("    %4d | %6d | %5d | %9.0f | %9.0f | %s" % [
			entry["wave"], entry["clicks"], entry["kills"],
			entry["core_lost"], entry["core_left"], str(entry["cleared"]),
		])


func _click_at(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)


func _warp_to(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	Input.warp_mouse(point)
	Input.parse_input_event(event)


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
